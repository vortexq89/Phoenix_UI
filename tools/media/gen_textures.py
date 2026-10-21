#!/usr/bin/env python3
"""Generates every Phoenix_UI texture (TGA, power-of-two) and PNG previews for docs.
All art is original and procedurally drawn here, so it is reproducible and license-clean.
Usage: python3 tools/media/gen_textures.py   (repo root)"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = "Media/Textures"; PNG = "docs/screenshots/assets"
os.makedirs(f"{OUT}/Icons", exist_ok=True); os.makedirs(PNG, exist_ok=True)
SS = 4  # supersampling

def save(im, path, png=None):
    im.save(f"{OUT}/{path}.tga")
    if png: im.save(f"{PNG}/{png}.png")

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
    # radial spark for status bar heads & accents
    r = Image.new("L", (64, 64), 0); d = ImageDraw.Draw(r); d.ellipse([20, 4, 44, 60], fill=255)
    r = r.filter(ImageFilter.GaussianBlur(6))
    save(Image.merge("RGBA", (Image.new("L", (64, 64), 255),) * 3 + (r,)), "Spark")
    # pill + circle for toggles/sliders
    for name, (w2, h2) in (("Pill", (64, 32)), ("Circle", (32, 32))):
        im = canvas(w2, h2); d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, w2 * SS - 1, h2 * SS - 1], radius=h2 * SS // 2, fill=(255, 255, 255, 255))
        save(down(im, w2, h2), name)
    # rounded 9-slice panel corner (radius 6) 32x32, 8px slices
    im = canvas(32, 32); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 32 * SS - 1, 32 * SS - 1], radius=6 * SS, fill=(255, 255, 255, 255))
    save(down(im, 32, 32), "Rounded")
    im = canvas(32, 32); d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 32 * SS - 1, 32 * SS - 1], radius=6 * SS, outline=(255, 255, 255, 255), width=SS)
    save(down(im, 32, 32), "RoundedBorder")
    # vertical fade used for header sheen / sidebar active row
    fade = Image.new("RGBA", (8, 64))
    for y in range(64):
        a = int(255 * (1 - y / 63) ** 1.6)
        for x in range(8): fade.putpixel((x, y), (255, 255, 255, a))
    save(fade, "FadeV")
    hfade = Image.new("RGBA", (64, 8))
    for x in range(64):
        a = int(255 * (1 - x / 63) ** 1.4)
        for y in range(8): hfade.putpixel((x, y), (255, 255, 255, a))
    save(hfade, "FadeH")

# ---------------------------------------------------------------- icons (white, tinted in game)
S = 64 * SS
def icon(name, fn):
    im = canvas(64, 64); d = ImageDraw.Draw(im); fn(d)
    save(down(im, 64, 64), f"Icons/{name}", f"icon_{name}")

W = 5 * SS  # stroke
P = lambda *xy: [v * SS for v in xy]
def rr(d, box, r=4, fill=None, width=W):
    if fill: d.rounded_rectangle(P(*box), radius=r * SS, fill=(255,) * 4)
    else: d.rounded_rectangle(P(*box), radius=r * SS, outline=(255,) * 4, width=width)
def line(d, pts, width=W): d.line([v * SS for v in pts], fill=(255,) * 4, width=width, joint="curve")
def dot(d, x, y, r): d.ellipse(P(x - r, y - r, x + r, y + r), fill=(255,) * 4)
def ring(d, x, y, r, width=W): d.ellipse(P(x - r, y - r, x + r, y + r), outline=(255,) * 4, width=width)
def poly(d, pts): d.polygon([v * SS for v in pts], fill=(255,) * 4)
def arc(d, x, y, r, a0, a1, width=W): d.arc(P(x - r, y - r, x + r, y + r), a0, a1, fill=(255,) * 4, width=width)

ICONS = {
 "home":        lambda d: (line(d, [10, 32, 32, 12, 54, 32]), rr(d, (17, 30, 47, 54), 3), rr(d, (28, 40, 36, 54), 1, fill=1)),
 "actionbars":  lambda d: [rr(d, (6 + i * 18, 22, 22 + i * 18, 42), 3) for i in range(3)],
 "unitframes":  lambda d: (ring(d, 18, 32, 9), rr(d, (31, 22, 58, 30), 2, fill=1), rr(d, (31, 35, 50, 42), 2, fill=1)),
 "groupframes": lambda d: [rr(d, (6 + (i % 2) * 27, 10 + (i // 2) * 23, 31 + (i % 2) * 27, 29 + (i // 2) * 23), 3) for i in range(4)],
 "castbars":    lambda d: (rr(d, (6, 24, 58, 40), 4), rr(d, (10, 28, 40, 36), 2, fill=1), dot(d, 44, 32, 3)),
 "auras":       lambda d: (rr(d, (8, 14, 28, 34), 3), rr(d, (36, 14, 56, 34), 3), line(d, [8, 46, 28, 46]), line(d, [36, 46, 50, 46])),
 "nameplates":  lambda d: (rr(d, (8, 30, 56, 42), 3), rr(d, (18, 16, 46, 22), 2, fill=1), poly(d, [28, 48, 36, 48, 32, 54])),
 "tooltip":     lambda d: (rr(d, (8, 10, 56, 44), 5), poly(d, [20, 43, 30, 43, 20, 54]), line(d, [17, 22, 47, 22]), line(d, [17, 32, 38, 32])),
 "chat":        lambda d: (rr(d, (8, 12, 48, 40), 8), poly(d, [16, 38, 28, 38, 14, 50]), dot(d, 20, 26, 3), dot(d, 28, 26, 3), dot(d, 36, 26, 3)),
 "minimap":     lambda d: (ring(d, 32, 32, 22), poly(d, [32, 14, 38, 32, 32, 50, 26, 32]), dot(d, 32, 32, 3)),
 "datatexts":   lambda d: [rr(d, (10 + i * 16, 50 - h, 20 + i * 16, 50), 2, fill=1) for i, h in enumerate((16, 30, 22))] + [line(d, [6, 54, 58, 54])],
 "itemlevel":   lambda d: (poly(d, [32, 8, 52, 18, 52, 34, 32, 56, 12, 34, 12, 18]),),
 "automation":  lambda d: (ring(d, 32, 32, 13), [line(d, [32 + 18 * math.cos(math.radians(a)), 32 + 18 * math.sin(math.radians(a)), 32 + 24 * math.cos(math.radians(a)), 32 + 24 * math.sin(math.radians(a))], 7 * SS) for a in range(0, 360, 45)], dot(d, 32, 32, 4)),
 "afk":         lambda d: (arc(d, 30, 34, 20, 300, 160), line(d, [38, 12, 52, 12, 38, 26, 52, 26], 4 * SS)),
 "mythicplus":  lambda d: (ring(d, 32, 34, 20), line(d, [32, 34, 32, 22]), line(d, [32, 34, 41, 40]), line(d, [26, 8, 38, 8])),
 "pvp":         lambda d: (line(d, [12, 12, 50, 50], 6 * SS), line(d, [52, 12, 14, 50], 6 * SS), line(d, [10, 44, 20, 54]), line(d, [54, 44, 44, 54])),
 "cooldowns":   lambda d: (ring(d, 32, 32, 22), d.pieslice(P(14, 14, 50, 50), -90, 110, fill=(255,) * 4)),
 "spellhistory":lambda d: (rr(d, (6, 22, 24, 40), 3, fill=1), rr(d, (28, 24, 42, 38), 3), rr(d, (46, 26, 56, 36), 2)),
 "combattext":  lambda d: (line(d, [16, 50, 16, 14]), line(d, [10, 20, 16, 14, 22, 20]), line(d, [34, 50, 34, 22]), line(d, [28, 28, 34, 22, 40, 28]), line(d, [50, 50, 50, 30])),
 "damagemeter": lambda d: [rr(d, (8, 10 + i * 12, 8 + w, 18 + i * 12), 2, fill=1) for i, w in enumerate((48, 38, 28, 18))],
 "skins":       lambda d: (rr(d, (8, 10, 56, 54), 5), line(d, [8, 22, 56, 22]), dot(d, 14, 16, 2), dot(d, 21, 16, 2)),
 "quality":     lambda d: (poly(d, [32, 6, 39, 24, 58, 25, 43, 37, 48, 56, 32, 45, 16, 56, 21, 37, 6, 25, 25, 24]),),
 "profiles":    lambda d: (ring(d, 32, 22, 10), arc(d, 32, 56, 20, 200, 340)),
 "about":       lambda d: (ring(d, 32, 32, 22), dot(d, 32, 21, 3.5), line(d, [32, 29, 32, 45])),
 "search":      lambda d: (ring(d, 27, 27, 15), line(d, [38, 38, 52, 52], 6 * SS)),
 "close":       lambda d: (line(d, [18, 18, 46, 46]), line(d, [46, 18, 18, 46])),
 "check":       lambda d: (line(d, [14, 33, 27, 46, 50, 19], 6 * SS),),
 "chevron":     lambda d: (line(d, [24, 14, 42, 32, 24, 50]),),
 "chevrondown": lambda d: (line(d, [14, 24, 32, 42, 50, 24]),),
 "reload":      lambda d: (arc(d, 32, 32, 18, 30, 320), poly(d, [44, 6, 54, 20, 38, 22])),
 "editmode":    lambda d: (rr(d, (8, 8, 56, 56), 4), line(d, [32, 16, 32, 48], 3 * SS), line(d, [16, 32, 48, 32], 3 * SS), poly(d, [32, 10, 37, 17, 27, 17]), poly(d, [32, 54, 37, 47, 27, 47]), poly(d, [10, 32, 17, 27, 17, 37]), poly(d, [54, 32, 47, 27, 47, 37])),
 "warning":     lambda d: (poly(d, [32, 8, 58, 54, 6, 54]),),
 "plus":        lambda d: (line(d, [32, 14, 32, 50]), line(d, [14, 32, 50, 32])),
 "export":      lambda d: (line(d, [32, 40, 32, 10]), line(d, [22, 20, 32, 10, 42, 20]), line(d, [12, 36, 12, 52, 52, 52, 52, 36])),
 "import":      lambda d: (line(d, [32, 10, 32, 40]), line(d, [22, 30, 32, 40, 42, 30]), line(d, [12, 36, 12, 52, 52, 52, 52, 36])),
}

def flame(d, cx, cy, s, fill=(255,) * 4):
    # stylised phoenix flame: three tongues
    def tongue(x, y, h, w, lean):
        pts = []
        for i in range(0, 101):
            t = i / 100.0
            yy = y - h * t
            ww = w * math.sin(math.pi * min(1, t * 1.15)) * (1 - t) ** 0.35
            pts.append((x + lean * h * t * t + ww, yy))
        for i in range(100, -1, -1):
            t = i / 100.0
            yy = y - h * t
            ww = w * math.sin(math.pi * min(1, t * 1.15)) * (1 - t) ** 0.35
            pts.append((x + lean * h * t * t - ww, yy))
        d.polygon([(px * SS, py * SS) for px, py in pts], fill=fill)
    tongue(cx, cy, 34 * s, 10 * s, 0.10)
    tongue(cx - 9 * s, cy - 1 * s, 22 * s, 6.5 * s, -0.35)
    tongue(cx + 9 * s, cy - 1 * s, 24 * s, 6.5 * s, 0.38)

def emblem(size=128, colored=True):
    im = canvas(size, size); d = ImageDraw.Draw(im); s = size / 64
    c = size / 2
    d.polygon([(c * SS, 3 * s * SS), ((size - 3 * s) * SS, c * SS), (c * SS, (size - 3 * s) * SS), (3 * s * SS, c * SS)],
              outline=(255,) * 4, width=int(3.2 * s * SS))
    flame(d, c / 1, c + 15 * s, s)
    im = down(im, size, size)
    if not colored: return im
    grad = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        r, g, b = (255, int(178 - 80 * t), int(63 - 37 * t))
        for x in range(size): grad.putpixel((x, y), (r, g, b, 255))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0)); out.paste(grad, (0, 0), im)
    return out

def logo():
    w, h = 512, 128
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    em = emblem(112); im.paste(em, (6, 8), em)
    font = ImageFont.truetype("Media/Fonts/Cinzel-Bold.ttf", 78)
    txt = Image.new("L", (w, h), 0); d = ImageDraw.Draw(txt); d.text((134, 14), "PHOENIX", font=font, fill=255)
    grad = Image.new("RGBA", (w, h))
    for x in range(w):
        t = max(0, min(1, (x - 134) / 360))
        col = (255, int(106 + (178 - 106) * t), int(26 + (63 - 26) * t), 255)
        for y in range(h): grad.putpixel((x, y), col)
    im.paste(grad, (0, 0), txt)
    save(im, "Logo", "logo")
    save(emblem(128), "Emblem", "emblem")
    save(emblem(64, colored=False), "Icons/phoenix", "icon_phoenix")

bars()
for k, fn in ICONS.items(): icon(k, fn)
logo()
print("textures:", len(os.listdir(OUT)), "icons:", len(os.listdir(f"{OUT}/Icons")))
