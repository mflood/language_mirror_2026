#!/usr/bin/env python3
"""
Step 2 (ElevenLabs variant): Synthesize a script.json file (output of step 1)
into audio using the ElevenLabs API, then concatenate the per-turn segments
into one track.

Drop-in alternative to ``2_synthesize_audio.py`` — reads the same script.json
and writes the same ``samples/<bundle_id>/audio/`` layout, so steps 3 and 4
of the pipeline don't care which TTS produced the audio.

See ``ELEVENLABS_WORKFLOW.md`` in this directory for the end-to-end flow,
voice picking, and cost model.

SAFETY: defaults to dry-run. Will refuse to call ElevenLabs without --commit.
Always prints a character debit estimate first. Hard cap on total character
count protects against runaway scripts.

Usage (dry-run, no API calls):
    python sample_bundle_pipeline/2_synthesize_audio_elevenlabs.py \\
        --bundle-id starter_seoul_market \\
        --voice-a <FEMALE_VOICE_ID> \\
        --voice-b <MALE_VOICE_ID>

Commit (will charge characters against your ElevenLabs quota):
    python sample_bundle_pipeline/2_synthesize_audio_elevenlabs.py \\
        --bundle-id starter_seoul_market \\
        --voice-a <FEMALE_VOICE_ID> \\
        --voice-b <MALE_VOICE_ID> \\
        --commit

Output:
    samples/<bundle_id>/audio/track_001.mp3
    samples/<bundle_id>/audio/script.timed.json
    samples/<bundle_id>/audio/turns/turn_NNN.mp3

Note on the script.json "voice" field:
    Step 1 populates ``voice`` with Polly voice names (Seoyeon, Jihye, ...).
    This script IGNORES that field and maps by ``speaker`` letter instead:
    "A" → --voice-a, "B" → --voice-b, etc. Scripts with more than two
    speakers will be rejected.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
SAMPLES_DIR = REPO_ROOT / "sample_bundle_pipeline" / "samples"

# Hard default cap. Override only if you really mean it.
DEFAULT_MAX_CHARS = 10_000

# Prompt the user to confirm if a single run would burn more than this.
# ElevenLabs doesn't expose a per-character USD cost (it depends on tier),
# so we gate on raw character count instead of dollars.
CONFIRM_CHAR_THRESHOLD = 5_000

# Retries for transient failures (429 rate limit, 5xx).
MAX_RETRIES = 4


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Synthesize a script with ElevenLabs")
    p.add_argument("--bundle-id", required=True, help="Folder name under samples/")
    p.add_argument("--script", type=Path, default=None, help="Override script.json path (default: samples/<id>/script.json)")
    p.add_argument("--output-dir", type=Path, default=None, help="Override output dir (default: samples/<id>/audio)")
    p.add_argument("--voice-a", required=True, help="ElevenLabs voice id for speaker A")
    p.add_argument("--voice-b", default=None, help="ElevenLabs voice id for speaker B (default: same as --voice-a)")
    p.add_argument("--model", default="eleven_multilingual_v2", help="ElevenLabs model id (default: eleven_multilingual_v2)")
    p.add_argument("--stability", type=float, default=0.5, help="Voice settings stability 0.0-1.0 (default: 0.5)")
    p.add_argument("--similarity-boost", type=float, default=0.75, help="Voice settings similarity_boost 0.0-1.0 (default: 0.75)")
    p.add_argument("--style", type=float, default=0.0, help="Voice settings style 0.0-1.0 (default: 0.0)")
    p.add_argument("--inter-turn-pause-ms", type=int, default=400, help="Silence between turns (ms)")
    p.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS, help=f"Hard cap on total characters (default: {DEFAULT_MAX_CHARS})")
    p.add_argument("--commit", action="store_true", help="Actually call ElevenLabs. Default is dry-run.")
    return p.parse_args()


def load_script(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"❌ Script not found: {path}\n   Did you run step 1 (--commit)?")
    return json.loads(path.read_text(encoding="utf-8"))


def build_voice_map(args: argparse.Namespace) -> dict[str, str]:
    """Speaker letter → voice id. B falls back to A if unspecified."""
    return {
        "A": args.voice_a,
        "B": args.voice_b or args.voice_a,
    }


def validate_speakers(script: dict[str, Any], voice_map: dict[str, str]) -> None:
    unknown: set[str] = set()
    for turn in script.get("turns", []):
        speaker = turn.get("speaker")
        if speaker not in voice_map:
            unknown.add(speaker or "<missing>")
    if unknown:
        raise SystemExit(
            f"❌ Script contains speakers with no voice mapping: {sorted(unknown)}\n"
            f"   This synth script only supports speakers A and B. Either collapse\n"
            f"   the script to two speakers, or extend this tool with more --voice-*\n"
            f"   flags."
        )


def count_chars(script: dict[str, Any]) -> int:
    return sum(len(turn.get("text", "")) for turn in script.get("turns", []))


def print_plan(script: dict[str, Any], total_chars: int, voice_map: dict[str, str], args: argparse.Namespace) -> None:
    print("═══ ElevenLabs synthesis plan ═══")
    print(f"  Bundle:           {args.bundle_id}")
    print(f"  Script:           {args.script}")
    print(f"  Title:            {script.get('title')} ({script.get('english_title', '')})")
    print(f"  Language:         {script.get('language')}")
    print(f"  Model:            {args.model}")
    print(f"  Voice A:          {voice_map['A']}")
    print(f"  Voice B:          {voice_map['B']}{' (same as A)' if voice_map['A'] == voice_map['B'] else ''}")
    print(f"  Stability:        {args.stability}")
    print(f"  Similarity boost: {args.similarity_boost}")
    print(f"  Style:            {args.style}")
    print(f"  Inter-turn pause: {args.inter_turn_pause_ms} ms")
    print(f"  Turns:            {len(script.get('turns', []))}")
    print(f"  Total characters: {total_chars}")
    print(f"  Cap:              {args.max_chars} chars")
    print()
    turns_per_voice: dict[str, int] = {}
    for t in script.get("turns", []):
        speaker = t.get("speaker", "?")
        voice_id = voice_map.get(speaker, "?")
        key = f"{speaker} → {voice_id}"
        turns_per_voice[key] = turns_per_voice.get(key, 0) + 1
    print(f"  Turns per voice: {turns_per_voice}")
    print(
        "  Cost:            varies by ElevenLabs tier — characters above will be\n"
        "                   debited from your monthly quota. See ELEVENLABS_WORKFLOW.md."
    )
    print()


def synth_turn(
    client: Any,
    voice_settings: Any,
    text: str,
    voice_id: str,
    model_id: str,
    out_file: Path,
) -> None:
    """One turn with retry on transient failures."""
    last_error: Exception | None = None
    for attempt in range(MAX_RETRIES):
        try:
            audio_iter = client.text_to_speech.convert(
                voice_id=voice_id,
                text=text,
                model_id=model_id,
                output_format="mp3_44100_128",
                voice_settings=voice_settings,
            )
            with open(out_file, "wb") as f:
                for chunk in audio_iter:
                    if chunk:
                        f.write(chunk)
            return
        except Exception as e:
            last_error = e
            status = getattr(e, "status_code", None) or getattr(e, "status", None)
            is_retryable = (
                status == 429
                or (isinstance(status, int) and 500 <= status < 600)
                or "429" in str(e)
                or "rate" in str(e).lower()
            )
            if attempt == MAX_RETRIES - 1 or not is_retryable:
                break
            delay = 2 ** attempt  # 1, 2, 4, 8 seconds
            print(f"   ⚠ transient error ({status or 'unknown'}); retrying in {delay}s")
            time.sleep(delay)
    raise SystemExit(f"❌ ElevenLabs request failed after {MAX_RETRIES} attempts: {last_error}")


def synth_with_elevenlabs(
    script: dict[str, Any],
    voice_map: dict[str, str],
    out_dir: Path,
    args: argparse.Namespace,
) -> None:
    try:
        from elevenlabs import ElevenLabs, VoiceSettings
    except ImportError:
        raise SystemExit("elevenlabs package not installed. pip install elevenlabs")

    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key:
        raise SystemExit("ELEVENLABS_API_KEY is not set")

    client = ElevenLabs(api_key=api_key)
    voice_settings = VoiceSettings(
        stability=args.stability,
        similarity_boost=args.similarity_boost,
        style=args.style,
    )

    out_dir.mkdir(parents=True, exist_ok=True)
    turns_dir = out_dir / "turns"
    turns_dir.mkdir(parents=True, exist_ok=True)

    per_turn_files: list[Path] = []
    timings: list[dict[str, Any]] = []
    cumulative_ms = 0

    for i, turn in enumerate(script.get("turns", [])):
        speaker = turn.get("speaker", "A")
        voice_id = voice_map[speaker]
        text = turn["text"]
        out_file = turns_dir / f"turn_{i:03d}.mp3"
        print(f"▶ Synthesizing turn {i + 1}/{len(script['turns'])}: speaker={speaker} voice={voice_id} chars={len(text)}")
        synth_turn(
            client=client,
            voice_settings=voice_settings,
            text=text,
            voice_id=voice_id,
            model_id=args.model,
            out_file=out_file,
        )
        per_turn_files.append(out_file)

        # Approx timing at ~12 chars/sec; concatenation step overwrites with
        # accurate values if pydub is available.
        approx_ms = int((len(text) / 12) * 1000)
        timings.append({
            "turn": i,
            "speaker": speaker,
            "voice": voice_id,
            "text": text,
            "startMs": cumulative_ms,
            "endMs": cumulative_ms + approx_ms,
            "approx": True,
        })
        cumulative_ms += approx_ms + args.inter_turn_pause_ms

    # Concatenate (identical to the Polly path)
    print("🔗 Concatenating turns...")
    track_path = out_dir / "track_001.mp3"
    try:
        from pydub import AudioSegment

        combined = AudioSegment.empty()
        accurate_timings: list[dict[str, Any]] = []
        cursor_ms = 0
        for i, f in enumerate(per_turn_files):
            seg = AudioSegment.from_file(f, format="mp3")
            start = cursor_ms
            combined += seg
            cursor_ms += len(seg)
            end = cursor_ms
            if i < len(per_turn_files) - 1:
                pause = AudioSegment.silent(duration=args.inter_turn_pause_ms)
                combined += pause
                cursor_ms += args.inter_turn_pause_ms
            accurate_timings.append({
                **timings[i],
                "startMs": start,
                "endMs": end,
                "approx": False,
            })
        combined.export(track_path, format="mp3", bitrate="128k")
        timings = accurate_timings
        print(f"✅ Wrote {track_path} ({cursor_ms / 1000:.1f}s, accurate timings)")
    except ImportError:
        print("⚠ pydub not installed; per-turn files written but not concatenated.")
        print("   pip install pydub  (and brew install ffmpeg)")
        print(f"   Per-turn files in: {out_dir}")

    timings_path = out_dir / "script.timed.json"
    timings_path.write_text(
        json.dumps({"language": script.get("language"), "turns": timings}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"✅ Wrote {timings_path}")


def main() -> int:
    args = parse_args()

    script_path = args.script or (SAMPLES_DIR / args.bundle_id / "script.json")
    args.script = script_path
    out_dir = args.output_dir or (SAMPLES_DIR / args.bundle_id / "audio")

    script = load_script(script_path)
    voice_map = build_voice_map(args)
    validate_speakers(script, voice_map)
    total_chars = count_chars(script)
    print_plan(script, total_chars, voice_map, args)

    if total_chars > args.max_chars:
        print(
            f"❌ Total characters ({total_chars}) exceeds the cap ({args.max_chars}).\n"
            f"   This is a safety guard. If you really want to proceed, re-run with\n"
            f"   --max-chars {total_chars + 100}.",
            file=sys.stderr,
        )
        return 1

    if not args.commit:
        print("--- DRY RUN — no ElevenLabs calls will be made ---")
        print()
        print(f"To actually synthesize, re-run with --commit ({total_chars} chars will be debited).")
        return 0

    if total_chars > CONFIRM_CHAR_THRESHOLD:
        print(f"⚠ This run will debit {total_chars} chars, above the {CONFIRM_CHAR_THRESHOLD} confirmation threshold.")
        confirm = input("Type 'YES' to proceed: ")
        if confirm != "YES":
            print("Aborted.")
            return 1

    print("🚀 Calling ElevenLabs...")
    synth_with_elevenlabs(script, voice_map, out_dir, args)
    print()
    print("🎉 Synthesis complete.")
    print(f"   QA first: afplay {out_dir}/track_001.mp3")
    print(f"   Then:     ./sample_bundle_pipeline/3_make_qr_pack.sh {args.bundle_id} {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
