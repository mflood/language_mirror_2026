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


RECENT_DAYS = 7


def recent_chosen(date: str, days: int = RECENT_DAYS) -> list[dict]:
    """Stories chosen in the `days` calendar days before `date` — used to
    keep a story that lingers in a feed window from being picked twice."""
    from datetime import date as _date, timedelta
    d = _date.fromisoformat(date)
    out: list[dict] = []
    for back in range(1, days + 1):
        path = WORK_ROOT / (d - timedelta(days=back)).isoformat() / "chosen.json"
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        for s in data.get("stories", []):
            if s.get("link") or s.get("headline"):
                out.append({"link": s.get("link", ""), "headline": s.get("headline", "")})
    return out


def build_curation_prompt(items: list[dict], recent: list[dict] | None = None) -> str:
    hard = [it for it in items if it["genre"] == "hard"]
    features = [it for it in items if it["genre"] != "hard"]

    def render(it: dict, i: int) -> str:
        title = it["title"]
        source = it["source"]
        summary = (it.get("summary") or "")[:300]
        return f"[{i}] ({source}) {title}\n    {summary}"

    recent_block = ""
    if recent:
        lines = "\n".join(f"- {r['headline']}" for r in recent if r.get("headline"))
        recent_block = (
            "ALREADY COVERED in recent daily packs — do NOT pick these stories\n"
            "again, even under a different headline or from a different outlet:\n"
            f"{lines}\n\n"
        )

    hard_block = "\n".join(render(it, i) for i, it in enumerate(hard))
    feature_block = "\n".join(render(it, i + len(hard)) for i, it in enumerate(features))

    return f"""You are curating today's U.S. news for a Korean-language learning podcast.
The audience is English speakers learning Korean who want to stay in touch with
U.S. news (not Korean domestic news) while practicing Korean comprehension.

PEDAGOGICAL CONSTRAINT — this matters more than "most important news":
Politics and diplomacy stories use vocabulary-dense Korean (외교, 협상, 봉쇄,
해제, 비상사태, 결의안, 제재…) and abstract sentence structures that are
genuinely hard for intermediate learners. Sports, science, and human-interest
stories use more concrete, learnable vocabulary (선수, 결승선, 사고, 환자…)
with simpler sentence shapes. We want the pack to teach AND inform.

CURATION TARGET (4 stories total):
- 2 hard-news stories — the most-covered top stories of the day
- 2 feature stories — concrete subject matter, ideally from two different
  genres

FEATURE GENRE PREFERENCE (apply when choosing the 2 features):
  Rank from most-preferred to least-preferred:
    1. explainer / how-it-works / human-interest — best for learners
       (vocab transfers to daily life: 가방, 공항, 학교, 병원, 가족 등).
       These often appear in the HARD pool from NPR/CBS/Politico under
       innocuous-sounding headlines like "How X works" or "Why Y matters".
    2. science (new discoveries, health, environment)
    3. arts / culture / books / film
    4. tech (only if non-politics)
    5. sports — LAST resort. Sports vocab (구단, 결승, 시즌) does not transfer
       well to other contexts. Our audience leans general-interest, not fans.
       Only pick a sports story if no other feature option exists.

  When the FEATURE POOL is dominated by sports/tech, look in the HARD POOL
  for explainer-style stories — those qualify as features. Reclassify them
  by listing their category as "feature" in your output.

CATEGORY MIX RULE:
- If ALL the top hard-news stories are politics/diplomacy/conflict (vocab
  dense), pick only 1 hard-news story and pull a 3rd feature instead.
- Prefer breadth: 2 different feature topics > 2 in the same topic.
- Never include 3+ politics/diplomacy stories in one pack.

DUPLICATION RULE:
- If multiple outlets cover the same story (e.g., NPR and BBC both on the
  Fed decision), count that as ONE story and pick the version with the best
  headline + summary.

{recent_block}HARD NEWS POOL ({len(hard)} items):
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

    recent = recent_chosen(date)
    recent_links = {r["link"] for r in recent if r.get("link")}
    before = len(items)
    items = [it for it in items if it.get("link") not in recent_links]
    if before != len(items):
        print(f"  ⏭ dropped {before - len(items)} feed item(s) already chosen "
              f"in the last {RECENT_DAYS} days")

    prompt = build_curation_prompt(items, recent=recent)
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
