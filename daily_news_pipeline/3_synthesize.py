#!/usr/bin/env python3
"""
Step 3: Synthesize. Thin orchestrator over the langpack `voicebox` package.

Flow: script.json → studypack (in-memory, studypack.adapters.news) →
voicebox.synth_pack (shared content-addressed cache at ~/.langpack/cache/audio,
configured via tts.yaml `cache_dir`) → outputs mapped into the legacy layout so
steps 4-6 and verify_whisper are unchanged:

    work/<date>/audio/<story_id>.mp3               (concatenated track)
    work/<date>/audio/<story_id>.timings.json      (legacy schema, 1:1 turns)
    work/<date>/audio/turns/<story_id>/turn_NNN_<key8>.mp3
    work/<date>/audio/voicebox.manifest.json       (new: raw voicebox manifest)
    work/<date>/costs/3_synthesize.json            (StepCostRecorder format)

Pipeline-only concerns stay here: vocab/example library attachment
(cache_lib.Library — library.json), the --max-chars spend gate, and cost
recording. TTS providers, cache keys, and concat now live in voicebox.

Safety: defaults to dry-run (prints hits/misses + estimated spend, writes
nothing). The spend gate applies to chars that would actually be debited
(cache misses), not total chars.

Usage:
    python 3_synthesize.py [--date YYYY-MM-DD] [--tts polly|elevenlabs]
                           [--max-chars N] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

import yaml

from studypack.adapters import news as news_adapter
from voicebox import key_params, synth_pack

from cache_lib import Library
from cost_tracker import StepCostRecorder

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"
CACHE_ROOT = HERE / "cache"
DEFAULT_TTS_CONFIG = HERE / "tts.yaml"

DEFAULT_MAX_CHARS = 20_000
CONFIRM_CHAR_THRESHOLD = 15_000


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Synthesize per-story audio (via voicebox)")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--config", type=Path, default=DEFAULT_TTS_CONFIG, help="tts.yaml path")
    p.add_argument("--tts", help="Override provider from tts.yaml (polly | elevenlabs)")
    p.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS,
                   help="Abort if freshly-debited (cache-miss) chars would exceed this.")
    p.add_argument("--commit", action="store_true", help="Actually call the TTS provider.")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def write_legacy_outputs(manifest: dict, script: dict, vb_dir: Path, out_dir: Path,
                         pause_ms: int, library: Library,
                         recorder: StepCostRecorder, kp) -> None:
    """Map voicebox outputs into the legacy audio/ layout, write timings.json,
    attach library audio keys, and record per-turn costs."""
    stories_by_id = {s["story_id"]: s for s in script["stories"]}

    for group in manifest["groups"]:
        story_id = group["unit_id"].replace("-", "_")
        story = stories_by_id[story_id]
        script_turns = story["turns"]
        spans = group["spans"]
        if len(script_turns) != len(spans):
            raise SystemExit(f"❌ {story_id}: {len(script_turns)} script turns vs "
                             f"{len(spans)} synthesized spans — aborting")

        # Per-turn files in legacy naming
        turns_dir = out_dir / "turns" / story_id
        turns_dir.mkdir(parents=True, exist_ok=True)
        hits = 0
        for turn, span in zip(script_turns, spans):
            if turn["text"] != span["text"]:
                raise SystemExit(f"❌ {story_id} turn {span['index']}: text mismatch "
                                 f"between script and synthesized span — aborting")
            src = vb_dir / span["file"]
            dest = turns_dir / f"turn_{span['index']:03d}_{span['audio_key'][:8]}.mp3"
            shutil.copy2(src, dest)
            hits += span["from_cache"]

            # Library attachment (vocab/example audio variants) — unchanged
            role = turn.get("role", "unique")
            text_key = turn.get("library_text_key")
            if role in ("vocab_word", "vocab_gloss") and text_key:
                library.attach_vocab_audio(
                    text_key, "ko" if role == "vocab_word" else "en", span["audio_key"])
            elif role in ("example_ko", "example_en") and text_key:
                library.attach_example_audio(
                    text_key, "ko" if role == "example_ko" else "en", span["audio_key"])

            voice = kp.voices[span["speaker"]]
            recorder.add_tts_call(
                provider=manifest["provider"], tier_or_engine=manifest["tier_or_engine"],
                voice_id=voice.voice_id, voice_label=voice.voice_label,
                model=manifest["model"], lang=turn["lang"], text=turn["text"],
                audio_key=span["audio_key"], cache_hit=bool(span["from_cache"]),
            )

        # Concatenated track
        shutil.copy2(vb_dir / group["track_file"], out_dir / f"{story_id}.mp3")

        # Legacy timings.json — speaker/lang/text/role from the SCRIPT turn,
        # timing from the voicebox span (indices proven aligned above).
        timings = {
            "story_id": story_id,
            "duration_ms": group["duration_ms"],
            "inter_turn_pause_ms": pause_ms,
            "turns": [
                {
                    "turn": span["index"],
                    "speaker": turn["speaker"],
                    "lang": turn["lang"],
                    "text": turn["text"],
                    "role": turn.get("role", "unique"),
                    "startMs": span["startMs"],
                    "endMs": span["endMs"],
                }
                for turn, span in zip(script_turns, spans)
            ],
        }
        (out_dir / f"{story_id}.timings.json").write_text(
            json.dumps(timings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        print(f"   ✓ {story_id}: {len(spans)} turns ({hits} cached), "
              f"track {group['duration_ms']} ms")


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    script_path = WORK_ROOT / date / "script.json"
    if not script_path.exists():
        raise SystemExit(f"❌ script.json not found at {script_path}. Run step 2 first.")
    script = json.loads(script_path.read_text(encoding="utf-8"))

    if not args.config.exists():
        raise SystemExit(f"❌ tts config not found: {args.config}")
    cfg = yaml.safe_load(args.config.read_text(encoding="utf-8")) or {}
    if args.tts:
        cfg["provider"] = args.tts
    provider_name = cfg.get("provider")
    if not provider_name:
        raise SystemExit("❌ No TTS provider configured. Set `provider:` in tts.yaml or pass --tts.")

    try:
        pack, warnings = news_adapter.convert(script)
    except news_adapter.LegacyFormatError as e:
        raise SystemExit(f"❌ {e}")
    for w in warnings:
        print(f"  ⚠ studypack: {w}", file=sys.stderr)

    out_dir = WORK_ROOT / date / "audio"
    pause_ms = int(cfg.get("inter_turn_pause_ms", 400))

    # Dry pass (no writes, no provider): plan + spend gate on MISS chars.
    plan = synth_pack(pack, cfg, out_dir / "vb", commit=False)
    t = plan["costs"]

    print(f"═══ Synthesizing audio for {date} (via voicebox) ═══")
    print(f"  Provider:      {plan['provider']}/{plan['model']}"
          f"{' (from --tts)' if args.tts else ' (from tts.yaml)'}")
    print(f"  Cache:         {plan['cache_dir']}")
    print(f"  Stories:       {len(script['stories'])}")
    print(f"  Total turns:   {t['calls']}  (cache hits {t['cache_hits']}, "
          f"to synthesize {t['synthesized']})")
    print(f"  Chars to debit: {t['chars_debited']}  (cap {args.max_chars})")
    print(f"  Estimated cost: ${t['estimated_cost_usd']:.4f}")
    print(f"  Output:        {out_dir}")
    print()

    if t["chars_debited"] > args.max_chars:
        print(f"❌ Chars to debit {t['chars_debited']} exceeds cap {args.max_chars}.",
              file=sys.stderr)
        return 1

    if not args.commit:
        print("--- DRY RUN — no TTS calls will be made ---")
        print("Re-run with --commit to synthesize.")
        return 0

    if t["chars_debited"] > CONFIRM_CHAR_THRESHOLD:
        print(f"⚠ This run will debit {t['chars_debited']} chars "
              f"(above {CONFIRM_CHAR_THRESHOLD}).")
        confirm = input("Type 'YES' to proceed: ")
        if confirm != "YES":
            print("Aborted.")
            return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    vb_dir = out_dir / "vb"

    library = Library.load(CACHE_ROOT)
    pre_stats = library.stats_summary()
    recorder = StepCostRecorder("3_synthesize", WORK_ROOT / date)
    kp = key_params(plan["provider"], cfg)

    manifest = synth_pack(pack, cfg, vb_dir, commit=True, concat=True)

    print()
    write_legacy_outputs(manifest, script, vb_dir, out_dir, pause_ms,
                         library, recorder, kp)

    # Keep the raw manifest, drop the voicebox-layout staging dir.
    shutil.copy2(vb_dir / "voicebox.manifest.json", out_dir / "voicebox.manifest.json")
    shutil.rmtree(vb_dir)

    library.save()
    recorder.write()
    totals = recorder.totals()
    ct = manifest["costs"]
    hit_rate = (ct["cache_hits"] / ct["calls"] * 100) if ct["calls"] else 0

    print()
    print(f"🎉 Synthesized {len(script['stories'])} tracks via {manifest['provider']}.")
    print(f"   {manifest['provider']} debit:   {ct['chars_debited']} chars across "
          f"{ct['synthesized']} freshly-synthesized turns  "
          f"est_cost=${totals['tts_cost_usd']:.4f}")
    print(f"   📦 Shared cache:  {ct['cache_hits']} hits / {ct['calls']} total turns  "
          f"({hit_rate:.1f}% hit rate)  at {manifest['cache_dir']}")
    print(f"   📚 Library:       vocab/example audio keys attached "
          f"(library.json entries: {pre_stats['vocab_terms']} vocab, "
          f"{pre_stats['example_sentences']} examples)")
    print(f"   Cost report:      {recorder.work_dir}/costs/{recorder.step}.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
