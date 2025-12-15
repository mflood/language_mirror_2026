from __future__ import annotations

import json
import os
from typing import Any


def _language_hint(language_code: str | None) -> str:
    if not language_code:
        return ""
    return f"\nLanguage: {language_code}"


def build_curation_prompt(segments: list[dict[str, Any]], audio_duration_ms: int, language_code: str | None) -> str:
    segments_json = json.dumps(segments, ensure_ascii=False, indent=2)
    hint = _language_hint(language_code)
    return f"""You are analyzing audio transcription to create practice clips for language learning.

Audio Duration: {audio_duration_ms} ms{hint}

Transcription segments with timestamps (in seconds):
{segments_json}

Your task:
1. Identify sentence boundaries in the text
2. Detect any noise/music sections (typically at start/end with no speech or very short duration)
3. Identify speakers based on speech patterns and timing gaps (label as \"Speaker 1\", \"Speaker 2\", etc.)
4. Create practice clips:
   - One \"drill\" clip for EACH sentence/transcript span
   - \"skip\" or \"noise\" clips for any music/noise sections at the beginning or end
5. IMPORTANT: Every transcript span should have a corresponding \"drill\" clip with matching timestamps

Output Format (JSON):
{{
  \"transcripts\": [
    {{
      \"startMs\": <start time in milliseconds>,
      \"endMs\": <end time in milliseconds>,
      \"text\": \"<text>\",
      \"speaker\": \"<speaker label>\"
    }}
  ],
  \"clips\": [
    {{
      \"startMs\": <start time in milliseconds>,
      \"endMs\": <end time in milliseconds>,
      \"kind\": \"drill\" or \"skip\" or \"noise\",
      \"title\": \"<brief description, e.g., 'Sentence 1' or 'Intro music'>\"
    }}
  ]
}}

Guidelines:
- Convert all times from seconds to milliseconds
- Each sentence should have its own transcript span
- Each transcript span MUST have a corresponding \"drill\" clip with the same timestamps
- Transcripts should be chronological and non-overlapping
- Clips should be chronological and non-overlapping
- Keep speaker labels consistent throughout

Respond ONLY with the JSON structure, no additional text."""


def curate_with_openai(model: str, prompt: str) -> dict[str, Any]:
    """
    Calls OpenAI chat completions and returns parsed JSON.
    Requires OPENAI_API_KEY in environment.
    """
    from openai import OpenAI

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY environment variable not set")

    client = OpenAI(api_key=api_key)
    # Newer OpenAI models require `max_completion_tokens` (and reject `max_tokens`).
    # Some older models/servers may still expect `max_tokens`, so we retry once if needed.
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are an expert in language transcription analysis."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_completion_tokens=8192,
        )
    except Exception as e:
        msg = str(e)
        if "Unsupported parameter" in msg and "max_completion_tokens" in msg:
            resp = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are an expert in language transcription analysis."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.3,
                max_tokens=8192,
            )
        else:
            raise
    text = (resp.choices[0].message.content or "").strip()
    if text.startswith("```json"):
        text = text[7:]
    if text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()
    return json.loads(text)


