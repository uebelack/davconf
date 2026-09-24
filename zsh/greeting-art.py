#!/usr/bin/env python3
"""Regenerate the Synthwave '85 sun used by greeting.zsh.

The art is a circle rendered with half-block characters (two pixel rows per
text row), colour-banded top to bottom, with slits cut through the lower half
the way an outrun sun is drawn. Colours are the Synthwave '85 palette, so the
sun and the terminal theme are the same palette rather than two that rhyme.

    python3 zsh/greeting-art.py

Paste the output into the `art=( … )` array in greeting.zsh. Every line is
padded to exactly 30 display columns so the info panel beside it lines up.
"""
import math
import re

W, PIX = 15, 16                    # half-width in chars, pixel rows
COLS = W * 2
SLITS = {9, 11, 13, 14}            # pixel rows left empty -> retro stripes
STOPS = ["fede5d", "ffc85d", "ff9f45", "ff8b39",
         "fe4450", "f92aad", "fb66c4", "ff7edb"]
GRID = "\\e[38;2;3;237;249m"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def band(row):
    """Colour of a pixel row, interpolated across the gradient stops."""
    t = row / (PIX - 1) * (len(STOPS) - 1)
    a = int(t)
    b = min(a + 1, len(STOPS) - 1)
    f = t - a
    ca, cb = rgb(STOPS[a]), rgb(STOPS[b])
    return tuple(round(ca[k] + (cb[k] - ca[k]) * f) for k in range(3))


def half_width(row):
    if row in SLITS:
        return 0
    y = (row + 0.5) / PIX * 2 - 1
    return int(round(math.sqrt(max(1 - y * y, 0)) * W))


def cell(row, x):
    """One text cell: upper pixel, lower pixel -> (char, fg, bg)."""
    up, lo = half_width(row), half_width(row + 1)
    xc = x + 0.5
    u, l = abs(xc) <= up, abs(xc) <= lo
    if u and l:
        return "▀", band(row), band(row + 1)
    if u:
        return "▀", band(row), None
    if l:
        return "▄", band(row + 1), None
    return " ", None, None


def esc(fg, bg):
    parts = [f"38;2;{fg[0]};{fg[1]};{fg[2]}"]
    parts.append(f"48;2;{bg[0]};{bg[1]};{bg[2]}" if bg else "49")
    return "\\e[" + ";".join(parts) + "m"


def render():
    lines = []
    for row in range(0, PIX, 2):
        cells = [cell(row, x) for x in range(-W, W)]
        out, i = "", 0
        while i < len(cells):                       # run-length encode: the
            ch, fg, bg = cells[i]                   # bands are constant across
            n = 1                                   # a row, so one escape per
            while i + n < len(cells) and cells[i + n] == (ch, fg, bg):
                n += 1                              # run instead of per cell
            out += ch * n if ch == " " else esc(fg, bg) + ch * n + "\\e[0m"
            i += n
        lines.append(out)
    lines.append(GRID + "╲   ╲   ╲  ╲ ╲│╱ ╱  ╱   ╱   ╱" + "\\e[0m")
    lines.append(GRID + "──────────────┼──────────────" + "\\e[0m")
    return lines


if __name__ == "__main__":
    for line in render():
        visible = re.sub(r"\\e\[[0-9;]*m", "", line)
        print("  '" + line + " " * max(COLS - len(visible), 0) + "'")
