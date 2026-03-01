# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (from repo root)
cd LanguageMirror && xcodebuild -scheme LanguageMirror -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build quietly (errors only)
cd LanguageMirror && xcodebuild -scheme LanguageMirror -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet build

# Run tests (test targets exist but are currently empty)
cd LanguageMirror && xcodebuild test -scheme LanguageMirror -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

No linting, no CI/CD, no external package dependencies.

## Project Layout

The iOS app source lives at `LanguageMirror/LanguageMirror/2025-09-13/`. The project uses Xcode 16+ **PBXFileSystemSynchronizedRootGroup** — new Swift files added to the source directory are automatically discovered by the build system. No pbxproj edits needed.

There is also a Python bundle pipeline at `bundle_pipeline/scripts/` for generating content packs from S3 audio sources (init → download → transcribe → assemble → publish). See `readme.md` for pipeline usage.

**Key targets**: LanguageMirror (app), LanguageMirrorShare (share extension), LanguageMirrorTests, LanguageMirrorUITests.

**Deployment**: iOS 18.5+, Swift 5.0, UIKit (no SwiftUI, no storyboards).

## Architecture

### Coordinator Pattern + Tab Bar

`SceneDelegate` creates `AppCoordinator` which manages four child coordinators, each owning a tab:

| Tab | Coordinator | Root VC | Purpose |
|-----|------------|---------|---------|
| Library | LibraryCoordinator | LibraryViewController | Browse packs/tracks, search, navigate to TrackDetail → Practice |
| Import | ImportCoordinator | ImportViewController | Import from video, files, recording, URL, bundle manifest, embedded packs |
| Practice | PracticeCoordinator | PracticeHomeViewController | Recent sessions + favorites → PracticeViewController |
| Settings | SettingsCoordinator | SettingsViewController | Speed, repeats, gaps, progression mode |

Cross-tab navigation is handled by `AppCoordinator` methods (`switchToLibraryWithTrack`, `navigateToPracticeFromHome`, `switchToImportTab`).

### Dependency Injection

`AppContainer` (struct) holds all service instances and is passed through coordinators:
- `SettingsService` → `SettingsServiceUserDefaults` (UserDefaults)
- `LibraryService` → `LibraryServiceJSON` (JSON files in Documents/)
- `PracticeService` → `PracticeServiceJSON` (JSON files in Documents/practice_sessions/)
- `AudioPlayerService` → `AudioPlayerServiceAVPlayer` (AVFoundation)
- `ClipService` → `ClipServiceJSON`
- `ImportService` → `ImportServiceLite`

All services are protocol-based. Import features use an additional Factory + Mock pattern for testability (see `Services/ImportServiceFeatures/`).

### Data Flow

**Models.swift** defines the core domain: `Pack` → `Track` → `PracticeSet` → `Clip`. A `PracticeSession` tracks per-clip play counts and current position. `TranscriptSpan` provides timed text alignment.

**Persistence** is JSON file-based (not CoreData). Audio files are stored under `Documents/LanguageMirror/library/packs/<packId>/tracks/<trackId>/`.

**Notifications** drive loose coupling: `.libraryDidAddTrack`, `.LibraryDidChange`, `.AudioPlayerDidStart/Stop/ClipDidChange/LoopDidComplete/SpeedDidChange/DidUpdateTime`.

### Audio Playback

`AudioPlayerServiceAVPlayer` handles clip-based looping with two modes:
- **Simple mode**: All repeats play at `simpleSpeed` (user-configurable via speed preset buttons)
- **Progression mode**: M-N-O ramp algorithm (M repeats at minSpeed → N ramp steps → O repeats at maxSpeed)

`calculateSpeed()` in `PracticeServiceJSON` computes the rate per loop iteration. Speed presets are defined in `SettingsService.speedPresets`.

### Share Extension

`LanguageMirrorShare` receives shared audio files → saves to app group container via `SharedImportManager` → `AppCoordinator` processes pending imports on next launch.

## Style Conventions

- Programmatic Auto Layout everywhere (no xibs/storyboards)
- `AppColors` enum for ADHD-friendly theming with dark mode support (use `AppColors.calmBackground`, `AppColors.primaryAccent`, `AppColors.durationShort/Medium/Long` for phase colors)
- `applyAdaptiveShadow()` UIView extension for appearance-aware shadows
- Views use `translatesAutoresizingMaskIntoConstraints = false` pattern
- Delegate protocols for view controller communication
- Haptic feedback via `UISelectionFeedbackGenerator` / `UIImpactFeedbackGenerator` on control changes
