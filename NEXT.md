# Language Mirror — Next Up

The 3 things to do next, in priority order. See `PRODUCT_IDEAS.md` for the
broader backlog and `LOG.md` for what's already shipped.

## ElevenLabs quota preflight in step 3 (blocked on API key permission)

Enable the `user_read` permission on the ElevenLabs API key (dashboard →
API keys), then add a preflight to `3_synthesize.py`: compare remaining
credits (`GET /v1/user/subscription`) against the run's estimated debit and
fail fast with "top up ~N credits" BEFORE synthesizing — the 2026-07-11 run
died mid-story instead. Recovery stays cheap either way (cache), but the
failure email should name the fix. The check belongs in voicebox (see
voicebox NEXT.md); step 3 just surfaces it.

## ✅ DONE: English starter packs are LIVE (remote, version-safe)

All five English starter packs (greetings, directions, cafe, story,
Dickinson poem) are published as REMOTE bundles on CloudFront and
referenced remotely in the live `featured_catalog.json` (published
2026-07-10). Because they're remote (not embedded), every app version —
including all current users — can install them by download, with no
publish-ordering gate. The earlier embedded approach + "ship then
publish" gate was retired to avoid breaking non-upgraded users. Only
the English NEWS edition remains (pipeline side).

## ⏳ Release gate: refresh App Store screenshots in the Six Wands language

Before shipping the next version: retake all App Store screenshots
(`app_store/screenshots_raw/`) — the 2026-04 set predates the full
Mije/Miri rebrand (plum field, serif plates, painted Miri, glyph tab
bar, ink-wash covers, hexagram meter). The store listing is currently
selling the old app. Do this LAST, after the remaining pre-release
changes land, so the shots match the shipped build.

## 1. Bump build number and ship to TestFlight

Lots of changes since the last archive: full Korean localization, transcript
banner + lock screen artwork, loop-current-clip, four embedded starter packs,
286 MB size reduction, Featured Packs UI, auto-import on first launch.
Current build is 6 — bump in `LanguageMirror.xcodeproj/project.pbxproj`,
archive, upload. Beta testers are stale.

## 2. #1 Translation toggle in transcript banner

The pipeline already produces native-language transcripts; add a Claude/GPT
translation pass in the bundle pipeline (one extra prompt) and a toggle in
the banner / detail sheet to flip between source and translation. Strongly
desired for the Korean→English audience.
Effort: a few hours (pipeline + small UI).

## 3. #6 3-screen onboarding swipe

Now that auto-import gives new users content immediately, onboarding should
focus on **how to use** the practice loop (tap a clip → loops → swipe to
reset → speed). Three screens with screenshots + short captions.
Effort: 1–2 days.

## 4. Point the daily-reminder tap at the news_latest alias

The pipeline now publishes a stable manifest alias on every run:
`https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/news_latest/bundle.json`
(2026-07-05; see `daily_news_pipeline/NEWS_PUSH_PIPELINE_SPEC.md`, option A —
pipeline acceptance boxes are checked). App follow-up: change
`NewsNotificationService` so the local reminder's tap resolves that alias
instead of constructing the dated URL — makes the reminder robust to
skipped/late pipeline runs. Effort: minutes.
