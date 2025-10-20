# Library Practice Navigation Refactoring

## Overview
This document describes the refactoring of practice session navigation to provide a more intuitive user experience with contextual navigation between Library and Practice views.

## Problem Statement

### Previous Behavior
When a user navigated through the Library to start a practice session:
```
Library Tab → Track Details → [Tap Practice Set] → Switches to Practice Tab
```

Issues with this approach:
- User lost navigation context when switching tabs
- No "back" button to return to Track Details
- Disconnected user flow between related screens

## New Behavior

### Contextual Navigation Flow
```
Library Tab → Track Details → Practice Session (pushed on Library stack) → Back to Track Details
```

### Shared State
- Practice Tab shows the same session regardless of how it was started
- Starting practice from Library updates Practice Tab's state
- Tapping Practice Tab shows the current active session

## Implementation

### 1. LibraryCoordinator.swift

**Change:** Push PracticeViewController onto Library navigation stack

```swift
extension LibraryCoordinator: TrackDetailViewControllerDelegate {
    func trackDetailViewController(_ vc: TrackDetailViewController, 
                                   didSelectPracticeSet practiceSet: PracticeSet, 
                                   forTrack track: Track) {
        // Push practice view onto Library nav stack for contextual navigation
        let practiceVC = PracticeViewController(
            settings: container.settings,
            libraryService: container.libraryService,
            clipService: container.clipService,
            audioPlayer: container.audioPlayer,
            practiceService: container.practiceService
        )
        practiceVC.loadTrackAndPracticeSet(track: track, practiceSet: practiceSet)
        navigationController.pushViewController(practiceVC, animated: true)
        
        // Sync Practice tab state so it shows the same session
        appCoordinator?.practiceSessionStartedFromLibrary(track: track, practiceSet: practiceSet)
    }
}
```

**Before:** Called `appCoordinator?.switchToPracticeWithSet()` which switched tabs
**After:** Pushes PracticeViewController onto the Library navigation stack and syncs state

### 2. AppCoordinator.swift

**Added:** New method to sync Practice Tab state without switching tabs

```swift
func practiceSessionStartedFromLibrary(track: Track, practiceSet: PracticeSet) {
    // Update Practice tab's view to show this session without switching tabs
    // This keeps both views in sync when practice is started from Library flow
    practiceCoordinator?.loadPracticeSet(track: track, practiceSet: practiceSet)
}
```

This ensures that:
- Practice Tab reflects the current active session
- State is shared between Library-initiated and Practice Tab views
- Users see consistent state regardless of which tab they're on

### 3. PracticeViewController.swift

**No changes needed** - The existing `viewWillDisappear` implementation already handles this correctly:

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Stop playback when navigating away from Practice screen
    // This prevents edge cases where audio continues playing for a different track
    if isMovingFromParent || isBeingDismissed {
        stopCurrentPlayback()
    }
}
```

Key behavior:
- `isMovingFromParent` is `true` when popping back in navigation → stops audio
- `isMovingFromParent` is `false` when app backgrounds → audio continues

## User Experience Flows

### Scenario 1: Library → Practice → Back
1. User is on Library tab browsing tracks
2. Taps a track → sees Track Details screen
3. Taps a practice set → PracticeViewController is pushed onto Library stack
4. User sees practice session with back button
5. Taps back → returns to Track Details, audio stops
6. Natural navigation flow preserved

### Scenario 2: Shared State Between Tabs
1. User starts practice from Library (Scenario 1)
2. User switches to Practice Tab
3. Practice Tab shows the same track and practice set
4. State is shared - both views reflect the current session

### Scenario 3: Direct Practice Tab Access
1. User taps Practice Tab directly
2. Sees the last active practice session (or empty state if none)
3. Can select track/practice set and start practicing
4. If user then navigates to Library, they stay on Practice Tab
5. Practice Tab remains the "home" for practice sessions

### Scenario 4: Background/Lock Screen Behavior
1. User starts practice from either Library or Practice Tab
2. Locks phone or switches to another app
3. Audio continues playing (background playback works)
4. Lock screen shows media controls
5. Returns to app → Practice view is still there
6. Audio stops only when navigating back, not when backgrounding

## Design Decisions

### 1a: Practice Tab Shows Last Active Session
- **Decision:** Practice Tab displays the most recent practice session
- **Rationale:** Provides consistency and continuity across app usage
- **Implementation:** `practiceSessionStartedFromLibrary` syncs state

### 2a: Same Session Across Tabs
- **Decision:** Practice Tab shows the same session regardless of where it started
- **Rationale:** Unified state, no duplicate sessions, clear single source of truth
- **Implementation:** Shared PracticeService and session management

### 3b: Only Start Practice Via Library Flow
- **Decision:** Primary practice initiation is through Library → Track → Practice Set
- **Rationale:** Provides context and clear path to practice sessions
- **Note:** Practice Tab still allows direct track selection for convenience

### 4a: Audio Stops on Navigation Back
- **Decision:** Audio stops when navigating back to Track Details
- **Rationale:** Clean separation, prevents edge cases, matches user expectations
- **Implementation:** `viewWillDisappear` with `isMovingFromParent` check

## Benefits

### For Users
- **Intuitive Navigation:** Back button works as expected
- **Contextual Flow:** Natural progression from browsing to practicing
- **Consistent State:** Same session visible across tabs
- **Clean Audio Management:** Audio behavior matches expectations

### For Development
- **Simpler State Management:** Single source of truth for sessions
- **Cleaner Architecture:** Navigation follows iOS conventions
- **Fewer Edge Cases:** Audio lifecycle is predictable
- **Maintainable:** Standard UIKit navigation patterns

## Testing Guide

### Test 1: Library Navigation Flow
1. Open Library tab
2. Tap a track
3. Tap a practice set
4. **Verify:** PracticeViewController is shown with back button
5. Tap back button
6. **Verify:** Returns to Track Details
7. **Verify:** Audio stops when navigating back

### Test 2: State Synchronization
1. Start practice from Library (Test 1)
2. Switch to Practice Tab
3. **Verify:** Same track and practice set are shown
4. **Verify:** Session state is preserved (current clip, loops, etc.)

### Test 3: Practice Tab Direct Access
1. Tap Practice Tab
2. **Verify:** Shows last active session or empty state
3. Select a track and practice set
4. Start practicing
5. Switch to Library Tab
6. **Verify:** Still on Library Tab (no automatic switching)
7. Switch back to Practice Tab
8. **Verify:** Session is still active

### Test 4: Background Playback
1. Start practice from Library
2. Lock phone or press home button
3. **Verify:** Audio continues playing
4. **Verify:** Lock screen shows media controls
5. Use lock screen controls to pause/resume
6. **Verify:** Controls work correctly
7. Return to app
8. **Verify:** Practice view is still showing

### Test 5: Audio Lifecycle
1. Start practice from Library
2. Navigate back to Track Details
3. **Verify:** Audio stops immediately
4. Navigate to practice set again
5. Start practice
6. Background app (don't navigate back)
7. **Verify:** Audio continues
8. Return to app
9. **Verify:** Audio still playing

## Migration Notes

### Breaking Changes
**None** - This is a pure enhancement to navigation flow

### Backward Compatibility
- Existing practice sessions continue to work
- Practice Tab still functions independently
- `switchToPracticeWithSet` method preserved for future use cases

### API Changes
**New Methods:**
- `AppCoordinator.practiceSessionStartedFromLibrary(track:practiceSet:)`

**Modified Methods:**
- `LibraryCoordinator.trackDetailViewController(_:didSelectPracticeSet:forTrack:)`
  - Now pushes instead of switching tabs

## Future Enhancements

### Potential Improvements
1. **Deep Linking:** Support URLs that navigate directly to practice sessions
2. **Breadcrumbs:** Show navigation path in Practice view when accessed from Library
3. **Multi-instance:** Allow multiple practice sessions in different contexts
4. **Quick Switch:** Add button to jump between Library and Practice views

### Considerations
- Should we show different UI when practice is accessed from Library vs directly?
- Should back button behavior be customizable via settings?
- Would users benefit from a "floating" practice view that overlays Library?

## Technical Details

### Navigation Stack Structure

**Library Tab Navigation:**
```
UINavigationController
  ├─ LibraryViewController
  ├─ TrackDetailViewController
  └─ PracticeViewController (when accessed from Track Details)
```

**Practice Tab Navigation:**
```
UINavigationController
  └─ PracticeViewController (standalone)
```

### State Management
- **PracticeService:** Manages session persistence and state
- **PracticeCoordinator:** Manages Practice Tab's view lifecycle
- **LibraryCoordinator:** Manages Library Tab's navigation stack
- **AppCoordinator:** Coordinates cross-tab state synchronization

### Memory Management
- Multiple PracticeViewController instances can exist (one per tab context)
- Shared services (PracticeService, AudioPlayerService) ensure consistent state
- Proper cleanup in `deinit` and `viewWillDisappear`

## Commit Information

**Commit Hash:** `89a3d63`
**Commit Message:** Refactor practice navigation to use Library nav stack

**Files Modified:**
- `Coordinators/LibraryCoordinator.swift` (19 lines added, 1 removed)
- `Coordinators/AppCoordinator.swift` (6 lines added)

**Total Changes:** 2 files changed, 19 insertions(+), 1 deletion(-)

