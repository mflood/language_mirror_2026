"""
Assemble a BundleManifest from database rows and publish to S3/CloudFront.
"""
from __future__ import annotations

import json
import logging
import uuid
from typing import Optional

from app.dao import DAO
from app.settings import settings

logger = logging.getLogger(__name__)

DEFAULT_PREFIX_TEMPLATE = "lmaudio/{pack_id}"


def _resolve_publish_prefix(pack: dict) -> str:
    """Use stored publish_prefix if set, otherwise generate from pack ID."""
    prefix = pack.get("publish_prefix")
    if prefix:
        return prefix.strip("/")
    return DEFAULT_PREFIX_TEMPLATE.format(pack_id=pack["id"])


def build_manifest(dao: DAO, pack_id: str) -> dict:
    """Build the bundle manifest JSON dict from DB rows."""
    pack = dao.get_pack(pack_id)
    if not pack:
        raise ValueError(f"Pack {pack_id} not found")

    publish_prefix = _resolve_publish_prefix(pack)
    project = dao.get_project(pack["project_id"])
    tracks_rows = dao.list_tracks_for_pack(pack_id)

    tracks = []
    for t in tracks_rows:
        clips_rows = dao.list_clips_for_track(t["id"])
        spans_rows = dao.list_spans_for_track(t["id"])

        # Build CloudFront URL for the audio file
        audio_url = f"{settings.cloudfront_base_url}/{publish_prefix}/{t['filename']}"

        # Group clips into a practice set
        practice_sets = []
        if clips_rows:
            ps_id = str(uuid.uuid4())
            clips = [
                {
                    "id": str(uuid.uuid4()),
                    "startMs": c["start_ms"],
                    "endMs": c["end_ms"],
                    "kind": c["kind"],
                    "title": c.get("title"),
                    "repeats": None,
                    "startSpeed": None,
                    "endSpeed": None,
                    "languageCode": t.get("language_code"),
                }
                for c in clips_rows
            ]
            practice_sets.append({
                "id": ps_id,
                "trackId": t["id"],
                "displayOrder": 0,
                "title": "Practice Set",
                "clips": clips,
                "isFavorite": False,
            })

        transcripts = [
            {
                "startMs": s["start_ms"],
                "endMs": s["end_ms"],
                "text": s["text"],
                "speaker": s.get("speaker"),
                "languageCode": s.get("language_code") or t.get("language_code"),
            }
            for s in spans_rows
        ]

        tracks.append({
            "id": t["id"],
            "title": t["title"],
            "url": audio_url,
            "filename": t["filename"],
            "durationMs": t["duration_ms"],
            "languageCode": t.get("language_code"),
            "practiceSets": practice_sets if practice_sets else None,
            "transcripts": transcripts if transcripts else None,
        })

    manifest = {
        "id": pack_id,
        "title": pack["title"],
        "packs": [
            {
                "id": pack_id,
                "title": pack["title"],
                "author": pack.get("author"),
                "coverUrl": pack.get("cover_url"),
                "coverFilename": None,
                "tracks": tracks,
            }
        ],
    }
    return manifest


def publish_pack(dao: DAO, pack_id: str) -> dict:
    """
    Build manifest, upload bundle.json + copy audio files to publish prefix, return info.
    """
    import boto3

    pack = dao.get_pack(pack_id)
    if not pack:
        raise ValueError(f"Pack {pack_id} not found")

    manifest = build_manifest(dao, pack_id)
    manifest_json = json.dumps(manifest, ensure_ascii=False, indent=2)

    publish_prefix = _resolve_publish_prefix(pack)
    bucket = settings.s3_bucket_name

    s3 = boto3.client("s3",
        region_name=settings.aws_region or "us-east-1",
        aws_access_key_id=settings.aws_access_key_id or None,
        aws_secret_access_key=settings.aws_secret_access_key or None,
    )

    # Upload bundle.json
    manifest_key = f"{publish_prefix}/bundle.json"
    logger.info("Publishing bundle.json to s3://%s/%s", bucket, manifest_key)
    s3.put_object(
        Bucket=bucket,
        Key=manifest_key,
        Body=manifest_json.encode("utf-8"),
        ContentType="application/json",
    )

    # Copy audio files from editor prefix to publish prefix
    tracks = dao.list_tracks_for_pack(pack_id)
    for t in tracks:
        source_key = t["s3_key"]
        dest_key = f"{publish_prefix}/{t['filename']}"
        if source_key != dest_key:
            logger.info("Copying audio %s -> %s", source_key, dest_key)
            s3.copy_object(
                Bucket=bucket,
                CopySource={"Bucket": bucket, "Key": source_key},
                Key=dest_key,
            )

    # Update pack status
    dao.update_pack(pack_id, status="published")

    # Build URLs
    manifest_url = f"{settings.cloudfront_base_url}/{manifest_key}"
    deeplink_url = f"languagemirror://import?url={manifest_url}"

    return {
        "manifest_url": manifest_url,
        "deeplink_url": deeplink_url,
        "manifest_key": manifest_key,
        "tracks_published": len(tracks),
        "publish_prefix": publish_prefix,
    }


def build_embedded_manifest(dao: DAO, pack_id: str, bundle_id: str) -> dict:
    """
    Build a manifest formatted for iOS app embedding.
    Differences from CDN manifest:
    - track url is null (audio is bundled in the app)
    - track filename is prefixed with {bundle_id}__
    - Includes a "Full Track" practice set as the first set
    """
    pack = dao.get_pack(pack_id)
    if not pack:
        raise ValueError(f"Pack {pack_id} not found")

    tracks_rows = dao.list_tracks_for_pack(pack_id)
    tracks = []
    for t in tracks_rows:
        clips_rows = dao.list_clips_for_track(t["id"])
        spans_rows = dao.list_spans_for_track(t["id"])

        embedded_filename = f"{bundle_id}__{t['filename']}"

        practice_sets = []
        # Full Track practice set (single clip covering entire duration)
        full_track_clip = {
            "id": str(uuid.uuid4()),
            "startMs": 0,
            "endMs": t["duration_ms"] or 0,
            "kind": "drill",
            "title": "Full Track",
            "repeats": None,
            "startSpeed": None,
            "endSpeed": None,
            "languageCode": t.get("language_code"),
        }
        practice_sets.append({
            "id": str(uuid.uuid4()),
            "trackId": t["id"],
            "displayOrder": 0,
            "title": "Full Track",
            "clips": [full_track_clip],
            "isFavorite": False,
        })

        # Practice Set from edited clips
        if clips_rows:
            ps_clips = [
                {
                    "id": str(uuid.uuid4()),
                    "startMs": c["start_ms"],
                    "endMs": c["end_ms"],
                    "kind": c["kind"],
                    "title": c.get("title"),
                    "repeats": None,
                    "startSpeed": None,
                    "endSpeed": None,
                    "languageCode": t.get("language_code"),
                }
                for c in clips_rows
            ]
            practice_sets.append({
                "id": str(uuid.uuid4()),
                "trackId": t["id"],
                "displayOrder": 1,
                "title": "Practice Set",
                "clips": ps_clips,
                "isFavorite": False,
            })

        transcripts = [
            {
                "startMs": s["start_ms"],
                "endMs": s["end_ms"],
                "text": s["text"],
                "speaker": s.get("speaker"),
                "languageCode": s.get("language_code") or t.get("language_code"),
            }
            for s in spans_rows
        ]

        tracks.append({
            "id": t["id"],
            "title": t["title"],
            "url": None,
            "filename": embedded_filename,
            "durationMs": t["duration_ms"],
            "languageCode": t.get("language_code"),
            "practiceSets": practice_sets,
            "transcripts": transcripts if transcripts else None,
        })

    return {
        "id": bundle_id,
        "title": pack["title"],
        "packs": [{
            "id": bundle_id,
            "title": pack["title"],
            "author": pack.get("author"),
            "coverUrl": None,
            "coverFilename": None,
            "tracks": tracks,
        }],
    }
