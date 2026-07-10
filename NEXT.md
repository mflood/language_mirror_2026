# Language Mirror — Next Up

The 3 things to do next, in priority order. See `PRODUCT_IDEAS.md` for the
broader backlog and `LOG.md` for what's already shipped.

## ⏳ Release gate: publish the remote featured_catalog.json AFTER the build ships

The English starter pack ("Everyday English Greetings") is EMBEDDED
(audio in the app) and registered in the *embedded* catalog copy. The
app loads the catalog REMOTE-first (CloudFront), embedded is only the
offline fallback. Do NOT publish the updated catalog to
`s3://turned.rip/lmaudio/featured_catalog.json` until the app version
containing the embedded English bundle is live on the App Store —
otherwise current users see the pack, tap it, and the install fails
(their installed build has no such embedded bundle). Sequence:
ship the app build → THEN publish the remote catalog.

English content status: pack 1 of 5 done (greetings). Remaining mirror
packs to build via the same path (sample_bundle_pipeline step 1 →
elevenlabs synth → assemble_conversation_bundle.py → 4_embed_in_app →
catalog): directions, cafe, short story, poem. Plus the English news
edition (pipeline).

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
