#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Initialize a bundle work directory and bundle.yaml")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--source-s3", required=True, help="e.g. s3://bucket/prefix/")
    p.add_argument("--language-code", required=True, help="e.g. ko-KR, en-US, zh-CN, es-ES")
    p.add_argument("--bundle-title", help="Defaults to bundle-id")
    p.add_argument("--pack-title", help="Defaults to bundle-title")
    p.add_argument("--author")
    p.add_argument("--cover-url")
    p.add_argument("--cover-filename")
    p.add_argument("--whisper-model", default="base")
    p.add_argument("--gpt-model", default="gpt-4o-mini")
    p.add_argument("--publish-config", type=Path, default=Path("bundle_publish_config.yaml"))
    p.add_argument("--work-root", type=Path, default=Path("work"))
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(work_root=args.work_root, bundle_id=args.bundle_id)
    wp.ensure_dirs()

    bundle_title = args.bundle_title or args.bundle_id
    pack_title = args.pack_title or bundle_title

    cfg = BundleConfig(
        bundle_id=args.bundle_id,
        source_s3=args.source_s3,
        language_code=args.language_code,
        bundle_title=bundle_title,
        pack_title=pack_title,
        author=args.author,
        cover_url=args.cover_url,
        cover_filename=args.cover_filename,
        whisper_model=args.whisper_model,
        gpt_model=args.gpt_model,
        publish_config_path=args.publish_config,
    )

    wp.config_path.write_text(cfg.dump_yaml(), encoding="utf-8")
    print(f"Wrote: {wp.config_path}")
    print(f"Audio dir: {wp.audio_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


