from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import os
import json
import time
from typing import List, Dict, Optional
from pydantic import BaseModel
import aiofiles
# No audio processing needed - we'll use browser audio controls

app = FastAPI(title="Audio Shadow Practice", description="ADHD-friendly audio shadow practice tool")

# Create templates directory
templates = Jinja2Templates(directory="templates")

# Create static directory for CSS/JS
os.makedirs("static", exist_ok=True)
os.makedirs("templates", exist_ok=True)
os.makedirs("data", exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Data models
class AudioSlice(BaseModel):
    id: str
    start_time: float
    end_time: float

class AudioFile(BaseModel):
    filename: str
    duration: Optional[float] = None

class GlobalSettings(BaseModel):
    playback_speed: float = 1.0
    loop_count: int = 3

# JSON files for storing data
SLICES_FILE = "data/audio_slices.json"
SETTINGS_FILE = "data/global_settings.json"

async def load_slices() -> Dict[str, List[AudioSlice]]:
    """Load slices from JSON file"""
    try:
        async with aiofiles.open(SLICES_FILE, 'r') as f:
            content = await f.read()
            data = json.loads(content)
            # Convert dict data back to AudioSlice objects
            result = {}
            for filename, slices_data in data.items():
                result[filename] = [AudioSlice(**slice_data) for slice_data in slices_data]
            return result
    except (FileNotFoundError, json.JSONDecodeError):
        return {}

async def save_slices(slices: Dict[str, List[AudioSlice]]):
    """Save slices to JSON file"""
    # Convert AudioSlice objects to dict for JSON serialization
    data = {}
    for filename, slice_list in slices.items():
        data[filename] = [slice_obj.model_dump() for slice_obj in slice_list]
    
    async with aiofiles.open(SLICES_FILE, 'w') as f:
        await f.write(json.dumps(data, indent=2))

async def load_settings() -> GlobalSettings:
    """Load global settings from JSON file"""
    try:
        async with aiofiles.open(SETTINGS_FILE, 'r') as f:
            content = await f.read()
            data = json.loads(content)
            return GlobalSettings(**data)
    except (FileNotFoundError, json.JSONDecodeError):
        return GlobalSettings()

async def save_settings(settings: GlobalSettings):
    """Save global settings to JSON file"""
    async with aiofiles.open(SETTINGS_FILE, 'w') as f:
        await f.write(json.dumps(settings.model_dump(), indent=2))

@app.get("/", response_class=HTMLResponse)
async def audio_list_page(request: Request):
    """Main page showing available audio files"""
    audio_files = []
    audio_dir = "audio_files"
    
    if os.path.exists(audio_dir):
        for filename in os.listdir(audio_dir):
            if filename.lower().endswith(('.mp3', '.wav', '.m4a', '.ogg')):
                file_path = os.path.join(audio_dir, filename)
                # Duration will be determined by the browser when audio loads
                duration = None
                
                audio_files.append(AudioFile(filename=filename, duration=duration))
    
    return templates.TemplateResponse("audio_list.html", {
        "request": request,
        "audio_files": audio_files
    })

@app.get("/practice/{filename}", response_class=HTMLResponse)
async def shadow_practice_page(request: Request, filename: str):
    """Shadow practice page for a specific audio file"""
    slices_data = await load_slices()
    file_slices = slices_data.get(filename, [])
    
    return templates.TemplateResponse("shadow_practice.html", {
        "request": request,
        "filename": filename,
        "slices": file_slices
    })

@app.post("/api/slice")
async def create_slice(
    filename: str = Form(...),
    current_time: float = Form(...)
):
    """Create a new audio slice at current time"""
    slices_data = await load_slices()
    
    if filename not in slices_data:
        # Create initial full slice
        slices_data[filename] = []
        full_slice = AudioSlice(
            id="full",
            start_time=0.0,
            end_time=999999.0  # Will be updated when we know the actual duration
        )
        slices_data[filename].append(full_slice)
    
    # Find the currently playing slice and adjust its end time
    current_slice = None
    for slice_obj in slices_data[filename]:
        if slice_obj.start_time <= current_time <= slice_obj.end_time:
            current_slice = slice_obj
            break
    
    if current_slice:
        # Adjust the current slice's end time
        current_slice.end_time = current_time
        
        # Create new slice starting from current time
        slice_id = f"{int(time.time() * 1000)}"
        new_slice = AudioSlice(
            id=slice_id,
            start_time=current_time,
            end_time=999999.0  # Will be updated when we know the actual duration
        )
        slices_data[filename].append(new_slice)
        
        # Sort slices by start time to maintain order
        slices_data[filename].sort(key=lambda x: x.start_time)
        
        # Find the new slice and update its end time to match the next slice's start time
        for i, slice_obj in enumerate(slices_data[filename]):
            if slice_obj.id == slice_id:
                # If this is not the last slice, set end time to next slice's start time
                if i + 1 < len(slices_data[filename]):
                    next_slice = slices_data[filename][i + 1]
                    slice_obj.end_time = next_slice.start_time
                break
    
    await save_slices(slices_data)
    return {"success": True}

@app.delete("/api/slice/{filename}/{slice_id}")
async def delete_slice(filename: str, slice_id: str):
    """Delete an audio slice"""
    slices_data = await load_slices()
    
    if filename in slices_data:
        # Find the slice to delete
        slice_to_delete = None
        for slice_obj in slices_data[filename]:
            if slice_obj.id == slice_id:
                slice_to_delete = slice_obj
                break
        
        if slice_to_delete:
            # Sort slices by start time to maintain order
            slices_data[filename].sort(key=lambda x: x.start_time)
            
            # Find the index of the slice to delete
            delete_index = -1
            for i, slice_obj in enumerate(slices_data[filename]):
                if slice_obj.id == slice_id:
                    delete_index = i
                    break
            
            if delete_index >= 0:
                # If there's a previous slice, extend its end time to the deleted slice's end time
                if delete_index > 0:
                    previous_slice = slices_data[filename][delete_index - 1]
                    previous_slice.end_time = slice_to_delete.end_time
                
                # Remove the slice
                slices_data[filename] = [s for s in slices_data[filename] if s.id != slice_id]
        
        await save_slices(slices_data)
    
    return {"success": True}

@app.get("/api/slices/{filename}")
async def get_slices(filename: str):
    """Get all slices for an audio file"""
    slices_data = await load_slices()
    return slices_data.get(filename, [])

@app.get("/api/settings")
async def get_settings():
    """Get global settings"""
    return await load_settings()

@app.post("/api/settings")
async def update_settings(
    playback_speed: float = Form(...),
    loop_count: int = Form(...)
):
    """Update global settings"""
    settings = GlobalSettings(
        playback_speed=playback_speed,
        loop_count=loop_count
    )
    await save_settings(settings)
    return {"success": True}

@app.get("/audio/{filename}")
async def serve_audio(filename: str):
    """Serve audio files"""
    file_path = f"audio_files/{filename}"
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(file_path, media_type="audio/mpeg")

# No need for slice file serving - we use the original audio with time controls

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8056)
