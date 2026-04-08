#!/usr/bin/env python3
"""
Step 2: Synthesize a script.json file (output of step 1) into audio using
AWS Polly, then concatenate the per-turn segments into one file per
"track" (or one file per scene if you're producing multi-file bundles).

SAFETY: defaults to dry-run. Will refuse to make any AWS calls without
--commit. Always shows the cost estimate first. Hard cap on total
character count protects against runaway scripts.

Usage (dry-run, no AWS calls):
    python sample_bundle_pipeline/2_synthesize_audio.py --bundle-id starter_coffee

Commit (will spend money):
    python sample_bundle_pipeline/2_synthesize_audio.py --bundle-id starter_coffee --commit

Output:
    samples/<bundle_id>/audio/track_001.mp3
    samples/<bundle_id>/audio/script.timed.json   (per-turn timings, useful for QA)

If you want multiple tracks per bundle, supply a script that contains
"scene_breaks" or run this script once per scene with a different bundle_id.
For now we produce a single track per script.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
SAMPLES_DIR = REPO_ROOT / "sample_bundle_pipeline" / "samples"

# Polly neural pricing as of 2025: $4.00 per 1M characters.
# Generative pricing is $16/1M but we don't use generative voices here.
NEURAL_COST_PER_CHAR = 4.00 / 1_000_000

# Hard default cap. Override only if you really mean it.
DEFAULT_MAX_CHARS = 10_000


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Synthesize a script with AWS Polly")
    p.add_argument("--bundle-id", required=True, help="Folder name under samples/")
    p.add_argument("--script", type=Path, default=None, help="Override script.json path (default: samples/<id>/script.json)")
    p.add_argument("--output-dir", type=Path, default=None, help="Override output dir (default: samples/<id>/audio)")
    p.add_argument("--engine", choices=("neural", "long-form", "standard"), default="neural", help="Polly engine")
    p.add_argument("--sample-rate", default="24000", help="Audio sample rate (default: 24000)")
    p.add_argument("--inter-turn-pause-ms", type=int, default=400, help="Silence between turns (ms)")
    p.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS, help=f"Hard cap on total characters (default: {DEFAULT_MAX_CHARS})")
    p.add_argument("--commit", action="store_true", help="Actually call Polly. Default is dry-run.")
    p.add_argument("--region", default="us-east-1", help="AWS region (default: us-east-1)")
    return p.parse_args()


def load_script(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"❌ Script not found: {path}\n   Did you run step 1 (--commit)?")
    return json.loads(path.read_text(encoding="utf-8"))


def estimate_cost(script: dict[str, Any]) -> tuple[int, float]:
    total_chars = sum(len(turn.get("text", "")) for turn in script.get("turns", []))
    cost_usd = total_chars * NEURAL_COST_PER_CHAR
    return total_chars, cost_usd


def print_plan(script: dict[str, Any], total_chars: int, cost_usd: float, args: argparse.Namespace) -> None:
    print("═══ Polly synthesis plan ═══")
    print(f"  Bundle:           {args.bundle_id}")
    print(f"  Script:           {args.script}")
    print(f"  Title:            {script.get('title')} ({script.get('english_title', '')})")
    print(f"  Language:         {script.get('language')}")
    print(f"  Engine:           {args.engine}")
    print(f"  Sample rate:      {args.sample_rate} Hz")
    print(f"  Inter-turn pause: {args.inter_turn_pause_ms} ms")
    print(f"  Turns:            {len(script.get('turns', []))}")
    print(f"  Total characters: {total_chars}")
    print(f"  Estimated cost:   ${cost_usd:.4f} USD  ({total_chars} chars × $4/1M neural)")
    print(f"  Cap:              {args.max_chars} chars")
    print()
    voices_used: dict[str, int] = {}
    for t in script.get("turns", []):
        v = t.get("voice", "?")
        voices_used[v] = voices_used.get(v, 0) + 1
    print(f"  Voices in use: {voices_used}")
    print()


def synth_with_polly(script: dict[str, Any], out_dir: Path, args: argparse.Namespace) -> None:
    try:
        import boto3
    except ImportError:
        raise SystemExit("boto3 not installed. pip install boto3")

    polly = boto3.client("polly", region_name=args.region)
    out_dir.mkdir(parents=True, exist_ok=True)
    audio_dir = out_dir
    audio_dir.mkdir(parents=True, exist_ok=True)
    # Per-turn scratch files live in a subdirectory so step 3's audio scan
    # only picks up the final concatenated track at the top level.
    turns_dir = audio_dir / "turns"
    turns_dir.mkdir(parents=True, exist_ok=True)

    # Synthesize each turn into its own mp3 first
    per_turn_files: list[Path] = []
    timings: list[dict[str, Any]] = []
    cumulative_ms = 0

    for i, turn in enumerate(script.get("turns", [])):
        voice = turn["voice"]
        text = turn["text"]
        out_file = turns_dir / f"turn_{i:03d}.mp3"
        print(f"▶ Synthesizing turn {i + 1}/{len(script['turns'])}: voice={voice}, chars={len(text)}")
        resp = polly.synthesize_speech(
            Text=text,
            OutputFormat="mp3",
            VoiceId=voice,
            Engine=args.engine,
            SampleRate=args.sample_rate,
        )
        with open(out_file, "wb") as f:
            f.write(resp["AudioStream"].read())
        per_turn_files.append(out_file)

        # We don't get duration back from Polly, so estimate at ~12 chars/sec.
        # The concatenation step (below) computes accurate timings from the
        # actual audio if pydub is available.
        approx_ms = int((len(text) / 12) * 1000)
        timings.append({
            "turn": i,
            "speaker": turn.get("speaker"),
            "voice": voice,
            "text": text,
            "startMs": cumulative_ms,
            "endMs": cumulative_ms + approx_ms,
            "approx": True,
        })
        cumulative_ms += approx_ms + args.inter_turn_pause_ms

    # Concatenate
    print("🔗 Concatenating turns...")
    track_path = audio_dir / "track_001.mp3"
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
        print(f"   Per-turn files in: {audio_dir}")

    # Save timings as a sidecar JSON for QA / future skip-whisper optimization
    timings_path = audio_dir / "script.timed.json"
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
    total_chars, cost_usd = estimate_cost(script)
    print_plan(script, total_chars, cost_usd, args)

    if total_chars > args.max_chars:
        print(
            f"❌ Total characters ({total_chars}) exceeds the cap ({args.max_chars}).\n"
            f"   This is a safety guard. If you really want to proceed, re-run with\n"
            f"   --max-chars {total_chars + 100}.",
            file=sys.stderr,
        )
        return 1

    if not args.commit:
        print("--- DRY RUN — no AWS calls will be made ---")
        print()
        print(f"To actually synthesize, re-run with --commit (estimated cost: ${cost_usd:.4f}).")
        return 0

    if cost_usd > 1.00:
        print(f"⚠ Estimated cost is ${cost_usd:.2f} which exceeds $1.00.")
        confirm = input("Type 'YES' to proceed: ")
        if confirm != "YES":
            print("Aborted.")
            return 1

    print("🚀 Calling Polly...")
    synth_with_polly(script, out_dir, args)
    print()
    print("🎉 Synthesis complete.")
    print(f"   Next: ./sample_bundle_pipeline/3_make_qr_pack.sh {args.bundle_id} {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
