#!/usr/bin/env python3
"""Cooldown Manager (2.0 S12) mockups: HTML mirroring Phoenix_UI_Options/Options/Tracker.lua and its Preview, drawn with
the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from Locales/enUS.lua, the
setting count from the smoke harness ("cooldown manager depth (S12)"). Icons are CSS stand-ins for the game's art;
these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s12.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, chips, COG, ALL, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["Tracker"] = (91, 59)
for g in s6.GROUPS:  # the page was renamed from Auras & Cooldowns
    g[3][:] = [("Tracker", "Cooldown Manager", "tracker", True) if isinstance(e, tuple) and e[0] == "Tracker" else e for e in g[3]]
OUT = SRC.parent
CSS = s9.CSS + ('<style>.cd{position:absolute;box-shadow:0 0 0 1px #000;overflow:hidden}'
                '.cd>i{position:absolute;inset:0}.cd>u{position:absolute;left:0;right:0;top:0;background:rgba(0,0,0,.62)}'
                '.cd>s{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:CondBold;color:#fff;'
                'text-decoration:none;text-shadow:1px 1px 0 #000}.cd>b{position:absolute;right:2px;bottom:1px;font-family:CondBold;font-size:11px;'
                'color:#fff;text-shadow:1px 1px 0 #000}.cd>em{position:absolute;right:2px;top:1px;font-family:CondSemi;font-size:9px;font-style:normal;'
                'color:#e8ecf2;text-shadow:1px 1px 0 #000}.cdg{position:absolute;pointer-events:none}'
                '.bb{position:absolute;background:#101216;box-shadow:0 0 0 1px #000}.bb>i{position:absolute;left:0;top:0;bottom:0}'
                '.bb>span{position:absolute;top:0;bottom:0;display:flex;align-items:center;font-family:CondSemi;font-size:11px;color:#fff;text-shadow:1px 1px 0 #000}</style>')
GRAD = ["#ff8a3d,#8a1d00", "#7fd8ff,#0d4a8a", "#ffe08a,#a86a00", "#c7a0ff,#3a1a7a", "#9df0a0,#1d6a2a", "#ff9bc4,#7a1a44",
        "#ffd0a0,#7a3a10", "#a0e8ff,#1a5a7a", "#ffb0b0,#8a1a1a", "#e0e0e0,#4a4a4a"]
# icon, timer ("" = ready), count, proc, keybind
ESS = [(0, "", "", True, "1"), (1, "8", "", False, "2"), (2, "", "", False, "3"), (3, "24", "2", False, "4"),
       (4, "", "", False, "Q"), (5, "1:12", "", False, "E"), (6, "", "", False, "R"), (7, "3", "", False, "F"),
       (8, "", "", False, "S1"), (9, "41", "", False, "S2")]


def icon(x, y, s, d, desat=True, glow=None, ready=False, keys=True, tsize=None):
    g, t, c, proc, kb = d
    c1, c2 = GRAD[g % len(GRAD)].split(",")
    grey = "filter:grayscale(1) brightness(.7);" if (t and desat) else ""
    sw = f'<u style="height:{int(s * (0.3 + (g % 3) * 0.2))}px"></u>' if t else ""
    out = (f'<div class="cd" style="left:{x}px;top:{y}px;width:{s}px;height:{s}px">'
           f'<i style="background:radial-gradient(circle at 35% 30%,{c1},{c2});{grey}"></i>{sw}'
           f'<s style="font-size:{tsize or max(11, s // 3)}px">{t}</s>{"<b>" + c + "</b>" if c else ""}'
           f'{"<em>" + kb + "</em>" if keys and kb else ""}</div>')
    if proc and glow:
        out += (f'<div class="cdg" style="left:{x - 3}px;top:{y - 3}px;width:{s + 6}px;height:{s + 6}px;'
                f'box-shadow:0 0 0 2px {glow},0 0 10px 2px {glow}"></div>')
    if ready and not t:
        out += (f'<div class="cdg" style="left:{x - 2}px;top:{y - 2}px;width:{s + 4}px;height:{s + 4}px;'
                'box-shadow:0 0 0 1px #3ddc97,0 0 8px 1px #3ddc97"></div>')
    return out


def grid(x0, y0, items, size=40, per=8, gap=3, delta=0, center=True, **kw):
    out = []
    rows = [items[i:i + per] for i in range(0, len(items), per)]
    widest = per * size + (per - 1) * gap
    y = y0
    for r, row in enumerate(rows):
        s = size + (delta if r > 0 else 0)
        w = len(row) * s + (len(row) - 1) * gap
        x = x0 + ((widest - w) // 2 if center else 0)
        for i, d in enumerate(row):
            out.append(icon(x + i * (s + gap), y, s, d, **kw))
        y += s + gap
    return "".join(out)


def bars(x0, y0, w=260, h=22):
    out = []
    for i, (name, v, t, g) in enumerate([("Combustion", 82, "14.2", 0), ("Heating Up", 46, "6.8", 5), ("Arcane Intellect", 20, "2.1", 2)]):
        y = y0 + i * (h + 6)
        out.append(icon(x0, y, h, (g, "", "", False, ""), keys=False))
        out.append(f'<div class="bb" style="left:{x0 + h + 3}px;top:{y}px;width:{w}px;height:{h}px"><i style="width:{v}%;'
                   f'background:linear-gradient(180deg,#ff7a2e,#c94a10)"></i><span style="left:6px">{name}</span>'
                   f'<span style="right:6px">{t}</span></div>')
    return "".join(out)


def head():
    return page_head("tracker", "Cooldown Manager", "Blizzard's Cooldown Manager in Phoenix style and layout, three custom bars for spells, items and trinkets, glows, keybinds, visibility rules and pre-pull reminders.", "Tracker")


TABS = ["Layout", "Appearance", "Text", "Behaviour", "Reminders"]
SCOPE = ["Essential", "Utility", "Buff icons", "Buff bars", "Custom bar 1", "Custom bar 2", "Custom bar 3"]


def scope(on="Essential"):
    return (f'<div class="scope"><div class="t">{ico("tracker", 13)}Viewer<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips([(s, None) for s in SCOPE], on=(on,))}</div></div>')


def stage(kind="essential"):
    st = CSS
    if kind == "essential":
        st += grid(26, 40, ESS, size=40, per=6, gap=3, delta=-8, glow="#ffb347", ready=True)
    elif kind == "bars":
        st += bars(40, 50)
    elif kind == "custom":
        items = [(9, "", "", True, "T1"), (6, "1:40", "", False, ""), (2, "", "", False, "5"), (5, "15", "2", False, "6")]
        st += grid(70, 70, items, size=44, per=4, gap=4, glow="#ffd24a", ready=True)
    return preview("Live preview", st, 170, tag="COOLDOWNS")


def p_layout():
    mgr = card("tracker", "Cooldown Manager", [line("Cooldown Manager", tog(), "Turns on the game's Cooldown Manager (Options → Gameplay → Advanced Options).", side=f'<span class="rs">{ico("chevron-right", 12)}</span>'),
                                              pair(cell("Choose spells", f'<div class="btn">{ico("tracker")}Open</div>'), cell("Test", f'<div class="btn">{ico("test")}Toggle test</div>')),
                                              line("Layout mode", f'<div class="btn">{ico("movers")}Layout mode</div>', "Drag the viewers placed by Phoenix, the custom bars and the reminders. Viewers on Edit Mode move in Edit Mode.")])
    lay = card("grid", "Layout", [line("Phoenix grid", tog(), "Lay the icons out with the settings below instead of Edit Mode's. The viewer itself stays an Edit Mode system."),
                                  pair(cell("Icon size", sld(40, "40"), ALL()), cell("Icons per row", sld(30, "6"), ALL())),
                                  pair(cell("Rows", sld(20, "2")), cell("Later rows size", sld(40, "-8"))),
                                  pair(cell("Spacing", sld(15, "3")), cell("Grow", sel("Right", 140))),
                                  pair(cell("Wrap", sel("Down", 140)), tcell("Centre short rows", True)),
                                  pair(tcell("Keep places", False), cell("Extra icons", sel("Move to Utility", 170)))])
    pos = card("movers", "Position", [pair(cell("Placed by", sel("Edit Mode", 150)), cell("Scale", sld(50, "100%")))])
    content = head() + scope("Essential") + tabs(TABS, 0) + '<div class="body">' + mgr + lay + pos + '</div>'
    return s6.shell("bars", "bars", "Tracker", content, stage("essential"), status="Essential · 6 per row × 2 rows · overflow to Utility")


def p_icons():
    ic = card("tracker", "Icons", [line("Phoenix style", tog(), "Dress this viewer's icons and texts and lay them out on Phoenix's grid. Which spells show stays Blizzard's choice (Choose spells)."),
                                   line("Square icons", tog(), "Crisp square icons with a Phoenix border instead of Blizzard's rounded ring.", side=COG()),
                                   pair(cell("Border", sel("Solid", 140)), tcell("Hide debuff border", False))])
    stt = card("cooldowntext", "Cooldown state", [pair(tcell("Grey out on cooldown", True), tcell("Hide the global cooldown", True)),
                                                  pair(cell("Swipe darkness", sld(70, "70%")), tcell("Out-of-range tint", True)),
                                                  line("Keybinds", tog(), "Show the key of the action button that holds the spell.")])
    gl = card("bell", "Glows", [line("Proc glow", sel("Pixel", 150), "How an icon glows when the game lights up the spell (a proc or an empowered cast).", side=COG()),
                                line("Ready glow", sel("Pixel", 150), "A glow when a cooldown comes back. Viewers glow briefly; custom bars glow while the spell is ready.", side=COG())])
    content = head() + scope("Essential") + tabs(TABS, 1) + '<div class="body">' + ic + stt + gl + '</div>'
    return s6.shell("bars", "bars", "Tracker", content, stage("essential"), status="Pixel proc glow · ready glow 1.5 s · keybinds")


def p_custom():
    cu = card("items", "Custom bar", [line("Show this bar", tog(), "A Phoenix bar for what the Cooldown Manager cannot show: other spells, items and trinkets."),
                                      line("Spells and items", '<div class="sel" style="width:300px">1953, item:5512, trinket1</div>', "Spell IDs or names, item:ID, trinket1 / trinket2, separated by commas. Spells you do not know and items you do not carry are skipped."),
                                      pair(tcell("Equipped trinkets", True), cell("Show icons", sel("Always", 150))),
                                      pair(tcell("Charges", True), tcell("Tooltips on mouseover", True))])
    lay = card("grid", "Layout", [pair(cell("Icon size", sld(44, "44")), cell("Icons per row", sld(20, "4"))),
                                  pair(cell("Spacing", sld(20, "4")), cell("Grow", sel("Right", 140)))])
    tx = card("fonts", "Texts", [line("Countdown numbers", sel("Cooldown Text", 170), "Cooldown Text styles them like every other cooldown (one setting for all); or this viewer claims them with its own timer font.")])
    content = head() + scope("Custom bar 1") + tabs(TABS, 0) + '<div class="body">' + cu + lay + tx + '</div>'
    return s6.shell("bars", "bars", "Tracker", content, stage("custom"), status="Custom bar 1 · 4 icons · secret-safe in combat")


def p_visibility():
    vi = card("opacity", "Visibility", [line("Show", sel("In combat or with a target", 220), "When this viewer or bar is visible. Out-of-combat fading applies on top."),
                                        pair(tcell("Hide while mounted", True), tcell("Hide in vehicles", True))])
    sp = card("spec", "Specializations", [pair(tcell("Show in specialization 1", True), tcell("Show in specialization 2", False)),
                                          pair(tcell("Show in specialization 3", True), cell("Per-spec profiles", f'<div class="btn">{ico("profiles")}Profiles</div>'))])
    fd = card("opacity", "Out of combat", [line("Fade out of combat", tog(), "Viewers and custom bars dim to the chosen opacity when you are not fighting and come back the moment combat starts.", side=COG())])
    content = head() + scope("Buff bars") + tabs(TABS, 3) + '<div class="body">' + vi + sp + fd + '</div>'
    return s6.shell("bars", "bars", "Tracker", content, stage("bars"), status="Buff bars · in combat or with a target")


def p_reminders():
    rm = card("bell", "Reminders", [line("Show reminders", tog(), "Icons for what is missing before a pull, out of combat only."),
                                    line("Only in dungeons and raids", tog(), "Stay quiet in the open world."),
                                    pair(tcell("Flask", True), tcell("Food buff", True)),
                                    pair(tcell("Augment rune", False), tcell("Your raid buff", True)),
                                    pair(tcell("Weapon oil or stone", True), tcell("Pet", True)),
                                    pair(tcell("Healthstone", True), cell("Mana on ready check", tog(), COG())),
                                    pair(cell("Icon size", sld(36, "36")), cell("Sound", sel("Phoenix: Alert", 160)))])
    st = CSS
    for i, (lab, g) in enumerate([("Flask", 3), ("Food buff", 6), ("Weapon oil or stone", 4), ("Your raid buff", 1)]):
        st += icon(48 + i * 72, 54, 40, (g, "", "", False, ""), keys=False)
        st += f'<div class="t" style="position:absolute;left:{38 + i * 72}px;top:100px;width:60px;text-align:center;font-family:CondSemi;font-size:10px;color:#fff">{lab}</div>'
    content = head() + scope("Essential") + tabs(TABS, 4) + '<div class="body">' + rm + '</div>'
    return s6.shell("bars", "bars", "Tracker", content, preview("Live preview", st, 170, tag="REMINDERS"), status="4 reminders · out of combat only")


def world():
    body = CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
    body += grid(520, 520, ESS[:7], size=44, per=7, gap=3, glow="#ffb347", ready=True, tsize=15)
    body += grid(552, 592, [(8, "", "", False, "S1"), (9, "41", "", False, "S2"), (2, "", "", False, "Z"), (5, "2:30", "", False, "X"), (6, "", "", False, "C"), (4, "", "", False, "V")],
                 size=32, per=6, gap=3, center=False)
    body += grid(560, 440, [(0, "12", "3", False, ""), (5, "6", "", False, ""), (2, "18", "", False, ""), (3, "3", "5", False, ""), (1, "9", "", False, "")],
                 size=34, per=5, gap=3, center=False, keys=False, desat=False)
    body += bars(560, 300)
    body += grid(980, 600, [(9, "", "", True, "T1"), (6, "1:40", "", False, ""), (2, "", "", False, "5"), (5, "15", "2", False, "6")], size=38, per=4, gap=4, glow="#ffd24a", ready=True)
    for i, (lab, g) in enumerate([("Flask", 3), ("Food buff", 6), ("Weapon oil or stone", 4), ("Your raid buff", 1)]):
        body += icon(560 + i * 70, 160, 36, (g, "", "", False, ""), keys=False)
        body += f'<div style="position:absolute;left:{548 + i * 70}px;top:200px;width:60px;text-align:center;font-family:CondSemi;font-size:10px;color:#fff">{lab}</div>'
    for x, y, lab in [(520, 500, "ESSENTIAL"), (552, 588, "UTILITY"), (560, 420, "BUFF ICONS"), (560, 280, "BUFF BARS"), (980, 580, "CUSTOM BAR 1"), (560, 140, "REMINDERS")]:
        body += f'<div style="position:absolute;left:{x}px;top:{y - 4}px;font-family:CondBold;font-size:11px;color:#ff6a1a;letter-spacing:1px">{lab}</div>'
    body += ('<div style="position:absolute;left:300px;top:40px;width:820px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
             'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">TEST</b><br>Sample icons and bars where every '
             'viewer, custom bar and the reminders sit, following every setting: grid, glows, grey-out, stacks, keybinds. Combat ends the test.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S12 Cooldown Manager with Test (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s12_layout": p_layout, "s12_icons": p_icons, "s12_custom": p_custom, "s12_visibility": p_visibility,
         "s12_reminders": p_reminders, "s12_test": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S12 Cooldown Manager (HTML)"), encoding="utf-8")
        w = 1440 if name == "s12_test" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
