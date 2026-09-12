#!/usr/bin/env python3
"""Render the Synthwave '85 images used by the Chrome theme.

    python3 chrome/theme-art.py

Writes chrome/theme/images/{frame,toolbar,ntp}.png from the same palette as
ghostty/config and the terminal greeting, so the browser, the terminal and the
sun in the greeting are one palette rather than three that rhyme.

Pure stdlib on purpose — this repo cannot assume Pillow is installed. The PNG
encoder at the bottom is zlib plus a CRC, and the antialiasing falls out of
drawing every line as a distance-based glow instead of a hard edge.

The images are committed, so a fresh checkout can load the theme without
running this. Re-run it after changing anything below; chrome/update.sh does
that for you when this file is newer than what it produced.
"""
import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent / "theme" / "images"

# ── Palette ────────────────────────────────────────────────────────────────
INDIGO = (0x1a, 0x10, 0x33)        # background, the midnight sky
DEEP = (0x24, 0x1b, 0x3a)          # ANSI black, the toolbar
PINK = (0xf9, 0x2a, 0xad)          # the foreground pink
HOTPINK = (0xff, 0x7e, 0xdb)       # neon magenta
CYAN = (0x00, 0xf0, 0xff)          # miami teal, the grid
GOLD = (0xfe, 0xde, 0x5d)          # sunset gold
ORANGE = (0xff, 0x8b, 0x39)
CORAL = (0xfe, 0x44, 0x50)
LILAC = (0xd4, 0xc8, 0xff)         # ANSI white, the stars

# Sun gradient, top to bottom — the greeting's STOPS, as RGB.
SUN = [GOLD, (0xff, 0xc8, 0x5d), (0xff, 0x9f, 0x45), ORANGE,
       CORAL, PINK, HOTPINK, (0xff, 0xb8, 0xf3)]

# Slits cut through the lower half of the sun, as (start, end) in disc height.
# They widen downward, the way an outrun sun is drawn.
SLITS = [(0.56, 0.585), (0.64, 0.675), (0.73, 0.78), (0.83, 0.90), (0.94, 1.0)]


def clamp01(t):
    return 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)


def ramp(stops, t):
    """Colour t (0..1) along an evenly spaced gradient."""
    t = clamp01(t) * (len(stops) - 1)
    a = min(int(t), len(stops) - 2)
    f = t - a
    ca, cb = stops[a], stops[a + 1]
    return tuple(ca[k] + (cb[k] - ca[k]) * f for k in range(3))


def blend(row, x, color, alpha):
    """Paint `color` over the pixel at x with coverage `alpha`."""
    if alpha <= 0.0:
        return
    if alpha > 1.0:
        alpha = 1.0
    i = x * 3
    for k in range(3):
        row[i + k] = int(row[i + k] + (color[k] - row[i + k]) * alpha + 0.5)


def glow(row, x, color, amount):
    """Add light at the pixel at x — neon, so it clips to white, not to grey."""
    if amount <= 0.0:
        return
    i = x * 3
    for k in range(3):
        v = row[i + k] + color[k] * amount
        row[i + k] = 255 if v > 255 else int(v)


def solid_row(width, color):
    return bytearray(bytes(int(c + 0.5) for c in color) * width)


# ── Window frame and toolbar ───────────────────────────────────────────────
# Both tile horizontally across the window, so the pattern has to meet itself:
# everything varies as a cosine of x, which is seamless by construction.

def bar(width, height, base, tint_top, tint_bottom, strength, fade):
    rows = []
    for y in range(height):
        v = (1.0 - y / (height - 1)) ** fade
        row = bytearray(width * 3)
        for x in range(width):
            t = x / width
            m = max(0.0, math.cos(2 * math.pi * (t - 0.25))) ** 3
            c = max(0.0, math.cos(2 * math.pi * (t - 0.75))) ** 3
            px = [float(k) for k in base]
            for k in range(3):
                px[k] += tint_top[k] * m * v * strength
                px[k] += tint_bottom[k] * c * v * strength * 0.7
            # Faint scanlines, the CRT tell.
            if y % 4 == 3:
                for k in range(3):
                    px[k] *= 0.94
            i = x * 3
            for k in range(3):
                row[i + k] = 255 if px[k] > 255 else int(px[k])
        rows.append(row)
    return rows


def render_frame():
    return bar(1600, 160, INDIGO, PINK, CYAN, strength=0.30, fade=2.2)


def render_toolbar():
    return bar(1600, 120, DEEP, HOTPINK, CYAN, strength=0.13, fade=3.0)


# ── New-tab background: the outrun scene ───────────────────────────────────
W, H = 2560, 1440
HORIZON = int(H * 0.58)
FLOOR = H - HORIZON
CX = W // 2
RADIUS = 380
CY = HORIZON - int(RADIUS * 0.80)

SKY = [INDIGO, (0x22, 0x14, 0x40), (0x3d, 0x18, 0x5e),
       (0x7a, 0x1e, 0x74), (0xc4, 0x2a, 0x8f), PINK]
GROUND = [(0x2a, 0x16, 0x4c), (0x1d, 0x10, 0x38), (0x12, 0x09, 0x24)]


def horizontal_lines():
    """y of each floor line — dense at the horizon, spread out up close."""
    n = 26
    return [HORIZON + FLOOR * (i / n) ** 2.3 for i in range(1, n + 1)]


def render_ntp():
    rows = []
    stars = random.Random(85)
    lines = horizontal_lines()

    for y in range(H):
        if y < HORIZON:
            t = y / HORIZON
            row = solid_row(W, ramp(SKY, t ** 2.6))
        else:
            s = (y - HORIZON) / FLOOR
            row = solid_row(W, ramp(GROUND, s))
            # Floor lines: nearest-line distance, as a glow rather than an edge.
            d = min(abs(y - ly) for ly in lines)
            width = 1.0 + 2.5 * s
            a = math.exp(-(d / width) ** 2) * (0.22 + 0.78 * s)
            if a > 0.004:
                for x in range(W):
                    glow(row, x, CYAN, a * 0.85)
        rows.append(row)

    # Stars — thin above, gone before the sky starts to burn.
    for _ in range(900):
        y = int(stars.triangular(0, HORIZON * 0.82, 0))
        x = stars.randrange(W)
        if abs(x - CX) < RADIUS * 1.5 and y > CY - RADIUS * 1.6:
            continue
        glow(rows[y], x, LILAC, stars.uniform(0.2, 0.95))

    # Floor lines running to the vanishing point.
    for y in range(HORIZON, H):
        s = (y - HORIZON) / FLOOR
        row = rows[y]
        spacing = 150 * s
        if spacing < 0.6:
            continue
        width = 0.8 + 1.6 * s
        a = 0.18 + 0.82 * s
        k = 0
        while True:
            dx = k * spacing
            if dx - 3 * width > W / 2 + 200:
                break
            for x0 in ({CX + dx, CX - dx} if k else {CX}):
                lo = int(x0 - 3 * width)
                hi = int(x0 + 3 * width) + 1
                for x in range(max(0, lo), min(W, hi)):
                    glow(row, x, CYAN, a * math.exp(-((x - x0) / width) ** 2) * 0.9)
            k += 1

    # The horizon itself: a hot line where sky meets grid.
    for y in range(HORIZON - 90, HORIZON + 70):
        if not 0 <= y < H:
            continue
        d = y - HORIZON
        a = math.exp(-(d / (26.0 if d < 0 else 16.0)) ** 2)
        row = rows[y]
        for x in range(W):
            glow(row, x, HOTPINK, a * 0.55)

    # The sun, and the light it throws.
    top = CY - RADIUS
    reach = int(RADIUS * 1.75)
    for y in range(max(0, CY - reach), min(H, CY + reach)):
        row = rows[y]
        dy = y - CY
        for x in range(max(0, CX - reach), min(W, CX + reach)):
            dx = x - CX
            dist = math.hypot(dx, dy)
            if dist > RADIUS:
                halo = math.exp(-((dist - RADIUS) / (RADIUS * 0.42)) ** 2)
                glow(row, x, PINK if y > CY else HOTPINK, halo * 0.34)
                continue
            if y >= HORIZON:
                # Below the horizon the grid wins, but the disc still has to
                # throw as much light as its rim does, or it reads as a hole.
                glow(row, x, PINK, 0.34)
                continue
            v = (y - top) / (2 * RADIUS)
            if any(lo <= v <= hi for lo, hi in SLITS):
                continue
            # Coverage at the rim, so the disc has a clean antialiased edge.
            blend(row, x, ramp(SUN, v), min(1.0, RADIUS - dist + 0.5))

    return rows


# ── PNG ────────────────────────────────────────────────────────────────────

def write_png(path, rows):
    width = len(rows[0]) // 3
    raw = bytearray()
    for row in rows:
        raw.append(0)                      # filter: none
        raw.extend(row)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, len(rows), 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    path.write_bytes(png)
    print(f"    {path.name:<16} {width}x{len(rows)}  {len(png) / 1024:.0f} KiB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, render in (("frame", render_frame),
                         ("toolbar", render_toolbar),
                         ("ntp", render_ntp)):
        write_png(OUT / f"{name}.png", render())


if __name__ == "__main__":
    main()
