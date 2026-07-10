# Ship Checklist — human dogfood pass

A personal walkthrough to do on a **real device** (TestFlight or a dev build)
before archiving. Focused on what machines can't judge — voice quality, Korean
naturalness, real-device feel, on-device notifications. ~30–45 min.

Legend:  ☐ do it   👁 your eyes/ears (subjective — no test covers this)
🚪 ship-gate ordering (getting this wrong breaks live users)
✅ already guarded by an automated test (listed for confidence, spot-check only)

---

## 0. Before you start

- ☐ Decide the surface: **real device** for anything marked 👁 (voice, OLED
  plum, launch screen, notifications). The simulator lies about all of these.
- ✅ **The English packs are already LIVE and version-safe.** They're published
  as **remote** bundles (audio on CloudFront) and referenced remotely in the
  live `featured_catalog.json`. Any app version — including all current
  users — can download and install them, so there is NO dangerous
  publish-ordering gate here (the old "ship then publish" concern only applied
  to *embedded* packs, which these no longer are). Current users see the five
  English packs now, without updating.
- ☐ Because they're live, dogfood them on the **current** app too: open Add →
  Featured Packs and confirm the five English packs appear and install by
  download. (A dev build needs no special launch arg now that the catalog is
  published.)

## 1. First run (needs a FRESH install)

Delete the app first (or `xcrun simctl uninstall`) so onboarding shows.
- ✅/👁 Onboarding page 1: Miri + wordmark + tagline + **Continue** — confirm
  there is **no "which language are you learning?" question** (removed).
- ☐ Continue → "How it works" (3 steps) → the CTA drops you straight into an
  auto-started, auto-playing practice session.
- 👁 Does the first-run flow feel welcoming and un-intimidating? Slow audio on
  day one is intentional.

## 2. The five core surfaces (dark AND light — toggle Control Center)

- 👁 **Library** — gallery-wall ink-wash covers, crimson/aqua ribbon bookmarks
  on pack headers, gold serif section captions. Scroll: does the plum field +
  grain read as "hand-tinted paper," not flat gray?
- 👁 **Track detail** — gold-plate header card, serif title, engraved
  Practice Sets / Transcripts captions.
- 👁 **Practice** — start a set: the **hexagram loop meter** fills gold as
  loops complete; the active sentence glows aqua; speed strip; tap a sentence
  → transcript banner shows the line over its **dimmed translation**.
- 👁 **Add** — bookplate stamp icons on parchment medallions (Featured is the
  gold coin); both **"Today's News"** rows; scroll to Advanced.
- 👁 **Settings** — bell/mirror/compass medallions, **aqua** slider tracks
  (no stray green/purple/orange), reminders toggle + time picker, Advanced
  disclosure.

## 3. English content — the Korean-learner direction (NEW)

Requires `-forceEmbeddedCatalog` (§0) or a post-publish build.
- ☐ Featured Packs → Starter Packs: five **English** packs lead the list
  (Greetings, Directions, Cafe, A Rainy Sunday Morning, Hope is the Thing
  with Feathers), Korean packs follow. ✅ (`testInstallEnglishPack`)
- 👁 **Install and play each of the five.** For each: English audio + the
  **Korean gloss** appears under the line during practice.
- 👁 **VOICE QUALITY (your ears — nothing automated covers this):** listen to
  each pack end to end. Do the ElevenLabs voices sound natural and native?
  Any mispronunciations, weird prosody, robotic moments? Flag any pack to
  re-synthesize. `afplay sample_bundle_pipeline/samples/starter_english_*/audio/track_001.mp3`
- 👁 **KOREAN GLOSS NATURALNESS (native judgment):** read each line's Korean
  translation. Register-matched to the English? Natural, not stiff/MT-ish?
  The poem's Korean especially — is it gently poetic and faithful?
- 👁 The poem is **Emily Dickinson, "Hope is the Thing with Feathers"**
  (public domain) — confirm it reads as intended, not the old Hughes one.

## 4. Dual news + locale

- 👁 With device language **English**: Add → "Daily Korean News" row is first.
- 👁 Switch device to **Korean** (Settings → General → Language): the app UI
  turns Korean, and **"매일 영어 뉴스" (Daily English News)** now leads the
  news rows. ✅ (`testNewsRowsFollowKoreanLocale`)
- ☐ Tap a news row: it attempts to import from the alias. Korean news should
  import & play. English news (`news_en_latest`) — if the pipeline's English
  edition is publishing, it imports; if not yet, it should **fail gracefully**
  (no crash, a clean error), because the app ships ahead of that alias.

## 5. Notifications — ON-DEVICE ONLY (the simulator can't do this reliably)

- 👁 Settings → enable the daily reminder; grant permission.
- 👁 Set the time a minute out (or trigger it), lock the phone, wait: the
  banner arrives. **Tap it** → the app opens and imports today's news for
  your locale's edition. This tap path is the one thing no test covers —
  verify it by hand.

## 6. Celebration + streak

- ☐ Finish a short set (the poem, ~23s, or set repeats to 1 in Settings):
  the **completion sheet** shows painted celebrating Miri, stats, and (if
  you've practiced 2+ days) a streak line. ✅ (`testSessionCompletionCelebration`)
- 👁 Painted Miri renders crisply (no halo/box around her).

## 7. Real-device-only appearance checks

- 👁 **Launch screen** on device: painted Miri floats on plum with **no seam
  rectangle** around her (the sim needed a cache dance; device should be clean).
- 👁 **OLED plum** — does the dark plum field look rich, not muddy or crushed?
- 👁 **Dynamic Type** — bump text size (Settings → Accessibility): do practice
  sentences and captions stay readable / not clipped?
- 👁 **VoiceOver** on the Practice hexagram meter — it should announce the loop
  count (e.g. "Loop 3 of 8"), since the visual meter has no text.

## 8. Content / copyright QA (already done — confirm)

- ✅ Verbatim-overlap checker run on the starter packs: four conversation/story
  packs are original (clean vs their prompts); the poem is a faithful
  reproduction of a **public-domain** work. (`daily_news_pipeline/check_verbatim_overlap.py`)
- 🚪 The recurring **news** edition is where ongoing copyright risk lives — the
  pipeline must gate every English news bundle through the verbatim checker
  (ENGLISH_NEWS_EDITION_SPEC.md acceptance #4). Confirm the pipeline session
  wired that in before English news goes out.

## 9. Ship gate (ORDER MATTERS)

1. ☐ Remove `-forceEmbeddedCatalog` from the Run scheme.
2. ☐ Bump build number (`project.pbxproj`).
3. ☐ Archive → TestFlight → this personal pass on the TestFlight build.
4. 🚪 Refresh **App Store screenshots** — the current store set predates the
   whole rebrand (NEXT.md release gate).
5. ☐ Submit; get the build **live**.
6. ✅ Catalog already published — English packs are remote and live for all
   versions, so no post-ship catalog step is needed. (To add/change catalog
   packs later: publish any new bundles to `s3://turned.rip/lmaudio/<id>/`
   first, then `./sample_bundle_pipeline/publish_catalog.sh` + invalidate
   `/lmaudio/featured_catalog.json`. Keep new packs `remote` for the same
   version-safety.)
7. 🚪 Confirm the pipeline is publishing `news_en_latest` (the English news
   edition) so the English news row has content.
