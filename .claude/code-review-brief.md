# Language Mirror — Code Review Brief

Every code agent reads this first, then surveys the source through its own lens.
Read/Grep/Glob freely; you may Bash to build, grep, or run the test/verbatim
tools, but **do not mutate source**. Judge the current tree.

## Stack & layout

- **iOS app**: Swift 5, **UIKit** (no SwiftUI, no storyboards except
  `LaunchScreen`), programmatic Auto Layout, iOS 18.5+. Source root:
  `LanguageMirror/LanguageMirror/2025-09-13/`. Xcode 16
  **PBXFileSystemSynchronizedRootGroup** (new files auto-discovered; no pbxproj
  edits). No external Swift packages.
- **Targets**: `LanguageMirror` (app), `LanguageMirrorShare` (share extension),
  `LanguageMirrorTests` / `LanguageMirrorUITests` (UI tests live; unit targets
  largely empty).
- **Architecture**: SceneDelegate → `AppCoordinator` → four child coordinators
  (Library/Import/Practice/Settings), each owning a tab. `AppContainer` struct
  is the DI seam holding protocol services: `SettingsService`,
  `LibraryService` (JSON files in Documents/), `PracticeService` (JSON),
  `AudioPlayerService` (AVFoundation), `ClipService`, `ImportService`. Import
  features add a Factory+Mock pattern (`Services/ImportServiceFeatures/`).
- **Audio** (the core mechanic): `AudioPlayerServiceAVPlayer` loops clips with a
  slow→fast progression (`calculateSpeed()` in `PracticeServiceJSON`, M-N-O ramp)
  or a constant `simpleSpeed`. Loose coupling via `.AudioPlayerDid*`
  notifications.
- **Persistence**: JSON files (NOT CoreData/SwiftData). Audio under
  `Documents/LanguageMirror/library/packs/…`. Practice sessions as JSON.
- **Content model**: `Pack → Track → PracticeSet → Clip`; `TranscriptSpan` with a
  `translations: [String:String]?` map keyed by base lang code (the gloss).
- **Remote content**: Featured catalog is fetched REMOTE-first from CloudFront
  (`d1ni0tk3ua6bwo.cloudfront.net/lmaudio/featured_catalog.json`), embedded copy
  is the offline fallback. Packs install embedded or via remote `bundle.json`.
  Daily news + English starter packs are remote (S3 `turned.rip`).
- **Pipelines** (Python): `daily_news_pipeline/` (news editions; thin orchestrator
  over the `langpack` subsystems studypack/bundler/voicebox/publisher/lexicon at
  `~/workspace/langpack/`) and `sample_bundle_pipeline/` (starter packs). Secrets
  in `.env` (gitignored): ANTHROPIC / ELEVENLABS / GEMINI / AWS.

## Build & test

```
cd LanguageMirror && xcodebuild -scheme LanguageMirror \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build
```

UI tests: `xcodebuild build-for-testing …` then `test-without-building` against
the `.xctestrun`. Sim UDID for this repo: `24D7D410-B299-45AF-9CD3-A80F30096644`.
The `/brand-tour` skill drives `EvaluationWalkTests`. To avoid a shared-DerivedData
build-db lock, build into a private `-derivedDataPath`.

## Known context (don't re-litigate unless newly relevant)

- Swift-6 main-actor conformance **warnings** on the coordinator delegate
  conformances (documented, not yet migrated).
- `MiriView.swift` (code-drawn mascot) is no longer displayed — painted assets
  replaced it; the `Expression` enum is still the API surface.
- Some `traitCollectionDidChange` uses migrated to `registerForTraitChanges`;
  others may remain.
- `-forceEmbeddedCatalog` launch arg = test hook to use the embedded catalog.

## Output format (every agent)

- **Verdict** — one line.
- **Strengths** — what's genuinely well-built (cite `file:line`).
- **Findings** — **[Blocker | Major | Minor]**, each with `file:line` and a
  concrete fix. Blocker = crash / data-loss / security / ship-stopper.
- **The one thing** — the single highest-leverage change.
- **Score /10** — your lens's grade, one-line why.

Be specific with `file:line`. No vibes; show the code.
