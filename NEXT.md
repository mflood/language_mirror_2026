# Language Mirror — Next Up

The 3 things to do next, in priority order. See `PRODUCT_IDEAS.md` for the
broader backlog and `LOG.md` for what's already shipped.

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
