#!/usr/bin/env python3
"""
Inspect / audit the phrase library.

Subcommands:
    stats               High-level counts + disk size
    vocab [--top N]     List vocab terms, sorted by uses
    examples            List example sentences with their vocab coverage
    show <ko>           Show full library entry for a Korean word
    play <ko>           Open the cached audio for a Korean word in the default player
    orphans             Audio files on disk not referenced from library.json
    set-gloss <ko> <en> Manually overwrite the canonical English gloss for a vocab term
                        (audio is NOT regenerated — the new gloss applies to FUTURE packs)

Usage:
    python library_inspect.py stats
    python library_inspect.py vocab --top 20
    python library_inspect.py examples
    python library_inspect.py show 협상
    python library_inspect.py play 협상
    python library_inspect.py set-gloss 협상 "negotiation, talks"
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from cache_lib import Library

HERE = Path(__file__).resolve().parent
CACHE_ROOT = HERE / "cache"


def cmd_stats(library: Library, args) -> int:
    s = library.stats_summary()
    print(f"📚 Library at {library.root}")
    print(f"   Vocab terms:       {s['vocab_terms']}")
    print(f"   Example sentences: {s['example_sentences']}")
    print(f"   Audio files:       {s['audio_files_on_disk']}  ({s['audio_bytes_on_disk'] / 1024 / 1024:.1f} MB)")
    return 0


def cmd_vocab(library: Library, args) -> int:
    items = sorted(library.data["vocab"].items(), key=lambda kv: -kv[1].get("uses", 0))
    if args.top:
        items = items[: args.top]
    print(f"{'Korean':18s}  {'English':30s}  uses  first_used")
    print("-" * 70)
    for ko, info in items:
        print(f"{ko:18s}  {info['canonical_en'][:30]:30s}  {info.get('uses', 0):4d}  {info.get('first_used', '?')}")
    print()
    print(f"Total vocab terms: {len(library.data['vocab'])}")
    return 0


def cmd_examples(library: Library, args) -> int:
    items = sorted(library.data["examples"], key=lambda e: -e.get("uses", 0))
    for ex in items:
        cov = ", ".join(ex["vocab_covered"])
        print(f"[{ex.get('uses', 0):3d}×] covers: {cov}")
        print(f"        ko: {ex['ko']}")
        print(f"        en: {ex['en']}")
        print()
    print(f"Total examples: {len(library.data['examples'])}")
    return 0


def _list_variant_summaries(library: Library, audio_keys: list[str]) -> None:
    for k in audio_keys:
        side = library.get_sidecar(k)
        if not side:
            print(f"    {k}: (no sidecar)")
            continue
        prov = side.get("provider", "?")
        engine = side.get("tier_or_engine", "?")
        voice = side.get("voice_id", "?")
        cost = side.get("estimated_cost_usd", 0)
        date = side.get("created_at", "?")
        print(f"    {k[:12]}…  {prov}/{engine}  voice={voice}  ${cost:.5f}  {date}")


def cmd_show(library: Library, args) -> int:
    ko = args.ko
    v = library.lookup_vocab(ko)
    if v:
        print(f"VOCAB: {ko}")
        print(f"  canonical_en: {v['canonical_en']}")
        print(f"  first_used:   {v['first_used']}")
        print(f"  uses:         {v['uses']}")
        for lang in ("ko", "en"):
            keys = v.get("audio_keys", {}).get(lang, [])
            if keys:
                print(f"  audio_keys.{lang}: ({len(keys)} variant(s))")
                _list_variant_summaries(library, keys)
            else:
                print(f"  audio_keys.{lang}: (none)")
        return 0
    for ex in library.data["examples"]:
        if ex["ko"] == ko:
            print(f"EXAMPLE: {ko}")
            for k, val in ex.items():
                if k == "audio_keys":
                    for lang in ("ko", "en"):
                        keys = val.get(lang, [])
                        print(f"  audio_keys.{lang}: ({len(keys)} variant(s))")
                        _list_variant_summaries(library, keys)
                else:
                    print(f"  {k}: {val}")
            return 0
    print(f"❌ '{ko}' not found in vocab or examples.", file=sys.stderr)
    return 1


def cmd_play(library: Library, args) -> int:
    ko = args.ko
    v = library.lookup_vocab(ko)
    candidate_keys: list[str] = []
    if v:
        candidate_keys = v.get("audio_keys", {}).get("ko", [])
    if not candidate_keys:
        for ex in library.data["examples"]:
            if ex["ko"] == ko:
                candidate_keys = ex.get("audio_keys", {}).get("ko", [])
                break
    if not candidate_keys:
        print(f"❌ no cached audio for '{ko}'", file=sys.stderr)
        return 1
    # Play the first variant
    audio_path = library.get_cached_audio(candidate_keys[0])
    if audio_path:
        print(f"▶ playing {audio_path}")
        subprocess.run(["afplay", str(audio_path)], check=False)
        return 0
    print(f"❌ audio file missing for key {candidate_keys[0]}", file=sys.stderr)
    return 1


def cmd_orphans(library: Library, args) -> int:
    referenced: set[str] = set()
    for v in library.data["vocab"].values():
        for lang in ("ko", "en"):
            referenced.update(v.get("audio_keys", {}).get(lang, []))
    for ex in library.data["examples"]:
        for lang in ("ko", "en"):
            referenced.update(ex.get("audio_keys", {}).get(lang, []))

    on_disk = {p.stem for p in library.audio_dir.glob("*.mp3")}
    orphans = sorted(on_disk - referenced)
    total_bytes = sum((library.audio_dir / f"{k}.mp3").stat().st_size for k in orphans)

    print(f"Audio files on disk: {len(on_disk)}")
    print(f"Referenced by index: {len(referenced)}")
    print(f"Orphans (unreferenced): {len(orphans)}  ({total_bytes / 1024 / 1024:.1f} MB)")
    if args.verbose:
        for k in orphans[:50]:
            print(f"  {k}.mp3")
        if len(orphans) > 50:
            print(f"  ... and {len(orphans) - 50} more")
    return 0


def cmd_set_gloss(library: Library, args) -> int:
    v = library.lookup_vocab(args.ko)
    if not v:
        print(f"❌ '{args.ko}' not in vocab library", file=sys.stderr)
        return 1
    old = v["canonical_en"]
    v["canonical_en"] = args.en
    # Clear English audio variants — new gloss won't match existing audio
    v["audio_keys"]["en"] = []
    library.save()
    print(f"✓ {args.ko}: '{old}' → '{args.en}'")
    print(f"  Note: en audio variants cleared; future packs will re-synth the new gloss.")
    return 0


def cmd_cost_history(library: Library, args) -> int:
    import json as _json
    from datetime import date as _date
    history_root = library.cost_history_root
    files = sorted(history_root.glob("*/*/*.json"))
    if args.since:
        cutoff = _date.fromisoformat(args.since)
        files = [f for f in files if _date.fromisoformat(f.name[:10]) >= cutoff]
    grand_total = 0.0
    print(f"{'Date / time':22s}  {'LLM':10s}  {'TTS':10s}  {'Total':10s}")
    print("-" * 55)
    for f in files:
        d = _json.loads(f.read_text(encoding="utf-8"))
        t = d.get("totals", {})
        llm = t.get("llm_cost_usd", 0)
        tts = t.get("tts_cost_usd", 0)
        total = t.get("estimated_cost_usd", 0)
        grand_total += total
        print(f"{f.stem:22s}  ${llm:9.4f}  ${tts:9.4f}  ${total:9.4f}")
    print("-" * 55)
    print(f"{'GRAND TOTAL':22s}  {'':10s}  {'':10s}  ${grand_total:9.4f}")
    print(f"\n{len(files)} run(s) recorded under {history_root}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="Inspect the phrase library")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("stats")

    p_vocab = sub.add_parser("vocab")
    p_vocab.add_argument("--top", type=int, default=0, help="Only show top N by uses")

    sub.add_parser("examples")

    p_show = sub.add_parser("show")
    p_show.add_argument("ko")

    p_play = sub.add_parser("play")
    p_play.add_argument("ko")

    p_orph = sub.add_parser("orphans")
    p_orph.add_argument("--verbose", action="store_true")

    p_set = sub.add_parser("set-gloss")
    p_set.add_argument("ko")
    p_set.add_argument("en")

    p_cost = sub.add_parser("cost-history")
    p_cost.add_argument("--since", help="YYYY-MM-DD (inclusive)")

    args = p.parse_args()
    library = Library.load(CACHE_ROOT)

    cmds = {
        "stats": cmd_stats,
        "vocab": cmd_vocab,
        "examples": cmd_examples,
        "show": cmd_show,
        "play": cmd_play,
        "orphans": cmd_orphans,
        "set-gloss": cmd_set_gloss,
        "cost-history": cmd_cost_history,
    }
    return cmds[args.cmd](library, args)


if __name__ == "__main__":
    raise SystemExit(main())
