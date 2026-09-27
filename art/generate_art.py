#!/usr/bin/env python3
"""Generate exact-size art templates and AI placeholders for Fossil Finder."""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = Path(__file__).resolve().parent
TRES_DIR = ROOT

BORDER = (36, 28, 22, 255)  # #241C16
GRID = (36, 28, 22, 56)
LABEL = (36, 28, 22, 180)
CHECK_A = (210, 200, 186, 36)
CHECK_B = (70, 60, 50, 28)
EMPTY_HATCH = (36, 28, 22, 40)
OCCUPIED = (196, 176, 140, 28)

DIRT = {
    "dirt_loose": (196, 163, 106, 255),  # #C4A36A
    "dirt_packed": (139, 94, 52, 255),
    "dirt_clay": (184, 92, 56, 255),
    "rock": (138, 134, 128, 255),
}
IVORY = (247, 233, 198, 255)
IVORY_DARK = (194, 162, 124, 255)
GOLD = (228, 183, 90, 255)
GOLD_DARK = (138, 106, 40, 255)
MOUNT = (42, 32, 24, 255)

CELL = (64, 40)
TOOL = (32, 32)
SCRAP = (16, 16)

CELLS = ["dirt_loose", "dirt_packed", "dirt_clay", "rock"]
TOOLS = ["hands", "shovel", "pickaxe", "brush"]
SCRAPS = [
    "pebble",
    "shell",
    "scale",
    "seed",
    "speck",
    "sparkle",
    "glint",
    "amber",
    "opal",
    "crystal",
    "nodule",
    "flake",
]
MUSEUM = {
    "t_rex": (256, 128),
    "triceratops": (256, 128),
    "brachiosaurus": (256, 160),
    "velociraptor": (256, 128),
    "stegosaurus": (256, 128),
    "small_finds": (256, 128),
}
SCRAP_COLORS = {
    "shell": (216, 180, 138, 255),
    "scale": (143, 190, 138, 255),
    "seed": (122, 90, 50, 255),
    "speck": (201, 176, 138, 255),
    "sparkle": (255, 224, 138, 255),
    "glint": (255, 224, 138, 255),
    "amber": (224, 144, 48, 255),
    "opal": (184, 212, 232, 255),
    "crystal": (212, 238, 246, 255),
    "nodule": (138, 134, 128, 255),
    "flake": (196, 122, 58, 255),
    "pebble": (154, 122, 82, 255),
}

def parse_fossil(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    if "piece_id" not in text or "shape" not in text:
        return None
    piece = re.search(r'piece_id\s*=\s*"([^"]+)"', text)
    width = re.search(r"shape_width\s*=\s*(\d+)", text)
    shape = re.search(r"shape\s*=\s*PackedInt32Array\(([^)]*)\)", text)
    if not piece or not width or not shape:
        return None
    cells = []
    values = [int(v.strip()) for v in shape.group(1).split(",") if v.strip()]
    w = int(width.group(1))
    if w <= 0:
        return None
    for i, value in enumerate(values):
        if value != 0:
            cells.append((i % w, i // w))
    if not cells:
        bounds = (0, 0)
    else:
        bounds = (max(c[0] for c in cells) + 1, max(c[1] for c in cells) + 1)
    return {"id": piece.group(1), "cells": cells, "bounds": bounds}


def fossils() -> list[dict]:
    found = []
    seen = set()
    for path in sorted(TRES_DIR.glob("*.tres")):
        data = parse_fossil(path)
        if data is None or data["id"] in seen:
            continue
        seen.add(data["id"])
        found.append(data)
    return found


def font(size: int = 8) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default()
    except OSError:
        return ImageFont.load_default()


def new_image(size: tuple[int, int], fill=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", size, fill)


def checker(img: Image.Image, step: int = 4) -> None:
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            px[x, y] = CHECK_A if ((x // step) + (y // step)) % 2 == 0 else CHECK_B


def border(draw: ImageDraw.ImageDraw, size: tuple[int, int]) -> None:
    draw.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=BORDER)


def grid(draw: ImageDraw.ImageDraw, size: tuple[int, int], cell: tuple[int, int]) -> None:
    w, h = size
    cw, ch = cell
    x = cw
    while x < w:
        draw.line([(x, 0), (x, h - 1)], fill=GRID)
        x += cw
    y = ch
    while y < h:
        draw.line([(0, y), (w - 1, y)], fill=GRID)
        y += ch


def label(draw: ImageDraw.ImageDraw, name: str, size: tuple[int, int]) -> None:
    text = name if size[0] >= 48 else name[:8]
    draw.text((2, 1), text, fill=LABEL, font=font())


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")


def template(size: tuple[int, int], name: str, cell: tuple[int, int] | None = None, occupied=None) -> Image.Image:
    img = new_image(size)
    checker(img)
    draw = ImageDraw.Draw(img)
    if occupied is not None and cell is not None:
        occ = set(occupied)
        cw, ch = cell
        cols, rows = size[0] // cw, size[1] // ch
        for y in range(rows):
            for x in range(cols):
                box = [x * cw, y * ch, (x + 1) * cw - 1, (y + 1) * ch - 1]
                if (x, y) in occ:
                    draw.rectangle(box, fill=OCCUPIED)
                else:
                    draw.rectangle(box, fill=(36, 28, 22, 18))
                    draw.line([box[0] + 2, box[1] + 2, box[2] - 2, box[3] - 2], fill=EMPTY_HATCH)
                    draw.line([box[2] - 2, box[1] + 2, box[0] + 2, box[3] - 2], fill=EMPTY_HATCH)
    if cell is not None:
        grid(draw, size, cell)
    border(draw, size)
    label(draw, name, size)
    return img


def dither(img: Image.Image, color: tuple[int, int, int, int], seed: int) -> None:
    px = img.load()
    w, h = img.size
    dark = tuple(max(0, c - 18) for c in color[:3]) + (255,)
    light = tuple(min(255, c + 16) for c in color[:3]) + (255,)
    for y in range(h):
        for x in range(w):
            n = (x * 13 + y * 29 + seed * 17) & 7
            if n == 0:
                px[x, y] = dark
            elif n == 1:
                px[x, y] = light


def ai_cell(name: str) -> Image.Image:
    img = new_image(CELL, DIRT[name])
    dither(img, DIRT[name], sum(ord(ch) for ch in name))
    draw = ImageDraw.Draw(img)
    border(draw, CELL)
    return img


def ai_bone(data: dict) -> Image.Image:
    cols, rows = data["bounds"]
    size = (max(cols, 1) * CELL[0], max(rows, 1) * CELL[1])
    img = new_image(size)
    draw = ImageDraw.Draw(img)
    occ = set(data["cells"])
    for y in range(max(rows, 1)):
        for x in range(max(cols, 1)):
            box = [x * CELL[0] + 1, y * CELL[1] + 1, (x + 1) * CELL[0] - 2, (y + 1) * CELL[1] - 2]
            if (x, y) not in occ:
                continue
            draw.rectangle(box, fill=IVORY_DARK)
            inset = [box[0] + 6, box[1] + 5, box[2] - 6, box[3] - 5]
            if inset[2] > inset[0] and inset[3] > inset[1]:
                draw.ellipse(inset, fill=IVORY)
            draw.rectangle(box, outline=GOLD_DARK)
    return img


def put(px, x, y, color, size) -> None:
    if 0 <= x < size[0] and 0 <= y < size[1]:
        px[x, y] = color


def fill_rect(px, x0, y0, x1, y1, color, size) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(px, x, y, color, size)


def ai_tool(name: str) -> Image.Image:
    img = new_image(TOOL)
    px = img.load()
    g, d = GOLD, GOLD_DARK
    if name == "hands":
        fill_rect(px, 10, 18, 21, 26, g, TOOL)
        for x, top in ((9, 10), (13, 7), (17, 8), (21, 11)):
            fill_rect(px, x, top, x + 2, 20, g, TOOL)
    elif name == "shovel":
        for i in range(16):
            fill_rect(px, 6 + i, 24 - i, 8 + i, 26 - i, d, TOOL)
        fill_rect(px, 18, 4, 27, 14, g, TOOL)
        fill_rect(px, 16, 8, 21, 16, g, TOOL)
    elif name == "pickaxe":
        for i in range(16):
            fill_rect(px, 10 + i // 2, 24 - i, 12 + i // 2, 26 - i, d, TOOL)
        fill_rect(px, 4, 8, 27, 11, g, TOOL)
        fill_rect(px, 20, 6, 24, 14, g, TOOL)
    else:
        for i in range(14):
            fill_rect(px, 8 + i // 2, 26 - i, 10 + i // 2, 28 - i, d, TOOL)
        fill_rect(px, 16, 6, 18, 16, g, TOOL)
        fill_rect(px, 19, 5, 21, 15, g, TOOL)
        fill_rect(px, 22, 7, 24, 16, g, TOOL)
        fill_rect(px, 14, 14, 18, 18, GOLD, TOOL)
    return img


def ai_scrap(name: str) -> Image.Image:
    img = new_image(SCRAP)
    draw = ImageDraw.Draw(img)
    color = SCRAP_COLORS[name]
    if name == "shell":
        draw.arc([1, 3, 14, 14], 20, 200, fill=color, width=2)
    elif name == "scale":
        draw.polygon([(8, 1), (14, 13), (2, 13)], fill=color)
    elif name == "seed":
        draw.ellipse([4, 5, 11, 14], fill=color)
        draw.ellipse([6, 2, 9, 6], fill=color)
    elif name in ("sparkle", "glint"):
        draw.line([(1, 8), (14, 8)], fill=color)
        draw.line([(8, 1), (8, 14)], fill=color)
        draw.point((8, 8), fill=(255, 246, 208, 255))
    elif name == "crystal":
        draw.polygon([(8, 1), (13, 13), (3, 13)], fill=color)
    elif name == "flake":
        draw.polygon([(2, 5), (12, 2), (13, 12), (3, 13)], fill=color)
    elif name == "speck":
        draw.ellipse([5, 6, 10, 11], fill=color)
        draw.ellipse([8, 4, 12, 8], fill=color)
    else:
        draw.ellipse([2, 2, 13, 13], fill=color)
        if name == "nodule":
            draw.ellipse([8, 6, 14, 13], fill=tuple(max(0, c - 20) for c in color[:3]) + (255,))
        if name == "opal":
            draw.ellipse([6, 4, 11, 8], fill=(232, 246, 255, 255))
        if name == "amber":
            draw.ellipse([4, 4, 8, 8], fill=(255, 208, 120, 255))
    return img


def ai_museum(name: str, size: tuple[int, int]) -> Image.Image:
    img = new_image(size, MOUNT)
    draw = ImageDraw.Draw(img)
    ivory = IVORY
    w, h = size
    body = [int(w * 0.28), int(h * 0.42), int(w * 0.78), int(h * 0.72)]
    if name == "brachiosaurus":
        draw.rectangle(body, fill=ivory)
        draw.rectangle([int(w * 0.22), int(h * 0.12), int(w * 0.34), int(h * 0.48)], fill=ivory)
        draw.rectangle([int(w * 0.08), int(h * 0.10), int(w * 0.26), int(h * 0.22)], fill=ivory)
        draw.rectangle([int(w * 0.72), int(h * 0.54), int(w * 0.92), int(h * 0.64)], fill=ivory)
    elif name == "small_finds":
        draw.rectangle([18, 28, 70, 88], outline=GOLD, width=2)
        draw.rectangle([92, 28, 144, 88], outline=GOLD, width=2)
        draw.rectangle([166, 28, 236, 88], outline=GOLD, width=2)
        draw.ellipse([34, 44, 54, 70], fill=ivory)
        draw.rectangle([108, 48, 128, 72], fill=ivory)
        draw.polygon([(201, 40), (226, 76), (176, 76)], fill=IVORY_DARK)
    elif name == "triceratops":
        draw.rectangle(body, fill=ivory)
        draw.ellipse([int(w * 0.10), int(h * 0.28), int(w * 0.36), int(h * 0.70)], fill=ivory)
        draw.rectangle([int(w * 0.16), int(h * 0.14), int(w * 0.20), int(h * 0.34)], fill=ivory)
        draw.rectangle([int(w * 0.24), int(h * 0.12), int(w * 0.28), int(h * 0.34)], fill=ivory)
    elif name == "stegosaurus":
        draw.rectangle(body, fill=ivory)
        for i, x in enumerate((0.36, 0.48, 0.60)):
            peak = int(h * (0.18 if i == 1 else 0.24))
            draw.polygon(
                [(int(w * x), peak), (int(w * (x + 0.08)), int(h * 0.46)), (int(w * (x - 0.08)), int(h * 0.46))],
                fill=ivory,
            )
    elif name == "velociraptor":
        draw.rectangle([int(w * 0.30), int(h * 0.46), int(w * 0.62), int(h * 0.64)], fill=ivory)
        draw.rectangle([int(w * 0.58), int(h * 0.50), int(w * 0.88), int(h * 0.58)], fill=ivory)
        draw.rectangle([int(w * 0.16), int(h * 0.36), int(w * 0.34), int(h * 0.50)], fill=ivory)
    else:
        draw.rectangle(body, fill=ivory)
        draw.rectangle([int(w * 0.10), int(h * 0.30), int(w * 0.34), int(h * 0.50)], fill=ivory)
        draw.rectangle([int(w * 0.72), int(h * 0.50), int(w * 0.92), int(h * 0.60)], fill=ivory)
    for x in (int(w * 0.34), int(w * 0.46), int(w * 0.58), int(w * 0.70)):
        draw.rectangle([x, int(h * 0.68), x + 8, int(h * 0.90)], fill=IVORY_DARK)
    border(draw, size)
    return img


def keep(folder: Path) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    keep_path = folder / ".gitkeep"
    if not keep_path.exists():
        keep_path.write_text("", encoding="utf-8")


def main() -> None:
    kinds = ["cells", "bones", "tools", "scraps", "museum"]
    for kind in kinds:
        keep(ART / "final" / kind)
        (ART / "templates" / kind).mkdir(parents=True, exist_ok=True)
        (ART / "ai" / kind).mkdir(parents=True, exist_ok=True)

    for name in CELLS:
        save(template(CELL, name, CELL, [(0, 0)]), ART / "templates" / "cells" / f"{name}.png")
        save(ai_cell(name), ART / "ai" / "cells" / f"{name}.png")

    for data in fossils():
        cols, rows = data["bounds"]
        size = (max(cols, 1) * CELL[0], max(rows, 1) * CELL[1])
        save(template(size, data["id"], CELL, data["cells"]), ART / "templates" / "bones" / f"{data['id']}.png")
        save(ai_bone(data), ART / "ai" / "bones" / f"{data['id']}.png")

    for name in TOOLS:
        save(template(TOOL, name, TOOL, [(0, 0)]), ART / "templates" / "tools" / f"{name}.png")
        save(ai_tool(name), ART / "ai" / "tools" / f"{name}.png")

    for name in SCRAPS:
        save(template(SCRAP, name, SCRAP, [(0, 0)]), ART / "templates" / "scraps" / f"{name}.png")
        save(ai_scrap(name), ART / "ai" / "scraps" / f"{name}.png")

    for name, size in MUSEUM.items():
        save(template(size, name, (64, 40)), ART / "templates" / "museum" / f"{name}.png")
        save(ai_museum(name, size), ART / "ai" / "museum" / f"{name}.png")

    print("wrote templates and AI placeholders under", ART)


if __name__ == "__main__":
    main()
