"""Phoenix Font (t154): an OFL font derived from Barlow Semi Condensed (Copyright 2017 The Barlow Project Authors, OFL 1.1).
Tuned only by geometric transforms of Barlow's own outlines with fontTools; no outlines from any other font are used.
Targets come from rendered metrics of the reference look (x-height / cap 0.78, wider caps and tabular digits, open
spacing). Transforms per glyph class:
  lowercase: x-height zone raised 6.5% (points 0..xh*1.12 scaled, points above shifted, so stems stay straight), width x1.004
  uppercase: width x1.067   digits: width x1.126   everything: +4 units tracking (on 1000 UPM), off-curve points
  pushed 3% away from the contour centre (squarer curves). TrueType hints are dropped (FreeType autohints, as WoW does).
Weights (matched to the reference's heavier colour at small sizes): Regular <- Barlow SC Bold, SemiBold <- ExtraBold, Bold <- Black."""
import os, sys, unicodedata
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates
SRC = os.path.join(os.path.dirname(__file__), '..', '..', 'design', 'fonts')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), 'build')
WEIGHTS = [('Regular', 'Bold', 400), ('SemiBold', 'ExtraBold', 600), ('Bold', 'Black', 700)]
XH_GAIN, TRACK, SQ = 1.065, 4, 0.03
SX = {'lower': 1.004, 'upper': 1.067, 'digit': 1.126, 'other': 1.02}

def classify(cps):
    for cp in cps:
        ch = chr(cp); cat = unicodedata.category(ch)
        if ch.isdigit(): return 'digit'
        if cat == 'Ll': return 'lower'
        if cat == 'Lu': return 'upper'
    return 'other'

def build(src, style, wclass):
    f = TTFont(src); glyf = f['glyf']; hmtx = f['hmtx']; xh = f['OS/2'].sxHeight
    rev = {}
    for cp, g in f.getBestCmap().items(): rev.setdefault(g, []).append(cp)
    for tag in ('fpgm', 'prep', 'cvt ', 'DSIG', 'hdmx', 'LTSH', 'VDMX'):
        if tag in f: del f[tag]
    done = {}
    for name in f.getGlyphOrder():
        g = glyf[name]; k = classify(rev.get(name, [])); sx = SX[k]; done[name] = (k, sx)
        if hasattr(g, 'program'): g.program.fromBytecode(b'')
        if g.isComposite():
            for comp in g.components: comp.x = int(round(comp.x * sx))
        elif g.numberOfContours > 0:
            coords = list(g.coordinates); flags = g.flags; ends = g.endPtsOfContours; out = []; start = 0
            for e in ends:
                pts = coords[start:e + 1]; fl = flags[start:e + 1]
                cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
                for (x, y), on in zip(pts, fl):
                    if not (on & 1): x = x + (x - cx) * SQ; y = y + (y - cy) * SQ
                    if k == 'lower':
                        lim = xh * 1.12
                        y = y * XH_GAIN if 0 <= y <= lim else (y + lim * (XH_GAIN - 1) if y > lim else y)
                    out.append((int(round(x * sx)), int(round(y))))
                start = e + 1
            g.coordinates = GlyphCoordinates(out)
        adv, lsb = hmtx[name]
        hmtx[name] = (int(round(adv * sx)) + (TRACK if adv else 0), int(round(lsb * sx)) + (TRACK // 2 if adv else 0))
        if g.numberOfContours > 0 and not g.isComposite():
            g.coordinates = GlyphCoordinates([(x + (TRACK // 2 if adv else 0), y) for x, y in g.coordinates])
    for name in f.getGlyphOrder(): glyf[name].recalcBounds(glyf)
    os2 = f['OS/2']; os2.sxHeight = int(xh * XH_GAIN); os2.usWeightClass = wclass
    fam = 'Phoenix Font'; full = f'{fam} {style}' if style != 'Regular' else fam; ps = f'PhoenixFont-{style}'
    nm = f['name']
    for rec in list(nm.names):
        if rec.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25): nm.removeNames(nameID=rec.nameID)
    sub = style if style in ('Regular', 'Bold') else 'Regular'; fam1 = fam if style in ('Regular', 'Bold') else f'{fam} {style}'
    for i, v in ((1, fam1), (2, sub), (3, f'1.000;PHNX;{ps}'), (4, full), (6, ps), (16, fam), (17, style)):
        nm.setName(v, i, 3, 1, 0x409); nm.setName(v, i, 1, 0, 0)
    nm.setName('Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow). Phoenix Font modifications Copyright 2026 The Phoenix UI Authors.', 0, 3, 1, 0x409)
    nm.setName('Version 1.000; derived from Barlow Semi Condensed 1.408', 5, 3, 1, 0x409)
    nm.setName('This Font Software is licensed under the SIL Open Font License, Version 1.1.', 13, 3, 1, 0x409)
    nm.setName('https://openfontlicense.org', 14, 3, 1, 0x409)
    f['head'].fontRevision = 1.0
    if 'gasp' in f: f['gasp'].gaspRange = {0xFFFF: 0x000F}
    os.makedirs(OUT, exist_ok=True); p = os.path.join(OUT, ps + '.ttf'); f.save(p); return p

if __name__ == '__main__':
    for style, src, w in WEIGHTS: print(build(os.path.join(SRC, f'BarlowSemiCondensed-{src}.ttf'), style, w))
