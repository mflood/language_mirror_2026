from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal


ClipKind = Literal["drill", "skip", "noise"]


@dataclass(frozen=True)
class Clip:
    id: str
    startMs: int
    endMs: int
    kind: ClipKind
    title: str | None = None
    repeats: int | None = None
    startSpeed: float | None = None
    endSpeed: float | None = None
    languageCode: str | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "startMs": self.startMs,
            "endMs": self.endMs,
            "kind": self.kind,
            "title": self.title,
            "repeats": self.repeats,
            "startSpeed": self.startSpeed,
            "endSpeed": self.endSpeed,
            "languageCode": self.languageCode,
        }


@dataclass(frozen=True)
class PracticeSet:
    id: str
    trackId: str
    displayOrder: int
    title: str | None
    clips: list[Clip]
    isFavorite: bool = False

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "trackId": self.trackId,
            "displayOrder": self.displayOrder,
            "title": self.title,
            "clips": [c.to_json() for c in self.clips],
            "isFavorite": self.isFavorite,
        }


@dataclass(frozen=True)
class TranscriptSpan:
    startMs: int
    endMs: int
    text: str
    speaker: str | None = None
    languageCode: str | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "startMs": self.startMs,
            "endMs": self.endMs,
            "text": self.text,
            "speaker": self.speaker,
            "languageCode": self.languageCode,
        }


@dataclass(frozen=True)
class BundleTrack:
    id: str | None
    title: str
    url: str | None
    filename: str | None
    durationMs: int | None
    languageCode: str | None
    practiceSets: list[PracticeSet] | None
    transcripts: list[TranscriptSpan] | None

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "url": self.url,
            "filename": self.filename,
            "durationMs": self.durationMs,
            "languageCode": self.languageCode,
            "practiceSets": None if self.practiceSets is None else [ps.to_json() for ps in self.practiceSets],
            "transcripts": None if self.transcripts is None else [t.to_json() for t in self.transcripts],
        }


@dataclass(frozen=True)
class BundlePack:
    id: str | None
    title: str
    author: str | None
    coverUrl: str | None
    coverFilename: str | None
    tracks: list[BundleTrack]

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "author": self.author,
            "coverUrl": self.coverUrl,
            "coverFilename": self.coverFilename,
            "tracks": [t.to_json() for t in self.tracks],
        }


@dataclass(frozen=True)
class BundleManifest:
    id: str | None
    title: str
    packs: list[BundlePack]

    def to_json(self) -> dict[str, Any]:
        return {"id": self.id, "title": self.title, "packs": [p.to_json() for p in self.packs]}


