from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


def artifact_path(dir_path: Path, audio_filename: str, kind: str) -> Path:
    """
    Store artifacts using the original audio filename for readability.
    Example: 'Track 01.mp3.curated.json'
    """
    return dir_path / f"{audio_filename}.{kind}.json"


def load_json_if_exists(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        logger.debug("Artifact not found (skipping read): %s", str(path))
        return None
    logger.debug("Reading JSON artifact: %s", str(path))
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    logger.debug("Writing JSON artifact: %s", str(path))
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")


