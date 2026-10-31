"""Phoenix settings GUI v4 concepts (t150). Real options from the harness dump (PUI_DUMP features.json)."""
import json, sys
from blz_frame import *
D = {m['key']: m for m in json.load(open(sys.argv[1] if len(sys.argv) > 1 else '_features.json'))}
OUT = sys.argv[2] if len(sys.argv) > 2 else '/workspace/pui_restore/docs/screenshots/v4'
WW, WH = 1440, 900
CATS = [('INTERFACE', 'interface'), ('COMBAT', 'combat'), ('SOCIAL', 'social'), ('UTILITY', 'utility'), ('SYSTEM', 'system')]
ICON = {'ActionBars': 'nav-bars', 'UnitFrames': 'nav-frames', 'GroupFrames': 'micro-groupfinder', 'NamePlates': 'nav-interface',
        'CastBars': 'tab-layout', 'Auras': 'nav-content', 'Bags': 'micro-shop', 'Tooltip': 'tab-text', 'Minimap': 'nav-windows',
        'Skins': 'nav-look', 'Movers': 'win-move', 'DataTexts': 'tab-behaviour', 'ItemLevel': 'micro-collections', 'CombatText': 'nav-combat',
        'CooldownText': 'win-reset', 'DamageMeter': 'nav-systems', 'Encounters': 'micro-journal', 'PvP': 'micro-guild', 'SpellHistory': 'micro-spells',
        'Tracker': 'micro-quests', 'Chat': 'micro-help', 'AFK': 'micro-housing', 'Automation': 'tab-behaviour', 'GroupFinder': 'micro-groupfinder',
        'MythicPlus': 'micro-achievements', 'Quality': 'win-favorite', 'Quests': 'micro-quests', 'Sim': 'nav-systems', 'Bugs': 'nav-support', 'General': 'win-settings'}
OFF = {'AFK', 'Sim', 'Quality'}

def groups(key, tab=None):
    out, cur_tab, cur = [], None, None
    for r in D[key]['rows']:
        if r['t'] == 'tab': cur_tab = r['l']; cur = None; continue
        if r['t'] in ('scope', 'preview', 'description'): continue
        if tab and cur_tab != tab: continue
        if r['t'] == 'header' or cur is None:
            cur = [r['l'] if r['t'] == 'header' else cur_tab, []]; out.append(cur)
            if r['t'] == 'header': continue
        cur[1].append(r)
    return [(h, rs) for h, rs in out if rs]
def tabs(key): return [r['l'] for r in D[key]['rows'] if r['t'] == 'tab']

_vi = [0]
def val(r):
    _vi[0] += 1; i = _vi[0]; t = r['t']; l = r['l'].lower()
    if t == 'toggle': return i % 3 != 0
    if t == 'range':
        if 'opacity' in l: return (0.25 + (i % 6) * .12, f'{25 + (i % 6) * 12}%')
        if 'scale' in l: return (0.5, '1.00')
        if 'offset' in l: return (0.5, str((i % 5 - 2) * 40))
        return (0.2 + (i % 7) * .1, str(4 + (i % 9) * 4))
    if t == 'select': return ['Up', 'Right', 'Bottom', 'Default', 'Medium', 'Class', 'Glow', 'Auto', 'None'][i % 9]
    if t == 'font': return 'Expressway · 12'
    if t == 'texture': return 'Phoenix Smooth'
    if t == 'style': return '1 px · Ember'
    if t == 'input': return '[combat] show; hide' if 'macro' in l else ('[name:short]' if 'text' in l else 'Ctrl-R')
    return ''

# ---------- compact controls (row h=28)
def ctl(c, x, y, w, r):
    t = r['t']; v = val(r); cy = y + 14
    if t == 'toggle':
        on = v; c.R(x + w - 30, cy - 8, 30, 16, fill=C['acc'] if on else C['hover'], r=8)
        c.d.ellipse([(x + w - (16 if on else 28)) * S, (cy - 6) * S, (x + w - (4 if on else 16)) * S, (cy + 6) * S], fill=(255, 255, 255) if on else C['t2'])
    elif t == 'range':
        f, txt = v; sw = min(120, w * .55); sx = x + w - sw - 44
        c.R(sx, cy - 2, sw, 4, fill=C['hover'], r=2); c.R(sx, cy - 2, sw * f, 4, fill=C['acc'], r=2)
        c.d.ellipse([(sx + sw * f - 6) * S, (cy - 6) * S, (sx + sw * f + 6) * S, (cy + 6) * S], fill=(255, 255, 255))
        c.R(x + w - 38, cy - 10, 38, 20, fill=C['sunken'], r=3, outline=C['borderS']); c.T(x + w - 19, cy, txt, 11, 'SemiBold', C['t1'], 'mm')
    elif t in ('select', 'font', 'texture', 'style'):
        bw = min(150, w * .52); bx = x + w - bw
        c.R(bx, cy - 11, bw, 22, fill=C['sunken'], r=3, outline=C['borderS'])
        if t == 'texture': c.R(bx + 6, cy - 4, 26, 8, fill=C['acc2'], r=2)
        if t == 'style': c.R(bx + 6, cy - 6, 14, 12, outline=C['acc'], r=2, width=1)
        c.T(bx + (38 if t == 'texture' else 26 if t == 'style' else 8), cy, v, 11, 'Medium', C['t1'], 'lm')
        chrome(c, bx + bw - 16, cy - 6, 'win-expand', None, 12)
    elif t == 'input':
        bw = min(170, w * .58); c.R(x + w - bw, cy - 11, bw, 22, fill=C['sunken'], r=3, outline=C['borderS']); c.T(x + w - bw + 8, cy, v, 11, 'Medium', C['t2'], 'lm')
    elif t == 'button':
        bw = c.tw(r['l'], 11, 'SemiBold') + 20; c.R(x + w - bw, cy - 11, bw, 22, fill=C['hover'], r=3, outline=C['border']); c.T(x + w - bw / 2, cy, r['l'], 11, 'SemiBold', C['t1'], 'mm')
    elif t in ('colors', 'color'):
        for k, col in enumerate([C['ok'], C['warn'], C['bad'], C['info']][: (4 if t == 'colors' else 1)]): c.R(x + w - 20 - k * 22, cy - 8, 16, 16, fill=col, r=3, outline=C['border'])
def row(c, x, y, w, r, zebra=False):
    if zebra: c.R(x - 6, y, w + 12, 28, fill=(25, 27, 31), r=3)
    lab = r['l'] if r['t'] != 'button' else ''
    c.T(x, y + 14, lab, 12.5, 'Medium', C['t1'], 'lm'); ctl(c, x, y, w, r)
GH, RH = 36, 28
def gheight(rs, collapsed=False): return GH + (0 if collapsed else len(rs) * RH + 10)
def gcard(c, x, y, w, h, rs, collapsed=False, cols=1, summary=None):
    c.R(x, y, w, gheight(rs, collapsed) if cols == 1 else 0, fill=C['raised'], r=6, outline=C['borderS'])
def card(c, x, y, w, title, rs, collapsed=False, cols=1, summary=None, accent=False):
    n = len(rs); per = (n + cols - 1) // cols; h = GH + (0 if collapsed else per * RH + 10)
    c.R(x, y, w, h, fill=C['raised'], r=6, outline=C['acc'] if accent else C['borderS'])
    c.R(x + 1, y + 1, 3, GH - 2, fill=C['acc'], r=1)
    c.T(x + 14, y + GH / 2, title.upper(), 11.5, 'Bold', C['t1'], 'lm')
    c.badge(x + 20 + c.tw(title.upper(), 11.5, 'Bold'), y + 10, str(n), C['t3'])
    chrome(c, x + w - 24, y + 10, 'win-expand', None, 16)
    if collapsed:
        sx = x + 60 + c.tw(title.upper(), 11.5, 'Bold')
        for s in (summary or []):
            bw = c.tw(s, 10.5, 'Medium') + 14
            if sx + bw > x + w - 34: break
            c.R(sx, y + 9, bw, 18, fill=C['sunken'], r=9); c.T(sx + bw / 2, y + 18, s, 10.5, 'Medium', C['t2'], 'mm'); sx += bw + 6
        return h
    c.L(x + 10, y + GH, x + w - 10, y + GH, C['borderS'])
    cw = (w - 28 - (cols - 1) * 24) / cols
    for i, r in enumerate(rs):
        col, k = divmod(i, per); row(c, x + 14 + col * (cw + 24), y + GH + 5 + k * RH, cw, r, zebra=k % 2 == 1)
    return h
def masonry(c, x, y, w, gs, ncol, gap=12, maxy=None):
    cw = (w - gap * (ncol - 1)) / ncol; ys = [y] * ncol
    for t, rs in gs:
        i = ys.index(min(ys)); h = card(c, x + i * (cw + gap), ys[i], cw, t, rs); ys[i] += h + gap
    return max(ys)

def window(c, X, Y):
    c.shadow(X, Y, WW - 2 * X, WH - 2 * Y, 10, 30, 170)
    c.R(X, Y, WW - 2 * X, WH - 2 * Y, fill=C['base'], r=10, outline=C['border'])
def rail(c, X, Y, H, active, subs=(), sub_on=None, w=236):
    c.R(X, Y, w, H, fill=(17, 19, 22), r=10); c.R(X + w - 10, Y, 10, H, fill=(17, 19, 22))
    c.L(X + w, Y, X + w, Y + H, C['borderS'])
    panel_icon(c, X + 12, Y + 12, 'panel-settings', 38); c.T(X + 58, Y + 24, 'PHOENIX', 16, 'Bold', C['t1'], 'lm'); c.T(X + 58, Y + 40, 'UI 3.0 · Default profile', 10.5, 'Medium', C['t3'], 'lm')
    c.R(X + 12, Y + 62, w - 24, 26, fill=C['sunken'], r=5, outline=C['borderS']); chrome(c, X + 20, Y + 67, 'win-search', None, 16)
    c.T(X + 42, Y + 75, 'Search 1,875 settings', 11.5, 'Medium', C['t3'], 'lm'); c.T(X + w - 20, Y + 75, 'Ctrl K', 10, 'Medium', C['t3'], 'rm')
    y = Y + 100
    yy = y; on = active == 'home'
    if on: c.R(X + 8, yy, w - 16, 26, fill=soft(C['acc'], .16, (17, 19, 22)), r=5); c.R(X + 8, yy + 4, 3, 18, fill=C['acc'], r=1)
    chrome(c, X + 18, yy + 5, 'nav-home', C['acc'] if on else None, 16); c.T(X + 42, yy + 13, 'Home', 12.5, 'SemiBold', C['t1'], 'lm'); y += 30
    for cat, k in CATS:
        mods = [m for m in D if D[m]['cat'] == k]
        opened = active in mods or (active == 'home' and k in ('interface', 'combat'))
        c.T(X + 18, y + 10, cat, 9.5, 'Bold', C['t3'], 'lm'); c.T(X + w - 18, y + 10, str(len(mods)) + ('' if opened else '  ›'), 9.5, 'Bold', C['t3'], 'rm'); y += 20
        if not opened:
            c.T(X + 18, y + 6, ' · '.join(D[m]['label'] for m in sorted(mods, key=lambda m: D[m]['label']))[:44] + '…', 10.5, 'Medium', C['t3'], 'lm'); y += 22; continue
        for m in sorted(mods, key=lambda m: D[m]['label']):
            on = m == active
            if on: c.R(X + 8, y, w - 16, 24, fill=soft(C['acc'], .16, (17, 19, 22)), r=5); c.R(X + 8, y + 4, 3, 16, fill=C['acc'], r=1)
            chrome(c, X + 18, y + 4, ICON.get(m, 'nav-home'), C['acc'] if on else None, 16)
            c.T(X + 42, y + 12, D[m]['label'], 12, 'SemiBold' if on else 'Medium', C['t1'] if on else C['t2'], 'lm')
            c.d.ellipse([(X + w - 22) * S, (y + 9) * S, (X + w - 16) * S, (y + 15) * S], fill=C['t3'] if m in OFF else C['ok'])
            y += 24
            if on:
                for s_ in subs:
                    so = s_ == sub_on
                    c.L(X + 26, y, X + 26, y + 22, C['border'])
                    if so: c.R(X + 34, y + 1, w - 50, 20, fill=C['hover'], r=4)
                    c.T(X + 44, y + 11, s_, 11.5, 'SemiBold' if so else 'Medium', C['acc2'] if so else C['t2'], 'lm'); y += 22
                y += 4
        y += 6
        if y > Y + H - 40: break
    return w
def header(c, x, y, w, key, sub=None, scopes=(), scope_on=0, preview=True, desc=None):
    m = D[key]
    panel_icon(c, x, y, 'panel-settings' if key == 'home' else 'panel-character', 1) if False else None
    c.R(x, y, 52, 52, fill=soft(C['acc'], .12), r=12, outline=soft(C['acc'], .35)); chrome(c, x + 8, y + 8, ICON[key], C['acc'], 36)
    c.T(x + 66, y + 10, ('Interface  ›  ' + m['label'] + ('  ›  ' + sub if sub else '')), 10.5, 'Medium', C['t3'], 'lm')
    c.T(x + 66, y + 32, m['label'], 24, 'Bold', C['t1'], 'lm')
    c.T(x + 70 + c.tw(m['label'], 24, 'Bold'), y + 34, desc or m['desc'][:90], 12, fill=C['t2'], anchor='lm')
    bx = x + w
    for t_, kind in (('Reset page', 'ghost'), ('Move on screen', 'secondary')):
        bw = c.tw(t_, 12, 'SemiBold') + 26 + 20; bx -= bw + 8
        c.R(bx, y + 4, bw, 28, fill=None if kind == 'ghost' else C['hover'], r=5, outline=C['border'])
        chrome(c, bx + 9, y + 10, 'win-reset' if kind == 'ghost' else 'win-move', None, 16); c.T(bx + 30, y + 18, t_, 12, 'SemiBold', C['t1'], 'lm')
    c.R(bx - 110, y + 4, 102, 28, fill=soft(C['ok'], .14), r=14, outline=soft(C['ok'], .4)); c.T(bx - 70, y + 18, 'Enabled', 12, 'SemiBold', C['ok'], 'mm')
    c.R(bx - 36, y + 10, 24, 16, fill=C['ok'], r=8); c.d.ellipse([(bx - 26) * S, (y + 12) * S, (bx - 14) * S, (y + 24) * S], fill=(255, 255, 255))
    yy = y + 62
    if scopes:
        c.T(x, yy + 13, 'EDITING', 9.5, 'Bold', C['t3'], 'lm'); sx = x + 58
        for i, s_ in enumerate(scopes):
            bw = c.tw(s_, 11.5, 'SemiBold') + 22; on = i == scope_on
            c.R(sx, yy + 1, bw, 24, fill=C['acc'] if on else C['raised'], r=12, outline=None if on else C['borderS'])
            c.T(sx + bw / 2, yy + 13, s_, 11.5, 'SemiBold', (24, 12, 4) if on else C['t2'], 'mm'); sx += bw + 6
        c.T(sx + 6, yy + 13, 'Shift-click to edit several at once', 11, 'Medium', C['t3'], 'lm')
        if preview:
            pw = 140; c.R(x + w - pw, yy + 1, pw, 24, fill=C['raised'], r=12, outline=C['borderS']); chrome(c, x + w - pw + 10, yy + 5, 'win-lock', None, 16)
            c.T(x + w - pw + 32, yy + 13, 'Live preview', 11.5, 'SemiBold', C['t1'], 'lm'); c.R(x + w - 38, yy + 5, 28, 16, fill=C['acc'], r=8)
            c.d.ellipse([(x + w - 24) * S, (yy + 7) * S, (x + w - 12) * S, (yy + 19) * S], fill=(255, 255, 255))
        yy += 34
    return yy
def bar_preview(c, x, y, w, h, n=12, sz=34):
    c.R(x, y, w, h, fill=C['sunken'], r=6, outline=C['borderS'])
    for i in range(int(w / 9)): c.L(x + i * 9, y + 1, x + i * 9, y + h - 1, (19, 21, 25))
    tw = n * (sz + 4) - 4; bx = x + (w - tw) / 2; by = y + (h - sz) / 2
    c.R(bx - 6, by - 6, tw + 12, sz + 12, fill=(10, 11, 13), r=4, outline=C['acc'])
    for i in range(n):
        c.icon(int(bx + i * (sz + 4)), int(by), sz, 300 + i, r=3); c.R(bx + i * (sz + 4), by, sz, sz, outline=(0, 0, 0), r=3)
        c.T(bx + i * (sz + 4) + sz - 3, by + 7, str(i + 1 if i < 9 else '-=0'[i - 9]), 10, 'Bold', (255, 255, 255), 'rm')
    c.T(x + 10, y + 12, 'Bar 1  ·  12 buttons  ·  1 row  ·  36 px', 10.5, 'SemiBold', C['t3'], 'lm')
    c.T(x + w - 10, y + 12, 'drag to move  ·  scroll to resize', 10.5, 'Medium', C['t3'], 'rm')
def footer(c, X, Y, x0, txt='Changes save and apply instantly'):
    fy = WH - Y - 30; c.L(x0, fy, WW - X, fy, C['borderS'])
    c.d.ellipse([(x0 + 16) * S, (fy + 12) * S, (x0 + 22) * S, (fy + 18) * S], fill=C['ok']); c.T(x0 + 30, fy + 15, txt, 11, 'Medium', C['t2'], 'lm')
    c.T(WW - X - 16, fy + 15, 'Profile: Default  ·  Undo  Ctrl Z', 11, 'Medium', C['t3'], 'rm')
BARS = ['Bar 1', 'Bar 2', 'Bar 3', 'Bar 4', 'Bar 5', 'Bar 6', 'Bar 7', 'Bar 8', 'Pet', 'Stance']
X = Y = 20

# ===== Concept A: Flow - one rail with inline sub-pages, sticky header, 3-column packed groups
def concept_a(key, sub, scopes, fname, preview=True, ncol=3):
    c = Canvas(WW, WH); backdrop(c, WW, WH); window(c, X, Y)
    rw = rail(c, X, Y, WH - 2 * Y, key, tabs(key), sub)
    x0 = X + rw + 20; w = WW - X - 20 - x0
    yy = header(c, x0, Y + 18, w, key, sub, scopes, 0, preview)
    if preview and key == 'ActionBars': bar_preview(c, x0, yy, w, 92); yy += 104
    if preview and key == 'UnitFrames': uf_preview(c, x0, yy, w, 92); yy += 104
    c.d.rectangle([x0 * S, (yy - 4) * S, (x0 + w) * S, (yy - 3) * S], fill=C['borderS'])
    masonry(c, x0, yy + 6, w, groups(key, sub), ncol)
    footer(c, X, Y, X + rw)
    c.save(f'{OUT}/{fname}', f'Phoenix settings v4 · Concept A "Flow" · {D[key]["label"]} › {sub} · real options from the build · schematic, not in-game')
def uf_preview(c, x, y, w, h):
    c.R(x, y, w, h, fill=C['sunken'], r=6, outline=C['borderS'])
    for i, (n, hp, cl) in enumerate([('Bmr', .86, (148, 130, 201)), ('Training Dummy', .42, (200, 60, 50)), ('Focus', .7, (90, 160, 255))]):
        fx = x + 60 + i * (w - 120) / 3; fy = y + 24; fw = 230
        c.R(fx, fy, fw, 44, fill=(10, 11, 13), r=3, outline=C['acc'] if i == 0 else C['border'])
        c.R(fx + 2, fy + 2, (fw - 4) * hp, 30, fill=cl, r=2); c.R(fx + 2, fy + 34, (fw - 4) * .8, 8, fill=(60, 120, 230), r=1)
        c.T(fx + 8, fy + 17, n, 12.5, 'SemiBold', (255, 255, 255), 'lm'); c.T(fx + fw - 8, fy + 17, f'{int(hp*100)}%', 12.5, 'SemiBold', (255, 255, 255), 'rm')
    c.T(x + 10, y + 12, 'Player  ·  230 × 44  ·  class colour', 10.5, 'SemiBold', C['t3'], 'lm')

# ===== Concept B: Inspector - rail + one scroll column of 2-up groups + sticky right preview/scope panel
def concept_b():
    key, sub = 'ActionBars', 'Bars'
    c = Canvas(WW, WH); backdrop(c, WW, WH); window(c, X, Y)
    rw = rail(c, X, Y, WH - 2 * Y, key, tabs(key), sub)
    pw = 330; x0 = X + rw + 20; w = WW - X - pw - 40 - x0
    yy = header(c, x0, Y + 18, w + pw + 20, key, sub, (), 0, False)
    c.d.rectangle([x0 * S, (yy - 2) * S, (x0 + w) * S, (yy - 1) * S], fill=C['borderS'])
    y = yy + 8
    for t, rs in groups(key, sub):
        if y + GH + ((len(rs) + 1) // 2) * RH + 10 > WH - Y - 40:
            c.T(x0 + w / 2, y + 12, f'↓  {t} and more below  ↓', 11, 'Medium', C['t3'], 'mm'); break
        y += card(c, x0, y, w, t, rs, cols=2) + 10
    px = WW - X - 20 - pw; py = yy - 70 + 62
    c.R(px, py, pw, WH - Y - 50 - py, fill=(19, 21, 25), r=8, outline=C['borderS'])
    c.T(px + 14, py + 18, 'BAR PICKER', 10, 'Bold', C['t3'], 'lm')
    sx, sy, sw, sh = px + 14, py + 32, pw - 28, 170
    c.R(sx, sy, sw, sh, fill=C['sunken'], r=5, outline=C['borderS'])
    spots = [(.5, .9, .62), (.5, .8, .62), (.5, .7, .4), (.95, .5, .06), (.88, .5, .06), (.2, .7, .25), (.8, .7, .25), (.5, .6, .3)]
    for i, (fx, fy, fw) in enumerate(spots):
        bw = max(8, sw * fw); bh = 9 if fw > .1 else 70
        if fw <= .1: bw = 9
        c.R(sx + sw * fx - bw / 2, sy + sh * fy - bh / 2, bw, bh, fill=C['acc'] if i == 0 else C['hover'], r=2, outline=C['acc2'] if i == 0 else C['border'])
    c.T(sx + sw / 2, sy + sh * .9 - 12, 'Bar 1', 9.5, 'Bold', C['acc2'], 'mm')
    gy = sy + sh + 12
    for i, b in enumerate(BARS):
        bx = px + 14 + (i % 5) * ((pw - 28) / 5); by = gy + (i // 5) * 30; on = i == 0
        c.R(bx, by, (pw - 28) / 5 - 6, 24, fill=C['acc'] if on else C['raised'], r=4, outline=None if on else C['borderS'])
        c.T(bx + ((pw - 28) / 5 - 6) / 2, by + 12, b, 11, 'SemiBold', (24, 12, 4) if on else C['t2'], 'mm')
    py2 = gy + 70; c.T(px + 14, py2, 'LIVE PREVIEW', 10, 'Bold', C['t3'], 'lm')
    c.R(px + 14, py2 + 12, pw - 28, 120, fill=C['sunken'], r=5, outline=C['borderS'])
    for i in range(12):
        c.icon(int(px + 26 + (i % 6) * 48), int(py2 + 26 + (i // 6) * 48), 42, 300 + i, r=3)
    py3 = py2 + 148; c.T(px + 14, py3, 'AT A GLANCE', 10, 'Bold', C['t3'], 'lm')
    for i, (k_, v_) in enumerate([('Buttons', '12 of 12'), ('Size', '36 × 36'), ('Visibility', 'Always'), ('Paging', 'Forms, skyriding'), ('Changed from default', '4 settings')]):
        c.T(px + 14, py3 + 22 + i * 24, k_, 12, 'Medium', C['t2'], 'lm'); c.T(px + pw - 14, py3 + 22 + i * 24, v_, 12, 'SemiBold', C['acc2'] if i == 4 else C['t1'], 'rm')
    footer(c, X, Y, X + rw)
    c.save(f'{OUT}/settings_v4_B_inspector.png', 'Phoenix settings v4 · Concept B "Inspector" · Action Bars › Bars · real options · schematic, not in-game')

# ===== Concept C: Deck - icon rail, all sub-pages on one page as accordion bands; collapsed bands show summary chips
def concept_c():
    key = 'ActionBars'
    c = Canvas(WW, WH); backdrop(c, WW, WH); window(c, X, Y)
    rw = 64; c.R(X, Y, rw, WH - 2 * Y, fill=(17, 19, 22), r=10); c.L(X + rw, Y, X + rw, WH - Y, C['borderS'])
    panel_icon(c, X + 12, Y + 12, 'panel-settings', 40); y = Y + 72
    for m in ['home'] + [m for _, k in CATS for m in D if D[m]['cat'] == k][:22]:
        on = m == key
        if on: c.R(X + 10, y - 3, 44, 30, fill=soft(C['acc'], .16, (17, 19, 22)), r=6); c.R(X + 4, y + 3, 3, 18, fill=C['acc'], r=1)
        chrome(c, X + 20, y + 1, 'nav-home' if m == 'home' else ICON[m], C['acc'] if on else None, 22); y += 34
    x0 = X + rw + 24; w = WW - X - 24 - x0
    yy = header(c, x0, Y + 18, w, key, None, BARS, 0, True)
    sx = x0
    for i, t in enumerate(tabs(key)):
        bw = c.tw(t, 12, 'SemiBold') + 30
        c.T(sx + bw / 2, yy + 8, t, 12, 'SemiBold', C['t1'] if i == 0 else C['t2'], 'mm')
        if i == 0: c.R(sx + 8, yy + 20, bw - 16, 2, fill=C['acc'])
        sx += bw
    c.T(x0 + w, yy + 8, 'jump to · all sections on one page', 11, 'Medium', C['t3'], 'rm')
    y = yy + 32
    summ = {'Position': ['Bottom', 'x 0', 'y 48', 'Medium strata', 'Scale 1.00'], 'Backdrop': ['Backdrop off', '60% opacity', '1 px Ember border'],
            'Paging (bar 1)': ['Forms', 'Skyriding', 'Vehicle', 'Shift → 2', 'Arrows off'], 'Button shape': ['Phoenix art', 'Square', 'Zoom 8%', 'Grey on cooldown'],
            'Feedback': ['Range tint', 'Power tint', 'Proc glow: Pulse', 'Ready flash'], 'Hotkeys': ['Short names', 'Expressway 11'],
            'Macro names': ['Hidden'], 'Counts and charges': ['Expressway 12'], 'Cooldown numbers': ['On', 'Size 14']}
    allg = [(t, g) for t in tabs(key) for g in groups(key, t)]
    for i, (t, (gt, rs)) in enumerate(allg):
        open_ = gt in ('Layout', 'Visibility')
        h = card(c, x0, y, w, gt, rs, collapsed=not open_, cols=4 if open_ else 1, summary=summ.get(gt, ['default']), accent=open_ and gt == 'Layout')
        y += h + 8
        if y > WH - 90: break
    footer(c, X, Y, X + rw)
    c.save(f'{OUT}/settings_v4_C_deck.png', 'Phoenix settings v4 · Concept C "Deck" · Action Bars, every section on one page · real options · schematic, not in-game')

# ===== Home in concept A
def home():
    c = Canvas(WW, WH); backdrop(c, WW, WH); window(c, X, Y)
    rw = rail(c, X, Y, WH - 2 * Y, 'home')
    x0 = X + rw + 20; w = WW - X - 20 - x0; y = Y + 18
    c.R(x0, y, w, 110, fill=(30, 20, 18), r=10, outline=soft(C['acc'], .4))
    for i in range(110): c.L(x0 + w * .55, y + i, x0 + w - 2, y + i, (int(30 + 40 * i / 110), int(20 + 10 * i / 110), 18))
    panel_icon(c, x0 + 18, y + 15, 'panel-gamemenu', 80)
    c.T(x0 + 112, y + 34, 'Good evening, Bmr', 24, 'Bold', C['t1'], 'lm'); c.T(x0 + 112, y + 62, 'Phoenix UI 3.0  ·  27 of 30 modules on  ·  profile Default (Destruction)  ·  everything healthy', 12.5, 'Medium', C['t2'], 'lm')
    bx = x0 + 112
    for t_, ic in (('Move frames', 'win-move'), ('Install wizard', 'nav-phoenix'), ('Profiles', 'nav-profiles'), ('Report a bug', 'nav-support')):
        bw = c.tw(t_, 12, 'SemiBold') + 44; c.R(bx, y + 78, bw, 24, fill=C['hover'], r=5, outline=C['border']); chrome(c, bx + 8, y + 82, ic, None, 16); c.T(bx + 30, y + 90, t_, 12, 'SemiBold', C['t1'], 'lm'); bx += bw + 8
    y += 124; cw = (w - 24) / 3
    for j, (cat, k) in enumerate(CATS):
        col = j % 3
    ys = [y] * 3
    for cat, k in CATS:
        mods = sorted([m for m in D if D[m]['cat'] == k], key=lambda m: D[m]['label'])
        i = ys.index(min(ys)); cx = x0 + i * (cw + 12); h = GH + len(mods) * 34 + 8
        c.R(cx, ys[i], cw, h, fill=C['raised'], r=6, outline=C['borderS']); c.R(cx + 1, ys[i] + 1, 3, GH - 2, fill=C['acc'], r=1)
        c.T(cx + 14, ys[i] + GH / 2, cat, 11.5, 'Bold', C['t1'], 'lm'); c.badge(cx + 20 + c.tw(cat, 11.5, 'Bold'), ys[i] + 10, f'{len(mods)} modules', C['t3'])
        for n, m in enumerate(mods):
            ry = ys[i] + GH + 4 + n * 34
            chrome(c, cx + 14, ry + 7, ICON[m], None, 20); c.T(cx + 44, ry + 11, D[m]['label'], 12.5, 'SemiBold', C['t1'], 'lm')
            c.T(cx + 44, ry + 25, f"{len(D[m]['rows'])} settings", 10, 'Medium', C['t3'], 'lm')
            on = m not in OFF; c.R(cx + cw - 44, ry + 9, 30, 16, fill=C['acc'] if on else C['hover'], r=8)
            c.d.ellipse([(cx + cw - (30 if on else 42)) * S, (ry + 11) * S, (cx + cw - (18 if on else 30)) * S, (ry + 23) * S], fill=(255, 255, 255) if on else C['t2'])
            c.T(cx + cw - 52, ry + 17, '›', 14, 'Bold', C['t3'], 'rm')
        ys[i] += h + 12
    i = ys.index(min(ys)); cx = x0 + i * (cw + 12); hy = ys[i]
    c.R(cx, hy, cw, 150, fill=C['raised'], r=6, outline=C['borderS']); c.T(cx + 14, hy + 18, 'HEALTH CHECKS', 11.5, 'Bold', C['t1'], 'lm')
    for n, (t_, col) in enumerate([('No Lua errors this session', C['ok']), ('Bug uploader running', C['ok']), ('2 bars overlap the chat frame', C['warn']), ('UI scale is pixel-perfect (0.53)', C['ok'])]):
        c.d.ellipse([(cx + 16) * S, (hy + 42 + n * 26) * S, (cx + 24) * S, (hy + 50 + n * 26) * S], fill=col); c.T(cx + 32, hy + 46 + n * 26, t_, 12, 'Medium', C['t1'], 'lm')
    hy += 162; c.R(cx, hy, cw, 140, fill=C['raised'], r=6, outline=C['borderS']); c.T(cx + 14, hy + 18, 'RECENTLY CHANGED', 11.5, 'Bold', C['t1'], 'lm')
    for n, (a_, b_) in enumerate([('Action Bars › Bar 1 › Buttons', '12 → 10'), ('Unit Frames › Player › Width', '220 → 230'), ('Combat Text › Crits › Sticky', 'on'), ('General › Font', 'Expressway (found)')]):
        c.T(cx + 14, hy + 44 + n * 24, a_, 11.5, 'Medium', C['t2'], 'lm'); c.T(cx + cw - 14, hy + 44 + n * 24, b_, 11.5, 'SemiBold', C['acc2'], 'rm')
    footer(c, X, Y, X + rw, 'Click a module to open it; the switch turns it on or off live')
    c.save(f'{OUT}/settings_v4_A_home.png', 'Phoenix settings v4 · Concept A "Flow" · Home dashboard · real module list · schematic, not in-game')

concept_a('ActionBars', 'Bars', BARS, 'settings_v4_A_flow_actionbars.png')
concept_b(); concept_c()
concept_a('UnitFrames', 'Frames', ['Player', 'Target', 'Target of target', 'Focus', 'Pet', 'Boss', 'Arena'], 'settings_v4_A_unitframes.png')
home()
