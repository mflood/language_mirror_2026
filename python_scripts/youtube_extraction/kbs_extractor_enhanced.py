#!/usr/bin/env python3
"""
Enhanced KBS News Video and Transcript Extractor with Web Agent

This script uses Selenium as a web agent to detect and extract video, audio, and transcript 
from KBS news articles, including dynamically loaded content.
"""

import os
import re
import json
import yaml
import logging
import subprocess
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Tuple, List
from urllib.parse import urljoin, urlparse, parse_qs

import requests
from bs4 import BeautifulSoup
from anthropic import Anthropic
from dotenv import load_dotenv

# Selenium imports
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.common.exceptions import TimeoutException, WebDriverException
from webdriver_manager.chrome import ChromeDriverManager

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class KBSWebAgent:
    """Web agent for detecting dynamic content on KBS news pages."""
    
    def __init__(self, headless: bool = True):
        """Initialize the web agent with Chrome driver."""
        self.headless = headless
        self.driver = None
        self._setup_driver()
    
    def _setup_driver(self):
        """Set up Chrome WebDriver with appropriate options."""
        try:
            chrome_options = Options()
            if self.headless:
                chrome_options.add_argument('--headless')
            chrome_options.add_argument('--no-sandbox')
            chrome_options.add_argument('--disable-dev-shm-usage')
            chrome_options.add_argument('--disable-gpu')
            chrome_options.add_argument('--window-size=1920,1080')
            chrome_options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36')
            
            # Disable images and CSS for faster loading
            prefs = {
                "profile.managed_default_content_settings.images": 2,
                "profile.default_content_setting_values.notifications": 2
            }
            chrome_options.add_experimental_option("prefs", prefs)
            
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            logger.info("Chrome WebDriver initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Chrome WebDriver: {e}")
            raise
    
    def get_page_content(self, url: str, wait_time: int = 10) -> Tuple[str, BeautifulSoup]:
        """
        Load page with JavaScript execution and return HTML content and parsed soup.
        
        Args:
            url: URL to load
            wait_time: Time to wait for page to load
            
        Returns:
            Tuple of (page_source, BeautifulSoup object)
        """
        try:
            logger.info(f"Loading page with web agent: {url}")
            self.driver.get(url)
            
            # Wait for page to load
            WebDriverWait(self.driver, wait_time).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            # Additional wait for dynamic content
            time.sleep(3)
            
            # Get page source after JavaScript execution
            page_source = self.driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
            
            logger.info("Page loaded successfully with web agent")
            return page_source, soup
            
        except TimeoutException:
            logger.warning("Page load timeout, using available content")
            page_source = self.driver.page_source
            soup = BeautifulSoup(page_source, 'html.parser')
            return page_source, soup
        except Exception as e:
            logger.error(f"Error loading page with web agent: {e}")
            raise
    
    def find_video_elements(self) -> List[Dict]:
        """
        Find video elements using various selectors and methods.
        
        Returns:
            List of video element information
        """
        video_elements = []
        
        try:
            # Look for video tags
            video_tags = self.driver.find_elements(By.TAG_NAME, "video")
            for video in video_tags:
                src = video.get_attribute("src")
                if src:
                    video_elements.append({
                        'type': 'video_tag',
                        'src': src,
                        'element': video
                    })
            
            # Look for iframe elements (YouTube, Vimeo, etc.)
            iframes = self.driver.find_elements(By.TAG_NAME, "iframe")
            for iframe in iframes:
                src = iframe.get_attribute("src")
                if src and any(domain in src for domain in ['youtube.com', 'youtu.be', 'vimeo.com', 'player.vimeo.com']):
                    video_elements.append({
                        'type': 'iframe',
                        'src': src,
                        'element': iframe
                    })
            
            # Look for elements with video-related data attributes
            video_selectors = [
                "[data-video-url]",
                "[data-video-id]", 
                "[data-src]",
                ".video-player",
                ".news-video",
                ".media-video"
            ]
            
            for selector in video_selectors:
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                for element in elements:
                    for attr in ['data-video-url', 'data-video-id', 'data-src']:
                        value = element.get_attribute(attr)
                        if value:
                            video_elements.append({
                                'type': 'data_attribute',
                                'src': value,
                                'attribute': attr,
                                'element': element
                            })
            
            # Look for clickable video elements
            clickable_selectors = [
                "[onclick*='video']",
                "[onclick*='play']",
                ".play-button",
                ".video-thumbnail"
            ]
            
            for selector in clickable_selectors:
                elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                for element in elements:
                    onclick = element.get_attribute("onclick")
                    if onclick:
                        video_elements.append({
                            'type': 'clickable',
                            'onclick': onclick,
                            'element': element
                        })
            
            logger.info(f"Found {len(video_elements)} potential video elements")
            return video_elements
            
        except Exception as e:
            logger.error(f"Error finding video elements: {e}")
            return []
    
    def extract_video_urls_from_scripts(self) -> List[str]:
        """
        Extract video URLs from JavaScript code on the page.
        
        Returns:
            List of video URLs found in scripts
        """
        video_urls = []
        
        try:
            # Execute JavaScript to find video URLs
            js_code = r"""
            var videoUrls = [];
            
            // Look for common video URL patterns in global variables
            if (window.videoUrl) videoUrls.push(window.videoUrl);
            if (window.video_url) videoUrls.push(window.video_url);
            if (window.videoSrc) videoUrls.push(window.videoSrc);
            if (window.video_src) videoUrls.push(window.video_src);
            
            // Look in common objects
            if (window.player && window.player.src) videoUrls.push(window.player.src);
            if (window.video && window.video.src) videoUrls.push(window.video.src);
            
            // Search through all script tags
            var scripts = document.getElementsByTagName('script');
            for (var i = 0; i < scripts.length; i++) {
                var scriptText = scripts[i].innerHTML;
                var matches = scriptText.match(/https?:\/\/[^"'\s]+\.(mp4|webm|avi|mov|m3u8)/gi);
                if (matches) {
                    videoUrls = videoUrls.concat(matches);
                }
            }
            
            return videoUrls;
            """
            
            urls = self.driver.execute_script(js_code)
            if urls:
                video_urls.extend(urls)
            
            logger.info(f"Found {len(video_urls)} video URLs in JavaScript")
            return video_urls
            
        except Exception as e:
            logger.error(f"Error extracting video URLs from scripts: {e}")
            return []
    
    def close(self):
        """Close the web driver."""
        if self.driver:
            self.driver.quit()
            logger.info("Web driver closed")


class KBSExtractorEnhanced:
    """Enhanced KBS extractor with web agent capabilities."""
    
    def __init__(self, output_dir: str = "output", use_web_agent: bool = True):
        """Initialize the enhanced extractor."""
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.use_web_agent = use_web_agent
        
        # Initialize web agent
        self.web_agent = None
        if use_web_agent:
            try:
                self.web_agent = KBSWebAgent(headless=True)
            except Exception as e:
                logger.warning(f"Failed to initialize web agent: {e}")
                self.use_web_agent = False
        
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
    
    def extract_ncd_from_url(self, url: str) -> Optional[str]:
        """
        Extract the ncd value from a KBS news URL.
        
        Args:
            url: KBS news article URL
            
        Returns:
            ncd value if found, None otherwise
        """
        try:
            parsed_url = urlparse(url)
            query_params = parse_qs(parsed_url.query)
            
            # Look for ncd parameter
            if 'ncd' in query_params:
                ncd_value = query_params['ncd'][0]
                logger.info(f"Extracted ncd value: {ncd_value}")
                return ncd_value
            
            logger.warning("No ncd parameter found in URL")
            return None
            
        except Exception as e:
            logger.error(f"Error extracting ncd from URL: {e}")
            return None
    
    def generate_filename(self, url: str, title: str) -> str:
        """
        Generate filename using ncd value from URL, with fallback to datetime.
        
        Args:
            url: KBS news article URL
            title: Article title (used as fallback)
            
        Returns:
            Safe filename string
        """
        # Try to extract ncd value first
        ncd_value = self.extract_ncd_from_url(url)
        
        if ncd_value:
            # Use ncd value as filename
            filename = ncd_value
            logger.info(f"Using ncd value for filename: {filename}")
        else:
            # Fallback to current datetime
            now = datetime.now()
            filename = now.strftime("%Y%m%d_%H%M%S")
            logger.info(f"Using datetime for filename: {filename}")
        
        return filename
    
    def extract_page_content(self, url: str) -> Tuple[str, str, str]:
        """
        Extract title, video URL, and transcript from KBS news page.
        
        Args:
            url: KBS news article URL
            
        Returns:
            Tuple of (title, video_url, transcript)
        """
        logger.info(f"Extracting content from: {url}")
        
        try:
            if self.use_web_agent and self.web_agent:
                # Use web agent for dynamic content
                page_source, soup = self.web_agent.get_page_content(url)
                video_url = self._extract_video_url_with_agent(url, soup)
            else:
                # Fallback to regular HTTP request
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                response.encoding = 'utf-8'
                soup = BeautifulSoup(response.text, 'html.parser')
                video_url = self._extract_video_url(soup, url)
            
            # Extract title and transcript
            title = self._extract_title(soup)
            transcript = self._extract_transcript(soup)
            
            return title, video_url, transcript
            
        except Exception as e:
            logger.error(f"Error extracting page content: {e}")
            raise
    
    def _extract_video_url_with_agent(self, base_url: str, soup: BeautifulSoup) -> Optional[str]:
        """Extract video URL using web agent capabilities."""
        if not self.web_agent:
            return self._extract_video_url(soup, base_url)
        
        try:
            # Get video elements using web agent
            video_elements = self.web_agent.find_video_elements()
            
            # Process video elements
            for element_info in video_elements:
                if element_info['type'] == 'video_tag' and element_info['src']:
                    return element_info['src']
                elif element_info['type'] == 'iframe' and element_info['src']:
                    return element_info['src']
                elif element_info['type'] == 'data_attribute' and element_info['src']:
                    video_url = element_info['src']
                    if not video_url.startswith('http'):
                        video_url = urljoin(base_url, video_url)
                    return video_url
            
            # Extract from JavaScript
            js_video_urls = self.web_agent.extract_video_urls_from_scripts()
            for video_url in js_video_urls:
                if video_url and not any(skip in video_url.lower() for skip in ['googletagmanager', 'analytics']):
                    return video_url
            
            # Fallback to regular extraction
            return self._extract_video_url(soup, base_url)
            
        except Exception as e:
            logger.error(f"Error extracting video URL with agent: {e}")
            return self._extract_video_url(soup, base_url)
    
    def _extract_video_url(self, soup: BeautifulSoup, base_url: str) -> Optional[str]:
        """Fallback video URL extraction method."""
        # Look for video elements
        video_elem = soup.find('video')
        if video_elem:
            source = video_elem.find('source')
            if source and source.get('src'):
                return urljoin(base_url, source['src'])
        
        # Look for iframe embeds
        iframes = soup.find_all('iframe')
        for iframe in iframes:
            src = iframe.get('src', '')
            if src and any(domain in src for domain in ['youtube.com', 'youtu.be', 'vimeo.com', 'player.vimeo.com']):
                return src
        
        # Look for script tags with video URLs
        scripts = soup.find_all('script')
        for script in scripts:
            if script.string:
                video_patterns = [
                    r'"(https?://[^"]*\.mp4[^"]*)"',
                    r'"(https?://[^"]*video[^"]*)"',
                    r'"(https?://[^"]*youtube[^"]*)"',
                    r'"(https?://[^"]*youtu\.be[^"]*)"',
                    r'videoUrl["\']?\s*:\s*["\']([^"\']+)["\']',
                    r'video_url["\']?\s*:\s*["\']([^"\']+)["\']'
                ]
                
                for pattern in video_patterns:
                    matches = re.findall(pattern, script.string, re.IGNORECASE)
                    for match in matches:
                        if not any(skip in match.lower() for skip in ['googletagmanager', 'analytics', 'facebook', 'twitter']):
                            if not match.startswith('http'):
                                match = urljoin(base_url, match)
                            return match
        
        logger.warning("No video URL found on the page")
        return None
    
    def _extract_title(self, soup: BeautifulSoup) -> str:
        """Extract the article title."""
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
                if title and len(title) > 10:
                    title = re.sub(r'\s+', ' ', title)
                    return title
        
        # Try meta tags
        meta_title = soup.find('meta', property='og:title')
        if meta_title and meta_title.get('content'):
            title = meta_title.get('content').strip()
            if len(title) > 10:
                return title
        
        # Try page title
        page_title = soup.find('title')
        if page_title:
            title = page_title.get_text(strip=True)
            title = re.sub(r'\s*-\s*KBS.*$', '', title)
            title = re.sub(r'\s*KBS.*$', '', title)
            if len(title) > 10:
                return title
        
        return "Untitled KBS News Article"
    
    def _extract_transcript(self, soup: BeautifulSoup) -> str:
        """Extract transcript/dialogue from the page."""
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
                if len(text) > 100:
                    return text
        
        # Try main content
        main_content = soup.find('main') or soup.find('article')
        if main_content:
            for script in main_content(["script", "style"]):
                script.decompose()
            text = main_content.get_text(strip=True)
            if len(text) > 100:
                return text
        
        return "Transcript not available"
    
    def download_video(self, video_url: str, filename: str) -> str:
        """Download video using yt-dlp or direct download."""
        logger.info(f"Downloading video from: {video_url}")
        
        # Check if it's a direct video URL (like KBS mp4 files)
        if video_url.endswith(('.mp4', '.webm', '.avi', '.mov', '.m3u8')):
            return self._download_direct_video(video_url, filename)
        
        # Use yt-dlp for other URLs
        output_path = self.output_dir / f"{filename}.%(ext)s"
        
        try:
            cmd = [
                'yt-dlp',
                '--output', str(output_path),
                '--format', 'best[height<=720]/best',
                '--no-playlist',
                '--user-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
                video_url
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode != 0:
                logger.error(f"yt-dlp failed: {result.stderr}")
                # Try direct download as fallback
                return self._download_direct_video(video_url, filename)
            
            # Find downloaded file
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
            # Try direct download as fallback
            return self._download_direct_video(video_url, filename)
    
    def _download_direct_video(self, video_url: str, filename: str) -> str:
        """Download video directly using requests."""
        logger.info(f"Downloading video directly: {video_url}")
        
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Referer': 'https://news.kbs.co.kr/'
            }
            
            response = self.session.get(video_url, headers=headers, stream=True, timeout=60)
            response.raise_for_status()
            
            # Determine file extension
            content_type = response.headers.get('content-type', '')
            if 'mp4' in content_type:
                ext = 'mp4'
            elif 'webm' in content_type:
                ext = 'webm'
            else:
                ext = 'mp4'  # Default
            
            video_path = self.output_dir / f"{filename}.{ext}"
            
            with open(video_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            logger.info(f"Video downloaded directly: {video_path}")
            return str(video_path)
            
        except Exception as e:
            logger.error(f"Direct video download failed: {e}")
            raise
    
    def extract_audio(self, video_path: str, filename: str) -> str:
        """Extract audio from video using ffmpeg."""
        logger.info(f"Extracting audio from: {video_path}")
        
        audio_path = self.output_dir / f"{filename}.mp3"
        
        try:
            cmd = [
                'ffmpeg',
                '-i', video_path,
                '-vn',
                '-acodec', 'mp3',
                '-ab', '128k',
                '-ar', '44100',
                '-y',
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
        """Use Claude to enhance and clean the transcript."""
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
        """Create metadata dictionary with all artifact information."""
        metadata = {
            'original_url': url,
            'title': title,
            'extraction_timestamp': str(Path().cwd()),
            'web_agent_used': self.use_web_agent,
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
        """Save metadata to file."""
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
        """Main method to process a KBS news URL."""
        logger.info(f"Processing KBS news URL with web agent: {url}")
        
        try:
            # Extract page content
            title, video_url, transcript = self.extract_page_content(url)
            
            # Generate filename using ncd value or datetime fallback
            filename = self.generate_filename(url, title)
            
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
        finally:
            # Clean up web agent
            if self.web_agent:
                self.web_agent.close()


def main():
    """Main function for command-line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Enhanced KBS News Extractor with Web Agent')
    parser.add_argument('url', help='KBS news article URL')
    parser.add_argument('--output-dir', default='output', help='Output directory (default: output)')
    parser.add_argument('--format', choices=['json', 'yaml'], default='json', help='Metadata format (default: json)')
    parser.add_argument('--no-web-agent', action='store_true', help='Disable web agent (use regular HTTP)')
    
    args = parser.parse_args()
    
    # Validate URL
    if not args.url.startswith('https://news.kbs.co.kr/'):
        logger.warning("URL doesn't appear to be a KBS news article")
    
    # Create extractor and process
    extractor = KBSExtractorEnhanced(
        output_dir=args.output_dir,
        use_web_agent=not args.no_web_agent
    )
    
    try:
        metadata = extractor.process_url(args.url, args.format)
        print(f"\nProcessing completed!")
        print(f"Title: {metadata['title']}")
        print(f"Web agent used: {metadata['web_agent_used']}")
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
