from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse

from app.auth import CurrentUser, require_auth
from app.dao import get_dao
from app.templating import templates

router = APIRouter()


@router.get("/", response_class=HTMLResponse)
def project_list(request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    if user.is_admin:
        projects = dao.list_projects()
    else:
        projects = dao.list_projects_for_user(user.user_id)
    return templates.TemplateResponse(
        request, "projects/list.html",
        {"projects": projects, "current_user": user},
    )


@router.get("/projects/{project_id}", response_class=HTMLResponse)
def project_detail(project_id: str, request: Request, user: CurrentUser = Depends(require_auth)):
    dao = get_dao()
    project = dao.get_project(project_id)
    if not project:
        return HTMLResponse("Project not found", status_code=404)
    if not user.is_admin and not dao.is_user_in_project(project_id, user.user_id):
        return HTMLResponse("Access denied", status_code=403)
    packs = dao.list_packs_for_project(project_id)
    members = dao.get_project_users(project_id)
    all_users = dao.list_users() if user.is_admin else []
    return templates.TemplateResponse(
        request, "projects/detail.html",
        {
            "project": project,
            "packs": packs,
            "members": members,
            "all_users": all_users,
            "current_user": user,
        },
    )
