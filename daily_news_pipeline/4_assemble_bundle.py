#!/usr/bin/env python3
"""
Step 4: Assemble. Thin orchestrator over the langpack `bundler` package.

Flow: script.json → studypack (in-memory, studypack.adapters.news) + per-story
audio timings → bundler.materialize → work/<date>/bundle.json (iOS schema,
unchanged: 4 practice sets per story track, English glosses appended to
single-Korean-turn clip titles, transcript spans with translations).

Timings come from work/<date>/audio/voicebox.manifest.json (written by the
migrated step 3); for pre-migration dates the legacy story_N.timings.json
files are used instead — both carry identical data.

Usage:
    python 4_assemble_bundle.py [--date YYYY-MM-DD] [--author AUTHOR]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

from bundler import GroupAudio, materialize, timings_from_voicebox

import edition
from studypack.adapters import news as news_adapter

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

CLOUDFRONT_BASE = "https://d1ni0tk3ua6bwo.cloudfront.net"
PUBLISH_PREFIX_TEMPLATE = "lmaudio/{bundle_id}"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Assemble the day's iOS bundle.json")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    edition.add_edition_arg(p)
    p.add_argument("--author", default="Six Wands Studios")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def legacy_timings_audio(pack, audio_dir: Path) -> dict:
    """Fallback for pre-voicebox dates: build the audio map from the legacy
    per-story story_N.timings.json files."""
    audio = {}
    for unit in pack.units:
        story_id = unit.id.replace("-", "_")
        timings_path = audio_dir / f"{story_id}.timings.json"
        if not timings_path.exists():
            raise SystemExit(f"❌ timings not found: {timings_path}. Run step 3 first.")
        t = json.loads(timings_path.read_text(encoding="utf-8"))
        audio[(unit.id, "main")] = GroupAudio(
            timings=[(turn["startMs"], turn["endMs"]) for turn in t["turns"]],
            duration_ms=t["duration_ms"],
        )
    return audio


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    work_dir = WORK_ROOT / date
    sfx = edition.suffix(args.edition)
    script_path = work_dir / f"script{sfx}.json"
    audio_dir = work_dir / f"audio{sfx}"
    if not script_path.exists():
        raise SystemExit(f"❌ {script_path.name} not found at {script_path}. Run step 2 first.")

    script = json.loads(script_path.read_text(encoding="utf-8"))
    if script.get("edition", "ko") != args.edition:
        raise SystemExit(f"❌ {script_path.name} is edition {script.get('edition', 'ko')!r}, "
                         f"but --edition {args.edition} was requested.")
    try:
        pack, warnings = news_adapter.convert(script)
    except news_adapter.LegacyFormatError as e:
        raise SystemExit(f"❌ {e}")
    for w in warnings:
        print(f"  ⚠ studypack: {w}", file=sys.stderr)

    vb_manifest_path = audio_dir / "voicebox.manifest.json"
    if vb_manifest_path.exists():
        vb = json.loads(vb_manifest_path.read_text(encoding="utf-8"))
        audio = timings_from_voicebox(vb)
    else:
        audio = legacy_timings_audio(pack, audio_dir)

    pack_id = script["pack_id"]
    bundle = materialize(
        pack,
        audio=audio,
        prefix=PUBLISH_PREFIX_TEMPLATE.format(bundle_id=pack_id),
        public_base=CLOUDFRONT_BASE,
        pack_id=pack_id,
        author=args.author,
        gloss_titles=True,
        track_name=lambda unit, group, single: f"{unit.id.replace('-', '_')}.mp3",
        # legacy news convention: track.id == filename (iOS re-derives from url)
        track_id=lambda unit, group, filename, single: filename,
    )

    out_path = work_dir / f"bundle{sfx}.json"
    out_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
    n_tracks = len(bundle["packs"][0]["tracks"])
    n_clips = sum(len(ps["clips"]) for t in bundle["packs"][0]["tracks"]
                  for ps in t["practiceSets"])
    print(f"✅ Wrote {out_path}")
    print(f"   {n_tracks} tracks, {n_clips} total clips")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
