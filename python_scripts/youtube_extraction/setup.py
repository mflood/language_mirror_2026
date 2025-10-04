#!/usr/bin/env python3
"""
Setup script for KBS News Extractor

This script helps set up the virtual environment and install dependencies.
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path


def run_command(cmd, description):
    """Run a command and handle errors."""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed: {e.stderr}")
        return False


def check_dependencies():
    """Check if required system dependencies are installed."""
    print("🔍 Checking system dependencies...")
    
    dependencies = {
        'python3': 'Python 3.8+',
        'ffmpeg': 'FFmpeg for audio/video processing',
        'yt-dlp': 'yt-dlp for video downloading'
    }
    
    missing = []
    
    for cmd, desc in dependencies.items():
        if shutil.which(cmd):
            print(f"✅ {desc} is installed")
        else:
            print(f"❌ {desc} is missing")
            missing.append(cmd)
    
    if missing:
        print(f"\n⚠️  Missing dependencies: {', '.join(missing)}")
        print("\nInstallation instructions:")
        
        if 'python3' in missing:
            print("• Python 3.8+: https://www.python.org/downloads/")
        
        if 'ffmpeg' in missing:
            if sys.platform == 'darwin':  # macOS
                print("• FFmpeg: brew install ffmpeg")
            elif sys.platform == 'linux':
                print("• FFmpeg: sudo apt install ffmpeg (Ubuntu/Debian)")
            else:
                print("• FFmpeg: https://ffmpeg.org/download.html")
        
        if 'yt-dlp' in missing:
            print("• yt-dlp: pip install yt-dlp")
        
        return False
    
    return True


def setup_venv():
    """Set up Python virtual environment."""
    venv_path = Path('venv')
    
    if venv_path.exists():
        print("✅ Virtual environment already exists")
        return True
    
    return run_command('python3 -m venv venv', 'Creating virtual environment')


def install_dependencies():
    """Install Python dependencies."""
    if sys.platform == 'win32':
        pip_cmd = 'venv\\Scripts\\pip'
    else:
        pip_cmd = 'venv/bin/pip'
    
    return run_command(f'{pip_cmd} install -r requirements.txt', 'Installing Python dependencies')


def create_env_file():
    """Create .env file from template if it doesn't exist."""
    env_file = Path('.env')
    env_example = Path('env.example')
    
    if env_file.exists():
        print("✅ .env file already exists")
        return True
    
    if env_example.exists():
        print("📝 Creating .env file from template...")
        try:
            with open(env_example, 'r') as src, open(env_file, 'w') as dst:
                dst.write(src.read())
            print("✅ .env file created")
            print("⚠️  Please edit .env file and add your ANTHROPIC_API_KEY")
            return True
        except Exception as e:
            print(f"❌ Failed to create .env file: {e}")
            return False
    else:
        print("❌ env.example file not found")
        return False


def main():
    """Main setup function."""
    print("🚀 Setting up KBS News Extractor...\n")
    
    # Check system dependencies
    if not check_dependencies():
        print("\n❌ Setup failed: Missing system dependencies")
        return 1
    
    # Set up virtual environment
    if not setup_venv():
        print("\n❌ Setup failed: Could not create virtual environment")
        return 1
    
    # Install Python dependencies
    if not install_dependencies():
        print("\n❌ Setup failed: Could not install Python dependencies")
        return 1
    
    # Create .env file
    if not create_env_file():
        print("\n❌ Setup failed: Could not create .env file")
        return 1
    
    print("\n🎉 Setup completed successfully!")
    print("\nNext steps:")
    print("1. Activate the virtual environment:")
    if sys.platform == 'win32':
        print("   venv\\Scripts\\activate")
    else:
        print("   source venv/bin/activate")
    
    print("2. Edit .env file and add your ANTHROPIC_API_KEY")
    print("3. Run the extractor:")
    print("   python kbs_extractor.py <KBS_NEWS_URL>")
    
    return 0


if __name__ == '__main__':
    exit(main())
