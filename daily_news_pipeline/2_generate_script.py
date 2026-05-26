#!/usr/bin/env python3
"""
Step 2: Generate a structured 4-section narration script for each chosen story.

For each story in chosen.json, prompt Claude to produce:
  - 5 advanced Korean vocab words pulled from the eventual Korean translation
  - 2 example sentences per vocab word (10 sentences)
  - 2 useful expressions/paraphrases from the story
  - Korean summary (3 sentences)
  - English summary (3 sentences)

Then emit the canonical turn sequence (KO header / EN header / vocab / examples
/ expressions / KO summary / EN summary) plus per-PracticeSet clip definitions
(turn-index ranges) that step 4 will convert to ms timestamps.

Output:
    work/<YYYY-MM-DD>/script.json
      {
        "date": "...",
        "pack_id": "news_2026_05_24",
        "pack_title_ko": "2026년 5월 24일 뉴스",
        "pack_title_en": "US News, May 24, 2026",
        "stories": [
          {
            "story_id": "story_1",
            "track_title_ko": "...",
            "track_title_en": "...",
            "turns": [ { "speaker": "A"|"B", "lang": "en"|"ko", "text": "..." }, ... ],
            "practice_sets": [
              { "title": "Beginner (with English)", "clips": [{turn_range: [a,b], title: "..."}, ...] },
              { "title": "Korean phrase loops",   "clips": [...] },
              { "title": "Full Korean summary",   "clips": [...] }
            ]
          },
          ...
        ]
      }

Safety: defaults to dry-run.

Usage:
    python 2_generate_script.py [--date YYYY-MM-DD] [--commit]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

import yaml

from cache_lib import Library
from cost_tracker import StepCostRecorder
from llm_providers import LLMProvider, provider_for_step, max_tokens_for_step

HERE = Path(__file__).resolve().parent
WORK_ROOT = HERE / "work"
CACHE_ROOT = HERE / "cache"
DEFAULT_LLM_CONFIG = HERE / "llm.yaml"


KO_MONTHS = ["", "1월", "2월", "3월", "4월", "5월", "6월", "7월", "8월", "9월", "10월", "11월", "12월"]
EN_MONTHS = ["", "January", "February", "March", "April", "May", "June",
             "July", "August", "September", "October", "November", "December"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate the narration script for the day's pack")
    p.add_argument("--date", help="YYYY-MM-DD (default: today, US/Eastern)")
    p.add_argument("--config", type=Path, default=DEFAULT_LLM_CONFIG, help="llm.yaml path")
    p.add_argument("--commit", action="store_true", help="Actually call the LLM.")
    p.add_argument("--no-qa", action="store_true", help="Skip the cross-model QA review (saves ~$0.10/run)")
    return p.parse_args()


def today_eastern() -> str:
    now = dt.datetime.now(dt.timezone(dt.timedelta(hours=-4)))
    return now.strftime("%Y-%m-%d")


def build_story_prompt(story: dict) -> str:
    return f"""You are building a Korean-language news listening pack for English speakers
learning Korean (intermediate level, roughly TOPIK 3-4).

SOURCE ARTICLE (English, U.S. news):
Headline: {story['headline']}
Source: {story['source']}

Body:
{story['body']}

Produce a JSON object with this exact shape (no markdown fences, no prose):

{{
  "track_title_ko": "<short Korean title, 4-10 syllables>",
  "track_title_en": "<English title>",
  "vocab": [
    {{ "ko": "<Korean word>", "en": "<short English gloss>" }},
    ... Pick the most important content words for an intermediate learner
    (TOPIK 2-4) from your Korean summary. Include nouns, verbs, adjectives,
    and adverbs that carry meaning. SKIP: particles (은/는/이/가/을/를/에/에서/으로/도/만),
    extremely common function verbs used grammatically (있다/없다/하다/되다/이다),
    proper nouns (people, place, brand names), and numbers/dates.
    Minimum 5 entries, maximum 12 entries. If the summary has fewer than 12
    worthwhile content words, list only what's actually useful — do not pad.
    If more candidates exist, pick the 12 most pedagogically valuable.
    List in order of first appearance in the summary.
  ],
  "examples": [
    {{ "ko": "<Korean example sentence>", "en": "<English translation>" }},
    ... 1 to 12 example sentences total. The KEY constraint: EVERY vocab word
    from the list above MUST appear in at least one example sentence (no vocab
    word left uncovered).
    AIM TO COMBINE multiple vocab words into a single sentence when natural.
    For example, if vocab includes 외교, 협상, 진행되다, an example like
    "외교 협상이 활발히 진행되고 있습니다." covers all three in one go.
    Prefer 5-8 well-crafted sentences (each covering 2-3 vocab words) over
    12 single-word sentences. Sentences 8-18 words. Use news-register Korean.
  ],
  "expressions": [
    {{ "ko": "<Korean expression>", "en": "<English translation>" }},
    ... 2 entries — useful collocations, idiomatic patterns, or paraphrases
    drawn directly from the news story content. Not single words; phrases.
  ],
  "summary_ko_easy": [
    "<sentence 1>", "<sentence 2>", "..."
  ],
  "summary_ko_natural": [
    "<sentence 1>", "<sentence 2>", "<sentence 3>"
  ],
  "summary_en": [
    "<sentence 1>", "<sentence 2>", "<sentence 3>"
  ]
}}

⚠ FACTUAL FIDELITY (BOTH SUMMARY LEVELS) — non-negotiable:
- NEVER invent facts, numbers, names, dates, or events not in the article body.
- NEVER fabricate direct quotes. If you didn't see the exact words in the source,
  do not use quotation marks. Paraphrasing without quotes is fine.
- NEVER attribute a statement to someone who didn't make it in the article.
- If the article says "around 50,000", say "약 5만 명" — not "정확히 5만 명".
- If a number, date, or detail isn't in the article, omit that detail.
- Easy and Natural summaries MUST convey the SAME FACTS — just at different
  linguistic complexity. The easy version is not "selective"; it covers all
  3 facts that the natural version covers, just with simpler language.

TWO SUMMARY LEVELS:
You will produce the same 3 facts at TWO difficulty levels.

   summary_ko_easy — for TOPIK 2 learners (lower-intermediate):
     ── 해요 form (-아요 / -어요 / -해요), NOT 습니다 form
     ── Max 12 Korean words per sentence
     ── ≤2 Sino-Korean (한자어) compounds per sentence
     ── TOPIK 1-2 verbs outside the vocab list
     ── Concrete verbal phrases, no nominalized abstractions
     ── Break ideas into more, shorter sentences if needed
     ── No embedded clauses
     ── 4-8 sentences total

   summary_ko_natural — for TOPIK 3-4 learners (intermediate-plus):
     ── 습니다 form (formal news register)
     ── Up to 18 words per sentence; embedded clauses OK
     ── News-style Sino-Korean compounds welcome
     ── 3 sentences total — the same 3 facts as the easy version
     ── This is what a Korean news anchor would actually read

The easy version must convey the SAME 3 FACTS as the natural version. Easy
is simpler language, NOT a shorter or different story.

DIFFICULTY DETAILS for summary_ko_easy:

1. SENTENCE LENGTH: Maximum 12 Korean words per sentence (count by spaces).
   Break longer ideas into multiple shorter sentences.

2. REGISTER: Use 해요 form (-아요 / -어요 / -해요 endings). NOT 습니다 form.
   This pack is for aural listening practice; 해요 is significantly easier
   to parse by ear and is the form most learners encounter first.

3. SINO-KOREAN (한자어): At most 2 Sino-Korean compounds per sentence.
   When a 순우리말 (native Korean) alternative exists, prefer it.
   Common swaps:
     동결하다 → 막다              발표하다 → 말하다
     우려 → 걱정                 재개하다 → 다시 열다
     결정하다 → 정하다            논의하다 → 이야기하다
     실시하다 → 하다              해제하다 → 풀다
     급등하다 → 빠르게 오르다       체결하다 → 맺다

4. NON-VOCAB VERBS: Verbs outside the vocab list must be TOPIK 1-2 frequency.
   Safe verbs to use freely: 가다 오다 하다 보다 듣다 말하다 알다 모르다
   좋다 나쁘다 크다 작다 많다 적다 있다 없다 먹다 마시다 만들다 사다 팔다
   살다 죽다 시작하다 끝나다 만나다 보내다 받다 주다 쓰다 읽다 일하다
   쉬다 일어나다 자다.

5. CONCRETE > ABSTRACT: Replace nominalized abstractions with verbal phrases.
   "외교적 해결책을 모색하다" → "평화롭게 이야기해요"
   "비상사태 선포가 이루어졌다" → "비상사태를 선언했어요"

6. NO EMBEDDED CLAUSES IN SUMMARY: One subject, one verb per sentence.
   Save complex grammar for the example sentences.

VOCAB SECTION DIFFICULTY:
- The vocab LIST itself can include TOPIK 3-4 spicy words — that's the whole
  point of vocab study. But the WORDS in the summary should only be the
  ones from the vocab list (which the listener has just been taught) plus
  TOPIK 1-2 connective tissue.

EXAMPLE SENTENCES should be MARKEDLY EASIER than the summary itself:
- Simple subjects (저는 / 우리는 / 그는 / 그녀는)
- Present tense as much as possible
- No embedded clauses
- The goal is to make the vocab word memorable in context, not to be impressive

ENGLISH SUMMARY: natural English translation of the Korean summary. Korean
comes first and reads idiomatically; English is the cushion.
"""


# Cost tracker + per-step LLM providers installed by main().
_cost_recorder: StepCostRecorder | None = None
_llm_script: LLMProvider | None = None
_llm_qa: LLMProvider | None = None
_max_tokens_script: int = 4096
_max_tokens_qa: int = 4096

# Running totals across all calls within a single run.
_run_totals = {"input_tokens": 0, "output_tokens": 0, "cost_usd": 0.0}


def call_llm(provider: LLMProvider, max_tokens: int, prompt: str, label: str) -> str:
    """Single-turn LLM call with cost recording."""
    print(f"     📡 [{label}] → {provider.name}")
    print(f"        model={provider.model}  prompt_chars={len(prompt)}  max_tokens={max_tokens}")
    resp = provider.chat(prompt, max_tokens=max_tokens)
    cost = 0.0
    if _cost_recorder is not None:
        cost = _cost_recorder.add_llm_call(
            provider=resp.provider, model=resp.model,
            input_tokens=resp.input_tokens, output_tokens=resp.output_tokens,
            label=label, response_chars=len(resp.text),
        )
    _run_totals["input_tokens"] += resp.input_tokens
    _run_totals["output_tokens"] += resp.output_tokens
    _run_totals["cost_usd"] += cost
    print(f"        ✓ usage: input={resp.input_tokens} output={resp.output_tokens} tokens  est_cost=${cost:.4f}  response_chars={len(resp.text)}")
    print(f"        ↳ running total: input={_run_totals['input_tokens']} output={_run_totals['output_tokens']} cost=${_run_totals['cost_usd']:.4f}")
    return resp.text


def build_qa_review_prompt(story: dict, generated: dict) -> str:
    """Build a prompt asking Claude to review and correct its own output."""
    return f"""You are reviewing a Korean-language learning pack you just generated.
The audience is English speakers learning Korean (TOPIK 2-4). Carefully check
the script below for any errors and correct them. Be conservative — only change
things that are actually wrong. If everything is correct, return the input
UNCHANGED.

CHECK FOR:

1. FACTUAL FIDELITY (CRITICAL — applies to BOTH summary levels and examples):
   a. Every fact, number, date, name, and event in the summaries MUST appear
      in the source article body. Flag any invented details.
   b. No fabricated quotes. Flag any text inside quotation marks that doesn't
      match the source verbatim.
   c. No attributions of statements to people who weren't quoted in the source.
   d. Numerical hedging: if the source says "around 50,000", flag any summary
      that says "정확히 5만 명" or other false precision.
   e. The easy and natural summaries MUST cover the SAME facts. Flag if the
      easy version drops or changes a fact that's in the natural version (or
      vice versa).

2. EASY-LEVEL DIFFICULTY COMPLIANCE (summary_ko_easy only):
   a. 해요 form (-아요/-어요/-해요), NOT 습니다 form. Flag any 습니다 endings.
   b. ≤12 Korean words per sentence (count by spaces). Flag longer ones.
   c. ≤2 Sino-Korean compounds per sentence (excluding vocab list terms).
      Flag dense compounds like 비상사태, 외교적 해결책, 폭발 위험성.
   d. Non-vocab verbs are TOPIK 1-2 frequency. Flag fancy verbs like
      급등하다, 동결하다, 발표되다 outside the vocab list.

3. NATURAL-LEVEL CHECK (summary_ko_natural only):
   a. 습니다 form (formal news register). Flag any 해요 endings.
   b. 3 sentences total — same facts as easy version.
   c. Idiomatic news-style Korean.

4. EXAMPLE QUALITY: Example sentences are SIMPLER than the easy summary
   (simple subjects, present tense, no embedded clauses). Each example uses
   the corresponding vocab word naturally.

5. KOREAN GRAMMAR: Particles (은/는, 이/가, 을/를, 에/에서), conjugations,
   spacing rules.

6. VOCAB COVERAGE: Each vocab word appears in the easy Korean summary AND
   in at least one example sentence.

7. TRANSLATION ACCURACY: English glosses accurately reflect the Korean.

8. TYPOS / SPACING: Spelling errors, missing 받침, unusual punctuation.

ORIGINAL ARTICLE (English source — use as ground truth for facts):
Headline: {story['headline']}
Body:
{story['body'][:2000]}

GENERATED SCRIPT TO REVIEW:
{json.dumps(generated, ensure_ascii=False, indent=2)}

Return ONLY a JSON object with the SAME schema as the input (track_title_ko,
track_title_en, vocab, examples, expressions, summary_ko, summary_en).
No markdown fences, no prose outside the JSON. If you made changes, include
a top-level "_qa_changes" array (list of short strings describing what you
fixed) so we have an audit trail. If nothing changed, set "_qa_changes": [].
"""


def qa_review_story(story: dict, generated: dict) -> tuple[dict, list[str]]:
    """Run Claude QA review on a generated story; return (corrected, change_list)."""
    prompt = build_qa_review_prompt(story, generated)
    raw = call_llm(_llm_qa, _max_tokens_qa, prompt, label=f"qa:{story['story_id']}")
    cleaned = strip_fences(raw)
    try:
        reviewed = json.loads(cleaned)
    except json.JSONDecodeError as e:
        print(f"     ⚠ QA review returned invalid JSON, keeping original. Error: {e}")
        return generated, []
    changes = reviewed.pop("_qa_changes", []) or []
    # Ensure all required keys made it through (defensive — fall back to original if not)
    required = {"track_title_ko", "track_title_en", "vocab", "examples", "expressions", "summary_ko_easy", "summary_ko_natural", "summary_en"}
    if not required.issubset(reviewed.keys()):
        missing = required - set(reviewed.keys())
        print(f"     ⚠ QA review output missing keys {missing}, keeping original")
        return generated, []
    return reviewed, changes


def apply_library_reuse(data: dict, library: Library) -> dict:
    """
    Mutate `data` in place to:
      1. Lock vocab glosses to library canonical forms (where the Korean word
         is already in the library)
      2. Replace `data["examples"]` with: cached examples that cover today's
         vocab + Claude's fresh examples that fill any gaps, capped at 12,
         ordered by the minimum-vocab-index they cover.

    Returns a report dict describing what was reused / replaced.
    """
    day_vocab = data["vocab"]
    day_vocab_set = [v["ko"] for v in day_vocab]

    # 1. Lock glosses
    locked = []
    for v in day_vocab:
        existing = library.lookup_vocab(v["ko"])
        if existing and existing["canonical_en"] != v["en"]:
            locked.append((v["ko"], v["en"], existing["canonical_en"]))
            v["en"] = existing["canonical_en"]

    # 2. Find cached examples that cover today's vocab (greedy set cover)
    cached, uncovered = library.find_examples_covering(day_vocab_set, max_n=12)

    # Normalize cached examples to {ko, en, vocab_covered}
    cached_examples = [
        {
            "ko": ex["ko"],
            "en": ex["en"],
            "vocab_covered": sorted(set(ex["vocab_covered"]) & set(day_vocab_set)),
        }
        for ex in cached
    ]

    # 3. Greedy fill from Claude's fresh examples for remaining uncovered vocab
    # First, annotate Claude's examples with which of today's vocab they contain.
    def coverage_of(ex_ko: str) -> list[str]:
        return [v for v in day_vocab_set if v in ex_ko]

    fresh_candidates = []
    for ex in data["examples"]:
        cov = coverage_of(ex["ko"])
        if cov:
            fresh_candidates.append({**ex, "vocab_covered": cov})

    remaining = uncovered
    fresh_picks = []
    while remaining and len(cached_examples) + len(fresh_picks) < 12:
        best = None
        best_n = 0
        for ex in fresh_candidates:
            if ex in fresh_picks:
                continue
            n = len(set(ex["vocab_covered"]) & remaining)
            if n > best_n:
                best = ex
                best_n = n
        if not best:
            break
        fresh_picks.append(best)
        remaining -= set(best["vocab_covered"])

    # 4. Combine + reorder by min vocab index (Beginner set plays in this order)
    vocab_idx = {v: i for i, v in enumerate(day_vocab_set)}
    combined = cached_examples + fresh_picks
    combined.sort(key=lambda ex: min((vocab_idx.get(v, 999) for v in ex["vocab_covered"]), default=999))
    data["examples"] = [
        {"ko": ex["ko"], "en": ex["en"], "vocab_covered": ex["vocab_covered"]}
        for ex in combined
    ]

    return {
        "cached_examples_used": len(cached_examples),
        "fresh_examples_added": len(fresh_picks),
        "uncovered_vocab": sorted(remaining),
        "locked_glosses": locked,
        "final_example_count": len(data["examples"]),
    }


def strip_fences(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        nl = text.find("\n")
        if nl != -1:
            text = text[nl + 1:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def build_turns_for_story(story_data: dict, date_iso: str) -> tuple[list[dict], list[dict]]:
    """
    Returns (turns, practice_sets) where:
      turns: list of {speaker, lang, text}
      practice_sets: list of {title, displayOrder, clips: [{turn_range, title, languageCode}]}

    Voice mapping (resolved in step 3):
      Voice A = English male teacher (speaks all English text)
      Voice B = Korean female narrator (speaks all Korean text)
    """
    turns: list[dict] = []
    # Indices recorded for clip definitions
    idx = {
        "vocab_word": [],          # one entry per vocab word: index of the Korean word turn
        "vocab_block": [],         # one entry per vocab word: (start_inclusive, end_inclusive)
        "example_block": [],       # one entry per example: (start, end)
        "example_ko": [],          # index of the Korean-only example turn
        "expression_block": [],    # (start, end)
        "expression_ko": [],       # index of Korean-only expression turn
        "summary_ko_sentence": [], # one entry per Korean summary sentence
        "summary_ko_range": None,  # (start, end) covering all KO summary sentences
        "english_summary_block": None,  # (start, end) of the English summary block
    }

    def add(speaker: str, lang: str, text: str, role: str = "unique", library_text_key: str | None = None) -> int:
        """Append a turn. role + library_text_key let step 3 attach audio to library entries."""
        turn: dict = {"speaker": speaker, "lang": lang, "text": text, "role": role}
        if library_text_key is not None:
            turn["library_text_key"] = library_text_key
        turns.append(turn)
        return len(turns) - 1

    # --- Story intro (KO date header → EN translation) -----------------------
    intro_ko_idx = add("B", "ko", story_data["track_title_ko"], role="track_intro_ko")
    intro_en_idx = add("A", "en", story_data["track_title_en"], role="track_intro_en")
    track_intro_range = (intro_ko_idx, intro_en_idx)

    # --- Section: 어휘 / Vocabulary -----------------------------------------
    add("B", "ko", "어휘",       role="section_header_ko")
    add("A", "en", "Vocabulary", role="section_header_en")

    for i, v in enumerate(story_data["vocab"]):
        ko_idx = add("B", "ko", v["ko"], role="vocab_word",  library_text_key=v["ko"])
        en_idx = add("A", "en", v["en"], role="vocab_gloss", library_text_key=v["ko"])
        idx["vocab_word"].append(ko_idx)
        idx["vocab_block"].append((ko_idx, en_idx))

    # --- Section: 예문 / Example sentences ----------------------------------
    add("B", "ko", "예문",             role="section_header_ko")
    add("A", "en", "Example sentences", role="section_header_en")

    for ex in story_data["examples"]:
        ko_idx = add("B", "ko", ex["ko"], role="example_ko", library_text_key=ex["ko"])
        en_idx = add("A", "en", ex["en"], role="example_en", library_text_key=ex["ko"])
        idx["example_ko"].append(ko_idx)
        idx["example_block"].append((ko_idx, en_idx))

    # --- Section: 표현 / Key expressions ------------------------------------
    add("B", "ko", "표현",            role="section_header_ko")
    add("A", "en", "Key Expressions", role="section_header_en")

    for ex in story_data["expressions"]:
        ko_idx = add("B", "ko", ex["ko"], role="expression_ko")
        en_idx = add("A", "en", ex["en"], role="expression_en")
        idx["expression_ko"].append(ko_idx)
        idx["expression_block"].append((ko_idx, en_idx))

    # --- Section: 뉴스 / News (easy Korean summary) ------------------------
    add("B", "ko", "뉴스", role="section_header_ko")
    add("A", "en", "News", role="section_header_en")
    add("B", "ko", "오늘의 쉬운 한국어 요약입니다.",                role="summary_intro_ko")
    add("A", "en", "Here's today's summary in easy Korean.",         role="summary_intro_en")

    summary_easy_start = len(turns)
    for sentence in story_data["summary_ko_easy"]:
        i = add("B", "ko", sentence, role="summary_ko_easy")
        idx["summary_ko_sentence"].append(i)
    summary_easy_end = len(turns) - 1
    idx["summary_ko_range"] = (summary_easy_start, summary_easy_end)

    # --- English summary block (Beginner set comprehension cushion) --------
    en_intro_ko_idx = add("B", "ko", "오늘의 영어 뉴스입니다.",                  role="summary_intro_ko")
    en_intro_en_idx = add("A", "en", "Here's today's full summary, in English.", role="summary_intro_en")
    en_summary_start = len(turns)
    for sentence in story_data["summary_en"]:
        add("A", "en", sentence, role="summary_en")
    en_summary_end = len(turns) - 1
    idx["english_summary_block"] = (en_intro_ko_idx, en_summary_end)

    # --- Natural Korean summary block (advanced listening) ----------------
    nat_intro_ko_idx = add("B", "ko", "이제 자연스러운 한국어 뉴스입니다.",   role="summary_intro_ko")
    nat_intro_en_idx = add("A", "en", "And now, the natural Korean version.", role="summary_intro_en")
    nat_summary_start = len(turns)
    for sentence in story_data["summary_ko_natural"]:
        add("B", "ko", sentence, role="summary_ko_natural")
    nat_summary_end = len(turns) - 1
    idx["natural_summary_block"] = (nat_intro_ko_idx, nat_summary_end)
    idx["natural_summary_korean_range"] = (nat_summary_start, nat_summary_end)

    # === Build PracticeSets =================================================
    last_turn = len(turns) - 1

    # Set 1 — Beginner (with English) — every turn, grouped into block clips
    beginner_clips: list[dict] = []
    # Track intro = one clip
    beginner_clips.append({
        "turn_range": list(track_intro_range),
        "title": "Headline",
        "languageCode": None,
    })
    # Vocab section (header + each word block)
    beginner_clips.append({
        "turn_range": [track_intro_range[1] + 1, track_intro_range[1] + 2],
        "title": "어휘 / Vocabulary",
        "languageCode": None,
    })
    for i, block in enumerate(idx["vocab_block"], start=1):
        ko_word = story_data["vocab"][i - 1]["ko"]
        beginner_clips.append({
            "turn_range": list(block),
            "title": f"Vocab {i}: {ko_word}",
            "languageCode": None,
        })
    # Example header
    after_vocab = idx["vocab_block"][-1][1]
    beginner_clips.append({
        "turn_range": [after_vocab + 1, after_vocab + 2],
        "title": "예문 / Example sentences",
        "languageCode": None,
    })
    for i, block in enumerate(idx["example_block"], start=1):
        beginner_clips.append({
            "turn_range": list(block),
            "title": f"Example {i}",
            "languageCode": None,
        })
    # Expression header
    after_examples = idx["example_block"][-1][1]
    beginner_clips.append({
        "turn_range": [after_examples + 1, after_examples + 2],
        "title": "표현 / Key Expressions",
        "languageCode": None,
    })
    for i, block in enumerate(idx["expression_block"], start=1):
        beginner_clips.append({
            "turn_range": list(block),
            "title": f"Expression {i}",
            "languageCode": None,
        })
    # News header + EASY Korean summary
    after_expressions = idx["expression_block"][-1][1]
    beginner_clips.append({
        "turn_range": [after_expressions + 1, idx["summary_ko_range"][1]],
        "title": "뉴스 (Easy Korean summary)",
        "languageCode": "ko-KR",
    })
    # English summary
    beginner_clips.append({
        "turn_range": list(idx["english_summary_block"]),
        "title": "English summary",
        "languageCode": "en-US",
    })
    # Natural Korean summary (advanced)
    beginner_clips.append({
        "turn_range": list(idx["natural_summary_block"]),
        "title": "Natural Korean summary",
        "languageCode": "ko-KR",
    })

    # Set 2 — Korean phrase loops — every Korean-only stretch as its own clip
    set2_clips: list[dict] = []
    for i, word_turn in enumerate(idx["vocab_word"], start=1):
        ko_word = story_data["vocab"][i - 1]["ko"]
        set2_clips.append({
            "turn_range": [word_turn, word_turn],
            "title": f"Vocab {i}: {ko_word}",
            "languageCode": "ko-KR",
        })
    for i, ko_turn in enumerate(idx["example_ko"], start=1):
        set2_clips.append({
            "turn_range": [ko_turn, ko_turn],
            "title": f"Example {i}",
            "languageCode": "ko-KR",
        })
    for i, ko_turn in enumerate(idx["expression_ko"], start=1):
        set2_clips.append({
            "turn_range": [ko_turn, ko_turn],
            "title": f"Expression {i}",
            "languageCode": "ko-KR",
        })
    for i, ko_turn in enumerate(idx["summary_ko_sentence"], start=1):
        set2_clips.append({
            "turn_range": [ko_turn, ko_turn],
            "title": f"Summary sentence {i}",
            "languageCode": "ko-KR",
        })

    # Set 3 — Easy Korean summary, single clip
    set3_clips = [{
        "turn_range": list(idx["summary_ko_range"]),
        "title": "Easy Korean summary",
        "languageCode": "ko-KR",
    }]

    # Set 4 — Natural Korean summary, single clip (advanced challenge)
    set4_clips = [{
        "turn_range": list(idx["natural_summary_korean_range"]),
        "title": "Natural Korean summary",
        "languageCode": "ko-KR",
    }]

    practice_sets = [
        {"title": "Beginner (with English)", "displayOrder": 0, "clips": beginner_clips},
        {"title": "Korean phrase loops",     "displayOrder": 1, "clips": set2_clips},
        {"title": "Easy Korean summary",     "displayOrder": 2, "clips": set3_clips},
        {"title": "Natural Korean summary",  "displayOrder": 3, "clips": set4_clips},
    ]
    return turns, practice_sets


def render_date_titles(date: str) -> tuple[str, str]:
    y, m, d = date.split("-")
    yi, mi, di = int(y), int(m), int(d)
    ko = f"{yi}년 {KO_MONTHS[mi]} {di}일 뉴스"
    en = f"US News, {EN_MONTHS[mi]} {di}, {yi}"
    return ko, en


def main() -> int:
    args = parse_args()
    date = args.date or today_eastern()

    chosen_path = WORK_ROOT / date / "chosen.json"
    if not chosen_path.exists():
        raise SystemExit(f"❌ chosen.json not found at {chosen_path}. Run step 1 first.")
    chosen = json.loads(chosen_path.read_text(encoding="utf-8"))
    stories = chosen["stories"]

    pack_id = f"news_{date.replace('-', '_')}"
    pack_title_ko, pack_title_en = render_date_titles(date)

    out_path = WORK_ROOT / date / "script.json"

    if not args.config.exists():
        raise SystemExit(f"❌ llm.yaml not found: {args.config}")
    llm_cfg = yaml.safe_load(args.config.read_text(encoding="utf-8")) or {}

    print(f"═══ Generating script for {date} ═══")
    print(f"  Pack ID:   {pack_id}")
    print(f"  Title:     {pack_title_ko} / {pack_title_en}")
    print(f"  Stories:   {len(stories)}")
    print(f"  Output:    {out_path}")
    print()

    if not args.commit:
        sample = stories[0]
        prompt = build_story_prompt(sample)
        print("--- DRY RUN — sample prompt for first story ---")
        print(prompt[:2000])
        if len(prompt) > 2000:
            print(f"... [truncated, full length {len(prompt)} chars] ...")
        print()
        print(f"Will call Claude {len(stories)} times (once per story) when --commit.")
        return 0

    # Install cost recorder + LLM providers (per-step)
    global _cost_recorder, _llm_script, _llm_qa, _max_tokens_script, _max_tokens_qa
    work_date_dir = WORK_ROOT / date
    _cost_recorder = StepCostRecorder("2_generate_script", work_date_dir)
    _llm_script = provider_for_step("script", llm_cfg)
    _max_tokens_script = max_tokens_for_step("script", llm_cfg, default=4096)
    if not args.no_qa:
        _llm_qa = provider_for_step("qa_review", llm_cfg)
        _max_tokens_qa = max_tokens_for_step("qa_review", llm_cfg, default=4096)
        print(f"📡 Script LLM: {_llm_script.name}/{_llm_script.model}  (max_tokens={_max_tokens_script})")
        print(f"📡 QA LLM:     {_llm_qa.name}/{_llm_qa.model}  (max_tokens={_max_tokens_qa})  ← cross-model review")
    else:
        print(f"📡 Script LLM: {_llm_script.name}/{_llm_script.model}  (max_tokens={_max_tokens_script})")
        print(f"📡 QA LLM:     (disabled with --no-qa)")
    print()

    # Load shared library for vocab/example reuse
    library = Library.load(CACHE_ROOT)
    lib_stats_before = library.stats_summary()
    print(f"📚 Library: {lib_stats_before['vocab_terms']} vocab, "
          f"{lib_stats_before['example_sentences']} examples, "
          f"{lib_stats_before['audio_files_on_disk']} cached audio files")
    print()

    story_outputs = []
    for s in stories:
        print(f"━━━ [{s['story_id']}] {s['headline'][:70]}")
        prompt = build_story_prompt(s)
        raw = call_llm(_llm_script, _max_tokens_script, prompt, label=f"script:{s['story_id']}")
        cleaned = strip_fences(raw)
        try:
            data = json.loads(cleaned)
        except json.JSONDecodeError as e:
            print(f"   ❌ JSON parse error: {e}", file=sys.stderr)
            print(cleaned, file=sys.stderr)
            raise SystemExit(1)

        qa_changes: list[str] = []
        if not args.no_qa:
            data, qa_changes = qa_review_story(s, data)
            if qa_changes:
                print(f"     ✎ QA made {len(qa_changes)} change(s):")
                for c in qa_changes:
                    print(f"        · {c}")
            else:
                print(f"     ✓ QA: no changes needed")

        # ── Library reuse: lock glosses + opportunistic example reuse ─────
        reuse_report = apply_library_reuse(data, library)
        if reuse_report["locked_glosses"]:
            print(f"     🔒 Library locked {len(reuse_report['locked_glosses'])} gloss(es):")
            for ko, claude_en, locked_en in reuse_report["locked_glosses"]:
                print(f"        · {ko}: '{claude_en}' → '{locked_en}' (locked)")
        print(f"     📚 Examples: {reuse_report['cached_examples_used']} cached + "
              f"{reuse_report['fresh_examples_added']} fresh = "
              f"{reuse_report['final_example_count']} total")
        if reuse_report["uncovered_vocab"]:
            print(f"        ⚠ Uncovered vocab (no example): {reuse_report['uncovered_vocab']}")

        # Record new vocab + fresh examples back to the library
        for v in data["vocab"]:
            library.record_vocab(v["ko"], v["en"], date)
        for ex in data["examples"]:
            library.record_example(ex["ko"], ex["en"], ex.get("vocab_covered", []), date)

        turns, practice_sets = build_turns_for_story(data, date)
        story_outputs.append({
            "story_id": s["story_id"],
            "category": s["category"],
            "headline": s["headline"],
            "source": s["source"],
            "link": s["link"],
            "track_title_ko": data["track_title_ko"],
            "track_title_en": data["track_title_en"],
            "vocab": data["vocab"],
            "examples": data["examples"],
            "expressions": data["expressions"],
            "summary_ko_easy": data["summary_ko_easy"],
            "summary_ko_natural": data["summary_ko_natural"],
            "summary_en": data["summary_en"],
            "qa_changes": qa_changes,
            "turns": turns,
            "practice_sets": practice_sets,
        })
        print(f"   ✓ {len(turns)} turns, {sum(len(ps['clips']) for ps in practice_sets)} clips across 3 sets")

    payload = {
        "date": date,
        "pack_id": pack_id,
        "pack_title_ko": pack_title_ko,
        "pack_title_en": pack_title_en,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "stories": story_outputs,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    library.save()
    _cost_recorder.write()
    lib_stats_after = library.stats_summary()
    print()
    print(f"✅ Wrote {out_path}")
    print(f"   Cost report: {_cost_recorder.work_dir}/costs/{_cost_recorder.step}.json")
    print(f"   Total Claude usage: input={_run_totals['input_tokens']} output={_run_totals['output_tokens']} tokens  est_total_cost=${_run_totals['cost_usd']:.4f}")
    print(f"   📚 Library now: {lib_stats_after['vocab_terms']} vocab (+{lib_stats_after['vocab_terms'] - lib_stats_before['vocab_terms']}), "
          f"{lib_stats_after['example_sentences']} examples (+{lib_stats_after['example_sentences'] - lib_stats_before['example_sentences']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
