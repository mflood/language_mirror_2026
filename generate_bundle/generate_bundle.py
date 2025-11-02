#!/usr/bin/env python3
"""
Bundle Manifest Generator

Scans a folder of audio files and generates a bundle manifest JSON file
suitable for S3 static website hosting and use with LanguageMirror app.
"""

import os
import json
import sys
import argparse
import uuid
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

try:
    import soundfile as sf
except ImportError:
    print("Error: soundfile is required. Install with: pip install soundfile")
    sys.exit(1)

try:
    import boto3
    from botocore.exceptions import ClientError, NoCredentialsError
except ImportError:
    boto3 = None

# Optional imports for transcription
try:
    import whisper
    whisper_available = True
except ImportError:
    whisper_available = False

try:
    from openai import OpenAI
    openai_available = True
except ImportError:
    openai_available = False

try:
    from dotenv import load_dotenv
    dotenv_available = True
except ImportError:
    dotenv_available = False


# Supported audio file extensions
AUDIO_EXTENSIONS = {'.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.opus'}


def natural_sort_key(filename: str) -> tuple:
    """
    Generate a sort key for natural sorting (e.g., track_01.mp3, track_02.mp3)
    """
    import re
    parts = re.split(r'(\d+)', filename.lower())
    return tuple(int(part) if part.isdigit() else part for part in parts)


def get_audio_duration_ms(audio_path: Path) -> int:
    """Get audio file duration in milliseconds"""
    try:
        info = sf.info(str(audio_path))
        return int(info.duration * 1000)
    except Exception as e:
        print(f"Warning: Could not get duration for {audio_path.name}: {e}")
        return 0


def find_audio_files(folder: Path) -> List[Path]:
    """Find all audio files in the given folder"""
    audio_files = []
    for file in folder.iterdir():
        if file.is_file() and file.suffix.lower() in AUDIO_EXTENSIONS:
            audio_files.append(file)
    
    # Sort naturally (e.g., track_01.mp3, track_02.mp3)
    audio_files.sort(key=lambda p: natural_sort_key(p.name))
    return audio_files


def clean_track_title(filename: str) -> str:
    """
    Clean up filename to use as track title.
    Removes extension and replaces underscores/hyphens with spaces.
    """
    name = Path(filename).stem  # Remove extension
    # Replace underscores and hyphens with spaces
    name = name.replace('_', ' ').replace('-', ' ')
    # Capitalize words
    name = ' '.join(word.capitalize() for word in name.split())
    return name


def create_full_track_practice_set(duration_ms: int, track_id_placeholder: str) -> Dict[str, Any]:
    """
    Create a default "Full Track" practice set with a single clip spanning the entire audio duration.
    
    Args:
        duration_ms: Duration of the audio track in milliseconds
        track_id_placeholder: Placeholder track ID (will be replaced during import)
    
    Returns:
        Dictionary representing a PracticeSet matching Swift Models.swift structure
    """
    if duration_ms <= 0:
        return {
            "id": str(uuid.uuid4()),
            "trackId": track_id_placeholder,
            "displayOrder": 0,
            "title": "Full Track",
            "clips": [],
            "isFavorite": False
        }
    
    practice_set_id = str(uuid.uuid4())
    clip_id = str(uuid.uuid4())
    
    return {
        "id": practice_set_id,
        "trackId": track_id_placeholder,
        "displayOrder": 0,
        "title": "Full Track",
        "clips": [
            {
                "id": clip_id,
                "startMs": 0,
                "endMs": duration_ms,
                "kind": "drill",
                "title": "Full Track",
                "repeats": None,
                "startSpeed": None,
                "endSpeed": None,
                "languageCode": None
            }
        ],
        "isFavorite": False
    }


def build_url(base_url: Optional[str], filename: str) -> str:
    """
    Build full URL for audio file.
    If base_url is None or empty, returns just the filename.
    """
    if not base_url:
        return filename
    
    # Normalize base_url (ensure it ends with / if not empty)
    base = base_url.rstrip('/')
    if base:
        return f"{base}/{filename}"
    return filename


def parse_s3_uri(s3_uri: str) -> Tuple[str, str]:
    """
    Parse S3 URI format: s3://bucket/key/path/
    Returns: (bucket_name, key_prefix)
    """
    if not s3_uri.startswith('s3://'):
        raise ValueError(f"Invalid S3 URI: must start with 's3://'")
    
    # Remove s3:// prefix
    path = s3_uri[5:]
    
    # Split bucket and key
    parts = path.split('/', 1)
    bucket = parts[0]
    key_prefix = parts[1] if len(parts) > 1 else ''
    
    # Ensure key prefix ends with / if not empty
    if key_prefix and not key_prefix.endswith('/'):
        key_prefix += '/'
    
    return bucket, key_prefix


def upload_to_s3(
    local_file: Path,
    bucket: str,
    s3_key: str,
    s3_client
) -> bool:
    """
    Upload a file to S3.
    Returns True if successful, False otherwise.
    """
    try:
        print(f"  Uploading {local_file.name}...", end=' ', flush=True)
        s3_client.upload_file(
            str(local_file),
            bucket,
            s3_key,
            ExtraArgs={'ContentType': get_content_type(local_file)}
        )
        print("✓")
        return True
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def get_content_type(file_path: Path) -> str:
    """Get content type based on file extension"""
    ext = file_path.suffix.lower()
    content_types = {
        '.mp3': 'audio/mpeg',
        '.m4a': 'audio/mp4',
        '.wav': 'audio/wav',
        '.aac': 'audio/aac',
        '.flac': 'audio/flac',
        '.ogg': 'audio/ogg',
        '.opus': 'audio/opus',
        '.json': 'application/json',
    }
    return content_types.get(ext, 'application/octet-stream')


class TranscriptionProcessor:
    """Handles audio transcription using Whisper"""
    
    def __init__(self, model_name: str = "base"):
        if not whisper_available:
            raise ImportError("whisper is required for transcription. Install with: pip install openai-whisper")
        print(f"Loading Whisper model: {model_name}...")
        self.model = whisper.load_model(model_name)
        print("Whisper model loaded successfully")
    
    def transcribe_audio(self, audio_path: Path, language: Optional[str] = None) -> Dict[str, Any]:
        """
        Transcribe audio file with word-level timestamps
        
        Args:
            audio_path: Path to audio file
            language: Optional language code (e.g., "ko", "en"). If None, auto-detect.
        
        Returns:
            Dictionary with segments and word-level timings
        """
        print(f"Transcribing: {audio_path.name}")
        
        result = self.model.transcribe(
            str(audio_path),
            language=language,
            word_timestamps=True,
            verbose=False
        )
        
        return result


class GPTAnalyzer:
    """Handles AI analysis using OpenAI GPT API"""
    
    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        if not openai_available:
            raise ImportError("openai is required for transcription. Install with: pip install openai")
        self.client = OpenAI(api_key=api_key)
        self.model = model
    
    def analyze_transcription(
        self, 
        transcription_result: Dict[str, Any],
        audio_duration_ms: int,
        language_code: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Analyze transcription to generate sentence boundaries, speaker labels, and clips
        
        Args:
            transcription_result: Whisper transcription result
            audio_duration_ms: Duration of audio in milliseconds
            language_code: Optional language code (e.g., "ko-KR") for transcripts
        
        Returns:
            Dictionary with transcripts and clips arrays
        """
        # Prepare the transcription data for GPT
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
        
        prompt = self._build_analysis_prompt(segments_data, audio_duration_ms, language_code)
        
        print("Sending transcription to GPT for analysis...")
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": "You are an expert in language transcription analysis."},
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
    
    def _build_analysis_prompt(self, segments: List[Dict], audio_duration_ms: int, language_code: Optional[str] = None) -> str:
        """Build the prompt for GPT analysis"""
        
        segments_json = json.dumps(segments, ensure_ascii=False, indent=2)
        language_hint = ""
        if language_code:
            lang_name = {"ko-KR": "Korean", "en-US": "English"}.get(language_code, language_code)
            language_hint = f"\nLanguage: {lang_name} ({language_code})"
        
        prompt = f"""You are analyzing audio transcription to create practice clips for language learning.

Audio Duration: {audio_duration_ms} ms{language_hint}

Transcription segments with timestamps (in seconds):
{segments_json}

Your task:
1. Identify sentence boundaries in the text
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
      "text": "<text>",
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
- Use natural sentence boundaries
- Keep speaker labels consistent throughout
- Clip titles should be descriptive: "Sentence 1", "Sentence 2", etc. for drill clips

Respond ONLY with the JSON structure, no additional text."""

        return prompt


def generate_manifest(
    audio_folder: Path,
    bundle_title: Optional[str],
    pack_title: Optional[str],
    pack_id: Optional[str],
    base_url: Optional[str],
    author: Optional[str],
    cover_url: Optional[str],
    cover_filename: Optional[str],
    transcribe: bool = False,
    transcriber: Optional[TranscriptionProcessor] = None,
    analyzer: Optional[GPTAnalyzer] = None,
    language_code: Optional[str] = None,
    whisper_model: str = "base"
) -> Dict[str, Any]:
    """
    Generate bundle manifest from audio files in folder.
    
    Args:
        transcribe: If True, transcribe audio and generate sentence-based practice sets
        transcriber: TranscriptionProcessor instance (required if transcribe=True)
        analyzer: GPTAnalyzer instance (required if transcribe=True)
        language_code: Optional language code for transcription (e.g., "ko-KR", "en-US")
        whisper_model: Whisper model to use (default: "base")
    """
    # Default titles from folder name if not provided
    folder_name = audio_folder.name
    bundle_title = bundle_title or folder_name
    pack_title = pack_title or folder_name
    
    # Generate pack ID if not provided
    if not pack_id:
        pack_id = str(uuid.uuid4())
    
    # Find all audio files
    audio_files = find_audio_files(audio_folder)
    
    if not audio_files:
        raise ValueError(f"No audio files found in {audio_folder}")
    
    print(f"Found {len(audio_files)} audio file(s)")
    
    # Generate tracks
    tracks = []
    total_duration_ms = 0
    
    for audio_file in audio_files:
        print(f"\nProcessing: {audio_file.name}...", end=' ', flush=True)
        
        # Get duration
        duration_ms = get_audio_duration_ms(audio_file)
        total_duration_ms += duration_ms
        
        # Generate track title from filename
        track_title = clean_track_title(audio_file.name)
        
        # Build URL
        audio_url = build_url(base_url, audio_file.name)
        
        # Generate placeholder track ID (will be replaced with deterministic UUID during import)
        track_id_placeholder = str(uuid.uuid4())
        
        # Create default "Full Track" practice set (displayOrder: 0)
        practice_sets = [create_full_track_practice_set(duration_ms, track_id_placeholder)]
        transcripts = []
        
        # If transcription is enabled, process the audio
        if transcribe:
            if not transcriber or not analyzer:
                print("\nError: Transcription requires transcriber and analyzer instances")
                raise ValueError("Transcription enabled but transcriber/analyzer not provided")
            
            try:
                # Detect language for Whisper (extract base language from language_code)
                whisper_lang = None
                if language_code:
                    # Extract base language code (e.g., "ko" from "ko-KR")
                    whisper_lang = language_code.split("-")[0] if "-" in language_code else language_code
                
                # Step 1: Transcribe with Whisper
                print(f"\n  Transcribing audio...")
                transcription_result = transcriber.transcribe_audio(audio_file, language=whisper_lang)
                print(f"  Transcription complete. Detected {len(transcription_result.get('segments', []))} segments")
                
                # Step 2: Analyze with GPT
                print(f"  Analyzing transcription...")
                analysis = analyzer.analyze_transcription(transcription_result, duration_ms, language_code)
                print(f"  Analysis complete:")
                print(f"    - {len(analysis.get('transcripts', []))} transcript spans")
                print(f"    - {len(analysis.get('clips', []))} clips")
                
                # Step 3: Format transcripts according to TranscriptSpan model
                formatted_transcripts = [
                    {
                        "startMs": t["startMs"],
                        "endMs": t["endMs"],
                        "text": t["text"],
                        "speaker": t.get("speaker"),
                        "languageCode": language_code
                    }
                    for t in analysis.get("transcripts", [])
                ]
                
                # Step 4: Format clips and create sentence-based practice set
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
                        "languageCode": language_code if c["kind"] == "drill" else None
                    }
                    for i, c in enumerate(analysis.get("clips", []))
                ]
                
                # Create sentence-based practice set (displayOrder: 1)
                sentence_practice_set = {
                    "id": str(uuid.uuid4()),
                    "trackId": track_id_placeholder,
                    "displayOrder": 1,
                    "title": "Practice Set",
                    "clips": formatted_clips,
                    "isFavorite": False
                }
                
                practice_sets.append(sentence_practice_set)
                transcripts = formatted_transcripts
                
                print(f"  ✓ Transcription and analysis complete")
                
            except Exception as e:
                print(f"\n  ✗ Error during transcription: {e}")
                import traceback
                traceback.print_exc()
                print(f"  Continuing with Full Track practice set only...")
        
        track = {
            "id": None,
            "title": track_title,
            "url": audio_url,
            "filename": audio_file.name,
            "durationMs": duration_ms,
            "practiceSets": practice_sets,
            "transcripts": transcripts
        }
        
        tracks.append(track)
        print(f"✓ ({duration_ms / 1000:.1f}s)")
    
    # Build pack
    pack = {
        "id": pack_id,
        "title": pack_title,
        "author": author,
        "coverUrl": cover_url,
        "coverFilename": cover_filename,
        "tracks": tracks
    }
    
    # Build manifest
    manifest = {
        "title": bundle_title,
        "packs": [pack]
    }
    
    return manifest


def main():
    parser = argparse.ArgumentParser(
        description="Generate bundle manifest JSON from audio files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage
  python generate_bundle.py --input /path/to/audio/folder
  
  # With custom titles and S3 base URL
  python generate_bundle.py -i /path/to/audio/folder \\
    --title "Korean Learning Pack 1" \\
    --pack-title "Beginner Korean" \\
    --base-url "https://my-bucket.s3.amazonaws.com/audio/" \\
    --output manifest.json
  
  # Dry run to preview output
  python generate_bundle.py -i /path/to/audio/folder --dry-run
        """
    )
    
    parser.add_argument(
        '--input', '-i',
        type=str,
        required=True,
        help='Folder path containing audio files (required)'
    )
    
    parser.add_argument(
        '--title', '-t',
        type=str,
        help='Bundle title (default: folder name)'
    )
    
    parser.add_argument(
        '--pack-title',
        type=str,
        help='Pack title (default: folder name)'
    )
    
    parser.add_argument(
        '--pack-id',
        type=str,
        help='Pack ID (default: auto-generated UUID)'
    )
    
    parser.add_argument(
        '--base-url',
        type=str,
        help='Base URL for S3 bucket (e.g., https://bucket.s3.amazonaws.com/audio/)'
    )
    
    parser.add_argument(
        '--author',
        type=str,
        help='Author name'
    )
    
    parser.add_argument(
        '--cover-url',
        type=str,
        help='Cover image URL'
    )
    
    parser.add_argument(
        '--cover-filename',
        type=str,
        help='Cover image filename'
    )
    
    parser.add_argument(
        '--output', '-o',
        type=str,
        help='Output manifest file path (default: bundle.json in input folder)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Print manifest without saving to file'
    )
    
    parser.add_argument(
        '--publish-s3',
        type=str,
        help='S3 URI to upload bundle (e.g., s3://bucket/path/to/bundle/). Uploads manifest and all audio files.'
    )
    
    parser.add_argument(
        '--manifest-only',
        action='store_true',
        help='When used with --publish-s3, only upload the manifest file (skip audio files). Useful when audio files are already on S3.'
    )
    
    parser.add_argument(
        '--transcribe',
        action='store_true',
        help='Enable transcription processing. Transcribes audio, analyzes sentences, and creates sentence-based practice sets. Requires OPENAI_API_KEY in environment or .env file.'
    )
    
    parser.add_argument(
        '--language-code',
        type=str,
        help='Language code for transcription (e.g., "ko-KR", "en-US"). Helps Whisper and GPT understand the language.'
    )
    
    parser.add_argument(
        '--whisper-model',
        type=str,
        default='base',
        choices=['tiny', 'base', 'small', 'medium', 'large'],
        help='Whisper model to use for transcription (default: base). Larger models are more accurate but slower.'
    )
    
    args = parser.parse_args()
    
    # Validate input folder
    audio_folder = Path(args.input)
    if not audio_folder.exists():
        print(f"Error: Folder does not exist: {audio_folder}")
        sys.exit(1)
    
    if not audio_folder.is_dir():
        print(f"Error: Not a directory: {audio_folder}")
        sys.exit(1)
    
    # Auto-generate base_url from S3 URI if not provided
    base_url = args.base_url
    if args.publish_s3 and not base_url:
        try:
            bucket, key_prefix = parse_s3_uri(args.publish_s3)
            # Construct base URL from bucket and key prefix
            # Using http:// (user can configure HTTPS if needed)
            base_url = f"http://{bucket}/{key_prefix}"
            print(f"Auto-generated base URL from S3 URI: {base_url}")
        except Exception as e:
            print(f"Warning: Could not auto-generate base URL: {e}")
    
    # Set up transcription if enabled
    transcriber = None
    analyzer = None
    if args.transcribe:
        print("\n" + "=" * 60)
        print("Transcription Mode Enabled")
        print("=" * 60)
        
        # Check for required dependencies
        if not whisper_available:
            print("Error: whisper is required for transcription.")
            print("Install with: pip install openai-whisper")
            sys.exit(1)
        
        if not openai_available:
            print("Error: openai is required for transcription.")
            print("Install with: pip install openai")
            sys.exit(1)
        
        if not dotenv_available:
            print("Warning: python-dotenv not found. Will only use environment variables.")
        else:
            # Load .env file if available
            load_dotenv()
        
        # Get OpenAI API key
        openai_api_key = os.getenv("OPENAI_API_KEY")
        if not openai_api_key:
            print("Error: OPENAI_API_KEY environment variable not set")
            print("Set it in your environment or create a .env file with:")
            print("  OPENAI_API_KEY=your_api_key_here")
            sys.exit(1)
        
        # Initialize transcription components
        print(f"Initializing Whisper model: {args.whisper_model}")
        transcriber = TranscriptionProcessor(model_name=args.whisper_model)
        
        print("Initializing GPT analyzer...")
        analyzer = GPTAnalyzer(api_key=openai_api_key, model="gpt-4o-mini")
        
        print("✓ Transcription components ready")
        print("=" * 60)
    
    try:
        # Generate manifest
        manifest = generate_manifest(
            audio_folder=audio_folder,
            bundle_title=args.title,
            pack_title=args.pack_title,
            pack_id=args.pack_id,
            base_url=base_url,
            author=args.author,
            cover_url=args.cover_url,
            cover_filename=args.cover_filename,
            transcribe=args.transcribe,
            transcriber=transcriber,
            analyzer=analyzer,
            language_code=args.language_code,
            whisper_model=args.whisper_model
        )
        
        # Convert to JSON
        manifest_json = json.dumps(manifest, indent=2, ensure_ascii=False)
        
        if args.dry_run:
            print("\n" + "=" * 60)
            print("Generated Manifest (dry run):")
            print("=" * 60)
            print(manifest_json)
            print("=" * 60)
        else:
            # Determine output file path
            if args.output:
                output_path = Path(args.output)
            else:
                output_path = audio_folder / "bundle.json"
            
            # Write manifest to file
            output_path.write_text(manifest_json, encoding='utf-8')
            
            # Print summary
            num_tracks = len(manifest["packs"][0]["tracks"])
            total_duration = sum(t["durationMs"] for t in manifest["packs"][0]["tracks"])
            total_minutes = total_duration / 60000
            
            print("\n" + "=" * 60)
            print("Bundle Manifest Generated Successfully!")
            print("=" * 60)
            print(f"Bundle Title: {manifest['title']}")
            print(f"Pack Title: {manifest['packs'][0]['title']}")
            print(f"Number of Tracks: {num_tracks}")
            print(f"Total Duration: {total_minutes:.1f} minutes ({total_duration / 1000:.1f} seconds)")
            print(f"Output File: {output_path}")
            print("=" * 60)
            
            if args.base_url:
                print(f"\nNote: Audio URLs are prefixed with: {args.base_url}")
                print("Make sure audio files are uploaded to the same relative paths on S3.")
            else:
                print("\nNote: Audio URLs use filenames only.")
                print("Make sure the manifest and audio files are in the same directory on S3.")
            
            # Upload to S3 if requested
            if args.publish_s3:
                if not boto3:
                    print("\nError: boto3 is required for S3 upload. Install with: pip install boto3")
                    sys.exit(1)
                
                try:
                    print("\n" + "=" * 60)
                    print("Uploading to S3...")
                    print("=" * 60)
                    
                    # Parse S3 URI
                    bucket, key_prefix = parse_s3_uri(args.publish_s3)
                    print(f"Bucket: {bucket}")
                    print(f"Key prefix: {key_prefix}")
                    
                    # Initialize S3 client
                    s3_client = boto3.client('s3')
                    
                    # Upload manifest
                    manifest_s3_key = f"{key_prefix}{output_path.name}"
                    print(f"\nUploading manifest: {manifest_s3_key}")
                    if not upload_to_s3(output_path, bucket, manifest_s3_key, s3_client):
                        print("Failed to upload manifest")
                        sys.exit(1)
                    
                    # Upload audio files (unless --manifest-only flag is set)
                    uploaded_audio = 0
                    if not args.manifest_only:
                        audio_files = find_audio_files(audio_folder)
                        print(f"\nUploading {len(audio_files)} audio file(s):")
                        for audio_file in audio_files:
                            audio_s3_key = f"{key_prefix}{audio_file.name}"
                            if upload_to_s3(audio_file, bucket, audio_s3_key, s3_client):
                                uploaded_audio += 1
                    else:
                        print("\nSkipping audio file uploads (--manifest-only flag set)")
                    
                    print("\n" + "=" * 60)
                    print("S3 Upload Complete!")
                    print("=" * 60)
                    if args.manifest_only:
                        print(f"Uploaded: 1 file (manifest only)")
                    else:
                        print(f"Uploaded: {uploaded_audio + 1} file(s) ({uploaded_audio} audio + 1 manifest)")
                    
                    # Generate public URL
                    if key_prefix:
                        manifest_url = f"https://{bucket}/{manifest_s3_key}"
                    else:
                        manifest_url = f"https://{bucket}/{output_path.name}"
                    
                    print(f"\nManifest URL: {manifest_url}")
                    print("You can use this URL in the LanguageMirror app's 'Install Bundle' feature.")
                    print("=" * 60)
                    
                except NoCredentialsError:
                    print("\nError: AWS credentials not found.")
                    print("Configure credentials using:")
                    print("  - AWS CLI: aws configure")
                    print("  - Environment variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
                    print("  - IAM role (if running on EC2)")
                    sys.exit(1)
                except ValueError as e:
                    print(f"\nError: {e}")
                    sys.exit(1)
                except Exception as e:
                    print(f"\nError uploading to S3: {e}")
                    import traceback
                    traceback.print_exc()
                    sys.exit(1)
    
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

