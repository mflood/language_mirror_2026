#!/usr/bin/env python3
"""
Diagnostic: transcribe each per-turn mp3 with local Whisper, compare to the
original script text, and produce a mismatch report. Does NOT re-synthesize.

The synth script writes one mp3 per turn under work/<date>/audio/turns/<story>/
turn_NNN.mp3 — those are the input. We compare Whisper's transcription against
script.json's turn text and flag turns where similarity drops below the
threshold.

Korean and English use different similarity thresholds since Whisper tends to
miss/insert punctuation more aggressively in Korean.

Output:
    work/<date>/verify_report.md
    work/<date>/verify_report.json

Usage:
    python verify_whisper.py [--date YYYY-MM-DD] [--model large-v3]
                              [--threshold-ko 0.75] [--threshold-en 0.85]
                              [--only-story story_1]
"""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import json
import re
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

DEFAULT_WHISPER_MODEL = "large-v3"
DEFAULT_KO_THRESHOLD = 0.75   # below this, flag as mismatch
DEFAULT_EN_THRESHOLD = 0.85


# Whisper output and our script text differ in trivial ways (punctuation,
# spacing, casing). Normalize both before comparing so the similarity score
# reflects actual content mismatches.
_PUNCT_RE = re.compile(r"[、。，．！？!?,.…\"'\"\"`·:;()\[\]\{\}\-—–_/]")
_WS_RE = re.compile(r"\s+")


def normalize(text: str) -> str:
    text = text.lower()
    text = _PUNCT_RE.sub("", text)
    text = _WS_RE.sub(" ", text)
    return text.strip()


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, normalize(a), normalize(b)).ratio()


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Whisper-vs-script mismatch report")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--model", default=DEFAULT_WHISPER_MODEL, help=f"Whisper model id (default: {DEFAULT_WHISPER_MODEL})")
    p.add_argument("--threshold-ko", type=float, default=DEFAULT_KO_THRESHOLD)
    p.add_argument("--threshold-en", type=float, default=DEFAULT_EN_THRESHOLD)
    p.add_argument("--only-story", help="Restrict to a single story_id (e.g. story_1)")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def transcribe_turn(model, mp3_path: Path, language: str) -> str:
    result = model.transcribe(
        str(mp3_path),
        language=language,
        fp16=False,
        verbose=False,
    )
    return (result.get("text") or "").strip()


def render_markdown(payload: dict) -> str:
    out: list[str] = []
    out.append(f"# Whisper verification report — {payload['date']}\n")
    out.append(f"- Model: `{payload['model']}`\n")
    out.append(f"- KO threshold: {payload['threshold_ko']}, EN threshold: {payload['threshold_en']}\n")
    out.append(f"- Total turns checked: {payload['stats']['total']}\n")
    out.append(f"- Mismatches flagged: **{payload['stats']['mismatches']}** ({payload['stats']['mismatch_pct']:.1f}%)\n")
    out.append(f"  - Korean turns flagged: {payload['stats']['ko_mismatches']} / {payload['stats']['ko_total']}\n")
    out.append(f"  - English turns flagged: {payload['stats']['en_mismatches']} / {payload['stats']['en_total']}\n")
    out.append("\n")
    for story in payload["stories"]:
        out.append(f"## {story['story_id']}: {story['title']}\n")
        if not story["mismatches"]:
            out.append("_(no mismatches)_\n\n")
            continue
        out.append(f"\n{len(story['mismatches'])} flagged turn(s):\n\n")
        for m in story["mismatches"]:
            out.append(f"### turn {m['turn']:03d}  [{m['lang']}] similarity={m['similarity']:.2f}\n")
            out.append(f"- **expected**:  `{m['expected']}`\n")
            out.append(f"- **whisper**:   `{m['whisper']}`\n")
            out.append("\n")
    return "".join(out)


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    script_path = WORK_ROOT / date / "script.json"
    audio_dir = WORK_ROOT / date / "audio"
    if not script_path.exists():
        raise SystemExit(f"❌ script.json not found at {script_path}. Run step 2 first.")
    if not audio_dir.exists():
        raise SystemExit(f"❌ audio dir not found at {audio_dir}. Run step 3 first.")

    script = json.loads(script_path.read_text(encoding="utf-8"))

    try:
        import whisper
    except ImportError:
        raise SystemExit("openai-whisper not installed. pip install openai-whisper")

    print(f"═══ Whisper verification for {date} ═══")
    print(f"  Model: {args.model}")
    print(f"  KO threshold: {args.threshold_ko}  EN threshold: {args.threshold_en}")
    if args.only_story:
        print(f"  Scope: {args.only_story} only")
    print()
    print(f"⏳ Loading Whisper model '{args.model}' (one-time)...")
    model = whisper.load_model(args.model)
    print(f"   ✓ model ready")
    print()

    stats = {
        "total": 0, "mismatches": 0,
        "ko_total": 0, "ko_mismatches": 0,
        "en_total": 0, "en_mismatches": 0,
    }
    stories_out: list[dict] = []

    for story in script["stories"]:
        if args.only_story and story["story_id"] != args.only_story:
            continue
        print(f"━━━ {story['story_id']}: {story['track_title_ko']}")
        story_mismatches: list[dict] = []
        turns_dir = audio_dir / "turns" / story["story_id"]
        if not turns_dir.exists():
            print(f"  ⚠ no turns/ subdir at {turns_dir} — skipping")
            continue

        for i, turn in enumerate(story["turns"]):
            mp3 = turns_dir / f"turn_{i:03d}.mp3"
            if not mp3.exists():
                print(f"  ⚠ missing {mp3.name}")
                continue
            lang = turn["lang"]
            expected = turn["text"]
            threshold = args.threshold_ko if lang == "ko" else args.threshold_en
            whisper_lang = "ko" if lang == "ko" else "en"

            transcribed = transcribe_turn(model, mp3, whisper_lang)
            sim = similarity(expected, transcribed)
            stats["total"] += 1
            if lang == "ko":
                stats["ko_total"] += 1
            else:
                stats["en_total"] += 1

            flag = sim < threshold
            mark = "✗" if flag else "✓"
            print(f"  {mark} turn {i:03d} [{lang}] sim={sim:.2f}  expected='{expected[:50]}...' whisper='{transcribed[:50]}...'")
            if flag:
                stats["mismatches"] += 1
                if lang == "ko":
                    stats["ko_mismatches"] += 1
                else:
                    stats["en_mismatches"] += 1
                story_mismatches.append({
                    "turn": i,
                    "lang": lang,
                    "speaker": turn["speaker"],
                    "similarity": round(sim, 3),
                    "expected": expected,
                    "whisper": transcribed,
                })

        stories_out.append({
            "story_id": story["story_id"],
            "title": story["track_title_ko"],
            "mismatches": story_mismatches,
        })

    stats["mismatch_pct"] = (stats["mismatches"] / stats["total"] * 100) if stats["total"] else 0.0

    payload: dict[str, Any] = {
        "date": date,
        "model": args.model,
        "threshold_ko": args.threshold_ko,
        "threshold_en": args.threshold_en,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "stats": stats,
        "stories": stories_out,
    }

    json_path = WORK_ROOT / date / "verify_report.json"
    md_path = WORK_ROOT / date / "verify_report.md"
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(render_markdown(payload), encoding="utf-8")

    print()
    print(f"✅ Verification complete.")
    print(f"   Total turns:    {stats['total']}")
    print(f"   Mismatches:     {stats['mismatches']} ({stats['mismatch_pct']:.1f}%)")
    print(f"     · Korean:      {stats['ko_mismatches']}/{stats['ko_total']}")
    print(f"     · English:     {stats['en_mismatches']}/{stats['en_total']}")
    print(f"   Report (md):    {md_path}")
    print(f"   Report (json):  {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
