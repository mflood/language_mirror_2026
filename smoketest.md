# Language Mirror - Pre-Release Smoketest

Run through this checklist on a **real device** before each App Store submission.
Tests marked (P) require a published bundle on S3.

---

## 1. Fresh Launch

- [ ] App launches without crash
- [ ] Library tab shows empty state (no leftover data)
- [ ] All four tabs are visible: Library, Import, Practice, Settings
- [ ] Tab icons and labels render correctly
- [ ] Dark mode: switch in Settings.app and verify all tabs adapt

---

## 2. Import Tab

- [ ] Five import options are displayed (Video, Files, Record, URL, Bundle)
- [ ] No "Install Free Packs" row is visible
- [ ] Help button (?) shows import instructions
- [ ] Each option has an icon, title, and description
- [ ] Tapping each option gives haptic feedback

### 2a. Import from Video

- [ ] Photo library picker opens, filtered to videos
- [ ] Selecting a video extracts audio and imports a track
- [ ] Progress UI appears during extraction
- [ ] Track appears in Library after success

### 2b. Import from Files

- [ ] Document picker opens, filtered to audio types
- [ ] Selecting an audio file imports it
- [ ] Progress UI appears during import

### 2c. Record Audio

- [ ] Recorder screen pushes onto navigation stack
- [ ] Record button starts recording with waveform animation
- [ ] Timer counts up during recording
- [ ] Stop button ends recording and shows review state
- [ ] Play button plays back the recording
- [ ] "Use Recording" imports the track
- [ ] "Re-record" returns to ready state

### 2d. Download from URL

- [ ] Alert appears with empty URL field (no pre-filled text)
- [ ] Optional title field is present
- [ ] Cancel dismisses without action
- [ ] Entering an invalid URL shows error
- [ ] Entering a valid audio URL downloads and imports the track

### 2e. Install Bundle (P)

- [ ] Alert appears with empty URL field (no pre-filled text)
- [ ] Cancel dismisses without action
- [ ] Entering a valid manifest URL downloads bundle with progress UI
- [ ] All tracks from bundle appear in Library under the correct pack
- [ ] Practice sets and transcripts are imported with each track

---

## 3. URL Scheme / QR Code Import (P)

- [ ] Open Safari and navigate to:
      `languagemirror://bundle?url=<your_encoded_manifest_url>`
      App opens and begins importing
- [ ] Cold launch: force-quit app, scan QR code, app launches and imports
- [ ] Warm launch: app is in background, scan QR code, app foregrounds and imports
- [ ] Invalid URL parameter shows error (not a crash)
- [ ] Unknown host (e.g. `languagemirror://foo`) is silently ignored (no crash)

---

## 4. Library Tab

### 4a. Browsing

- [ ] Imported tracks appear organized by pack
- [ ] Pack sections are collapsible/expandable
- [ ] "Recently Added" section shows latest imports
- [ ] Pull-to-refresh works
- [ ] Track cells show title and duration

### 4b. Search & Sort

- [ ] Search bar filters tracks by title
- [ ] Sort menu is accessible (Title, Date Added, Duration)
- [ ] Each sort direction works (A-Z / Z-A, Newest / Oldest, etc.)
- [ ] Sort preference persists across tab switches

### 4c. Track Detail

- [ ] Tapping a track opens Track Detail screen
- [ ] Practice sets are listed
- [ ] Tapping a practice set navigates to Practice screen
- [ ] Back button returns to Library

### 4d. Delete

- [ ] Swipe-to-delete (or context menu) prompts confirmation
- [ ] Confirming removes the track from library
- [ ] Cancelling keeps the track

---

## 5. Practice Tab

### 5a. Practice Home

- [ ] Shows recent/active practice sessions (or empty state)
- [ ] "Continue Practicing" cards scroll horizontally
- [ ] Tapping a session card opens Practice screen
- [ ] "Browse Library" button navigates to Library tab

### 5b. Playback - Simple Mode

- [ ] Play button starts clip playback
- [ ] Pause button pauses playback
- [ ] Clip loops the configured number of repeats
- [ ] Advances to next clip after repeats complete
- [ ] Speed preset strip is visible and functional
- [ ] Changing speed mid-playback takes effect immediately
- [ ] Loop counter increments correctly
- [ ] Progress label shows current clip / total clips

### 5c. Playback - Progression Mode

- [ ] Switch to Progression mode in Settings
- [ ] Return to Practice - speed ramps from min to max across loops
- [ ] Visual speed indicator reflects current speed
- [ ] Progression curve matches Settings configuration

### 5d. Forever Mode

- [ ] Tap infinity button to enable forever mode
- [ ] Playback loops through all clips indefinitely
- [ ] Tap again to disable - playback stops after current cycle

### 5e. Edit Mode

- [ ] Toggle edit mode in Practice screen
- [ ] Split clip at current position
- [ ] Merge adjacent clips
- [ ] Save changes persists edits
- [ ] Discard changes reverts to original

### 5f. Favorites

- [ ] Mark a practice set as favorite
- [ ] Favorite appears in Library's favorites section
- [ ] Unfavorite removes it

---

## 6. Settings Tab

### 6a. Practice Mode

- [ ] Toggle between Simple and Progression mode
- [ ] Simple mode settings are visible when selected
- [ ] Progression mode settings are visible when selected

### 6b. Simple Mode Settings

- [ ] Speed preset strip changes speed
- [ ] Repeat count slider adjusts (1-100)

### 6c. Progression Mode Settings

- [ ] Min speed / Max speed adjustable
- [ ] Min repeats / Max repeats adjustable
- [ ] Ramp steps adjustable
- [ ] Progression curve preview updates in real-time

### 6d. Playback Settings

- [ ] Gap between repeats slider (0-2.0s)
- [ ] Gap between clips slider (0-2.0s)
- [ ] Preroll silence selector (0/100/200/300ms)
- [ ] Duck other audio toggle

---

## 7. Share Extension

- [ ] Open Voice Memos (or another app with audio)
- [ ] Tap Share button, select "Language Mirror"
- [ ] Extension UI shows progress
- [ ] Return to Language Mirror - shared track appears in Library

---

## 8. Dark Mode & Appearance

- [ ] Switch to dark mode in iOS Settings
- [ ] All screens render correctly (no white backgrounds, unreadable text)
- [ ] Switch back to light mode - all screens adapt
- [ ] Shadows adapt to appearance (not visible in dark mode)

---

## 9. Edge Cases

- [ ] Airplane mode: URL/bundle imports show clear network error
- [ ] Cancel an in-progress import - no crash, UI recovers
- [ ] Rapidly switch tabs during playback - no crash or audio glitch
- [ ] Background the app during playback - audio continues
- [ ] Return from background - UI state is correct
- [ ] Rotate device (if supported) - layout adapts

---

## 10. No Intellectual Property

- [ ] No embedded audio packs are included in the app bundle
- [ ] "Install Free Packs" option is not visible
- [ ] No third-party content is bundled or pre-loaded

---

## Notes

- Test on the oldest supported device/OS you can (iOS 18.5+)
- Test on both iPhone and iPad if universal
- Keep Xcode console open during testing to catch warnings/crashes
- After all tests pass, archive and upload via Product > Archive > Distribute
