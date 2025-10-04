#!/usr/bin/env python3
"""
KBS News Video and Transcript Extractor

This script extracts video, audio, and transcript from KBS news articles.
It uses yt-dlp for video downloading and BeautifulSoup for HTML parsing.
"""

import os
import re
import json
import yaml
import logging
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Optional, Tuple
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from anthropic import Anthropic
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class KBSExtractor:
    """Main class for extracting content from KBS news articles."""
    
    def __init__(self, output_dir: str = "output"):
        """Initialize the extractor with output directory."""
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Initialize Anthropic client
        self.anthropic = Anthropic(
            api_key=os.getenv('ANTHROPIC_API_KEY')
        )
        self.claude_model = os.getenv('CLAUDE_MODEL', 'claude-3-5-sonnet-20241022')
        
        # Session for HTTP requests
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
    
    def extract_page_content(self, url: str) -> Tuple[str, str, str]:
        """
        Extract title, video URL, and transcript from KBS news page.
        
        Args:
            url: KBS news article URL
            
        Returns:
            Tuple of (title, video_url, transcript)
        """
        logger.info(f"Fetching page content from: {url}")
        
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            response.encoding = 'utf-8'
            
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract title
            title = self._extract_title(soup)
            
            # Extract video URL
            video_url = self._extract_video_url(soup, url)
            
            # Extract transcript/dialogue
            transcript = self._extract_transcript(soup)
            
            return title, video_url, transcript
            
        except Exception as e:
            logger.error(f"Error extracting page content: {e}")
            raise
    
    def _extract_title(self, soup: BeautifulSoup) -> str:
        """Extract the article title."""
        # Try multiple selectors for title
        title_selectors = [
            'h1.news-title',
            'h1.title',
            '.news-title',
            '.article-title',
            'h1',
            'title'
        ]
        
        for selector in title_selectors:
            title_elem = soup.select_one(selector)
            if title_elem:
                title = title_elem.get_text(strip=True)
                if title and len(title) > 10:  # Ensure it's a meaningful title
                    # Clean up the title
                    title = re.sub(r'\s+', ' ', title)  # Normalize whitespace
                    return title
        
        # Try to extract from meta tags
        meta_title = soup.find('meta', property='og:title')
        if meta_title and meta_title.get('content'):
            title = meta_title.get('content').strip()
            if len(title) > 10:
                return title
        
        # Try to extract from the page title and clean it
        page_title = soup.find('title')
        if page_title:
            title = page_title.get_text(strip=True)
            # Remove common suffixes like "KBS 뉴스"
            title = re.sub(r'\s*-\s*KBS.*$', '', title)
            title = re.sub(r'\s*KBS.*$', '', title)
            if len(title) > 10:
                return title
        
        return "Untitled KBS News Article"
    
    def _extract_video_url(self, soup: BeautifulSoup, base_url: str) -> Optional[str]:
        """Extract video URL from the page."""
        # Look for video elements
        video_elem = soup.find('video')
        if video_elem:
            source = video_elem.find('source')
            if source and source.get('src'):
                return urljoin(base_url, source['src'])
        
        # Look for iframe embeds (YouTube, Vimeo, etc.)
        iframes = soup.find_all('iframe')
        for iframe in iframes:
            src = iframe.get('src', '')
            if src and any(domain in src for domain in ['youtube.com', 'youtu.be', 'vimeo.com', 'player.vimeo.com']):
                return src
        
        # Look for KBS-specific video elements
        kbs_video_selectors = [
            '.video-player',
            '.news-video',
            '.media-video',
            '[data-video-id]',
            '[data-video-url]'
        ]
        
        for selector in kbs_video_selectors:
            elem = soup.select_one(selector)
            if elem:
                # Check for data attributes
                for attr in ['data-video-url', 'data-video-id', 'data-src']:
                    if elem.get(attr):
                        video_url = elem.get(attr)
                        if not video_url.startswith('http'):
                            video_url = urljoin(base_url, video_url)
                        return video_url
        
        # Look for script tags that might contain video URLs
        scripts = soup.find_all('script')
        for script in scripts:
            if script.string:
                # Look for KBS-specific video patterns
                video_patterns = [
                    r'"(https?://[^"]*kbs[^"]*\.mp4[^"]*)"',
                    r'"(https?://[^"]*video[^"]*\.mp4[^"]*)"',
                    r'"(https?://[^"]*youtube[^"]*)"',
                    r'"(https?://[^"]*youtu\.be[^"]*)"',
                    r'"(https?://[^"]*vimeo[^"]*)"',
                    r'videoUrl["\']?\s*:\s*["\']([^"\']+)["\']',
                    r'video_url["\']?\s*:\s*["\']([^"\']+)["\']',
                    r'src["\']?\s*:\s*["\']([^"\']*\.mp4[^"\']*)["\']'
                ]
                
                for pattern in video_patterns:
                    matches = re.findall(pattern, script.string, re.IGNORECASE)
                    for match in matches:
                        # Filter out obvious non-video URLs
                        if not any(skip in match.lower() for skip in ['googletagmanager', 'analytics', 'facebook', 'twitter']):
                            if not match.startswith('http'):
                                match = urljoin(base_url, match)
                            return match
        
        # Look for video links in the page
        video_links = soup.find_all('a', href=True)
        for link in video_links:
            href = link.get('href', '')
            if any(ext in href.lower() for ext in ['.mp4', '.webm', '.avi', '.mov']):
                if not href.startswith('http'):
                    href = urljoin(base_url, href)
                return href
        
        logger.warning("No video URL found on the page")
        return None
    
    def _extract_transcript(self, soup: BeautifulSoup) -> str:
        """Extract transcript/dialogue from the page."""
        # Look for transcript in various possible locations
        transcript_selectors = [
            '.transcript',
            '.dialogue',
            '.script',
            '.news-content',
            '.article-content',
            '.content'
        ]
        
        for selector in transcript_selectors:
            elem = soup.select_one(selector)
            if elem:
                text = elem.get_text(strip=True)
                if len(text) > 100:  # Ensure it's substantial content
                    return text
        
        # If no specific transcript found, try to extract main content
        main_content = soup.find('main') or soup.find('article')
        if main_content:
            # Remove script and style elements
            for script in main_content(["script", "style"]):
                script.decompose()
            
            text = main_content.get_text(strip=True)
            if len(text) > 100:
                return text
        
        return "Transcript not available"
    
    def download_video(self, video_url: str, filename: str) -> str:
        """
        Download video using yt-dlp.
        
        Args:
            video_url: URL of the video to download
            filename: Base filename for the downloaded video
            
        Returns:
            Path to the downloaded video file
        """
        logger.info(f"Downloading video from: {video_url}")
        
        output_path = self.output_dir / f"{filename}.%(ext)s"
        
        try:
            # Use yt-dlp to download the video
            cmd = [
                'yt-dlp',
                '--output', str(output_path),
                '--format', 'best[height<=720]',  # Limit to 720p for reasonable file size
                '--no-playlist',
                video_url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                logger.error(f"yt-dlp failed: {result.stderr}")
                raise Exception(f"Video download failed: {result.stderr}")
            
            # Find the downloaded file
            for ext in ['mp4', 'webm', 'mkv', 'avi']:
                video_file = self.output_dir / f"{filename}.{ext}"
                if video_file.exists():
                    logger.info(f"Video downloaded: {video_file}")
                    return str(video_file)
            
            raise Exception("Downloaded video file not found")
            
        except subprocess.TimeoutExpired:
            raise Exception("Video download timed out")
        except Exception as e:
            logger.error(f"Error downloading video: {e}")
            raise
    
    def extract_audio(self, video_path: str, filename: str) -> str:
        """
        Extract audio from video using ffmpeg.
        
        Args:
            video_path: Path to the video file
            filename: Base filename for the audio file
            
        Returns:
            Path to the extracted audio file
        """
        logger.info(f"Extracting audio from: {video_path}")
        
        audio_path = self.output_dir / f"{filename}.mp3"
        
        try:
            cmd = [
                'ffmpeg',
                '-i', video_path,
                '-vn',  # No video
                '-acodec', 'mp3',
                '-ab', '128k',  # Audio bitrate
                '-ar', '44100',  # Sample rate
                '-y',  # Overwrite output file
                str(audio_path)
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            
            if result.returncode != 0:
                logger.error(f"ffmpeg failed: {result.stderr}")
                raise Exception(f"Audio extraction failed: {result.stderr}")
            
            if audio_path.exists():
                logger.info(f"Audio extracted: {audio_path}")
                return str(audio_path)
            else:
                raise Exception("Audio file was not created")
                
        except subprocess.TimeoutExpired:
            raise Exception("Audio extraction timed out")
        except Exception as e:
            logger.error(f"Error extracting audio: {e}")
            raise
    
    def enhance_transcript_with_claude(self, transcript: str, title: str) -> str:
        """
        Use Claude to enhance and clean the transcript.
        
        Args:
            transcript: Raw transcript text
            title: Article title for context
            
        Returns:
            Enhanced transcript
        """
        if not self.anthropic or len(transcript) < 50:
            return transcript
        
        try:
            prompt = f"""
            Please clean and enhance this Korean news transcript. The article title is: "{title}"
            
            Tasks:
            1. Remove any HTML tags or formatting artifacts
            2. Fix any obvious OCR or text extraction errors
            3. Organize the content into clear paragraphs
            4. Preserve the original Korean text
            5. If there are speaker labels or dialogue markers, preserve them
            
            Raw transcript:
            {transcript}
            
            Please return only the cleaned transcript without any additional commentary.
            """
            
            response = self.anthropic.messages.create(
                model=self.claude_model,
                max_tokens=4000,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            enhanced = response.content[0].text.strip()
            logger.info("Transcript enhanced with Claude")
            return enhanced
            
        except Exception as e:
            logger.warning(f"Failed to enhance transcript with Claude: {e}")
            return transcript
    
    def create_metadata(self, url: str, title: str, video_path: str, 
                       audio_path: str, transcript_path: str) -> Dict:
        """
        Create metadata dictionary with all artifact information.
        
        Args:
            url: Original article URL
            title: Article title
            video_path: Path to video file
            audio_path: Path to audio file
            transcript_path: Path to transcript file
            
        Returns:
            Metadata dictionary
        """
        metadata = {
            'original_url': url,
            'title': title,
            'extraction_timestamp': str(Path().cwd()),
            'artifacts': {
                'video': {
                    'path': video_path,
                    'size_bytes': Path(video_path).stat().st_size if Path(video_path).exists() else 0
                },
                'audio': {
                    'path': audio_path,
                    'size_bytes': Path(audio_path).stat().st_size if Path(audio_path).exists() else 0
                },
                'transcript': {
                    'path': transcript_path,
                    'size_bytes': Path(transcript_path).stat().st_size if Path(transcript_path).exists() else 0
                }
            }
        }
        
        return metadata
    
    def save_metadata(self, metadata: Dict, format: str = 'json') -> str:
        """
        Save metadata to file.
        
        Args:
            metadata: Metadata dictionary
            format: Output format ('json' or 'yaml')
            
        Returns:
            Path to saved metadata file
        """
        if format.lower() == 'yaml':
            metadata_path = self.output_dir / 'metadata.yaml'
            with open(metadata_path, 'w', encoding='utf-8') as f:
                yaml.dump(metadata, f, default_flow_style=False, allow_unicode=True)
        else:
            metadata_path = self.output_dir / 'metadata.json'
            with open(metadata_path, 'w', encoding='utf-8') as f:
                json.dump(metadata, f, ensure_ascii=False, indent=2)
        
        logger.info(f"Metadata saved: {metadata_path}")
        return str(metadata_path)
    
    def process_url(self, url: str, output_format: str = 'json') -> Dict:
        """
        Main method to process a KBS news URL.
        
        Args:
            url: KBS news article URL
            output_format: Metadata output format ('json' or 'yaml')
            
        Returns:
            Metadata dictionary
        """
        logger.info(f"Processing KBS news URL: {url}")
        
        try:
            # Extract page content
            title, video_url, transcript = self.extract_page_content(url)
            
            # Clean title for filename
            safe_title = re.sub(r'[^\w\s-]', '', title).strip()
            safe_title = re.sub(r'[-\s]+', '-', safe_title)
            filename = safe_title[:50]  # Limit filename length
            
            # Save transcript
            transcript_path = self.output_dir / f"{filename}_transcript.txt"
            with open(transcript_path, 'w', encoding='utf-8') as f:
                f.write(transcript)
            
            video_path = None
            audio_path = None
            
            # Download video if URL is available
            if video_url:
                try:
                    video_path = self.download_video(video_url, filename)
                    audio_path = self.extract_audio(video_path, filename)
                except Exception as e:
                    logger.error(f"Video processing failed: {e}")
                    # Continue without video/audio
            else:
                logger.warning("No video URL found, skipping video/audio extraction")
            
            # Enhance transcript with Claude
            enhanced_transcript = self.enhance_transcript_with_claude(transcript, title)
            
            # Save enhanced transcript
            enhanced_transcript_path = self.output_dir / f"{filename}_enhanced_transcript.txt"
            with open(enhanced_transcript_path, 'w', encoding='utf-8') as f:
                f.write(enhanced_transcript)
            
            # Create metadata
            metadata = self.create_metadata(
                url, title, 
                video_path or "N/A", 
                audio_path or "N/A", 
                str(enhanced_transcript_path)
            )
            
            # Save metadata
            metadata_path = self.save_metadata(metadata, output_format)
            metadata['metadata_file'] = metadata_path
            
            logger.info("Processing completed successfully")
            return metadata
            
        except Exception as e:
            logger.error(f"Error processing URL: {e}")
            raise


def main():
    """Main function for command-line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Extract video, audio, and transcript from KBS news articles')
    parser.add_argument('url', help='KBS news article URL')
    parser.add_argument('--output-dir', default='output', help='Output directory (default: output)')
    parser.add_argument('--format', choices=['json', 'yaml'], default='json', help='Metadata format (default: json)')
    
    args = parser.parse_args()
    
    # Validate URL
    if not args.url.startswith('https://news.kbs.co.kr/'):
        logger.warning("URL doesn't appear to be a KBS news article")
    
    # Create extractor and process
    extractor = KBSExtractor(args.output_dir)
    
    try:
        metadata = extractor.process_url(args.url, args.format)
        print(f"\nProcessing completed!")
        print(f"Title: {metadata['title']}")
        print(f"Output directory: {args.output_dir}")
        print(f"Metadata file: {metadata['metadata_file']}")
        
        if metadata['artifacts']['video']['path'] != 'N/A':
            print(f"Video: {metadata['artifacts']['video']['path']}")
        if metadata['artifacts']['audio']['path'] != 'N/A':
            print(f"Audio: {metadata['artifacts']['audio']['path']}")
        print(f"Transcript: {metadata['artifacts']['transcript']['path']}")
        
    except Exception as e:
        logger.error(f"Failed to process URL: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    exit(main())
