from kit import *
from gen_chrome_color import BASE, PANEL, STATES, render
# 1) chrome set: every icon in its four states at 64 px, plus 24 px as drawn on the nav rail
names = list(BASE); cols = 3; cw = 380; rh = 84
rows = (len(names) + cols - 1) // cols
c = Canvas(cols * cw + 40, rows * rh + 110, (16, 14, 18))
c.T(20, 18, 'Phoenix chrome icons v4 - full colour, ember gradient with depth   (normal · hover · pressed light-burst · disabled · 24 px)', 15, 'SemiBold', C['t1'])
for i, nm in enumerate(names):
    x = 20 + (i % cols) * cw; y = 56 + (i // cols) * rh
    for j, st in enumerate(STATES): chrome(c, x + j * 68, y, nm, None, 64, st)
    chrome(c, x + 4 * 68 + 6, y + 20, nm, None, 24, 'normal'); c.T(x + 4 * 68 + 40, y + 32, nm, 11, 'Medium', C['t3'], 'lm')
c.save('/workspace/pui_restore/docs/screenshots/v3/chrome_icons.png', 'Original work (Phoenix UI licence) · chrome only: never class, spec, ability, spell or item icons')
# 2) panel icons (window top-left corner): medallion, 96 px + 40 px
pn = list(PANEL); cols = 7
c = Canvas(cols * 170 + 40, ((len(pn) + cols - 1) // cols) * 170 + 90, (16, 14, 18))
c.T(20, 18, 'Phoenix panel icons - one per window, shown in its top-left corner (96 px master view, 40 px as drawn)', 15, 'SemiBold', C['t1'])
for i, nm in enumerate(pn):
    x = 30 + (i % cols) * 170; y = 56 + (i // cols) * 170
    panel_icon(c, x, y, nm, 96); panel_icon(c, x + 104, y + 28, nm, 40)
    c.T(x + 70, y + 120, nm.replace('panel-', '').title(), 13, 'SemiBold', C['t2'], 'mm')
c.save('/workspace/pui_restore/docs/screenshots/v3/panel_icons.png', 'Original work · panel icons replace no game art except the window portrait slot')
