from kit import *
names = list(CHROME)
groups = [('Micro menu', [n for n in names if n.startswith('micro-')]), ('Settings nav & GUI tabs', [n for n in names if n.startswith(('nav-', 'tab-'))]),
          ('Macro window chrome', [n for n in names if n.startswith('macro-')]), ('Window controls', [n for n in names if n.startswith('win-')])]
W_ = 1500; H_ = 120 + sum(((len(g) + 9) // 10) * 112 + 50 for _, g in groups) + 40
c = Canvas(W_, H_, C['base'])
c.T(32, 28, 'Phoenix chrome icons v3 — original set, 24-unit grid, 1.75 stroke, round caps, one tint', 18, 'Bold')
c.T(32, 58, 'UI chrome only (micro menu, settings nav, GUI tabs, macro window controls, window controls). Class, spec, ability, spell and item icons are never replaced.', 12, fill=C['t2'])
y = 100
for title, g in groups:
    c.T(32, y, title.upper(), 11, 'SemiBold', C['acc']); y += 24
    for i, n in enumerate(g):
        x = 32 + (i % 10) * 144; yy = y + (i // 10) * 112
        c.R(x, yy, 132, 100, fill=C['raised'], r=6, outline=C['borderS'])
        chrome(c, x + 14, yy + 12, n, C['t1'], 48)
        chrome(c, x + 76, yy + 14, n, C['t2'], 20); chrome(c, x + 102, yy + 16, n, C['acc'], 16)
        c.T(x + 66, yy + 84, n, 10, 'Medium', C['t3'], 'mm')
    y += ((len(g) + 9) // 10) * 112 + 26
c.save('/workspace/pui_restore/docs/screenshots/v3/chrome_icons.png', 'Phoenix UI · chrome icon set (48 px, plus 20 and 16 px as drawn in game) · original work')
