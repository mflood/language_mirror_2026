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
      \"title\": \"<brief label, e.g., 'Sentence 1' or 'Intro music'>\"
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


MAX_SNIPPET_LEN = 25


def enrich_clip_titles(curated: dict[str, Any]) -> dict[str, Any]:
    """Replace generic 'Sentence N' clip titles with numbered transcript snippets.

    For each drill clip, find the transcript span that overlaps its time range
    and set the title to  ``"<N>. <snippet…>"``.  Non-drill clips (skip, noise)
    are left unchanged.
    """
    transcripts = curated.get("transcripts") or []
    clips = curated.get("clips") or []

    drill_num = 0
    for clip in clips:
        if clip.get("kind") != "drill":
            continue
        drill_num += 1
        # Find best-matching transcript by time overlap
        best_text = ""
        best_overlap = 0
        c_start = clip["startMs"]
        c_end = clip["endMs"]
        for t in transcripts:
            overlap_start = max(c_start, t["startMs"])
            overlap_end = min(c_end, t["endMs"])
            overlap = max(0, overlap_end - overlap_start)
            if overlap > best_overlap:
                best_overlap = overlap
                best_text = t.get("text", "")
        if best_text:
            snippet = best_text if len(best_text) <= MAX_SNIPPET_LEN else best_text[:MAX_SNIPPET_LEN] + "…"
            clip["title"] = f"{drill_num}. {snippet}"
        else:
            clip["title"] = f"Sentence {drill_num}"

    return curated


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


