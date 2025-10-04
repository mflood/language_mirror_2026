#!/usr/bin/env python3
"""
Project Summary for KBS News Extractor

This script provides an overview of the project structure and capabilities.
"""

import os
from pathlib import Path


def show_project_structure():
    """Display the project structure."""
    print("📁 Project Structure")
    print("=" * 50)
    
    project_files = [
        ("kbs_extractor.py", "Main extraction script with KBSExtractor class"),
        ("setup.py", "Setup script for environment and dependencies"),
        ("test_setup.py", "Test script to verify installation"),
        ("demo.py", "Demonstration script with usage examples"),
        ("requirements.txt", "Python dependencies"),
        ("README.md", "Documentation and usage instructions"),
        (".gitignore", "Git ignore file for Python projects"),
        ("env.example", "Environment variables template"),
        ("venv/", "Python virtual environment (created by setup)"),
        ("output/", "Default output directory for extracted content")
    ]
    
    for filename, description in project_files:
        status = "✅" if Path(filename).exists() else "❌"
        print(f"{status} {filename:<20} - {description}")


def show_capabilities():
    """Display the script capabilities."""
    print("\n🚀 Capabilities")
    print("=" * 50)
    
    capabilities = [
        "🎥 Video Download: Uses yt-dlp to download videos from KBS news articles",
        "🎵 Audio Extraction: Extracts audio from videos using FFmpeg",
        "📝 Transcript Processing: Extracts and enhances transcripts using Claude AI",
        "📊 Metadata Generation: Creates JSON/YAML metadata files with artifact information",
        "🔧 Robust Error Handling: Handles various edge cases and provides detailed logging",
        "🌐 Web Scraping: Parses KBS news pages to extract content and video URLs",
        "🤖 AI Enhancement: Uses Claude to clean and enhance extracted transcripts",
        "📁 Organized Output: Creates structured output with meaningful filenames",
        "⚙️ Configurable: Supports custom output directories and metadata formats",
        "🧪 Testing: Includes comprehensive test suite and setup verification"
    ]
    
    for capability in capabilities:
        print(f"  {capability}")


def show_usage_modes():
    """Display different usage modes."""
    print("\n💡 Usage Modes")
    print("=" * 50)
    
    modes = [
        {
            "mode": "Command Line",
            "description": "Direct command-line usage with arguments",
            "example": "python kbs_extractor.py <URL> [options]"
        },
        {
            "mode": "Programmatic",
            "description": "Import and use the KBSExtractor class in your code",
            "example": "from kbs_extractor import KBSExtractor"
        },
        {
            "mode": "Batch Processing",
            "description": "Process multiple URLs in sequence",
            "example": "Use demo.py or create custom batch scripts"
        },
        {
            "mode": "Custom Integration",
            "description": "Integrate with other tools and workflows",
            "example": "Extend KBSExtractor class for specific needs"
        }
    ]
    
    for mode in modes:
        print(f"📌 {mode['mode']}")
        print(f"   {mode['description']}")
        print(f"   Example: {mode['example']}")
        print()


def show_output_structure():
    """Display the output structure."""
    print("📦 Output Structure")
    print("=" * 50)
    
    output_files = [
        ("article-title_video.mp4", "Downloaded video file (if available)"),
        ("article-title_audio.mp3", "Extracted audio file (if video available)"),
        ("article-title_transcript.txt", "Raw transcript from page content"),
        ("article-title_enhanced_transcript.txt", "Claude-enhanced transcript"),
        ("metadata.json", "Metadata file with artifact information")
    ]
    
    print("Generated files in output directory:")
    for filename, description in output_files:
        print(f"  📄 {filename:<35} - {description}")


def show_metadata_example():
    """Show an example of the metadata structure."""
    print("\n📊 Metadata Example")
    print("=" * 50)
    
    example_metadata = {
        "original_url": "https://news.kbs.co.kr/news/pc/view/view.do?ncd=8373851",
        "title": "Article Title",
        "extraction_timestamp": "2024-01-01T12:00:00",
        "artifacts": {
            "video": {
                "path": "output/article-title_video.mp4",
                "size_bytes": 12345678
            },
            "audio": {
                "path": "output/article-title_audio.mp3",
                "size_bytes": 1234567
            },
            "transcript": {
                "path": "output/article-title_enhanced_transcript.txt",
                "size_bytes": 1234
            }
        }
    }
    
    import json
    print(json.dumps(example_metadata, indent=2, ensure_ascii=False))


def show_requirements():
    """Display system and Python requirements."""
    print("\n🔧 Requirements")
    print("=" * 50)
    
    print("System Dependencies:")
    system_deps = [
        "Python 3.8+",
        "FFmpeg (for audio/video processing)",
        "yt-dlp (for video downloading)"
    ]
    
    for dep in system_deps:
        print(f"  • {dep}")
    
    print("\nPython Dependencies:")
    python_deps = [
        "requests>=2.31.0",
        "beautifulsoup4>=4.12.0",
        "yt-dlp>=2023.12.30",
        "anthropic>=0.7.0",
        "python-dotenv>=1.0.0",
        "PyYAML>=6.0.1",
        "lxml>=4.9.0"
    ]
    
    for dep in python_deps:
        print(f"  • {dep}")
    
    print("\nEnvironment Variables:")
    env_vars = [
        "ANTHROPIC_API_KEY (required for transcript enhancement)",
        "CLAUDE_MODEL (optional, defaults to claude-3-5-sonnet-20241022)"
    ]
    
    for var in env_vars:
        print(f"  • {var}")


def show_quick_start():
    """Display quick start instructions."""
    print("\n🚀 Quick Start")
    print("=" * 50)
    
    steps = [
        "1. Run setup: python setup.py",
        "2. Activate venv: source venv/bin/activate",
        "3. Edit .env file with your ANTHROPIC_API_KEY",
        "4. Test setup: python test_setup.py",
        "5. Run extractor: python kbs_extractor.py <KBS_URL>",
        "6. Check output directory for results"
    ]
    
    for step in steps:
        print(f"  {step}")


def main():
    """Display complete project summary."""
    print("📰 KBS News Extractor - Project Summary")
    print("=" * 60)
    
    show_project_structure()
    show_capabilities()
    show_usage_modes()
    show_output_structure()
    show_metadata_example()
    show_requirements()
    show_quick_start()
    
    print("\n🎉 Project Summary Complete!")
    print("\nFor more information, see README.md or run demo.py")


if __name__ == '__main__':
    main()

