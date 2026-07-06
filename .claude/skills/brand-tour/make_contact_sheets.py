#!/usr/bin/env python3
"""Grid a folder of screenshots into labeled contact sheets.

Usage: make_contact_sheets.py <input_dir> <output_prefix> [--cols 3] [--max-per-sheet 12]

Writes <output_prefix>_1.png, _2.png, ... with filename labels under each
tile. Requires Pillow.
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw

TILE_W = 300
LABEL_H = 22


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_dir")
    ap.add_argument("output_prefix")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--max-per-sheet", type=int, default=12)
    args = ap.parse_args()

    files = sorted(p for p in Path(args.input_dir).iterdir()
                   if p.suffix.lower() == ".png")
    if not files:
        raise SystemExit(f"no PNGs in {args.input_dir}")

    for sheet_i in range(0, len(files), args.max_per_sheet):
        chunk = files[sheet_i:sheet_i + args.max_per_sheet]
        tiles = []
        for f in chunk:
            im = Image.open(f).convert("RGB")
            h = round(im.height * TILE_W / im.width)
            tiles.append((im.resize((TILE_W, h), Image.LANCZOS), f.stem))
        tile_h = max(t[0].height for t in tiles) + LABEL_H
        cols = args.cols
        rows = math.ceil(len(tiles) / cols)
        sheet = Image.new("RGB", (cols * TILE_W, rows * tile_h), (30, 22, 28))
        draw = ImageDraw.Draw(sheet)
        for i, (im, label) in enumerate(tiles):
            x, y = (i % cols) * TILE_W, (i // cols) * tile_h
            sheet.paste(im, (x, y))
            draw.text((x + 6, y + im.height + 4), label[:40], fill=(200, 185, 160))
        out = f"{args.output_prefix}_{sheet_i // args.max_per_sheet + 1}.png"
        sheet.save(out)
        print("wrote", out, f"({len(tiles)} shots)")


if __name__ == "__main__":
    main()
