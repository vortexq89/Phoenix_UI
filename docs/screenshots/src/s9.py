#!/usr/bin/env python3
"""Cast bars and buffs/debuffs (2.0 S9) mockups: HTML mirroring Phoenix_UI_Options/Options/CastBars.lua, Auras.lua
and their Previews, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome.
Labels come from Locales/enUS.lua, the setting counts from the smoke harness ("cast bars depth (S9)", "auras depth
(S9)"). Icons and textures are CSS stand-ins for the game's art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s9.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, chips, style_face, COG, ALL, preview, page_head, tabs  # noqa: E402
import s8  # noqa: E402

s6.DEPTH["CastBars"] = (100, 55)
s6.DEPTH["Auras"] = (63, 41)
OUT = SRC.parent
CSS = s8.CSS + ('<style>.cb{position:absolute;background:#14161b;box-shadow:0 0 0 1px #000,0 3px 8px rgba(0,0,0,.6)}'
                '.cb>.f{position:absolute;left:0;top:0;bottom:0}.cb>.sp{position:absolute;top:-2px;bottom:-2px;width:2px;background:#fff;box-shadow:0 0 6px #fff}'
                '.cb>.lat{position:absolute;right:0;top:0;bottom:0;background:rgba(255,61,0,.45)}.cb>.tk{position:absolute;top:0;bottom:0;width:1px;background:rgba(255,255,255,.7)}'
                '.cb>.st{position:absolute;top:-1px;bottom:-1px;width:2px;background:#ffe9a8}.cb>.kk{position:absolute;top:-3px;bottom:-3px;width:2px;background:#3ddc97;box-shadow:0 0 4px #3ddc97}'
                '.cb .tx{position:absolute;top:50%;transform:translateY(-50%);font-family:CondSemi;color:#fff;text-shadow:1px 1px 0 #000;white-space:nowrap}'
                '.cbi{position:absolute;box-shadow:0 0 0 1px #000;background:radial-gradient(circle at 35% 30%,#7fd0ff,#123049)}'
                '.cbi b{position:absolute;right:-5px;bottom:-5px;font-size:11px}'
                '.au{position:absolute;box-shadow:0 0 0 1px #000}.au b{position:absolute;right:2px;bottom:1px;font-family:CondBold;font-size:11px;color:#fff;text-shadow:1px 1px 0 #000}'
                '.au s{position:absolute;left:0;right:0;bottom:-15px;text-align:center;font-family:CondSemi;font-size:11px;text-decoration:none;text-shadow:1px 1px 0 #000}</style>')
COL = {"cast": "#ffb02e", "channel": "#3ddc97", "locked": "#8a8f99", "notready": "#c43a3a", "interrupted": "#ff4d5e", "empower": "#7b8cff"}


def castbar(x, y, w, h, name, time, pct, kind="cast", icon="left", lat=0, ticks=0, stages=(), kick=None, target="",
            shield=False, glow=False, edge=False, mover=False):
    out = []
    ix = x
    if icon == "left":
        out.append(f'<div class="cbi" style="left:{x}px;top:{y}px;width:{h}px;height:{h}px">{"<b>🛡</b>" if shield else ""}</div>')
        x, w = x + h + 3, w - h - 3
    elif icon == "right":
        out.append(f'<div class="cbi" style="left:{x + w - h}px;top:{y}px;width:{h}px;height:{h}px">{"<b>🛡</b>" if shield else ""}</div>')
        w = w - h - 3
    st = ""
    if glow:
        st += "box-shadow:0 0 0 1px #000,0 0 10px #ffd24a;"
    if edge:
        st += "outline:2px solid #ff4d5e;outline-offset:0;"
    if mover:
        st += "outline:1px dashed var(--acc);outline-offset:4px;"
    c = COL[kind]
    inner = f'<i class="f" style="width:{pct}%;background:linear-gradient(180deg,{c},{c}bb)"></i>'
    inner += f'<i class="sp" style="left:calc({pct}% - 1px)"></i>' if kind != "interrupted" else ""
    if lat:
        inner += f'<i class="lat" style="width:{lat}%"></i>'
    for t in range(1, ticks):
        inner += f'<i class="tk" style="left:{t * 100 / ticks:.2f}%"></i>'
    for s in stages:
        inner += f'<i class="st" style="left:{s}%"></i>'
    if kick is not None:
        inner += f'<i class="kk" style="left:{kick}%"></i>'
    fs = max(10, min(13, h - 4))
    inner += f'<div class="tx" style="left:5px;font-size:{fs}px">{name}{(" <span style=color:#c9ced8>→ " + target + "</span>") if target else ""}</div>'
    if time:
        inner += f'<div class="tx" style="right:5px;font-size:{fs}px">{time}</div>'
    out.append(f'<div class="cb" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;{st}">{inner}</div>')
    del ix
    return "".join(out)


AURA = ["#d4a017,#4a3404", "#2b6fd6,#0b1d3d", "#7b3fd0,#22103d", "#2fa86a,#0b3320", "#c43a3a,#3d0b0b", "#3fb6c9,#0b2d33"]


def aura(x, y, s, c, timer, tcol="#fff", stack="", edge="#000", wide=False, grey=False):
    h = int(s * 0.7 + 0.5) if wide else s
    c1, c2 = AURA[c % len(AURA)].split(",")
    g = "filter:grayscale(1) brightness(.75);" if grey else ""
    return (f'<div class="au" style="left:{x}px;top:{y}px;width:{s}px;height:{h}px;box-shadow:0 0 0 1px {edge};'
            f'background:radial-gradient(circle at 35% 30%,{c1},{c2})"><i style="position:absolute;inset:0;{g}"></i>'
            f'{"<b>" + stack + "</b>" if stack else ""}<s style="color:{tcol}">{timer}</s></div>')


def cb_head():
    return page_head("castbars", "Cast Bars", "Phoenix's own cast bars for player, target, focus, pet, boss and arena: colours, ticks, stages, latency and texts.", "CastBars")


CB_TABS = ["Bars", "Look", "Text", "Behaviour"]


def cb_scope(on="Target"):
    items = [(n, None) for n in ("Player", "Target", "Focus", "Pet", "Boss", "Arena")]
    return (f'<div class="scope"><div class="t">{ico("castbars", 13)}Bar<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips(items, on=(on,))}</div></div>')


def cb_dock(state="Casting"):
    st = CSS
    if state == "Interrupted":
        st += castbar(24, 30, 262, 20, "Interrupted", "", 100, "interrupted")
    else:
        st += castbar(24, 30, 262, 20, "Greater Heal", "1.2 / 2.5", 48, "cast", lat=9)
    st += castbar(24, 66, 262, 20, "Shadow Bolt Volley", "0.8", 66, "notready", kick=82, target="Vorte", edge=True)
    st += castbar(24, 102, 262, 20, "Void Eruption", "2.1", 31, "locked", shield=True, glow=True)
    st += castbar(24, 138, 262, 20, "Fire Breath", "", 58, "empower", stages=(25, 50, 75))
    return preview("Live preview", st, 176, [("Casting", None), ("Channel", None), ("Interrupted", None)], on=(state,), tag="CAST BAR")


def cb_bars():
    mode = card("castbars", "Cast bars", [line("Bars drawn by", sel("Phoenix", 200), "Phoenix draws its own cast bars for player, target, focus, pet, boss and arena (the player bar replaces Edit Mode's). Blizzard keeps the game's bars and only skins them."),
                                          line("Test casts", f'<div class="btn">{ico("test")}Toggle test casts</div>', "Every enabled bar loops a sample cast where it sits, so you can see sizes, colours, ticks and texts out of combat or in it."),
                                          line("Move frames", f'<div class="btn">{ico("editmode")}Layout mode</div>', "Drag the free cast bars, the swing timer and attached bars' frames in Layout mode.")])
    size = card("layout", "Size and placement", [line("Show this cast bar", tog(), "Off: no Phoenix bar for this unit."),
                                                 line("Placement", sel("Attached to the unit frame", 230), "Attached: the bar sits on the Phoenix unit frame's cast bar anchor (Unit Frames > Cast bar). Free: its own mover."),
                                                 pair(cell("Width", sld(52, "240"), ALL()), cell("Height", sld(30, "18"), ALL())),
                                                 pair(cell("Scale", sld(50, "100%")), cell("Frame strata", sel("Medium", 160)))], gate=True)
    look = card("border", "Fill", [pair(cell("Bar texture", sel("Satin", 180, sw="linear-gradient(180deg,#ffb02e,#a86a0a)")), cell("Border", style_face("Pixel", "pixel"), COG() + ALL())),
                                   pair(tcell("Reverse fill", False), tcell("Smooth fill", True)),
                                   line("Fill colours", '<div style="display:flex;gap:6px">' + swatch(COL["cast"]) + swatch(COL["channel"]) + swatch(COL["locked"]) + '</div>', "Interruptible casts, channels and casts that cannot be interrupted. Right-click a swatch to follow the theme."),
                                   line("State colours", '<div style="display:flex;gap:6px">' + swatch(COL["notready"]) + swatch(COL["interrupted"]) + swatch("#3ddc97") + '</div>', "Interrupt not ready, interrupted and finished flashes.")])
    content = cb_head() + cb_scope("Target") + tabs(CB_TABS, 0) + '<div class="body">' + mode + size + look + '</div>'
    return s6.shell("frames", "frames", "CastBars", content, cb_dock(), status="Target · attached to the unit frame anchor")


def cb_behaviour():
    pl = card("spec", "Your casts", [line("Latency", tog(), "The part of your cast the server still has to answer, at the end of the bar.", side=COG()),
                                     line("Channel ticks", tog(), "Marks where your channelled spells tick. Built-in counts are a starting point; the list below overrides them.", side=COG()),
                                     line("Own tick counts", '<div class="sel" style="--w:260px"><span style="font-family:Mono;font-size:10.5px">15407:6, 234153:5</span></div>'),
                                     line("Empower stages", tog(), "Marks each stage of an empowered spell.", side=COG()),
                                     line("Global cooldown bar", tog(False), "A thin bar under your cast bar while the global cooldown runs.", side=COG())])
    en = card("cat-combat", "Enemy casts", [line("Interrupt-ready tick", tog(), "A tick where your interrupt comes off cooldown; casts turn the not-ready colour until then.", side=COG()),
                                        line("Glow on important casts", tog(), "Spells the game marks as important get a glow."),
                                        line("Mark casts at me", tog(), "A red edge while the cast is aimed at you.")])
    end = card("opacity", "When a cast ends", [pair(cell("Hold time", sld(30, "0.6")), tcell("Interrupted and finished flash", True))])
    note = '<div class="rowl"><div class="lt"><div class="ds">In 12.x the game can hide cast timing from addons (secret values). Phoenix bars then still fill, colour and count down - the game does the maths.</div></div></div>'
    st = CSS + castbar(24, 34, 262, 22, "Mind Flay", "1.9", 62, "channel", ticks=6, lat=8)
    st += castbar(24, 78, 262, 22, "Fire Breath", "", 58, "empower", stages=(25, 50, 75))
    st += castbar(24, 122, 262, 22, "Shadow Bolt Volley", "0.8", 66, "notready", kick=82, target="Vorte")
    dk = preview("Live preview", st, 176, [("Casting", None), ("Channel", None), ("Interrupted", None)], on=("Channel",), tag="CAST BAR")
    content = cb_head() + cb_scope("Player") + tabs(CB_TABS, 3) + '<div class="body">' + pl + en + end + card("lock", "Secret values", [note]) + '</div>'
    return s6.shell("frames", "frames", "CastBars", content, dk, status="Player · ticks 6 (Mind Flay)")


def au_head():
    return page_head("auras", "Buffs & Debuffs", "Your buffs, debuffs and weapon enchants on Phoenix aura containers: grid, sort, timers and type borders.", "Auras")


AU_TABS = ["Layout", "Look", "Text", "Enchants and more"]


def au_scope(on="Buffs"):
    return (f'<div class="scope"><div class="t">{ico("auras", 13)}Header<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips([("Buffs", None), ("Debuffs", None)], on=(on,))}</div></div>')


def au_grid(x0, y0, s, n, per, wide=False, debuff=False, gap=5, start=0):
    out = ""
    h = int(s * 0.7 + 0.5) if wide else s
    edges = ["#9b4dff", "#3f8cff", "#3ddc97", "#8a5a2b", "#c43a3a"]
    timers = [("2h", "#fff"), ("14m", "#fff"), ("48s", "#ffc24b"), ("6.2", "#ff4d5e"), ("31m", "#fff"), ("55s", "#ffc24b"),
              ("9m", "#fff"), ("1h", "#fff"), ("3.4", "#ff4d5e"), ("22m", "#fff")]
    for i in range(n):
        r, c = divmod(i, per)
        t, tc = timers[(i + start) % len(timers)]
        out += aura(x0 - c * (s + gap), y0 + r * (h + 20), s, i + start, t, tc, stack=("3" if i % 4 == 1 else ""),
                    edge=edges[i % len(edges)] if debuff else "#000", wide=wide, grey=debuff and i % 3 == 2)
    return out


def au_dock(state=()):
    st = CSS + au_grid(236, 22, 28, 8, 8) + au_grid(236, 100, 28, 4, 8, debuff=True, start=3)
    return preview("Live preview", st, 176, [("Expiring", None)], on=state, tag="AURAS")


def au_layout():
    mode = card("auras", "Auras", [line("Auras drawn by", sel("Phoenix (aura containers)", 240), "Phoenix shows your buffs, debuffs and weapon enchants on its own aura containers (right-click cancels, also in combat). Blizzard keeps BuffFrame and DebuffFrame and Phoenix only skins them."),
                                   line("Test auras", f'<div class="btn">{ico("test")}Toggle test auras</div>', "Fills both headers with sample buffs and debuffs (timers, stacks, type borders) so you can lay them out.")])
    grid = card("grid", "Grid", [line("Show this header", tog(), "Off: these auras are not shown at all."),
                                 pair(cell("Icon size", sld(40, "32"), ALL()), cell("Icon shape", sel("Square", 140))),
                                 pair(cell("Icons per row", sld(50, "8")), cell("Rows", sld(20, "2"))),
                                 pair(cell("Horizontal spacing", sld(30, "6")), cell("Row spacing", sld(40, "20"))),
                                 pair(cell("Grow towards", sel("Left", 140)), cell("New rows go", sel("Down", 140)))], gate=True)
    srt = card("presets", "Sorting", [pair(cell("Sort by", sel("Time left", 150)), cell("Direction", sel("Descending", 150))),
                                      line("Your own auras", sel("First", 150), "Keep auras you cast before the others."),
                                      '<div class="rowl"><div class="lt"><div class="ds">Grid changes apply out of combat (aura containers). Timers, borders and colours update any time.</div></div></div>'])
    content = au_head() + au_scope("Buffs") + tabs(AU_TABS, 0) + '<div class="body">' + mode + grid + srt + '</div>'
    return s6.shell("frames", "frames", "Auras", content, au_dock(), status="Buffs · 8 per row, sorted by time left")


def au_look():
    lk = card("border", "Look", [line("Border by debuff type", tog(), "Magic, curse, disease, poison and bleed get the game's colours (the game supplies them, secret auras too)."),
                                 pair(tcell("Cooldown swipe", True), tcell("Reverse swipe", False)),
                                 line("Grey debuff icons", tog(), "Show debuff art in grey so the type border stands out.")])
    tm = card("clock", "Timer", [pair(cell("Time format", sel("Short (2h, 14m, 28)", 190)), cell("Tenths below", sld(20, "10"))),
                                 line("Colour by time left", tog(), "Timers turn the soon colour under a minute and the expiring colour under the tenths threshold.", side=COG()),
                                 line("Timer colours", '<div style="display:flex;gap:6px">' + swatch("#ff4d5e") + swatch("#ffc24b") + swatch("#ffffff") + '</div>')])
    bh = card("spec", "Behaviour", [line("Right-click cancels buffs", tog(), "Right-click a buff to remove it (secure, works in combat)."),
                                      line("Weapon enchants", sel("With the buffs", 170), "Temporary weapon enchants (oils, poisons, imbues) with the buffs, as their own block, or hidden."),
                                      pair(tcell("Show private auras", True), cell("Anchors", sld(30, "3")))])
    content = au_head() + au_scope("Debuffs") + tabs(AU_TABS, 1) + '<div class="body">' + lk + tm + bh + '</div>'
    return s6.shell("frames", "frames", "Auras", content, au_dock(("Expiring",)), status="Debuffs · type borders from the game's colours")


def world():
    def lbl(t, x, y):
        return f'<div style="position:absolute;left:{x}px;top:{y}px;font-family:CondBold;font-size:10px;letter-spacing:1px;color:var(--acc);background:rgba(10,10,12,.8);padding:2px 6px">{t}</div>'
    mv = '<div style="position:absolute;left:{}px;top:{}px;width:{}px;height:{}px;outline:1px dashed var(--acc);outline-offset:4px"></div>'
    body = CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
    body += s8.frame(310, 560, 240, 46, "Vorte", 86, s8.CLASS["PRIEST"], "412K · 86%", power=64, portrait="left")
    body += castbar(310, 612, 240, 18, "TEST · Mind Flay", "1.9", 62, "channel", ticks=6, lat=8)
    body += s8.frame(890, 560, 240, 46, "TEST · Void-Touched Stalker", 57, s8.HOSTILE, "57%", power=80, pcolor="#e04a3a", portrait="right", star=True)
    body += castbar(890, 612, 240, 18, "Shadow Bolt Volley", "0.8", 66, "notready", kick=82, target="Vorte", edge=True)
    body += castbar(600, 700, 260, 22, "TEST · Greater Heal", "1.2 / 2.5", 48, "cast", lat=9, mover=True)
    for i in range(3):
        body += s8.frame(1180, 300 + i * 72, 200, 36, f"TEST · Boss {i + 1}", [92, 61, 23][i], s8.HOSTILE, f"{[92, 61, 23][i]}%", portrait="hide")
        body += castbar(1180, 340 + i * 72, 200, 14, ["Void Eruption", "Shadow Nova", "Dark Mending"][i], "2.1", [31, 58, 77][i],
                        ["locked", "cast", "channel"][i], shield=(i == 0), glow=(i == 0), icon="right")
    body += au_grid(1380, 34, 32, 12, 8)
    body += mv.format(1380 - 7 * 37, 34, 8 * 37 - 5, 2 * 52 - 20)
    body += au_grid(1380, 170, 32, 4, 8, debuff=True, start=3)
    body += mv.format(1380 - 7 * 37, 170, 8 * 37 - 5, 32)
    body += aura(960, 34, 32, 1, "58m") + aura(997, 34, 32, 3, "41m") + mv.format(960, 34, 69, 32)
    body += (lbl("BUFFS", 1380 - 7 * 37, 10) + lbl("DEBUFFS", 1380 - 7 * 37, 146) + lbl("WEAPON ENCHANTS", 960, 10)
             + lbl("PLAYER CAST BAR (FREE)", 600, 678) + lbl("TARGET", 890, 538) + lbl("BOSS", 1180, 278))
    body += ('<div style="position:absolute;left:420px;top:40px;width:440px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
             'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">TEST CASTS + TEST AURAS · LAYOUT MODE</b><br>Every bar loops a sample cast; '
             'the buff, debuff and weapon enchant blocks fill with samples. Drag a free bar or a block to place it; right-click resets.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S9 cast bars and auras with Test casts/auras in Layout mode (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s9_castbars": cb_bars, "s9_castbehaviour": cb_behaviour, "s9_auras": au_layout, "s9_auralook": au_look, "s9_test": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S9 cast bars and auras (HTML)"), encoding="utf-8")
        w = 1440 if name == "s9_test" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
