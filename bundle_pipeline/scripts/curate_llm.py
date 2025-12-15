#!/usr/bin/env python3
from __future__ import annotations

import argparse
import logging
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.audio import find_audio_files, get_audio_duration_ms
from bundle_pipeline.artifacts import artifact_path, load_json_if_exists, write_json
from bundle_pipeline.whisper_tools import extract_segments_for_llm
from bundle_pipeline.openai_tools import build_curation_prompt, curate_with_openai

logger = logging.getLogger(__name__)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Use an LLM to curate transcripts + derive practice clips")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--gpt-model", help="Override OpenAI model name")
    p.add_argument("--force", action="store_true", help="Reprocess even if curated output already exists")
    p.add_argument("--verbose", action="store_true", help="Enable debug logging")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=(logging.DEBUG if args.verbose else logging.INFO),
        format="%(levelname)s:%(name)s:%(message)s",
    )
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)

    wp.ensure_dirs()

    model_name = args.gpt_model or cfg.gpt_model
    logger.info(
        "Starting LLM curation: bundle_id=%s work_root=%s model=%s",
        args.bundle_id,
        str(args.work_root),
        model_name,
    )

    audio_files = find_audio_files(wp.audio_dir)
    if not audio_files:
        raise ValueError(f"No audio files found in {wp.audio_dir}. Run download_audio.py first.")
    logger.info("Found %d audio file(s) to consider in %s", len(audio_files), str(wp.audio_dir))

    done = 0
    for audio_path in audio_files:
        out_path = artifact_path(wp.curated_dir, audio_path.name, "curated")
        existing = load_json_if_exists(out_path)
        if existing and not args.force:
            logger.warning("Skipping (already curated). Use --force to reprocess: %s -> %s", audio_path.name, str(out_path))
            done += 1
            continue
        if existing and args.force:
            logger.info("Reprocessing due to --force: %s -> %s", audio_path.name, str(out_path))

        whisper_path = artifact_path(wp.whisper_dir, audio_path.name, "whisper")
        whisper = load_json_if_exists(whisper_path)
        if not whisper:
            raise FileNotFoundError(f"Missing whisper artifact for {audio_path.name}: {whisper_path}. Run transcribe_whisper.py first.")

        logger.debug(
            "Processing: %s (whisper=%s, out=%s)",
            audio_path.name,
            str(whisper_path),
            str(out_path),
        )
        duration_ms = get_audio_duration_ms(audio_path)
        segments = extract_segments_for_llm(whisper)
        logger.debug("Prepared LLM input for %s: duration_ms=%d segments=%d", audio_path.name, duration_ms, len(segments))
        prompt = build_curation_prompt(segments, audio_duration_ms=duration_ms, language_code=cfg.language_code)
        curated = curate_with_openai(model=model_name, prompt=prompt)
        write_json(out_path, curated)
        done += 1
        transcripts_n = len(curated.get("transcripts", []) or [])
        clips_n = len(curated.get("clips", []) or [])
        logger.debug(
            "Completed: %s (transcripts=%d clips=%d) -> %s",
            audio_path.name,
            transcripts_n,
            clips_n,
            str(out_path),
        )
        logger.info("Wrote: %s", str(out_path))

    logger.info("Curated artifacts available for %d/%d file(s) in %s", done, len(audio_files), str(wp.curated_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


