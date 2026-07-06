---
name: brand-tour
description: Capture screenshots of every reachable app screen (light + dark) via the UI-test walk, assemble labeled contact sheets, and send them for design review. Use when Matthew wants to review the app's look ("run the brand tour", "screenshot everything", "let's review the screens").
---

# Brand Tour — screenshot every screen for review

Captures the app's screens via `EvaluationWalkTests` (each test calls
`shot()` → XCTAttachment), exports the attachments from the xcresult
bundle, builds labeled contact sheets, and sends them with SendUserFile.

## Constants

```
SIM=24D7D410-B299-45AF-9CD3-A80F30096644          # iPhone 17 Pro (check simctl list if missing)
XCTESTRUN=/tmp/xcode_DerivedData/Build/Products/LanguageMirror_LanguageMirror_iphonesimulator26.2-arm64.xctestrun
BUNDLE_ID=sixwandsstudios.LanguageMirror
OUT=<scratchpad>/brand_tour_<date>                # one folder per run
```

## Modes

**Quick** (default, ~2 min per appearance): state-safe tests only —
`testSettingsBasicAdvancedSplit`, `testEnableDailyNewsReminder`,
`testTranslationBannerOnNewsPack`.

**Full** (~6 min per appearance): everything, including state-mutating
tests. ASK FIRST or confirm the user is okay wiping sim app data,
because correct ordering requires a fresh install:

1. `xcrun simctl uninstall $SIM $BUNDLE_ID` (wipes library + sessions!)
2. `testPracticeEmptyState` (needs zero sessions — must run first)
3. `testFirstRunFunnelTour` (completes onboarding, captures onboarding + auto-practice)
4. `testSessionCompletionCelebration` (creates a session; captures the completion sheet)
5. The three quick tests.

## Recipe

1. **Build for testing** (once):
   `cd LanguageMirror && xcodebuild build-for-testing -scheme LanguageMirror -destination "id=$SIM" -quiet`
   Boot the sim if needed (`simctl boot` + `bootstatus -b`).

2. **Per appearance** (`dark`, then `light`):
   - `xcrun simctl ui $SIM appearance <mode>`
   - Run the mode's test list with a result bundle:
     ```
     xcodebuild test-without-building -xctestrun $XCTESTRUN -destination "id=$SIM" \
       -only-testing:LanguageMirrorUITests/EvaluationWalkTests/<test> [...] \
       -resultBundlePath $OUT/<mode>.xcresult
     ```
   - Export the shots:
     ```
     xcrun xcresulttool export attachments --path $OUT/<mode>.xcresult --output-path $OUT/<mode>
     ```
     (Attachments export with hashed names plus a manifest.json mapping
     to the human `shot()` names — rename with:)
     ```
     python3 - <<'EOF'
     import json, os, shutil
     d = "<OUT>/<mode>"
     for t in json.load(open(f"{d}/manifest.json")):
         for a in t["attachments"]:
             human = a["suggestedHumanReadableName"].split("_0_")[0] + ".png"
             shutil.move(f"{d}/{a['exportedFileName']}", f"{d}/{human}")
     EOF
     ```

3. **Launch screen** (not reachable from tests): terminate the app, then
   `(xcrun simctl launch $SIM $BUNDLE_ID &)` and grab 4–6 rapid
   `simctl io screenshot` frames; keep the one showing Miri. If the old
   launch image appears, the SplashBoard cache is stale — delete
   `$(simctl get_app_container $SIM $BUNDLE_ID data)/Library/SplashBoard`.

4. **Contact sheets**: run `make_contact_sheets.py <dir> <out.png>` (in
   this skill folder) per appearance — it grids the PNGs with filename
   labels. Keep sheets ≤ ~12 images each for phone readability.

5. **Send** the contact sheets (and any single frame worth calling out)
   via SendUserFile, with a short list of anything that looks off —
   this is a design review, so lead with observations, not mechanics.

## Notes

- Tests live in `LanguageMirror/LanguageMirrorUITests/EvaluationWalkTests.swift`;
  when a new screen ships, add a `shot("NN-name")` walk for it so the tour
  stays complete.
- After a Full run the sim has fresh state (onboarding done, one session,
  starter packs). Mention that to the user.
- Restore appearance to dark (Matthew's usual) when done.
