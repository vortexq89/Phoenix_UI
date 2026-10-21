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

bars()
print("textures:", sorted(f for f in os.listdir(OUT) if f.endswith(".tga")))
