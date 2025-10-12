#!/usr/bin/env python3
"""
Startup script for the Audio Shadow Practice FastAPI application.
Run this script to start the server on port 8056.
"""

import uvicorn
import os
import sys

def main():
    # Ensure we're in the right directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    print("🎧 Starting Audio Shadow Practice Server...")
    print("📍 Server will be available at: http://localhost:8056")
    print("🛑 Press Ctrl+C to stop the server")
    print("-" * 50)
    
    try:
        uvicorn.run(
            "main:app",
            host="0.0.0.0",
            port=8056,
            reload=True,  # Auto-reload on code changes
            log_level="info"
        )
    except KeyboardInterrupt:
        print("\n👋 Server stopped. Goodbye!")
    except Exception as e:
        print(f"❌ Error starting server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()

