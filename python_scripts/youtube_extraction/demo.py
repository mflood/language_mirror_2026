#!/usr/bin/env python3
"""
Demonstration script for KBS News Extractor

This script shows various usage examples and capabilities of the KBS extractor.
"""

import os
import sys
import json
from pathlib import Path
from kbs_extractor import KBSExtractor


def demo_basic_usage():
    """Demonstrate basic usage of the KBS extractor."""
    print("🎬 Demo 1: Basic Usage")
    print("=" * 50)
    
    # Example KBS news URL
    url = "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851"
    
    # Create extractor instance
    extractor = KBSExtractor(output_dir="demo_output")
    
    try:
        # Process the URL
        metadata = extractor.process_url(url)
        
        print(f"✅ Successfully processed: {metadata['title']}")
        print(f"📁 Output directory: {extractor.output_dir}")
        print(f"📄 Metadata file: {metadata['metadata_file']}")
        
        # Show artifact information
        artifacts = metadata['artifacts']
        print("\n📦 Generated Artifacts:")
        for artifact_type, info in artifacts.items():
            if info['path'] != 'N/A':
                size_mb = info['size_bytes'] / (1024 * 1024)
                print(f"  • {artifact_type}: {info['path']} ({size_mb:.2f} MB)")
            else:
                print(f"  • {artifact_type}: Not available")
        
        return metadata
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def demo_custom_output():
    """Demonstrate custom output directory and format."""
    print("\n🎬 Demo 2: Custom Output Directory and YAML Format")
    print("=" * 50)
    
    url = "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851"
    
    # Create extractor with custom output directory
    extractor = KBSExtractor(output_dir="custom_output")
    
    try:
        # Process with YAML format
        metadata = extractor.process_url(url, output_format='yaml')
        
        print(f"✅ Processed with custom settings")
        print(f"📁 Custom output directory: {extractor.output_dir}")
        print(f"📄 YAML metadata file: {metadata['metadata_file']}")
        
        return metadata
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def demo_programmatic_usage():
    """Demonstrate programmatic usage and custom processing."""
    print("\n🎬 Demo 3: Programmatic Usage")
    print("=" * 50)
    
    url = "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851"
    extractor = KBSExtractor(output_dir="programmatic_output")
    
    try:
        # Step-by-step processing
        print("📥 Fetching page content...")
        title, video_url, transcript = extractor.extract_page_content(url)
        
        print(f"📰 Title: {title}")
        print(f"🎥 Video URL: {video_url if video_url else 'Not found'}")
        print(f"📝 Transcript length: {len(transcript)} characters")
        
        # Save transcript manually
        safe_title = title.replace(' ', '-').replace('/', '-')[:30]
        transcript_path = extractor.output_dir / f"{safe_title}_manual_transcript.txt"
        
        with open(transcript_path, 'w', encoding='utf-8') as f:
            f.write(transcript)
        
        print(f"💾 Manual transcript saved: {transcript_path}")
        
        # Enhance transcript with Claude
        print("🤖 Enhancing transcript with Claude...")
        enhanced_transcript = extractor.enhance_transcript_with_claude(transcript, title)
        
        enhanced_path = extractor.output_dir / f"{safe_title}_enhanced_manual.txt"
        with open(enhanced_path, 'w', encoding='utf-8') as f:
            f.write(enhanced_transcript)
        
        print(f"✨ Enhanced transcript saved: {enhanced_path}")
        
        return {
            'title': title,
            'video_url': video_url,
            'transcript_path': str(transcript_path),
            'enhanced_path': str(enhanced_path)
        }
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None


def demo_batch_processing():
    """Demonstrate batch processing of multiple URLs."""
    print("\n🎬 Demo 4: Batch Processing")
    print("=" * 50)
    
    # Example URLs (you can add more)
    urls = [
        "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851",
        # Add more KBS news URLs here for batch processing
    ]
    
    extractor = KBSExtractor(output_dir="batch_output")
    results = []
    
    for i, url in enumerate(urls, 1):
        print(f"📰 Processing URL {i}/{len(urls)}: {url}")
        
        try:
            metadata = extractor.process_url(url)
            results.append({
                'url': url,
                'title': metadata['title'],
                'success': True,
                'metadata_file': metadata['metadata_file']
            })
            print(f"✅ Success: {metadata['title']}")
            
        except Exception as e:
            results.append({
                'url': url,
                'title': 'Failed',
                'success': False,
                'error': str(e)
            })
            print(f"❌ Failed: {e}")
    
    # Save batch results
    batch_results_path = extractor.output_dir / "batch_results.json"
    with open(batch_results_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    print(f"\n📊 Batch processing completed!")
    print(f"📄 Results saved: {batch_results_path}")
    print(f"✅ Successful: {sum(1 for r in results if r['success'])}")
    print(f"❌ Failed: {sum(1 for r in results if not r['success'])}")
    
    return results


def show_usage_examples():
    """Show command-line usage examples."""
    print("\n🎬 Command-Line Usage Examples")
    print("=" * 50)
    
    examples = [
        {
            'description': 'Basic usage',
            'command': 'python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851"'
        },
        {
            'description': 'Custom output directory',
            'command': 'python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851" --output-dir my_news'
        },
        {
            'description': 'YAML metadata format',
            'command': 'python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851" --format yaml'
        },
        {
            'description': 'Combined options',
            'command': 'python kbs_extractor.py "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851" --output-dir news_archive --format yaml'
        }
    ]
    
    for i, example in enumerate(examples, 1):
        print(f"{i}. {example['description']}:")
        print(f"   {example['command']}")
        print()


def main():
    """Run all demonstrations."""
    print("🚀 KBS News Extractor - Demonstration Script")
    print("=" * 60)
    
    # Check if virtual environment is activated
    if not hasattr(sys, 'real_prefix') and not (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print("⚠️  Warning: Virtual environment not detected.")
        print("   Please activate the virtual environment first:")
        print("   source venv/bin/activate")
        print()
    
    # Check environment variables
    if not os.getenv('ANTHROPIC_API_KEY'):
        print("⚠️  Warning: ANTHROPIC_API_KEY not found in environment.")
        print("   Please set it in your .env file for full functionality.")
        print()
    
    try:
        # Run demonstrations
        demo_basic_usage()
        demo_custom_output()
        demo_programmatic_usage()
        demo_batch_processing()
        show_usage_examples()
        
        print("\n🎉 All demonstrations completed!")
        print("\n📁 Check the following output directories:")
        print("   • demo_output/")
        print("   • custom_output/")
        print("   • programmatic_output/")
        print("   • batch_output/")
        
    except KeyboardInterrupt:
        print("\n\n⏹️  Demonstration interrupted by user.")
    except Exception as e:
        print(f"\n❌ Demonstration failed: {e}")


if __name__ == '__main__':
    main()

