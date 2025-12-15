from __future__ import annotations

import json
import logging
import uuid
from pathlib import Path
from typing import Any

from .artifacts import artifact_path, load_json_if_exists
from .audio import clean_track_title, find_audio_files, get_audio_duration_ms
from .config import BundleConfig, PublishConfig
from .models import (
    BundleManifest,
    BundlePack,
    BundleTrack,
    Clip,
    PracticeSet,
    TranscriptSpan,
)
from .paths import WorkPaths

logger = logging.getLogger(__name__)


def _audio_https_url(publish_cfg: PublishConfig, bundle_id: str, filename: str) -> str:
    return f"{publish_cfg.cloudfront_https_base}{publish_cfg.cloudfront_prefix(bundle_id)}/{filename}"


def _full_track_practice_set(duration_ms: int, language_code: str | None) -> PracticeSet:
    # NOTE: trackId is a placeholder; iOS import replaces it with the generated trackId.
    track_id_placeholder = str(uuid.uuid4())
    if duration_ms <= 0:
        return PracticeSet(
            id=str(uuid.uuid4()),
            trackId=track_id_placeholder,
            displayOrder=0,
            title="Full Track",
            clips=[],
            isFavorite=False,
        )

    return PracticeSet(
        id=str(uuid.uuid4()),
        trackId=track_id_placeholder,
        displayOrder=0,
        title="Full Track",
        clips=[
            Clip(
                id=str(uuid.uuid4()),
                startMs=0,
                endMs=duration_ms,
                kind="drill",
                title="Full Track",
                repeats=None,
                startSpeed=None,
                endSpeed=None,
                languageCode=None,
            )
        ],
        isFavorite=False,
    )


def _curated_to_practice_set(curated: dict[str, Any], language_code: str | None) -> tuple[list[TranscriptSpan], PracticeSet]:
    """
    Expected curated schema (from curate_llm.py):
      {
        "transcripts": [ {startMs,endMs,text,speaker?}, ... ],
        "clips": [ {startMs,endMs,kind,title?}, ... ]
      }
    """
    track_id_placeholder = str(uuid.uuid4())

    transcripts: list[TranscriptSpan] = []
    for t in curated.get("transcripts", []) or []:
        transcripts.append(
            TranscriptSpan(
                startMs=int(t["startMs"]),
                endMs=int(t["endMs"]),
                text=str(t["text"]),
                speaker=t.get("speaker"),
                languageCode=language_code,
            )
        )

    clips: list[Clip] = []
    for c in curated.get("clips", []) or []:
        kind = str(c["kind"])
        clips.append(
            Clip(
                id=str(uuid.uuid4()),
                startMs=int(c["startMs"]),
                endMs=int(c["endMs"]),
                kind=kind,  # drill|skip|noise
                title=c.get("title"),
                repeats=None,
                startSpeed=None,
                endSpeed=None,
                languageCode=language_code if kind == "drill" else None,
            )
        )

    ps = PracticeSet(
        id=str(uuid.uuid4()),
        trackId=track_id_placeholder,
        displayOrder=1,
        title="Practice Set",
        clips=clips,
        isFavorite=False,
    )

    return transcripts, ps


def assemble_manifest(work_root: Path, bundle_id: str, config_path: Path | None = None) -> tuple[BundleManifest, Path]:
    wp = WorkPaths(work_root=work_root, bundle_id=bundle_id)
    logger.info("Assembling manifest: bundle_id=%s work_root=%s", bundle_id, str(work_root))
    cfg = BundleConfig.load(config_path or wp.config_path)
    publish_cfg = PublishConfig.load(cfg.publish_config_path)

    audio_files = find_audio_files(wp.audio_dir)
    if not audio_files:
        raise ValueError(f"No audio files found in {wp.audio_dir}")
    logger.info("Found %d audio file(s) in %s", len(audio_files), str(wp.audio_dir))

    tracks: list[BundleTrack] = []
    for audio_path in audio_files:
        logger.debug("Processing track: %s", str(audio_path))
        duration_ms = get_audio_duration_ms(audio_path)
        title = clean_track_title(audio_path.name)

        curated_path = artifact_path(wp.curated_dir, audio_path.name, "curated")
        logger.debug("Loading curated artifact (if present): %s", str(curated_path))
        curated = load_json_if_exists(curated_path)

        practice_sets: list[PracticeSet] = []
        transcripts: list[TranscriptSpan] = []

        practice_sets.append(_full_track_practice_set(duration_ms, cfg.language_code))
        if curated:
            curated_transcripts, curated_set = _curated_to_practice_set(curated, cfg.language_code)
            transcripts = curated_transcripts
            if curated_set.clips:
                practice_sets.append(curated_set)

        track = BundleTrack(
            id=audio_path.name,  # stable per track; iOS import uses id+url to derive deterministic UUID
            title=title,
            url=_audio_https_url(publish_cfg, cfg.bundle_id, audio_path.name),
            filename=audio_path.name,
            durationMs=duration_ms if duration_ms > 0 else None,
            languageCode=cfg.language_code,
            practiceSets=practice_sets,
            transcripts=transcripts,
        )
        tracks.append(track)

    pack = BundlePack(
        id=cfg.bundle_id,
        title=cfg.pack_title,
        author=cfg.author,
        coverUrl=cfg.cover_url,
        coverFilename=cfg.cover_filename,
        tracks=tracks,
    )

    manifest = BundleManifest(id=cfg.bundle_id, title=cfg.bundle_title, packs=[pack])
    out_path = wp.manifest_path
    logger.debug("Writing manifest JSON: %s", str(out_path))
    out_path.write_text(json.dumps(manifest.to_json(), ensure_ascii=False, indent=2), encoding="utf-8")
    logger.info("Assembled manifest: %s", str(out_path))
    return manifest, out_path


