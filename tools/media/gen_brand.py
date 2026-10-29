"""Phoenix brand textures from tools/media/brand/flame_crest_source.png (the Flame Crest emblem, ours).

Writes Media/Textures: Emblem64/128/256, Logo512/1024 (emblem + PHOENIX wordmark in Cinzel), EmblemGlow (white
blurred silhouette, tinted in game) and Embers (8x4 flipbook of rising embers, 64 px cells, white, tinted in game).
With --web DIR also the website favicon set. Uncompressed TGA, power-of-two sizes. Run: python3 tools/media/gen_brand.py
"""
import os, sys, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Media", "Textures")
FONT = os.path.join(ROOT, "Media", "Fonts", "Cinzel-Bold.ttf")


def emblem():
    src = Image.open(os.path.join(ROOT, "tools", "media", "brand", "flame_crest_source.png")).convert("RGB")
    a = np.asarray(src).astype(np.float64)
    alpha = np.clip((a.max(axis=2) - 14.0) / 46.0, 0, 1)
    rgb = np.where(alpha[..., None] > 0, np.clip(a / np.maximum(alpha[..., None], 1e-3), 0, 255), 0)
    im = Image.fromarray(np.dstack([rgb, alpha * 255]).astype("uint8"), "RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    im = im.crop(box)
    side = int(max(im.size) * 1.08)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize((1024, 1024), Image.LANCZOS)


def small(e, px):
    im = e.resize((px, px), Image.LANCZOS)
    if px <= 64:
        im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    return im


def logo(e, w):
    h = w // 4
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    es = int(h * 0.92)
    im.alpha_composite(e.resize((es, es), Image.LANCZOS), (int(h * 0.06), (h - es) // 2))
    font = ImageFont.truetype(FONT, int(h * 0.56))
    text = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(text)
    x0 = int(h * 1.12)
    bb = d.textbbox((0, 0), "PHOENIX", font=font)
    d.text((x0, (h - (bb[3] - bb[1])) // 2 - bb[1]), "PHOENIX", font=font, fill=255)
    grad = np.zeros((h, w, 3))
    t = np.linspace(0, 1, w)[None, :, None]
    grad[:] = (1 - t) * np.array([255, 106, 26]) + t * np.array([255, 178, 63])
    word = Image.fromarray(np.dstack([grad, np.asarray(text)]).astype("uint8"), "RGBA")
    im.alpha_composite(word)
    return im


def glow(e):
    a = e.getchannel("A").resize((128, 128), Image.LANCZOS)
    pad = Image.new("L", (128, 128), 0)
    pad.paste(a.resize((96, 96), Image.LANCZOS), (16, 16))
    g = pad.filter(ImageFilter.GaussianBlur(9)).point(lambda v: min(255, int(v * 1.6)))
    return Image.merge("RGBA", (Image.new("L", g.size, 255),) * 3 + (g,))


def embers():
    cell, cols, rows = 64, 8, 4
    frames = cols * rows
    rnd = random.Random(1729)
    parts = [(rnd.uniform(10, 54), rnd.uniform(0, 1), rnd.uniform(1.2, 2.6), rnd.uniform(-6, 6)) for _ in range(14)]
    sheet = Image.new("L", (cell * cols, cell * rows), 0)
    for f in range(frames):
        fr = Image.new("L", (cell * 4, cell * 4), 0)
        d = ImageDraw.Draw(fr)
        for x, phase, r, drift in parts:
            p = (f / frames + phase) % 1.0             # loops seamlessly: every ember wraps after one cycle
            y = (1 - p) * (cell - 4) + 2
            xx = x + drift * np.sin(p * 6.283)
            fade = np.sin(p * 3.1416)
            v = int(255 * fade)
            d.ellipse(((xx - r) * 4, (y - r) * 4, (xx + r) * 4, (y + r) * 4), fill=v)
        fr = fr.resize((cell, cell), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
        sheet.paste(fr, ((f % cols) * cell, (f // cols) * cell))
    return Image.merge("RGBA", (Image.new("L", sheet.size, 255),) * 3 + (sheet,))


def web(e, d):
    os.makedirs(d, exist_ok=True)
    e.resize((256, 256), Image.LANCZOS).save(os.path.join(d, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    small(e, 32).save(os.path.join(d, "favicon-32.png"))
    touch = Image.new("RGBA", (180, 180), (11, 12, 16, 255))
    touch.alpha_composite(e.resize((150, 150), Image.LANCZOS), (15, 15))
    touch.convert("RGB").save(os.path.join(d, "apple-touch-icon.png"))
    og = Image.new("RGBA", (1200, 630), (11, 12, 16, 255))
    og.alpha_composite(logo(e, 1024), (88, 187))
    og.convert("RGB").save(os.path.join(d, "og-image.png"))


if __name__ == "__main__":
    e = emblem()
    for px in (64, 128, 256):
        small(e, px).save(os.path.join(OUT, f"Emblem{px}.tga"))
    logo(e, 512).save(os.path.join(OUT, "Logo512.tga"))
    logo(e, 1024).save(os.path.join(OUT, "Logo1024.tga"))
    glow(e).save(os.path.join(OUT, "EmblemGlow.tga"))
    embers().save(os.path.join(OUT, "Embers.tga"))
    if "--web" in sys.argv:
        web(e, sys.argv[sys.argv.index("--web") + 1])
    print("brand textures written")
