#!/usr/bin/env python3
"""
Step 1: Curate. Read feeds.json, ask Claude to pick:
  - 3 hard-news stories with the broadest cross-source coverage
  - 1-2 feature stories (science/tech/sports/arts) — pick the most interesting

For each chosen story, fetch the full article body via trafilatura (max ~3000
chars) so step 2 has substantive material to summarize. Fair-use: we never
republish article body text — only our own generated summary makes it into the
pack.

Output:
    work/<YYYY-MM-DD>/chosen.json
      { "date": "...", "stories": [
            { "story_id": "story_1", "category": "hard"|"feature",
              "headline": "...", "source": "...", "link": "...",
              "body": "...", "rationale": "..." }, ... ] }

Safety: defaults to dry-run (prints the curation prompt). Pass --commit to
actually call Claude + fetch article bodies.

Usage:
    python 1_curate.py [--date YYYY-MM-DD] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

import yaml

from cost_tracker import StepCostRecorder
from llm_providers import LLMProvider, provider_for_step, max_tokens_for_step

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"
DEFAULT_LLM_CONFIG = HERE / "llm.yaml"

MAX_BODY_CHARS = 3000

_cost_recorder: StepCostRecorder | None = None
_llm: LLMProvider | None = None
_max_tokens: int = 2048


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Curate today's stories")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--config", type=Path, default=DEFAULT_LLM_CONFIG, help="llm.yaml path")
    p.add_argument("--commit", action="store_true", help="Actually call the LLM + fetch bodies.")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def build_curation_prompt(items: list[dict]) -> str:
    hard = [it for it in items if it["genre"] == "hard"]
    features = [it for it in items if it["genre"] != "hard"]

    def render(it: dict, i: int) -> str:
        title = it["title"]
        source = it["source"]
        summary = (it.get("summary") or "")[:300]
        return f"[{i}] ({source}) {title}\n    {summary}"

    hard_block = "\n".join(render(it, i) for i, it in enumerate(hard))
    feature_block = "\n".join(render(it, i + len(hard)) for i, it in enumerate(features))

    return f"""You are curating today's U.S. news for a Korean-language learning podcast.
The audience is English speakers learning Korean who want to stay in touch with
U.S. news (not Korean domestic news) while practicing Korean comprehension.

From the HARD NEWS pool below, pick the 3 most important stories — prioritize
stories covered by multiple major outlets (NPR, Reuters, AP, NYT, BBC), since
broad coverage signals importance. Avoid duplicates: if NPR and Reuters both
cover the same Fed decision, count that as one story and pick the version with
the best headline/summary.

From the FEATURE pool, pick 1 or 2 standout stories from science, tech, sports,
or arts/entertainment — the kind of "interesting bonus" that a thoughtful daily
brief would close on.

Total: 4 or 5 stories (3 hard + 1 or 2 features).

HARD NEWS POOL ({len(hard)} items):
{hard_block}

FEATURE POOL ({len(features)} items):
{feature_block}

Return ONLY a JSON object, no markdown fences, no prose:

{{
  "stories": [
    {{
      "index": <number from the brackets above>,
      "category": "hard" | "feature",
      "rationale": "<one sentence why this story made the cut>"
    }},
    ...
  ]
}}
"""


def call_llm(prompt: str, label: str = "curate") -> str:
    if _llm is None:
        raise SystemExit("LLM provider not initialized — should not happen")
    print(f"  📡 [{label}] → {_llm.name}")
    print(f"     model={_llm.model}  prompt_chars={len(prompt)}  max_tokens={_max_tokens}")
    resp = _llm.chat(prompt, max_tokens=_max_tokens)
    cost = 0.0
    if _cost_recorder is not None:
        cost = _cost_recorder.add_llm_call(
            provider=resp.provider, model=resp.model,
            input_tokens=resp.input_tokens, output_tokens=resp.output_tokens,
            label=label, response_chars=len(resp.text),
        )
    print(f"     ✓ usage: input={resp.input_tokens} output={resp.output_tokens} tokens  est_cost=${cost:.4f}  response_chars={len(resp.text)}")
    return resp.text


def strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        nl = text.find("\n")
        if nl != -1:
            text = text[nl + 1:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def fetch_body(url: str) -> str:
    """Fetch and extract the main article body. Returns truncated text."""
    try:
        import trafilatura
    except ImportError:
        raise SystemExit("trafilatura not installed. pip install trafilatura")
    print(f"     ↓ trafilatura GET {url}")
    downloaded = trafilatura.fetch_url(url)
    if not downloaded:
        print(f"     ⚠ trafilatura returned no HTML for {url}")
        return ""
    print(f"     ↓ fetched {len(downloaded)} bytes; extracting main content...")
    extracted = trafilatura.extract(downloaded, include_comments=False, include_tables=False)
    if not extracted:
        print(f"     ⚠ trafilatura could not extract main content")
        return ""
    body = extracted.strip()[:MAX_BODY_CHARS]
    print(f"     ✓ extracted {len(body)} chars (capped at {MAX_BODY_CHARS})")
    return body


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    feeds_path = WORK_ROOT / date / "feeds.json"
    if not feeds_path.exists():
        raise SystemExit(f"❌ feeds.json not found at {feeds_path}. Run step 0 first.")
    feeds_data = json.loads(feeds_path.read_text(encoding="utf-8"))
    items = feeds_data["items"]

    prompt = build_curation_prompt(items)
    out_path = WORK_ROOT / date / "chosen.json"

    if not args.config.exists():
        raise SystemExit(f"❌ llm.yaml not found: {args.config}")
    llm_cfg = yaml.safe_load(args.config.read_text(encoding="utf-8")) or {}

    print(f"═══ Curating {len(items)} items for {date} ═══")
    print(f"  Output:  {out_path}")
    print()

    if not args.commit:
        print("--- DRY RUN — prompt that WOULD be sent ---")
        print(prompt[:2000])
        if len(prompt) > 2000:
            print(f"... [truncated, full length {len(prompt)} chars] ...")
        print()
        print("Re-run with --commit to actually curate + fetch bodies.")
        return 0

    global _cost_recorder, _llm, _max_tokens
    _cost_recorder = StepCostRecorder("1_curate", WORK_ROOT / date)
    _llm = provider_for_step("curate", llm_cfg)
    _max_tokens = max_tokens_for_step("curate", llm_cfg, default=2048)
    print(f"📡 Using LLM: {_llm.name}/{_llm.model} (max_tokens={_max_tokens})")
    raw = call_llm(prompt, label="curate")
    cleaned = strip_fences(raw)
    try:
        decision = json.loads(cleaned)
    except json.JSONDecodeError as e:
        print("❌ Claude did not return valid JSON.", file=sys.stderr)
        print(cleaned, file=sys.stderr)
        raise SystemExit(f"JSON parse error: {e}")

    chosen_indices = decision.get("stories") or []
    if not chosen_indices:
        raise SystemExit("❌ Claude returned no stories.")

    print(f"📰 Claude chose {len(chosen_indices)} stories. Fetching bodies...")
    stories: list[dict] = []
    for n, choice in enumerate(chosen_indices, start=1):
        idx = choice["index"]
        if idx < 0 or idx >= len(items):
            print(f"  ⚠ skipping out-of-range index {idx}")
            continue
        item = items[idx]
        print(f"  ↓ story_{n}: {item['title'][:70]}")
        body = fetch_body(item["link"])
        if not body:
            print(f"     ⚠ failed to extract body from {item['link']} — falling back to RSS summary")
            body = item.get("summary") or item["title"]
        stories.append({
            "story_id": f"story_{n}",
            "category": choice["category"],
            "rationale": choice.get("rationale", ""),
            "source": item["source"],
            "headline": item["title"],
            "link": item["link"],
            "body": body,
        })

    payload = {
        "date": date,
        "curated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "stories": stories,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if _cost_recorder is not None:
        _cost_recorder.write()
    print()
    print(f"✅ Wrote {out_path} ({len(stories)} stories)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
