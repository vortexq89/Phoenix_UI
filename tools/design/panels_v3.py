from blz_frame import *
# headers of the other skinned windows: Blizzard size and title kept, Phoenix panel icon in the top-left corner
W_, H_ = 1500, 820; c = Canvas(W_, H_); backdrop(c, W_, H_); k = 1.0
c.T(30, 26, 'Every window: its own Phoenix panel icon in the top-left corner (Blizzard frame size and title kept)', 17, 'SemiBold', C['t1'])
wins = [('panel-bags', 'Backpack'), ('panel-mail', 'Inbox'), ('panel-friends', 'Friends'), ('panel-guild', 'Guild & Communities'),
        ('panel-groupfinder', 'Group Finder'), ('panel-achievements', 'Achievements'), ('panel-spellbook', 'Spellbook'),
        ('panel-talents', 'Talents'), ('panel-quests', 'Quest Log'), ('panel-map', 'World Map'), ('panel-calendar', 'Calendar'),
        ('panel-professions', 'Professions'), ('panel-journal', 'Adventure Guide'), ('panel-pvp', 'Player vs. Player'),
        ('panel-bank', 'Bank'), ('panel-merchant', 'Merchant'), ('panel-auction', 'Auction House'), ('panel-loot', 'Loot')]
for i, (ic, t) in enumerate(wins):
    x = 60 + (i % 6) * 238; y = 100 + (i // 6) * 236
    frame(c, x, y, 200, 170, k, t, panel=ic)
    inset(c, x + 10, y + 34, 180, 126)
    for r in range(4): c.R(x + 20, y + 46 + r * 28, 160 - r * 22, 14, fill=C['raised'], r=3)
c.save('/workspace/pui_restore/docs/screenshots/v3/panels_v3.png', 'Phoenix UI v3 mockup (t149) · window headers with panel icons · schematic, contents are placeholders')
