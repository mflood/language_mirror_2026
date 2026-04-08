# Language Mirror — Product Ideas Backlog

Last updated: 2026-04-06

Target audience:
- Korean speakers learning English
- English speakers learning Korean
- Anyone using shadowing / repetition-based language practice
- ADHD-friendly UX is a core constraint

---

## Tier 1 — Highest impact, smallest effort

### 1. Translation toggle in transcript banner
Show source language by default; tap to flip to translation. Requires adding a translation pass to the bundle pipeline (one extra GPT prompt).
Effort: a few hours.

### 2. Loop-just-this-clip button ✅ (in progress)
Forever button currently loops the whole set. Add a button to loop only the current clip indefinitely — shadowers want to drill one sentence until it clicks.
Effort: <1 hour.

### 3. Adjustable transcript banner font size ✅ (in progress)
Simple A−/A+ toggle, persisted to UserDefaults. Helps users practicing without glasses or wanting to read along easily.
Effort: tiny.

### 4. Copy / share transcript text ✅ (in progress)
Add a copy/share button to the transcript detail sheet. Learners constantly copy sentences into Anki, Notes, or translation apps.
Effort: trivial.

### 5. Show transcript on lock screen artwork
Replace the placeholder gradient with a rendered image of the current transcript text, so users can practice eyes-up (driving, walking, working out).
Effort: half a day. Long Korean sentences need wrapping logic.

---

## Tier 2 — High impact, modest effort

### 6. 3-screen onboarding swipe
"Import audio → Slice into clips → Practice with loops". Reduces drop-off for new users who land on a blank library.
Effort: 1–2 days.

### 7. "Try a sample" empty state
Bundle one royalty-free sample track (must be your own — no IP). Auto-import on first launch if library is empty so users can experience the practice loop immediately.
Effort: a few hours plus recording.

### 8. Practice streak / daily goal
Track consecutive days with practice sessions. Display badge on Practice Home. Habit-driver, especially good for ADHD users.
Effort: small.

### 9. Background bundle download notification
Local notification when a long bundle download completes. Polish + reliability perception.
Effort: ~2 hours.

### 10. iPad layout fix
Clamp content to `readableContentGuide` and audit landscape. Ten-line fix that helps a lot now that all four orientations are declared.
Effort: a few hours.

---

## Tier 3 — Strategic but more work

### 11. "Today's clip" home screen widget
Shows one clip + tap-to-practice CTA. Massive engagement driver via WidgetKit.
Effort: 1–2 days.

### 12. Speaker labels in transcript banner
Bundles already capture speaker info. For dialogues, show "👤 Speaker 1: ..." in the banner.
Effort: tiny — data is already there.

### 13. Color-coded clip cells by completion
Tint completed clips green so users can see at a glance which they've drilled enough. Visual progress helps ADHD users.
Effort: a few lines in ClipCell.

### 14. Export practice session as PDF / text
Share button that generates a simple text/PDF with what was practiced, when, and how many loops.
Effort: half a day.

### 15. Speed shortcut on lock screen / Control Center
Custom MPRemoteCommand to change playback speed without unlocking.
Effort: half a day.
