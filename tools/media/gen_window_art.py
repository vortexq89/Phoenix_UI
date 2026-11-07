#!/usr/bin/env python3
# Copyright (c) 2026 VortexQ8 (ABDULRAHMAN ALYOUSEF). All rights reserved. See Media/LICENSE.md.
"""Phoenix settings-window art, v2 "Forge" (Nov 2026). Every pixel is generated here from seeded noise and
geometry, plus Phoenix's own wings picture (Media/Art/PhoenixWingsBG) as a faint watermark: nothing is taken
from another addon. Run from the repo root:  python3 tools/media/gen_window_art.py

Surfaces are neutral graphite so the theme colours stay in charge; the accent pieces are white with alpha and
get tinted in the game by accent.primary / accent.glow (class colour, custom colour and Phoenix orange alike).

  Media/Window/Surface.png     1600x1200  content background: cloudy stone, top light, vignette, wings watermark, hex grid
  Media/Window/Rail.png         512x1200  sidebar background: darker brushed graphite, hex grid at the foot
  Media/Window/HeaderGlow.png  1024x64    accent line under the page header: fades in from the left, flares on the right
  Media/Window/Corner.png       512x512   accent glow and sparks rising from a bottom corner (mirrored for the other)
  Media/Window/Embers.png      1024x512   drifting sparks over the foot of the page (animated in the game)
  Media/Textures/RoundCorner.tga  64x64   quarter disc for rounded fills
  Media/Textures/RoundArc{4,6,10}.tga     quarter ring for rounded 1 px borders at that corner radius
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Media", "Window")
TEX = os.path.join(ROOT, "Media", "Textures")
rng = np.random.default_rng(1797)  # fixed seed: the files are reproducible byte for byte


def fbm(w, h, octaves=6, base=4, persistence=0.55):
    """Fractal value noise in 0..1 (smooth upscaled random grids)."""
    acc = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gw, gh = base * 2 ** o + 1, int(base * 2 ** o * h / w) + 2
        grid = rng.random((gh, gw)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        acc += amp * (np.asarray(img, np.float32) / 255)
        total += amp
        amp *= persistence
    acc /= total
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)


def hexgrid(w, h, size, width=1.1):
    """Anti-aliased hexagon outline field in 0..1 (pointy-top hexes of circumradius `size`)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    s3 = np.sqrt(3)
    q = (s3 / 3 * x - y / 3) / size
    r = (2 / 3 * y) / size
    # cube round
    cx, cz = q, r
    cy = -cx - cz
    rx, ry, rz = np.round(cx), np.round(cy), np.round(cz)
    dx, dy, dz = np.abs(rx - cx), np.abs(ry - cy), np.abs(rz - cz)
    m1 = (dx > dy) & (dx > dz)
    m2 = (~m1) & (dy > dz)
    rx = np.where(m1, -ry - rz, rx)
    ry = np.where(m2, -rx - rz, ry)
    rz = np.where(~(m1 | m2), -rx - ry, rz)
    # centre of the cell, distance to the hexagon edge
    hx = size * s3 * (rx + rz / 2)
    hy = size * 1.5 * rz
    px, py = np.abs(x - hx), np.abs(y - hy)
    edge = np.maximum(px * s3 / 2 + py / 2, py) - size * s3 / 2
    return np.clip(1 - np.abs(edge) / width, 0, 1)


def radial(w, h, cx, cy, rx, ry):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)


def save_rgb(arr, name):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, name), optimize=True)


def save_alpha(alpha, name, folder=OUT, tga=False):
    a = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    rgba = np.dstack([np.full_like(a, 255)] * 3 + [a])
    img = Image.fromarray(rgba, "RGBA")
    if tga:
        img.save(os.path.join(folder, name), compression=None)
    else:
        img.save(os.path.join(folder, name), optimize=True)


def grain(h, w, amount):
    return (rng.random((h, w)).astype(np.float32) - 0.5) * 2 * amount


def wings_mask(w, h, scale):
    src = Image.open(os.path.join(ROOT, "Media", "Art", "PhoenixWingsBG.blp")).convert("L")
    tw = int(w * scale)
    th = int(src.height * tw / src.width)
    src = src.resize((tw, th), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    m = np.asarray(src, np.float32) / 255
    m = np.clip((m - 0.08) / 0.7, 0, 1) ** 1.6  # drop the dark sky, keep the feathers
    out = np.zeros((h, w), np.float32)
    x0, y0 = (w - tw) // 2, int(h * 0.30)
    hh = min(th, h - y0)
    out[y0:y0 + hh, x0:x0 + tw] = m[:hh]
    return out


def surface():
    w, h = 1600, 1200
    stone = fbm(w, h, 7, 3)
    cloud = fbm(w, h, 4, 2, 0.6)
    L = 19 + (stone - 0.5) * 9 + (cloud - 0.5) * 7
    L += np.clip(1 - radial(w, h, w * 0.5, -h * 0.15, w * 0.75, h * 0.7), 0, 1) ** 1.5 * 12  # light from the top
    L -= np.clip(radial(w, h, w / 2, h / 2, w * 0.62, h * 0.66) - 0.55, 0, 1) * 13  # vignette
    L += wings_mask(w, h, 0.78) * 13  # Phoenix watermark, grey on grey
    hx = hexgrid(w, h, 26)
    fade = np.clip(1.15 - radial(w, h, w, h, w * 0.55, h * 0.75), 0, 1) ** 2
    L += hx * fade * 9
    L += grain(h, w, 1.6)
    rgb = np.dstack([L * 1.0, L * 0.985, L * 0.97])  # a breath of warmth: graphite, not blue-black
    save_rgb(rgb, "Surface.png")


def rail():
    w, h = 512, 1200
    streak = np.asarray(Image.fromarray((rng.random((h // 8, w)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
                        np.float32) / 255  # vertical brushing
    stone = fbm(w, h, 6, 2)
    L = 13 + (streak - 0.5) * 4 + (stone - 0.5) * 5
    L += np.clip(1 - radial(w, h, w * 0.2, 0, w * 1.2, h * 0.5), 0, 1) ** 2 * 5
    hx = hexgrid(w, h, 20)
    L += hx * np.clip((np.mgrid[0:h, 0:w][0] / h - 0.62) / 0.38, 0, 1) ** 2 * 8
    L += grain(h, w, 1.4)
    save_rgb(np.dstack([L, L * 0.985, L * 0.97]), "Rail.png")


def header_glow():
    w, h = 1024, 64
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u = x / (w - 1)
    cy = 40
    env = np.clip(u / 0.55, 0, 1) ** 2 * (3 - 2 * np.clip(u / 0.55, 0, 1))  # smoothstep in from the left
    env = np.where(u > 0.82, 1 - (u - 0.82) / 0.18 * 0.75, env)
    flare = np.exp(-((u - 0.82) / 0.06) ** 2)
    core = np.exp(-((y - cy) / 0.9) ** 2)
    halo = np.exp(-((y - cy) / 6) ** 2) * 0.32
    haze = np.exp(-((y - cy + 6) / 14) ** 2) * np.where(y < cy, 1, 0.35) * 0.28 * flare
    a = (core + halo) * env + (core * 0.6 + haze + halo) * flare
    save_alpha(np.clip(a, 0, 1), "HeaderGlow.png")


def sparks(w, h, n, density_fn, size=(0.6, 2.4), streak=0.0):
    a = np.zeros((h, w), np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    placed = 0
    while placed < n:
        x, y = rng.random() * w, rng.random() * h
        if rng.random() > density_fn(x / w, y / h):
            continue
        r = rng.uniform(*size)
        bright = rng.uniform(0.35, 1.0)
        x0, x1, y0, y1 = int(max(0, x - 12 * r)), int(min(w, x + 12 * r)), int(max(0, y - 30 * r)), int(min(h, y + 12 * r))
        sx, sy = xs[y0:y1, x0:x1] - x, ys[y0:y1, x0:x1] - y
        st = 1 + streak * rng.random() * 4
        d2 = (sx / r) ** 2 + (np.where(sy < 0, sy / (r * st), sy / r)) ** 2
        a[y0:y1, x0:x1] += bright * (np.exp(-d2) + 0.18 * np.exp(-d2 / 16))
        placed += 1
    return np.clip(a, 0, 1)


def corner():
    w = h = 512
    g = np.clip(1 - radial(w, h, 0, h, w * 0.95, h * 0.95), 0, 1) ** 2.0 * 0.7
    s = sparks(w, h, 70, lambda u, v: ((1 - u) * v) ** 1.5, (0.5, 1.8), 0.5)
    save_alpha(np.clip(g + s * 0.9, 0, 1), "Corner.png")


def embers():
    w, h = 1024, 512
    a = sparks(w, h, 110, lambda u, v: v ** 2.4, (0.5, 2.2), 0.6)
    # tile cleanly upward: fade the top and bottom edges so the scrolling copies meet invisibly
    v = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    a *= np.clip(v / 0.12, 0, 1) * np.clip((1 - v) / 0.04, 0, 1)
    save_alpha(a, "Embers.png")


def round_pieces():
    n = 64
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) + 0.5
    d = np.sqrt((n - x) ** 2 + (n - y) ** 2)  # centre at the bottom-right: the piece is a top-left corner
    disc = np.clip(n - d + 0.5, 0, 1)
    save_alpha(disc, "RoundCorner.tga", TEX, tga=True)
    for radius in (4, 6, 10):
        stroke = n * 1.15 / radius  # about one screen pixel at the drawn corner size
        ring = np.clip(n - d + 0.5, 0, 1) * np.clip(d - (n - stroke) + 0.5, 0, 1)
        save_alpha(ring, "RoundArc%d.tga" % radius, TEX, tga=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    surface(); rail(); header_glow(); corner(); embers(); round_pieces()
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
