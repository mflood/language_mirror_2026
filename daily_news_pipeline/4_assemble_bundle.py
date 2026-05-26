#!/usr/bin/env python3
"""
Step 4: Assemble the iOS-compatible bundle.json from script.json + per-story
timings. Converts turn-range clip definitions into ms-range Clip objects,
attaches translation transcripts to each Korean clip (so the app shows the
English gloss when the Korean clip plays), and writes the final bundle to
work/<date>/bundle.json.

The bundle is structured to match the BundleManifest the iOS app expects
(see bundle_pipeline/models.py).

Output:
    work/<date>/bundle.json

Usage:
    python 4_assemble_bundle.py [--date YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

# Matches the existing bundle pipeline's S3 publish config.
CLOUDFRONT_BASE = "https://d1ni0tk3ua6bwo.cloudfront.net"
PUBLISH_PREFIX_TEMPLATE = "/lmaudio/{bundle_id}"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Assemble the day's bundle.json")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--author", default="Six Wands Studios")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def turn_range_to_ms(turn_range: list[int], turn_timings: list[dict]) -> tuple[int, int]:
    """Convert (turn_start_idx, turn_end_idx) inclusive → (startMs, endMs)."""
    a, b = turn_range
    return turn_timings[a]["startMs"], turn_timings[b]["endMs"]


def join_turns_text(turn_range: list[int], turn_timings: list[dict], lang_filter: str | None = None) -> str:
    """Join the text of turns in range, optionally filtered by lang."""
    a, b = turn_range
    out = []
    for i in range(a, b + 1):
        t = turn_timings[i]
        if lang_filter is not None and t["lang"] != lang_filter:
            continue
        out.append(t["text"])
    return " ".join(out)


def english_gloss_for_korean_clip(turn_range: list[int], turn_timings: list[dict], story: dict) -> str | None:
    """
    For a Korean-only clip in Set 2 (single Korean turn), find the matching
    English translation by looking up the corresponding entry in vocab/examples
    /expressions/summary_ko by text match.
    """
    a, b = turn_range
    if a != b:
        return None  # multi-turn clips don't get an inline gloss
    ko_text = turn_timings[a]["text"]

    for v in story.get("vocab", []):
        if v["ko"] == ko_text:
            return v["en"]
    for ex in story.get("examples", []):
        if ex["ko"] == ko_text:
            return ex["en"]
    for ex in story.get("expressions", []):
        if ex["ko"] == ko_text:
            return ex["en"]
    summary_ko_easy = story.get("summary_ko_easy", []) or []
    summary_ko_natural = story.get("summary_ko_natural", []) or []
    summary_en = story.get("summary_en", []) or []
    # Match against easy summary first (1:1 with English where lengths agree)
    for i, sentence in enumerate(summary_ko_easy):
        if sentence == ko_text and i < len(summary_en):
            return summary_en[i]
    # Match against natural summary (3 sentences, 1:1 with English)
    for i, sentence in enumerate(summary_ko_natural):
        if sentence == ko_text and i < len(summary_en):
            return summary_en[i]
    return None


def build_clip(turn_range: list[int], clip_def: dict, turn_timings: list[dict], story: dict) -> dict:
    start_ms, end_ms = turn_range_to_ms(turn_range, turn_timings)
    language_code = clip_def.get("languageCode")
    title = clip_def.get("title")
    clip = {
        "id": str(uuid.uuid4()),
        "startMs": start_ms,
        "endMs": end_ms,
        "kind": "drill",
        "title": title,
        "repeats": None,
        "startSpeed": None,
        "endSpeed": None,
        "languageCode": language_code,
    }
    # If single-Korean-turn clip, attach English gloss into the title so the
    # app's transcript field shows it. The Track.transcripts list (built below)
    # covers the structural transcript; the per-clip title carries the gloss.
    if language_code == "ko-KR" and turn_range[0] == turn_range[1]:
        gloss = english_gloss_for_korean_clip(turn_range, turn_timings, story)
        if gloss and title:
            clip["title"] = f"{title} — {gloss}"
    return clip


def build_track(story: dict, timings: dict, pack_id: str) -> dict:
    turn_timings = timings["turns"]
    duration_ms = timings["duration_ms"]
    track_id_placeholder = str(uuid.uuid4())  # iOS import re-derives stable id from url

    # Practice sets
    practice_sets_out: list[dict] = []
    for ps_def in story["practice_sets"]:
        clips = [
            build_clip(c["turn_range"], c, turn_timings, story)
            for c in ps_def["clips"]
        ]
        practice_sets_out.append({
            "id": str(uuid.uuid4()),
            "trackId": track_id_placeholder,
            "displayOrder": ps_def["displayOrder"],
            "title": ps_def["title"],
            "clips": clips,
            "isFavorite": False,
        })

    # Transcripts — one span per turn with bilingual gloss for parallel display
    transcripts: list[dict] = []
    for t in turn_timings:
        transcripts.append({
            "startMs": t["startMs"],
            "endMs": t["endMs"],
            "text": t["text"],
            "speaker": t["speaker"],
            "languageCode": "ko-KR" if t["lang"] == "ko" else "en-US",
        })

    filename = f"{story['story_id']}.mp3"
    url = f"{CLOUDFRONT_BASE}{PUBLISH_PREFIX_TEMPLATE.format(bundle_id=pack_id)}/{filename}"

    return {
        "id": filename,
        "title": story["track_title_ko"],
        "url": url,
        "filename": filename,
        "durationMs": duration_ms,
        "languageCode": "ko-KR",
        "practiceSets": practice_sets_out,
        "transcripts": transcripts,
    }


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
    pack_id = script["pack_id"]

    tracks: list[dict] = []
    for story in script["stories"]:
        timings_path = audio_dir / f"{story['story_id']}.timings.json"
        if not timings_path.exists():
            print(f"❌ Missing timings for {story['story_id']}: {timings_path}", file=sys.stderr)
            return 1
        timings = json.loads(timings_path.read_text(encoding="utf-8"))
        tracks.append(build_track(story, timings, pack_id))

    pack = {
        "id": pack_id,
        "title": script["pack_title_ko"],
        "author": args.author,
        "coverUrl": None,
        "coverFilename": None,
        "tracks": tracks,
    }
    manifest = {
        "id": pack_id,
        "title": script["pack_title_ko"],
        "packs": [pack],
    }

    out_path = WORK_ROOT / date / "bundle.json"
    out_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Wrote {out_path}")
    print(f"   {len(tracks)} tracks, {sum(len(ps['clips']) for t in tracks for ps in t['practiceSets'])} total clips")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
