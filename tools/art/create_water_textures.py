"""Generate tileable texture maps for the stylized water material."""

from __future__ import annotations

import math
from pathlib import Path
import struct
import zlib


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = PROJECT_ROOT / "assets" / "textures" / "world" / "water"
SIZE = 256


def periodic_height(u: float, v: float, variant: int) -> float:
    """Small tileable height function used to derive water normals/noise."""
    phases = (
        (1.0, 2.0, 0.30, 0.0),
        (2.0, 1.0, 0.20, 1.7),
        (3.0, 5.0, 0.16, 2.4),
        (6.0, 4.0, 0.08, 4.1),
        (9.0, 7.0, 0.05, 5.6),
    )
    total = 0.0
    for fx, fy, amp, phase in phases:
        phase += float(variant) * 1.913
        total += math.sin((u * fx + v * fy) * math.tau + phase) * amp
        total += math.cos((u * fy - v * fx) * math.tau + phase * 0.73) * amp * 0.5
    return total


def clamp_byte(value: float) -> int:
    return max(0, min(255, int(round(value))))


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    """Write an RGBA PNG without external image libraries."""
    def chunk(name: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + name
            + data
            + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)
        )

    rows: list[bytes] = []
    for y in range(height):
        start = y * width
        row = bytearray()
        row.append(0)
        for r, g, b, a in pixels[start : start + width]:
            row.extend((r, g, b, a))
        rows.append(bytes(row))

    raw = b"".join(rows)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def make_normal_map(variant: int, strength: float) -> list[tuple[int, int, int, int]]:
    pixels: list[tuple[int, int, int, int]] = []
    step = 1.0 / float(SIZE)

    for y in range(SIZE):
        v = y / float(SIZE)
        for x in range(SIZE):
            u = x / float(SIZE)
            left = periodic_height((u - step) % 1.0, v, variant)
            right = periodic_height((u + step) % 1.0, v, variant)
            down = periodic_height(u, (v - step) % 1.0, variant)
            up = periodic_height(u, (v + step) % 1.0, variant)

            dx = (right - left) * strength
            dy = (up - down) * strength
            nx = -dx
            ny = -dy
            nz = 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            nx /= length
            ny /= length
            nz /= length

            pixels.append(
                (
                    clamp_byte((nx * 0.5 + 0.5) * 255.0),
                    clamp_byte((ny * 0.5 + 0.5) * 255.0),
                    clamp_byte((nz * 0.5 + 0.5) * 255.0),
                    255,
                )
            )
    return pixels


def make_foam_noise() -> list[tuple[int, int, int, int]]:
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(SIZE):
        v = y / float(SIZE)
        for x in range(SIZE):
            u = x / float(SIZE)
            h1 = periodic_height(u, v, 10)
            h2 = periodic_height((u * 2.0) % 1.0, (v * 2.0) % 1.0, 11) * 0.45
            value = max(0.0, min(1.0, 0.5 + h1 * 0.55 + h2))
            value = value ** 1.6
            byte = clamp_byte(value * 255.0)
            pixels.append((byte, byte, byte, 255))
    return pixels


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    write_png(OUTPUT_DIR / "water_normal_a.png", SIZE, SIZE, make_normal_map(1, 5.2))
    write_png(OUTPUT_DIR / "water_normal_b.png", SIZE, SIZE, make_normal_map(2, 3.8))
    write_png(OUTPUT_DIR / "water_foam_noise.png", SIZE, SIZE, make_foam_noise())
    print(f"Generated water textures in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
