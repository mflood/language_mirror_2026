# Daily-News Push Notification — Pipeline / Backend Spec

**Audience:** the Claude session refactoring `daily_news_pipeline`.
**Status:** the iOS app already ships the *receiving* half of this feature.
This document captures what the pipeline / a small backend needs to add to
complete it. **No app changes are required for the recommended MVP (option A).**

## Context: what the iOS app already does

- Ships a **local daily reminder** (no backend needed): the app schedules a
  repeating on-device notification at a user-chosen time (default 08:00) and,
  on tap, constructs the day's news-pack URL and imports it, dropping the user
  into practice — which feeds their streak.
- The URL it constructs follows the **existing publish pattern**:
  `https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/news_YYYY_MM_DD/bundle.json`
  where the date is **US/Eastern** (matching `today_eastern()` in the pipeline).
- The app also **handles remote (APNs) pushes** already: a push whose payload
  carries `type: "dailyNews"` and `bundleUrl: "<...>"` is routed to the same
  import-and-practice flow. So the pipeline/backend only needs to *send* it.

The relevant app files (for reference, do not edit from the pipeline session):
`Services/NewsNotificationService.swift`, `App/AppDelegate.swift`
(`UNUserNotificationCenterDelegate`), `Coordinators/AppCoordinator.swift`
(`handleOpenNewsBundle` / `importBundle`).

## The problem the pipeline can fix

The **local** reminder fires at a fixed time regardless of whether the day's
pack actually published. If a run is skipped or late, the constructed dated URL
404s and the import fails. Two levels of fix, pick based on appetite:

---

### Option A — `news_latest` alias (recommended, small, no backend)

After a successful publish, **also** copy the day's `bundle.json` to a stable
alias key so "today's pack" always resolves even if the app's clock/date math
disagrees or a run slips:

```
s3://turned.rip/lmaudio/news_latest/bundle.json   ← copy of the freshest bundle.json
```

- One extra `aws s3 cp` at the end of `5_publish_s3.py` (or the refactor's
  equivalent publish step), plus a CloudFront invalidation of
  `/lmaudio/news_latest/bundle.json`.
- **Audio URLs inside that bundle keep pointing at the real dated folder**
  (e.g. `.../lmaudio/news_2026_07_02/story_1.mp3`) — only `bundle.json` is
  aliased, so no audio is duplicated. The bundle's `id`/pack `id` should remain
  the real dated id (e.g. `news_2026_07_02`) so the app dedups/updates cleanly
  rather than creating a "latest" pack that changes contents underneath it.
- **App follow-up: DONE.** The local reminder's tap now opens
  `news_latest/bundle.json` (`NewsNotificationService.latestNewsBundleURL`).

This alone makes the shipped local-notification feature robust. **Do this one.**

---

### Option B — real remote push (APNs), only fire when content exists

Truly correct delivery: the user is notified **only after** the pack is live,
with the real headline as the body. Requires infrastructure the pipeline session
should scope with Matthew before building:

**1. Device-token registration endpoint (new backend).**
   The app captures the APNs device token (`NewsNotificationService.storeDeviceToken`,
   currently logged with a `TODO` to POST it). It needs somewhere to POST to —
   e.g. `POST https://<api>/devices { "token": "<hex>", "platform": "ios" }` —
   storing tokens in a table. *App change required:* wire that POST + call
   `registerForRemoteNotifications()` and add the `aps-environment` entitlement
   + push capability. Track as an app task; don't assume it's done.

**2. Send step after publish.**
   After a successful publish (end of the pipeline, gated on real content),
   send an APNs push to all registered tokens. Payload the app expects:

   ```json
   {
     "aps": {
       "alert": {
         "title": "오늘의 뉴스 · Today's News",
         "body": "<pack title or top headline, e.g. '문어와 거울 외 4개 이야기'>"
       },
       "sound": "default"
     },
     "type": "dailyNews",
     "bundleUrl": "https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/news_YYYY_MM_DD/bundle.json"
   }
   ```

   - `type` **must** be exactly `"dailyNews"` and `bundleUrl` the published
     bundle URL — that's the contract the app's tap handler keys on.
   - Send via APNs HTTP/2 (`api.push.apple.com`) with a `.p8` auth key
     (team id + key id + bundle id `sixwandsstudios.LanguageMirror`), or a
     provider like OneSignal.
   - Timing: fire **only after** the publish + CloudFront invalidation succeed,
     so tapping never 404s. Respect the user's local morning — the app's local
     reminder defaults to 08:00; a remote push should target a similar local
     window (store per-device timezone, or send in batches by region).

**Cost/complexity note:** Option B needs a persistent backend (token store +
APNs sender) and app-side entitlement/registration work. Option A is ~5 lines
in the publish step and makes the already-shipped local feature reliable. Start
with A; do B only if Matthew wants server-driven, content-aware pushes.

## Acceptance for the pipeline side (Option A)

- [x] After publish, `lmaudio/news_latest/bundle.json` exists and equals the
      freshest day's `bundle.json` (dated `id`, dated audio URLs preserved).
- [x] CloudFront path `/lmaudio/news_latest/bundle.json` invalidated each run.
- [x] `curl https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/news_latest/bundle.json`
      returns the current day's manifest.
