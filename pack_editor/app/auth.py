from __future__ import annotations

import logging
import secrets
from dataclasses import dataclass
from typing import Optional

from fastapi import HTTPException, Request, status

from app.settings import settings

logger = logging.getLogger(__name__)

# Session keys
SESSION_USER_ID = "user_id"
SESSION_USER_EMAIL = "user_email"
SESSION_IS_ADMIN = "is_admin"


@dataclass
class CurrentUser:
    user_id: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    is_admin: bool = False


def verify_admin_password(password: str) -> bool:
    if not settings.admin_password:
        return False
    return secrets.compare_digest(
        password.encode("utf-8"),
        settings.admin_password.encode("utf-8"),
    )


def login_admin(request: Request) -> None:
    request.session[SESSION_IS_ADMIN] = True
    request.session[SESSION_USER_EMAIL] = "admin"


def login_user(request: Request, user_id: str, email: str) -> None:
    request.session[SESSION_USER_ID] = user_id
    request.session[SESSION_USER_EMAIL] = email
    request.session[SESSION_IS_ADMIN] = False


def logout(request: Request) -> None:
    request.session.clear()


def require_auth(request: Request) -> CurrentUser:
    """FastAPI dependency: any authenticated user."""
    is_admin = request.session.get(SESSION_IS_ADMIN, False)
    user_id = request.session.get(SESSION_USER_ID)
    email = request.session.get(SESSION_USER_EMAIL)

    if is_admin:
        return CurrentUser(is_admin=True, email="admin")

    if user_id and email:
        return CurrentUser(user_id=user_id, email=email, full_name=request.session.get("user_full_name"))

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Not authenticated",
    )


def require_admin(request: Request) -> CurrentUser:
    """FastAPI dependency: admin only."""
    is_admin = request.session.get(SESSION_IS_ADMIN, False)
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin access required",
        )
    return CurrentUser(is_admin=True, email="admin")
