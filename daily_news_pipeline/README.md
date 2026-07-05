# Daily News Pipeline

Generates a daily Korean-language news listening pack from U.S. news sources
and publishes it to S3 + sixwandsstudios.com for English-speaking learners of
Korean. End-to-end: RSS fetch → LLM curation + script generation → cross-model
QA review → TTS synthesis → iOS-compatible bundle assembly → S3 publish + QR
code → static website deploy.

Each daily run costs roughly **$1.70 in API spend** and takes ~10-12 minutes
end-to-end.

## Who this is for

The target listener is an English speaker learning Korean (TOPIK 2-4 range)
who wants to stay in touch with U.S. news without switching to Korean
domestic news. The pack teaches advanced topical vocabulary in the context
of stories the listener already understands the gist of.

## Pack structure

One **Pack** per day. Each Pack has 4 **Tracks** (one per chosen story).
Each Track has **4 PracticeSets**:

| # | Set name | Purpose | Clip count |
|---|---|---|---|
| 1 | Beginner (with English) | Full bilingual narration — vocab, examples, expressions, summary, English cushion, then the natural Korean version | ~25 clips |
| 2 | Korean phrase loops | All Korean-only stretches broken into short clips for pronunciation drill | ~20 clips |
| 3 | Easy Korean summary | TOPIK 2 summary as a single continuous clip (해요 form) | 1 clip |
| 4 | Natural Korean summary | TOPIK 3-4 summary as a single continuous clip (습니다 form) | 1 clip |

Sets 3 and 4 cover the same 3 facts at different difficulty levels — the
listener picks their level. Set 1 plays both back-to-back so a beginner can
listen to the easy version with English, then attempt the natural version.

## Section structure per story

Each Track contains these sections in order (some are the same text every
day, which the library cache picks up across packs):

1. **헤드라인** — story title (Korean + English)
2. **어휘 / Vocabulary** — up to 12 advanced Korean words from the summary
3. **예문 / Example sentences** — 5-8 sentences using vocab in *everyday*
   contexts (school, family, friends — strict scaffolding)
4. **표현 / Key Expressions** — 2 useful collocations from the news story
5. **뉴스 / News**
   - Easy Korean summary (4-8 short sentences, 해요 form)
   - English summary (3 sentences)
   - Natural Korean summary (3 sentences, 습니다 form)

## Architecture

The pipeline is 8 numbered steps (incl. 2b) plus a cron entry point, two
local helper modules, and five langpack subsystem packages. Each step has a single responsibility and writes its output to
`work/<date>/`. Steps can be re-run independently.

```
┌─────────────────────────────────────────────────────────────────────┐
│   run_daily.sh                                                      │
│   cron entry point. Sources .env, runs 0→2→2b→3→…→6, finalizes cost │
│   ledger.                                                           │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────┐    ┌────────────────────────────┐
│ 0_fetch_feeds.py             │    │ feeds.yaml                 │
│ Pull RSS from 8 hard + 4     │ ←──│ Source URLs + genre tags   │
│ feature sources              │    └────────────────────────────┘
└──────────────────────────────┘
        │ work/<date>/feeds.json
        ▼
┌──────────────────────────────┐    ┌────────────────────────────┐
│ 1_curate.py                  │    │ llm.yaml                   │
│ LLM picks 4 stories: 2 hard  │ ←──│ steps.curate:              │
│ + 2 features. Politics cap.  │    │   anthropic/claude-sonnet  │
│ Features prefer explainers.  │    └────────────────────────────┘
│ Fetches article bodies via   │
│ trafilatura.                 │
└──────────────────────────────┘
        │ work/<date>/chosen.json
        ▼
┌──────────────────────────────┐    ┌────────────────────────────┐
│ 2_generate_script.py         │    │ llm.yaml                   │
│ Per story: generate vocab +  │ ←──│ steps.script:              │
│ examples + 2 summary tiers + │    │   anthropic/claude-sonnet  │
│ expressions. Then cross-     │    │ steps.qa_review:           │
│ model QA review.             │    │   openai/gpt-5.5           │
│                              │    └────────────────────────────┘
│ Applies library reuse:       │    ┌────────────────────────────┐
│ - lock vocab glosses to      │ ←──│ lexicon (langpack)         │
│   library canonical          │    │ vocab + examples + audio   │
│ - opportunistic example      │    │ keys (cross-day reuse)     │
│   reuse via greedy set cover │    └────────────────────────────┘
└──────────────────────────────┘
        │ work/<date>/script.json  (turns + practice_sets)
        ▼
┌──────────────────────────────┐
│ 2b_translate_easy.py         │
│ Per-sentence English for the │
│ easy summary (haiku, ~$0.004)│
│ → summary_en_easy in script  │
└──────────────────────────────┘
        │
        ▼
┌──────────────────────────────┐    ┌────────────────────────────┐
│ 3_synthesize.py              │    │ tts.yaml                   │
│ Per turn: compute audio_key, │ ←──│ provider: polly|elevenlabs │
│ check library cache, else    │    │ polly:    Matthew, Seoyeon │
│ synth via active provider.   │    │ elevenlabs: voice_a, b...  │
│ Concat turns into mp3 per    │    └────────────────────────────┘
│ story; write timings.json.   │    ┌────────────────────────────┐
│                              │ ←──│ voicebox (langpack)        │
│ Caches: writes mp3 + sidecar │    │ ElevenLabs + Polly adapters│
│ JSON (provider, voice, cost, │    └────────────────────────────┘
│ duration, library role).     │
└──────────────────────────────┘
        │ work/<date>/audio/<story_id>.mp3
        │ work/<date>/audio/<story_id>.timings.json
        ▼
┌──────────────────────────────┐
│ 4_assemble_bundle.py         │
│ Convert turn-range clip defs │
│ into ms-range Clip objects.  │
│ Attach English glosses to    │
│ Korean clip titles in set 2. │
│ Build BundlePack/Track/      │
│ PracticeSet/Clip JSON in     │
│ iOS-compatible schema.       │
└──────────────────────────────┘
        │ work/<date>/bundle.json
        ▼
┌──────────────────────────────┐
│ 5_publish_s3.py              │
│ Publish via langpack         │
│ `publisher` (clobber gate,   │
│ post-flight verify, CF       │
│ invalidation) to lmaudio.    │
│ Update news_latest alias.    │
│ Generate QR PNG pointing at  │
│ CloudFront manifest URL.     │
└──────────────────────────────┘
        │ work/<date>/qr.png
        ▼
┌──────────────────────────────┐
│ 6_deploy_news_page.py        │
│ Render day page + rolling    │
│ archive via langpack         │
│ `pagesmith`; write to local  │
│ git-versioned site tree;     │
│ git commit; publish via      │
│ `publisher` (protected-keys  │
│ preflight, clobber gate,     │
│ --redeploy, CF invalidation) │
│ to sixwandsstudios.com.      │
└──────────────────────────────┘
        │ https://sixwandsstudios.com/news/<date>/
        ▼
┌──────────────────────────────┐    ┌────────────────────────────┐
│ run_daily.sh finalize        │ ──→│ cache/cost_history/        │
│ aggregates work/<date>/      │    │ YYYY/MM/<date>_<HHMMSS>.json│
│ costs/*.json                 │    └────────────────────────────┘
└──────────────────────────────┘
```

## Helper modules

| File | Role |
|---|---|
| `lexicon` (package) | Shared vocabulary library at `~/.langpack/lexicon/ko-en.json`: canonical gloss locking, greedy set-cover example reuse, audio-key attachment. Inspect via the `lexicon` CLI. |
| `cost_tracker.py` | StepCostRecorder + finalize_run. Per-step JSON in `work/<date>/costs/`; aggregated daily entry in `cache/cost_history/YYYY/MM/`. Provider pricing tables (estimates only). |
| `studypack` / `voicebox` (packages) | langpack subsystems (editable installs from `~/workspace/langpack/`). Step 3 converts script.json → studypack in-memory and synthesizes via voicebox over the shared cache. |
| `llm_providers.py` | Abstract `LLMProvider` + `AnthropicProvider` + `OpenAIProvider`. Per-step selection via `llm.yaml`. Handles GPT-5/o1/o3 `max_completion_tokens` quirk. |
| `cost_history.py` | Prints the aggregated daily cost ledger from `cache/cost_history/`. (Vocab inspection moved to the `lexicon` CLI.) |
| `verify_whisper.py` | Diagnostic: transcribe synthesized audio with Whisper large-v3, compare to script, produce mismatch report. Does NOT re-synthesize. |

## Source feeds (current — `feeds.yaml`)

**Hard news pool — politically balanced** (8 sources):
- *Left-leaning*: NPR, Guardian US
- *Centrist*: BBC US/Canada, CBS News, Politico
- *Right-leaning*: Fox News, Washington Examiner, NY Post

**Feature pool — concrete vocab** (4 sources):
- Ars Technica (tech), Science News (science), ESPN (sports), NPR Arts (arts)

Reuters retired their public RSS in 2023; NYT and The Hill paywall their
article bodies so trafilatura returns empty. Avoided.

## Curation rules

- Target **4 stories total** — 2 hard + 2 features.
- **Politics cap**: never include 3+ politics/diplomacy/conflict stories in
  one pack. If all top hard news is politics-heavy, drop to 1 hard + 3
  features.
- **Feature preference ladder** (most → least preferred):
  1. Explainer / how-it-works / human-interest
  2. Science
  3. Arts / culture
  4. Tech
  5. Sports (last resort — narrow vocab transfer)
- LLM may pull explainer-style stories from the HARD pool and tag them as
  features.

## Prompt design philosophy

The script generator (step 2) enforces these properties in the LLM prompt;
the cross-model QA reviewer (also step 2) verifies them.

### Difficulty constraints

- **summary_ko_easy** — TOPIK 2: ≤12 words per sentence, 해요 form, ≤2
  Sino-Korean compounds per sentence, TOPIK 1-2 verbs outside the vocab
  list, no embedded clauses.
- **summary_ko_natural** — TOPIK 3-4: 3 sentences, 습니다 form, news
  register. Same 3 facts as the easy version, just at higher difficulty.

### Scaffolding constraint (examples must be easier than the summary)

- Subjects must be everyday people/things (저, 우리, 학생들, 친구, 가족,
  경찰). News subjects like 대통령, 정부, 당국 are flagged.
- Contexts must be daily life (school, family, neighborhood). Not
  diplomatic/economic/medical/political.
- Present tense; one subject + one verb per sentence; 5-12 words; no
  embedded clauses.
- Example: vocab `봉쇄` (blockade) → good: "사고 때문에 도로 봉쇄가 있었어요"
  (everyday road blockage), bad: "양측이 봉쇄 해제를 논의했어요" (news).

### Factual fidelity guardrails

Both summary levels and all examples must be supported by the source
article. Hard rules: no invented numbers/dates/names, no fabricated
quotes (no quotation marks unless the words match source verbatim), no
attributions to people who weren't quoted, "약 5만 명" not "정확히 5만 명"
when source says "around 50,000". GPT-5.5 reviews against the article
body and flags violations.

### Vocab + example combination logic

- 5-12 vocab words per story, picked by LLM from the easy summary's
  content.
- Examples may combine 2-3 vocab words per sentence to keep total example
  count low (5-6 sentences usually) while covering every vocab word at
  least once. Greedy set cover from the cached example library covers
  what it can; LLM-fresh examples fill gaps.

## Library cache + cross-day reuse

Two-tier cache:

1. **Content-addressed audio cache** — key is sha256 of (text + provider +
   voice_id + model + settings). Every turn in a script computes its key;
   cache hit copies the existing mp3, cache miss synthesizes and adds to
   cache. Sidecar `<key>.json` has full provenance.
   Since 2026-07-04 this lives in the **shared langpack cache** at
   `~/.langpack/cache/audio` (configured via `cache_dir` in tts.yaml) and is
   managed by the `voicebox` package — shared with the kdrama pipeline and
   any future producer. The local `cache/audio/` dir is frozen legacy (its
   contents were imported into the shared cache) and is only read by
   the `lexicon play` CLI.

2. **Structural library** (`cache/library.json`) — vocab terms with locked
   canonical English glosses + example sentences tagged by which vocab
   words they cover. Step 2 uses this to:
   - Replace LLM's vocab gloss with the locked canonical (pedagogical
     consistency: 협상 always glosses to "negotiation")
   - Pre-select cached examples that cover today's vocab via greedy
     set cover

After 30 days of daily runs, expect 50-70% cache hit rate on synthesis
(section headers reuse every day; common vocab repeats across stories;
similar example sentences for repeated vocab). Hit rate on day 1 of fresh
cache is ~20%, climbing fast.

Inspect the library:

```sh
lexicon stats
lexicon vocab --top 20
lexicon show 협상       # full vocab entry with variants
lexicon play 협상       # afplay the cached audio
lexicon orphans         # cache audio not referenced by the lexicon
lexicon set-gloss 협상 "talks, negotiation"   # manually override
python3 cost_history.py                      # daily cost ledger
python3 cost_history.py --since 2026-06-01           # runs by date
```

## Cost ledger

Each `run_daily.sh` invocation writes a timestamped report to
`cache/cost_history/YYYY/MM/YYYY-MM-DD_HHMMSS.json`. The schema:

```json
{
  "date": "2026-06-07",
  "totals": {"estimated_cost_usd": 1.71, "llm_cost_usd": 0.33, "tts_cost_usd": 1.38},
  "providers": {
    "anthropic/claude-sonnet-4-5": {"calls": 5, "input_tokens": ..., "cost_usd": 0.13},
    "openai/gpt-5.5":              {"calls": 4, "input_tokens": ..., "cost_usd": 0.20},
    "elevenlabs/creator":          {"calls": 296, "cache_hits": 99, "cache_misses": 197, "chars_debited": 5225, "cost_usd": 1.38}
  },
  "steps": {"1_curate": {...}, "2_generate_script": {...}, "3_synthesize": {...}},
  "library_growth": {...}
}
```

Per-day reports are partitioned by year/month so a 5-year history stays
browsable.

## Cost model (per pack — real numbers from production runs)

| Component | Cost | Notes |
|---|---|---|
| Curate (1 Claude call) | ~$0.05 | ~14k input + ~300 output tokens |
| Script generation (5 Claude calls, sonnet-4-5) | ~$0.10 | ~1.5k input + ~1k output per story |
| QA review (5 GPT-5.5 calls) | ~$0.20 | Reasoning model uses more output tokens |
| TTS — ElevenLabs Creator (~7k chars after cache hits) | ~$1.40 | $0.00022/char × Korean multiplier |
| TTS — Polly neural (alternative, ~5k chars after hits) | ~$0.025 | 50× cheaper, lower quality |
| S3 PUT + CloudFront | ~$0.001 | Negligible |
| **Total per day (ElevenLabs)** | **~$1.70** | ~$50/month at 1 pack/day |
| **Total per day (Polly)** | **~$0.30** | For iteration / testing |

## Operating the pipeline

### Daily run (production)

```sh
cd daily_news_pipeline
./run_daily.sh --commit                    # today's date in US/Eastern
./run_daily.sh --commit --date 2026-06-14  # specific date
```

Each step in run_daily.sh runs in sequence; failure of any step aborts the
rest. Logs to `work/<date>/run.log` and stdout. Defaults to dry-run; the
`--commit` flag is required to actually spend.

### Dry-run a single step

Every step has `--commit`; without it, the step prints what it would do.
Useful for inspecting prompts before spending:

```sh
python3 1_curate.py --date 2026-06-14                # see the curation prompt
python3 2_generate_script.py --date 2026-06-14       # see the script prompt
python3 5_publish_s3.py --date 2026-06-14            # see upload plan + check clobber
```

### Switch TTS provider

Edit `tts.yaml`:
```yaml
provider: polly   # was elevenlabs
```

Or one-off override:
```sh
python3 3_synthesize.py --date 2026-06-14 --tts polly --commit
```

### Switch LLM model per step

Edit `llm.yaml`:
```yaml
steps:
  qa_review:
    provider: anthropic
    model: claude-opus-4   # was openai/gpt-5.5
```

### Verify audio quality

```sh
python3 verify_whisper.py --date 2026-06-14
# Produces work/<date>/verify_report.md with similarity scores per turn.
# Mismatches under threshold (KO: 0.75, EN: 0.85) are flagged.
```

## Safety gates

- All API-spending steps default to **dry-run**; `--commit` is required.
- Hard character cap on TTS (20,000 chars/run by default).
- TTS confirmation prompt above 15,000 chars.
- S3 deploy is **cp-only** — never `aws s3 sync --delete`, never `aws s3 rm`.
- Pre-flight bucket integrity check before step 6 — refuses to deploy if
  any of 9 protected top-level files is missing from
  `s3://sixwandsstudios.com/`.
- Refuse-to-clobber checks in step 5 (bundle bucket) and step 6 (website)
  flag existing keys at the destination prefix and abort the deploy.
  Manual delete is required to overwrite — by design.
- Local website source under `~/Desktop/sixwandsstudiosllc/sixwands.com/`
  is git-versioned. Step 6 creates a commit before each S3 push so git
  is the recovery path.

## Configuration files

| File | What it controls |
|---|---|
| `feeds.yaml` | RSS source URLs + genre tags. Curate pulls from these. |
| `llm.yaml` | Per-step LLM provider + model + max_tokens. |
| `tts.yaml` | Active TTS provider + per-provider voice + settings. |
| `requirements.txt` | Python dependencies. |
| `../.env` | API keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`. Gitignored. |

## File layout

```
daily_news_pipeline/
├── README.md                    ← this file
├── requirements.txt
├── feeds.yaml                   ← RSS sources
├── llm.yaml                     ← per-step LLM config
├── tts.yaml                     ← TTS provider + voices
│
├── 0_fetch_feeds.py             ← pipeline step 0
├── 1_curate.py                  ← step 1
├── 2_generate_script.py         ← step 2
├── 2b_translate_easy.py         ← step 2b (easy-summary EN)
├── 3_synthesize.py              ← step 3
├── 4_assemble_bundle.py         ← step 4
├── 5_publish_s3.py              ← step 5
├── 6_deploy_news_page.py        ← step 6
├── run_daily.sh                 ← cron entry point
│
├── (vocab library via lexicon)  ← langpack subsystem, ~/.langpack/lexicon/
├── cost_tracker.py              ← shared: cost recording
├── llm_providers.py             ← shared: LLM abstraction
├── (tts via voicebox package)   ← langpack subsystem
├── cost_history.py              ← cost ledger CLI
├── verify_whisper.py            ← QA diagnostic
│
├── cache/                       ← gitignored runtime state
│   ├── library.json             ← FROZEN legacy (imported into ~/.langpack/lexicon/)
│   ├── audio/                   ← FROZEN legacy (imported into ~/.langpack/cache/audio/)
│   └── cost_history/            ← still live: aggregated daily cost ledger
│       └── YYYY/MM/
│           └── <date>_<HHMMSS>.json
│
└── work/                        ← gitignored per-day work
    └── <YYYY-MM-DD>/
        ├── feeds.json
        ├── chosen.json
        ├── script.json
        ├── audio/
        │   ├── <story_id>.mp3
        │   ├── <story_id>.timings.json
        │   └── turns/<story_id>/turn_NNN_<key8>.mp3
        ├── bundle.json
        ├── qr.png
        ├── run.log
        └── costs/
            ├── 1_curate.json
            ├── 2_generate_script.json
            └── 3_synthesize.json
```

## Cron (not yet wired up)

Intended setup: macOS launchd or cron at 8:00 ET, running `./run_daily.sh
--commit`. Not currently scheduled — runs are triggered manually.

## Publishing destinations

| Artifact | URL pattern |
|---|---|
| Pack manifest | `https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/news_YYYY_MM_DD/bundle.json` |
| Latest-pack alias | `…/lmaudio/news_latest/bundle.json` — stable key, rewritten + CloudFront-invalidated on every publish; resolved by the iOS daily reminder (see `NEWS_PUSH_PIPELINE_SPEC.md`). Manifest only — its pack id and audio URLs stay dated. |
| Audio tracks | `…/news_YYYY_MM_DD/story_N.mp3` |
| QR scheme (deep link) | `languagemirror://bundle?url=<encoded manifest URL>` |
| Day's landing page | `https://sixwandsstudios.com/news/YYYY-MM-DD/` |
| Archive page | `https://sixwandsstudios.com/news/` |

All uploads go through the langpack `publisher` package (destination registry
at `~/.langpack/publisher.yaml`): cp-only, clobber-gated, post-flight
verified, CloudFront-invalidated. Never deletes.
