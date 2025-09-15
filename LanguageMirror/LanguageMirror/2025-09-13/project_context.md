LanguageMirror — Comprehensive Project Context

Last updated: 2025-09-14

Directive: This document is the single source of truth for LanguageMirror’s scope, terminology, architecture, and decisions. Update it whenever we rename terms, add/remove screens, change data models, or make notable decisions. After any change, append to the Decision Log and, when code changes are proposed, include a patch snippet.

0) Vision & Guardrails

LanguageMirror helps learners mirror native speech by slicing dialogue audio into small, labeled segments, then looping practice segments N times while skipping noise/non-practice parts.

Non-negotiables

UIKit only, no storyboard, no SwiftUI. All views programmatic.

High cohesion, low coupling via Coordinators + Service protocols.

JSON-first storage with a clean migration path to Core Data.

Precise playback loops (no drift), ergonomic editing, fast imports.

Supported iOS: iOS 15+
Swift: 5.9+ (Xcode 15/16 era)

1) Terminology (short, teachable)

Pack: Importable collection (e.g., from S3) containing tracks + optional segment maps.

Track: A single audio file in your library.

Segment: A time-bounded slice of a Track with metadata.

SegmentKind:

Drill (practice segment): played N times, then advance.

Skip: ignored during practice.

Noise: ignored and visually de-emphasized (hidden by default).

Map: The set of Segments for a Track.

Routine: An ordered list of Drills (e.g., “all Drills in this Track” or cross-track set).

Session: A saved run with settings + stats (optional, later).

Alt names for Drill if ever rebranded: Loop, Line, Echo. Default: Drill.

2) Information Architecture (tabs; modular)

Root: UITabBarController (programmatic)

Library

Library list (search/filter/sort; group by Pack/Language/Source)

Track Detail → Segment Editor (waveform + segment list)

Quick start: “Play all Drills”

Import

Sources: Files / Share Sheet, Record, From Video, From URL, Get Pack (S3)

Import queue + status; unified pipeline writes to Library

Practice

Pick a Routine (default: last edited Track, Drills only)

Drill Player: transport, N repeats, gap, beep, transcript view

Settings

Defaults (N, gap, pre-roll), transcript options, output route, auto-advance

ASR provider (off / on-device / server), language defaults, S3 token, storage mgmt

Design principles

Screens talk to Coordinators (navigation) + Services (use cases).

Views depend on protocols—not storage. Swapping JSON ↔ Core Data shouldn’t touch VCs.

Player logic isolated behind PlayerEngine.

3) Architecture & Project Layout
LanguageMirror/
  AppDelegate.swift
  SceneDelegate.swift
  AppCoordinator.swift
  Coordinator.swift
  AppContainer.swift              // dependency container
  Services/
    LibraryService.swift
    LibraryServiceJSON.swift
    // TranscriptionService.swift (stub later)
    // ImportService.swift (stub later)
    // PlayerEngine.swift (stub later)
  Models/
    Models.swift
  Coordinators/
    LibraryCoordinator.swift
    ImportCoordinator.swift
    PracticeCoordinator.swift
    SettingsCoordinator.swift
  Screens/
    LibraryViewController.swift
    TrackDetailViewController.swift
    ImportViewController.swift
    PracticeViewController.swift
    SettingsViewController.swift
  Resources/
    library_seed.json
    sample.mp3


Coordinators retained strongly by AppCoordinator (or in [Coordinator]) to avoid weak-delegate nils.

4) Data Model (JSON-first; Core Data-ready)
Swift (Codable)
struct Pack: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var languageHint: String?
    var tracks: [Track]         // lightweight is fine for now
}

struct Track: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var filename: String        // e.g., "sample.mp3"
    var durationMs: Int?        // optional for now
    var languageCode: String?   // e.g., "ko-KR" | "en-US"
}

struct SegmentMap: Codable, Equatable {
    var version: Int
    var segments: [Segment]
}

enum SegmentKind: String, Codable { case drill, skip, noise }

struct Segment: Codable, Identifiable, Equatable {
    let id: String
    var startMs: Int
    var endMs: Int
    var kind: SegmentKind
    var title: String?
    var repeats: Int?               // nil = use global N
    var languageCode: String?
    var transcript: [TranscriptSpan]?
}

struct TranscriptSpan: Codable, Equatable {
    var startMs: Int
    var endMs: Int
    var text: String
    var speaker: String?
}

File Layout (Documents/LanguageMirror/)
LanguageMirror/
  library/
    packs/<packId>/manifest.json
    tracks/<trackId>/
      audio.m4a | .mp3
      track.json           # Track + optional SegmentMap
      transcript.json      # optional
  routines/
    <routineId>.json
  imports/queue.json

Seed example (Resources/library_seed.json)
{
  "packs": [
    {
      "id": "demo-pack",
      "title": "Demo Pack",
      "languageHint": "en-US",
      "tracks": [
        { "id": "t1", "title": "Greetings 01", "filename": "sample.mp3", "durationMs": 30000, "languageCode": "en-US" },
        { "id": "t2", "title": "Greetings 02", "filename": "sample.mp3", "durationMs": 42000, "languageCode": "en-US" },
        { "id": "t3", "title": "Dialog A",    "filename": "sample.mp3", "durationMs": 51000, "languageCode": "en-US" }
      ]
    }
  ]
}

5) Services (protocol-first)
protocol LibraryService {
    func listPacks() -> [Pack]
    func listTracks(in packId: String?) -> [Track]
    func loadTrack(id: String) throws -> Track
    func saveTrack(_ track: Track) throws
}


JSON impl notes

Persist to Documents/LanguageMirror/library.json.

On first run, copy Resources/library_seed.json.

Future: move to Core Data by replacing the impl; keep protocol signature.

ImportService (planned)

Import sources: Files / Share Sheet / Video / URL / Pack (S3 via presigned URLs).

Unified pipeline writes audio and stub track.json.

TranscriptionService (planned)

Start with SFSpeechRecognizer for short segments.

Allow per-segment languageCode. Keep protocol to swap server ASR.

PlayerEngine (planned)

Prefer AVAudioEngine/AVAudioPlayerNode with scheduleSegment by frames.

Optional pre-roll and gap (silence buffer). Snap to zero-crossings.

6) Current UI (starter)

Library: Table of tracks (from JSON), pushes Track Detail.

Track Detail: “Overview” (file/duration/language), “Actions” (Start Routine, Edit Segments) → placeholders.

Import / Practice / Settings: stub screens.

7) UX specifics for upcoming work
Segment Editor (Track Detail)

Waveform with zoom; draggable handles; snap to zero-crossing.

Segment list: timecode • title • kind • repeats • language.

Quick actions: tap kind pill (Drill ↔ Skip ↔ Noise), long-press menu: rename, set repeats, set language, split/merge, delete.

Toggle “Show Noise” (default off).

Drill Player

Big play/prev/next; global N with per-segment override badge.

Optional gap (0.3–1.5s), optional beep, optional pre-roll (100–300ms).

Transcript panel (collapsible); queue sidebar (tap to jump).

8) Coding Standards & Conventions

No storyboards. Use UINavigationController, Auto Layout with anchors, translatesAutoresizingMaskIntoConstraints = false.

Use final classes for VCs unless subclassed; prefer struct for models.

Keep view state in the VC; business logic in Services.

Dependency injection via initializers; avoid singletons in Services.

weak delegates; Coordinators retained by parent coordinator/app.

Prefer small pure helpers; isolate AVFoundation details in PlayerEngine.

Naming: simple, explicit. Avoid abbreviations outside common iOS names.

9) LLM Collaboration Protocol

To keep changes precise and mergeable, always respond with patch-style snippets:

Add/Replace a file

// path: Services/LibraryServiceJSON.swift
```swift
// ... code ...


Edit a file: include only the sections that change with enough context.

Multiple files: repeat the // path: header for each.

No pseudo-code; code should compile (or clearly note // TODO with stubs).

Also include:

Short rationale (1–3 bullets) why this design fits our guardrails.

Acceptance checks (“Build & Run → tap X → expect Y”).

If you alter models or file layouts, append a patch to this doc (section 18 Decision Log).

10) Milestones & Backlog (bite-sized, each with AC)

M1: Library foundations (DONE / in progress)

✅ Tab scaffold + Coordinators retained by AppCoordinator

✅ JSON LibraryService (seed load, list tracks)

✅ Track Detail scaffold with Overview + Actions

M2: Track Detail & Player stub

B2.1: Replace “Start Routine” alert with player stub that plays filename once
AC: Tap “Start Routine” → audio plays; handle missing file gracefully (alert).

B2.2: Add “Play N repeats (global N=3)” with simple loop using AVPlayer (temporary)
AC: Track plays 3 times with ~0.5s gap; stop/pause work.

M3: Segment Editor (list-first)

B3.1: Segments section (empty state + “Add Segment” sheet with start/end in ms)
AC: New segment appears in list; persisted to JSON inside track.json.

B3.2: Edit Segment: title, kind, repeats, language
AC: Edits persist; list updates without reload app.

M4: Waveform

B4.1: WaveformPreviewView placeholder (static image or simple render)
AC: Visible, resizes, scrolls.

B4.2: Draggable handles to set start/end; snap to zero-crossing helper
AC: Dragging updates ms; snapping togglable.

M5: Import basics

B5.1: Files picker → copy audio → append Track to library; set filename; duration via AVAsset
AC: After import, new track visible in Library and playable in stub.

M6: Transcription (opt-in)

B6.1: Button: “Transcribe visible Drills” → call TranscriptionService (local)
AC: Transcript spans appear under segment.

M7: Packs from S3 (presigned)

B7.1: Download .zip pack; unzip; write to library/packs/<packId>/
AC: New Pack with tracks shows in Library.

M8: Core Data migration

Mirror JSON entities; one-time importer; swap service impls.

11) Acceptance Checks (smoke tests)

Launch → 4 tabs visible with large titles.

Library shows tracks from seed JSON (or persisted library).

Pushing a track shows Overview + Actions.

No storyboard references or nib loading in logs.

Rotations don’t break layout.

12) Accessibility & i18n

Support Dynamic Type; VoiceOver labels on transport and segment cells.

Use BCP-47 codes (languageCode) for tracks/segments.

Don’t rely on color alone to communicate kind (add icons/text).

13) Performance Notes

Lazy generate waveform previews; consider caching by zoom.

Don’t block main thread during import/transcode/waveform render.

Consider down-mixed mono rendering for waveform speed.

14) Privacy & Security

Avoid embedding long-lived AWS credentials; fetch presigned URLs via API.

Provide local-only transcription mode; user-controlled deletion.

Respect microphone/background download permissions.

15) Debugging Tips

If delegate seems nil, ensure child coordinators are retained (array or properties).

Add deinit { print("LibraryCoordinator deinit") } while debugging lifetimes.

For audio clicks at boundaries, check zero-crossing and add tiny pre-roll.

16) Style Guide (Swift)

final where possible; private/fileprivate for encapsulation.

Group VC code by // MARK: sections (Lifecycle, Layout, Actions, DataSource, Delegate).

Use small helpers (msToClock(_), formatTimecode(_)) and unit-test them.

Keep VCs lean; push logic to Services.

17) Open Questions

Waveform approach: roll our own vs. a lightweight OSS lib (license/perf)?

Default N, gap, beep (reasonable defaults: N=3, gap=0.5s, beep=off)?

Transcript default model: per Segment vs. per Track (+timecodes). (We can support both; pick a UI default.)

Server ASR vendor/pricing (later; protocol allows swapping).

18) Decision Log (append newest at top)

- 2025-09-15 — Waveform editor polish: added Selection Level Meter (RMS/Peak via AVAssetReader) and directional zero-crossing nudges (◀︎0 / 0▶︎ for Start/End). Extended ZeroCrossingSource with next/previous APIs; Synthetic and AVAsset-backed implementations updated. Debounced background analysis keeps UI fluid.


- 2025-09-15 — Waveform editor: added “Loop until Stop” toggle (∞). Play Selection now supports 1×, N× (from Settings), or ∞ looping with Settings.gapSeconds and Settings.prerollMs.


- 2025-09-15 — Waveform editor gained a tiny loop audition toggle (1× vs N× from Settings). Play Selection now repeats according to the toggle, using Settings.gapSeconds for inter-repeat gap and Settings.prerollMs for preroll.


- 2025-09-15 — Segment Waveform Editor gained “Play Selection”. Uses AudioPlayerService segments API to audition the current range as a one-shot with preroll from Settings. UI shows Pause/Resume and Stop while playing. Wired audioPlayer + settings down through SegmentEditor → Waveform Editor.

- 2025-09-15 — Added zoomable/pannable waveform to Segment Waveform Editor with a slider (1×–10×). Implemented snap-to-zero-crossing (toggleable) via a pluggable ZeroCrossingSource. Current source uses the synthetic waveform; ready to swap for true audio-based zero-crossing later.


- 2025-09-15 — Added WaveformPlaceholderView with draggable start/end handles and time ruler. Introduced SegmentWaveformEditorViewController for visual editing of a single segment (create or edit). Segment Editor now pushes the waveform editor for add/edit. Duration derived from Track.durationMs or AVAsset if needed.

- 2025-09-15 — Practice tab now exposes quick controls for N, gap, inter-segment gap, and preroll, bound to SettingsService (UserDefaults). Added track picker and immediate “Play Drills” action using AudioPlayerService segments API. Practice remembers last selected track.

- 2025-09-15 — Start Routine now plays only Drill segments in order. AudioPlayerService gained a segments API honoring per-segment repeats with a gap between repeats and between segments. Implemented via AVPlayer with a periodic time observer; whole-track play preserved for legacy/testing.
- 2025-09-15 — Wired N repeats + gap using AVPlayer. Extended AudioPlayerService with play(track:repeats:gapSeconds:), pause(), resume(), stop(). Track Detail exposes Pause/Resume and Stop controls and listens for start/stop notifications to update UI.
- 2025-09-15 — Added dedicated Segment Editor screen. Editor supports list, add/edit/delete, reorder, and quick kind cycle. Introduced SegmentService.update/moveSegment to persist edits and ordering. Track Detail now pushes the editor and refreshes its Segments section on return via callback.
- 2025-09-15 — Added Segments section scaffold to Track Detail. Introduced Segment/SegmentKind/SegmentMap models and JSON-backed SegmentService that reads/writes Documents/LanguageMirror/library/tracks/<trackId>/track.json. Supports empty state, add dialog (start/end/title/kind), and swipe-to-delete.

- 2025-09-14 — Starter app (UIKit, no storyboard) with TabBar + coordinators retained strongly to keep delegates alive. JSON-first LibraryService loads library_seed.json or persists to Documents/LanguageMirror/library.json. Chose Drill/Skip/Noise for SegmentKind. Track has optional languageCode.

- 2025-09-13 — Initial architecture/IA defined; AVAudioEngine chosen for precise loops; Coordinators + Services to ensure low coupling.


19) Quick “Patch Template” for LLM replies

When proposing changes, use this format:

Summary (1–3 bullets)

What changed and why (tie to guardrails).

Patches

// path: Screens/TrackDetailViewController.swift
```swift
// <code here>

// path: Services/PlayerEngine.swift
```swift
// <code here>


