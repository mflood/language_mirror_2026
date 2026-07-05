#!/usr/bin/env python3
"""
Generate the MiriLaunch launch-screen image assets.

The launch screen (LaunchScreen.storyboard) is a static storyboard and can't
run code, so Miri — who is normally drawn at runtime in Views/MiriView.swift —
has to be baked into a PNG here. This script reproduces MiriView's `.happy`
expression (aqua→lavender gradient body, glossy sheen, dot eyes, smile, coral
cheeks) and writes miri.png / @2x / @3x into the MiriLaunch imageset.

SUPERSEDED (2026-07-05): the MiriLaunch imageset now holds the PAINTED Miri
portrait from the brand/miri/ character-sheet work (generated via
brand/miri/generate.py, prompt_launch). Do not re-run this script unless
you deliberately want to revert to the old code-drawn flat mascot.

    python3 LanguageMirror/tools/generate_miri_launch.py

Requires Pillow (`pip install pillow`).
"""

from pathlib import Path
from PIL import Image, ImageDraw

# Output imageset (relative to this script → repo layout independent).
OUT = (Path(__file__).resolve().parent.parent
       / "LanguageMirror/2025-09-13/Assets.xcassets/MiriLaunch.imageset")

BASE_PT = 140  # points; @1x/@2x/@3x are multiples


def c(r, g, b, a=255):
    return (int(r * 255), int(g * 255), int(b * 255), a)


# Mirror of MiriView / AppColors (sRGB 0..1).
AQUA     = c(0.36, 0.82, 0.86)       # brandGradient top
LAVENDER = c(0.52, 0.56, 0.95)       # brandGradient bottom
CORAL    = c(0.98, 0.42, 0.38, 140)  # brandSecondary cheeks (~0.55 alpha)
FACE     = c(0.12, 0.12, 0.12)
SHEEN    = (255, 255, 255, 90)       # glossy highlight (~0.35 alpha)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(size: int) -> Image.Image:
    S = size * 4  # supersample for smooth edges, downscaled at the end
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # Body: slightly-squashed rounded blob (matches MiriView bodyRect insets).
    inset_x, inset_y = S * 0.06, S * 0.084
    bx0, by0 = inset_x, inset_y
    bx1, by1 = S - inset_x, S - inset_y
    bw, bh = bx1 - bx0, by1 - by0
    radius = bw * 0.46

    # Vertical aqua→lavender gradient, masked to the rounded-rect body.
    grad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gp = grad.load()
    for y in range(S):
        t = max(0.0, min(1.0, (y - by0) / bh if bh else 0.0))
        col = lerp(AQUA, LAVENDER, t) + (255,)
        for x in range(S):
            gp[x, y] = col
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([bx0, by0, bx1, by1], radius=radius, fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)

    # Glossy sheen (top-left oval).
    sx, sy = bx0 + bw * 0.16, by0 + bh * 0.12
    d.ellipse([sx, sy, sx + bw * 0.30, sy + bh * 0.20], fill=SHEEN)

    # Coral cheeks.
    cr = bw * 0.075
    for cx in (0.30, 0.70):
        x, y = bx0 + bw * cx - cr, by0 + bh * 0.58
        d.ellipse([x, y, x + cr * 2, y + cr * 2], fill=CORAL)

    # Dot eyes.
    eye_y = by0 + bh * 0.46
    eye_dx = bw * 0.20
    eye_r = bw * 0.055
    for ex in (S / 2 - eye_dx, S / 2 + eye_dx):
        d.ellipse([ex - eye_r, eye_y - eye_r, ex + eye_r, eye_y + eye_r], fill=FACE)

    # Smile.
    mcx, mcy = S / 2, by0 + bh * 0.60
    mw = bw * 0.26
    d.arc([mcx - mw / 2, mcy - mw * 0.35, mcx + mw / 2, mcy + mw * 0.55],
          start=20, end=160, fill=FACE, width=int(S * 0.018))

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for scale, name in [(1, "miri.png"), (2, "miri@2x.png"), (3, "miri@3x.png")]:
        render(BASE_PT * scale).save(OUT / name)
        print(f"wrote {name} ({BASE_PT * scale}px)")


if __name__ == "__main__":
    main()
