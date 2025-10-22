#!/usr/bin/env python3
"""
Korean Audio Transcription & Practice Set Generator

Processes all audio files in the Korean Culture 1 pack to generate:
- Transcripts with word-level timestamps using Whisper
- Speaker diarization and sentence boundaries using Claude
- Practice clips organized by sentence
"""

import os
import json
import sys
from pathlib import Path
from typing import List, Dict, Any
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
WHISPER_MODEL = "base"  # Options: tiny, base, small, medium, large

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
AUDIO_DIR = PROJECT_ROOT / "Resources" / "audio_files" / "culture_1"
PACK_JSON_INPUT = PROJECT_ROOT / "Resources" / "embedded_packs" / "pack_culture_1.json"
PACK_JSON_OUTPUT = PROJECT_ROOT / "Resources" / "embedded_packs" / "pack_culture_1_enhanced.json"


class TranscriptionProcessor:
    """Handles audio transcription using Whisper"""
    
    def __init__(self, model_name: str = "base"):
        print(f"Loading Whisper model: {model_name}...")
        self.model = whisper.load_model(model_name)
        print("Whisper model loaded successfully")
    
    def transcribe_audio(self, audio_path: Path) -> Dict[str, Any]:
        """
        Transcribe audio file with word-level timestamps
        
        Returns:
            Dictionary with segments and word-level timings
        """
        print(f"Transcribing: {audio_path.name}")
        
        result = self.model.transcribe(
            str(audio_path),
            language="ko",
            word_timestamps=True,
            verbose=False
        )
        
        return result


class GPTAnalyzer:
    """Handles AI analysis using OpenAI GPT API"""
    
    def __init__(self, api_key: str, model: str):
        self.client = OpenAI(api_key=api_key)
        self.model = model
    
    def analyze_transcription(
        self, 
        transcription_result: Dict[str, Any],
        audio_duration_ms: int
    ) -> Dict[str, Any]:
        """
        Analyze transcription to generate sentence boundaries, speaker labels, and clips
        
        Returns:
            Dictionary with transcripts and clips arrays
        """
        # Prepare the transcription data for Claude
        segments_data = []
        for segment in transcription_result.get("segments", []):
            segment_info = {
                "start": segment["start"],
                "end": segment["end"],
                "text": segment["text"].strip()
            }
            
            # Include word-level timings if available
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
        
        prompt = self._build_analysis_prompt(segments_data, audio_duration_ms)
        
        print("Sending transcription to GPT for analysis...")
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": "You are an expert in Korean language transcription analysis."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=4096
        )
        
        # Parse GPT's response
        response_text = response.choices[0].message.content
        
        # Extract JSON from response (GPT might wrap it in markdown)
        response_text = response_text.strip()
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        if response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        response_text = response_text.strip()
        
        try:
            analysis = json.loads(response_text)
            return analysis
        except json.JSONDecodeError as e:
            print(f"Error parsing GPT response: {e}")
            print(f"Response: {response_text[:500]}")
            raise
    
    def _build_analysis_prompt(self, segments: List[Dict], audio_duration_ms: int) -> str:
        """Build the prompt for GPT analysis"""
        
        segments_json = json.dumps(segments, ensure_ascii=False, indent=2)
        
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

        return prompt


class PackGenerator:
    """Generates the enhanced pack JSON file"""
    
    def __init__(self, input_path: Path, output_path: Path):
        self.input_path = input_path
        self.output_path = output_path
    
    def load_pack(self) -> Dict[str, Any]:
        """Load the existing pack JSON"""
        with open(self.input_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def enhance_track(
        self,
        track: Dict[str, Any],
        transcripts: List[Dict[str, Any]],
        clips: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Add transcripts and practice sets to a track
        
        Args:
            track: Original track dictionary
            transcripts: List of transcript spans from Claude
            clips: List of clips from Claude
        
        Returns:
            Enhanced track dictionary
        """
        track_id = track.get("id", str(uuid.uuid4()))
        
        # Format transcripts according to TranscriptSpan model
        formatted_transcripts = [
            {
                "startMs": t["startMs"],
                "endMs": t["endMs"],
                "text": t["text"],
                "speaker": t.get("speaker"),
                "languageCode": "ko-KR"
            }
            for t in transcripts
        ]
        
        # Format clips according to Clip model
        formatted_clips = [
            {
                "id": str(uuid.uuid4()),
                "startMs": c["startMs"],
                "endMs": c["endMs"],
                "kind": c["kind"],
                "title": c.get("title", f"Clip {i+1}"),
                "repeats": None,
                "startSpeed": None,
                "endSpeed": None,
                "languageCode": "ko-KR" if c["kind"] == "drill" else None
            }
            for i, c in enumerate(clips)
        ]
        
        # Create practice set according to PracticeSet model
        practice_set = {
            "id": str(uuid.uuid4()),
            "trackId": track_id,
            "displayOrder": 0,
            "title": "Practice Set",
            "clips": formatted_clips
        }
        
        # Update track with new data
        enhanced_track = track.copy()
        enhanced_track["transcripts"] = formatted_transcripts
        enhanced_track["practiceSets"] = [practice_set]
        
        # Remove old segment_maps if present
        if "segment_maps" in enhanced_track:
            del enhanced_track["segment_maps"]
        
        return enhanced_track
    
    def save_pack(self, pack_data: Dict[str, Any]):
        """Save the enhanced pack JSON"""
        with open(self.output_path, 'w', encoding='utf-8') as f:
            json.dump(pack_data, f, ensure_ascii=False, indent=2)
        print(f"\nEnhanced pack saved to: {self.output_path}")


def get_audio_duration_ms(audio_path: Path) -> int:
    """Get audio file duration in milliseconds"""
    info = sf.info(str(audio_path))
    return int(info.duration * 1000)


def main():
    """Main processing pipeline"""
    
    if not OPENAI_API_KEY:
        print("Error: OPENAI_API_KEY environment variable not set")
        sys.exit(1)
    
    print("=" * 60)
    print("Korean Audio Transcription & Practice Set Generator")
    print("=" * 60)
    print()
    
    # Initialize components
    transcriber = TranscriptionProcessor(model_name=WHISPER_MODEL)
    analyzer = GPTAnalyzer(api_key=OPENAI_API_KEY, model=GPT_MODEL)
    pack_generator = PackGenerator(input_path=PACK_JSON_INPUT, output_path=PACK_JSON_OUTPUT)
    
    # Load existing pack
    print(f"Loading pack from: {PACK_JSON_INPUT}")
    pack_data = pack_generator.load_pack()
    print(f"Found {len(pack_data['tracks'])} tracks in pack")
    
    # TEMPORARY: Only process first 3 tracks for testing
    tracks_to_process = pack_data["tracks"][:3]
    print(f"*** TESTING MODE: Processing only {len(tracks_to_process)} tracks ***")
    print()
    
    # Process each track
    enhanced_tracks = []
    
    for i, track in enumerate(tracks_to_process, 1):
        print(f"\n{'=' * 60}")
        print(f"Processing Track {i}/{len(tracks_to_process)}: {track['title']}")
        print(f"{'=' * 60}")
        
        filename = track["filename"]
        audio_path = AUDIO_DIR / filename
        
        if not audio_path.exists():
            print(f"Warning: Audio file not found: {audio_path}")
            enhanced_tracks.append(track)
            continue
        
        try:
            # Get audio duration
            duration_ms = get_audio_duration_ms(audio_path)
            print(f"Audio duration: {duration_ms / 1000:.2f} seconds")
            
            # Step 1: Transcribe with Whisper
            transcription_result = transcriber.transcribe_audio(audio_path)
            print(f"Transcription complete. Detected {len(transcription_result.get('segments', []))} segments")
            
            # Step 2: Analyze with Claude
            analysis = analyzer.analyze_transcription(transcription_result, duration_ms)
            print(f"Analysis complete:")
            print(f"  - {len(analysis.get('transcripts', []))} transcript spans")
            print(f"  - {len(analysis.get('clips', []))} clips")
            
            # Step 3: Enhance track
            enhanced_track = pack_generator.enhance_track(
                track=track,
                transcripts=analysis.get("transcripts", []),
                clips=analysis.get("clips", [])
            )
            
            enhanced_tracks.append(enhanced_track)
            
            print(f"✓ Track {i} processed successfully")
            
        except Exception as e:
            print(f"✗ Error processing track {i}: {e}")
            import traceback
            traceback.print_exc()
            enhanced_tracks.append(track)  # Keep original track on error
    
    # Update pack with enhanced tracks (only first 3 for testing)
    # Keep the rest of the tracks unchanged
    remaining_tracks = pack_data["tracks"][3:]
    pack_data["tracks"] = enhanced_tracks + remaining_tracks
    
    # Save enhanced pack
    pack_generator.save_pack(pack_data)
    
    print("\n" + "=" * 60)
    print("Processing Complete!")
    print("=" * 60)
    print(f"Enhanced pack saved to: {PACK_JSON_OUTPUT}")


if __name__ == "__main__":
    main()

