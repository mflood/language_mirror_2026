#!/usr/bin/env python3
"""
LM Studio Transcript Enhancer

A utility script to enhance transcripts using a local LM Studio instance.
This is useful when Claude API tokens are exhausted or unavailable.
"""

import os
import sys
import json
import logging
import argparse
from pathlib import Path
from typing import Optional

import requests


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class LMStudioEnhancer:
    """Enhanced transcript processor using local LM Studio instance."""
    
    def __init__(self, base_url: str = "http://localhost:1234", model: str = "mistralai/magistral-small-2509"):
        """
        Initialize the LM Studio enhancer.
        
        Args:
            base_url: Base URL for LM Studio API
            model: Model name to use for enhancement
        """
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json'
        })
    
    def test_connection(self) -> bool:
        """
        Test connection to LM Studio instance.
        
        Returns:
            True if connection is successful, False otherwise
        """
        try:
            # Simple test request
            test_payload = {
                "model": self.model,
                "messages": [
                    {"role": "user", "content": "Hello"}
                ],
                "max_tokens": 10,
                "stream": False
            }
            
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=test_payload,
                timeout=10
            )
            
            if response.status_code == 200:
                logger.info("✅ Successfully connected to LM Studio")
                return True
            else:
                logger.error(f"❌ LM Studio returned status code: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return False
                
        except requests.exceptions.ConnectionError:
            logger.error("❌ Cannot connect to LM Studio. Is it running on localhost:1234?")
            return False
        except requests.exceptions.Timeout:
            logger.error("❌ Connection to LM Studio timed out")
            return False
        except Exception as e:
            logger.error(f"❌ Error testing LM Studio connection: {e}")
            return False
    
    def enhance_transcript(self, transcript: str, title: str = "Korean News Article") -> str:
        """
        Enhance transcript using LM Studio.
        
        Args:
            transcript: Raw transcript text
            title: Article title for context
            
        Returns:
            Enhanced transcript text
        """
        if not transcript or len(transcript.strip()) < 50:
            logger.warning("Transcript is too short or empty, returning original")
            return transcript
        
        try:
            prompt = f"""Please clean and enhance this Korean news transcript. The article title is: "{title}"

Tasks:
1. Remove any HTML tags or formatting artifacts
2. Fix any obvious OCR or text extraction errors
3. Organize the content into clear paragraphs
4. Preserve the original Korean text
5. If there are speaker labels or dialogue markers, preserve them
6. Improve readability while maintaining the original meaning

Raw transcript:
{transcript}

Please return only the cleaned transcript without any additional commentary or explanations."""

            payload = {
                "model": self.model,
                "messages": [
                    {
                        "role": "system", 
                        "content": "You are a helpful assistant that cleans and enhances Korean news transcripts. Always respond in Korean and maintain the original meaning while improving readability."
                    },
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                "temperature": 0.3,  # Lower temperature for more consistent results
                "max_tokens": -1,    # No limit
                "stream": False
            }
            
            logger.info("🤖 Sending transcript to LM Studio for enhancement...")
            
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=120  # Longer timeout for large transcripts
            )
            
            if response.status_code == 200:
                result = response.json()
                
                if 'choices' in result and len(result['choices']) > 0:
                    enhanced_text = result['choices'][0]['message']['content'].strip()
                    logger.info("✅ Transcript enhanced successfully")
                    return enhanced_text
                else:
                    logger.error("❌ Unexpected response format from LM Studio")
                    logger.error(f"Response: {result}")
                    return transcript
            else:
                logger.error(f"❌ LM Studio returned status code: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return transcript
                
        except requests.exceptions.Timeout:
            logger.error("❌ Request to LM Studio timed out")
            return transcript
        except Exception as e:
            logger.error(f"❌ Error enhancing transcript: {e}")
            return transcript
    
    def process_transcript_file(self, transcript_path: str, output_path: Optional[str] = None) -> str:
        """
        Process a transcript file and save the enhanced version.
        
        Args:
            transcript_path: Path to the input transcript file
            output_path: Path for the enhanced transcript (optional)
            
        Returns:
            Path to the enhanced transcript file
        """
        transcript_file = Path(transcript_path)
        
        if not transcript_file.exists():
            raise FileNotFoundError(f"Transcript file not found: {transcript_path}")
        
        # Read the transcript
        logger.info(f"📖 Reading transcript from: {transcript_file}")
        with open(transcript_file, 'r', encoding='utf-8') as f:
            transcript = f.read()
        
        # Determine output path
        if output_path is None:
            # Create enhanced version in the same directory
            output_file = transcript_file.parent / f"{transcript_file.stem}_enhanced{transcript_file.suffix}"
        else:
            output_file = Path(output_path)
        
        # Extract title from filename if possible
        title = transcript_file.stem.replace('_transcript', '').replace('_', ' ')
        
        # Enhance the transcript
        enhanced_transcript = self.enhance_transcript(transcript, title)
        
        # Save the enhanced transcript
        logger.info(f"💾 Saving enhanced transcript to: {output_file}")
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(enhanced_transcript)
        
        # Log statistics
        original_length = len(transcript)
        enhanced_length = len(enhanced_transcript)
        logger.info(f"📊 Original length: {original_length} characters")
        logger.info(f"📊 Enhanced length: {enhanced_length} characters")
        logger.info(f"📊 Size change: {enhanced_length - original_length:+d} characters")
        
        return str(output_file)


def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(
        description='Enhance transcripts using local LM Studio instance',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Enhance a transcript file
  python lm_studio_enhancer.py transcript.txt
  
  # Specify custom output path
  python lm_studio_enhancer.py transcript.txt -o enhanced_transcript.txt
  
  # Use different LM Studio URL and model
  python lm_studio_enhancer.py transcript.txt --url http://localhost:8080 --model my-model
  
  # Test connection only
  python lm_studio_enhancer.py --test-connection
        """
    )
    
    parser.add_argument('transcript_path', nargs='?', help='Path to transcript file to enhance')
    parser.add_argument('-o', '--output', help='Output path for enhanced transcript')
    parser.add_argument('--url', default='http://localhost:1234', 
                       help='LM Studio API URL (default: http://localhost:1234)')
    parser.add_argument('--model', default='mistralai/magistral-small-2509',
                       help='Model name to use (default: mistralai/magistral-small-2509)')
    parser.add_argument('--test-connection', action='store_true',
                       help='Test connection to LM Studio and exit')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Set logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create enhancer instance
    enhancer = LMStudioEnhancer(base_url=args.url, model=args.model)
    
    # Test connection
    if not enhancer.test_connection():
        logger.error("❌ Cannot connect to LM Studio. Please check:")
        logger.error("   1. LM Studio is running")
        logger.error("   2. The correct URL is specified (--url)")
        logger.error("   3. The model is loaded and available (--model)")
        return 1
    
    # If only testing connection, exit here
    if args.test_connection:
        logger.info("✅ Connection test successful!")
        return 0
    
    # Check if transcript path is provided
    if not args.transcript_path:
        parser.error("transcript_path is required unless using --test-connection")
    
    try:
        # Process the transcript
        output_path = enhancer.process_transcript_file(
            args.transcript_path, 
            args.output
        )
        
        print(f"\n✅ Enhancement completed!")
        print(f"📁 Enhanced transcript saved to: {output_path}")
        
        return 0
        
    except FileNotFoundError as e:
        logger.error(f"❌ File not found: {e}")
        return 1
    except Exception as e:
        logger.error(f"❌ Error processing transcript: {e}")
        return 1


if __name__ == '__main__':
    exit(main())

