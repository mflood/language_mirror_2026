from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi import APIRouter, Depends, Form, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth import CurrentUser, require_auth
from app.dao import get_dao
from app.s3 import generate_presigned_url, s3_key_for_track, upload_file
from app.templating import templates

router = APIRouter()

AUDIO_EXTENSIONS = {".mp3", ".m4a", ".wav", ".aac", ".flac", ".ogg", ".opus"}


def _get_duration_ms(file_path: Path) -> int | None:
    try:
        from mutagen import File as MutagenFile
        audio = MutagenFile(str(file_path))
        if audio and audio.info:
            return int(audio.info.length * 1000)
    except Exception:
        pass
    return None


def _clean_title(filename: str) -> str:
    name = Path(filename).stem
    name = name.replace("_", " ").replace("-", " ")
    return " ".join(word.capitalize() for word in name.split())


@router.post("/packs/{pack_id}/tracks/upload")
async def upload_track(
    pack_id: str,
    request: Request,
    file: UploadFile = None,
    user: CurrentUser = Depends(require_auth),
):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)

    if not file or not file.filename:
        return RedirectResponse(url=f"/packs/{pack_id}", status_code=302)

    ext = Path(file.filename).suffix.lower()
    if ext not in AUDIO_EXTENSIONS:
        return templates.TemplateResponse(
            request, "packs/detail.html",
            {
                "pack": pack,
                "project": dao.get_project(pack["project_id"]),
                "tracks": dao.list_tracks_for_pack(pack_id),
                "current_user": user,
                "error": f"Unsupported file type: {ext}. Use MP3, M4A, WAV, etc.",
            },
        )

    # Save to temp file, detect duration, upload to S3
    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        duration_ms = _get_duration_ms(tmp_path)
        s3_key = s3_key_for_track(pack["project_id"], pack_id, file.filename)
        upload_file(tmp_path, s3_key)
    finally:
        tmp_path.unlink(missing_ok=True)

    title = _clean_title(file.filename)
    display_order = dao.get_next_track_order(pack_id)
    project = dao.get_project(pack["project_id"])
    language_code = project["language_code"] if project else None

    dao.create_track(
        pack_id=pack_id,
        title=title,
        filename=file.filename,
        s3_key=s3_key,
        duration_ms=duration_ms,
        language_code=language_code,
        display_order=display_order,
    )

    return RedirectResponse(url=f"/packs/{pack_id}", status_code=302)


@router.get("/tracks/{track_id}", response_class=HTMLResponse)
def track_detail(track_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return HTMLResponse("Track not found", status_code=404)
    pack = dao.get_pack(track["pack_id"])
    project = dao.get_project(pack["project_id"]) if pack else None
    if not user.is_admin and pack and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    clips = dao.list_clips_for_track(track_id)
    spans = dao.list_spans_for_track(track_id)
    latest_job = dao.get_latest_job_for_track(track_id)
    return templates.TemplateResponse(
        request, "tracks/detail.html",
        {
            "track": track,
            "pack": pack,
            "project": project,
            "clips": clips,
            "spans": spans,
            "latest_job": latest_job,
            "current_user": user,
        },
    )


@router.post("/tracks/{track_id}/transcribe")
def request_transcription(track_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return HTMLResponse("Track not found", status_code=404)
    pack = dao.get_pack(track["pack_id"])
    if not user.is_admin and pack and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    # Check if there's already a pending/running job
    latest = dao.get_latest_job_for_track(track_id)
    if latest and latest["status"] in ("pending", "running"):
        return RedirectResponse(url=f"/tracks/{track_id}", status_code=302)
    dao.create_job(track_id=track_id, job_type="whisper")
    return RedirectResponse(url=f"/tracks/{track_id}", status_code=302)


@router.post("/tracks/{track_id}/delete")
def delete_track(track_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return HTMLResponse("Track not found", status_code=404)
    pack = dao.get_pack(track["pack_id"])
    if not user.is_admin and pack and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    from app.s3 import delete_file
    try:
        delete_file(track["s3_key"])
    except Exception:
        pass
    pack_id = track["pack_id"]
    dao.delete_track(track_id)
    return RedirectResponse(url=f"/packs/{pack_id}", status_code=302)
