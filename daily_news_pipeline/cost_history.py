#!/usr/bin/env python3
"""
Print the aggregated daily cost ledger from cache/cost_history/YYYY/MM/*.json.
(Formerly the `cost-history` subcommand of library_inspect.py — vocab
inspection moved to the langpack `lexicon` CLI.)

Usage:
    python cost_history.py [--since YYYY-MM-DD]
"""

from __future__ import annotations

import argparse
import json
from datetime import date as _date
from pathlib import Path

HERE = Path(__file__).resolve().parent
HISTORY_ROOT = HERE / "cache" / "cost_history"


def main() -> int:
    p = argparse.ArgumentParser(description="Aggregated daily cost ledger")
    p.add_argument("--since", help="YYYY-MM-DD (inclusive)")
    args = p.parse_args()

    files = sorted(HISTORY_ROOT.glob("*/*/*.json"))
    if args.since:
        cutoff = _date.fromisoformat(args.since)
        files = [f for f in files if _date.fromisoformat(f.name[:10]) >= cutoff]

    grand_total = 0.0
    print(f"{'Date / time':22s}  {'LLM':10s}  {'TTS':10s}  {'Total':10s}")
    print("-" * 55)
    for f in files:
        d = json.loads(f.read_text(encoding="utf-8"))
        t = d.get("totals", {})
        llm = t.get("llm_cost_usd", 0)
        tts = t.get("tts_cost_usd", 0)
        total = t.get("estimated_cost_usd", 0)
        grand_total += total
        print(f"{f.stem:22s}  ${llm:9.4f}  ${tts:9.4f}  ${total:9.4f}")
    print("-" * 55)
    print(f"{'GRAND TOTAL':22s}  {'':10s}  {'':10s}  ${grand_total:9.4f}")
    print(f"\n{len(files)} run(s) recorded under {HISTORY_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
