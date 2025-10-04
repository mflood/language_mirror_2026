#!/usr/bin/env python3
"""
Test script to verify the KBS extractor setup.
"""

import os
import sys
import subprocess
from pathlib import Path


def test_imports():
    """Test if all required modules can be imported."""
    print("🔍 Testing Python imports...")
    
    try:
        import requests
        print("✅ requests")
    except ImportError:
        print("❌ requests - run: pip install requests")
        return False
    
    try:
        import bs4
        print("✅ beautifulsoup4")
    except ImportError:
        print("❌ beautifulsoup4 - run: pip install beautifulsoup4")
        return False
    
    try:
        import anthropic
        print("✅ anthropic")
    except ImportError:
        print("❌ anthropic - run: pip install anthropic")
        return False
    
    try:
        import yaml
        print("✅ PyYAML")
    except ImportError:
        print("❌ PyYAML - run: pip install PyYAML")
        return False
    
    try:
        from dotenv import load_dotenv
        print("✅ python-dotenv")
    except ImportError:
        print("❌ python-dotenv - run: pip install python-dotenv")
        return False
    
    return True


def test_system_dependencies():
    """Test if system dependencies are available."""
    print("\n🔍 Testing system dependencies...")
    
    # Test yt-dlp
    try:
        result = subprocess.run(['yt-dlp', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ yt-dlp {result.stdout.strip()}")
        else:
            print("❌ yt-dlp not working properly")
            return False
    except FileNotFoundError:
        print("❌ yt-dlp not found - install with: pip install yt-dlp")
        return False
    
    # Test ffmpeg
    try:
        result = subprocess.run(['ffmpeg', '-version'], capture_output=True, text=True)
        if result.returncode == 0:
            version_line = result.stdout.split('\n')[0]
            print(f"✅ ffmpeg {version_line}")
        else:
            print("❌ ffmpeg not working properly")
            return False
    except FileNotFoundError:
        print("❌ ffmpeg not found - install for your OS")
        return False
    
    return True


def test_env_file():
    """Test if .env file exists and has required variables."""
    print("\n🔍 Testing environment configuration...")
    
    env_file = Path('.env')
    if not env_file.exists():
        print("❌ .env file not found")
        return False
    
    print("✅ .env file exists")
    
    # Load environment variables
    from dotenv import load_dotenv
    load_dotenv()
    
    api_key = os.getenv('ANTHROPIC_API_KEY')
    model = os.getenv('CLAUDE_MODEL')
    
    if not api_key:
        print("❌ ANTHROPIC_API_KEY not set in .env file")
        return False
    
    if not model:
        print("❌ CLAUDE_MODEL not set in .env file")
        return False
    
    print(f"✅ ANTHROPIC_API_KEY is set")
    print(f"✅ CLAUDE_MODEL is set to: {model}")
    
    return True


def test_kbs_extractor():
    """Test if the KBS extractor can be imported."""
    print("\n🔍 Testing KBS extractor...")
    
    try:
        from kbs_extractor import KBSExtractor
        print("✅ KBS extractor can be imported")
        
        # Test creating an instance
        extractor = KBSExtractor(output_dir="test_output")
        print("✅ KBS extractor can be instantiated")
        
        return True
    except Exception as e:
        print(f"❌ KBS extractor error: {e}")
        return False


def main():
    """Run all tests."""
    print("🧪 Testing KBS News Extractor Setup\n")
    
    tests = [
        test_imports,
        test_system_dependencies,
        test_env_file,
        test_kbs_extractor
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Setup is complete.")
        print("\nYou can now run:")
        print("python kbs_extractor.py <KBS_NEWS_URL>")
        return 0
    else:
        print("❌ Some tests failed. Please fix the issues above.")
        return 1


if __name__ == '__main__':
    exit(main())
