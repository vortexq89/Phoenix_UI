#!/usr/bin/env python3
"""Phoenix UI "Ember Bevel" framed chrome icons (approved t169), original Phoenix art. Original, fully procedural (no traced or copied art).
Renders frame + states at 256 and 64 px, sample glyphs, and a preview sheet. Usage: python3 gen_phoenix_wow_frames.py"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageEnhance

OUT = "out"; M = 1024            # master canvas (4x of 256)
S = M / 64                        # 1 unit = 1 px at 64
RAMP = [(0.0, (0xFF, 0xEC, 0xAA)), (0.35, (0xFF, 0xB0, 0x40)), (0.7, (0xF0, 0x60, 0x1C)), (1.0, (0x96, 0x1E, 0x12))]
RIM = (0x34, 0x0A, 0x06); GLOW = (0xFF, 0x3D, 0x00); GOLD = (0xFF, 0xEC, 0xAA)
OBS = (0x07, 0x08, 0x0A)          # bg.sunken (Theme.lua) for the well
FRAME_IN, FRAME_OUT = 4, 60       # frame square at 64: 4..60 (56 px, 4 px margin for glow)
BEVEL = 4                         # bevel band width at 64
RIVETS = True                     # the simplified 16 px cell drops them (and uses a 3 px bevel)

def ramp(t):
    t = max(0, min(1, t))
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if t <= b:
            k = (t - a) / (b - a); return tuple(int(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
    return RAMP[-1][1]

def vgrad(y0, y1):
    g = Image.new("RGB", (M, M))
    d = ImageDraw.Draw(g)
    for y in range(M): d.line([(0, y), (M, y)], fill=ramp((y - y0) / max(1, y1 - y0)))
    return g

def u(v): return int(v * S)

def frame_layers():
    a0, a1 = u(FRAME_IN), u(FRAME_OUT)
    img = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    # well: painterly obsidian-to-crimson radial with brush noise
    well = Image.new("RGB", (M, M), OBS); wd = ImageDraw.Draw(well)
    cx, cy = M * 0.42, M * 0.38
    for r in range(int(M * 0.75), 0, -8):
        k = 1 - r / (M * 0.75)
        wd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=tuple(int(OBS[i] + ((0x5A, 0x16, 0x0C)[i] - OBS[i]) * k ** 1.5) for i in range(3)))
    rnd = random.Random(7); br = Image.new("L", (M, M), 0); bd = ImageDraw.Draw(br)
    for _ in range(260):   # painterly strokes
        x, y, l, ang = rnd.uniform(0, M), rnd.uniform(0, M), rnd.uniform(40, 160), rnd.uniform(-0.6, -0.2)
        bd.line([(x, y), (x + l * math.cos(ang), y + l * math.sin(ang))], fill=rnd.randint(10, 40), width=rnd.randint(6, 18))
    br = br.filter(ImageFilter.GaussianBlur(6))
    well = Image.composite(Image.new("RGB", (M, M), (0x96, 0x3A, 0x18)), well, br)
    mask = Image.new("L", (M, M), 0); ImageDraw.Draw(mask).rectangle([a0, a0, a1, a1], fill=255)
    img.paste(well, (0, 0), mask)
    # inner shadow (dark vignette inside the well)
    sh = Image.new("L", (M, M), 0); ImageDraw.Draw(sh).rectangle([a0, a0, a1, a1], outline=255, width=u(9))
    sh = ImageChops.multiply(sh.filter(ImageFilter.GaussianBlur(u(4))), mask)
    img = Image.alpha_composite(img, Image.merge("RGBA", (*[Image.new("L", (M, M), 0)] * 3, sh.point(lambda v: v * 0.8))))
    return img, mask

def bevel_frame():
    a0, a1, b = u(FRAME_IN), u(FRAME_OUT), u(BEVEL)
    f = Image.new("RGBA", (M, M), (0, 0, 0, 0)); d = ImageDraw.Draw(f)
    # four bevel faces, lit from top-left
    lit, mid, dark = (0xFF, 0xEC, 0xAA), (0xD8, 0x9A, 0x38), (0x6A, 0x22, 0x0E)
    d.polygon([(a0, a0), (a1, a0), (a1 - b, a0 + b), (a0 + b, a0 + b)], fill=lit)      # top
    d.polygon([(a0, a0), (a0 + b, a0 + b), (a0 + b, a1 - b), (a0, a1)], fill=mid)      # left
    d.polygon([(a1, a0), (a1, a1), (a1 - b, a1 - b), (a1 - b, a0 + b)], fill=(0xA8, 0x48, 0x18))  # right
    d.polygon([(a0, a1), (a1, a1), (a1 - b, a1 - b), (a0 + b, a1 - b)], fill=dark)     # bottom
    # metal grain on the gold: multiply by ramp so it reads as ember-gold, not flat
    g = vgrad(a0, a1).convert("RGBA"); g.putalpha(255)
    f = Image.composite(ImageChops.blend(f, ImageChops.multiply(f, g), 0.35), f, f.split()[3])
    d = ImageDraw.Draw(f)
    d.rectangle([a0, a0, a1, a1], outline=RIM + (255,), width=u(1))                     # outer rim
    d.rectangle([a0 + b, a0 + b, a1 - b, a1 - b], outline=RIM + (255,), width=u(1))     # inner rim
    d.line([(a0 + u(1), a0 + u(1)), (a1 - u(1), a0 + u(1))], fill=(255, 255, 240, 200), width=max(1, u(0.6)))  # top spec
    # corner rivets
    for cx, cy in (() if not RIVETS else None) or ((a0, a0), (a1, a0), (a0, a1), (a1, a1)):
        r = u(2.2); d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=RIM + (255,))
        r2 = u(1.4); d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(0xFF, 0xB0, 0x40, 255))
        r3 = u(0.6); d.ellipse([cx - r3 - u(0.4), cy - r3 - u(0.4), cx + r3 - u(0.4), cy + r3 - u(0.4)], fill=GOLD + (255,))
    return f

def edge_glow(alpha):
    a0, a1, b = u(FRAME_IN + BEVEL), u(FRAME_OUT - BEVEL), u(1)
    e = Image.new("L", (M, M), 0); ImageDraw.Draw(e).rectangle([a0, a0, a1, a1], outline=255, width=u(1.5))
    e = e.filter(ImageFilter.GaussianBlur(u(1.5))).point(lambda v: int(v * alpha))
    return Image.merge("RGBA", (*Image.new("RGB", (M, M), (0xF0, 0x60, 0x1C)).split(), e))

def gloss():
    a0, a1, b = u(FRAME_IN + BEVEL), u(FRAME_OUT - BEVEL), 0
    g = Image.new("L", (M, M), 0); d = ImageDraw.Draw(g)
    h = (a1 - a0) * 0.45
    for y in range(int(h)): d.line([(a0, a0 + y), (a1, a0 + y)], fill=int(70 * (1 - y / h) ** 2))
    # diagonal arc edge of the gloss
    cut = Image.new("L", (M, M), 0); ImageDraw.Draw(cut).ellipse([a0 - M * 0.3, a0 - M * 0.75, a1 + M * 0.1, a0 + h], fill=255)
    return Image.merge("RGBA", (*[Image.new("L", (M, M), 255)] * 3, ImageChops.multiply(g, cut)))

# ---- glyphs (original geometry), drawn as L masks in 64-unit coordinates, live area 14..50 ----
def G(): return Image.new("L", (M, M), 0)
def gear():
    m = G(); d = ImageDraw.Draw(m); c = M / 2
    pts = []
    for i in range(16):
        a = i * math.pi / 8; r = u(17) if i % 2 == 0 else u(13)
        for da in (-0.17, 0.17): pts.append((c + r * math.cos(a + da), c + r * math.sin(a + da)))
    d.polygon(pts, fill=255); r = u(5.5); d.ellipse([c - r, c - r, c + r, c + r], fill=0); return m
def bag():
    m = G(); d = ImageDraw.Draw(m)
    d.ellipse([u(15), u(24), u(49), u(52)], fill=255)
    d.polygon([(u(23), u(27)), (u(41), u(27)), (u(37), u(19)), (u(27), u(19))], fill=255)
    d.rectangle([u(22), u(20), u(42), u(24)], fill=0)
    d.ellipse([u(26), u(12), u(38), u(22)], outline=255, width=u(3.5))
    r = u(3.5); d.ellipse([u(32) - r, u(38) - r, u(32) + r, u(38) + r], fill=0)
    return m
def mapg():
    m = G(); d = ImageDraw.Draw(m)
    d.polygon([(u(13), u(18)), (u(25), u(14)), (u(39), u(18)), (u(51), u(14)), (u(51), u(46)), (u(39), u(50)), (u(25), u(46)), (u(13), u(50))], fill=255)
    for x in (25, 39): d.line([(u(x), u(15)), (u(x), u(49))], fill=0, width=u(3.2))
    r = u(5); d.ellipse([u(32) - r, u(32) - r, u(32) + r, u(32) + r], fill=0)   # bold location pin hole
    return m
def social():
    m = G(); d = ImageDraw.Draw(m)
    for cx, cy, r, w in ((24, 24, 6.5, 12), (40, 24, 6.5, 12)):
        d.ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], fill=255)
        d.pieslice([u(cx - w), u(cy + 8), u(cx + w), u(cy + 32)], 180, 360, fill=255)
    d.line([(u(32), u(14)), (u(32), u(46))], fill=0, width=u(2.5))
    return m
def search():
    m = G(); d = ImageDraw.Draw(m)
    d.ellipse([u(14), u(14), u(40), u(40)], outline=255, width=u(5.5))
    d.line([(u(36), u(36)), (u(50), u(50))], fill=255, width=u(7)); return m
def close():
    m = G(); d = ImageDraw.Draw(m)
    for p in (((17, 17), (47, 47)), ((47, 17), (17, 47))): d.line([(u(p[0][0]), u(p[0][1])), (u(p[1][0]), u(p[1][1]))], fill=255, width=u(7.5))
    return m
GLYPHS = {"settings": gear, "bags": bag, "map": mapg, "social": social, "search": search, "close": close}

def glyph_layer(mask, bright=1.0):
    a0, a1 = mask.getbbox()[1], mask.getbbox()[3]
    body = vgrad(a0, a1)
    inner = mask.filter(ImageFilter.MinFilter(int(u(2.5)) | 1))      # stroke vs fill: fill darker (62%)
    stroke = ImageChops.subtract(mask, inner)
    fill = ImageEnhance.Brightness(body).enhance(0.62 * 1.25)        # 62% plus painterly lift
    col = Image.composite(body, fill, stroke.point(lambda v: 255 if v > 0 else 0))
    col = Image.composite(body, col, Image.new("L", (M, M), 0))
    # top light: shift mask down, subtract -> top edges
    top = ImageChops.subtract(mask, ImageChops.offset(mask, 0, int(u(1.2)))).filter(ImageFilter.GaussianBlur(u(0.4)))
    col = Image.composite(Image.new("RGB", (M, M), GOLD), col, top.point(lambda v: int(v * 0.8)))
    col = ImageEnhance.Brightness(col).enhance(bright)
    out = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    # drop shadow (down-right) + dark ember rim
    shadow = ImageChops.offset(mask, int(u(1.5)), int(u(1.5))).filter(ImageFilter.GaussianBlur(u(1.5)))
    out = Image.alpha_composite(out, Image.merge("RGBA", (*Image.new("RGB", (M, M), (0, 0, 0)).split(), shadow.point(lambda v: int(v * 0.85)))))
    rim = mask.filter(ImageFilter.MaxFilter(int(u(2.2)) | 1))
    out = Image.alpha_composite(out, Image.merge("RGBA", (*Image.new("RGB", (M, M), RIM).split(), rim)))
    return Image.alpha_composite(out, Image.merge("RGBA", (*col.split(), mask)))

def rays(n=16):
    r = Image.new("L", (M, M), 0); d = ImageDraw.Draw(r); c = M / 2
    for i in range(n):
        a = i * 2 * math.pi / n; w = 0.07
        d.polygon([(c, c), (c + M * math.cos(a - w), c + M * math.sin(a - w)), (c + M * math.cos(a + w), c + M * math.sin(a + w))], fill=150)
    rad = Image.radial_gradient("L").resize((M, M)).point(lambda v: 255 - v)
    r = ImageChops.multiply(r, rad).filter(ImageFilter.GaussianBlur(u(0.8)))
    core = Image.new("L", (M, M), 0); cr = u(11); ImageDraw.Draw(core).ellipse([c - cr, c - cr, c + cr, c + cr], fill=255)
    core = core.filter(ImageFilter.GaussianBlur(u(4)))
    l = ImageChops.lighter(r, core)
    return Image.merge("RGBA", (*Image.new("RGB", (M, M), GOLD).split(), l))

def outer_glow(alpha=0.9):
    a0, a1 = u(FRAME_IN), u(FRAME_OUT)
    g = Image.new("L", (M, M), 0); ImageDraw.Draw(g).rectangle([a0, a0, a1, a1], outline=255, width=u(3))
    g = g.filter(ImageFilter.GaussianBlur(u(2))).point(lambda v: int(min(255, v * 1.6) * alpha))
    return Image.merge("RGBA", (*Image.new("RGB", (M, M), GLOW).split(), g))

def scale_about_centre(im, k):
    s = int(M * k); sm = im.resize((s, s), Image.LANCZOS)
    out = Image.new("RGBA", (M, M), (0, 0, 0, 0)); out.paste(sm, ((M - s) // 2, (M - s) // 2), sm); return out

def render(glyph, state):
    well, wmask = frame_layers()
    img = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    if state in ("hover", "pressed"): img = Image.alpha_composite(img, outer_glow(1.0 if state == "pressed" else 0.8))
    img = Image.alpha_composite(img, well)
    inner = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    if state == "pressed": inner = Image.alpha_composite(inner, rays())
    if glyph:
        gl = glyph_layer(GLYPHS[glyph](), {"normal": 1.0, "hover": 1.12, "pressed": 1.28, "disabled": 1.0}[state])
        if state == "pressed": gl = scale_about_centre(gl, 0.94)
        inner = Image.alpha_composite(inner, gl)
    inner.putalpha(ImageChops.multiply(inner.split()[3], wmask))
    img = Image.alpha_composite(img, inner)
    img = Image.alpha_composite(img, edge_glow({"normal": 0.55, "hover": 0.9, "pressed": 1.0, "disabled": 0.2}[state]))
    img = Image.alpha_composite(img, gloss())
    img = Image.alpha_composite(img, bevel_frame())
    if state == "hover": img = Image.alpha_composite(img, Image.new("RGBA", (M, M), (0, 0, 0, 0)))
    if state == "disabled":
        a = img.split()[3]; g = img.convert("L").convert("RGB"); img = g.convert("RGBA"); img.putalpha(a.point(lambda v: int(v * 0.6)))
    return img

def down(im, s):
    # 2-step Lanczos then light unsharp so 20 px still reads
    out = im.resize((s * 2, s * 2), Image.LANCZOS).resize((s, s), Image.LANCZOS)
    return out.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=0)) if s <= 64 else out

STATES = ["normal", "hover", "pressed", "disabled"]
if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    renders = {}
    for g in [None] + list(GLYPHS):
        for st in STATES:
            m = render(g, st); name = f"{g or 'frame'}_{st}"; renders[name] = m
            for s in (256, 64): down(m, s).save(f"{OUT}/{name}_{s}.png")
    # preview sheet: rows = glyphs, cols = states at 64, then 20 px and 16 px of normal/hover/pressed, on bg.base
    rows = [None] + list(GLYPHS); cw = 64 + 16
    W = 16 + len(STATES) * cw + 3 * 36 + 3 * 30 + 40 + 256 + 16
    H = max(16 + len(rows) * cw + 16, 16 + 256 + 16)
    sheet = Image.new("RGBA", (W, H), (0x0B, 0x0C, 0x10, 255))
    for r, g in enumerate(rows):
        y = 16 + r * cw; x = 16
        for st in STATES:
            sheet.alpha_composite(down(renders[f"{g or 'frame'}_{st}"], 64), (x, y)); x += cw
        for st in STATES[:3]:
            sheet.alpha_composite(down(renders[f"{g or 'frame'}_{st}"], 20), (x + 6, y + 22)); x += 36
        for st in STATES[:3]:
            sheet.alpha_composite(down(renders[f"{g or 'frame'}_{st}"], 16), (x + 6, y + 24)); x += 30
    sheet.alpha_composite(down(renders["settings_hover"], 256), (W - 256 - 16, 16))
    sheet.save(f"{OUT}/preview_sheet.png")
    # in-game-size check: 20 px icons upscaled x4 nearest
    strip = Image.new("RGBA", (len(GLYPHS) * 24, 24), (0x15, 0x17, 0x1D, 255))
    for i, g in enumerate(GLYPHS): strip.alpha_composite(down(renders[f"{g}_normal"], 20), (i * 24 + 2, 2))
    strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST).save(f"{OUT}/check_20px_x4.png")
    print("written", OUT)
