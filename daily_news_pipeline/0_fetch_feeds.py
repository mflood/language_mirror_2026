#!/usr/bin/env python3
"""
Step 0: Pull RSS feeds defined in feeds.yaml, normalize into a single JSON
list of headlines tagged by source and genre. No spending, no API calls — just
network reads from public RSS endpoints.

Output:
    work/<YYYY-MM-DD>/feeds.json
      { "date": "...", "fetched_at": "...", "items": [...] }

Each item: { "source", "genre", "title", "link", "published", "summary" }
where "summary" is the RSS description (often 1-3 sentences). Full article
bodies are NOT fetched here — that happens in step 1 (curate) only for the
chosen stories, to keep network traffic minimal.

Usage:
    python 0_fetch_feeds.py [--date YYYY-MM-DD] [--feeds path/to/feeds.yaml]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import feedparser
import yaml


HERE = Path(__file__).resolve().parent
DEFAULT_FEEDS = HERE / "feeds.yaml"
WORK_ROOT = HERE / "work"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Fetch RSS feeds for the daily news pipeline")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--feeds", type=Path, default=DEFAULT_FEEDS, help="Path to feeds.yaml")
    p.add_argument("--max-per-feed", type=int, default=20, help="Cap items per feed (default: 20)")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def load_feeds_config(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"❌ feeds config not found: {path}")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def fetch_feed(source: str, url: str, genre: str, max_items: int) -> list[dict]:
    print(f"  ↓ {source:20s} ({genre})", end=" ", flush=True)
    parsed = feedparser.parse(url)
    if parsed.bozo and not parsed.entries:
        print(f"⚠ failed: {parsed.bozo_exception}")
        return []
    items: list[dict] = []
    for entry in parsed.entries[:max_items]:
        items.append({
            "source": source,
            "genre": genre,
            "title": (entry.get("title") or "").strip(),
            "link": entry.get("link") or "",
            "published": entry.get("published") or entry.get("updated") or "",
            "summary": (entry.get("summary") or entry.get("description") or "").strip(),
        })
    print(f"{len(items)} items")
    return items


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    cfg = load_feeds_config(args.feeds)
    out_dir = WORK_ROOT / date
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "feeds.json"

    print(f"═══ Fetching feeds for {date} ═══")
    items: list[dict] = []

    for entry in cfg.get("hard", []) or []:
        items.extend(fetch_feed(entry["source"], entry["url"], "hard", args.max_per_feed))

    for entry in cfg.get("features", []) or []:
        items.extend(fetch_feed(entry["source"], entry["url"], entry.get("genre", "feature"), args.max_per_feed))

    print()
    if not items:
        print("❌ No items fetched. All feeds failed.", file=sys.stderr)
        return 1

    payload = {
        "date": date,
        "fetched_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "items": items,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Wrote {out_path} ({len(items)} items)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
