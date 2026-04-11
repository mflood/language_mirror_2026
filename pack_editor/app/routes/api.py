from __future__ import annotations

from fastapi import APIRouter, Body, Depends
from fastapi.responses import JSONResponse

from app.auth import CurrentUser, require_auth
from app.dao import get_dao
from app.s3 import generate_presigned_url

router = APIRouter(prefix="/api")


# ── Audio ──────────────────────────────────────────────────────────────

@router.get("/tracks/{track_id}/audio-url")
def track_audio_url(track_id: str, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return JSONResponse({"error": "Track not found"}, status_code=404)
    pack = dao.get_pack(track["pack_id"])
    if not user.is_admin and pack and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return JSONResponse({"error": "Access denied"}, status_code=403)
    url = generate_presigned_url(track["s3_key"])
    return {"url": url, "filename": track["filename"], "duration_ms": track["duration_ms"]}


# ── Jobs ───────────────────────────────────────────────────────────────

@router.get("/jobs/{job_id}/status")
def job_status(job_id: str, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    job = dao.get_job(job_id)
    if not job:
        return JSONResponse({"error": "Job not found"}, status_code=404)
    return {
        "id": job["id"],
        "status": job["status"],
        "job_type": job["job_type"],
        "error_message": job["error_message"],
        "created_at": str(job["created_at"]) if job["created_at"] else None,
        "completed_at": str(job["completed_at"]) if job["completed_at"] else None,
    }


@router.get("/tracks/{track_id}/job-status")
def track_job_status(track_id: str, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    job = dao.get_latest_job_for_track(track_id)
    if not job:
        return {"status": "none"}
    return {
        "id": job["id"],
        "status": job["status"],
        "job_type": job["job_type"],
        "error_message": job["error_message"],
    }


# ── Clips ──────────────────────────────────────────────────────────────

@router.put("/clips/{clip_id}")
def update_clip(clip_id: str, body: dict = Body(...), user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    clip = dao.get_clip(clip_id)
    if not clip:
        return JSONResponse({"error": "Clip not found"}, status_code=404)
    updated = dao.update_clip(
        clip_id,
        start_ms=body.get("start_ms"),
        end_ms=body.get("end_ms"),
        kind=body.get("kind"),
        title=body.get("title"),
        display_order=body.get("display_order"),
    )
    return updated


@router.post("/tracks/{track_id}/clips")
def create_clip(track_id: str, body: dict = Body(...), user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return JSONResponse({"error": "Track not found"}, status_code=404)
    clip = dao.create_clip(
        track_id=track_id,
        start_ms=body.get("start_ms", 0),
        end_ms=body.get("end_ms", 1000),
        kind=body.get("kind", "drill"),
        title=body.get("title", ""),
    )
    return clip


@router.delete("/clips/{clip_id}")
def delete_clip(clip_id: str, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    clip = dao.get_clip(clip_id)
    if not clip:
        return JSONResponse({"error": "Clip not found"}, status_code=404)
    dao.delete_clip(clip_id)
    return {"ok": True}


# ── Transcript Spans ───────────────────────────────────────────────────

@router.put("/transcript-spans/{span_id}")
def update_span(span_id: str, body: dict = Body(...), user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    span = dao.get_span(span_id)
    if not span:
        return JSONResponse({"error": "Span not found"}, status_code=404)
    updated = dao.update_span(
        span_id,
        start_ms=body.get("start_ms"),
        end_ms=body.get("end_ms"),
        text=body.get("text"),
        speaker=body.get("speaker"),
        language_code=body.get("language_code"),
        display_order=body.get("display_order"),
    )
    return updated


@router.post("/tracks/{track_id}/transcript-spans")
def create_span(track_id: str, body: dict = Body(...), user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    track = dao.get_track(track_id)
    if not track:
        return JSONResponse({"error": "Track not found"}, status_code=404)
    span = dao.create_span(
        track_id=track_id,
        start_ms=body.get("start_ms", 0),
        end_ms=body.get("end_ms", 1000),
        text=body.get("text", ""),
        speaker=body.get("speaker", ""),
        language_code=body.get("language_code"),
    )
    return span


@router.delete("/transcript-spans/{span_id}")
def delete_span(span_id: str, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    span = dao.get_span(span_id)
    if not span:
        return JSONResponse({"error": "Span not found"}, status_code=404)
    dao.delete_span(span_id)
    return {"ok": True}
