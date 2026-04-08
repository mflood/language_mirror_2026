#!/usr/bin/env python3
"""
Step 1: Generate a multi-speaker narration script from a topic description.

Uses Anthropic Claude (or OpenAI as fallback) to produce structured JSON
suitable for step 2 (Polly TTS synthesis). Output goes to:

    sample_bundle_pipeline/samples/<bundle_id>/script.json

Defaults to a dry-run that prints the prompt without calling the LLM.
Pass --commit to actually make the API call.

Usage:
    python sample_bundle_pipeline/1_generate_script.py \\
        --bundle-id starter_coffee \\
        --topic "Two friends order coffee at a Seoul cafe" \\
        --language ko-KR \\
        --duration-seconds 60 \\
        --num-speakers 2 \\
        [--commit]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
SAMPLES_DIR = REPO_ROOT / "sample_bundle_pipeline" / "samples"


# Default voice maps per language. Step 2 uses these if a turn doesn't specify
# a voice explicitly. Voice ids are AWS Polly neural voice ids.
DEFAULT_VOICE_MAPS: dict[str, list[str]] = {
    "ko-KR": ["Seoyeon", "Jihye"],  # both are female; only differentiation available on Polly today
    "en-US": ["Joanna", "Matthew"],
    "en-GB": ["Amy", "Brian"],
    "ja-JP": ["Takumi", "Kazuha"],
    "es-ES": ["Lucia", "Sergio"],
    "fr-FR": ["Lea", "Remi"],
    "de-DE": ["Vicki", "Daniel"],
    "zh-CN": ["Zhiyu"],
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate a Language Mirror narration script")
    p.add_argument("--bundle-id", required=True, help="Folder name for samples/<bundle_id>/")
    p.add_argument("--topic", help="Topic description (or pass via --topic-file)")
    p.add_argument("--topic-file", type=Path, help="Read the topic from a file (e.g. samples/<id>/topic.md)")
    p.add_argument("--language", default="ko-KR", help="BCP-47 language code (default: ko-KR)")
    p.add_argument("--duration-seconds", type=int, default=60, help="Target audio duration (default: 60)")
    p.add_argument("--num-speakers", type=int, default=2, help="Number of speakers (default: 2)")
    p.add_argument("--style", default="natural conversation", help="Style hint (e.g. 'narrative', 'interview')")
    p.add_argument(
        "--provider",
        choices=("anthropic", "openai"),
        default="anthropic",
        help="Which LLM provider to use (default: anthropic)",
    )
    p.add_argument(
        "--model",
        default=None,
        help="Override model id. Defaults: claude-sonnet-4-5 / gpt-4o-mini",
    )
    p.add_argument("--commit", action="store_true", help="Actually call the LLM API. Default is dry-run.")
    p.add_argument("--output", type=Path, default=None, help="Override output path (default: samples/<id>/script.json)")
    return p.parse_args()


def build_prompt(topic: str, language: str, duration_seconds: int, num_speakers: int, style: str) -> str:
    voices = DEFAULT_VOICE_MAPS.get(language, ["Speaker1", "Speaker2"])
    voice_hint = ", ".join(voices)
    return f"""You are writing a short audio script for a language-learning app.

Topic: {topic}
Language: {language}
Target duration when read aloud: about {duration_seconds} seconds
Number of speakers: {num_speakers}
Style: {style}

Constraints:
- Write in {language}. Do NOT include English translations or romanization.
- Use natural, conversational phrasing appropriate for an intermediate learner.
- Each turn should be a single complete sentence (one breath, one thought).
- Aim for sentences between 5 and 18 words. Avoid very long run-on sentences.
- Total combined character count should land near {duration_seconds * 12} characters
  (Polly speaks ~12 chars/sec for most languages).
- Speakers alternate naturally; the first speaker is always "A".
- Available Polly neural voice ids for this language: {voice_hint}.
  Assign the first speaker the first voice, second speaker the second, etc.

Return ONLY a JSON object matching this schema, with no markdown fences or
prose outside the JSON:

{{
  "topic": "<echo of the topic>",
  "language": "{language}",
  "title": "<short human-readable title, 2-6 words, in the target language>",
  "english_title": "<same title in English for QA>",
  "turns": [
    {{
      "speaker": "A",
      "voice": "{voices[0]}",
      "text": "<sentence in {language}>"
    }},
    {{
      "speaker": "B",
      "voice": "{voices[-1]}",
      "text": "<sentence in {language}>"
    }}
    // ... continue alternating until target duration is reached
  ]
}}
"""


def call_anthropic(prompt: str, model: str) -> str:
    try:
        from anthropic import Anthropic
    except ImportError:
        raise SystemExit("anthropic package not installed. pip install anthropic")
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise SystemExit("ANTHROPIC_API_KEY is not set")
    client = Anthropic(api_key=api_key)
    msg = client.messages.create(
        model=model,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    # Concatenate text blocks
    parts = []
    for block in msg.content:
        if getattr(block, "type", None) == "text":
            parts.append(block.text)
    return "".join(parts).strip()


def call_openai(prompt: str, model: str) -> str:
    try:
        from openai import OpenAI
    except ImportError:
        raise SystemExit("openai package not installed. pip install openai")
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is not set")
    client = OpenAI(api_key=api_key)
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are an expert language script writer. Output only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.4,
    )
    return (resp.choices[0].message.content or "").strip()


def strip_markdown_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        first_newline = text.find("\n")
        if first_newline != -1:
            text = text[first_newline + 1 :]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def validate_script(parsed: dict[str, Any]) -> None:
    required = {"topic", "language", "title", "turns"}
    missing = required - set(parsed.keys())
    if missing:
        raise SystemExit(f"LLM output missing required keys: {sorted(missing)}")
    if not isinstance(parsed["turns"], list) or not parsed["turns"]:
        raise SystemExit("'turns' must be a non-empty list")
    for i, turn in enumerate(parsed["turns"]):
        if not all(k in turn for k in ("speaker", "voice", "text")):
            raise SystemExit(f"Turn {i} missing speaker/voice/text")


def main() -> int:
    args = parse_args()

    # Load topic
    topic = args.topic
    if not topic and args.topic_file:
        topic = args.topic_file.read_text(encoding="utf-8").strip()
    if not topic:
        # Try samples/<id>/topic.md
        candidate = SAMPLES_DIR / args.bundle_id / "topic.md"
        if candidate.exists():
            topic = candidate.read_text(encoding="utf-8").strip()
            print(f"📖 Loaded topic from {candidate}")
    if not topic:
        print("❌ No topic provided. Pass --topic, --topic-file, or create samples/<id>/topic.md", file=sys.stderr)
        return 1

    out_path = args.output or (SAMPLES_DIR / args.bundle_id / "script.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    prompt = build_prompt(
        topic=topic,
        language=args.language,
        duration_seconds=args.duration_seconds,
        num_speakers=args.num_speakers,
        style=args.style,
    )

    model = args.model or ("claude-sonnet-4-5" if args.provider == "anthropic" else "gpt-4o-mini")

    print("═══ Plan ═══")
    print(f"  Bundle:    {args.bundle_id}")
    print(f"  Topic:     {topic[:80]}{'…' if len(topic) > 80 else ''}")
    print(f"  Language:  {args.language}")
    print(f"  Duration:  ~{args.duration_seconds}s")
    print(f"  Speakers:  {args.num_speakers}")
    print(f"  Provider:  {args.provider}")
    print(f"  Model:     {model}")
    print(f"  Output:    {out_path}")
    print()

    if not args.commit:
        print("--- DRY RUN — prompt that WOULD be sent ---")
        print(prompt)
        print()
        print("Re-run with --commit to actually call the LLM.")
        return 0

    print(f"📡 Calling {args.provider} ({model})...")
    if args.provider == "anthropic":
        raw = call_anthropic(prompt, model)
    else:
        raw = call_openai(prompt, model)

    cleaned = strip_markdown_fences(raw)
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError as e:
        print("❌ LLM did not return valid JSON.", file=sys.stderr)
        print("Raw output:", file=sys.stderr)
        print(cleaned, file=sys.stderr)
        raise SystemExit(f"JSON parse error: {e}")

    validate_script(parsed)

    out_path.write_text(json.dumps(parsed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Wrote {out_path}")

    total_chars = sum(len(t["text"]) for t in parsed["turns"])
    estimated_seconds = total_chars / 12
    print(f"📊 {len(parsed['turns'])} turns, {total_chars} characters total")
    print(f"📊 Estimated audio duration when synthesized: ~{estimated_seconds:.1f} seconds")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
