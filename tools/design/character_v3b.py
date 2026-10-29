from blz_frame import *
from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
k = 1.6; FW, FH = 540, 424
W_, H_ = int(FW * k) + 520, int(FH * k) + 200; c = Canvas(W_, H_); backdrop(c, W_, H_)
X, Y = 80, 70
frame(c, X, Y, FW, FH, k, 'Bmr', portrait_seed=77, bottom_tabs=['Character', 'Reputation', 'Currency'])
g = lambda v: v * k
# CharacterFrameInset (paper doll) and InsetRight (stats, 172 wide) - CharacterFrame.xml / PaperDollFrame.xml
ix, iy, iw, ih = X + g(4), Y + g(60), g(FW - 172 - 12), g(FH - 64)
rx, rw = X + g(FW - 172 - 4), g(172)
inset(c, ix, iy, iw, ih); inset(c, rx, iy, rw, ih, C['raised'])
c.T(X + g(70), Y + g(36), 'Level 90 Warlock · Destruction', int(7.5 * k), fill=C['t2'], anchor='lm')
c.T(X + g(FW - 180), Y + g(36), 'Item level 676', int(7.5 * k), 'SemiBold', (198, 120, 255), 'rm')
# model (game ModelScene, untouched) - soft glow behind
lay = _I.new('RGBA', c.im.size, (0, 0, 0, 0)); ld = _D.Draw(lay); mx = ix + iw / 2; my = iy + ih * 0.45
ld.ellipse([(mx - g(70)) * S, (my - g(110)) * S, (mx + g(70)) * S, (my + g(110)) * S], fill=(150, 90, 255, 80))
lay = lay.filter(_F.GaussianBlur(30 * S)); c.im.paste(lay, (0, 0), lay); c.d = ImageDraw.Draw(c.im)
c.d.ellipse([(mx - g(14)) * S, (my - g(110)) * S, (mx + g(14)) * S, (my - g(80)) * S], fill=(72, 56, 110))
c.d.polygon([((mx - g(16)) * S, (my - g(76)) * S), ((mx + g(16)) * S, (my - g(76)) * S), ((mx + g(40)) * S, (my - g(62)) * S), ((mx + g(34)) * S, (my + g(110)) * S),
             ((mx - g(34)) * S, (my + g(110)) * S), ((mx - g(40)) * S, (my - g(62)) * S)], fill=(72, 56, 110))
c.T(mx, iy + g(12), 'game model (unchanged)', int(6.5 * k), fill=C['t3'], anchor='mm')
# 8 + 8 slots, 37 px, 4 apart (PaperDollItemSlotButtonLeft/RightTemplate), weapons at the bottom
Q = [(163, 53, 238), (0, 112, 221), (163, 53, 238), (163, 53, 238), (255, 128, 0), None, None, (163, 53, 238)]
SL = g(37)
def slot(x, y, seed, q, lvl, side, enchant=False):
    if q:
        c.icon(int(x), int(y), int(SL), seed, r=3, quality=q)
        c.R(x + SL - g(17), y + SL - g(9), g(16), g(8), fill=(0, 0, 0), r=2); c.T(x + SL - g(2), y + SL - g(5), lvl, int(6 * k), 'SemiBold', C['t1'], 'rm')
        if enchant: c.d.ellipse([(x + g(2)) * S, (y + g(2)) * S, (x + g(7)) * S, (y + g(7)) * S], fill=C['warn'])
    else:
        c.R(x, y, SL, SL, fill=C['raised'], r=3, outline=C['border'])
for i in range(8):
    y = iy + g(2) + i * g(41)
    slot(ix + g(4), y, i * 7 + 1, Q[i], str(670 + i), 'L', enchant=(i == 3))
    slot(ix + iw - g(4) - SL, y, i * 11 + 5, ((163, 53, 238) if i != 4 else (0, 112, 221)), str(672 + i), 'R', enchant=(i == 5))
for j in range(2): slot(ix + iw / 2 - SL - g(2.5) + j * (SL + g(5)), iy + ih - g(16) - SL, 90 + j, (255, 128, 0), '684', 'B')
# InsetRight: sidebar tabs (portrait tab = game portrait; titles / equipment manager = Phoenix chrome icons)
tx = rx + rw - g(8)
for n, (kind, name) in enumerate([('chrome', 'macro-save'), ('chrome', 'tab-text'), ('game', None)]):
    tx -= g(33); on = n == 2
    c.R(tx, iy + g(6), g(30), g(30), fill=C['hover'] if not on else soft(C['acc'], 0.18, C['raised']), r=4, outline=C['acc'] if on else C['borderS'])
    if kind == 'game': c.icon(int(tx + g(4)), int(iy + g(10)), int(g(22)), 77, r=int(g(11)))
    else: chrome(c, tx + g(7), iy + g(13), name, C['t2'], int(g(16)))
    tx -= g(4)
# stats pane (CharacterStatsPane: Item Level, Attributes, Enhancements)
sy = iy + g(44)
def cat(y, t):
    c.R(rx + g(6), y, rw - g(12), g(16), fill=C['hover'], r=3); c.T(rx + rw / 2, y + g(8), t, int(7.5 * k), 'SemiBold', C['t1'], 'mm'); return y + g(20)
sy = cat(sy, 'Item Level'); c.T(rx + rw / 2, sy + g(9), '676.4', int(15 * k), 'Bold', (198, 120, 255), 'mm'); c.T(rx + rw / 2, sy + g(22), '678 equipped max', int(6.5 * k), fill=C['t3'], anchor='mm'); sy += g(34)
sy = cat(sy, 'Attributes')
for a, v in [('Intellect', '16,480'), ('Stamina', '151,800'), ('Armor', '4,120')]:
    c.T(rx + g(10), sy + g(6), a, int(7.5 * k), fill=C['t2'], anchor='lm'); c.T(rx + rw - g(10), sy + g(6), v, int(7.5 * k), 'SemiBold', C['t1'], 'rm'); sy += g(14)
sy = cat(sy + g(4), 'Enhancements')
for a, v, f, col in [('Critical Strike', '24.10%', .48, (240, 96, 80)), ('Haste', '18.42%', .37, (250, 200, 70)), ('Mastery', '38.85%', .6, (90, 160, 255)), ('Versatility', '6.20%', .15, (110, 210, 140)), ('Leech', '2.00%', .05, (200, 120, 255))]:
    c.T(rx + g(10), sy + g(6), a, int(7.5 * k), fill=C['t2'], anchor='lm'); c.T(rx + rw - g(10), sy + g(6), v, int(7.5 * k), 'SemiBold', C['t1'], 'rm')
    c.R(rx + g(10), sy + g(12), rw - g(20), g(2), fill=C['hover'], r=1); c.R(rx + g(10), sy + g(12), (rw - g(20)) * f, g(2), fill=col, r=1); sy += g(18)
# notes
def note(x, y, t, tx, ty):
    w = c.tw(t, 12, 'Medium') + 20; c.R(x, y, w, 26, fill=(255, 214, 102), r=4); c.T(x + 10, y + 13, t, 12, 'Medium', (30, 24, 10), 'lm'); c.L(x, y + 13, tx, ty, (255, 214, 102))
NX = X + FW * k + 40
note(NX, Y + 30, "Blizzard's layout: 540x424, 8+8 slots, model, stats pane, 3 tabs", X + FW * k - 30, Y + 30)
note(NX, Y + 150, 'Item and portrait icons are the game\'s own - never replaced', ix + iw - 20, iy + 40)
note(NX, Y + 200, 'Phoenix icons only on chrome: sidebar tabs, close', rx + rw - 60, iy + g(20))
note(NX, Y + 290, 'Extras: item level, missing-enchant dot (yellow), stat bars', ix + g(10), iy + g(125))
note(NX, Y + 380, 'Theme: dark surfaces, 1 px borders, Inter, accent tabs', rx + rw / 2, sy - 40)
c.save('/workspace/pui_restore/docs/screenshots/v3/character_v3.png', "Phoenix UI v3 mockup (revised t148) · Character window: Blizzard's layout, Phoenix theme · schematic render, not in-game · game icons are placeholders")
