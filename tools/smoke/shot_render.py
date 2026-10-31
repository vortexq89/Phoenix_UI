#!/usr/bin/env python3
"""Paints a scene written by tools/smoke/shot.lua (PUI_SHOT_OUT) into a PNG: the settings window as the game draws
it, with the bundled font files, the icon atlases and the texture files of the addon.
    python3 tools/smoke/shot_render.py <scene.json> <out.png> [scale]
Approximations: no font hinting or WoW's text renderer, string widths come from the real font file (the harness
lays text out with a fixed glyph width), and textures are drawn without mip-mapping."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
WHITE = ('WHITE', 'Interface\\Buttons\\WHITE8X8', 'Interface\\Buttons\\WHITE8x8', 'Interface\\BUTTONS\\WHITE8X8')


def local_path(p):
    if not p:
        return None
    p = p.replace('\\', '/')
    for prefix in ('Interface/AddOns/Phoenix_UI/', 'Interface/AddOns/Phoenix_UI_Options/'):
        if p.lower().startswith(prefix.lower()):
            rel = p[len(prefix):]
            base = ROOT if 'Phoenix_UI/' in prefix else os.path.join(ROOT, 'Phoenix_UI_Options')
            for ext in ('', '.tga', '.TGA', '.png', '.blp'):
                full = os.path.join(base, rel + ext)
                if os.path.exists(full):
                    return full
    return None


_tex, _font = {}, {}


def texture(p):
    if p in _tex:
        return _tex[p]
    img = None
    lp = local_path(p)
    if lp and not lp.endswith('.blp'):
        try:
            img = Image.open(lp).convert('RGBA')
        except Exception:
            img = None
    _tex[p] = img
    return img


def font(path, size):
    key = (path, size)
    if key not in _font:
        lp = local_path(path) or os.path.join(ROOT, 'Media', 'Fonts', 'PhoenixFont-Regular.ttf')
        try:
            _font[key] = ImageFont.truetype(lp, size)
        except Exception:
            _font[key] = ImageFont.truetype(os.path.join(ROOT, 'Media', 'Fonts', 'PhoenixFont-Regular.ttf'), size)
    return _font[key]


def rgba(c, alpha=1.0):
    c = [v if isinstance(v, (int, float)) else 1 for v in (c if isinstance(c, list) else [])]
    c = (c + [1, 1, 1, 1])[:4]
    a = (c[3] if len(c) > 3 else 1) * alpha
    return tuple(max(0, min(255, int(round(v * 255)))) for v in (c[0], c[1], c[2], a))


def gradient(w, h, g, alpha):
    def num4(c):
        c = [v if isinstance(v, (int, float)) else 1 for v in (c if isinstance(c, list) else [])]
        return (c + [1, 1, 1, 1])[:4]
    o, c1, c2 = g[0], num4(g[1]), num4(g[2])
    img = Image.new('RGBA', (w, h))
    px = img.load()
    for i in range(w if o == 'HORIZONTAL' else h):
        t = i / max(1, (w if o == 'HORIZONTAL' else h) - 1)
        if o != 'HORIZONTAL':
            t = 1 - t  # WoW: the first colour is at the bottom
        col = rgba([c1[k] + (c2[k] - c1[k]) * t for k in range(4)], alpha)
        if o == 'HORIZONTAL':
            for y in range(h):
                px[i, y] = col
        else:
            for x in range(w):
                px[x, i] = col
    return img


def paste(canvas, img, x, y, clip, s):
    if clip:
        cx0, cy0, cx1, cy1 = [int(round(v * s)) for v in clip]
        l, t = max(x, cx0), max(y, cy0)
        r, b = min(x + img.width, cx1), min(y + img.height, cy1)
        if r <= l or b <= t:
            return
        img = img.crop((l - x, t - y, r - x, b - y))
        x, y = l, t
    canvas.alpha_composite(img, (x, y)) if x >= 0 and y >= 0 else canvas.paste(img, (x, y), img)


def draw_tex(canvas, it, s):
    x, y, w, h = it['rect']
    X, Y, Wd, Ht = int(round(x * s)), int(round(y * s)), max(1, int(round(w * s))), max(1, int(round(h * s)))
    alpha = it.get('alpha', 1)
    tex = it.get('tex')
    if it.get('grad'):
        img = gradient(Wd, Ht, it['grad'], alpha)
        src = None if tex in WHITE or not tex else texture(tex)
        if src is not None:
            mask = src.resize((Wd, Ht), Image.LANCZOS).getchannel('A')
            img.putalpha(Image.composite(img.getchannel('A'), Image.new('L', img.size, 0), mask))
        paste(canvas, img, X, Y, it.get('clip'), s)
        return
    col = rgba(it.get('vc'), alpha)
    if not tex or tex in WHITE:
        img = Image.new('RGBA', (Wd, Ht), col)
    else:
        src = texture(tex)
        if src is None:
            # game art (spell icons, Blizzard atlases) is not on disk here: a neutral tile in its place
            img = Image.new('RGBA', (Wd, Ht), (0, 0, 0, 0))
            dd = ImageDraw.Draw(img)
            dd.rectangle((0, 0, Wd - 1, Ht - 1), fill=(46, 44, 52, int(230 * alpha)), outline=(78, 74, 86, int(255 * alpha)))
            if Wd > 12 and Ht > 12:
                dd.rectangle((Wd // 4, Ht // 4, Wd * 3 // 4, Ht * 3 // 4), fill=(66, 60, 72, int(255 * alpha)))
            paste(canvas, img, X, Y, it.get('clip'), s)
            return
        tc = it.get('tc') or [0, 1, 0, 1]
        sw, sh = src.size
        box = (int(round(tc[0] * sw)), int(round(tc[2] * sh)), int(round(tc[1] * sw)), int(round(tc[3] * sh)))
        if box[2] <= box[0] or box[3] <= box[1]:
            return
        part = src.crop(box).resize((Wd, Ht), Image.LANCZOS)
        r, g, b, a = part.split()
        r = r.point(lambda v: v * col[0] // 255); g = g.point(lambda v: v * col[1] // 255)
        b = b.point(lambda v: v * col[2] // 255); a = a.point(lambda v: v * col[3] // 255)
        img = Image.merge('RGBA', (r, g, b, a))
    paste(canvas, img, X, Y, it.get('clip'), s)


def wrap_lines(text, f, width):
    out = []
    for para in text.split('\n'):
        words, line = para.split(' '), ''
        for wd in words:
            test = (line + ' ' + wd).strip()
            if width and f.getlength(test) > width and line:
                out.append(line); line = wd
            else:
                line = test
        out.append(line)
    return out


def ellipsize(line, f, width):
    if not width or f.getlength(line) <= width:
        return line
    while line and f.getlength(line + '\u2026') > width:
        line = line[:-1]
    return line + '\u2026'


def draw_text(canvas, it, s):
    fnt = it.get('font') or ['', 13, '']
    sc = it.get('scale', 1)
    size = max(6, int(round(float(fnt[1] or 13) * sc * s)))
    f = font(fnt[0], size)
    text = it['text']
    import re
    text = re.sub(r'\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a', '', text)
    xs, ys = it['xs'], it['ys']
    lo = next((p[1] for p in xs if p[0] == 0), None)
    hi = next((p[1] for p in xs if p[0] == 1), None)
    width = None
    if lo is not None and hi is not None:
        width = (hi - lo) * s
    elif it.get('w'):
        width = it['w'] * sc * s
    lines = wrap_lines(text, f, width) if (it.get('wrap') and width) else [text]
    if not it.get('wrap') and width:
        lines = [ellipsize(lines[0], f, width)]
    asc, desc = f.getmetrics()
    lh = int(round(size * 1.18))
    bh = lh * len(lines)
    tw = max(f.getlength(l) for l in lines) if lines else 0
    if width is None:
        width = tw
    if lo is not None:
        left = lo * s
    else:
        p = xs[0]
        left = p[1] * s - width * p[0]
    top_p = next((p[1] for p in ys if p[0] == 1), None)
    bot_p = next((p[1] for p in ys if p[0] == 0), None)
    box_h = None
    if top_p is not None and bot_p is not None:
        top, box_h = top_p * s, (bot_p - top_p) * s
    elif it.get('h'):
        box_h = it['h'] * sc * s
        p = ys[0]
        top = p[1] * s - box_h * (1 - p[0])
    else:
        p = ys[0]
        top = p[1] * s - bh * (1 - p[0])
    if box_h is not None:
        jv = it.get('jv') or 'MIDDLE'
        top = top + (0 if jv == 'TOP' else (box_h - bh if jv == 'BOTTOM' else (box_h - bh) / 2))
    jh = it.get('jh') or 'CENTER'
    col = rgba(it.get('col'), it.get('alpha', 1))
    layer = Image.new('RGBA', (int(width + 8 * s) + 4, int(bh + 6 * s) + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    outline = 'OUTLINE' in (fnt[2] or '')
    for i, line in enumerate(lines):
        lw = f.getlength(line)
        x = 2 + (0 if jh == 'LEFT' else ((width - lw) if jh == 'RIGHT' else (width - lw) / 2))
        y = 2 + i * lh + (lh - (asc + desc)) / 2
        if outline:
            d.text((x, y), line, font=f, fill=col, stroke_width=max(1, int(s)), stroke_fill=(0, 0, 0, col[3]))
        else:
            d.text((x, y), line, font=f, fill=col)
    paste(canvas, layer, int(round(left)) - 2, int(round(top)) - 2, it.get('clip'), s)


def main():
    scene, out = sys.argv[1], sys.argv[2]
    s = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    d = json.load(open(scene, encoding='utf-8'))
    wx, wy, ww, wh = d['window']
    sw, sh = d['screen']
    canvas = Image.new('RGBA', (int(sw * s), int(sh * s)), (10, 10, 12, 255))
    items = sorted(d['items'], key=lambda i: (i['lvl'], i['layer'], i['sub'], i['seq']))
    for it in items:
        if it['kind'] == 'tex':
            draw_tex(canvas, it, s)
        else:
            draw_text(canvas, it, s)
    pad = int(24 * s)
    crop = canvas.crop((max(0, int(wx * s) - pad), max(0, int(wy * s) - pad),
                        min(canvas.width, int((wx + ww) * s) + pad), min(canvas.height, int((wy + wh) * s) + pad)))
    crop.convert('RGB').save(out)
    print(out, crop.size)


if __name__ == '__main__':
    main()
