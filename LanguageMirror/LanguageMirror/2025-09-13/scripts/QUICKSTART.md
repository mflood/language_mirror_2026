# Quick Start Guide

## TL;DR

Process all 40 Korean Culture 1 audio tracks to create transcripts and practice clips:

```bash
cd scripts

# One-time setup
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Add your Anthropic API key to .env file (already created)

# Test with one track first
python test_single_track.py 1

# Process all 40 tracks (takes ~2-3 hours)
python generate_culture_1_transcripts.py
```

Output will be in: `Resources/embedded_packs/pack_culture_1_enhanced.json`

## Important Notes

1. **API Credits Required**: Your Anthropic account needs ~$1-3 in credits to process all tracks
   - Currently showing: "Your credit balance is too low"
   - Add credits at: https://console.anthropic.com/

2. **Processing Time**: 
   - Whisper (local): ~2-5 min per track (FREE)
   - Claude API: ~5-10 sec per track (~$0.05 each)
   - Total: ~2-3 hours for 40 tracks

3. **First Run**: Whisper will download ~140MB model to `~/.cache/whisper/`

## What You Get

For each track:
- **Korean transcripts** with timestamps and speaker labels
- **Practice clips** - one per sentence
- **Skip clips** for noise/music sections
- All in JSON format matching your Swift models

## Example Output

```json
{
  "transcripts": [
    {
      "startMs": 53720,
      "endMs": 54920,
      "text": "안녕하십니까?",
      "speaker": "Speaker 1",
      "languageCode": "ko-KR"
    }
  ],
  "clips": [
    {
      "id": "uuid",
      "startMs": 53720,
      "endMs": 54920,
      "kind": "drill",
      "title": "Sentence 1"
    }
  ]
}
```

## Troubleshooting

**Low credit balance error?**
→ Add credits at https://console.anthropic.com/

**Can't find audio files?**
→ Should be in `Resources/audio_files/culture_1/`

**Want to test first?**
→ Run `python test_single_track.py 1` to process just one track

See `README.md` for detailed documentation.

