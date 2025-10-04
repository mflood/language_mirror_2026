# KBS News Video and Transcript Extractor

An agentic Python script that extracts video, audio, and transcript from KBS news articles. The script automatically downloads videos, extracts audio, and processes transcripts using Claude AI for enhancement.

## Features

- 🎥 **Video Download**: Automatically downloads videos from KBS news articles using yt-dlp
- 🎵 **Audio Extraction**: Extracts audio from videos using FFmpeg
- 📝 **Transcript Processing**: Extracts and enhances transcripts using Claude AI
- 📊 **Metadata Generation**: Creates JSON/YAML metadata files with artifact information
- 🔧 **Robust Error Handling**: Handles various edge cases and provides detailed logging

## Prerequisites

### System Dependencies

- **Python 3.8+**
- **FFmpeg** (for audio/video processing)
- **yt-dlp** (for video downloading)

### Installation Instructions

#### macOS
```bash
# Install FFmpeg
brew install ffmpeg

# Install yt-dlp
pip install yt-dlp
```

#### Ubuntu/Debian
```bash
# Install FFmpeg
sudo apt update
sudo apt install ffmpeg

# Install yt-dlp
pip install yt-dlp
```

#### Windows
1. Download FFmpeg from https://ffmpeg.org/download.html
2. Add FFmpeg to your PATH
3. Install yt-dlp: `pip install yt-dlp`

## Setup

1. **Clone or download this repository**

2. **Run the setup script**:
   ```bash
   python setup.py
   ```

3. **Activate the virtual environment**:
   ```bash
   # macOS/Linux
   source venv/bin/activate
   
   # Windows
   venv\Scripts\activate
   ```

4. **Configure environment variables**:
   - Edit the `.env` file
   - Add your `ANTHROPIC_API_KEY` and `CLAUDE_MODEL`

## Usage

### Basic Usage

```bash
python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851"
```

### Advanced Usage

```bash
# Specify output directory
python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851" --output-dir my_output

# Use YAML format for metadata
python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851" --format yaml
```

### Programmatic Usage

```python
from kbs_extractor import KBSExtractor

# Create extractor instance
extractor = KBSExtractor(output_dir="my_output")

# Process a KBS news URL
metadata = extractor.process_url("https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851")

print(f"Title: {metadata['title']}")
print(f"Video: {metadata['artifacts']['video']['path']}")
print(f"Audio: {metadata['artifacts']['audio']['path']}")
print(f"Transcript: {metadata['artifacts']['transcript']['path']}")
```

## Output Structure

The script creates the following files in the output directory:

```
output/
├── article-title_video.mp4          # Downloaded video file
├── article-title_audio.mp3          # Extracted audio file
├── article-title_transcript.txt     # Raw transcript
├── article-title_enhanced_transcript.txt  # Claude-enhanced transcript
└── metadata.json                    # Metadata file
```

## Metadata Format

The metadata file contains:

```json
{
  "original_url": "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851",
  "title": "Article Title",
  "extraction_timestamp": "2024-01-01T12:00:00",
  "artifacts": {
    "video": {
      "path": "output/article-title_video.mp4",
      "size_bytes": 12345678
    },
    "audio": {
      "path": "output/article-title_audio.mp3",
      "size_bytes": 1234567
    },
    "transcript": {
      "path": "output/article-title_enhanced_transcript.txt",
      "size_bytes": 1234
    }
  }
}
```

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
ANTHROPIC_API_KEY=your_anthropic_api_key_here
CLAUDE_MODEL=claude-3-5-sonnet-20241022
```

### Customization

You can customize the extractor behavior by modifying the `KBSExtractor` class:

- **Video quality**: Change the `--format` parameter in `download_video()`
- **Audio settings**: Modify FFmpeg parameters in `extract_audio()`
- **Transcript enhancement**: Customize the Claude prompt in `enhance_transcript_with_claude()`

## Troubleshooting

### Common Issues

1. **"yt-dlp not found"**
   - Install yt-dlp: `pip install yt-dlp`
   - Ensure it's in your PATH

2. **"ffmpeg not found"**
   - Install FFmpeg for your operating system
   - Ensure it's in your PATH

3. **"No video URL found"**
   - The article might not have an embedded video
   - Check if the URL is a valid KBS news article

4. **"Claude API error"**
   - Verify your `ANTHROPIC_API_KEY` is correct
   - Check your API quota and billing

### Debug Mode

Enable debug logging by modifying the logging level in `kbs_extractor.py`:

```python
logging.basicConfig(level=logging.DEBUG)
```

## Limitations

- Only works with KBS news articles
- Requires internet connection for video download
- Video download depends on yt-dlp's extractor support
- Claude API usage requires valid API key and may incur costs

## Legal Notice

This tool is for educational and research purposes. Please respect:
- KBS's terms of service
- Copyright laws
- Rate limiting and fair use policies
- Local regulations regarding content downloading

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is provided as-is for educational purposes.
