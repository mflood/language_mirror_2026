from __future__ import annotations

from pathlib import Path
from typing import Any


def transcribe_with_whisper(audio_path: Path, model_name: str, language_code: str | None) -> dict[str, Any]:
    """
    Runs Whisper and returns the raw transcription result.
    language_code can be a BCP-47 tag; Whisper wants base language like 'ko', 'en', ...
    """
    import whisper

    whisper_lang = None
    if language_code:
        whisper_lang = language_code.split("-")[0] if "-" in language_code else language_code

    model = whisper.load_model(model_name)
    return model.transcribe(
        str(audio_path),
        language=whisper_lang,
        word_timestamps=True,
        verbose=False,
    )


def extract_segments_for_llm(whisper_result: dict[str, Any]) -> list[dict[str, Any]]:
    """
    Reduce raw Whisper output to a stable, compact form for LLM prompts.
    """
    segments_out: list[dict[str, Any]] = []
    for s in whisper_result.get("segments", []) or []:
        seg: dict[str, Any] = {
            "start": s.get("start", 0),
            "end": s.get("end", 0),
            "text": (s.get("text") or "").strip(),
        }
        if "words" in s and s["words"]:
            seg["words"] = [
                {"word": (w.get("word") or ""), "start": w.get("start", 0), "end": w.get("end", 0)}
                for w in (s.get("words") or [])
            ]
        segments_out.append(seg)
    return segments_out


