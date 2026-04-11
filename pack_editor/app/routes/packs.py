from __future__ import annotations

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth import CurrentUser, require_auth
from app.bundle_export import build_manifest, publish_pack
from app.dao import get_dao
from app.templating import templates

router = APIRouter()


@router.post("/projects/{project_id}/packs")
def create_pack(
    project_id: str,
    request: Request,
    title: str = Form(...),
    author: str = Form(""),
    user: CurrentUser = Depends(require_auth),
):
    dao = get_dao()
    project = dao.get_project(project_id)
    if not project:
        return HTMLResponse("Project not found", status_code=404)
    if not user.is_admin and not dao.is_user_in_project(project_id, user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    pack = dao.create_pack(project_id=project_id, title=title, author=author or None)
    return RedirectResponse(url=f"/packs/{pack['id']}", status_code=302)


@router.get("/packs/{pack_id}", response_class=HTMLResponse)
def pack_detail(pack_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    project = dao.get_project(pack["project_id"])
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    tracks = dao.list_tracks_for_pack(pack_id)
    return templates.TemplateResponse(
        request, "packs/detail.html",
        {"pack": pack, "project": project, "tracks": tracks, "current_user": user},
    )


@router.post("/packs/{pack_id}/edit")
def edit_pack(
    pack_id: str,
    request: Request,
    title: str = Form(...),
    author: str = Form(""),
    user: CurrentUser = Depends(require_auth),
):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    dao.update_pack(pack_id, title=title, author=author or None)
    return RedirectResponse(url=f"/packs/{pack_id}", status_code=302)


@router.post("/packs/{pack_id}/delete")
def delete_pack(
    pack_id: str,
    request: Request,
    user: CurrentUser = Depends(require_auth),
):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    project_id = pack["project_id"]
    dao.delete_pack(pack_id)
    return RedirectResponse(url=f"/projects/{project_id}", status_code=302)


@router.get("/packs/{pack_id}/publish", response_class=HTMLResponse)
def publish_confirm(pack_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    project = dao.get_project(pack["project_id"])
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    tracks = dao.list_tracks_for_pack(pack_id)
    manifest = build_manifest(dao, pack_id)
    import json
    manifest_preview = json.dumps(manifest, ensure_ascii=False, indent=2)
    return templates.TemplateResponse(
        request, "packs/publish_confirm.html",
        {
            "pack": pack,
            "project": project,
            "tracks": tracks,
            "manifest_preview": manifest_preview,
            "current_user": user,
        },
    )


@router.post("/packs/{pack_id}/publish")
def publish_execute(pack_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    pack = dao.get_pack(pack_id)
    if not pack:
        return HTMLResponse("Pack not found", status_code=404)
    project = dao.get_project(pack["project_id"])
    if not user.is_admin and not dao.is_user_in_project(pack["project_id"], user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    result = publish_pack(dao, pack_id)
    return templates.TemplateResponse(
        request, "packs/publish_done.html",
        {
            "pack": dao.get_pack(pack_id),
            "project": project,
            "result": result,
            "current_user": user,
        },
    )
