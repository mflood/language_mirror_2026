# Bundle Manifest Generator

A Python tool for generating bundle manifest JSON files from folders of audio files. The generated manifest is compatible with the LanguageMirror iOS app's "Install Bundle" feature and can be hosted on S3 as a static website.

## Features

- Scans a folder for audio files (mp3, m4a, wav, aac, flac, ogg, opus)
- Automatically detects audio file durations
- Generates bundle manifest JSON matching the LanguageMirror app structure
- Supports custom bundle/pack titles, author, cover images
- Constructs URLs for S3 static website hosting
- Natural sorting of files (e.g., track_01.mp3, track_02.mp3)

## Setup

### Prerequisites

- Python 3.7 or higher
- FFmpeg (required by soundfile for some audio formats)
  - macOS: `brew install ffmpeg`
  - Linux: `sudo apt-get install ffmpeg`
  - Windows: Download from https://ffmpeg.org/

### Installation

1. **Navigate to the generate_bundle directory:**
   ```bash
   cd generate_bundle
   ```

2. **Activate the virtual environment:**
   ```bash
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
   
   Note: The venv is already set up. If you need to recreate it:
   ```bash
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Verify installation:**
   ```bash
   python generate_bundle.py --help
   ```

## Usage

**Important:** Always activate the virtual environment before running the script:
```bash
cd generate_bundle
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Basic Usage

Generate a manifest from a folder of audio files:

```bash
python generate_bundle.py --input /path/to/audio/folder
```

This will:
- Scan the folder for audio files
- Generate `bundle.json` in the same folder
- Use the folder name as the bundle and pack title
- Use just filenames for audio URLs (relative paths)

### Advanced Usage

**With custom titles and S3 base URL:**
```bash
source venv/bin/activate  # Activate venv first
python generate_bundle.py \
  --input /path/to/audio/folder \
  --title "Korean Learning Pack 1" \
  --pack-title "Beginner Korean" \
  --base-url "https://my-bucket.s3.amazonaws.com/audio/" \
  --author "Language Learning Co." \
  --output manifest.json
```

**With cover image:**
```bash
python generate_bundle.py \
  --input /path/to/audio/folder \
  --cover-url "https://my-bucket.s3.amazonaws.com/images/cover.jpg" \
  --cover-filename "cover.jpg"
```

**Dry run to preview output:**
```bash
python generate_bundle.py --input /path/to/audio/folder --dry-run
```

### Command-line Arguments

| Argument | Short | Required | Description |
|----------|-------|----------|-------------|
| `--input` | `-i` | Yes | Folder path containing audio files |
| `--title` | `-t` | No | Bundle title (default: folder name) |
| `--pack-title` | | No | Pack title (default: folder name) |
| `--pack-id` | | No | Pack ID (default: auto-generated UUID) |
| `--base-url` | | No | Base URL for S3 bucket |
| `--author` | | No | Author name |
| `--cover-url` | | No | Cover image URL |
| `--cover-filename` | | No | Cover image filename |
| `--output` | `-o` | No | Output file path (default: `bundle.json` in input folder) |
| `--dry-run` | | No | Print manifest without saving |

## Output Format

The generated manifest follows the `BundleManifest` structure:

```json
{
  "title": "Bundle Title",
  "packs": [
    {
      "id": "optional-pack-id",
      "title": "Pack Title",
      "author": "Optional Author",
      "coverUrl": "https://.../cover.jpg",
      "coverFilename": "cover.jpg",
      "tracks": [
        {
          "id": null,
          "title": "Track Title",
          "url": "https://s3-bucket.com/audio/track.mp3",
          "filename": "track.mp3",
          "durationMs": 12345,
          "clips": null,
          "transcripts": null
        }
      ]
    }
  ]
}
```

## S3 Static Website Setup

### Step 1: Generate and Upload the Manifest

Generate your bundle manifest and upload to S3:

```bash
cd generate_bundle
source venv/bin/activate  # Activate venv first

python generate_bundle.py \
  --input ./my_audio_folder \
  --title "My Learning Pack" \
  --base-url "https://my-bucket.s3.amazonaws.com/audio/" \
  --publish-s3 "s3://my-bucket/audio/" \
  --output manifest.json
```

The `--publish-s3` flag will automatically upload the manifest and all audio files to S3.

### Step 2: Verify S3 Structure

After uploading with `--publish-s3`, your S3 bucket should have this structure:

```
s3://my-bucket/
├── manifest.json          # The generated manifest
└── audio/
    ├── track_01.mp3
    ├── track_02.mp3
    └── ...
```

Or if you want everything in the root:

```
s3://my-bucket/
├── manifest.json
├── track_01.mp3
├── track_02.mp3
└── ...
```

(If using the root structure, omit `--base-url` to use relative paths)

### Step 3: Configure S3 Static Website (if needed)

If you're not using the `--publish-s3` flag and uploading manually:

1. Enable static website hosting in your S3 bucket settings
2. Set index document to `manifest.json` (or another file)
3. Set error document (optional)
4. Make bucket public or configure bucket policy for public read access

### Step 4: Get the Manifest URL

Your manifest URL will be:
- **Website endpoint**: `http://my-bucket.s3-website-us-east-1.amazonaws.com/manifest.json`
- **Virtual hosted**: `https://my-bucket.s3.amazonaws.com/manifest.json` (if bucket name is DNS-compliant)

### Step 5: Use in LanguageMirror App

In the LanguageMirror app:
1. Go to Import screen
2. Tap "Install Bundle"
3. Enter the manifest URL
4. The app will download all audio files and import tracks

## Examples

### Example 1: Simple Bundle

```bash
# Folder structure:
# my_pack/
#   ├── lesson_01.mp3
#   ├── lesson_02.mp3
#   └── lesson_03.mp3

python generate_bundle.py --input ./my_pack
# Creates: my_pack/bundle.json
```

### Example 2: S3-Hosted Bundle

```bash
python generate_bundle.py \
  --input ./korean_lessons \
  --title "Korean Beginner Pack" \
  --pack-title "Korean Basics" \
  --base-url "https://language-mirror-packs.s3.amazonaws.com/korean_lessons/" \
  --author "Korean Learning Academy" \
  --output korean_manifest.json
```

Then upload:
- `korean_manifest.json` to S3 root or a known location
- Audio files to `s3://language-mirror-packs/korean_lessons/`

### Example 3: With Cover Image

```bash
python generate_bundle.py \
  --input ./spanish_lessons \
  --cover-url "https://my-bucket.s3.amazonaws.com/covers/spanish.jpg" \
  --cover-filename "spanish.jpg"
```

## Troubleshooting

**"soundfile is required" error**
- Install dependencies: `pip install -r requirements.txt`

**"Could not get duration" warnings**
- Ensure FFmpeg is installed
- Some audio formats may require additional codecs
- The manifest will still be generated with durationMs: 0

**"No audio files found" error**
- Check that the folder path is correct
- Ensure files have supported extensions (.mp3, .m4a, .wav, etc.)
- Check file permissions

**URL issues with S3**
- Make sure `--base-url` matches your S3 bucket structure
- URLs must be accessible (bucket must be public or have proper CORS/access policies)
- Test the manifest URL in a browser before using in the app

## Notes

- Track titles are automatically generated from filenames (extension removed, underscores/hyphens replaced with spaces)
- Files are sorted naturally (track_01.mp3 comes before track_02.mp3)
- If duration cannot be determined, it will be set to 0
- The manifest uses `null` for optional fields (clips, transcripts) which can be added later

