from __future__ import annotations

import logging

from authlib.integrations.starlette_client import OAuth
from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth import login_user
from app.dao import get_dao
from app.settings import settings

logger = logging.getLogger(__name__)

router = APIRouter()

oauth = OAuth()
oauth.register(
    name="google",
    client_id=settings.google_client_id,
    client_secret=settings.google_client_secret,
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={"scope": "openid email profile"},
)


@router.get("/auth/google")
async def google_login(request: Request):
    if not settings.google_client_id:
        return HTMLResponse("Google OAuth not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.", status_code=503)
    redirect_uri = request.url_for("google_callback")
    return await oauth.google.authorize_redirect(request, redirect_uri)


@router.get("/auth/google/callback")
async def google_callback(request: Request):
    try:
        token = await oauth.google.authorize_access_token(request)
    except Exception as e:
        logger.error("OAuth error: %s", e)
        return RedirectResponse(url="/login?error=oauth_failed", status_code=302)

    userinfo = token.get("userinfo", {})
    email = userinfo.get("email", "").lower().strip()
    full_name = userinfo.get("name", "")

    if not email:
        return RedirectResponse(url="/login?error=no_email", status_code=302)

    # Check if this email was invited
    dao = get_dao()
    user = dao.get_user_by_email(email)

    if not user:
        logger.warning("OAuth login rejected: %s not invited", email)
        return RedirectResponse(url="/login?error=not_invited", status_code=302)

    # Update full_name if we got one from Google and the DB doesn't have one
    if full_name and not user.get("full_name"):
        # Light touch: just update the name
        try:
            dao.update_user_name(user["id"], full_name)
        except Exception:
            pass  # Not critical

    login_user(request, user_id=user["id"], email=email)
    logger.info("OAuth login: %s (%s)", email, full_name)
    return RedirectResponse(url="/", status_code=302)
