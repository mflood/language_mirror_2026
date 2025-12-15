from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class WorkPaths:
    work_root: Path
    bundle_id: str

    @property
    def bundle_root(self) -> Path:
        return self.work_root / self.bundle_id

    @property
    def audio_dir(self) -> Path:
        return self.bundle_root / "audio"

    @property
    def artifacts_dir(self) -> Path:
        return self.bundle_root / "artifacts"

    @property
    def whisper_dir(self) -> Path:
        return self.artifacts_dir / "whisper"

    @property
    def curated_dir(self) -> Path:
        return self.artifacts_dir / "curated"

    @property
    def manifest_path(self) -> Path:
        return self.bundle_root / "bundle.json"

    @property
    def config_path(self) -> Path:
        return self.bundle_root / "bundle.yaml"

    @property
    def qr_path(self) -> Path:
        return self.bundle_root / "qr.png"

    def ensure_dirs(self) -> None:
        self.bundle_root.mkdir(parents=True, exist_ok=True)
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self.whisper_dir.mkdir(parents=True, exist_ok=True)
        self.curated_dir.mkdir(parents=True, exist_ok=True)


