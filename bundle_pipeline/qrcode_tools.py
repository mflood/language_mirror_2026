from __future__ import annotations

from pathlib import Path


def write_qr_png(url: str, out_path: Path) -> None:
    """
    Writes a QR code PNG for the given URL.
    Dependency: qrcode[pil]
    """
    import qrcode

    img = qrcode.make(url)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


