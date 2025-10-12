# Practice Page UI Design & Behavior

## Overview
The practice page is designed to be ADHD-friendly, intuitive, and fun for audio shadow practice. It provides a streamlined interface for creating practice sections and playing them with customizable loops and speed controls.

## Layout Structure

### Header Section
- **Back Button**: Returns to the audio file selection page
- **Title**: "🎧 Shadow Practice" with the filename as subtitle
- **Clean, minimal design** to reduce cognitive load

### Main Audio Player Section
- **Audio Player**: Standard HTML5 audio controls for the full audio file
- **Time Display**: Shows current time and total duration in MM:SS format
- **Mark Practice Point Button**: 
  - Text: "📍 Mark Practice Point"
  - Creates a new practice section at the current audio position
  - Uses gradient styling (purple to pink) with hover animations

### Global Controls Section
- **Speed Control**: 
  - Label: "🎚️ Speed"
  - Dropdown with options: 0.5x (Slow), 0.75x, 1.0x (Normal), 1.25x, 1.5x (Fast)
  - Affects playback speed for all practice sections
- **Repeat Control**:
  - Label: "🔄 Repeat Times"
  - Slider from 1-10 with live display of current value
  - Determines how many times each section plays before moving to the next

### Practice Sections List
- **Header**: "🎯 Your Practice Sections"
- **Subtitle**: "Click any section to practice it with repeats!"
- **Empty State**: Encouraging message with emoji when no sections exist
- **Section Cards**: Each practice section is displayed as a card with:
  - **Title**: "🎵 Full Audio" for the initial section, "📍 Section [ID]" for others
  - **Time Range**: Shows start time, end time, and duration
  - **Practice Button**: "🎯 Practice This!" with gradient styling (green to cyan)
  - **Delete Button**: Trash icon for removing sections

## Behavior & Interactions

### Creating Practice Sections
1. **User plays audio** using the main audio player
2. **User clicks "Mark Practice Point"** at desired time
3. **System automatically**:
   - Adjusts the end time of the currently playing section to the current time
   - Creates a new section starting from the current time
   - Sorts all sections chronologically
   - Updates the UI to show the new section

### Playing Practice Sections
1. **User clicks "🎯 Practice This!"** on any section
2. **System**:
   - Stops any currently playing section
   - Loads global settings (speed and repeat count)
   - Sets up the audio element for section playback
   - Waits for audio to be ready (using `canplaythrough` event)
   - Sets `currentTime` to the section's start time
   - Begins playback

### Section Playback Logic
- **Starts from beginning** of audio file but monitors time
- **Waits until reaching start time** before considering the section "active"
- **Plays through the section** until reaching the end time
- **Repeats the section** the specified number of times
- **Automatically proceeds** to the next section after all repeats are complete
- **Stops cleanly** when all sections are finished

### Auto-Progression
- **After completing all repeats** of a section, automatically moves to the next section
- **Maintains chronological order** (always plays sections in start time order)
- **Provides console feedback** about progression
- **Handles edge cases** gracefully (no more sections, errors, etc.)

### Deleting Sections
1. **User clicks delete button** (trash icon)
2. **Confirmation dialog**: "Delete this practice section? You can always recreate it!"
3. **If confirmed**:
   - Extends the previous section's end time to fill the gap
   - Removes the deleted section
   - Updates the UI
   - Maintains continuous timeline with no gaps

## Visual Design Features

### ADHD-Friendly Elements
- **High contrast colors** for better readability
- **Clear visual hierarchy** with proper spacing and typography
- **Immediate visual feedback** on all interactions
- **Consistent button styling** with gradients and animations
- **Emojis throughout** for visual interest and quick recognition

### Animations & Feedback
- **Button hover effects**: Scale up, lift, and enhanced shadows
- **Active button states**: Scale down on click for tactile feedback
- **Playing section indicator**: Pulsing glow animation with green accent
- **Smooth transitions** on all interactive elements

### Color Scheme
- **Primary**: Purple gradient for main actions
- **Success**: Green gradient for play buttons
- **Fun accents**: Pink and cyan for visual interest
- **Neutral backgrounds**: Light grays and whites for content areas

## Technical Implementation

### Audio Handling
- **Uses HTML5 Audio API** with proper ready state checking
- **Implements `canplaythrough` event** to ensure audio is ready before seeking
- **Monitors `timeupdate` events** for precise section timing
- **Handles race conditions** with proper event listener management

### State Management
- **Global settings** stored in JSON file and synced across sessions
- **Section metadata** stored as JSON with start/end times
- **Real-time UI updates** when sections are created, deleted, or played
- **Persistent storage** of all practice data

### Error Handling
- **Graceful fallbacks** for audio loading issues
- **User-friendly error messages** with encouraging tone
- **Automatic cleanup** of event listeners and audio state
- **Robust handling** of edge cases and network issues

## User Experience Flow

1. **Load page** → See audio player and empty sections list
2. **Play audio** → Listen to content while deciding on practice points
3. **Mark points** → Click button at desired times to create sections
4. **Practice sections** → Click any section to practice with repeats
5. **Adjust settings** → Change speed and repeat count as needed
6. **Auto-progression** → System automatically moves through all sections
7. **Manage sections** → Delete unwanted sections, create new ones

This design prioritizes simplicity, immediate feedback, and visual clarity to create an engaging and effective practice environment for language learning.
