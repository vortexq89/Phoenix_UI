#!/usr/bin/env python3
"""Generates Phoenix_UI's procedural surface textures (bars, shadow, pill, circle, rounded, vertical fade)
as power-of-two TGA. All art here is original and procedurally drawn, so it is reproducible and license-clean.
Icons, the emblem and the logo are built by tools/media/gen_icons.py.
Usage: python3 tools/media/gen_textures.py   (repo root)"""
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = "Media/Textures"
os.makedirs(OUT, exist_ok=True)
SS = 4  # supersampling

def save(im, path):
    im.save(f"{OUT}/{path}.tga")

def canvas(w, h): return Image.new("RGBA", (w * SS, h * SS), (255, 255, 255, 0))
def down(im, w, h): return im.resize((w, h), Image.LANCZOS)

# ---------------------------------------------------------------- bars & surfaces
def bars():
    w, h = 256, 32
    flat = Image.new("RGBA", (w, h), (255, 255, 255, 255)); save(flat, "BarFlat")
    satin = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / (h - 1); v = int(255 * (1.0 - 0.22 * t))
        for x in range(w): satin.putpixel((x, y), (v, v, v, 255))
    save(satin, "BarSatin")
    ember = Image.new("RGBA", (w, h))
    for y in range(h):
        t = y / (h - 1)
        v = 1.0 - 0.28 * t
        if t < 0.12: v = min(1.0, v + 0.10 * (1 - t / 0.12))
        for x in range(w):
            stripe = 0.035 if ((x + y) // 6) % 2 == 0 else 0.0
            c = int(255 * max(0, v - stripe)); ember.putpixel((x, y), (c, c, c, 255))
    save(ember, "BarEmber")
    # soft shadow / glow 9-slice source (64x64, 16px slices)
    g = Image.new("L", (64, 64), 0); d = ImageDraw.Draw(g); d.rectangle([16, 16, 47, 47], fill=255)
    g = g.filter(ImageFilter.GaussianBlur(5.5))
    glow = Image.merge("RGBA", (Image.new("L", (64, 64), 255),) * 3 + (g,)); save(glow, "Shadow")
    # pill + circle for toggles/sliders
    for name, (w2, h2) in (("Pill", (64, 32)), ("Circle", (32, 32))):
        im = canvas(w2, h2); d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, w2 * SS - 1, h2 * SS - 1], radius=h2 * SS // 2, fill=(255, 255, 255, 255))
        save(down(im, w2, h2), name)
    # rounded 9-slice panel corner (radius 6) 32x32, 8px slices
    im = canvas(32, 32); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 32 * SS - 1, 32 * SS - 1], radius=6 * SS, fill=(255, 255, 255, 255))
    save(down(im, 32, 32), "Rounded")
    # vertical fade used for header sheen / sidebar active row
    fade = Image.new("RGBA", (8, 64))
    for y in range(64):
        a = int(255 * (1 - y / 63) ** 1.6)
        for x in range(8): fade.putpixel((x, y), (255, 255, 255, a))
    save(fade, "FadeV")

# ---------------------------------------------------------------- the status bar set
# Every bar is white/grey (the game tints it with SetStatusBarColor), 256x32, tiles horizontally, and is drawn from
# a formula: v(x, y) in 0..1 with x, y in pixels. Names are the LibSharedMedia names after "Phoenix ".
import math, random
W, H = 256, 32

def shade(fn, name, alpha=None):
    im = Image.new("RGBA", (W, H))
    px = im.load()
    for y in range(H):
        for x in range(W):
            v = max(0.0, min(1.0, fn(x, y)))
            a = 255 if alpha is None else int(255 * max(0.0, min(1.0, alpha(x, y))))
            c = int(round(255 * v)); px[x, y] = (c, c, c, a)
    save(im, name)

def ty(y): return y / (H - 1)
def smooth(t): return t * t * (3 - 2 * t)
rng = random.Random(1203)
NOISE = [[rng.random() for _ in range(W)] for _ in range(H)]
STREAK = [rng.random() for _ in range(H)]
def noise(x, y): return NOISE[y][x]

BAR_SET = [
    # (file, LSM name suffix, style label key, formula)
    ("BarFlat", "Flat", "flat", None),
    ("BarSatin", "Satin", "gradient", None),
    ("BarEmber", "Ember", "stripes", None),
    ("BarSmooth", "Smooth", "gradient", lambda x, y: 0.70 + 0.30 * math.cos(ty(y) * math.pi * 0.5)),
    ("BarGradient", "Gradient", "gradient", lambda x, y: 1.0 - 0.45 * ty(y)),
    ("BarSoft", "Soft", "soft", lambda x, y: 0.78 + 0.22 * math.sin(ty(y) * math.pi)),
    ("BarGlass", "Glass", "glass", lambda x, y: (0.97 - 0.10 * ty(y) / 0.48) if ty(y) < 0.48 else (0.72 + 0.16 * (ty(y) - 0.48) / 0.52)),
    ("BarSheen", "Sheen", "glass", lambda x, y: 0.80 - 0.12 * ty(y) + (0.18 if 0.10 < ty(y) < 0.32 else 0.0) * (1 - abs(ty(y) - 0.21) / 0.11)),
    ("BarMinimal", "Minimal", "minimal", lambda x, y: 1.0 if y == 0 else (0.62 if y == H - 1 else 0.88)),
    ("BarBevel", "Bevel", "minimal", lambda x, y: 1.0 if y < 2 else (0.55 if y >= H - 2 else 0.85 - 0.08 * ty(y))),
    ("BarInset", "Inset", "minimal", lambda x, y: 0.60 + 0.40 * smooth(min(1.0, min(y, H - 1 - y) / 6.0))),
    ("BarRidge", "Ridge", "glass", lambda x, y: 0.70 + 0.30 * (1 - abs(ty(y) - 0.5) * 2) ** 2),
    ("BarSplit", "Split", "flat", lambda x, y: 0.96 if y < H // 2 else 0.80),
    ("BarChrome", "Chrome", "metal", lambda x, y: 0.78 + 0.16 * math.sin(ty(y) * math.pi * 3.0 + 0.6) - 0.06 * ty(y)),
    ("BarBrushed", "Brushed", "metal", lambda x, y: 0.82 + 0.10 * (STREAK[y] - 0.5) + 0.05 * (noise(x, y) - 0.5) - 0.10 * ty(y)),
    ("BarMatte", "Matte", "soft", lambda x, y: 0.88 + 0.06 * (noise(x, y) - 0.5) - 0.08 * ty(y)),
    ("BarStripes", "Stripes", "stripes", lambda x, y: (0.95 if ((x + y) // 8) % 2 == 0 else 0.80) - 0.12 * ty(y)),
    ("BarFineStripes", "Fine Stripes", "stripes", lambda x, y: (0.94 if ((x + y) // 3) % 2 == 0 else 0.84) - 0.10 * ty(y)),
    ("BarHatch", "Hatch", "stripes", lambda x, y: 0.90 - 0.10 * ty(y) - (0.10 if (x + y) % 6 == 0 or (x - y) % 6 == 0 else 0.0)),
    ("BarScanline", "Scanline", "pixel", lambda x, y: (0.95 if y % 2 == 0 else 0.78) - 0.08 * ty(y)),
    ("BarCarbon", "Carbon", "pixel", lambda x, y: 0.84 - 0.08 * ty(y) + (0.07 if ((x // 4) + (y // 4)) % 2 == 0 else 0.0) * (0.5 + 0.5 * ((x % 4) / 3 if ((x // 4) + (y // 4)) % 2 == 0 else (y % 4) / 3))),
    ("BarHalftone", "Halftone", "pixel", lambda x, y: 0.82 - 0.06 * ty(y) + (0.10 if math.hypot((x % 4) - 1.5, (y % 4) - 1.5) < 0.8 + 0.9 * (1 - ty(y)) else 0.0)),
    ("BarAurora", "Aurora", "soft", lambda x, y: 0.80 + 0.14 * math.sin(x / W * math.pi * 4 + ty(y) * 2.0) * (1 - ty(y)) - 0.06 * ty(y)),
    ("BarFrost", "Frost", "soft", lambda x, y: 0.93 - 0.20 * ty(y) + 0.07 * (noise(x, y) - 0.5) * (1 - ty(y))),
    # 2.0 Phase 2: twelve high-contrast faces that read apart at a glance, even at 12 px tall
    ("BarNeon", "Neon", "bold", lambda x, y: 0.30 + 0.70 * math.exp(-((ty(y) - 0.5) / 0.16) ** 2)),
    ("BarTube", "Tube", "bold", lambda x, y: 0.28 + 0.72 * math.sin(ty(y) * math.pi) ** 0.6 + (0.25 if 0.16 < ty(y) < 0.30 else 0.0)),
    ("BarGloss", "Gloss", "bold", lambda x, y: (1.0 - 0.18 * ty(y) / 0.5) if ty(y) < 0.5 else (0.50 + 0.22 * (ty(y) - 0.5) / 0.5)),
    ("BarEdge", "Edge", "bold", lambda x, y: 0.95 if y < 3 else (0.42 if y >= H - 3 else 0.70)),
    ("BarChevron", "Chevron", "pattern", lambda x, y: 0.72 + (0.26 if ((x + abs(y - H / 2)) // 8) % 2 == 0 else 0.0) - 0.10 * ty(y)),
    ("BarDiamond", "Diamond Plate", "pattern", lambda x, y: 0.70 - 0.10 * ty(y) + (0.28 if abs((x % 16) - 8) + abs((y % 16) - 8) < 4 else 0.0)),
    ("BarHoney", "Honeycomb", "pattern", lambda x, y: 0.86 - 0.12 * ty(y) - (0.34 if hexline(x, y) else 0.0)),
    ("BarCells", "Cells", "pattern", lambda x, y: 0.55 + 0.45 * cells(x, y) - 0.08 * ty(y)),
    ("BarPinstripe", "Pinstripe", "pattern", lambda x, y: (1.0 if x % 8 == 0 else 0.74) - 0.14 * ty(y)),
    ("BarRain", "Rain", "pattern", lambda x, y: 0.60 - 0.10 * ty(y) + (0.38 if (x + 3 * y) % 24 < 4 and ((x + 3 * y) // 24 + y // 11) % 2 == 0 else 0.0)),
    ("BarDots", "Dots", "pattern", lambda x, y: 0.62 - 0.08 * ty(y) + (0.36 if math.hypot((x % 16) - 7.5, (y % 16) - 7.5) < 4.2 else 0.0)),
    ("BarSegments", "Segments", "pattern", lambda x, y: (0.30 if x % 32 in (0, 1) else 0.94 - 0.24 * ty(y))),
]

# periodic helpers for the patterned faces (period divides 256 so the bar tiles cleanly)
def hexline(x, y):
    # flat hex rows: 16 px cells, borders where the distance to the cell centre peaks
    cx, cy = (x % 16) - 8, (y % 14) - 7
    if (y // 14) % 2: cx = ((x + 8) % 16) - 8
    return max(abs(cx) * 0.866 + abs(cy) * 0.5, abs(cy)) > 6.2

CELL_PTS = [(rng.uniform(0, 256), rng.uniform(0, 32)) for _ in range(28)]
def cells(x, y):
    ds = sorted(min(abs(x - px), 256 - abs(x - px)) ** 2 + min(abs(y - py), 32 - abs(y - py)) ** 2 for px, py in CELL_PTS)
    edge = math.sqrt(ds[1]) - math.sqrt(ds[0])          # 0 on a cell border
    return min(1.0, edge / 3.0)

def bar_set():
    for file, _, _, fn in BAR_SET:
        if fn: shade(fn, file)

# ---------------------------------------------------------------- borders and glows
def borders_and_glows():
    # Solid backdrop edge: every one of the eight edge segments is white, so it works at any edgeSize as a clean
    # solid border (other addons pick it from LibSharedMedia "border").
    save(Image.new("RGBA", (128, 16), (255, 255, 255, 255)), "BorderSolid")
    # Glows: 9-slice sources like Shadow (64x64, 16 px slices) with a tighter and a wider falloff.
    for name, inner, blur in (("GlowTight", 20, 3.0), ("GlowWide", 12, 7.5)):
        g = Image.new("L", (64, 64), 0); d = ImageDraw.Draw(g); d.rectangle([inner, inner, 63 - inner, 63 - inner], fill=255)
        g = g.filter(ImageFilter.GaussianBlur(blur))
        save(Image.merge("RGBA", (Image.new("L", (64, 64), 255),) * 3 + (g,)), name)

# ---------------------------------------------------------------- action button shapes (ActionBars v2)
# Masks are white with the shape in alpha (MaskTexture), rings are the matching 1/16-wide outline the game tints for
# the button border. 64x64, drawn at 4x and downsampled, so edges stay soft at any button size.
def hexagon(n, inset=0.0):
    c = n / 2; r = n / 2 - inset
    return [(c + r * math.cos(math.radians(60 * i - 90)), c + r * math.sin(math.radians(60 * i - 90))) for i in range(6)]

def button_shapes():
    n = 64 * SS; ring = 4 * SS
    def shape(d, inset, kind, fill):
        box = [inset, inset, n - 1 - inset, n - 1 - inset]
        if kind == "Rounded": d.rounded_rectangle(box, radius=14 * SS - inset, fill=fill)
        elif kind == "Circle": d.ellipse(box, fill=fill)
        else: d.polygon(hexagon(n, inset + 1 * SS), fill=fill)
    for kind in ("Rounded", "Circle", "Hex"):
        mask = Image.new("L", (n, n), 0); shape(ImageDraw.Draw(mask), 0, kind, 255)
        cut = Image.new("L", (n, n), 0); shape(ImageDraw.Draw(cut), ring, kind, 255)
        outline = Image.eval(Image.merge("L", (mask,)), lambda v: v)
        outline = Image.composite(Image.new("L", (n, n), 0), outline, cut)
        white = Image.new("L", (n, n), 255)
        save(down(Image.merge("RGBA", (white, white, white, mask)), 64, 64), "Mask" + kind)
        save(down(Image.merge("RGBA", (white, white, white, outline)), 64, 64), "Ring" + kind)

# Minimap rectangle masks: white with a centred horizontal band in alpha (Minimap:SetMaskTexture), one per height the
# Minimap page offers (percent of the map's width). 128x128: the edges are straight, so they stay crisp scaled up.
MINIMAP_RECTS = (50, 60, 70, 80, 90)

def minimap_masks():
    n = 128
    for pct in MINIMAP_RECTS:
        band = round(n * pct / 100)
        top = (n - band) // 2
        alpha = Image.new("L", (n, n), 0)
        ImageDraw.Draw(alpha).rectangle([0, top, n - 1, top + band - 1], fill=255)
        white = Image.new("L", (n, n), 255)
        save(Image.merge("RGBA", (white, white, white, alpha)), f"MinimapRect{pct}")

def lua_str(s): return '"' + s.replace('"', '\\"') + '"'

def write_data():
    with open("Core/TextureData.lua", "w", newline="\n") as f:
        f.write("local _, ns = ...\n\n")
        f.write("-- GENERATED by tools/media/gen_textures.py. Do not edit by hand. Original procedural art (MIT, see LICENSE).\n")
        f.write("-- style groups the bar picker; key = the saved setting value, name = the LibSharedMedia name.\n")
        f.write("ns.TextureData = {\n    bars = {\n")
        for file, label, style, _ in BAR_SET:
            f.write(f"        {{ key = {lua_str(label.replace(' ', ''))}, name = {lua_str('Phoenix ' + label)}, file = {lua_str(file)}, style = {lua_str(style)} }},\n")
        f.write("    },\n    borders = {\n        { key = \"Solid\", name = \"Phoenix Solid\", file = \"BorderSolid\" },\n    },\n")
        f.write("    glows = {\n        { key = \"Soft\", file = \"Shadow\" },\n        { key = \"Tight\", file = \"GlowTight\" },\n")
        f.write("        { key = \"Wide\", file = \"GlowWide\" },\n    },\n}\n")

bars()
bar_set()
borders_and_glows()
button_shapes()
minimap_masks()
write_data()
print("textures:", sorted(f for f in os.listdir(OUT) if f.endswith(".tga")))
