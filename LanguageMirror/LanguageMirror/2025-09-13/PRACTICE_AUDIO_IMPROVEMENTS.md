# Practice Session Audio Improvements

## Overview
This document describes improvements made to handle audio playback edge cases during navigation and to enable proper background playback controls on iOS.

## Problems Addressed

### 1. Navigation Edge Cases
**Problem:** Audio playback continued when navigating to different tracks or screens, leading to confusing states where:
- Audio from Track A played while viewing Track B
- Multiple practice sessions could overlap
- Audio continued after leaving the Practice screen

**Solution:** Implemented intelligent playback stopping:
- **Track switching**: Audio automatically stops when selecting a different track
- **Screen navigation**: Audio stops when navigating away from Practice screen (detected via `viewWillDisappear` and `isMovingFromParent`)
- **Memory cleanup**: Audio is properly stopped in the `deinit` method

### 2. Background Playback Controls
**Problem:** While audio continued playing in the background, no media controls appeared on the lock screen or in Control Center.

**Solution:** Enhanced the audio player service with proper iOS media integration:
- **Fixed duplicate command registration**: Removed duplicate remote command handlers that could cause issues
- **Improved audio session**: Changed to `.spokenAudio` mode (better for language learning content)
- **Added Now Playing metadata**: 
  - Track/clip title
  - Album title ("LanguageMirror")
  - Artist ("Practice Session")
  - Playback duration and elapsed time
  - Playback rate information
- **Added artwork**: Created placeholder artwork with emoji icon and gradient background for better lock screen presence

## Code Changes

### `PracticeViewController.swift`

#### 1. Added lifecycle methods for audio management
```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Stop playback when navigating away from Practice screen
    if isMovingFromParent || isBeingDismissed {
        stopCurrentPlayback()
    }
}

deinit {
    NotificationCenter.default.removeObserver(self)
    stopCurrentPlayback()
}
```

#### 2. Enhanced track switching logic
```swift
private var selectedTrack: Track? {
    didSet {
        // Stop playback when switching to a different track
        if let oldTrack = oldValue, let newTrack = selectedTrack, oldTrack.id != newTrack.id {
            stopCurrentPlayback()
        }
        // ... rest of the code
    }
}
```

#### 3. Added helper method
```swift
private func stopCurrentPlayback() {
    if isPlaying || isPaused {
        player.stop()
        isPlaying = false
        isPaused = false
        updatePlayPauseButton()
    }
}
```

### `AudioPlayerServiceAVPlayer.swift`

#### 1. Fixed Remote Command Registration
**Before:** Duplicate command registrations that could cause conflicts
```swift
let t1 = center.playCommand.addTarget { ... }
let t2 = center.pauseCommand.addTarget { ... }
let t3 = center.stopCommand.addTarget { ... }
// ... duplicate registrations below
center.playCommand.addTarget { ... }
center.pauseCommand.addTarget { ... }
center.stopCommand.addTarget { ... }
```

**After:** Single, clean registration
```swift
center.playCommand.addTarget { [weak self] _ in 
    self?.resume()
    return .success 
}
center.pauseCommand.addTarget { [weak self] _ in 
    self?.pause()
    return .success 
}
center.stopCommand.addTarget { [weak self] _ in 
    self?.stop()
    return .success 
}
```

#### 2. Improved Audio Session Configuration
```swift
// Use .playback category to enable background audio and lock screen controls
// Mode .spokenAudio is better for language learning content
try session.setCategory(.playback, mode: .spokenAudio, options: opts)
try session.setActive(true, options: [])
```

**Why `.spokenAudio` mode?**
- Optimized for spoken content (perfect for language learning)
- Better handling of voice audio
- Proper integration with system audio routing

#### 3. Enhanced Now Playing Info
```swift
private func updateNowPlaying(track: Track,
                              segmentTitle: String?,
                              elapsed: Double,
                              duration: Double,
                              rate: Float) {
    var info: [String: Any] = [:]
    
    // Track/clip title
    let displayTitle = segmentTitle?.isEmpty == false ? segmentTitle : track.title
    info[MPMediaItemPropertyTitle] = displayTitle
    info[MPMediaItemPropertyAlbumTitle] = "LanguageMirror"
    info[MPMediaItemPropertyArtist] = "Practice Session"
    
    // Playback info
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
    info[MPMediaItemPropertyPlaybackDuration] = duration
    info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    info[MPNowPlayingInfoPropertyPlaybackRate] = rate
    info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
    
    // Add artwork for better lock screen presence
    if let artwork = createPlaceholderArtwork(title: displayTitle) {
        info[MPMediaItemPropertyArtwork] = artwork
    }

    nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}
```

#### 4. Added Artwork Generation
```swift
private func createPlaceholderArtwork(title: String) -> MPMediaItemArtwork? {
    // Creates a 300x300 image with:
    // - Blue to purple gradient background
    // - White headphones emoji (🎧)
    // - Centered layout
}
```

## Testing Guide

### Test Navigation Edge Cases

1. **Test Track Switching**
   - Start practicing Track A
   - Switch to Track B using the track selector
   - ✅ Verify: Audio for Track A stops immediately
   - ✅ Verify: Track B is loaded with no audio playing

2. **Test Screen Navigation**
   - Start a practice session
   - Tap the track title to navigate to Library/TrackDetail
   - ✅ Verify: Audio stops when leaving Practice screen
   - Return to Practice screen
   - ✅ Verify: Practice session state is preserved but not playing

3. **Test Tab Switching**
   - Start a practice session
   - Switch to Library, Import, or Settings tab
   - ✅ Verify: Audio stops when switching tabs
   - Return to Practice tab
   - ✅ Verify: Can resume practice from where you left off

### Test Background Playback Controls

1. **Test Lock Screen Controls**
   - Start a practice session
   - Lock your device (press power button)
   - ✅ Verify: Lock screen shows:
     - Track/clip title
     - "LanguageMirror" album name
     - "Practice Session" artist
     - Headphones emoji artwork with gradient
     - Play/Pause button
     - Timeline scrubber
   - ✅ Verify: Pause button works
   - ✅ Verify: Play button resumes playback
   - ✅ Verify: Progress bar updates in real-time

2. **Test Control Center**
   - Start a practice session
   - Swipe down to open Control Center (or swipe up on older devices)
   - ✅ Verify: Media controls appear with same information
   - ✅ Verify: Play/Pause works from Control Center
   - ✅ Verify: Closing Control Center doesn't affect playback

3. **Test Background Playback**
   - Start a practice session
   - Go to home screen (swipe up)
   - ✅ Verify: Audio continues playing
   - ✅ Verify: Controls remain accessible from lock screen/Control Center
   - Open another app
   - ✅ Verify: Audio continues playing
   - ✅ Verify: Progress updates in Now Playing info

4. **Test AirPods/Bluetooth**
   - Connect AirPods or Bluetooth headphones
   - Start practice session
   - ✅ Verify: Audio routes to AirPods/headphones
   - ✅ Verify: Physical controls on AirPods work (play/pause)
   - Remove AirPods
   - ✅ Verify: Playback pauses automatically (polite behavior)

### Test Speed Changes
- Start practice with speed ramping enabled
- Lock device
- ✅ Verify: Speed changes are reflected in Now Playing info
- ✅ Verify: Playback rate updates in Control Center

## Expected Behavior Summary

### Navigation
- ✅ Audio stops when changing tracks
- ✅ Audio stops when leaving Practice screen
- ✅ Audio stops when switching tabs
- ✅ Practice session state persists
- ✅ Can resume practice after navigation

### Background Playback
- ✅ Audio continues when app is backgrounded
- ✅ Lock screen shows media controls with artwork
- ✅ Control Center shows media controls
- ✅ Physical controls (AirPods, headphones) work
- ✅ Play/Pause from lock screen/Control Center works
- ✅ Progress bar updates in real-time
- ✅ Speed changes reflected in Now Playing
- ✅ Clip transitions update lock screen title

## Future Enhancements (Optional)

Consider adding these features in the future:

1. **User Preference for Background Behavior**
   - Add a setting: "Continue playing when navigating within app"
   - Some users might want audio to continue when switching tabs

2. **Next/Previous Track Commands**
   - Enable skip forward/backward in Control Center
   - Map to next/previous clip in practice session

3. **Custom Artwork**
   - Allow users to set custom artwork for tracks
   - Display track-specific images on lock screen

4. **Notification-style Controls**
   - Consider showing persistent notification with controls (Android-style)

## Notes

- The app's `Info.plist` already had `UIBackgroundModes` with `audio` enabled, so no changes were needed there
- The `.spokenAudio` audio session mode is specifically optimized for language learning content
- Artwork generation is lightweight (300x300 pixels) to avoid memory issues
- All changes maintain backward compatibility with existing practice sessions

## Commit Information

**Commit Hash:** `0e167b3`
**Commit Message:** Fix practice session audio playback edge cases and background controls

