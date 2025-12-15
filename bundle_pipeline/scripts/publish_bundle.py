#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths
from bundle_pipeline.config import PublishConfig
from bundle_pipeline.s3io import upload_files
from bundle_pipeline.qrcode_tools import write_qr_png


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Publish audio + bundle.json to destination S3 and generate QR code")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--manifest", type=Path, help="Manifest path (default: work/<bundle_id>/bundle.json)")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    wp = WorkPaths(args.work_root, args.bundle_id)
    cfg_path = args.config or wp.config_path
    cfg = BundleConfig.load(cfg_path)
    wp.ensure_dirs()

    manifest_path = args.manifest or wp.manifest_path

    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}. Run assemble_manifest.py first.")

    publish_cfg = PublishConfig.load(cfg.publish_config_path)
    prefix = publish_cfg.publish_prefix(cfg.bundle_id)

    # Upload audio + manifest
    files_to_upload = [manifest_path] + sorted(wp.audio_dir.glob("*"))
    upload_files(publish_cfg.publish_bucket, prefix, files_to_upload)

    manifest_url = publish_cfg.manifest_https_url(cfg.bundle_id, manifest_filename=manifest_path.name)
    print(f"Manifest URL: {manifest_url}")
    write_qr_png(manifest_url, wp.qr_path)
    print(f"QR code: {wp.qr_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


