from kit import *
# Blizzard ButtonFrameTemplate / PortraitFrameTemplate geometry, Phoenix-themed. k = render scale (game units -> px)
def frame(c, X, Y, w, h, k, title, portrait_seed=None, bottom_tabs=None, active_tab=0):
    c.shadow(X, Y, w * k, h * k, 8, 24, 160)
    c.R(X, Y, w * k, h * k, fill=C['base'], r=6, outline=C['border'])
    c.R(X + 1, Y + 1, w * k - 2, 22 * k, fill=C['raised'], r=6); c.R(X + 1, Y + 14 * k, w * k - 2, 9 * k, fill=C['raised'])
    c.L(X, Y + 23 * k, X + w * k, Y + 23 * k, C['borderS'])
    c.T(X + w * k / 2, Y + 11.5 * k, title, int(8.5 * k), 'SemiBold', C['t1'], 'mm')
    chrome(c, X + w * k - 18 * k, Y + 4 * k, 'win-close', C['t2'], int(14 * k))
    if portrait_seed is not None:   # the portrait stays the game's (the player, or the window's own art)
        px, py, pr = X - 6 * k, Y - 8 * k, 30 * k
        c.d.ellipse([px * S, py * S, (px + 2 * pr) * S, (py + 2 * pr) * S], fill=C['sunken'], outline=C['acc'], width=int(1.5 * S))
        c.icon(int(px + 8 * k), int(py + 8 * k), int(44 * k), portrait_seed, r=int(22 * k))
    if bottom_tabs:
        tx = X + 10 * k
        for i, t in enumerate(bottom_tabs):
            tw = max(c.tw(t, int(7.5 * k), 'Medium') + 22 * k, 52 * k); on = i == active_tab
            c.R(tx, Y + h * k - 2, tw, 22 * k, fill=C['raised'] if on else C['base'], r=4, outline=C['acc'] if on else C['borderS'])
            if on: c.R(tx + 6, Y + h * k - 2, tw - 12, 2, fill=C['acc'])
            c.T(tx + tw / 2, Y + h * k + 9 * k, t, int(7.5 * k), 'SemiBold' if on else 'Medium', C['t1'] if on else C['t2'], 'mm')
            tx += tw + 2 * k
def inset(c, x, y, w, h, fill=None):
    c.R(x, y, w, h, fill=fill or C['sunken'], r=4, outline=C['borderS'])
def backdrop(c, W_, H_):
    for i in range(H_ * S):
        t = i / (H_ * S); c.d.line([(0, i), (W_ * S, i)], fill=(int(34 * (1 - t) + 12 * t), int(18 * (1 - t) + 10 * t), int(26 * (1 - t) + 14 * t)))
