#!/usr/bin/env python3
"""
Step 5: Publish bundle.json + audio files to the `lmaudio` destination
(s3://turned.rip/lmaudio/<pack_id>/ behind CloudFront) and generate a QR code
PNG pointing at the manifest URL — via the langpack `publisher` package.

Output:
    work/<date>/qr.png
    Bundle assets uploaded to s3://turned.rip/lmaudio/<pack_id>/

Safety: defaults to dry-run. Pass --commit to actually upload. Existing keys
at the destination prefix are never overwritten unless --redeploy is passed
(publisher clobber gate). bundle.json is CloudFront-invalidated after upload
so republished packs propagate immediately.

Usage:
    python 5_publish_s3.py [--date YYYY-MM-DD] [--commit] [--redeploy]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

from publisher import build_app_url, load_destination, publish, write_qr_png

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

DESTINATION = "lmaudio"
PREFIX_TEMPLATE = "lmaudio/{bundle_id}"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Publish the day's bundle to S3 + generate QR")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--commit", action="store_true", help="Actually upload to S3.")
    p.add_argument("--redeploy", action="store_true",
                   help="Allow overwriting an already-published pack (cp-only, never deletes).")
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
    prefix = PREFIX_TEMPLATE.format(bundle_id=pack_id)

    dest = load_destination(DESTINATION)
    mp3_files = sorted(p for p in audio_dir.glob("*.mp3") if p.is_file())
    files_to_upload = [bundle_path] + mp3_files
    plan = [(f, f"{prefix}/{f.name}") for f in files_to_upload]

    manifest_url = dest.public_url(f"{prefix}/{bundle_path.name}")
    qr_path = work_dir / "qr.png"

    print(f"═══ Publishing {pack_id} for {date} ═══")
    print(f"  Destination:   {DESTINATION} (s3://{dest.bucket}/)")
    print(f"  Prefix:        {prefix}/")
    print(f"  Manifest URL:  {manifest_url}")
    print(f"  QR output:     {qr_path}")
    print()

    publish(dest, plan,
            redeploy=args.redeploy,
            invalidate_paths=[f"/{prefix}/bundle.json"],
            commit=args.commit)

    if not args.commit:
        print(f"Re-run with --commit to publish {len(files_to_upload)} files.")
        return 0

    print("🔳 Generating QR code...")
    write_qr_png(manifest_url, qr_path)
    print(f"✅ QR code: {qr_path}")
    print(f"   App URL:      {build_app_url(manifest_url)}")
    print(f"   Manifest URL: {manifest_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
