# AudioRecorderViewController Interface Builder Setup Guide

This guide provides step-by-step instructions for setting up the AudioRecorderViewController in Interface Builder.

## Overview

The AudioRecorderViewController provides a comprehensive interface for recording audio with:
- Recording controls (record, pause, stop)
- Real-time waveform visualization
- Playback controls with progress tracking
- Recording quality settings
- Recent recordings list
- File management

## Main View Controller Setup

### 1. Create the View Controller
1. Open your storyboard
2. Add a new View Controller
3. Set the Class to `AudioRecorderViewController`
4. Set the Storyboard ID to `AudioRecorderViewController`

### 2. View Hierarchy
Create the following hierarchy in the main view:

```
View (Main View)
├── ScrollView
│   └── Content Stack View (Vertical)
│       ├── Header View
│       ├── Recording Controls Container View
│       ├── Waveform Container View
│       ├── Playback Controls Container View
│       ├── Settings Container View
│       └── Recordings Container View
└── Loading Overlay View
```

## Header Section

### Header View
- **Height**: 60
- **Background**: Clear
- **Constraints**: Top, Leading, Trailing to Safe Area

#### Header Title Label
- **Text**: "Audio Recorder"
- **Font**: System Bold 24
- **Color**: PrimaryText
- **Constraints**: Center Y, Leading 20

#### Cancel Button
- **Text**: "Cancel"
- **Font**: System Semibold 17
- **Color**: SecondaryText
- **Constraints**: Center Y, Trailing to Save Button -20

#### Save Button
- **Text**: "Save"
- **Font**: System Semibold 17
- **Color**: PrimaryBlue
- **Enabled**: False (initially)
- **Constraints**: Center Y, Trailing -20

## Recording Controls Section

### Recording Controls Container View
- **Height**: 120
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Constraints**: Top 20, Leading 20, Trailing -20

#### Record Button
- **Text**: "●" (record symbol)
- **Font**: System Semibold 16
- **Background**: SuccessGreen
- **Text Color**: White
- **Corner Radius**: 25
- **Size**: 50x50
- **Constraints**: Center X, Top 16

#### Pause Button
- **Text**: "⏸"
- **Font**: System Semibold 16
- **Background**: WarningOrange
- **Text Color**: White
- **Corner Radius**: 20
- **Size**: 40x40
- **Enabled**: False (initially)
- **Constraints**: Leading to Record Button -20, Center Y

#### Stop Button
- **Text**: "■"
- **Font**: System Semibold 16
- **Background**: ErrorRed
- **Text Color**: White
- **Corner Radius**: 20
- **Size**: 40x40
- **Enabled**: False (initially)
- **Constraints**: Trailing to Record Button 20, Center Y

#### Recording Status Label
- **Text**: "Ready to record"
- **Font**: System Semibold 16
- **Color**: SecondaryText
- **Alignment**: Center
- **Constraints**: Top to Record Button 8, Leading 16, Trailing -16

#### Recording Timer Label
- **Text**: "00:00"
- **Font**: Monospaced Digit System Bold 24
- **Color**: PrimaryText
- **Alignment**: Center
- **Constraints**: Top to Status Label 4, Leading 16, Trailing -16, Bottom -16

## Waveform Visualization Section

### Waveform Container View
- **Height**: 150
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Constraints**: Top 20, Leading 20, Trailing -20

#### Waveform View
- **Background**: BackgroundGray
- **Corner Radius**: 8
- **Constraints**: Top 16, Leading 16, Trailing -16, Bottom -16

#### Waveform Scroll View
- **Background**: Clear
- **Shows Horizontal Scroll Indicator**: False
- **Shows Vertical Scroll Indicator**: False
- **Constraints**: All edges to Waveform View

#### Waveform Content View
- **Background**: Clear
- **Constraints**: All edges to Scroll View

#### No Audio Label
- **Text**: "No audio recorded yet"
- **Font**: System Regular 16
- **Color**: SecondaryText
- **Alignment**: Center
- **Hidden**: False (initially)
- **Constraints**: Center X, Center Y

## Playback Controls Section

### Playback Controls Container View
- **Height**: 120
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Hidden**: Initially hidden
- **Constraints**: Top 20, Leading 20, Trailing -20

#### Play Button
- **Text**: "▶"
- **Font**: System Semibold 16
- **Background**: PrimaryBlue
- **Text Color**: White
- **Corner Radius**: 20
- **Size**: 40x40
- **Constraints**: Leading 16, Top 16

#### Pause Playback Button
- **Text**: "⏸"
- **Font**: System Semibold 16
- **Background**: WarningOrange
- **Text Color**: White
- **Corner Radius**: 20
- **Size**: 40x40
- **Enabled**: False (initially)
- **Constraints**: Leading to Play Button 12, Top 16

#### Stop Playback Button
- **Text**: "■"
- **Font**: System Semibold 16
- **Background**: ErrorRed
- **Text Color**: White
- **Corner Radius**: 20
- **Size**: 40x40
- **Constraints**: Leading to Pause Button 12, Top 16

#### Playback Progress Slider
- **Minimum Value**: 0
- **Maximum Value**: 1
- **Value**: 0
- **Constraints**: Top to Play Button 12, Leading 16, Trailing -16

#### Playback Time Label
- **Text**: "00:00"
- **Font**: Monospaced Digit System Regular 14
- **Color**: SecondaryText
- **Constraints**: Top to Progress Slider 8, Leading 16, Bottom -16

#### Total Time Label
- **Text**: "00:00"
- **Font**: Monospaced Digit System Regular 14
- **Color**: SecondaryText
- **Alignment**: Right
- **Constraints**: Top to Progress Slider 8, Trailing -16, Bottom -16

## Settings Section

### Settings Container View
- **Height**: 140
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Constraints**: Top 20, Leading 20, Trailing -20

#### Settings Title Label
- **Text**: "Recording Settings"
- **Font**: System Bold 20
- **Color**: PrimaryText
- **Constraints**: Top 16, Leading 16, Trailing -16

#### Quality Segmented Control
- **Segments**: 3 (Low, Medium, High)
- **Selected Segment**: 2 (High)
- **Constraints**: Top 12, Leading 16, Trailing -16

#### Sample Rate Label
- **Text**: "Sample Rate: 48000 Hz"
- **Font**: System Regular 14
- **Color**: SecondaryText
- **Constraints**: Top 8, Leading 16, Trailing -16

#### Bit Depth Label
- **Text**: "Bit Depth: 24 bit"
- **Font**: System Regular 14
- **Color**: SecondaryText
- **Constraints**: Top 4, Leading 16, Trailing -16

#### Format Label
- **Text**: "Format: AAC"
- **Font**: System Regular 14
- **Color**: SecondaryText
- **Constraints**: Top 4, Leading 16, Bottom -16

## Recordings List Section

### Recordings Container View
- **Height**: 300
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Constraints**: Top 20, Leading 20, Trailing -20, Bottom -20

#### Recordings Title Label
- **Text**: "Recent Recordings"
- **Font**: System Bold 20
- **Color**: PrimaryText
- **Constraints**: Top 16, Leading 16, Trailing -16

#### Recordings Table View
- **Background**: Clear
- **Separator Style**: None
- **Shows Vertical Scroll Indicator**: False
- **Constraints**: Top 8, Leading 16, Trailing -16, Bottom -16

#### No Recordings Label
- **Text**: "No recordings yet"
- **Font**: System Regular 16
- **Color**: SecondaryText
- **Alignment**: Center
- **Hidden**: Initially hidden
- **Constraints**: Center X, Center Y

## Loading Overlay

### Loading Overlay View
- **Background**: Black with 50% alpha
- **Hidden**: Initially hidden
- **Constraints**: All edges to Superview

#### Loading Activity Indicator
- **Style**: Large
- **Color**: White
- **Constraints**: Center X, Center Y -20

#### Loading Label
- **Text**: "Processing audio..."
- **Font**: System Semibold 16
- **Color**: White
- **Alignment**: Center
- **Constraints**: Center X, Top to Activity Indicator 16

## Custom Table View Cell

### SiivRecordingCell.xib
Create a new XIB file for the recording cell:

#### Container View
- **Background**: White
- **Corner Radius**: 12
- **Shadow**: 2pt offset, 4pt radius, 10% opacity
- **Constraints**: All edges with 8pt margins

#### Recording Icon Image View
- **Image**: System "waveform"
- **Tint**: PrimaryBlue
- **Size**: 24x24
- **Constraints**: Leading 16, Center Y

#### Recording Name Label
- **Font**: System Semibold 16
- **Color**: PrimaryText
- **Number of Lines**: 2
- **Constraints**: Top 12, Leading to Icon 12, Trailing to Play Button -12

#### Recording Duration Label
- **Font**: Monospaced Digit System Regular 14
- **Color**: SecondaryText
- **Constraints**: Top 4, Leading to Icon 12, Trailing -16

#### Recording Date Label
- **Font**: System Regular 12
- **Color**: SecondaryText
- **Constraints**: Top 4, Leading to Icon 12, Trailing -16

#### Recording Size Label
- **Font**: System Regular 12
- **Color**: SecondaryText
- **Constraints**: Top 4, Leading to Icon 12, Trailing -16, Bottom -12

#### Play Button
- **Text**: "▶"
- **Font**: System Semibold 14
- **Background**: PrimaryBlue
- **Text Color**: White
- **Corner Radius**: 16
- **Size**: 32x32
- **Constraints**: Center Y, Trailing to Delete Button -8

#### Delete Button
- **Text**: "🗑"
- **Font**: System Semibold 14
- **Background**: ErrorRed
- **Text Color**: White
- **Corner Radius**: 16
- **Size**: 32x32
- **Constraints**: Center Y, Trailing -16

## Color Assets

Make sure you have the following colors defined in your Assets.xcassets:

- **PrimaryText**: Dark text color (#1C1C1E)
- **SecondaryText**: Light text color (#8E8E93)
- **PrimaryBlue**: Main accent color (#007AFF)
- **SuccessGreen**: Success color (#34C759)
- **WarningOrange**: Warning color (#FF9500)
- **ErrorRed**: Error color (#FF3B30)
- **BackgroundGray**: Light background color (#F2F2F7)

## Constraints Summary

### Main Content Stack View
- **Top**: 0 to Safe Area
- **Leading**: 0 to Safe Area
- **Trailing**: 0 to Safe Area
- **Bottom**: 0 to Safe Area

### Scroll View
- **All edges**: 0 to Safe Area

### Container Views
- **Leading**: 20 to Safe Area
- **Trailing**: -20 to Safe Area
- **Top**: 20 to previous container (or Safe Area for first)

### Recording Controls
- **Button spacing**: 20pt between buttons
- **Timer alignment**: Center horizontally

### Waveform View
- **Height**: 100pt for waveform display
- **Scroll view**: Full width and height of container

### Playback Controls
- **Button spacing**: 12pt between buttons
- **Progress slider**: Full width with 16pt margins

### Table View
- **Height**: 200 (or use dynamic height with constraints)

## Testing the Setup

1. **Build and run** the app
2. **Navigate** to the AudioRecorderViewController
3. **Test microphone permission** - should request access
4. **Test recording controls** - record, pause, stop
5. **Verify waveform visualization** - should show real-time waveform
6. **Test playback controls** - play, pause, stop, progress slider
7. **Test settings** - quality selection should update display
8. **Test recordings list** - should show saved recordings
9. **Test file management** - delete recordings

## Common Issues and Solutions

### Microphone Permission
- Ensure microphone usage description is in Info.plist
- Test permission flow on device (not simulator)

### Audio Session Setup
- Check that audio session category is set correctly
- Verify audio session is activated

### Waveform Not Displaying
- Ensure waveform layer is added to view hierarchy
- Check that metering is enabled on audio recorder
- Verify waveform data is being collected

### Playback Not Working
- Check that audio player is properly initialized
- Verify file URL is valid and accessible
- Ensure audio session supports playback

### Recording Quality Issues
- Verify recording settings match selected quality
- Check that sample rate and bit depth are appropriate
- Test different quality levels

### Table View Not Updating
- Ensure recordings are being saved to correct location
- Check that loadRecordings() is called after save
- Verify file manager operations are successful

## Audio Session Configuration

Add the following to your Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone to record audio for language learning.</string>
```

## Required Frameworks

Make sure to import these frameworks in your project:
- AVFoundation
- Accelerate (for waveform processing) 
