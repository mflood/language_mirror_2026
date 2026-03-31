from __future__ import annotations

from pathlib import Path
from urllib.parse import quote


def build_app_url(manifest_url: str) -> str:
    """Build a languagemirror:// URL that opens the app and triggers bundle import."""
    return f"languagemirror://bundle?url={quote(manifest_url, safe='')}"


def write_qr_png(url: str, out_path: Path, *, use_app_scheme: bool = True) -> None:
    """
    Writes a QR code PNG for the given URL.

    If use_app_scheme is True (default), wraps the URL in a
    languagemirror://bundle?url=... scheme so scanning opens the app directly.
    Dependency: qrcode[pil]
    """
    import qrcode

    qr_url = build_app_url(url) if use_app_scheme else url
    img = qrcode.make(qr_url)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


