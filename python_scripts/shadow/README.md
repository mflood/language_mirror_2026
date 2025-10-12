# Audio Shadow Practice

An ADHD-friendly FastAPI web application for audio shadow practice with slicing and loop functionality.

## Features

- 🎧 **Audio File Management**: Browse and select audio files from the `audio_files` folder
- ✂️ **Audio Slicing**: Create virtual slices with precise start/end times (no file modification)
- 🔄 **Loop Practice**: Practice specific slices with configurable loop counts
- ⚡ **Speed Control**: Adjust playback speed (0.5x to 1.5x)
- 💾 **JSON Storage**: Slice metadata stored in JSON file for persistence
- 🎯 **ADHD-Friendly UI**: Clean, focused design with clear visual feedback
- 📱 **Responsive Design**: Works on desktop and mobile devices

## Setup

1. **Activate the virtual environment**:
   ```bash
   source venv/bin/activate
   ```

2. **Install dependencies** (if not already installed):
   ```bash
   pip install -r requirements.txt
   ```

3. **Add audio files**:
   - Place your audio files (MP3, WAV, M4A, OGG) in the `audio_files/` folder
   - The app will automatically detect and list them

## Running the Application

### Option 1: Using the startup script (Recommended)
```bash
python run.py
```

### Option 2: Using uvicorn directly
```bash
uvicorn main:app --host 0.0.0.0 --port 8056 --reload
```

The application will be available at: **http://localhost:8056**

## How to Use

### 1. Select an Audio File
- On the main page, click on any audio file card to start practicing
- Each card shows the filename and duration

### 2. Create Audio Slices
- Use the main audio player to navigate to the section you want to practice
- Click "Create Slice" to immediately create a new slice at the current time
- The current slice's end time is automatically adjusted to the current position
- A new slice is created starting from the current time

### 3. Global Controls
- **Playback Speed**: Adjust the speed for all slices (0.5x to 1.5x)
- **Loop Count**: Set how many times each slice repeats (1-10)
- These settings apply to all slices globally

### 4. Practice Slices
- All created slices appear in the "Practice Slices" section
- Click "Practice" on any slice to play it in a loop
- The slice will repeat according to the global loop count setting
- Currently playing slices are highlighted in green

### 5. Manage Slices
- Delete unwanted slices using the trash icon
- Each slice shows its time range
- The first slice represents the full audio file

## File Structure

```
shadow/
├── audio_files/          # Place your audio files here
├── data/                # JSON files storing slice metadata and global settings
│   ├── audio_slices.json
│   └── global_settings.json
├── static/              # CSS and static assets
├── templates/           # HTML templates
├── venv/               # Python virtual environment
├── main.py             # FastAPI application
├── run.py              # Startup script
├── requirements.txt    # Python dependencies
├── .gitignore         # Git ignore rules
└── README.md          # This file
```

## Technical Details

- **Framework**: FastAPI with Jinja2 templates
- **Audio Processing**: Browser-native audio controls (no server-side processing)
- **Data Storage**: JSON file for slice metadata
- **Frontend**: Vanilla JavaScript with ADHD-friendly CSS
- **Port**: 8056
- **Audio Formats**: MP3, WAV, M4A, OGG

## ADHD-Friendly Design Features

- **High Contrast**: Clear visual hierarchy with distinct colors
- **Large Touch Targets**: Easy-to-click buttons and controls
- **Visual Feedback**: Immediate response to user actions
- **Reduced Cognitive Load**: Simple, focused interface
- **Clear Typography**: Easy-to-read fonts and sizing
- **Consistent Spacing**: Predictable layout patterns
- **Progress Indicators**: Visual cues for current state

## Development

The application uses auto-reload during development. Any changes to the Python files will automatically restart the server.

## Troubleshooting

- **Audio not playing**: Ensure your browser supports the audio format
- **Slices not creating**: Check that the audio file is valid and accessible
- **Slices not saving**: Check that the `data/` directory is writable
- **Port already in use**: Change the port in `run.py` or kill the process using port 8056

## License

This project is for educational and personal use.
