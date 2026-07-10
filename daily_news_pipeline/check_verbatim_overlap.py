#!/usr/bin/env python3
"""
Verbatim-overlap check — copyright guard for same-language learner content.

The English news edition rewrites English source articles into English learner
text, so an LLM can lift distinctive phrasing straight from a copyrighted
article. Facts aren't copyrightable, but *expression* is — our output must
state the facts in our own words, not reproduce the source's sentences.

This is a DETERMINISTIC gate (no API cost, no LLM self-policing): for each
generated sentence it finds the longest run of consecutive words shared with
the source article. A long shared run (default 6+ words) is a strong signal
that a phrase was copied rather than reworded, and gets flagged for
regeneration or human review.

The Korean edition doesn't need this (cross-language output can't be a verbatim
copy), but its English fields (summary_en, track_title_en) can be checked too.

Library use:
    from check_verbatim_overlap import worst_overlap, check_texts
    flags = check_texts(source_body, ["gen sentence 1", ...], min_run=6)

CLI (gate a generated script against its source):
    python check_verbatim_overlap.py --source article.txt --script script.json
    # exit 0 = clean, 2 = one or more sentences flagged
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_WORD = re.compile(r"[a-z0-9']+")


def _norm(text: str) -> list[str]:
    """Lowercase word tokens; punctuation and casing don't affect a copy."""
    return _WORD.findall(text.lower())


def longest_shared_run(gen: str, source_words: list[str], source_index: set) -> tuple[int, str]:
    """Longest run of consecutive words the generated text shares with the
    source. `source_index` is the set of source k-grams for the min length
    (fast membership); we extend any hit to find the true run length.
    Returns (run_length, the_shared_phrase)."""
    g = _norm(gen)
    best_len, best_phrase = 0, ""
    n = len(source_words)
    # Map each source word position list for extension.
    for i in range(len(g)):
        # find source positions where g[i] starts a shared run
        # (cheap: scan only when the seed k-gram is present)
        for j in range(n):
            if source_words[j] != g[i]:
                continue
            k = 0
            while i + k < len(g) and j + k < n and g[i + k] == source_words[j + k]:
                k += 1
            if k > best_len:
                best_len, best_phrase = k, " ".join(g[i:i + k])
    return best_len, best_phrase


def worst_overlap(gen_texts: list[str], source: str) -> list[dict]:
    """Per-sentence longest shared run, sorted worst-first."""
    src = _norm(source)
    src_set = set(src)  # cheap seed filter
    results = []
    for t in gen_texts:
        # Only pay the O(n·m) scan for sentences that share vocabulary at all.
        if not (set(_norm(t)) & src_set):
            results.append({"text": t, "run": 0, "phrase": ""})
            continue
        run, phrase = longest_shared_run(t, src, src_set)
        results.append({"text": t, "run": run, "phrase": phrase})
    return sorted(results, key=lambda r: -r["run"])


def check_texts(source: str, gen_texts: list[str], min_run: int = 6) -> list[dict]:
    """Return the entries whose longest shared run is >= min_run (the flags)."""
    return [r for r in worst_overlap(gen_texts, source) if r["run"] >= min_run]


def english_texts_from_script(script: dict) -> list[str]:
    """Pull the English strings worth checking from a news script.json —
    the summaries and examples that could echo the source. Tolerant of both
    the ko-edition (summary_en) and the en-edition (summary_en_easy/natural)
    shapes."""
    out: list[str] = []
    for key in ("summary_en", "summary_en_easy", "summary_en_natural"):
        v = script.get(key)
        if isinstance(v, list):
            out.extend(x for x in v if isinstance(x, str))
        elif isinstance(v, str):
            out.append(v)
    for ex in script.get("examples", []):
        if isinstance(ex, dict) and isinstance(ex.get("en"), str):
            out.append(ex["en"])
    if isinstance(script.get("track_title_en"), str):
        out.append(script["track_title_en"])
    return out


def main() -> int:
    p = argparse.ArgumentParser(description="Flag learner text that copies the source article verbatim")
    p.add_argument("--source", type=Path, required=True, help="Source article text file")
    p.add_argument("--script", type=Path, help="Generated script.json (checks its English fields)")
    p.add_argument("--text", action="append", default=[], help="Ad-hoc generated string(s) to check")
    p.add_argument("--min-run", type=int, default=6, help="Flag a shared run of this many consecutive words (default 6)")
    args = p.parse_args()

    source = args.source.read_text(encoding="utf-8")
    texts = list(args.text)
    if args.script:
        texts += english_texts_from_script(json.loads(args.script.read_text(encoding="utf-8")))
    if not texts:
        print("nothing to check (pass --script or --text)", file=sys.stderr)
        return 1

    ranked = worst_overlap(texts, source)
    flags = [r for r in ranked if r["run"] >= args.min_run]
    print(f"checked {len(texts)} strings against source · min_run={args.min_run}")
    for r in ranked[:5]:
        mark = "⚠ FLAG" if r["run"] >= args.min_run else "ok"
        print(f"  [{mark}] run={r['run']:>2}  \"{r['text'][:60]}\"" +
              (f"   ↳ shared: \"{r['phrase']}\"" if r["run"] else ""))
    if flags:
        print(f"\n❌ {len(flags)} sentence(s) copy a {args.min_run}+ word run from the source — reword or regenerate.")
        return 2
    print("\n✅ no verbatim runs at or above threshold.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
