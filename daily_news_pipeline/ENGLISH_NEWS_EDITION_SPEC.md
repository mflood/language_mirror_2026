# English News Edition — pipeline spec

Hand-off spec for the pipeline session. Goal: a daily **English-audio** news
edition for **Korean learners** — the mirror of today's Korean-audio edition
for English learners. Language Mirror serves both directions; the news stream
must too.

Decisions already made (Matthew, 2026-07-09):
- **Full pedagogical mirror** — English vocab/idioms + scaffolded easy example
  sentences + easy & natural English summaries, all with **Korean** glosses.
  (Not a lean summary-only edition.)
- **App surfacing is DONE** (see "App side" below) — the app already shows two
  "Today's News" rows, locale-ordered, and the daily reminder picks the edition
  by device locale. It points at the alias `lmaudio/news_en_latest/bundle.json`.
  The pipeline just needs to fill that alias.

## The insight: symmetric, and simpler

The current edition reads English news → **writes Korean** (summary/vocab/
examples) → Korean audio + English gloss. The English edition reads the **same
English news** → **simplifies the English** → English audio + **Korean** gloss.
There is no translate-into-target step (the source is already the target
language), so it's the Korean edition mirrored with `ko↔en` swapped, minus one
translation hop.

Steps **0 (fetch) and 1 (curate) are language-independent** — curate the day's
stories ONCE, then branch to two editions for steps 2–6. Don't double the fetch
or the story selection.

## Per-step changes

Add an `--edition {ko,en}` flag (default `ko`, preserving current behavior)
to steps 2–6. `ko` = today's behavior unchanged.

**Step 2 `2_generate_script.py`** — the big one. Parameterize the prompt by
edition. For `en`:
- Target language = English; learner = intermediate Korean speaker (roughly
  CEFR B1–B2 / a Korean high-school–university English level).
- Output schema mirrors the Korean one with `ko↔en` swapped:
  `track_title_en`/`track_title_ko`, `vocab: [{en, ko}]` (English content
  word + Korean gloss — prioritize the things Korean learners actually
  struggle with: **phrasal verbs, idioms, collocations, polysemous verbs**,
  not just single nouns), `examples: [{en, ko}]` (scaffolded EASY English —
  everyday subjects I/we/students, present tense, one clause, 5–12 words,
  strictly easier than the summary), `expressions: [{en, ko}]`,
  `summary_en_easy`, `summary_en_natural`, `summary_ko` (the Korean gloss of
  the summary).
- Same non-negotiable FACTUAL FIDELITY block.
- Keep the scaffolding contract (vocab → easy examples → easy summary →
  natural summary), just in English.

**Step 2b `2b_translate_easy.py`** — for `ko` it adds English glosses to the
easy summary. For `en` the target IS English, so instead add **Korean** glosses
to the easy English summary (`summary_ko_easy` alongside `summary_en_easy`).
Same shape, opposite direction.

**Step 3 `3_synthesize.py`** — TTS. `tts.yaml` already has an English teacher
voice (`voice_a`) and Korean narrator (`voice_b`). For `en`, the **audio being
practiced is English**, so the primary/narration voice is English. The
role→language map inverts: `vocab_word`→**en** audio (was ko), `vocab_gloss`→
**ko** (was en); `example_en` is the practiced line, `summary_en_*` is English
audio. Consider a second English voice for two-speaker feel (the starter-pack
work used ElevenLabs Rachel `21m00Tcm4TlvDq8ikWAM` + the config English male
`UgBBYS2sOqTuMpoF3BR0`).

**Step 4 `4_assemble_bundle.py` + studypack `adapters/news.py`** — the adapter
already has `example_en`/`expression_en`/`section_header_en` role names, so it
partly anticipates this. Make it edition-aware: set `studypack.Languages.primary
= "en"` for the English edition and map roles so the **English** spans are the
practiced text and `translations.ko` carries the gloss. The iOS bundle schema is
unchanged — `transcripts[].translations` keyed by base code (`ko`), exactly
what the starter English packs already ship and the app already renders.

**Step 5 `5_publish_s3.py`** — publish English packs under a dated prefix
(suggest `news_en_YYYY_MM_DD`) and alias the rolling
**`lmaudio/news_en_latest/bundle.json`** (mirror of `news_latest`; the current
`LATEST_ALIAS_KEY` constant becomes edition-derived). The pack `id` and inner
audio URLs stay dated so imports dedup.

**Step 6 `6_deploy_news_page.py`** — optional; an English news web page can
follow later. Not required for the app.

**`run_daily.sh`** — restructure to: fetch (0) → curate (1) once → then for each
edition in {ko, en}: steps 2–6 with `--edition`. Cost roughly doubles for 2–6
(cents-scale per run), fetch/curate unchanged.

## App side (DONE — for reference, do not re-implement)

- `NewsNotificationService.latestEnglishNewsBundleURL` → `news_en_latest`.
- `localePrefersEnglishNews` (Korean UI locale ⇒ true) and
  `preferredNewsBundleURL`; the daily reminder opens the preferred edition.
- Featured Packs shows both "Today's News" rows, ordered so the user's likely
  learning direction leads. Rows point at the two aliases via the existing
  remote-manifest import path.
- The English row imports gracefully-fails until `news_en_latest` exists, so
  the app can ship ahead of the pipeline.

## Copyright / verbatim-copy guard (REQUIRED for the en edition)

The en edition is English source → English output, so the LLM can lift
distinctive phrasing straight from a copyrighted article. Facts are free;
*expression* is not. The existing cross-model QA review (`qa_review_story`)
checks factual fidelity, difficulty, and grammar — it does **not** check for
copying. Two layers close that gap:

1. **Prompt instruction (generation + QA):** the en script prompt must state,
   as a non-negotiable alongside FACTUAL FIDELITY: *"Restate every fact in your
   own words at the target reading level. Do NOT reuse the source's sentences
   or distinctive phrasing. No sentence may share a run of 6+ consecutive words
   with the source article. Quote only when unavoidable and clearly marked."*
   The pedagogy already pushes this way (simplify to ~CEFR B1, 5–12 word
   sentences, everyday vocab) — a properly simplified summary is necessarily
   reworded — but say it explicitly. The `summary_en_natural` (news register)
   is the highest-risk field; watch it hardest.

2. **Deterministic gate (`check_verbatim_overlap.py`) — WIRED
   `2_generate_script.py`:** after the QA pass, `verbatim_flags(story, data)`
   runs every English string (summaries + examples + title) against the source
   body and flags any run ≥ 6 shared consecutive words. On the **en edition**
   it's a hard gate: a flag triggers ONE rewrite (the offending phrases are fed
   back into the prompt with an explicit reword instruction); if it still flags,
   the story is DROPPED from the bundle rather than shipped. If every story is
   dropped the step exits non-zero rather than write an empty bundle. It's
   deterministic, free, and doesn't rely on the model policing itself.

   ```
   from check_verbatim_overlap import check_texts, english_texts_from_script
   flags = check_texts(source_body, english_texts_from_script(script), min_run=6)
   ```

   On the **ko edition** the same check runs on its English fields
   (`summary_en`) but is **advisory** (logged, not dropped) — cross-language
   narration can't be a verbatim copy, so only the gloss field is at issue.

Note: the embedded `starter_english_*` packs are ORIGINAL works (topic-
generated dialogue) or public domain (the Dickinson poem) — no source article,
no exposure. This guard is specifically for the news edition's article-derived
text.

## Acceptance (all verified 2026-07-10 — first production run via launchd)

1. ✅ `run_daily.sh --commit` produces BOTH `news_latest` and `news_en_latest`
   bundles from one curate pass.
2. ✅ The English bundle validates against the iOS schema (same as the embedded
   `starter_english_*` packs: `transcripts[].translations.ko` present on every
   span) and plays in the app via the "Daily English News" row.
3. ✅ The Korean edition output is byte-for-byte unchanged when run without
   `--edition en` (no regression).
4. ✅ Every published English news bundle passes `check_verbatim_overlap.py`
   against its source article (no 6+ word verbatim runs) — a copyright gate,
   not advisory. Wired into `2_generate_script.py` as `verbatim_flags()`:
   rewrite-once-then-drop for the en edition; advisory for ko's English fields.
