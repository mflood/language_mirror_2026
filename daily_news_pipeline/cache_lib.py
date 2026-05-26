"""
Phrase library and content-addressed audio cache for the daily news pipeline.

Storage layout:
    cache/
      library.json                ← LEAN INDEX (vocab + examples; audio_keys are pointers)
      audio/
        <audio_key>.mp3           ← actual audio
        <audio_key>.json          ← SIDECAR metadata (provider, voice, cost, etc.)
      cost_history/
        YYYY/MM/
          YYYY-MM-DD_HHMMSS.json  ← one file per pipeline run (timestamped)

Audio is content-addressed: the key is sha256(text + provider + voice_id + model + settings).
Identical text under identical config always lands on the same key — switching
voices/models/providers naturally invalidates the cache, which is correct.

Three tiers of reuse:
  Tier 1 — Static phrases (section headers like 어휘) — same text every day → cache hits
  Tier 2 — Vocab words — keyed by Korean word; canonical English gloss locked on first use
  Tier 3 — Example sentences — tagged with covered vocab; reused via greedy set cover

Audio variants:
  Each vocab/example can have MULTIPLE cached audio variants (different
  providers/voices/models). audio_keys["ko"] is a list of pointers. When step 3
  needs Korean audio for 협상 under provider=elevenlabs/voice=X, it computes the
  current audio_key, hits cache/audio/<key>.mp3 if present, else synthesizes and
  appends a new variant.
"""

from __future__ import annotations

import hashlib
import json
import shutil
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


LIBRARY_VERSION = 2


def compute_audio_key(text: str, provider: str, voice_id: str, model: str, settings: dict) -> str:
    """
    Content-addressed audio key. Includes provider in the hash so that
    polly+Seoyeon and elevenlabs+VoiceX renderings of 협상 land on distinct keys
    (and distinct on-disk files).
    """
    payload = {
        "text": text,
        "provider": provider,
        "model": model,
        "voice_id": voice_id,
        "settings": dict(sorted((settings or {}).items())),
    }
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:24]


@dataclass
class Library:
    root: Path
    data: dict[str, Any] = field(default_factory=dict)

    @property
    def audio_dir(self) -> Path:
        return self.root / "audio"

    @property
    def index_path(self) -> Path:
        return self.root / "library.json"

    @property
    def cost_history_root(self) -> Path:
        return self.root / "cost_history"

    # ─── load / save ──────────────────────────────────────────────────────────

    @classmethod
    def load(cls, root: Path) -> "Library":
        root.mkdir(parents=True, exist_ok=True)
        (root / "audio").mkdir(exist_ok=True)
        (root / "cost_history").mkdir(exist_ok=True)
        lib = cls(root=root)
        if lib.index_path.exists():
            lib.data = json.loads(lib.index_path.read_text(encoding="utf-8"))
            lib._migrate_if_needed()
        else:
            lib.data = {
                "version": LIBRARY_VERSION,
                "vocab": {},      # ko_word → {canonical_en, first_used, uses, audio_keys: {ko:[], en:[]}}
                "examples": [],   # list of {ko, en, vocab_covered, first_used, uses, audio_keys: {ko:[], en:[]}}
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
        return lib

    def _migrate_if_needed(self) -> None:
        """Convert old (v1) schema entries to v2 (audio_keys as lists)."""
        version = self.data.get("version", 1)
        if version >= LIBRARY_VERSION:
            return
        # v1 had vocab[ko].ko_audio_key (single string or None). v2 has audio_keys lists.
        for ko, info in self.data.get("vocab", {}).items():
            if "audio_keys" in info:
                continue
            ko_key = info.pop("ko_audio_key", None)
            en_key = info.pop("en_audio_key", None)
            info["audio_keys"] = {
                "ko": [ko_key] if ko_key else [],
                "en": [en_key] if en_key else [],
            }
        for ex in self.data.get("examples", []):
            if "audio_keys" in ex:
                continue
            ko_key = ex.pop("ko_audio_key", None)
            en_key = ex.pop("en_audio_key", None)
            ex["audio_keys"] = {
                "ko": [ko_key] if ko_key else [],
                "en": [en_key] if en_key else [],
            }
        self.data["version"] = LIBRARY_VERSION

    def save(self) -> None:
        tmp = self.index_path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(self.data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        tmp.replace(self.index_path)

    # ─── audio cache (content-addressed) + sidecar metadata ──────────────────

    def audio_path(self, audio_key: str) -> Path:
        return self.audio_dir / f"{audio_key}.mp3"

    def sidecar_path(self, audio_key: str) -> Path:
        return self.audio_dir / f"{audio_key}.json"

    def get_cached_audio(self, audio_key: str) -> Path | None:
        p = self.audio_path(audio_key)
        return p if p.exists() and p.stat().st_size > 0 else None

    def put_audio(self, audio_key: str, src_path: Path, metadata: dict) -> Path:
        """
        Copy a freshly-synthesized mp3 into the cache and write its sidecar
        metadata. Returns the cached audio path.

        `metadata` should include at minimum:
          text, lang, provider, model, voice_id, settings, chars_debited,
          estimated_cost_usd, duration_ms, library_role, library_text_key.
        We add audio_key + created_at automatically.
        """
        dest = self.audio_path(audio_key)
        if not dest.exists():
            shutil.copy2(src_path, dest)
        sidecar = self.sidecar_path(audio_key)
        full = {
            "audio_key": audio_key,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            **metadata,
        }
        sidecar.write_text(json.dumps(full, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        return dest

    def get_sidecar(self, audio_key: str) -> dict | None:
        p = self.sidecar_path(audio_key)
        return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None

    # ─── vocab (Tier 2) ──────────────────────────────────────────────────────

    def lookup_vocab(self, ko: str) -> dict | None:
        return self.data["vocab"].get(ko)

    def record_vocab(self, ko: str, en: str, today: str) -> None:
        if ko in self.data["vocab"]:
            self.data["vocab"][ko]["uses"] = self.data["vocab"][ko].get("uses", 0) + 1
            return
        self.data["vocab"][ko] = {
            "canonical_en": en,
            "first_used": today,
            "uses": 1,
            "audio_keys": {"ko": [], "en": []},
        }

    def attach_vocab_audio(self, ko: str, lang: str, audio_key: str) -> None:
        """Add an audio_key to a vocab entry (no-op if already present)."""
        entry = self.data["vocab"].get(ko)
        if not entry:
            return
        keys = entry.setdefault("audio_keys", {}).setdefault(lang, [])
        if audio_key not in keys:
            keys.append(audio_key)

    # ─── examples (Tier 3) ────────────────────────────────────────────────────

    def find_examples_covering(self, vocab_list: list[str], max_n: int = 12) -> tuple[list[dict], set[str]]:
        """Greedy set cover over cached examples. Returns (chosen, uncovered_vocab)."""
        remaining = set(vocab_list)
        chosen: list[dict] = []
        available = list(self.data["examples"])

        while remaining and len(chosen) < max_n:
            best = None
            best_n = 0
            for ex in available:
                if ex in chosen:
                    continue
                n = len(set(ex["vocab_covered"]) & remaining)
                if n > best_n:
                    best = ex
                    best_n = n
            if best_n == 0 or best is None:
                break
            chosen.append(best)
            remaining -= set(best["vocab_covered"])

        return chosen, remaining

    def record_example(self, ko: str, en: str, vocab_covered: list[str], today: str) -> dict:
        for ex in self.data["examples"]:
            if ex["ko"] == ko:
                ex["uses"] = ex.get("uses", 0) + 1
                ex["vocab_covered"] = sorted(set(ex["vocab_covered"]) | set(vocab_covered))
                return ex
        ex = {
            "ko": ko,
            "en": en,
            "vocab_covered": sorted(vocab_covered),
            "first_used": today,
            "uses": 1,
            "audio_keys": {"ko": [], "en": []},
        }
        self.data["examples"].append(ex)
        return ex

    def attach_example_audio(self, ko: str, lang: str, audio_key: str) -> None:
        for ex in self.data["examples"]:
            if ex["ko"] == ko:
                keys = ex.setdefault("audio_keys", {}).setdefault(lang, [])
                if audio_key not in keys:
                    keys.append(audio_key)
                return

    # ─── stats ────────────────────────────────────────────────────────────────

    def stats_summary(self) -> dict:
        audio_files = list(self.audio_dir.glob("*.mp3"))
        total_bytes = sum(p.stat().st_size for p in audio_files)
        return {
            "vocab_terms": len(self.data["vocab"]),
            "example_sentences": len(self.data["examples"]),
            "audio_files_on_disk": len(audio_files),
            "audio_bytes_on_disk": total_bytes,
        }
