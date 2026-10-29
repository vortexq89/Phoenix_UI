from blz_frame import *
from PIL import Image as _I, ImageDraw as _D, ImageFilter as _F
k = 1.3; FW, FH = 703, 606
W_, H_ = int(FW * k) + 480, int(FH * k) + 170; c = Canvas(W_, H_); backdrop(c, W_, H_)
X, Y = 70, 60; g = lambda v: v * k
frame(c, X, Y, FW, FH, k, 'Mounts', panel='panel-collections', bottom_tabs=['Mounts', 'Pets', 'Toys', 'Heirlooms', 'Appearances', 'Campsites'])
# MountCount (InsetFrameTemplate3 130x20) top-left, LeftInset 260x496, RightInset to the frame's right
c.R(X + g(70), Y + g(30), g(130), g(20), fill=C['sunken'], r=3, outline=C['borderS']); c.T(X + g(78), Y + g(40), 'Total mounts', int(7 * k), fill=C['t2'], anchor='lm'); c.T(X + g(192), Y + g(40), '612', int(7.5 * k), 'SemiBold', C['acc'], 'rm')
lx, ly, lw, lh = X + g(4), Y + g(60), g(260), g(FH - 60 - 34)
inset(c, lx, ly, lw, lh)
rx = lx + lw + g(20) - g(18); ry = ly; rw = X + g(FW - 6) - rx; rh = g(FH - 60 - 34)
inset(c, rx, ry, rw, rh)
# search box (145x20) and filter dropdown, Phoenix chrome icons
c.R(lx + g(11), ly + g(9), g(145), g(20), fill=C['base'], r=3, outline=C['borderS']); chrome(c, lx + g(15), ly + g(12), 'win-search', C['t3'], int(g(14))); c.T(lx + g(32), ly + g(19), 'Search', int(7.5 * k), fill=C['t3'], anchor='lm')
fx = lx + lw - g(5) - g(90); c.R(fx, ly + g(9), g(90), g(20), fill=C['hover'], r=3, outline=C['border']); chrome(c, fx + g(6), ly + g(12), 'win-filter', C['t2'], int(g(14))); c.T(fx + g(26), ly + g(19), 'Filter', int(7.5 * k), 'Medium', C['t1'], 'lm'); chrome(c, fx + g(72), ly + g(12), 'win-expand', C['t2'], int(g(14)))
names = [("Ashes of Al'ar", True, True), ('Invincible', True, False), ("Mimiron's Head", True, False), ('Armored Bloodwing', True, False), ('Blue Wind Rider', True, False),
 ('Swift Spectral Tiger', False, False), ('Onyxian Drake', True, True), ('Felsteel Annihilator', False, False), ('Sandstone Drake', True, False)]
yy = ly + g(36)
for i, (n, have, fav) in enumerate(names):   # rows 208x46, icon 38 (MountListButtonTemplate)
    on = i == 0; bx = lx + g(44)
    if on: c.R(bx - g(40), yy, g(250), g(46), fill=soft(C['acc'], 0.12, C['sunken']), r=4); c.R(bx - g(40), yy + g(8), 2, g(30), fill=C['acc'])
    c.icon(int(bx - g(36)), int(yy + g(4)), int(g(38)), i * 13 + 2, r=3, quality=(255, 128, 0) if on else C['border'])
    if not have:
        ov = _I.new('RGBA', c.im.size, (0, 0, 0, 0)); _D.Draw(ov).rectangle([(bx - g(36)) * S, (yy + g(4)) * S, (bx + g(2)) * S, (yy + g(42)) * S], fill=(16, 18, 21, 170)); c.im.paste(ov, (0, 0), ov); c.d = ImageDraw.Draw(c.im)
    c.T(bx + g(10), yy + g(17), n, int(8 * k), 'SemiBold' if on else 'Medium', C['t1'] if have else C['t3'], 'lm')
    c.T(bx + g(10), yy + g(31), 'Flying' if i % 2 == 0 else 'Ground', int(6.5 * k), fill=C['t3'], anchor='lm')
    if fav: chrome(c, bx + g(186), yy + g(9), 'win-favorite', C['acc'], int(g(12)))
    yy += g(50)
c.R(lx + lw - g(6), ly + g(36), g(3), lh - g(44), fill=C['hover'], r=2); c.R(lx + lw - g(6), ly + g(36), g(3), g(80), fill=C['t3'], r=2)
# MountDisplay: name + icon on top, model, lore + source at the bottom, Summon button below the inset
c.icon(int(rx + g(12)), int(ry + g(10)), int(g(30)), 2, r=3, quality=(255, 128, 0)); c.T(rx + g(50), ry + g(25), "Ashes of Al'ar", int(11 * k), 'Bold', C['t1'], 'lm')
lay = _I.new('RGBA', c.im.size, (0, 0, 0, 0)); ld = _D.Draw(lay); mx, my = rx + rw / 2, ry + rh * 0.45
ld.ellipse([(mx - g(150)) * S, (my - g(110)) * S, (mx + g(150)) * S, (my + g(110)) * S], fill=(255, 110, 30, 100)); lay = lay.filter(_F.GaussianBlur(40 * S)); c.im.paste(lay, (0, 0), lay); c.d = ImageDraw.Draw(c.im)
c.d.polygon([((mx - g(150)) * S, (my - g(40)) * S), ((mx - g(40)) * S, (my - g(6)) * S), ((mx - g(6)) * S, (my - g(60)) * S), ((mx + g(14)) * S, (my - g(20)) * S), ((mx + g(150)) * S, (my - g(52)) * S),
             ((mx + g(40)) * S, (my + g(20)) * S), ((mx + g(14)) * S, (my + g(80)) * S), ((mx - g(14)) * S, (my + g(26)) * S)], fill=(255, 150, 60))
c.T(mx, my + g(100), 'game model (unchanged)', int(6.5 * k), fill=C['t3'], anchor='mm')
by = ry + rh - g(70); c.R(rx + g(8), by, rw - g(16), g(62), fill=C['raised'], r=4, outline=C['borderS'])
c.T(rx + g(16), by + g(12), 'Source:  Drop: Kael\'thas Sunstrider · The Eye', int(7.5 * k), 'Medium', C['t1'], 'lm')
c.T(rx + g(16), by + g(28), "Al'ar was the beloved pet of Kael'thas Sunstrider, who often", int(7 * k), fill=C['t2'], anchor='lm')
c.T(rx + g(16), by + g(40), 'boasted that death would never claim it.', int(7 * k), fill=C['t2'], anchor='lm')
c.T(rx + g(16), by + g(53), 'Phoenix: used 214 times · learned 2019-03-11', int(6.5 * k), 'Medium', C['acc'], 'lm')
sbw = g(140); c.R(X + g(FW - 6) - sbw, Y + g(FH - 28), sbw, g(22), fill=C['acc'], r=4); c.T(X + g(FW - 6) - sbw / 2, Y + g(FH - 17), 'Summon', int(8 * k), 'SemiBold', (20, 12, 6), 'mm')
c.R(lx, Y + g(FH - 28), g(160), g(22), fill=C['hover'], r=4, outline=C['border']); chrome(c, lx + g(6), Y + g(FH - 24), 'win-settings', C['t2'], int(g(14))); c.T(lx + g(26), Y + g(FH - 17), 'Mount equipment', int(7.5 * k), 'Medium', C['t1'], 'lm')
def note(x, y, t, tx, ty):
    w = c.tw(t, 12, 'Medium') + 20; c.R(x, y, w, 26, fill=(255, 214, 102), r=4); c.T(x + 10, y + 13, t, 12, 'Medium', (30, 24, 10), 'lm'); c.L(x, y + 13, tx, ty, (255, 214, 102))
NX = X + FW * k + 30
note(NX, Y + 20, "Blizzard's layout: 703x606, list 260 wide, 6 bottom tabs", X + FW * k - 20, Y + 20)
note(NX, Y + 120, 'Mount, pet and toy icons and models stay the game\'s', rx + rw - 40, ry + 60)
note(NX, Y + 170, 'Phoenix chrome icons: search, filter, favourite, settings', lx + lw - 40, ly + 20)
note(NX, Y + 400, 'Extras: usage count and learned date, favourite marker', rx + rw - 60, by + g(53))
note(NX, Y + 450, 'Not owned: dimmed icon and name (game data)', lx + g(100), ly + g(36) + 5 * g(50) + 20)
c.save('/workspace/pui_restore/docs/screenshots/v3/collections_v3.png', "Phoenix UI v3 mockup (revised t149) · Collections › Mounts: Blizzard's layout, Phoenix theme · schematic render, not in-game · game icons are placeholders")
