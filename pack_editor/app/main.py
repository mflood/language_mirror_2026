from __future__ import annotations

import logging
import sys
import traceback
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware

from app.settings import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stdout,
    force=True,
)

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"

app = FastAPI(title="Language Mirror Pack Editor")

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

app.add_middleware(
    SessionMiddleware,
    secret_key=settings.session_secret_key,
    max_age=86400,
    same_site="lax",
    https_only=settings.is_prod,
)

# Import routers after app is created to avoid circular imports
from app.routes.admin import router as admin_router  # noqa: E402
from app.routes.projects import router as projects_router  # noqa: E402
from app.routes.packs import router as packs_router  # noqa: E402
from app.routes.tracks import router as tracks_router  # noqa: E402
from app.routes.api import router as api_router  # noqa: E402
from app.routes.oauth import router as oauth_router  # noqa: E402

app.include_router(admin_router)
app.include_router(projects_router)
app.include_router(packs_router)
app.include_router(tracks_router)
app.include_router(api_router)
app.include_router(oauth_router)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    if exc.status_code == status.HTTP_401_UNAUTHORIZED:
        return RedirectResponse(url="/login", status_code=status.HTTP_302_FOUND)
    content = {"detail": exc.detail}
    if not settings.is_prod:
        content["traceback"] = traceback.format_exc()
    return JSONResponse(status_code=exc.status_code, content=content)


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    traceback_str = traceback.format_exc()
    logging.error(f"Unhandled: {type(exc).__name__}: {exc}\n{traceback_str}")
    content = {"detail": str(exc), "type": type(exc).__name__}
    if not settings.is_prod:
        content["traceback"] = traceback_str
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=content,
    )


@app.get("/health")
def health():
    return {"status": "ok"}
