#!/usr/bin/env python3
"""
Assemble a Language Mirror bundle.json directly from a synthesized
conversation script — no Whisper, no S3.

Unlike step 3 (make_qr_pack.sh), which re-transcribes the audio and publishes
to S3, this reads the GROUND-TRUTH text + per-turn timings we already have
(script.json + audio/script.timed.json) and the Korean translations attached
to script.json, producing a bundle ready for step 4 (embed_in_app).

  samples/<id>/script.json         turns: text, speaker, translations{ko:…}
  samples/<id>/audio/script.timed.json  per-turn startMs/endMs
        ↓
  work/<id>/bundle.json  +  work/<id>/audio/track_001.mp3

Two practice sets, matching the embedded-starter convention:
  - "Full Track"   — one clip spanning the whole track
  - "Practice Set" — one drill clip per turn ("N. <sentence>")

Usage:
    python assemble_conversation_bundle.py --bundle-id starter_english_greetings \\
        --title "Everyday Greetings" --language en-US --author "Six Wands Studios"
"""

from __future__ import annotations

import argparse
import json
import shutil
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
SAMPLES = HERE / "samples"
WORK_ROOT = HERE.parent / "work"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Assemble a bundle.json from a synthesized script")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--title", required=True, help="Display pack title")
    p.add_argument("--language", default="en-US", help="BCP-47 audio language (default en-US)")
    p.add_argument("--author", default="Six Wands Studios")
    p.add_argument("--track-title", default="Track 001")
    return p.parse_args()


def uid() -> str:
    return str(uuid.uuid4())


def main() -> int:
    args = parse_args()
    sdir = SAMPLES / args.bundle_id
    script = json.loads((sdir / "script.json").read_text(encoding="utf-8"))
    timed = json.loads((sdir / "audio" / "script.timed.json").read_text(encoding="utf-8"))
    timed_turns = timed["turns"] if isinstance(timed, dict) else timed
    turns = script["turns"]
    if len(turns) != len(timed_turns):
        raise SystemExit(f"turn count mismatch: script={len(turns)} timed={len(timed_turns)}")

    speaker_label = {"A": "Speaker 1", "B": "Speaker 2", "C": "Speaker 3"}
    duration_ms = max(int(t["endMs"]) for t in timed_turns)

    transcripts = []
    practice_clips = []
    for i, (turn, tt) in enumerate(zip(turns, timed_turns)):
        start, end = int(tt["startMs"]), int(tt["endMs"])
        text = turn["text"]
        span = {
            "startMs": start, "endMs": end, "text": text,
            "speaker": speaker_label.get(turn.get("speaker", "A"), "Speaker 1"),
            "languageCode": args.language,
        }
        if turn.get("translations"):
            span["translations"] = turn["translations"]
        transcripts.append(span)
        practice_clips.append({
            "id": uid(), "startMs": start, "endMs": end, "kind": "drill",
            "title": f"{i + 1}. {text}", "repeats": None,
            "startSpeed": None, "endSpeed": None, "languageCode": args.language,
        })

    track_id = "track_001.mp3"
    track = {
        "id": track_id, "title": args.track_title, "url": None,
        "filename": track_id, "durationMs": duration_ms, "languageCode": args.language,
        "practiceSets": [
            {"id": uid(), "trackId": track_id, "displayOrder": 0, "title": "Full Track",
             "isFavorite": False,
             "clips": [{"id": uid(), "startMs": 0, "endMs": duration_ms, "kind": "drill",
                        "title": "Full Track", "repeats": None, "startSpeed": None,
                        "endSpeed": None, "languageCode": None}]},
            {"id": uid(), "trackId": track_id, "displayOrder": 1, "title": "Practice Set",
             "isFavorite": False, "clips": practice_clips},
        ],
        "transcripts": transcripts,
    }
    bundle = {
        "id": args.bundle_id, "title": args.title,
        "packs": [{
            "id": args.bundle_id, "title": args.title, "author": args.author,
            "coverUrl": None, "coverFilename": None, "languageCode": args.language,
            "tracks": [track],
        }],
    }

    out_dir = WORK_ROOT / args.bundle_id
    (out_dir / "audio").mkdir(parents=True, exist_ok=True)
    (out_dir / "bundle.json").write_text(
        json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    shutil.copy2(sdir / "audio" / "track_001.mp3", out_dir / "audio" / "track_001.mp3")

    n_tr = len(transcripts)
    n_ko = sum(1 for s in transcripts if s.get("translations", {}).get("ko"))
    print(f"✅ {out_dir/'bundle.json'}")
    print(f"   1 track · {duration_ms/1000:.1f}s · {n_tr} spans · {n_ko}/{n_tr} with Korean gloss")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
