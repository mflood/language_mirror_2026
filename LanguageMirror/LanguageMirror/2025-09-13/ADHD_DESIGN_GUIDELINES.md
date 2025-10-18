# ADHD-Friendly Design Guidelines for LanguageMirror

## Core Principles

### 1. Visual Over Verbal
- Use icons, colors, and shapes before text
- Color-code information by category or priority
- Create visual patterns that become familiar

### 2. Reduce Cognitive Load
- Show only essential information by default
- Use progressive disclosure (expand for details)
- Group related items clearly
- Maintain consistent patterns

### 3. Provide Immediate Feedback
- Haptic feedback for all interactions
- Smooth animations (not instant changes)
- Visual state changes (pressed, selected, etc.)
- Success celebrations for completions

### 4. Minimize Decision Paralysis
- Clear visual hierarchy guides attention
- Limit choices when possible
- Provide smart defaults
- Make reversible actions easy

### 5. Create Comfortable Environments
- Soft, rounded shapes (not harsh angles)
- Gentle color palettes (not high contrast)
- Spacious layouts (not cramped)
- Dark mode as first-class citizen

## Color Guidelines

### Duration Color Coding
```
0-2 min   → Green  (Quick win! Low commitment)
2-5 min   → Amber  (Medium session, doable)
5+ min    → Blue   (Longer commitment, plan ahead)
```

### Dark Mode Colors
- **Don't use**: Pure black (#000000) or pure white (#FFFFFF)
- **Do use**: Soft dark grays (0.11-0.17 white) and off-whites (0.95-0.99 white)
- **Shadows**: Lighter and more subtle in dark mode
- **Glows**: More effective than shadows in dark mode

### Pack Colors (Rainbow System)
Cycle through 9 distinct colors for visual variety:
Blue → Green → Purple → Teal → Indigo → Pink → Orange → Cyan → Mint

## Animation Guidelines

### Timing
- **Quick interactions**: 0.1-0.2s (button presses)
- **UI updates**: 0.3s (standard transitions)
- **Major changes**: 0.4-0.6s (expansions, reveals)

### Spring Physics
```swift
damping: 0.7          // Bouncy but controlled
initialVelocity: 0.5  // Natural acceleration
```

### When to Animate
- ✅ State changes (expand/collapse)
- ✅ User interactions (tap, swipe)
- ✅ Content updates (new data)
- ✅ Success/completion
- ❌ Don't animate on initial load
- ❌ Respect reduce motion settings

## Spacing System

```
Micro:   4pt   (icon-to-label, tight grouping)
Small:   6-8pt (between related elements)
Medium:  12pt  (card padding, between groups)
Large:   16pt  (screen margins, section gaps)
XLarge:  24pt+ (major section breaks)
```

## Typography

### Font Weights
- **Heavy (700-900)**: Avoid (too aggressive)
- **Semibold (600)**: Headers, emphasis
- **Medium (500)**: Default for most text
- **Regular (400)**: Body text, descriptions
- **Light (300)**: Avoid (too faint)

### Sizes
```
Large Title:  34pt (navigation bars)
Title 1:      28pt (major sections)
Title 2:      22pt (subsections)
Title 3:      20pt (card headers)
Body:         17pt (main content)
Callout:      16pt (secondary content)
Subhead:      15pt (labels)
Footnote:     13pt (metadata)
Caption:      11-12pt (tags, badges)
```

## Interaction Design

### Touch Targets
- **Minimum**: 44x44pt (Apple HIG)
- **Preferred**: 48x48pt or larger
- **Exception**: Densely packed info (e.g., tags) can be smaller if not primary action

### Feedback Types

#### Haptic Feedback
```swift
Light    → Selection, expansion, minor actions
Medium   → Primary actions, important confirmations
Heavy    → Destructive actions (use sparingly)
Success  → Completed tasks, achievements
Warning  → Alerts, important changes
Error    → Failed operations
```

#### Visual Feedback
- **Instant**: Background color change
- **Brief**: Scale animation (0.1-0.2s)
- **Persistent**: State indicator (checkmark, badge)

## Layout Patterns

### Card-Based Design
```
┌─────────────────────────────┐
│ [Icon] Title         [Badge]│
│        Subtitle              │
│        [Tag] [Tag] [+2 more] │
│ ──────────────────────       │ ← Progress
└─────────────────────────────┘
```

Benefits:
- Clear boundaries (no ambiguity)
- Self-contained (easy to scan)
- Shadowable (depth perception)
- Tappable (obvious interaction)

### Progressive Disclosure
```
Pack Header (always visible)
  ▼ Expanded → Shows tracks
    Track 1
    Track 2
    Track 3
```

Benefits:
- User controls information density
- Reduces initial overwhelm
- Encourages exploration
- Persistent state (remembers choices)

## Empty States

### Components
1. **Icon**: Large (60-80pt), relevant symbol
2. **Title**: Clear, positive language
3. **Message**: Helpful guidance, not blame
4. **Action** (optional): Clear next step

### Tone
- ❌ "No items" → Too negative
- ❌ "Nothing here yet" → Implies failure
- ✅ "Your library awaits" → Positive, inviting
- ✅ "Ready to start?" → Action-oriented

## Common Patterns

### Duration Badge
```swift
┌──────────┐
│  4:32    │  ← Monospaced font, color-coded background
└──────────┘
```

### Tag Chip
```swift
┌──────────┐
│ culture  │  ← Small, rounded, subtle background
└──────────┘
```

### Count Badge
```swift
┌────┐
│ 42 │  ← Circular or pill-shaped, clear number
└────┘
```

### Progress Bar
```swift
─────────────────█████░░░░░░  ← Thin (3-4pt), subtle, at bottom
```

## Accessibility Considerations

### Color Blindness
- Don't rely on color alone
- Use icons + color
- Test with color filters

### Dynamic Type
- Use system fonts (auto-scaling)
- Test at largest sizes
- Maintain hierarchy at all sizes

### VoiceOver
- Meaningful labels
- Group related elements
- Logical reading order
- Action hints for custom controls

### Reduce Motion
```swift
if UIAccessibility.isReduceMotionEnabled {
    // Instant updates instead of animations
    view.alpha = 1.0
} else {
    // Normal spring animation
    UIView.animate(withDuration: 0.3, ...) { ... }
}
```

## Anti-Patterns (Things to Avoid)

### Visual
- ❌ Pure black or white
- ❌ High contrast stripes
- ❌ Flashing or pulsing (seizure risk)
- ❌ Too many colors at once
- ❌ Tiny text (< 11pt)
- ❌ Cramped layouts

### Interaction
- ❌ Instant changes (no animation)
- ❌ Long animations (> 0.8s)
- ❌ Elastic/bouncy (makes some people nauseous)
- ❌ Hidden actions (require discovery)
- ❌ Unclear states

### Content
- ❌ Walls of text
- ❌ Too many options
- ❌ Ambiguous labels
- ❌ Negative language ("No items", "Empty", "Failed")

## Testing Checklist

Before shipping a new screen:

- [ ] Test in light mode at various brightness levels
- [ ] Test in dark mode at various brightness levels
- [ ] Try with largest Dynamic Type size
- [ ] Enable VoiceOver and navigate
- [ ] Enable Reduce Motion and check animations
- [ ] Test with limited dexterity (large touch targets?)
- [ ] Ask: Does this feel overwhelming?
- [ ] Ask: Is it immediately clear what to do?
- [ ] Ask: Does interaction feel rewarding?
- [ ] Ask: Would I want to use this when tired/distracted?

## Resources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Inclusive Design Principles](https://inclusivedesignprinciples.org/)
- ADHD-specific: Focus on reducing cognitive load, providing immediate feedback, and creating comfortable environments

---

**Remember**: The goal isn't perfection—it's creating an environment where users with ADHD can succeed. Every small improvement in clarity, feedback, and comfort compounds into a significantly better experience.

