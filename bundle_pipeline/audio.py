from __future__ import annotations

import logging
from pathlib import Path

try:
    import soundfile as sf  # type: ignore[import-not-found]
except Exception:  # pragma: no cover
    sf = None

logger = logging.getLogger(__name__)


AUDIO_EXTENSIONS = {".mp3", ".m4a", ".wav", ".aac", ".flac", ".ogg", ".opus"}


def natural_sort_key(filename: str) -> tuple:
    import re

    parts = re.split(r"(\d+)", filename.lower())
    return tuple(int(part) if part.isdigit() else part for part in parts)


def find_audio_files(folder: Path) -> list[Path]:
    logger.debug("Scanning audio folder: %s", str(folder))
    audio_files: list[Path] = []
    for f in folder.iterdir():
        if f.is_file() and f.suffix.lower() in AUDIO_EXTENSIONS:
            audio_files.append(f)
    audio_files.sort(key=lambda p: natural_sort_key(p.name))
    return audio_files


def clean_track_title(filename: str) -> str:
    """
    Best-effort title generation from filename.
    Keeps Unicode; only removes extension and normalizes underscores/hyphens.
    """
    name = Path(filename).stem
    name = name.replace("_", " ").replace("-", " ")
    name = " ".join(word.capitalize() for word in name.split())
    return name


def get_audio_duration_ms(audio_path: Path) -> int:
    if sf is None:
        raise ImportError("soundfile is required. Install with: pip install soundfile")
    try:
        logger.debug("Reading audio metadata (duration): %s", str(audio_path))
        info = sf.info(str(audio_path))
        return int(info.duration * 1000)
    except Exception:
        return 0


