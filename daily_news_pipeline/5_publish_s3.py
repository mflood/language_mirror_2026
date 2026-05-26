#!/usr/bin/env python3
"""
Step 5: Publish bundle.json + audio files to s3://turned.rip/lmaudio/<pack_id>/
and generate a QR code PNG that points at the CloudFront-served manifest URL.

Reuses the existing bundle pipeline's S3 + QR helpers so the iOS app sees a
news pack the same way it sees any other published pack.

Output:
    work/<date>/qr.png
    Bundle assets uploaded to s3://turned.rip/lmaudio/<pack_id>/

Safety: defaults to dry-run. Pass --commit to actually upload.

Usage:
    python 5_publish_s3.py [--date YYYY-MM-DD] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
WORK_ROOT = HERE / "work"

PUBLISH_BUCKET = "turned.rip"
PUBLISH_PREFIX_TEMPLATE = "lmaudio/{bundle_id}"
CLOUDFRONT_BASE = "https://d1ni0tk3ua6bwo.cloudfront.net"


def list_existing_keys(bucket: str, prefix: str) -> list[str]:
    """Return all keys currently at s3://bucket/prefix/. Empty list if none."""
    result = subprocess.run(
        ["aws", "s3api", "list-objects-v2", "--bucket", bucket, "--prefix", prefix],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        # Bucket access denied or doesn't exist — surface the actual error
        raise SystemExit(f"❌ aws s3api list-objects-v2 failed: {result.stderr.strip()}")
    if not result.stdout.strip():
        return []
    parsed = json.loads(result.stdout)
    return [obj["Key"] for obj in (parsed.get("Contents") or [])]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Publish the day's bundle to S3 + generate QR")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--commit", action="store_true", help="Actually upload to S3.")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    work_dir = WORK_ROOT / date
    bundle_path = work_dir / "bundle.json"
    audio_dir = work_dir / "audio"
    if not bundle_path.exists():
        raise SystemExit(f"❌ bundle.json not found at {bundle_path}. Run step 4 first.")

    manifest = json.loads(bundle_path.read_text(encoding="utf-8"))
    pack_id = manifest["id"]
    prefix = PUBLISH_PREFIX_TEMPLATE.format(bundle_id=pack_id)

    mp3_files = sorted(p for p in audio_dir.glob("*.mp3") if p.is_file())
    files_to_upload = [bundle_path] + mp3_files

    manifest_url = f"{CLOUDFRONT_BASE}/{prefix}/{bundle_path.name}"
    qr_path = work_dir / "qr.png"

    print(f"═══ Publishing {pack_id} for {date} ═══")
    print(f"  Bucket:        s3://{PUBLISH_BUCKET}/")
    print(f"  Prefix:        {prefix}/")
    print(f"  Manifest URL:  {manifest_url}")
    print(f"  QR output:     {qr_path}")
    print()

    # Pre-flight: check if anything already exists at the destination prefix.
    print(f"🔍 Pre-flight: listing existing keys at s3://{PUBLISH_BUCKET}/{prefix}/")
    existing = list_existing_keys(PUBLISH_BUCKET, prefix + "/")
    if existing:
        print(f"   ⚠ Destination prefix is NOT empty — {len(existing)} key(s) already there:")
        for k in existing:
            print(f"     · s3://{PUBLISH_BUCKET}/{k}")
        # Check which uploads would clobber
        upload_keys = {f"{prefix}/{f.name}" for f in files_to_upload}
        clobbers = sorted(set(existing) & upload_keys)
        if clobbers:
            print(f"   ❗ {len(clobbers)} of these would be OVERWRITTEN by this run:")
            for k in clobbers:
                print(f"     · s3://{PUBLISH_BUCKET}/{k}")
            if args.commit:
                raise SystemExit(
                    "❌ Refusing to clobber existing keys. If the previous pack is correct,\n"
                    "   skip this run. If it's bad and you intend to replace it, manually\n"
                    "   delete those keys first (aws s3 rm) and re-run."
                )
        else:
            print(f"   ✓ no clobber: uploads will be additive at this prefix")
    else:
        print(f"   ✓ destination empty — uploads will be all-new")
    print()

    print("Files to upload (local → s3):")
    for f in files_to_upload:
        size_kb = f.stat().st_size / 1024
        s3_dest = f"s3://{PUBLISH_BUCKET}/{prefix}/{f.name}"
        print(f"  {f}  ({size_kb:.0f} KB)")
        print(f"    → {s3_dest}")
    print()

    if not args.commit:
        print("--- DRY RUN — no S3 uploads, no QR generation ---")
        print(f"Re-run with --commit to publish {len(files_to_upload)} files.")
        return 0

    # Make bundle_pipeline importable (its helpers live in the repo)
    sys.path.insert(0, str(REPO_ROOT))
    try:
        from bundle_pipeline.s3io import upload_files
        from bundle_pipeline.qrcode_tools import write_qr_png, build_app_url
    except ImportError as e:
        raise SystemExit(f"❌ failed to import bundle_pipeline helpers: {e}")

    print("📤 Uploading to S3...")
    for f in files_to_upload:
        s3_dest = f"s3://{PUBLISH_BUCKET}/{prefix}/{f.name}"
        print(f"   ↑ {f.name}  →  {s3_dest}")
    upload_files(PUBLISH_BUCKET, prefix, files_to_upload)
    print(f"✅ Uploaded {len(files_to_upload)} files.")

    # Post-upload verification
    print("🔍 Post-flight: verifying uploaded keys are visible...")
    after = set(list_existing_keys(PUBLISH_BUCKET, prefix + "/"))
    for f in files_to_upload:
        key = f"{prefix}/{f.name}"
        ok = "✓" if key in after else "✗"
        print(f"   {ok} s3://{PUBLISH_BUCKET}/{key}")

    print("🔳 Generating QR code...")
    write_qr_png(manifest_url, qr_path)
    print(f"✅ QR code: {qr_path}")
    print(f"   App URL:      {build_app_url(manifest_url)}")
    print(f"   Manifest URL: {manifest_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
