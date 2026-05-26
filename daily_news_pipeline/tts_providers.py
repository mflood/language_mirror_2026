"""
TTS provider abstraction. Two implementations today: ElevenLabs and AWS Polly.

Step 3 selects a provider via `tts.yaml` (or `--tts <name>` CLI flag) and calls
`provider.synth_to_file(text, speaker, lang, out_path)`. The audio cache key is
derived from (text, provider, voice_id, model, settings) so different providers'
renderings of the same text get distinct cache entries — never collide.

Adding a new provider: subclass `TTSProvider`, implement `synth_to_file`, register
in `make_provider()` and `PROVIDERS_BY_NAME`.
"""

from __future__ import annotations

import os
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class VoiceInfo:
    voice_id: str
    voice_label: str


class TTSProvider(ABC):
    name: str                # e.g. "elevenlabs" / "polly"
    tier_or_engine: str      # e.g. "creator" / "neural" — for cost lookup
    model: str               # provider-specific model id

    @abstractmethod
    def voice_for_speaker(self, speaker: str) -> VoiceInfo:
        """Return voice info for speaker letter ('A' or 'B')."""

    @abstractmethod
    def settings_for_audio_key(self) -> dict:
        """Return the dict of settings that goes into the audio_key hash.
        Provider-specific knobs that should invalidate cache when changed."""

    @abstractmethod
    def synth_to_file(self, text: str, speaker: str, lang: str, out_path: Path) -> dict:
        """Synthesize text → mp3 at out_path. Returns metadata for sidecar."""

    def metadata(self, speaker: str, lang: str) -> dict:
        v = self.voice_for_speaker(speaker)
        return {
            "provider": self.name,
            "tier_or_engine": self.tier_or_engine,
            "model": self.model,
            "voice_id": v.voice_id,
            "voice_label": v.voice_label,
            "settings": self.settings_for_audio_key(),
        }


# ─── ElevenLabs ───────────────────────────────────────────────────────────────


MAX_RETRIES = 4


class ElevenLabsProvider(TTSProvider):
    name = "elevenlabs"

    def __init__(self, cfg: dict) -> None:
        try:
            from elevenlabs import ElevenLabs, VoiceSettings
        except ImportError as e:
            raise SystemExit(f"elevenlabs package required: {e}")
        api_key = os.getenv("ELEVENLABS_API_KEY")
        if not api_key:
            raise SystemExit("ELEVENLABS_API_KEY is not set")
        self.cfg = cfg
        self._VoiceSettings = VoiceSettings
        self._client = ElevenLabs(api_key=api_key)
        self.tier_or_engine = cfg.get("tier", "creator")
        self.model = cfg.get("model_id", "eleven_multilingual_v2")
        self._stability = float(cfg.get("stability", 0.5))
        self._similarity_boost = float(cfg.get("similarity_boost", 0.75))
        self._style = float(cfg.get("style", 0.0))

    def voice_for_speaker(self, speaker: str) -> VoiceInfo:
        key = "voice_a" if speaker == "A" else "voice_b"
        v = self.cfg.get(key)
        if not v or not v.get("id") or "PLACEHOLDER" in v["id"]:
            raise SystemExit(f"elevenlabs.{key}.id missing or placeholder in tts.yaml")
        return VoiceInfo(voice_id=v["id"], voice_label=v.get("label", ""))

    def settings_for_audio_key(self) -> dict:
        return {"stability": self._stability, "similarity_boost": self._similarity_boost, "style": self._style}

    def synth_to_file(self, text: str, speaker: str, lang: str, out_path: Path) -> dict:
        v = self.voice_for_speaker(speaker)
        settings_obj = self._VoiceSettings(
            stability=self._stability,
            similarity_boost=self._similarity_boost,
            style=self._style,
        )
        last_error: Exception | None = None
        for attempt in range(MAX_RETRIES):
            try:
                audio_iter = self._client.text_to_speech.convert(
                    voice_id=v.voice_id,
                    text=text,
                    model_id=self.model,
                    output_format="mp3_44100_128",
                    voice_settings=settings_obj,
                )
                with open(out_path, "wb") as f:
                    for chunk in audio_iter:
                        if chunk:
                            f.write(chunk)
                return self.metadata(speaker, lang)
            except Exception as e:
                last_error = e
                status = getattr(e, "status_code", None) or getattr(e, "status", None)
                if status == 402:
                    raise SystemExit(
                        f"❌ ElevenLabs 402 payment_required: voice {v.voice_id} requires a paid plan.\n"
                        f"   Upgrade the subscription or switch tts.yaml to a different voice."
                    )
                retryable = status == 429 or (isinstance(status, int) and 500 <= status < 600)
                if attempt == MAX_RETRIES - 1 or not retryable:
                    break
                delay = 2 ** attempt
                print(f"     ⚠ transient error ({status or 'unknown'}); retrying in {delay}s")
                time.sleep(delay)
        raise SystemExit(f"❌ ElevenLabs failed after {attempt + 1} attempt(s): {last_error}")


# ─── AWS Polly ────────────────────────────────────────────────────────────────


class PollyProvider(TTSProvider):
    name = "polly"

    LANG_CODES = {"en": "en-US", "ko": "ko-KR"}

    def __init__(self, cfg: dict) -> None:
        try:
            import boto3
        except ImportError as e:
            raise SystemExit(f"boto3 package required: {e}")
        self.cfg = cfg
        self._client = boto3.client("polly")
        self.tier_or_engine = cfg.get("engine", "neural")  # 'neural' | 'standard' | 'generative'
        self.model = self.tier_or_engine

    def voice_for_speaker(self, speaker: str) -> VoiceInfo:
        key = "voice_a" if speaker == "A" else "voice_b"
        v = self.cfg.get(key)
        if not v or not v.get("id"):
            raise SystemExit(f"polly.{key}.id missing in tts.yaml")
        return VoiceInfo(voice_id=v["id"], voice_label=v.get("label", ""))

    def settings_for_audio_key(self) -> dict:
        return {"engine": self.tier_or_engine}

    def synth_to_file(self, text: str, speaker: str, lang: str, out_path: Path) -> dict:
        v = self.voice_for_speaker(speaker)
        lang_code = self.LANG_CODES.get(lang, "en-US")
        last_error: Exception | None = None
        for attempt in range(MAX_RETRIES):
            try:
                resp = self._client.synthesize_speech(
                    Text=text,
                    OutputFormat="mp3",
                    VoiceId=v.voice_id,
                    Engine=self.tier_or_engine,
                    LanguageCode=lang_code,
                )
                with open(out_path, "wb") as f:
                    f.write(resp["AudioStream"].read())
                return self.metadata(speaker, lang)
            except Exception as e:
                last_error = e
                msg = str(e).lower()
                retryable = "throttl" in msg or "5" == str(getattr(e, "response", {}).get("Error", {}).get("Code", ""))[:1]
                if attempt == MAX_RETRIES - 1 or not retryable:
                    break
                delay = 2 ** attempt
                print(f"     ⚠ Polly transient error; retrying in {delay}s")
                time.sleep(delay)
        raise SystemExit(f"❌ Polly failed after {attempt + 1} attempt(s): {last_error}")


# ─── Factory ──────────────────────────────────────────────────────────────────


PROVIDERS_BY_NAME: dict[str, type[TTSProvider]] = {
    "elevenlabs": ElevenLabsProvider,
    "polly": PollyProvider,
}


def make_provider(name: str, full_cfg: dict) -> TTSProvider:
    if name not in PROVIDERS_BY_NAME:
        raise SystemExit(f"unknown TTS provider '{name}'. options: {sorted(PROVIDERS_BY_NAME)}")
    provider_cfg = full_cfg.get(name)
    if not provider_cfg:
        raise SystemExit(f"tts.yaml has no section for provider '{name}'")
    return PROVIDERS_BY_NAME[name](provider_cfg)
