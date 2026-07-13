#!/usr/bin/env python3
"""
Step 5: Publish bundle.json + audio files to the `lmaudio` destination
(s3://turned.rip/lmaudio/<pack_id>/ behind CloudFront) and generate a QR code
PNG pointing at the manifest URL — via the langpack `publisher` package.

Output:
    work/<date>/qr.png
    Bundle assets uploaded to s3://turned.rip/lmaudio/<pack_id>/
    s3://turned.rip/lmaudio/news_latest/bundle.json  (stable alias; see
    NEWS_PUSH_PIPELINE_SPEC.md — the iOS daily reminder resolves this key)

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

import edition
import notify_email
import json
from pathlib import Path

from publisher import build_app_url, load_destination, publish, write_qr_png

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"

DESTINATION = "lmaudio"
PREFIX_TEMPLATE = "lmaudio/{bundle_id}"
# Stable aliases the iOS daily reminder resolves (NEWS_PUSH_PIPELINE_SPEC.md +
# ENGLISH_NEWS_EDITION_SPEC.md): one per edition.
LATEST_ALIAS_KEYS = {
    "ko": "lmaudio/news_latest/bundle.json",
    "en": "lmaudio/news_en_latest/bundle.json",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Publish the day's bundle to S3 + generate QR")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--commit", action="store_true", help="Actually upload to S3.")
    edition.add_edition_arg(p)
    p.add_argument("--redeploy", action="store_true",
                   help="Allow overwriting an already-published pack (cp-only, never deletes).")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    sfx = edition.suffix(args.edition)
    work_dir = WORK_ROOT / date
    bundle_path = work_dir / f"bundle{sfx}.json"
    audio_dir = work_dir / f"audio{sfx}"
    if not bundle_path.exists():
        raise SystemExit(f"❌ {bundle_path.name} not found at {bundle_path}. Run step 4 first.")

    manifest = json.loads(bundle_path.read_text(encoding="utf-8"))
    pack_id = manifest["id"]
    prefix = PREFIX_TEMPLATE.format(bundle_id=pack_id)
    latest_alias_key = LATEST_ALIAS_KEYS[args.edition]

    dest = load_destination(DESTINATION)
    mp3_files = sorted(p for p in audio_dir.glob("*.mp3") if p.is_file())
    # Upload audio FIRST and the manifest LAST. publish() uploads plan entries
    # in order, so this guarantees there is never a window where a live
    # bundle.json points at MP3s that haven't landed yet (a client hitting
    # CloudFront mid-publish would otherwise 404 on every clip).
    # The S3 key is always bundle.json even when the local file is bundle_en.json.
    plan = [(f, f"{prefix}/{f.name}") for f in mp3_files]
    plan.append((bundle_path, f"{prefix}/bundle.json"))
    files_to_upload = mp3_files + [bundle_path]

    manifest_url = dest.public_url(f"{prefix}/bundle.json")
    qr_path = work_dir / f"qr{sfx}.png"

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

    # news_latest alias (NEWS_PUSH_PIPELINE_SPEC.md, option A): the iOS app's
    # daily reminder resolves "today's pack" via this stable key even when a
    # run slips. Only bundle.json is aliased — its pack id and audio URLs stay
    # dated, so the app dedups against the real pack and audio isn't duplicated.
    print()
    print(f"🔗 Updating {latest_alias_key} alias...")
    publish(dest, [(bundle_path, latest_alias_key)],
            allow_overwrite_keys=(latest_alias_key,),   # rolling alias, always overwritten
            invalidate_paths=[f"/{latest_alias_key}"],
            commit=True)

    print("🔳 Generating QR code...")
    write_qr_png(manifest_url, qr_path)
    print(f"✅ QR code: {qr_path}")
    print(f"   App URL:      {build_app_url(manifest_url)}")
    print(f"   Manifest URL: {manifest_url}")

    pack = manifest.get("packs", [{}])[0]
    tracks = "\n".join(f"  · {t.get('title', '?')}" for t in pack.get("tracks", []))
    edition_label = "Korean" if args.edition == "ko" else "English"
    notify_email.send(
        subject=f"✅ {pack_id} deployed ({edition_label} edition)",
        body=(f"{pack.get('title', pack_id)}\n\n"
              f"Tracks:\n{tracks}\n\n"
              f"Manifest: {manifest_url}\n"
              f"Alias:    {dest.public_url(latest_alias_key)}\n"
              + (f"Web:      https://sixwandsstudios.com/news/{date}/\n"
                 if args.edition == "ko" else "")),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
