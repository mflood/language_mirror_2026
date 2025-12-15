#!/usr/bin/env python3
from __future__ import annotations

import argparse
import logging
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.s3io import download_prefix_to_dir


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Download source audio from S3 prefix into work/<bundle_id>/audio/")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--verbose", action="store_true", help="Enable debug logging")
    p.add_argument(
        "--match",
        help="Case-sensitive substring match on basename filename; only matching files will be downloaded",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()

    logging.basicConfig(
        level=(logging.DEBUG if args.verbose else logging.INFO),
        format="%(levelname)s %(message)s",
    )
    logger = logging.getLogger(__name__)

    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)

    wp.ensure_dirs()

    logger.info("Starting download from %s to %s", cfg.source_s3, wp.audio_dir)
    if args.match:
        logger.info("Filter enabled: --match=%r (basename substring, case-sensitive)", args.match)

    downloaded = download_prefix_to_dir(cfg.source_s3, wp.audio_dir, match=args.match, logger=logger)
    logger.info("Downloaded %d file(s) to %s", len(downloaded), wp.audio_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


