# DownloadFromURLViewController - Text Mockup

## Screen Layout

```
┌─────────────────────────────────────────────────────────┐
│ Status Bar (9:41)                    Battery: 100%     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Header Container                                │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ ← Download From URL                          │ │   │
│  │ │ Download audio files from web URLs           │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ URL Input Section                               │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ 🌐 Enter URL                                 │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ https://example.com/audio/lesson1.mp3  │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ │ [Paste] [Clear] [Validate URL]              │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ URL Validation                                  │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ ✅ Valid URL                                │ │   │
│  │ │ File: lesson1.mp3                           │ │   │
│  │ │ Size: 5.2 MB                                │ │   │
│  │ │ Format: MP3                                 │ │   │
│  │ │ Duration: 12:45                             │ │   │
│  │ │ [Download] [Preview]                        │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Download Progress                               │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ ⏳ Downloading lesson1.mp3...               │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ ██████████████████████████████████████ │ │ │   │
│  │ │ │ Progress: 75% (3.9 MB of 5.2 MB)       │ │ │   │
│  │ │ │ Speed: 1.2 MB/s • Time: ~1 minute left  │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ │ [Pause] [Cancel]                            │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Download Settings                               │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ ⚙️ Download Settings                        │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ Quality: [High] [Medium] [Low]          │ │ │   │
│  │ │ │ Auto-convert: [On] [Off]                │ │ │   │
│  │ │ │ Save to: [Audio Files] [Custom Folder]  │ │ │   │
│  │ │ │ Category: [Downloaded] [Other]           │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Recent Downloads                                 │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ 📥 Recent Downloads (3)                     │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ 🎵 korean_lesson_2.mp3                  │ │ │   │
│  │ │ │    Downloaded: 2 hours ago              │ │ │   │
│  │ │ │    6.8 MB • 15:32 • MP3                 │ │ │   │
│  │ │ │    [Play] [Delete] [Re-download]        │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ 🎵 chinese_conversation.m4a             │ │ │   │
│  │ │ │    Downloaded: 1 day ago                │ │ │   │
│  │ │ │    12.3 MB • 28:15 • M4A                │ │ │   │
│  │ │ │    [Play] [Delete] [Re-download]        │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ │ ┌─────────────────────────────────────────┐ │ │   │
│  │ │ │ 🎵 japanese_grammar.mp3                 │ │ │   │
│  │ │ │    Downloaded: 3 days ago               │ │ │   │
│  │ │ │    8.5 MB • 18:42 • MP3                 │ │ │   │
│  │ │ │    [Play] [Delete] [Re-download]        │ │ │   │
│  │ │ └─────────────────────────────────────────┘ │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Download Actions                                 │   │
│  │ ┌─────────────────────────────────────────────┐ │   │
│  │ │ [Download All] [Clear History] [Settings]   │ │   │
│  │ └─────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ Tab Bar                                                  │
│ 🏠 Home  🎵 Audio  ✂️ Soundbites  📚 Learn            │
│ ─────────────────────────────────────────────────────── │
└─────────────────────────────────────────────────────────┘
```

## Design Elements

### Header Section
- **Background**: White with rounded corners (12pt radius)
- **Shadow**: Subtle drop shadow for depth
- **Back Button**: Left arrow for navigation
- **Title**: "Download From URL" in bold 20pt font
- **Subtitle**: Descriptive text in regular 16pt

### URL Input Section
- **Background**: White with rounded corners
- **Header**: "Enter URL" with globe icon
- **URL Field**: Editable text field with placeholder
- **Action Buttons**: Paste, clear, validate URL
- **Styling**: Clean, focused input design

### URL Validation Section
- **Background**: White with rounded corners
- **Status Icon**: Checkmark for valid URLs
- **File Info**: Name, size, format, duration
- **Action Buttons**: Download and preview
- **Styling**: Informative validation display

### Download Progress Section
- **Background**: White with rounded corners
- **Header**: Download status with filename
- **Progress Bar**: Visual progress indicator
- **Status Text**: Progress percentage, speed, time remaining
- **Control Buttons**: Pause and cancel options
- **Styling**: Clear progress visualization

### Download Settings Section
- **Background**: White with rounded corners
- **Header**: "Download Settings" with gear icon
- **Quality Options**: High, medium, low quality
- **Auto-convert**: Toggle for format conversion
- **Save Location**: Audio Files or custom folder
- **Category**: Downloaded or other category
- **Styling**: Organized settings layout

### Recent Downloads Section
- **Background**: White with rounded corners
- **Header**: "Recent Downloads" with count
- **Download Cards**: Individual download items
- **Metadata**: Download date, size, duration, format
- **Action Buttons**: Play, delete, re-download
- **Styling**: Timeline layout with file info

### Download Actions Section
- **Background**: White with rounded corners
- **Action Buttons**: Download all, clear history, settings
- **Layout**: Three equal-width buttons
- **Styling**: Primary action button highlighted

## Visual States

### Normal State
- **Background**: White cards on light gray background
- **Buttons**: Blue primary buttons, gray secondary buttons
- **Text**: Black primary text, gray secondary text
- **Icons**: Colored emojis for visual appeal

### URL Validation State
- **Valid URL**: Green checkmark and file info
- **Invalid URL**: Red X and error message
- **Loading**: Spinning indicator during validation
- **Action Buttons**: Active download and preview options

### Downloading State
- **Progress Bar**: Animated progress visualization
- **Status Updates**: Real-time download progress
- **Speed Display**: Current download speed
- **Time Estimate**: Remaining download time
- **Control Buttons**: Pause and cancel available

### Download Complete State
- **Success Indicator**: Green checkmark and completion message
- **File Info**: Final file details
- **Action Buttons**: Play, delete, re-download options
- **Visual Feedback**: Success state highlighting

### Error State
- **Error Message**: Red text with error description
- **Retry Button**: Action button for failed downloads
- **Help Text**: Guidance for resolving issues
- **Visual Indicators**: Warning icons and colors

## Color Scheme

- **Primary Blue**: #007AFF (buttons, accents, progress)
- **Primary Text**: #000000 (main text)
- **Secondary Text**: #8E8E93 (metadata, labels)
- **Background Gray**: #F2F2F7 (screen background)
- **Success Green**: #34C759 (success states, valid URLs)
- **Error Red**: #FF3B30 (error states, invalid URLs)
- **Warning Orange**: #FF9500 (warning states, paused)
- **Progress Blue**: #007AFF with gradient (progress bars)

## Typography

- **Header Title**: SF Pro Display 20pt Bold
- **Subtitle**: SF Pro Display 16pt Regular
- **Section Headers**: SF Pro Display 18pt Semibold
- **URL Text**: SF Pro Display 16pt Regular
- **File Names**: SF Pro Display 16pt Semibold
- **Metadata**: SF Pro Display 14pt Regular
- **Button Text**: SF Pro Display 16pt Semibold
- **Progress Text**: SF Pro Display 14pt Regular

## Spacing & Layout

- **Card Margins**: 8pt between cards
- **Content Padding**: 16pt from screen edges
- **Card Padding**: 16pt internal spacing
- **Button Spacing**: 8pt between buttons
- **Section Spacing**: 12pt between sections
- **Download Card Height**: 100pt for download items
- **URL Field Height**: 44pt for input field

## Interactive Elements

### URL Input
- **Text Field**: Editable URL input with validation
- **Paste Button**: Paste from clipboard
- **Clear Button**: Clear URL field
- **Validate Button**: Check URL validity

### URL Validation
- **Validation Check**: Verify URL and file format
- **File Info Display**: Show file details
- **Preview Option**: Preview audio before download
- **Download Action**: Start download process

### Download Progress
- **Progress Tracking**: Real-time download progress
- **Speed Monitoring**: Current download speed
- **Time Estimation**: Remaining download time
- **Pause/Resume**: Control download process
- **Cancel Option**: Stop download operation

### Download Settings
- **Quality Selection**: Choose download quality
- **Format Conversion**: Auto-convert audio formats
- **Save Location**: Choose download folder
- **Category Assignment**: Set file category

### Recent Downloads
- **Download History**: List of recent downloads
- **File Playback**: Play downloaded files
- **File Management**: Delete or re-download files
- **Metadata Display**: File information and dates

## User Flow

1. **Initial Load**: User sees URL input field
2. **URL Entry**: User enters or pastes URL
3. **URL Validation**: System validates URL and file
4. **File Preview**: User previews audio file
5. **Settings**: User configures download settings
6. **Download**: User initiates download process
7. **Progress**: User monitors download progress
8. **Completion**: File appears in recent downloads

## Download States

### No URL Entered
```
┌─────────────────────────────────────────────────────────┐
│ URL Input Section                                       │
│ ┌─────────────────────────────────────────────────┐   │
│ │ 🌐 Enter URL                                     │   │
│ │ ┌─────────────────────────────────────────────┐ │   │
│ │ │ Enter audio file URL here...                │ │   │
│ │ └─────────────────────────────────────────────┘ │   │
│ │ [Paste] [Clear] [Validate URL]                  │   │
│ └─────────────────────────────────────────────┘   │   │
└─────────────────────────────────────────────────────────┘
```

### Invalid URL
```
┌─────────────────────────────────────────────────────────┐
│ URL Validation                                          │
│ ┌─────────────────────────────────────────────────┐   │
│ │ ❌ Invalid URL                                  │   │
│ │ Please enter a valid audio file URL.            │   │
│ │ Supported formats: MP3, M4A, WAV, AAC          │   │
│ │ [Try Again] [Help]                              │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Download Complete
```
┌─────────────────────────────────────────────────────────┐
│ Download Complete                                       │
│ ┌─────────────────────────────────────────────────┐   │
│ │ ✅ Download Complete!                            │   │
│ │ lesson1.mp3 downloaded successfully             │   │
│ │ 5.2 MB • 12:45 • MP3                            │   │
│ │ [Play] [Delete] [Download Another]              │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### No Recent Downloads
```
┌─────────────────────────────────────────────────────────┐
│ Recent Downloads                                        │
│ ┌─────────────────────────────────────────────────┐   │
│ │ 📥 Recent Downloads (0)                          │   │
│ │ No recent downloads. Start downloading files!   │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Supported URL Types

### Direct Audio Files
- **MP3**: http://example.com/audio.mp3
- **M4A**: http://example.com/audio.m4a
- **WAV**: http://example.com/audio.wav
- **AAC**: http://example.com/audio.aac

### Audio Streaming
- **Podcast URLs**: RSS feed audio links
- **Streaming Services**: Direct stream URLs
- **Cloud Storage**: Dropbox, Google Drive links
- **Audio Platforms**: SoundCloud, etc.

### File Size Limits
- **Individual Files**: Up to 500MB per file
- **Download Queue**: Up to 10 files simultaneously
- **Storage Warning**: Alert when approaching limits
- **Auto-compression**: Compress large files

## Performance Considerations

- **URL Validation**: Fast URL checking and format detection
- **Download Management**: Efficient download queue handling
- **Progress Updates**: Real-time progress monitoring
- **Error Handling**: Robust error recovery and retry logic
- **Storage Management**: Smart file organization
- **Network Optimization**: Efficient bandwidth usage 