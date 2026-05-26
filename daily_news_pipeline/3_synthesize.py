#!/usr/bin/env python3
"""
Step 3 (provider-agnostic): Synthesize audio for each story track.

Reads work/<date>/script.json, picks a TTS provider per tts.yaml (or --tts), and
for each turn: computes the content-addressed audio_key, checks the library
cache, synthesizes if missed. Concatenates turns into one mp3 per story and
writes per-turn timings JSON.

Output:
    work/<date>/audio/<story_id>.mp3
    work/<date>/audio/<story_id>.timings.json
    work/<date>/costs/3_synthesize.json
    cache/audio/<audio_key>.mp3 (+ sidecar JSON) for each newly-synthesized turn

Safety: defaults to dry-run.

Usage:
    python 3_synthesize.py [--date YYYY-MM-DD] [--tts polly|elevenlabs] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

import yaml

from cache_lib import Library, compute_audio_key
from cost_tracker import StepCostRecorder
from tts_providers import TTSProvider, make_provider


HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"
CACHE_ROOT = HERE / "cache"
DEFAULT_TTS_CONFIG = HERE / "tts.yaml"

DEFAULT_MAX_CHARS = 20_000
CONFIRM_CHAR_THRESHOLD = 15_000

_run_totals = {"chars": 0, "turns": 0, "cache_hits": 0, "cache_misses": 0}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Synthesize per-story audio")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--config", type=Path, default=DEFAULT_TTS_CONFIG, help="tts.yaml path")
    p.add_argument("--tts", help="Override provider from tts.yaml (polly | elevenlabs)")
    p.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS)
    p.add_argument("--commit", action="store_true", help="Actually call the TTS provider.")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def synth_story(provider: TTSProvider, story: dict, out_dir: Path, pause_ms: int,
                library: Library, recorder: StepCostRecorder) -> dict:
    """Synthesize one story's turns; concat; write track + timings. Returns timings."""
    from pydub import AudioSegment

    story_id = story["story_id"]
    turns_dir = out_dir / "turns" / story_id
    turns_dir.mkdir(parents=True, exist_ok=True)

    per_turn_files: list[Path] = []
    for i, turn in enumerate(story["turns"]):
        speaker = turn["speaker"]
        text = turn["text"]

        # Library cache lookup (content-addressed across all prior runs).
        # This is the SOLE source of truth for "have we synthesized this turn?"
        # — work-dir mp3s are not trusted across runs because the script content
        # or provider may have changed.
        voice_info = provider.voice_for_speaker(speaker)
        audio_key = compute_audio_key(
            text=text,
            provider=provider.name,
            voice_id=voice_info.voice_id,
            model=provider.model,
            settings=provider.settings_for_audio_key(),
        )
        # Filename includes the audio_key prefix so stale per-turn files from
        # earlier scripts/providers don't collide with the current run.
        out_file = turns_dir / f"turn_{i:03d}_{audio_key[:8]}.mp3"
        role = turn.get("role", "unique")
        library_text_key = turn.get("library_text_key")

        cached = library.get_cached_audio(audio_key)
        if cached:
            shutil.copy2(cached, out_file)
            _run_totals["cache_hits"] += 1
            recorder.add_tts_call(
                provider=provider.name, tier_or_engine=provider.tier_or_engine,
                voice_id=voice_info.voice_id, voice_label=voice_info.voice_label,
                model=provider.model, lang=turn["lang"], text=text,
                audio_key=audio_key, cache_hit=True,
            )
            print(f"     ⚡ turn {i:03d} library HIT  key={audio_key[:8]}  text=\"{text[:50]}{'…' if len(text) > 50 else ''}\"")
            per_turn_files.append(out_file)
            continue

        # Miss — synthesize
        print(f"     ▶ turn {i:03d}/{len(story['turns']) - 1:03d}  speaker={speaker}  voice={voice_info.voice_id} ({voice_info.voice_label})  lang={turn['lang']}  chars={len(text)}  key={audio_key[:8]}")
        print(f"        text: \"{text[:80]}{'…' if len(text) > 80 else ''}\"")
        provider.synth_to_file(text=text, speaker=speaker, lang=turn["lang"], out_path=out_file)

        cost = recorder.add_tts_call(
            provider=provider.name, tier_or_engine=provider.tier_or_engine,
            voice_id=voice_info.voice_id, voice_label=voice_info.voice_label,
            model=provider.model, lang=turn["lang"], text=text,
            audio_key=audio_key, cache_hit=False,
        )

        sidecar_metadata = {
            "text": text,
            "lang": turn["lang"],
            "provider": provider.name,
            "tier_or_engine": provider.tier_or_engine,
            "model": provider.model,
            "voice_id": voice_info.voice_id,
            "voice_label": voice_info.voice_label,
            "settings": provider.settings_for_audio_key(),
            "chars_debited": len(text),
            "estimated_cost_usd": round(cost, 6),
            "library_role": role,
            "library_text_key": library_text_key,
        }
        library.put_audio(audio_key, out_file, sidecar_metadata)

        if role in ("vocab_word", "vocab_gloss") and library_text_key:
            library.attach_vocab_audio(library_text_key, "ko" if role == "vocab_word" else "en", audio_key)
        elif role in ("example_ko", "example_en") and library_text_key:
            library.attach_example_audio(library_text_key, "ko" if role == "example_ko" else "en", audio_key)

        _run_totals["chars"] += len(text)
        _run_totals["turns"] += 1
        _run_totals["cache_misses"] += 1
        print(f"        ✓ wrote {out_file}  ({out_file.stat().st_size} bytes)  cached as {audio_key[:8]}")
        print(f"        ↳ running total: {_run_totals['turns']} turns synthesized, {_run_totals['chars']} chars debited")
        per_turn_files.append(out_file)

    # Concatenate
    combined = AudioSegment.empty()
    turn_timings: list[dict] = []
    cursor_ms = 0
    for i, f in enumerate(per_turn_files):
        seg = AudioSegment.from_file(f, format="mp3")
        start = cursor_ms
        combined += seg
        cursor_ms += len(seg)
        end = cursor_ms
        turn = story["turns"][i]
        turn_timings.append({
            "turn": i, "speaker": turn["speaker"], "lang": turn["lang"],
            "text": turn["text"], "role": turn.get("role", "unique"),
            "startMs": start, "endMs": end,
        })
        if i < len(per_turn_files) - 1:
            combined += AudioSegment.silent(duration=pause_ms)
            cursor_ms += pause_ms

    track_path = out_dir / f"{story_id}.mp3"
    combined.export(track_path, format="mp3", bitrate="128k")
    print(f"     ✓ wrote concatenated track: {track_path}  ({track_path.stat().st_size} bytes, {cursor_ms} ms)")

    timings = {
        "story_id": story_id, "duration_ms": cursor_ms,
        "inter_turn_pause_ms": pause_ms, "turns": turn_timings,
    }
    timings_path = out_dir / f"{story_id}.timings.json"
    timings_path.write_text(json.dumps(timings, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return timings


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    script_path = WORK_ROOT / date / "script.json"
    if not script_path.exists():
        raise SystemExit(f"❌ script.json not found at {script_path}. Run step 2 first.")
    script = json.loads(script_path.read_text(encoding="utf-8"))

    if not args.config.exists():
        raise SystemExit(f"❌ tts config not found: {args.config}")
    tts_cfg = yaml.safe_load(args.config.read_text(encoding="utf-8")) or {}
    provider_name = args.tts or tts_cfg.get("provider")
    if not provider_name:
        raise SystemExit("❌ No TTS provider configured. Set `provider:` in tts.yaml or pass --tts.")

    out_dir = WORK_ROOT / date / "audio"
    out_dir.mkdir(parents=True, exist_ok=True)
    pause_ms = int(tts_cfg.get("inter_turn_pause_ms", 400))
    total_chars = sum(len(turn["text"]) for story in script["stories"] for turn in story["turns"])

    print(f"═══ Synthesizing audio for {date} ═══")
    print(f"  Provider:      {provider_name}{' (from --tts)' if args.tts else ' (from tts.yaml)'}")
    print(f"  Stories:       {len(script['stories'])}")
    print(f"  Total turns:   {sum(len(s['turns']) for s in script['stories'])}")
    print(f"  Total chars:   {total_chars}")
    print(f"  Max chars cap: {args.max_chars}")
    print(f"  Output:        {out_dir}")
    print()

    if total_chars > args.max_chars:
        print(f"❌ Total chars {total_chars} exceeds cap {args.max_chars}.", file=sys.stderr)
        return 1

    if not args.commit:
        print("--- DRY RUN — no TTS calls will be made ---")
        print(f"Re-run with --commit to synthesize.")
        return 0

    if total_chars > CONFIRM_CHAR_THRESHOLD:
        print(f"⚠ This run will process {total_chars} chars (above {CONFIRM_CHAR_THRESHOLD}).")
        confirm = input("Type 'YES' to proceed: ")
        if confirm != "YES":
            print("Aborted.")
            return 1

    provider = make_provider(provider_name, tts_cfg)
    print(f"✓ Provider ready: {provider.name} ({provider.tier_or_engine}, model={provider.model})")
    print(f"  Voice A: {provider.voice_for_speaker('A').voice_id} ({provider.voice_for_speaker('A').voice_label})")
    print(f"  Voice B: {provider.voice_for_speaker('B').voice_id} ({provider.voice_for_speaker('B').voice_label})")
    print()

    library = Library.load(CACHE_ROOT)
    pre_stats = library.stats_summary()
    print(f"📚 Library: {pre_stats['audio_files_on_disk']} cached audio files at {CACHE_ROOT}")
    print()

    recorder = StepCostRecorder("3_synthesize", WORK_ROOT / date)

    for story in script["stories"]:
        print()
        print(f"━━━ {story['story_id']}: {story['track_title_ko']}")
        synth_story(provider, story, out_dir, pause_ms, library, recorder)

    library.save()
    recorder.write()
    post_stats = library.stats_summary()
    new_audio = post_stats["audio_files_on_disk"] - pre_stats["audio_files_on_disk"]
    total_turns = _run_totals["cache_hits"] + _run_totals["cache_misses"]
    hit_rate = (_run_totals["cache_hits"] / total_turns * 100) if total_turns else 0
    totals = recorder.totals()

    print()
    print(f"🎉 Synthesized {len(script['stories'])} tracks via {provider.name}.")
    print(f"   {provider.name} debit:   {_run_totals['chars']} chars across {_run_totals['cache_misses']} freshly-synthesized turns  est_cost=${totals['tts_cost_usd']:.4f}")
    print(f"   📚 Library cache:  {_run_totals['cache_hits']} hits / {total_turns} total turns  ({hit_rate:.1f}% hit rate)")
    print(f"   📚 Library grew:   +{new_audio} new audio files (total now {post_stats['audio_files_on_disk']})")
    print(f"   Cost report:       {recorder.work_dir}/costs/{recorder.step}.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
