#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.s3io import download_prefix_to_dir


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Download source audio from S3 prefix into work/<bundle_id>/audio/")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)

    wp.ensure_dirs()

    downloaded = download_prefix_to_dir(cfg.source_s3, wp.audio_dir)
    print(f"Downloaded {len(downloaded)} file(s) to {wp.audio_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


