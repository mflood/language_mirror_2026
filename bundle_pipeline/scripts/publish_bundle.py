#!/usr/bin/env python3
from __future__ import annotations

import argparse
import logging
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
    p.add_argument("--verbose", action="store_true", help="Enable debug logging")
    p.add_argument("--dryrun", action="store_true", help="Do not upload to S3; print/log what would be uploaded")
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
    logger.debug("Resolved: work_root=%s bundle_id=%s", str(args.work_root), args.bundle_id)
    logger.debug("Resolved: config=%s", str(cfg_path))

    cfg = BundleConfig.load(cfg_path)
    wp.ensure_dirs()

    manifest_path = args.manifest or wp.manifest_path
    logger.debug("Resolved: manifest=%s", str(manifest_path))
    logger.debug("Resolved: audio_dir=%s", str(wp.audio_dir))
    logger.debug("Resolved: qr_path=%s", str(wp.qr_path))

    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}. Run assemble_manifest.py first.")

    publish_cfg = PublishConfig.load(cfg.publish_config_path)
    prefix = publish_cfg.publish_prefix(cfg.bundle_id)

    # Upload audio + manifest
    files_to_upload = [manifest_path] + sorted([p for p in wp.audio_dir.glob("*") if p.is_file()])
    logger.info("Preparing publish: bucket=%s prefix=%s", publish_cfg.publish_bucket, prefix)
    logger.info("Files to upload: %d", len(files_to_upload))
    for f in files_to_upload:
        logger.debug("Upload plan: %s -> s3://%s/%s/%s", str(f), publish_cfg.publish_bucket, prefix.strip("/"), f.name)

    if args.dryrun:
        logger.info("Dry-run enabled: skipping S3 uploads.")
    else:
        logger.info("Uploading to S3...")
        upload_files(publish_cfg.publish_bucket, prefix, files_to_upload)
        logger.info("Upload complete.")

    manifest_url = publish_cfg.manifest_https_url(cfg.bundle_id, manifest_filename=manifest_path.name)
    print(f"Manifest URL: {manifest_url}")
    logger.info("Manifest URL: %s", manifest_url)
    write_qr_png(manifest_url, wp.qr_path)
    print(f"QR code: {wp.qr_path}")
    logger.info("QR code: %s", str(wp.qr_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


