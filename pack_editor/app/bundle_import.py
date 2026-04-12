"""
Import an existing published bundle.json into the pack editor database.
Audio files remain at their existing S3/CloudFront locations — we just
record the s3_key so the editor can reference them.
"""
from __future__ import annotations

import logging
from urllib.parse import urlparse

import httpx

from app.dao import DAO
from app.settings import settings

logger = logging.getLogger(__name__)


def _s3_key_from_url(url: str) -> str:
    """
    Extract the S3 key from a CloudFront or S3 URL.
    e.g. https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/foo/track.mp3 -> lmaudio/foo/track.mp3
    """
    parsed = urlparse(url)
    return parsed.path.lstrip("/")


def fetch_manifest(manifest_url: str) -> dict:
    resp = httpx.get(manifest_url, timeout=30, follow_redirects=True)
    resp.raise_for_status()
    return resp.json()


def import_bundle(dao: DAO, manifest_url: str, project_id: str) -> dict:
    """
    Fetch a bundle.json and import its packs/tracks/clips/spans into the DB
    under the given project.

    Returns summary dict.
    """
    manifest = fetch_manifest(manifest_url)
    logger.info("Importing bundle '%s' (%d packs)", manifest.get("title"), len(manifest.get("packs", [])))

    # Derive the publish prefix from the manifest URL
    # e.g. https://cdn.../lmaudio/starter_korean_greetings/bundle.json -> lmaudio/starter_korean_greetings
    parsed_url = urlparse(manifest_url)
    url_path = parsed_url.path.lstrip("/")
    if url_path.endswith("/bundle.json"):
        publish_prefix = url_path[: -len("/bundle.json")]
    else:
        publish_prefix = url_path.rsplit("/", 1)[0] if "/" in url_path else ""

    stats = {"packs": 0, "tracks": 0, "clips": 0, "spans": 0}

    for bundle_pack in manifest.get("packs", []):
        pack = dao.create_pack(
            project_id=project_id,
            title=bundle_pack.get("title", "Untitled"),
            author=bundle_pack.get("author"),
        )
        # Mark as published and store the original S3 prefix
        dao.update_pack(pack["id"], status="published", publish_prefix=publish_prefix)
        stats["packs"] += 1

        for bundle_track in bundle_pack.get("tracks", []):
            audio_url = bundle_track.get("url", "")
            filename = bundle_track.get("filename") or audio_url.split("/")[-1]
            s3_key = _s3_key_from_url(audio_url) if audio_url else ""

            track = dao.create_track(
                pack_id=pack["id"],
                title=bundle_track.get("title", filename),
                filename=filename,
                s3_key=s3_key,
                duration_ms=bundle_track.get("durationMs"),
                language_code=bundle_track.get("languageCode"),
                display_order=stats["tracks"],
            )
            stats["tracks"] += 1

            # Import practice sets and clips
            for ps_data in bundle_track.get("practiceSets") or []:
                ps = dao.create_practice_set(
                    track_id=track["id"],
                    title=ps_data.get("title", "Practice Set"),
                    display_order=ps_data.get("displayOrder", 0),
                )
                clips = ps_data.get("clips") or []
                if clips:
                    dao.bulk_insert_clips(track["id"], ps["id"], clips)
                    stats["clips"] += len(clips)

            # Import transcript spans
            transcripts = bundle_track.get("transcripts") or []
            if transcripts:
                language_code = bundle_track.get("languageCode")
                dao.bulk_insert_transcript_spans(track["id"], transcripts, language_code)
                stats["spans"] += len(transcripts)

    return stats
