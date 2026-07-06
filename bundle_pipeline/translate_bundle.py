#!/usr/bin/env python3
"""
DEPRECATED (2026-07): span translations are now produced natively by the
platform (news step 2b + studypack refs). This tool remains only for
backfilling old published bundles.

Generic span-translation enricher for any bundle.json — no script.json needed
(unlike the daily news pipeline, which derives translations from turn roles).
Used to backfill packs produced by other pipelines (starters, akc, hccc drama
scenes, one-offs) and for future non-news packs.

Three passes:
  1. Pair pass (--pair-adjacent): interleaved bilingual packs (ko,en,ko,en…)
     already contain the translation as the adjacent span. A ko span followed
     by a singleton en span (and not itself part of a grouped ko block) gets
     {"en": next.text}; the en span gets the reverse {"ko": prev.text}.
     Grouped blocks are skipped — index pairing there would misalign.
  2. LLM pass: remaining source-language spans lacking a requested target
     language are translated per track in a single call, with the full
     ordered transcript in the prompt for context. Strict 1:1 count
     validation with one retry. In-run cache dedupes identical span text
     (e.g. akc-01 and akc-01-v2 share all content).
  3. Verify: the enriched bundle must differ from the original ONLY in
     `translations` keys; per-track coverage is reported.

Dry-run by default: writes translate_work/<name>/bundle.json and prints a
summary. --commit uploads bundle.json to s3://turned.rip/lmaudio/<pack_id>/
(+ CloudFront invalidation) for pack-id inputs, or overwrites the file for
local-path inputs.

Usage:
    python translate_bundle.py starter_seoul_lunch                  # dry-run
    python translate_bundle.py starter_seoul_lunch --commit
    python translate_bundle.py hccc-s01e15-sc01 --pair-adjacent --commit
    python translate_bundle.py path/to/bundle.json --langs en,es --commit
"""

from __future__ import annotations

import argparse
import copy
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
WORK_ROOT = HERE / "translate_work"

# Reuse the daily pipeline's provider + pricing plumbing (same pattern as
# daily_news_pipeline/5_publish_s3.py importing bundle_pipeline helpers).
sys.path.insert(0, str(REPO_ROOT / "daily_news_pipeline"))
from llm_providers import make_provider  # noqa: E402
from cost_tracker import estimate_llm_cost  # noqa: E402

PUBLISH_BUCKET = "turned.rip"
CLOUDFRONT_DOMAIN = "d1ni0tk3ua6bwo.cloudfront.net"

LANG_NAMES = {
    "en": "English", "ko": "Korean", "es": "Spanish",
    "zh-Hans": "Simplified Chinese", "zh-Hant": "Traditional Chinese",
    "th": "Thai", "ja": "Japanese",
}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Enrich a bundle.json with span translations")
    p.add_argument("target", help="published pack id (lmaudio/<id>/) or local bundle.json path")
    p.add_argument("--langs", default="en", help="comma-separated target base language codes")
    p.add_argument("--pair-adjacent", action="store_true",
                   help="pair interleaved bilingual spans before the LLM pass")
    p.add_argument("--model", default="claude-haiku-4-5")
    p.add_argument("--provider", default="anthropic")
    p.add_argument("--max-tokens", type=int, default=4096)
    p.add_argument("--commit", action="store_true",
                   help="upload to S3 (pack id) or overwrite the file (local path)")
    return p.parse_args()


def base_lang(code: str | None) -> str:
    return (code or "").split("-")[0]


def fetch_bundle(target: str) -> tuple[dict, str | None, Path | None]:
    """Returns (bundle, pack_id_or_None, local_path_or_None)."""
    path = Path(target)
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8")), None, path
    # Treat as published pack id; S3 is the source of truth for backfills.
    result = subprocess.run(
        ["aws", "s3", "cp", f"s3://{PUBLISH_BUCKET}/lmaudio/{target}/bundle.json", "-"],
        capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"❌ not a local file and S3 fetch failed: {result.stderr.strip()}")
    return json.loads(result.stdout), target, None


def iter_spans(bundle: dict):
    for pack in bundle.get("packs", []):
        for track in pack.get("tracks", []):
            yield track, track.get("transcripts") or []


def pair_adjacent(bundle: dict) -> int:
    """
    Reciprocally translate interleaved bilingual span pairs.

    Direction matters: in these packs the translation FOLLOWS the original
    (ko, en, ko, en…), so only (primary-language span → next other-language
    span) couples are paired. A direction-agnostic rule would also pair
    (en, ko) couples across pair boundaries and shift every subsequent
    translation off by one.
    """
    paired = 0
    for track, spans in iter_spans(bundle):
        langs = [base_lang(s.get("languageCode")) for s in spans]
        primary = base_lang(track.get("languageCode"))
        if not primary:
            counts: dict[str, int] = {}
            for lg in langs:
                if lg:
                    counts[lg] = counts.get(lg, 0) + 1
            primary = max(counts, key=counts.get) if counts else ""
        for i in range(len(spans) - 1):
            a, b = langs[i], langs[i + 1]
            if a != primary or not b or a == b:
                continue
            # Both must be singletons of their language: no grouped blocks.
            if i > 0 and langs[i - 1] == a:
                continue
            if i + 2 < len(spans) and langs[i + 2] == b:
                continue
            sa, sb = spans[i], spans[i + 1]
            if not sa.get("text") or not sb.get("text"):
                continue
            sa.setdefault("translations", {}).setdefault(b, sb["text"])
            sb.setdefault("translations", {}).setdefault(a, sa["text"])
            paired += 1
    return paired


def build_prompt(track_title: str, spans: list[dict], todo: list[int], lang: str) -> str:
    lang_name = LANG_NAMES.get(lang, lang)
    context = "\n".join(
        f"[{i}] ({base_lang(s.get('languageCode')) or '?'}) {s['text']}"
        for i, s in enumerate(spans))
    numbered = "\n".join(f"[{i}] {spans[i]['text']}" for i in todo)
    return f"""You are translating lines from a Korean-learning audio track titled "{track_title}".
The full transcript is below for context (speaker turns, register, who is talking):

{context}

Translate ONLY the following {len(todo)} lines into natural {lang_name}, staying
faithful to meaning, register, and tone (casual stays casual, formal stays formal).

Rules:
- Translate each line independently; do not merge or add content.
- Return ONLY a JSON array of objects: {{"line": <integer from the brackets>, "translation": "..."}}.

Lines:
{numbered}"""


def parse_response(text: str, todo: list[int]) -> dict[int, str]:
    """Map requested line index → translation. Extra lines the model volunteers
    are dropped; every requested line must be present."""
    import re
    m = re.search(r"\[.*\]", text, re.DOTALL)
    if not m:
        raise ValueError(f"no JSON array in response: {text[:200]}")
    arr = json.loads(m.group(0))
    if not isinstance(arr, list):
        raise ValueError("response is not a JSON array")
    got: dict[int, str] = {}
    for item in arr:
        if not isinstance(item, dict) or not isinstance(item.get("translation"), str):
            continue
        line = item.get("line")
        if isinstance(line, str):  # tolerate "[0]" / "0"
            digits = re.sub(r"\D", "", line)
            line = int(digits) if digits else None
        if isinstance(line, int):
            got[line] = item["translation"]
    missing = [i for i in todo if i not in got]
    if missing:
        raise ValueError(f"missing translations for lines {missing[:8]}")
    return {i: got[i] for i in todo}


def llm_pass(bundle: dict, langs: list[str], provider, max_tokens: int,
             cache: dict[tuple[str, str], str]) -> tuple[int, float]:
    translated = 0
    cost = 0.0
    for track, spans in iter_spans(bundle):
        for lang in langs:
            todo = [i for i, s in enumerate(spans)
                    if s.get("text")
                    and base_lang(s.get("languageCode")) != lang
                    and lang not in (s.get("translations") or {})]
            # Serve cache hits first
            remaining = []
            for i in todo:
                hit = cache.get((spans[i]["text"], lang))
                if hit is not None:
                    spans[i].setdefault("translations", {})[lang] = hit
                    translated += 1
                else:
                    remaining.append(i)
            if not remaining:
                continue
            prompt = build_prompt(track.get("title") or "", spans, remaining, lang)
            for attempt in (1, 2):
                resp = provider.chat(prompt, max_tokens=max_tokens)
                cost += estimate_llm_cost(resp.provider, resp.model,
                                          resp.input_tokens, resp.output_tokens)
                try:
                    results = parse_response(resp.text, remaining)
                    break
                except ValueError as e:
                    if attempt == 2:
                        raise SystemExit(f"❌ track '{track.get('title')}': {e}")
                    print(f"  ⚠️  retry ({e})")
            for i, tr in results.items():
                spans[i].setdefault("translations", {})[lang] = tr
                cache[(spans[i]["text"], lang)] = tr
                translated += 1
            print(f"  📡 {track.get('title', '?')[:40]} → {lang}: {len(remaining)} spans "
                  f"(in={resp.input_tokens} out={resp.output_tokens})")
    return translated, cost


def strip_translations(obj):
    if isinstance(obj, dict):
        return {k: strip_translations(v) for k, v in obj.items() if k != "translations"}
    if isinstance(obj, list):
        return [strip_translations(x) for x in obj]
    return obj


def coverage(bundle: dict, langs: list[str]) -> str:
    lines = []
    for track, spans in iter_spans(bundle):
        n = len(spans)
        done = sum(1 for s in spans
                   if all(lang in (s.get("translations") or {})
                          or base_lang(s.get("languageCode")) == lang for lang in langs))
        lines.append(f"    {track.get('title', '?')[:44]:46s} {done}/{n}")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    langs = [x.strip() for x in args.langs.split(",") if x.strip()]

    bundle, pack_id, local_path = fetch_bundle(args.target)
    original = copy.deepcopy(bundle)
    name = pack_id or local_path.stem
    print(f"🔎 {name}: {sum(len(s) for _, s in iter_spans(bundle))} spans, targets={langs}")

    paired = 0
    if args.pair_adjacent:
        paired = pair_adjacent(bundle)
        print(f"  🔗 pair pass: {paired} adjacent pairs linked (free)")

    provider = make_provider(args.provider, args.model)
    cache: dict[tuple[str, str], str] = {}
    translated, cost = llm_pass(bundle, langs, provider, args.max_tokens, cache)
    print(f"  💬 LLM pass: {translated} spans translated  est_cost=${cost:.4f}")

    # Verify: nothing but translations may change.
    if strip_translations(bundle) != strip_translations(original):
        raise SystemExit("❌ structural drift detected — enrichment touched non-translation data")
    print("  ✅ structural check: only `translations` keys added")
    print("  coverage per track:")
    print(coverage(bundle, langs))

    out_dir = WORK_ROOT / name
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "bundle.json"
    out_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"  📝 wrote {out_path}")

    if not args.commit:
        print("  (dry-run — re-run with --commit to publish)")
        return 0

    if local_path is not None:
        local_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n",
                              encoding="utf-8")
        print(f"✅ overwrote {local_path}")
        return 0

    dest = f"s3://{PUBLISH_BUCKET}/lmaudio/{pack_id}/bundle.json"
    subprocess.run(["aws", "s3", "cp", str(out_path), dest,
                    "--content-type", "application/json", "--only-show-errors"], check=True)
    print(f"✅ uploaded {dest}")
    dist = subprocess.run(
        ["aws", "cloudfront", "list-distributions", "--query",
         f"DistributionList.Items[?DomainName=='{CLOUDFRONT_DOMAIN}'].Id", "--output", "text"],
        capture_output=True, text=True).stdout.strip()
    if dist and dist != "None":
        subprocess.run(["aws", "cloudfront", "create-invalidation", "--distribution-id", dist,
                        "--paths", f"/lmaudio/{pack_id}/bundle.json",
                        "--query", "Invalidation.Id", "--output", "text"], check=True)
        print(f"✅ invalidated /lmaudio/{pack_id}/bundle.json ({dist})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
