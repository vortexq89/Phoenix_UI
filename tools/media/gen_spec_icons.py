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


MARGIN = SS  # every shape's outer extent sits 1 px (at 64) inside the cell, on both axes


def offset(points, d):
    """Moves a convex outline inward by d along each vertex's normal, so a ring cut with it has the same
    perpendicular stroke everywhere (corners included), whatever the shape."""
    n, out = len(points), []
    for i in range(n):
        (x0, y0), (x1, y1), (x2, y2) = points[i - 1], points[i], points[(i + 1) % n]
        # unit normals of the two edges meeting here (pointing inward for a clockwise outline)
        def normal(ax, ay, bx, by):
            ex, ey = bx - ax, by - ay
            ln = math.hypot(ex, ey) or 1
            return -ey / ln, ex / ln
        n1, n2 = normal(x0, y0, x1, y1), normal(x1, y1, x2, y2)
        bx, by = n1[0] + n2[0], n1[1] + n2[1]
        bl = math.hypot(bx, by) or 1
        bx, by = bx / bl, by / bl
        cos_half = max(0.5, bx * n1[0] + by * n1[1])  # miter: d / cos(half the turn)
        out.append((x1 + bx * d / cos_half, y1 + by * d / cos_half))
    return out


def regular(sides, rot):
    # radius chosen so the shape's widest extent (a vertex or a flat side) touches the margin
    c = N / 2
    flat = sides == 8  # the octagon is rotated to sit on its flat sides; the others sit on a vertex
    r = (N / 2 - MARGIN) / (math.cos(math.pi / sides) if flat else 1)
    return [(c + r * math.cos(math.radians(360 / sides * i + rot)), c + r * math.sin(math.radians(360 / sides * i + rot)))
            for i in range(sides)]


def shield():
    # centred: top edge at the margin, the point at the bottom margin, sides at the margin
    c, top, bot, w = N / 2, MARGIN, N - MARGIN, N / 2 - MARGIN
    shoulder = top + (bot - top) * 0.5
    pts = [(c - w, top), (c + w, top), (c + w, shoulder)]
    for i in range(1, 16):
        t = i / 16
        pts.append((c + w * (1 - t) ** 1.4, shoulder + (bot - shoulder) * t))
    pts.append((c, bot))
    for i in range(15, 0, -1):
        t = i / 16
        pts.append((c - w * (1 - t) ** 1.4, shoulder + (bot - shoulder) * t))
    pts.append((c - w, shoulder))
    return pts


def squircle():
    c, r, pts = N / 2, N / 2 - MARGIN, []
    for i in range(192):
        a = 2 * math.pi * i / 192
        x, y = math.cos(a), math.sin(a)
        pts.append((c + r * math.copysign(abs(x) ** 0.5, x), c + r * math.copysign(abs(y) ** 0.5, y)))
    return pts


# Hexagon: Phoenix's action-button hexagon is cut radially (thinner on the flat sides); the spec icon set has its
# own, cut perpendicular like the others.
SHAPES = {"Diamond": regular(4, -90), "Octagon": regular(8, 22.5), "Shield": shield(), "Squircle": squircle(),
          "Hex": regular(6, -90)}


def save(alpha, name):
    white = Image.new("L", alpha.size, 255)
    Image.merge("RGBA", (white, white, white, alpha)).resize((64, 64), Image.LANCZOS).save(f"{OUT}/{name}.tga")


def shapes():
    for kind, pts in SHAPES.items():
        area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
        if area < 0:  # offset() wants the outline clockwise on screen (positive area with y down)
            pts = pts[::-1]
        mask = Image.new("L", (N, N), 0)
        ImageDraw.Draw(mask).polygon(pts, fill=255)
        inner = offset(pts, RING)
        cut = Image.new("L", (N, N), 0)
        ImageDraw.Draw(cut).polygon(inner, fill=255)
        ring = Image.composite(Image.new("L", (N, N), 0), mask, cut)
        name = "Spec" + kind if kind == "Hex" else kind
        save(mask, "Mask" + name)
        save(ring, "Ring" + name)


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
    # inner line 2 px at 64 and full strength, so it still reads at a 16-20 px draw size
    d.rectangle([7 * SS, 7 * SS, N - 1 - 7 * SS, N - 1 - 7 * SS], outline=255, width=2 * SS)
    for cx, cy in ((0, 0), (N, 0), (0, N), (N, N)):
        d.polygon([(cx, cy), (abs(cx - 12 * SS), cy), (cx, abs(cy - 12 * SS))], fill=255)
    save(f, "FrameEmber")


os.makedirs(OUT, exist_ok=True)
shapes()
overlays()
print("spec icon textures written")
