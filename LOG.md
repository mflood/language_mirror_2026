# Language Mirror — Session Log

Reverse-chronological notes about non-trivial work. Routine commits aren't
listed; consult `git log` for the full history.

---

## 2026-07-10 — English News Edition shipped (Korean learners of English)

- Daily pipeline now produces two editions from one curate pass: ko (original)
  and en (English audio, Korean glosses) via --edition on steps 2–5.
  Publishes news_en_YYYY_MM_DD + lmaudio/news_en_latest alias — the app's
  "Daily English News" row and locale-aware reminder were already wired.
- studypack adapter is edition-aware (Languages.primary from script,
  direction-agnostic translation pairing); new en-ko lexicon store.
- First production run verified via launchd kickstart: both aliases live,
  248/248 en spans carry ko glosses, voices mirrored (en→A, ko→B).
  ko edition byte-identical (no regression). ~$4.2/day for both editions.


## 2026-07-04/05 — langpack platform: pipeline decomposed into six subsystems

- Extracted the daily-news pipeline's shared machinery into standalone repos
  at ~/workspace/langpack/: studypack (schema), voicebox (TTS + shared cache),
  publisher (gated S3/CDN), bundler (iOS bundles), lexicon (vocab library),
  pagesmith (HTML renderers). kdrama_poc migrated onto the same subsystems.
- Every extraction verified byte/UUID-identical against production artifacts;
  tts_providers.py, cache_lib.py, library_inspect.py retired.
- Pipeline steps are now thin orchestrators; see daily_news_pipeline/README.md
  architecture diagram and each langpack repo's CLAUDE.md.


## 2026-07-05 — news_latest alias published for the daily reminder (pipeline side)

- `5_publish_s3.py` now also copies each day's `bundle.json` to the stable
  key `lmaudio/news_latest/bundle.json` and CloudFront-invalidates it
  (NEWS_PUSH_PIPELINE_SPEC.md option A; acceptance verified live).
- Pack id + audio URLs inside stay dated, so the app dedups cleanly.
- App follow-up tracked in NEXT.md #4: point the local reminder's tap at
  the alias instead of the constructed dated URL.


## 2026-04-09 — Color-coded clip cells, swipe-to-reset, remote catalog, three more starter packs

- Added 3 more Polly-generated starter packs:
  `starter_korean_greetings` (beginner dialogue, 41s),
  `starter_seoul_subway` (intermediate dialogue, 51s),
  `starter_korean_story` (intermediate monologue, 54s).
  Featured Packs catalog now has 4 cohesive Seoul-themed entries with
  distinct icons and accent colors. Total embedded audio ~3 MB.
  Pipeline batch cost: ~$0.04 (commits `4cd5463`).
- #13 Color-coded clip cells by completion (commit forthcoming).
- Swipe-to-reset on practice clips now works outside edit mode.
- #18 Remote catalog override: FeaturedCatalogService now races a CDN
  fetch and prefers the fresher copy.
- Created NEXT.md and LOG.md per workspace convention.

## 2026-04-08 — Lock screen artwork, speaker labels, three more bundles, AKC removed

- #5 Lock screen transcript artwork: 600x600 image rendered from current
  clip transcript text, warm cream-on-brown, auto-sized font, falls back
  to muted title (commit `f8e5557`).
- #12 Speaker labels in transcript banner with compact "A: " / "B: "
  prefixes when a clip has multiple speakers; "Speaker A" / "Speaker B"
  headers in detail sheet.
- Removed AKC pack from embedded bundles + Featured Packs catalog (IP)
  (commit `e9ff8a4`). Sample bundle pipeline now has explicit IP-review
  warning at the embed step.
- First Polly end-to-end run produced `starter_seoul_lunch` (12-turn
  dialogue, ~48s, $0.001 Polly + ~$0.001 OpenAI curation) and validated
  the entire 4-step pipeline.
- Auto-install starter sample on first launch when library is empty.
  UserDefaults flag prevents re-import. Existing libraryDidAddTrack
  observer drives the UI refresh.
- Featured Packs catalog: in-app `featured_catalog.json` listing both
  embedded and remote bundles. New `FeaturedCatalogService` +
  `FeaturedPacksViewController` accessible from Import tab.
- Deleted ~286 MB of legacy embedded packs (audio_files/, embedded_packs/,
  PackSelectionViewController, EmbeddedBundleManifestLoader chain).
  .app dropped from ~300 MB to 12 MB.
- Refactored `ImportBundleManifestDriver` so the manifest processing is
  source-agnostic via a new `AudioSourceResolver` protocol with remote
  and app-bundle implementations. Foundation for the embedded-bundle
  flow used by the Polly pipeline.

## 2026-04-07 — Sample bundle pipeline scaffolding (overnight, dry-run only)

- Built `sample_bundle_pipeline/` with 4 scripts:
  generate_script.py (Anthropic/OpenAI), synthesize_audio.py (Polly with
  10K char cap and dry-run default), make_qr_pack.sh (wraps existing
  bundle_pipeline), embed_in_app.py (functional, tested against AKC
  pack 4 as proof-of-concept).
- Discovered Xcode 16 Synchronized File System Groups flatten nested
  folders at build time. Worked around by prefixing filenames with the
  bundle id and looking up flat via `Bundle.main.url(forResource:)`.
- All paid steps default to dry-run; --commit is required.

## 2026-04-06 — Transcript banner + adjustable font + loop-current-clip

- Transcript banner above the speed strip showing current clip transcript,
  tappable to expand into a sheet. Banner collapses to 0 height when no
  transcripts.
- Detail sheet with copy/share buttons + A−/A+ font size toggle (max 56pt
  for accessibility).
- Loop-just-this-clip button (repeat.1 icon) toggles
  `AVPlayer.loopCurrentClipOnly` to override the advance-to-next logic.
- Lazy session creation in clip-tap handler so playback can start without
  pressing the play button first.

## Earlier

- Korean localization wrap (198 strings across 24 files), refactor of
  practice clip layout, fix for full-track 166:39 duration bug, App Store
  iPad orientation fix, Korean voice mapping, etc. See `git log`.
