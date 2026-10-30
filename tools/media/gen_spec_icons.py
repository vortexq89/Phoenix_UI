#!/usr/bin/env python3
"""Generates the masks, rings and overlays for Phoenix's spec icon styles (UI/SpecIcon.lua). All shapes are
original and procedurally drawn (MIT, Phoenix's own); the icons themselves are the game's spec icons, drawn by the
client, so nothing third-party is shipped. Usage: python3 tools/media/gen_spec_icons.py   (repo root)"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = "Media/Textures"
SS = 4
N = 64 * SS
RING = 4 * SS


def poly(points):
    return lambda d, inset, fill: d.polygon(points(inset), fill=fill)


def regular(sides, rot):
    def pts(inset):
        c, r = N / 2, N / 2 - inset - SS
        return [(c + r * math.cos(math.radians(360 / sides * i + rot)), c + r * math.sin(math.radians(360 / sides * i + rot)))
                for i in range(sides)]
    return pts


def shield(inset):
    c, top, bot, w = N / 2, inset + SS, N - inset - SS, N / 2 - inset - 3 * SS
    pts = [(c - w, top), (c + w, top), (c + w, N * 0.55)]
    for i in range(1, 12):  # curved lower edges to the point
        t = i / 12
        pts.append((c + w * (1 - t) ** 1.4, N * 0.55 + (bot - N * 0.55) * t))
    pts.append((c, bot))
    for i in range(11, 0, -1):
        t = i / 12
        pts.append((c - w * (1 - t) ** 1.4, N * 0.55 + (bot - N * 0.55) * t))
    pts.append((c - w, N * 0.55))
    return pts


def squircle(inset):
    c, r, pts = N / 2, N / 2 - inset - SS, []
    for i in range(160):
        a = 2 * math.pi * i / 160
        x, y = math.cos(a), math.sin(a)
        pts.append((c + r * math.copysign(abs(x) ** 0.5, x), c + r * math.copysign(abs(y) ** 0.5, y)))
    return pts


SHAPES = {"Diamond": regular(4, -90), "Octagon": regular(8, 22.5), "Shield": shield, "Squircle": squircle}


def save(alpha, name):
    white = Image.new("L", alpha.size, 255)
    Image.merge("RGBA", (white, white, white, alpha)).resize((64, 64), Image.LANCZOS).save(f"{OUT}/{name}.tga")


def shapes():
    for kind, pts in SHAPES.items():
        mask = Image.new("L", (N, N), 0)
        ImageDraw.Draw(mask).polygon(pts(0), fill=255)
        cut = Image.new("L", (N, N), 0)
        ImageDraw.Draw(cut).polygon(pts(RING), fill=255)
        ring = Image.composite(Image.new("L", (N, N), 0), mask, cut)
        save(mask, "Mask" + kind)
        save(ring, "Ring" + kind)


def overlays():
    # gloss: a soft top highlight that fades out by the middle
    g = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(g)
    for y in range(N // 2):
        d.line([(0, y), (N, y)], fill=int(150 * (1 - y / (N / 2)) ** 1.6))
    save(g, "IconGloss")
    # inner shade: dark edges, clear centre (tinted black in game)
    s = Image.new("L", (N, N), 0)
    ImageDraw.Draw(s).rectangle([0, 0, N - 1, N - 1], outline=255, width=7 * SS)
    save(s.filter(ImageFilter.GaussianBlur(5 * SS)), "IconShade")
    # ember frame: a double line with notched corners (tinted with the accent)
    f = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(f)
    d.rectangle([SS, SS, N - 1 - SS, N - 1 - SS], outline=255, width=3 * SS)
    d.rectangle([7 * SS, 7 * SS, N - 1 - 7 * SS, N - 1 - 7 * SS], outline=150, width=SS)
    for cx, cy in ((0, 0), (N, 0), (0, N), (N, N)):
        d.polygon([(cx, cy), (abs(cx - 12 * SS), cy), (cx, abs(cy - 12 * SS))], fill=255)
    save(f, "FrameEmber")


os.makedirs(OUT, exist_ok=True)
shapes()
overlays()
print("spec icon textures written")
