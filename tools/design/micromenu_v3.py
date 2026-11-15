from blz_frame import *
k = 2.0; W_, H_ = 1500, 620; c = Canvas(W_, H_); backdrop(c, W_, H_)
c.T(40, 40, 'Micro menu — Blizzard order and size (13 buttons, 32x40, MainMenuBarMicroButtons.xml), Phoenix theme and chrome icons', 18, 'Bold')
BTN = [('Character', 'micro-character'), ('Professions', 'micro-professions'), ('Talents & Spellbook', 'micro-spells'), ('Achievements', 'micro-achievements'),
 ('Quest Log', 'micro-quests'), ('Housing', 'micro-housing'), ('Guild & Communities', 'micro-guild'), ('Group Finder', 'micro-groupfinder'),
 ('Collections', 'micro-collections'), ('Adventure Guide', 'micro-journal'), ('Help', 'micro-help'), ('Shop', 'micro-shop'), ('Game Menu', 'micro-menu')]
def bar(x0, y0, state_of, label):
    c.T(x0, y0 - 26, label, 12, 'SemiBold', C['acc'])
    w = 13 * 32 * k + 12 * 2 * k + 12; c.R(x0 - 6, y0 - 6, w, 40 * k + 12, fill=C['base'], r=6, outline=C['border'])
    for i, (n, ic) in enumerate(BTN):
        x = x0 + i * 34 * k; st = state_of(i)
        fill = {'default': C['raised'], 'hover': C['hover'], 'open': soft(C['acc'], 0.16, C['raised']), 'alert': C['raised'], 'off': C['raised']}[st]
        c.R(x, y0, 32 * k, 40 * k, fill=fill, r=4, outline=C['acc'] if st == 'open' else C['borderS'])
        col = {'default': C['t2'], 'hover': C['t1'], 'open': C['acc'], 'alert': C['t2'], 'off': (70, 74, 80)}[st]
        chrome(c, x + (32 * k - 20 * k) / 2, y0 + 8 * k, ic, col, int(20 * k))
        if st == 'open': c.R(x + 6, y0 + 40 * k - 3, 32 * k - 12, 2, fill=C['acc'])
        if st == 'alert': c.d.ellipse([(x + 32 * k - 13) * S, (y0 + 5) * S, (x + 32 * k - 5) * S, (y0 + 13) * S], fill=C['acc'])
bar(40, 120, lambda i: 'default', 'DEFAULT')
bar(40, 260, lambda i: {0: 'open', 3: 'alert', 7: 'hover', 11: 'off'}.get(i, 'default'), 'STATES: open (Character) · alert dot (Achievements) · hover (Group Finder) · disabled (Shop)')
# tooltip example
tx, ty = 40 + 7 * 34 * k, 260 + 40 * k + 20
c.R(tx, ty, 300, 92, fill=C['raised'], r=6, outline=C['border']); c.T(tx + 14, ty + 20, 'Group Finder', 14, 'SemiBold'); c.T(tx + 14, ty + 42, 'Shortcut: I', 12, fill=C['t3'])
c.T(tx + 14, ty + 64, 'Phoenix: queued as Healer · 4 min', 12, 'Medium', C['acc'])
c.T(40, 470, 'Phoenix extras: per-button show/hide, order, size, spacing, vertical layout, fade until mouseover, latency/FPS on the Game Menu button, queue status in tooltips.', 12, fill=C['t2'])
c.T(40, 492, 'Icons: the Phoenix chrome set, one tint per state. The Character button keeps no portrait art; class, spec and spell icons are never used here.', 12, fill=C['t2'])
c.save('/workspace/pui_restore/docs/screenshots/v3/micromenu_v3.png', "Phoenix UI v3 mockup · micro menu · schematic render, not in-game")
