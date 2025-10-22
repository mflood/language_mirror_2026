# Korean Audio Transcription Scripts

This directory contains Python scripts for generating transcripts and practice sets from Korean audio files.

## Setup

1. **Create and activate Python virtual environment:**
   ```bash
   cd scripts
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure API keys:**
   - Copy `.env.example` to `.env`
   - Add your OpenAI API key to the `.env` file
   - **Important:** Ensure your OpenAI account has sufficient credits

4. **Install FFmpeg (required by Whisper):**
   - macOS: `brew install ffmpeg`
   - Linux: `sudo apt-get install ffmpeg`
   - Windows: Download from https://ffmpeg.org/

## Scripts

### generate_culture_1_transcripts.py

Processes all audio files in the Korean Culture 1 pack to generate:
- Korean transcripts with word-level timestamps using Whisper
- Speaker diarization using GPT-4o-mini
- Practice clips organized by sentence
- Enhanced pack JSON file with all metadata

**Usage:**
```bash
# Make sure venv is activated first
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Run the full script (processes all 40 tracks)
python generate_culture_1_transcripts.py

# Or test with a single track first
python test_single_track.py 1
```

**What it does:**
1. Loads all 40 audio files from `Resources/audio_files/culture_1/`
2. Transcribes each file using Whisper (local, no API key needed)
3. Analyzes transcriptions with OpenAI GPT API to:
   - Identify sentence boundaries
   - Detect speakers (male/female)
   - Identify noise/music sections
   - Generate practice clips
4. Outputs enhanced pack to `Resources/embedded_packs/pack_culture_1_enhanced.json`

**Configuration:**
- `WHISPER_MODEL`: Model size (tiny, base, small, medium, large)
  - `base` is default - good balance of speed and accuracy
  - Larger models are more accurate but slower
- `GPT_MODEL`: Currently set to gpt-4o-mini for cost efficiency ($0.15 per 1M input tokens)

**Processing Time:**
- Approximately 2-5 minutes per track (depends on audio length and Whisper model)
- Total time for 40 tracks: ~2-3 hours

**Cost Estimate:**
- Whisper: Free (runs locally)
- OpenAI GPT API: ~$0.50-1.50 for all 40 tracks (using gpt-4o-mini)

## Output Format

The enhanced pack JSON follows the Swift models in `Models.swift`:

```json
{
  "id": "urn:pack-app:com.six.wands.pack.culture.1",
  "title": "Demo Pack - Korean Culture 1",
  "tracks": [
    {
      "title": "Culture 1-01",
      "filename": "culture_1_01.mp3",
      "transcripts": [
        {
          "startMs": 1000,
          "endMs": 3500,
          "text": "안녕하세요",
          "speaker": "Speaker 1",
          "languageCode": "ko-KR"
        }
      ],
      "practiceSets": [
        {
          "id": "uuid",
          "trackId": "track-id",
          "displayOrder": 0,
          "title": "Practice Set",
          "clips": [
            {
              "id": "uuid",
              "startMs": 1000,
              "endMs": 3500,
              "kind": "drill",
              "title": "Sentence 1",
              "repeats": null,
              "startSpeed": null,
              "endSpeed": null,
              "languageCode": "ko-KR"
            }
          ]
        }
      ]
    }
  ]
}
```

## Troubleshooting

**"OPENAI_API_KEY environment variable not set"**
- Make sure you've created a `.env` file with your API key
- Ensure the venv is activated when running the script

**"Insufficient credits" or API errors**
- Your OpenAI API account needs sufficient credits
- Visit https://platform.openai.com/settings/organization/billing to add credits
- Each track costs approximately $0.01-$0.04 to process with gpt-4o-mini

**"Audio file not found"**
- Verify the audio files are in `Resources/audio_files/culture_1/`
- Check that filenames match those in `pack_culture_1.json`

**Whisper model download issues**
- Models download automatically on first run
- Requires ~140MB for base model, ~1.5GB for large model
- Downloads are stored in `~/.cache/whisper/`

**Out of memory errors**
- Try a smaller Whisper model (tiny or base)
- Process fewer tracks at a time

**OpenAI API errors**
- Check your API key is valid
- Verify you have API credits
- Rate limits: gpt-4o-mini allows 500 requests/minute on paid plans

**Python 3.13 compatibility**
- Script is tested and working with Python 3.13
- Uses soundfile instead of pydub for better compatibility

