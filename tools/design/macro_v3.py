from blz_frame import *
k = 1.7; FW, FH = 338, 424
W_, H_ = int(FW * k) + 540, int(FH * k) + 140; c = Canvas(W_, H_); backdrop(c, W_, H_)
X, Y = 70, 60; g = lambda v: v * k
frame(c, X, Y, FW, FH, k, 'Create Macros', panel='panel-macro')
# PanelTopTabButtonTemplate tabs: General / Character (Phoenix chrome icons on the tabs)
tx = X + g(60); ty = Y + g(28)
for i, (t, ic) in enumerate([('General Macros', 'macro-general'), ('Bmr Specific Macros', 'macro-character')]):
    w = c.tw(t, int(7.5 * k), 'Medium') + g(34); on = i == 0
    c.R(tx, ty, w, g(22), fill=C['raised'] if on else C['base'], r=4, outline=C['acc'] if on else C['borderS'])
    chrome(c, tx + g(7), ty + g(4), ic, C['acc'] if on else C['t2'], int(g(14))); c.T(tx + g(25), ty + g(11), t, int(7.5 * k), 'SemiBold' if on else 'Medium', C['t1'] if on else C['t2'], 'lm'); tx += w + g(3)
# MacroSelector: 319x146, 6 per row, 36 px buttons - the macros' icons are the player's chosen game icons
gx, gy = X + g(10), Y + g(56); inset(c, gx, gy, g(319), g(146))
for i in range(18):
    bx = gx + g(8) + (i % 6) * g(51); by = gy + g(6) + (i // 6) * g(46)
    if i < 14:
        c.icon(int(bx), int(by), int(g(36)), i * 9 + 4, r=3, quality=C['acc'] if i == 2 else C['border'])
        c.T(bx + g(18), by + g(42), ['Burst', 'Focus', 'Cast', 'Kick', 'Mount', 'Port', 'Pet', 'Sac', 'Def', 'Soul', 'Gate', 'Fear', 'HS', 'Trink'][i], int(5.5 * k), 'Medium', C['t2'], 'mm')
    else: c.R(bx, by, g(36), g(36), fill=C['raised'], r=3, outline=C['borderS'])
# selected macro: 64 slot + name + "Change Name/Icon" (Phoenix rename glyph on the button only)
sy = gy + g(154); c.R(X + g(10), sy, g(48), g(48), fill=C['raised'], r=4, outline=C['border']); c.icon(int(X + g(16)), int(sy + g(6)), int(g(36)), 22, r=3)
c.T(X + g(66), sy + g(12), 'Cast', int(10 * k), 'Bold', C['t1'], 'lm')
c.R(X + g(66), sy + g(24), g(150), g(20), fill=C['hover'], r=4, outline=C['border']); chrome(c, X + g(71), sy + g(27), 'macro-rename', C['t2'], int(g(14))); c.T(X + g(90), sy + g(34), 'Change Name/Icon', int(7.5 * k), 'Medium', C['t1'], 'lm')
# Enter Macro Commands: 286x85 edit box, char count (Phoenix extra: syntax colours, used count turns amber near 255)
c.T(X + g(14), sy + g(60), 'Enter Macro Commands:', int(7 * k), 'Medium', C['t2'], 'lm')
ex, ey = X + g(14), sy + g(68); inset(c, ex, ey, g(306), g(95))
lines = [[('#showtooltip', C['t3'])], [('/cast ', (255, 170, 60)), ('[@mouseover,harm,nodead][]', (120, 180, 255)), (' Chaos Bolt', C['t1'])],
         [('/use ', (255, 170, 60)), ('13', (130, 220, 150))], [('/startattack', (255, 170, 60))]]
for j, ln in enumerate(lines):
    x = ex + g(8)
    for t, col in ln: c.T(x, ey + g(12) + j * g(14), t, int(7.5 * k), 'Medium', col, 'lm'); x += c.tw(t, int(7.5 * k), 'Medium')
c.T(ex + g(306), ey + g(104), '96 / 255 characters used', int(6.5 * k), 'Medium', C['t3'], 'rm')
# bottom buttons: Delete, New, Exit (UIPanelButtonTemplate 80x22) with chrome glyphs
bx = X + g(FW - 6)
for t, ic, kind in [('Exit', 'win-close', 'secondary'), ('New', 'macro-new', 'primary'), ('Delete', 'macro-delete', 'secondary')]:
    w = g(80); bx -= w + g(4)
    if kind == 'primary': c.R(bx, Y + g(FH - 28), w, g(22), fill=C['acc'], r=4); col = (20, 12, 6)
    else: c.R(bx, Y + g(FH - 28), w, g(22), fill=C['hover'], r=4, outline=C['border']); col = C['t1']
    chrome(c, bx + g(8), Y + g(FH - 24), ic, col, int(g(14))); c.T(bx + g(48), Y + g(FH - 17), t, int(7.5 * k), 'SemiBold', col, 'mm')
def note(x, y, t, tx, ty):
    w = c.tw(t, 12, 'Medium') + 20; c.R(x, y, w, 26, fill=(255, 214, 102), r=4); c.T(x + 10, y + 13, t, 12, 'Medium', (30, 24, 10), 'lm'); c.L(x, y + 13, tx, ty, (255, 214, 102))
NX = X + FW * k + 30
note(NX, Y + 30, "Blizzard's layout: 338x424, 2 tabs, 6-wide grid, edit box", X + FW * k - 30, Y + 20)
note(NX, Y + 90, 'Phoenix icons: tabs, rename, New / Delete / Exit', tx - 40, ty + g(11))
note(NX, Y + 200, "Macro icons are the player's chosen game icons - untouched", gx + g(300), gy + g(40))
note(NX, Y + 470, 'Extras: syntax colours, live character count', ex + g(300), ey + g(30))
c.save('/workspace/pui_restore/docs/screenshots/v3/macro_v3.png', "Phoenix UI v3 mockup · Macro window: Blizzard's layout, Phoenix theme · schematic render, not in-game · macro icons are placeholders for game art")
