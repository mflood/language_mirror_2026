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


def generate_manifest(
    audio_folder: Path,
    bundle_title: Optional[str],
    pack_title: Optional[str],
    pack_id: Optional[str],
    base_url: Optional[str],
    author: Optional[str],
    cover_url: Optional[str],
    cover_filename: Optional[str]
) -> Dict[str, Any]:
    """
    Generate bundle manifest from audio files in folder.
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
        print(f"Processing: {audio_file.name}...", end=' ', flush=True)
        
        # Get duration
        duration_ms = get_audio_duration_ms(audio_file)
        total_duration_ms += duration_ms
        
        # Generate track title from filename
        track_title = clean_track_title(audio_file.name)
        
        # Build URL
        audio_url = build_url(base_url, audio_file.name)
        
        track = {
            "id": None,
            "title": track_title,
            "url": audio_url,
            "filename": audio_file.name,
            "durationMs": duration_ms,
            "clips": [],
            "transcripts": []
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
            cover_filename=args.cover_filename
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
                    
                    # Upload audio files
                    audio_files = find_audio_files(audio_folder)
                    print(f"\nUploading {len(audio_files)} audio file(s):")
                    uploaded = 0
                    for audio_file in audio_files:
                        audio_s3_key = f"{key_prefix}{audio_file.name}"
                        if upload_to_s3(audio_file, bucket, audio_s3_key, s3_client):
                            uploaded += 1
                    
                    print("\n" + "=" * 60)
                    print("S3 Upload Complete!")
                    print("=" * 60)
                    print(f"Uploaded: {uploaded + 1} file(s) ({uploaded} audio + 1 manifest)")
                    
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

