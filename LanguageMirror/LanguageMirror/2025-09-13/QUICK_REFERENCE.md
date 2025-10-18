# Library View Controller - Quick Reference

## What Changed?

### Before 👎
```
Plain UITableView
├─ Basic system cells
├─ Text-only information
├─ Instant reload (no animation)
├─ Basic header views
└─ Empty screens when no data
```

### After 👍
```
Beautiful Card-Based Design
├─ Custom TrackCell with icons, badges, tags
├─ Color-coded duration system
├─ Smooth spring animations
├─ Enhanced headers with pack colors
├─ Encouraging empty states
├─ Haptic feedback throughout
└─ Full dark mode optimization
```

## Visual Hierarchy

```
┌─────────────────────────────────────────┐
│ ← Library               [Sort]          │  Navigation
├─────────────────────────────────────────┤
│ [Search tracks]                         │  Search
├─────────────────────────────────────────┤
│                                         │
│  ┌────────────────────────────────┐    │  Pack Header
│  │ │ ▶ Korean Culture Pack   (24)│    │  - Color stripe
│  └────────────────────────────────┘    │  - Animated chevron
│                                         │  - Count badge
│  ┌────────────────────────────────┐    │
│  │ ┌──┐                           │    │  Track Cell
│  │ │🌊│ Track Title        ┌────┐ │    │  - Waveform icon
│  │ └──┘ Subtitle           │4:32│ │    │  - Duration badge
│  │      [tag] [tag] [+3]   └────┘ │    │  - Tag chips
│  │      ━━━━━━━━━░░░░░░░░         │    │  - Progress bar
│  └────────────────────────────────┘    │
│                                         │
│  ┌────────────────────────────────┐    │  Another Track
│  │ ┌──┐                           │    │
│  │ │🌊│ Another Track      ┌────┐ │    │
│  │ └──┘ Info               │1:45│ │    │
│  │      [vocab]            └────┘ │    │
│  │      ━━━━━━━━━━━━━━━━━         │    │
│  └────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

## Color System at a Glance

### Duration Badges
```
┌──────┐  ┌──────┐  ┌──────┐
│ 1:23 │  │ 3:45 │  │ 7:30 │
└──────┘  └──────┘  └──────┘
  Green     Amber      Blue
  0-2min    2-5min     5+min
```

### Pack Colors (Cycle through 9)
```
Blue → Green → Purple → Teal → Indigo
  ↓                              ↑
Cyan ← Mint  ← Orange ← Pink ←──┘
```

### Dark Mode Comparison
```
Light Mode              Dark Mode
────────────────────────────────────────
Background: 0.97 white  Background: 0.11 white
Cards:      0.98 white  Cards:      0.15 white
Text:       0.00 black  Text:       1.00 white
Shadow:     Soft black  Glow:       Soft white
Opacity:    0.08-0.10   Opacity:    0.05-0.08
```

## Animation Speeds

```
Button Press    ┃▮▮▮▯▯▯▯▯▯▯┃ 0.1s  Fast & responsive
Tap Feedback    ┃▮▮▮▮▮▯▯▯▯▯┃ 0.3s  Standard transitions
Pack Expansion  ┃▮▮▮▮▮▮▮▯▯▯┃ 0.4s  Smooth & natural
Empty State     ┃▮▮▮▮▮▮▮▮▮▯┃ 0.6s  Gentle entrance
```

## Key Files

```
Utils/
  └─ AppColors.swift           ← Color system + extensions

Views/
  ├─ TrackCell.swift           ← Custom track cell
  ├─ EmptyStateView.swift      ← Empty states
  └─ WaveformPlaceholderView.swift (existing)

Screens/
  └─ LibraryViewController.swift ← Main view (enhanced)

Documentation/
  ├─ LIBRARY_UI_IMPROVEMENTS.md  ← Detailed guide
  ├─ ADHD_DESIGN_GUIDELINES.md   ← Design system
  └─ QUICK_REFERENCE.md          ← This file
```

## Code Snippets

### Using the Color System
```swift
// Background
view.backgroundColor = AppColors.primaryBackground

// Card with shadow
cardView.backgroundColor = AppColors.cardBackground
cardView.applyAdaptiveShadow()

// Duration badge
badge.backgroundColor = AppColors.durationShortBackground
badge.textColor = AppColors.durationShort

// Pack color
header.backgroundColor = AppColors.packBackground(index: 0)
```

### Adding Haptic Feedback
```swift
// Light tap
let generator = UIImpactFeedbackGenerator(style: .light)
generator.impactOccurred()

// Success
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success)
```

### Spring Animation
```swift
UIView.animate(
    withDuration: 0.3,
    delay: 0,
    usingSpringWithDamping: 0.7,
    initialSpringVelocity: 0.5,
    options: [.allowUserInteraction]
) {
    view.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
}
```

## Testing Quick Checks

### Visual
1. Switch between light/dark mode → colors adapt smoothly
2. Tap cells → scale animation + haptic
3. Expand packs → chevron rotates, rows fade in
4. Pull down → refresh control appears
5. Clear library → empty state shows

### Interaction
1. All touches have haptic feedback
2. All animations are < 0.8s
3. Touch targets are ≥ 44x44pt
4. VoiceOver reads everything logically

### Appearance
1. No pure black (#000) or pure white (#FFF)
2. Text is readable in both modes
3. Shadows are subtle and appropriate
4. Spacing feels comfortable (not cramped)
5. Colors are distinguishable

## Common Adjustments

### Want slower animations?
```swift
// Change duration from 0.3 to 0.5
UIView.animate(withDuration: 0.5, ...)
```

### Want less bouncy?
```swift
// Increase damping from 0.7 to 0.85
usingSpringWithDamping: 0.85
```

### Want different pack colors?
```swift
// Edit packBaseColors in AppColors.swift
private static let packBaseColors: [UIColor] = [
    .systemBlue,
    .systemGreen,
    // Add your colors here
]
```

### Want different duration thresholds?
```swift
// Edit configure(durationMs:) in DurationBadge
if totalSeconds < 120 {  // Change from 120 (2min)
    // short
} else if totalSeconds < 300 {  // Change from 300 (5min)
    // medium
} else {
    // long
}
```

## Troubleshooting

### Colors don't adapt to dark mode
- Check if using `UIColor { traitCollection in ... }`
- Ensure calling `traitCollectionDidChange`

### Animations feel choppy
- Check if running on real device (simulator can lag)
- Verify not blocking main thread
- Consider reducing shadow complexity

### Cells look squished
- Check height constraints
- Verify `estimatedHeightForRowAt` is reasonable
- Ensure `UITableView.automaticDimension` is set

### Empty state not showing
- Check `updateEmptyState()` is called after reload
- Verify `filteredPacks` is actually empty
- Ensure empty view constraints are correct

## Performance Notes

- Cell reuse: ✅ Using dequeue properly
- Shadow rendering: ✅ Cached via layer
- Animation performance: ✅ Using layer transforms
- Memory usage: ✅ Lightweight views
- Image loading: ✅ SF Symbols (vector)

## Next Steps

1. **Build and run** to see the improvements
2. **Test in both modes** (light and dark)
3. **Try on device** for haptic feedback
4. **Adjust colors/timing** to your preference
5. **Extend pattern** to other view controllers

---

**TL;DR**: Library now has beautiful cards, color-coded durations, smooth animations, haptic feedback, encouraging empty states, and perfect dark mode support. It feels amazing! 🎉

