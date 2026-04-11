from __future__ import annotations

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth import (
    CurrentUser,
    login_admin,
    logout,
    require_admin,
    verify_admin_password,
)
from app.dao import get_dao
from app.templating import templates

router = APIRouter()


@router.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    return templates.TemplateResponse(request, "login.html")


@router.post("/login")
def login_submit(request: Request, password: str = Form(...)):
    if verify_admin_password(password):
        login_admin(request)
        return RedirectResponse(url="/", status_code=302)
    return templates.TemplateResponse(request, "login.html", {"error": "Invalid password"})


@router.post("/logout")
def logout_route(request: Request):
    logout(request)
    return RedirectResponse(url="/login", status_code=302)


@router.get("/admin/users", response_class=HTMLResponse)
def admin_users(request: Request, admin: CurrentUser = Depends(require_admin)):
    dao = get_dao()
    users = dao.list_users()
    return templates.TemplateResponse(
        request, "admin/users.html",
        {"users": users, "current_user": admin},
    )


@router.post("/admin/users/invite")
def admin_invite_user(
    request: Request,
    email: str = Form(...),
    full_name: str = Form(""),
    admin: CurrentUser = Depends(require_admin),
):
    dao = get_dao()
    existing = dao.get_user_by_email(email)
    if existing:
        users = dao.list_users()
        return templates.TemplateResponse(
            request, "admin/users.html",
            {"users": users, "current_user": admin, "error": f"User {email} already exists"},
        )
    dao.create_user(email=email, full_name=full_name or None)
    return RedirectResponse(url="/admin/users", status_code=302)


@router.get("/admin/projects", response_class=HTMLResponse)
def admin_projects(request: Request, admin: CurrentUser = Depends(require_admin)):
    dao = get_dao()
    projects = dao.list_projects()
    users = dao.list_users()
    member_counts = dao.get_project_member_counts()
    pack_counts = dao.get_project_pack_counts()
    return templates.TemplateResponse(
        request, "admin/dashboard.html",
        {
            "projects": projects,
            "users": users,
            "member_counts": member_counts,
            "pack_counts": pack_counts,
            "current_user": admin,
        },
    )


@router.post("/admin/projects")
def admin_create_project(
    request: Request,
    name: str = Form(...),
    language_code: str = Form(...),
    description: str = Form(""),
    admin: CurrentUser = Depends(require_admin),
):
    dao = get_dao()
    dao.create_project(name=name, language_code=language_code, description=description or None)
    return RedirectResponse(url="/admin/projects", status_code=302)


@router.post("/admin/projects/{project_id}/assign")
def admin_assign_user(
    project_id: str,
    request: Request,
    user_id: str = Form(...),
    admin: CurrentUser = Depends(require_admin),
):
    dao = get_dao()
    dao.assign_user_to_project(project_id=project_id, user_id=user_id)
    return RedirectResponse(url="/admin/projects", status_code=302)


@router.post("/admin/projects/{project_id}/unassign")
def admin_unassign_user(
    project_id: str,
    request: Request,
    user_id: str = Form(...),
    admin: CurrentUser = Depends(require_admin),
):
    dao = get_dao()
    dao.unassign_user_from_project(project_id=project_id, user_id=user_id)
    return RedirectResponse(url="/admin/projects", status_code=302)
