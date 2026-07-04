#!/usr/bin/env python3
"""
Step 2b: Per-sentence English translations for the easy Korean summary.

The script generator (step 2) produces `summary_ko_easy` (4-9 short 해요-form
sentences) but only a 3-sentence `summary_en` aligned with the *natural*
summary — so the easy sentences have no per-sentence English. This step fills
the gap: it translates each easy-summary sentence and writes the result back
into script.json as `summary_en_easy`, 1:1 aligned with `summary_ko_easy`.

Step 4 (assemble) then attaches these as `translations` on the transcript
spans, so the app can show the English for any easy-summary clip.

Idempotent: stories that already have a well-formed `summary_en_easy`
(same length as `summary_ko_easy`) are skipped. Safe to run as a backfill
against any older work/<date>/ directory.

Output:
    work/<date>/script.json  (updated in place; original kept as .bak)

Usage:
    python 2b_translate_easy.py [--date YYYY-MM-DD] [--force]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

import yaml

from cost_tracker import StepCostRecorder
from llm_providers import LLMProvider, provider_for_step, max_tokens_for_step

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Translate easy-summary sentences to English")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--force", action="store_true",
                   help="Re-translate even if summary_en_easy already exists")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def build_prompt(story: dict) -> str:
    sentences = story["summary_ko_easy"]
    numbered = "\n".join(f"{i + 1}. {s}" for i, s in enumerate(sentences))
    return f"""Translate each numbered Korean sentence into natural, simple English.
These are sentences from an easy Korean news summary for language learners.
Context — the story headline: {story.get('headline', '(unknown)')}

Rules:
- Translate each sentence independently and faithfully (no merging, no adding facts).
- Keep the English simple and natural, matching the easy register of the Korean.
- Return ONLY a JSON array of strings, one per sentence, same order, same count ({len(sentences)}).

Korean sentences:
{numbered}"""


def parse_response(text: str, expected_count: int) -> list[str]:
    """Extract the JSON array from the LLM response, tolerating code fences."""
    m = re.search(r"\[.*\]", text, re.DOTALL)
    if not m:
        raise ValueError(f"no JSON array in response: {text[:200]}")
    arr = json.loads(m.group(0))
    if not isinstance(arr, list) or not all(isinstance(s, str) for s in arr):
        raise ValueError("response is not a JSON array of strings")
    if len(arr) != expected_count:
        raise ValueError(f"expected {expected_count} translations, got {len(arr)}")
    return arr


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()
    work_dir = WORK_ROOT / date

    script_path = work_dir / "script.json"
    if not script_path.exists():
        raise SystemExit(f"❌ script.json not found at {script_path}. Run step 2 first.")

    script = json.loads(script_path.read_text(encoding="utf-8"))

    llm_cfg = yaml.safe_load((HERE / "llm.yaml").read_text(encoding="utf-8"))
    provider: LLMProvider = provider_for_step("translate_easy", llm_cfg)
    max_tokens = max_tokens_for_step("translate_easy", llm_cfg)

    recorder = StepCostRecorder("2b_translate_easy", work_dir)

    translated = 0
    skipped = 0
    for story in script["stories"]:
        ko = story.get("summary_ko_easy") or []
        if not ko:
            print(f"  ⏭  {story['story_id']}: no summary_ko_easy, skipping")
            skipped += 1
            continue
        existing = story.get("summary_en_easy") or []
        if not args.force and len(existing) == len(ko):
            print(f"  ⏭  {story['story_id']}: summary_en_easy already present ({len(ko)} sentences)")
            skipped += 1
            continue

        print(f"  📡 {story['story_id']}: translating {len(ko)} sentences → {provider.name}/{provider.model}")
        resp = provider.chat(build_prompt(story), max_tokens=max_tokens)
        cost = recorder.add_llm_call(
            provider=resp.provider, model=resp.model,
            input_tokens=resp.input_tokens, output_tokens=resp.output_tokens,
            label=f"translate_easy:{story['story_id']}", response_chars=len(resp.text),
        )
        story["summary_en_easy"] = parse_response(resp.text, len(ko))
        print(f"     ✓ input={resp.input_tokens} output={resp.output_tokens} tokens  est_cost=${cost:.4f}")
        translated += 1

    if translated:
        backup = script_path.with_suffix(".json.bak")
        if not backup.exists():
            backup.write_text(script_path.read_text(encoding="utf-8"), encoding="utf-8")
        script_path.write_text(json.dumps(script, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        recorder.write()
        print(f"✅ Updated {script_path} ({translated} stories translated, {skipped} skipped)")
    else:
        print(f"✅ Nothing to do ({skipped} stories skipped)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
