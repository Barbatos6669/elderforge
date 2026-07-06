"""Generate the first world texture atlas for terrain and modular props.

The atlas is intentionally deterministic. Artists can edit this script or paint
over the generated PNG later, while programmers can keep using the JSON metadata
to find stable tile coordinates.
"""

from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ATLAS_DIR = PROJECT_ROOT / "assets" / "textures" / "world" / "atlas"
ATLAS_PATH = ATLAS_DIR / "world_texture_atlas.png"
PREVIEW_PATH = ATLAS_DIR / "world_texture_atlas_preview.png"
METADATA_PATH = ATLAS_DIR / "world_texture_atlas.json"

CELL_SIZE = 256
GUTTER = 8
TILE_SIZE = CELL_SIZE - (GUTTER * 2)
COLUMNS = 4
ROWS = 4
ATLAS_SIZE = CELL_SIZE * COLUMNS

Color = tuple[int, int, int, int]
TilePainter = Callable[[ImageDraw.ImageDraw, tuple[int, int, int, int], random.Random], None]


def main() -> None:
    ATLAS_DIR.mkdir(parents=True, exist_ok=True)

    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 255))
    draw = ImageDraw.Draw(atlas, "RGBA")

    metadata = {
        "texture": "res://assets/textures/world/atlas/world_texture_atlas.png",
        "atlas_size": [ATLAS_SIZE, ATLAS_SIZE],
        "cell_size": CELL_SIZE,
        "tile_size": TILE_SIZE,
        "gutter": GUTTER,
        "tiles": {},
    }

    for index, tile in enumerate(TILES):
        column = index % COLUMNS
        row = index // COLUMNS
        cell = (
            column * CELL_SIZE,
            row * CELL_SIZE,
            (column + 1) * CELL_SIZE,
            (row + 1) * CELL_SIZE,
        )
        inner = (
            cell[0] + GUTTER,
            cell[1] + GUTTER,
            cell[0] + GUTTER + TILE_SIZE,
            cell[1] + GUTTER + TILE_SIZE,
        )

        tile["painter"](draw, cell, random.Random(tile["seed"]))
        draw.rectangle(cell, outline=(22, 18, 13, 255), width=2)

        u0 = inner[0] / ATLAS_SIZE
        v0 = inner[1] / ATLAS_SIZE
        u1 = inner[2] / ATLAS_SIZE
        v1 = inner[3] / ATLAS_SIZE
        metadata["tiles"][tile["id"]] = {
            "display_name": tile["name"],
            "category": tile["category"],
            "cell": [column, row],
            "rect_px": [inner[0], inner[1], TILE_SIZE, TILE_SIZE],
            "uv_rect": [round(u0, 6), round(v0, 6), round(u1, 6), round(v1, 6)],
        }

    atlas.save(ATLAS_PATH)
    _save_preview(atlas, metadata)
    METADATA_PATH.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    print(f"Wrote {ATLAS_PATH.relative_to(PROJECT_ROOT)}")
    print(f"Wrote {PREVIEW_PATH.relative_to(PROJECT_ROOT)}")
    print(f"Wrote {METADATA_PATH.relative_to(PROJECT_ROOT)}")


def _save_preview(atlas: Image.Image, metadata: dict) -> None:
    preview = atlas.copy()
    draw = ImageDraw.Draw(preview, "RGBA")
    for tile_id, info in metadata["tiles"].items():
        x = info["cell"][0] * CELL_SIZE
        y = info["cell"][1] * CELL_SIZE
        label = tile_id.replace("_", " ")
        draw.rectangle((x + 8, y + CELL_SIZE - 34, x + CELL_SIZE - 8, y + CELL_SIZE - 8), fill=(0, 0, 0, 150))
        draw.text((x + 14, y + CELL_SIZE - 29), label, fill=(245, 238, 212, 255))
    preview.save(PREVIEW_PATH)


def _noise(base: tuple[int, int, int], amount: int, rng: random.Random) -> Color:
    return (
        _clamp(base[0] + rng.randint(-amount, amount)),
        _clamp(base[1] + rng.randint(-amount, amount)),
        _clamp(base[2] + rng.randint(-amount, amount)),
        255,
    )


def _clamp(value: int) -> int:
    return max(0, min(255, value))


def _fill_block_noise(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    base: tuple[int, int, int],
    amount: int,
    rng: random.Random,
    block: int = 8,
) -> None:
    x0, y0, x1, y1 = rect
    for y in range(y0, y1, block):
        for x in range(x0, x1, block):
            draw.rectangle((x, y, min(x + block, x1), min(y + block, y1)), fill=_noise(base, amount, rng))


def _draw_facets(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    colors: list[tuple[int, int, int]],
    rng: random.Random,
    count: int = 34,
) -> None:
    x0, y0, x1, y1 = rect
    for _ in range(count):
        cx = rng.randint(x0, x1)
        cy = rng.randint(y0, y1)
        radius = rng.randint(28, 80)
        points = []
        for _point in range(rng.randint(3, 5)):
            points.append((cx + rng.randint(-radius, radius), cy + rng.randint(-radius, radius)))
        color = rng.choice(colors)
        alpha = rng.randint(35, 90)
        draw.polygon(points, fill=(color[0], color[1], color[2], alpha))


def _draw_cracks(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    rng: random.Random,
    count: int,
    color: Color = (34, 34, 34, 180),
) -> None:
    x0, y0, x1, y1 = rect
    for _ in range(count):
        x = rng.randint(x0 + 12, x1 - 12)
        y = rng.randint(y0 + 12, y1 - 12)
        points = [(x, y)]
        for _segment in range(rng.randint(2, 5)):
            x += rng.randint(-22, 22)
            y += rng.randint(-22, 22)
            points.append((x, y))
        draw.line(points, fill=color, width=rng.choice([1, 1, 2]))


def _draw_grass(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (64, 110, 58), 18, rng)
    _draw_facets(draw, rect, [(73, 134, 63), (52, 96, 50), (91, 139, 72)], rng, 42)
    x0, y0, x1, y1 = rect
    for _ in range(220):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        length = rng.randint(5, 14)
        draw.line((x, y, x + rng.randint(-2, 3), y - length), fill=(106, 164, 83, rng.randint(90, 170)), width=1)


def _draw_worn_grass(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (72, 101, 55), 16, rng)
    _draw_facets(draw, rect, [(98, 118, 70), (55, 91, 49), (126, 103, 65)], rng, 38)
    x0, y0, x1, y1 = rect
    for _ in range(28):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        draw.ellipse((x - 9, y - 4, x + 20, y + 8), fill=(112, 91, 54, rng.randint(80, 130)))


def _draw_dirt(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (108, 78, 48), 20, rng)
    _draw_facets(draw, rect, [(130, 91, 54), (82, 62, 43), (151, 112, 65)], rng, 35)
    x0, y0, x1, y1 = rect
    for _ in range(80):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        r = rng.randint(1, 5)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(80, 64, 49, rng.randint(70, 140)))


def _draw_path(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (126, 96, 61), 18, rng)
    _draw_facets(draw, rect, [(148, 117, 72), (104, 79, 51), (169, 135, 82)], rng, 34)
    x0, y0, x1, y1 = rect
    for _ in range(9):
        y = rng.randint(y0 + 16, y1 - 16)
        points = []
        for step in range(0, x1 - x0 + 24, 24):
            points.append((x0 + step, y + rng.randint(-7, 7)))
        draw.line(points, fill=(82, 62, 42, 120), width=rng.randint(2, 4))


def _draw_cut_stone(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (124, 128, 120), 17, rng)
    _draw_facets(draw, rect, [(146, 149, 139), (94, 99, 95), (168, 166, 154)], rng, 28)
    x0, y0, x1, y1 = rect
    block_w = 64
    block_h = 48
    for y in range(y0 - block_h, y1 + block_h, block_h):
        offset = 32 if ((y - y0) // block_h) % 2 else 0
        for x in range(x0 - offset, x1, block_w):
            draw.rectangle((x, y, x + block_w, y + block_h), outline=(54, 57, 55, 120), width=2)
    _draw_cracks(draw, rect, rng, 18)


def _draw_cobblestone(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (93, 97, 88), 13, rng)
    x0, y0, x1, y1 = rect
    for y in range(y0, y1, 38):
        x = x0 - rng.randint(0, 18)
        while x < x1:
            w = rng.randint(34, 58)
            h = rng.randint(28, 45)
            color = _noise((111, 115, 104), 24, rng)
            draw.rounded_rectangle((x, y, x + w, y + h), radius=7, fill=color, outline=(39, 41, 39, 170), width=2)
            x += w + rng.randint(3, 8)


def _draw_ruin_stone(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _draw_cut_stone(draw, rect, rng)
    x0, y0, x1, y1 = rect
    for _ in range(35):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        draw.line((x, y, x + rng.randint(-18, 18), y + rng.randint(12, 36)), fill=(58, 102, 48, 120), width=2)
    for _ in range(7):
        x = rng.randint(x0 + 20, x1 - 30)
        y = rng.randint(y0 + 20, y1 - 30)
        draw.line((x, y, x + rng.randint(-18, 18), y + rng.randint(-24, 24)), fill=(40, 190, 230, 150), width=2)


def _draw_dark_stone(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (50, 57, 58), 15, rng)
    _draw_facets(draw, rect, [(70, 78, 78), (38, 42, 44), (91, 96, 92)], rng, 38)
    _draw_cracks(draw, rect, rng, 34, (18, 21, 23, 210))
    _draw_cracks(draw, rect, rng, 12, (155, 165, 160, 120))


def _draw_planks(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (145, 88, 37), 17, rng)
    x0, y0, x1, y1 = rect
    plank_h = 42
    for y in range(y0, y1, plank_h):
        fill = _noise((151, 91, 39), 22, rng)
        draw.rectangle((x0, y, x1, min(y + plank_h, y1)), fill=fill)
        draw.line((x0, y, x1, y), fill=(69, 42, 23, 180), width=3)
        for _ in range(8):
            yy = y + rng.randint(8, plank_h - 8)
            draw.line((x0, yy, x1, yy + rng.randint(-7, 7)), fill=(198, 128, 58, 70), width=1)
        for _ in range(4):
            knot_x = rng.randint(x0 + 10, x1 - 10)
            knot_y = y + rng.randint(7, plank_h - 7)
            draw.ellipse((knot_x - 10, knot_y - 5, knot_x + 10, knot_y + 5), outline=(82, 48, 24, 120), width=2)


def _draw_bark(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (88, 57, 33), 19, rng)
    x0, y0, x1, y1 = rect
    for _ in range(60):
        x = rng.randint(x0, x1)
        points = []
        for y in range(y0 - 20, y1 + 20, 24):
            points.append((x + rng.randint(-12, 12), y))
        draw.line(points, fill=(48, 31, 20, rng.randint(95, 170)), width=rng.randint(2, 4))
    for _ in range(45):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        draw.line((x, y, x + rng.randint(-12, 12), y + rng.randint(8, 20)), fill=(150, 95, 48, 100), width=1)


def _draw_moss(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (51, 92, 43), 16, rng)
    x0, y0, x1, y1 = rect
    for _ in range(280):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        r = rng.randint(2, 9)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=_noise((79, 135, 54), 32, rng))


def _draw_vines(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (45, 76, 39), 13, rng)
    x0, y0, x1, y1 = rect
    for _ in range(18):
        x = rng.randint(x0, x1)
        points = []
        for y in range(y0, y1 + 20, 24):
            points.append((x + rng.randint(-15, 15), y))
        draw.line(points, fill=(44, 111, 46, 210), width=3)
    for _ in range(120):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        draw.ellipse((x - 7, y - 4, x + 8, y + 5), fill=_noise((72, 135, 56), 28, rng), outline=(28, 64, 26, 80))


def _draw_sand(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (176, 150, 96), 14, rng)
    _draw_facets(draw, rect, [(196, 169, 111), (148, 123, 82), (214, 188, 127)], rng, 30)
    x0, y0, x1, y1 = rect
    for _ in range(14):
        y = rng.randint(y0 + 12, y1 - 12)
        points = []
        for step in range(0, x1 - x0 + 20, 18):
            points.append((x0 + step, y + rng.randint(-4, 4)))
        draw.line(points, fill=(125, 101, 68, 75), width=2)


def _draw_cliff_rock(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (96, 95, 85), 16, rng)
    _draw_facets(draw, rect, [(133, 132, 118), (77, 78, 73), (158, 153, 135), (58, 62, 61)], rng, 55)
    _draw_cracks(draw, rect, rng, 24, (32, 34, 33, 180))


def _draw_rune_blue(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _draw_dark_stone(draw, rect, rng)
    x0, y0, x1, y1 = rect
    for _ in range(10):
        x = rng.randint(x0 + 18, x1 - 18)
        y = rng.randint(y0 + 18, y1 - 18)
        length = rng.randint(34, 78)
        color = (42, 210, 255, 230)
        draw.line((x, y, x + rng.randint(-16, 16), y - length), fill=color, width=3)
        draw.line((x - 4, y + 4, x + rng.randint(-18, 18), y - length + 4), fill=(36, 123, 179, 100), width=9)
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(147, 235, 255, 220))


def _draw_gold_trim(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], rng: random.Random) -> None:
    _fill_block_noise(draw, rect, (44, 39, 34), 10, rng)
    x0, y0, x1, y1 = rect
    for y in range(y0 + 16, y1, 48):
        draw.rectangle((x0, y, x1, y + 14), fill=(180, 125, 39, 255))
        draw.line((x0, y, x1, y), fill=(244, 205, 93, 210), width=2)
        draw.line((x0, y + 14, x1, y + 14), fill=(88, 54, 25, 220), width=2)
        for x in range(x0 + 20, x1, 42):
            draw.polygon(
                ((x, y + 7), (x + 9, y - 3), (x + 18, y + 7), (x + 9, y + 17)),
                fill=(225, 176, 61, 230),
                outline=(91, 58, 28, 180),
            )


TILES: list[dict[str, object]] = [
    {"id": "grass_meadow", "name": "Meadow Grass", "category": "terrain", "seed": 101, "painter": _draw_grass},
    {"id": "worn_grass", "name": "Worn Grass", "category": "terrain", "seed": 102, "painter": _draw_worn_grass},
    {"id": "packed_dirt", "name": "Packed Dirt", "category": "terrain", "seed": 103, "painter": _draw_dirt},
    {"id": "dirt_path", "name": "Dirt Path", "category": "terrain", "seed": 104, "painter": _draw_path},
    {"id": "cut_stone", "name": "Cut Stone", "category": "architecture", "seed": 201, "painter": _draw_cut_stone},
    {"id": "cobblestone", "name": "Cobblestone", "category": "terrain", "seed": 202, "painter": _draw_cobblestone},
    {"id": "ruin_stone", "name": "Ruin Stone", "category": "architecture", "seed": 203, "painter": _draw_ruin_stone},
    {"id": "dark_cracked_stone", "name": "Dark Cracked Stone", "category": "architecture", "seed": 204, "painter": _draw_dark_stone},
    {"id": "timber_planks", "name": "Timber Planks", "category": "architecture", "seed": 301, "painter": _draw_planks},
    {"id": "tree_bark", "name": "Tree Bark", "category": "nature", "seed": 302, "painter": _draw_bark},
    {"id": "moss", "name": "Moss", "category": "nature", "seed": 303, "painter": _draw_moss},
    {"id": "vines", "name": "Vines", "category": "nature", "seed": 304, "painter": _draw_vines},
    {"id": "sand", "name": "Sand", "category": "terrain", "seed": 401, "painter": _draw_sand},
    {"id": "cliff_rock", "name": "Cliff Rock", "category": "terrain", "seed": 402, "painter": _draw_cliff_rock},
    {"id": "blue_rune_stone", "name": "Blue Rune Stone", "category": "accent", "seed": 501, "painter": _draw_rune_blue},
    {"id": "gold_trim", "name": "Gold Trim", "category": "accent", "seed": 502, "painter": _draw_gold_trim},
]


if __name__ == "__main__":
    main()
