#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.audio import find_audio_files, get_audio_duration_ms
from bundle_pipeline.artifacts import artifact_path, load_json_if_exists, write_json
from bundle_pipeline.whisper_tools import extract_segments_for_llm
from bundle_pipeline.openai_tools import build_curation_prompt, curate_with_openai


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Use an LLM to curate transcripts + derive practice clips")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--gpt-model", help="Override OpenAI model name")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)

    wp.ensure_dirs()

    model_name = args.gpt_model or cfg.gpt_model

    audio_files = find_audio_files(wp.audio_dir)
    if not audio_files:
        raise ValueError(f"No audio files found in {wp.audio_dir}. Run download_audio.py first.")

    done = 0
    for audio_path in audio_files:
        out_path = artifact_path(wp.curated_dir, audio_path.name, "curated")
        existing = load_json_if_exists(out_path)
        if existing:
            done += 1
            continue

        whisper_path = artifact_path(wp.whisper_dir, audio_path.name, "whisper")
        whisper = load_json_if_exists(whisper_path)
        if not whisper:
            raise FileNotFoundError(f"Missing whisper artifact for {audio_path.name}: {whisper_path}. Run transcribe_whisper.py first.")

        duration_ms = get_audio_duration_ms(audio_path)
        segments = extract_segments_for_llm(whisper)
        prompt = build_curation_prompt(segments, audio_duration_ms=duration_ms, language_code=cfg.language_code)
        curated = curate_with_openai(model=model_name, prompt=prompt)
        write_json(out_path, curated)
        done += 1
        print(f"Wrote: {out_path}")

    print(f"Curated artifacts available for {done}/{len(audio_files)} file(s) in {wp.curated_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


