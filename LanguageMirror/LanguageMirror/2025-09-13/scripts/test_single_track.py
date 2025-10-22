#!/usr/bin/env python3
"""
Test script for processing a single track

Usage: python test_single_track.py [track_number]
Example: python test_single_track.py 1
"""

import os
import json
import sys
from pathlib import Path
import uuid

import whisper
from openai import OpenAI
import soundfile as sf
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GPT_MODEL = "gpt-4o-mini"  # Cost-effective model ($0.15 per 1M input tokens)
WHISPER_MODEL = "base"

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
AUDIO_DIR = PROJECT_ROOT / "Resources" / "audio_files" / "culture_1"
PACK_JSON_INPUT = PROJECT_ROOT / "Resources" / "embedded_packs" / "pack_culture_1.json"


def get_audio_duration_ms(audio_path: Path) -> int:
    """Get audio file duration in milliseconds"""
    info = sf.info(str(audio_path))
    return int(info.duration * 1000)


def transcribe_audio(model, audio_path: Path):
    """Transcribe audio file with Whisper"""
    print(f"Transcribing: {audio_path.name}")
    
    result = model.transcribe(
        str(audio_path),
        language="ko",
        word_timestamps=True,
        verbose=False
    )
    
    return result


def analyze_with_gpt(client, model, transcription_result, audio_duration_ms):
    """Analyze transcription with GPT"""
    
    # Prepare segments data
    segments_data = []
    for segment in transcription_result.get("segments", []):
        segment_info = {
            "start": segment["start"],
            "end": segment["end"],
            "text": segment["text"].strip()
        }
        
        if "words" in segment:
            segment_info["words"] = [
                {
                    "word": w.get("word", ""),
                    "start": w.get("start", 0),
                    "end": w.get("end", 0)
                }
                for w in segment["words"]
            ]
        
        segments_data.append(segment_info)
    
    segments_json = json.dumps(segments_data, ensure_ascii=False, indent=2)
    
    prompt = f"""You are analyzing Korean language audio transcription to create practice clips for language learning.

Audio Duration: {audio_duration_ms} ms

Transcription segments with timestamps (in seconds):
{segments_json}

Your task:
1. Identify sentence boundaries in the Korean text
2. Detect any noise/music sections (typically at start/end with no speech or very short duration)
3. Identify speakers based on speech patterns and timing gaps (label as "Speaker 1", "Speaker 2", "Male", "Female", etc.)
4. Create practice clips:
   - One "drill" clip for EACH sentence/transcript span
   - "skip" clips for any music/noise sections at the beginning or end
5. IMPORTANT: Every transcript span should have a corresponding "drill" clip with matching timestamps

Output Format (JSON):
{{
  "transcripts": [
    {{
      "startMs": <start time in milliseconds>,
      "endMs": <end time in milliseconds>,
      "text": "<Korean text>",
      "speaker": "<speaker label>"
    }}
  ],
  "clips": [
    {{
      "startMs": <start time in milliseconds>,
      "endMs": <end time in milliseconds>,
      "kind": "drill" or "skip",
      "title": "<brief description, e.g., 'Sentence 1' or 'Intro music'>"
    }}
  ]
}}

Guidelines:
- Convert all times from seconds to milliseconds
- Each sentence should have its own transcript span
- Each transcript span MUST have a corresponding "drill" clip with the same timestamps
- If you detect music/noise at the beginning or end, add "skip" clips for those BEFORE/AFTER the drill clips
- Transcripts should be chronological and non-overlapping
- Clips should be chronological and non-overlapping  
- Clips array should include: [skip clips for intro music] + [drill clip for each sentence] + [skip clips for outro music]
- Use natural sentence boundaries in Korean (often ending with 다, 요, 까, etc.)
- Keep speaker labels consistent throughout
- Clip titles should be descriptive: "Sentence 1", "Sentence 2", etc. for drill clips

Respond ONLY with the JSON structure, no additional text."""
    
    print("Sending to GPT for analysis...")
    
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are an expert in Korean language transcription analysis."},
            {"role": "user", "content": prompt}
        ],
        temperature=0.3,
        max_tokens=4096
    )
    
    # Parse response
    response_text = response.choices[0].message.content.strip()
    
    # Clean up markdown formatting if present
    if response_text.startswith("```json"):
        response_text = response_text[7:]
    if response_text.startswith("```"):
        response_text = response_text[3:]
    if response_text.endswith("```"):
        response_text = response_text[:-3]
    response_text = response_text.strip()
    
    return json.loads(response_text)


def main():
    if len(sys.argv) > 1:
        track_num = int(sys.argv[1])
    else:
        track_num = 1
    
    print("=" * 60)
    print(f"Testing Single Track: Culture 1-{track_num:02d}")
    print("=" * 60)
    print()
    
    if not OPENAI_API_KEY:
        print("Error: OPENAI_API_KEY not set")
        sys.exit(1)
    
    # Load pack to get track info
    with open(PACK_JSON_INPUT, 'r', encoding='utf-8') as f:
        pack_data = json.load(f)
    
    if track_num < 1 or track_num > len(pack_data["tracks"]):
        print(f"Error: Track number must be between 1 and {len(pack_data['tracks'])}")
        sys.exit(1)
    
    track = pack_data["tracks"][track_num - 1]
    audio_path = AUDIO_DIR / track["filename"]
    
    if not audio_path.exists():
        print(f"Error: Audio file not found: {audio_path}")
        sys.exit(1)
    
    print(f"Track: {track['title']}")
    print(f"File: {track['filename']}")
    print()
    
    # Load Whisper model
    print(f"Loading Whisper model: {WHISPER_MODEL}")
    whisper_model = whisper.load_model(WHISPER_MODEL)
    print("✓ Whisper model loaded")
    print()
    
    # Get audio duration
    duration_ms = get_audio_duration_ms(audio_path)
    print(f"Audio duration: {duration_ms / 1000:.2f} seconds")
    print()
    
    # Transcribe
    transcription = transcribe_audio(whisper_model, audio_path)
    print(f"✓ Transcription complete")
    print(f"  Detected {len(transcription.get('segments', []))} segments")
    print()
    
    # Show raw transcription
    print("Raw Transcription:")
    print("-" * 60)
    for i, seg in enumerate(transcription.get("segments", []), 1):
        print(f"{i}. [{seg['start']:.2f}s - {seg['end']:.2f}s] {seg['text'].strip()}")
    print()
    
    # Analyze with GPT
    client = OpenAI(api_key=OPENAI_API_KEY)
    analysis = analyze_with_gpt(client, GPT_MODEL, transcription, duration_ms)
    
    print("✓ GPT analysis complete")
    print()
    
    # Show analysis results
    print("Transcripts:")
    print("-" * 60)
    for i, t in enumerate(analysis.get("transcripts", []), 1):
        speaker = f" [{t.get('speaker', 'Unknown')}]" if t.get('speaker') else ""
        print(f"{i}. [{t['startMs']}ms - {t['endMs']}ms]{speaker} {t['text']}")
    print()
    
    print("Clips:")
    print("-" * 60)
    for i, c in enumerate(analysis.get("clips", []), 1):
        print(f"{i}. [{c['startMs']}ms - {c['endMs']}ms] {c['kind']}: {c.get('title', 'Untitled')}")
    print()
    
    # Save results to file
    output_file = SCRIPT_DIR / f"test_output_track_{track_num:02d}.json"
    output_data = {
        "track": track,
        "audio_duration_ms": duration_ms,
        "whisper_result": {
            "segments": transcription.get("segments", [])
        },
        "claude_analysis": analysis
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
    
    print(f"✓ Results saved to: {output_file}")
    print()
    print("=" * 60)
    print("Test Complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()

