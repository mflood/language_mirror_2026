#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.audio import find_audio_files, get_audio_duration_ms
from bundle_pipeline.artifacts import artifact_path, load_json_if_exists, write_json
from bundle_pipeline.whisper_tools import transcribe_with_whisper


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run Whisper transcription for all audio files in work/<bundle_id>/audio/")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--whisper-model", help="Override Whisper model name")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)

    wp.ensure_dirs()

    model_name = args.whisper_model or cfg.whisper_model

    audio_files = find_audio_files(wp.audio_dir)
    if not audio_files:
        raise ValueError(f"No audio files found in {wp.audio_dir}. Run download_audio.py first.")

    done = 0
    for audio_path in audio_files:
        out_path = artifact_path(wp.whisper_dir, audio_path.name, "whisper")
        existing = load_json_if_exists(out_path)
        if existing:
            done += 1
            continue

        # Force duration read once to fail fast if soundfile missing.
        _ = get_audio_duration_ms(audio_path)
        result = transcribe_with_whisper(audio_path, model_name=model_name, language_code=cfg.language_code)
        write_json(out_path, result)
        done += 1
        print(f"Wrote: {out_path}")

    print(f"Whisper artifacts available for {done}/{len(audio_files)} file(s) in {wp.whisper_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


