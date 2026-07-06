#!/usr/bin/env python3
"""Publish audio + bundle.json to S3 and generate a QR code — via the langpack
`publisher` package (destination "lmaudio"). Gains the platform gates: clobber
refusal with --redeploy escape, post-flight verify, CloudFront invalidation."""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

from publisher import build_app_url, load_destination, publish, write_qr_png

from bundle_pipeline.config import BundleConfig
from bundle_pipeline.paths import WorkPaths

DESTINATION = "lmaudio"
PREFIX_TEMPLATE = "lmaudio/{bundle_id}"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Publish audio + bundle.json to destination S3 and generate QR code")
    p.add_argument("--bundle-id", required=True)
    p.add_argument("--work-root", type=Path, default=Path("work"))
    p.add_argument("--config", type=Path, help="Path to bundle.yaml (default: work/<bundle_id>/bundle.yaml)")
    p.add_argument("--manifest", type=Path, help="Manifest path (default: work/<bundle_id>/bundle.json)")
    p.add_argument("--verbose", action="store_true", help="Enable debug logging")
    p.add_argument("--dryrun", action="store_true", help="Do not upload to S3; print/log what would be uploaded")
    p.add_argument("--redeploy", action="store_true",
                   help="Allow overwriting an already-published bundle (cp-only, never deletes)")
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

    manifest_path = args.manifest or wp.manifest_path
    if not manifest_path.exists():
        raise FileNotFoundError(f"Manifest not found: {manifest_path}. Run assemble_manifest.py first.")

    dest = load_destination(DESTINATION)
    prefix = PREFIX_TEMPLATE.format(bundle_id=cfg.bundle_id)

    files_to_upload = [manifest_path] + sorted(
        p for p in wp.audio_dir.glob("*") if p.is_file())
    plan = [(f, f"{prefix}/{f.name}") for f in files_to_upload]
    logger.info("Preparing publish: bucket=%s prefix=%s", dest.bucket, prefix)
    logger.info("Files to upload: %d", len(files_to_upload))

    publish(dest, plan,
            redeploy=args.redeploy,
            invalidate_paths=[f"/{prefix}/{manifest_path.name}"],
            commit=not args.dryrun)

    manifest_url = dest.public_url(f"{prefix}/{manifest_path.name}")
    app_url = build_app_url(manifest_url)
    print(f"Manifest URL: {manifest_url}")
    print(f"App URL:      {app_url}")
    if not args.dryrun:
        write_qr_png(manifest_url, wp.qr_path)
        print(f"QR code: {wp.qr_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
