#!/usr/bin/env python3
"""Unit frames (2.0 S8) mockups: HTML mirroring Phoenix_UI_Options/Options/UnitFrames.lua and
Previews/UnitFrames.lua, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome.
Labels come from Locales/enUS.lua, the setting count from the smoke harness ("unit frames depth (S8)"). Portraits,
icons and textures are CSS stand-ins for the game's art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s8.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, cfield, chips, style_face, COG, ALL, preview, page_head, tabs  # noqa: E402

s6.DEPTH["UnitFrames"] = (200, 150)
s6.DEPTH["ActionBars"] = (116, 114)
s6.DEPTH["CooldownText"] = (15, 12)
OUT = SRC.parent

CLASS = {"PALADIN": "#f48cba", "MAGE": "#3fc7eb", "PRIEST": "#ffffff", "WARRIOR": "#c69b6d", "ROGUE": "#fff468", "DRUID": "#ff7c0a"}
HOSTILE, FRIENDLY = "#e04a3a", "#3ddc97"
CSS = ('<style>.uf{position:absolute;box-shadow:0 0 0 1px #000,0 3px 8px rgba(0,0,0,.6);background:#0b0c10}'
       '.uf .hp{position:absolute;overflow:hidden;background:#1a1c22}.uf .hp>i{position:absolute;left:0;top:0;bottom:0}'
       '.uf .pw{position:absolute;background:#0a0f1c;overflow:hidden}.uf .pw>i{position:absolute;left:0;top:0;bottom:0}'
       '.uf .tx{position:absolute;font-family:CondSemi;color:#fff;text-shadow:1px 1px 0 #000;white-space:nowrap}'
       '.uf .pt{position:absolute;background:radial-gradient(circle at 40% 35%,#c8a2ff,#3b1f63);box-shadow:0 0 0 1px #000}'
       '.ai{position:absolute;width:20px;height:20px;box-shadow:0 0 0 1px #000}.ai b{position:absolute;right:1px;bottom:0;font-family:CondBold;font-size:10px;color:#fff;text-shadow:1px 1px 0 #000}'
       '.mk{position:absolute;width:16px;height:16px;font-size:14px;line-height:16px;text-align:center}'
       '.cp{position:absolute;display:flex;gap:2px}.cp i{flex:1;box-shadow:0 0 0 1px #000}</style>')
AURA = ["#d4a017,#4a3404", "#2b6fd6,#0b1d3d", "#7b3fd0,#22103d", "#2fa86a,#0b3320", "#c43a3a,#3d0b0b", "#3fb6c9,#0b2d33"]


def frame(x, y, w, h, name, hp, color, right="", power=None, pcolor="#4da3ff", portrait="left", info="", dark=False,
          absorb=0, marker=None, glow=None, auras=(), debuffs=(), cp=None, faded=False, target=False, cast=None, star=False):
    ph = 6 if power is not None else 0
    px = h if portrait in ("left", "right") else 0
    x0 = px + 1 if portrait == "left" else 0
    hw = w - px - (1 if px else 0)
    hh = h - ph - (1 if ph else 0)
    fill = f"background:linear-gradient(180deg,{color},{color}cc)"
    hpbar = (f'<i style="width:{hp}%;{"background:#22252c" if dark else fill}"></i>'
             + (f'<i style="left:{hp}%;width:{100 - hp}%;{fill}"></i>' if dark else '')
             + (f'<i style="left:{hp}%;width:{absorb}%;background:repeating-linear-gradient(45deg,rgba(255,255,255,.55) 0 3px,rgba(255,255,255,.15) 3px 6px)"></i>' if absorb else ''))
    out = [f'<div class="uf" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;{"opacity:.45;" if faded else ""}'
           f'{"box-shadow:0 0 0 1px var(--acc),0 0 10px rgba(255,61,0,.6);" if target else ""}'
           f'{"box-shadow:0 0 0 1px #000,0 0 10px " + glow + ";" if glow else ""}">']
    if px:
        pl = 0 if portrait == "left" else w - px
        out.append(f'<div class="pt" style="left:{pl}px;top:0;width:{px}px;height:{px}px"></div>')
    out.append(f'<div class="hp" style="left:{x0}px;top:0;width:{hw}px;height:{hh}px">{hpbar}</div>')
    if ph:
        out.append(f'<div class="pw" style="left:{x0}px;top:{h - ph}px;width:{hw}px;height:{ph}px"><i style="width:{power}%;background:{pcolor}"></i></div>')
    fs = max(10, min(13, hh // 2 + 1))
    out.append(f'<div class="tx" style="left:{x0 + 5}px;top:{(hh - fs) // 2 - 1}px;font-size:{fs}px">{name}</div>')
    if right:
        out.append(f'<div class="tx" style="right:{(px + 5) if portrait == "right" else 5}px;top:{(hh - fs) // 2 - 1}px;font-size:{fs}px">{right}</div>')
    if info:
        out.append(f'<div class="tx" style="left:{x0 + 5}px;top:{hh - 13}px;font-size:9.5px;color:#c9ced8">{info}</div>')
    if marker:
        out.append(f'<div class="mk" style="left:{x0 + hw // 2 - 8}px;top:-9px">{marker}</div>')
    if star:
        out.append('<div class="mk" style="left:-7px;top:-7px;color:#ffd24a;font-size:13px">★</div>')
    for i, (c, n) in enumerate(auras):
        c1, c2 = AURA[c % len(AURA)].split(",")
        out.append(f'<div class="ai" style="left:{x0 + i * 22}px;top:-24px;background:radial-gradient(circle at 35% 30%,{c1},{c2})"><b>{n}</b></div>')
    for i, (c, n, edge, grey) in enumerate(debuffs):
        c1, c2 = AURA[c % len(AURA)].split(",")
        g = "filter:grayscale(1) brightness(.6);" if grey else ""
        out.append(f'<div class="ai" style="left:{x0 + i * 22}px;top:{h + 4 + (10 if cast else 0)}px;{g}background:radial-gradient(circle at 35% 30%,{c1},{c2});'
                   f'box-shadow:0 0 0 1px {edge}"><b>{n}</b></div>')
    if cp:
        n, lit, col = cp
        pips = "".join(f'<i style="background:{col if i < lit else "rgba(255,255,255,.08)"}"></i>' for i in range(n))
        out.append(f'<div class="cp" style="left:{x0}px;top:-9px;width:{hw}px;height:6px">{pips}</div>')
    if cast:
        out.append(f'<div style="position:absolute;left:{x0}px;top:{h + 2}px;width:{hw}px;height:9px;background:#14161b;box-shadow:0 0 0 1px #000">'
                   f'<i style="position:absolute;left:0;top:0;bottom:0;width:{cast}%;background:#ffb02e"></i></div>')
    out.append('</div>')
    return "".join(out)


def scope(on="Target"):
    items = [(n, None) for n in ("Player", "Target", "Target of target", "Focus", "Focus target", "Pet", "Boss", "Arena")]
    return (f'<div class="scope"><div class="t">{ico("unitframes", 13)}Frame<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips(items, on=(on,))}'
            f'<div style="margin-left:auto;display:flex;align-items:center;gap:8px;font-family:Cond;font-size:11px;color:var(--muted)">Apply all settings from {sel("Focus", 110)}</div></div></div>')


def head():
    return page_head("unitframes", "Unit Frames", "Phoenix's own player, target, focus, pet, boss and arena frames: bars, tags, portraits, icons and auras.", "UnitFrames")


TABS = ["Frames", "Health", "Power", "Text", "Portrait", "Icons and auras"]


def dock(key="target", states=("Low health",)):
    low = "Low health" in states
    far = "Out of range" in states
    if key == "player":
        st = CSS + frame(34, 44, 280, 46, "Vorte", 30 if low else 86, CLASS["PALADIN"], "412K · 86%", power=64, portrait="left",
                         cp=(5, 3, "#ffd24a"), marker="✦", auras=[(0, ""), (1, "3")])
    else:
        st = CSS + frame(34, 40, 280, 46, "Void-Touched Stalker", 18 if low else 57, HOSTILE, "1.8M · 57%" if not low else "520K · 18%",
                         power=80, pcolor="#e04a3a", portrait="right", info="92 Elite", absorb=0, marker="☾", faded=far, star=True,
                         debuffs=[(4, "", "#3f8cff", False), (2, "2", "#9b4dff", True), (3, "", "#3ddc97", False)], auras=[(0, ""), (5, "3")])
    return preview("Live preview", st, 170, [("Low health", None), ("Out of range", None), ("In combat", "cat-combat")], on=states, tag="UNIT FRAME")


def frames_tab():
    mode = card("unitframes", "Unit frames", [line("Unit frames", sel("Phoenix frames", 220), "Phoenix frames replace Blizzard's player, target, focus, pet and boss frames. Blizzard keeps the game's frames and only reskins them. Changing this reloads the interface."),
                                              line("Show test frames", f'<div class="btn">{ico("test")}Show</div>', "Sample frames for every unit in your style, where the real ones sit."),
                                              line("Move frames", f'<div class="btn">{ico("editmode")}Layout mode</div>', "Opens Layout mode, where every Phoenix frame has a mover you can drag and snap.")])
    size = card("layout", "Size", [pair(cell("Width", sld(52, "240"), ALL()), cell("Height", sld(30, "46"), ALL())),
                                   pair(cell("Scale", sld(50, "100%")), cell("Frame strata", sel("Low", 160))),
                                   pair(cell("Anchor point", sel("Center", 160)), cell("Horizontal offset", sld(64, "290")))], gate=True)
    look = card("border", "Look", [pair(cell("Bar texture", sel("Satin", 180, sw="linear-gradient(180deg,#e04a3a,#9a2414)")), cell("Frame border", style_face("Pixel", "pixel"), COG() + ALL())),
                                   pair(cell("Background opacity", sld(80, "80%")), cell("Unit tooltip", sel("Out of combat only", 170))),
                                   line("Mouseover highlight", tog(), "The frame brightens while the mouse is over it.")])
    fade = card("opacity", "Fading", [line("Range fade", tog(), "Group members more than 40 yards away fade. The game does not tell addons the range of enemies in combat, so enemy frames stay solid then.", side=COG()),
                                      line("Fade out of combat", tog(False), "The frame fades when you are out of combat with nothing targeted and full health.", side=COG())])
    content = head() + scope("Target") + tabs(TABS, 0) + '<div class="body">' + mode + size + look + fade + '</div>'
    return s6.shell("frames", "frames", "UnitFrames", content, dock(), status="Target · Width applies to Target + Focus")


def health_tab():
    bar = card("heart", "Health bar", [line("Health colour", sel("By health left", 200), "Class colour for players, reaction colour for NPCs, a colour by health left, one fixed colour, or the theme surface.", side=COG()),
                                       line("Dark mode bar", tog(False), "The health part is dark and the missing part shows the colour, so damage taken stands out."),
                                       line("Bar shading", sld(40, "25%"), "A soft top-to-bottom shade on the bar. Zero is flat."),
                                       pair(tcell("Vertical bars", False), cell("Bar background", sel("Dark tint of the bar colour", 200), COG()))])
    ab = card("lock", "Absorbs and heals", [line("Absorb shields", tog(), "Shows absorb shields on the health bar, after the current health.", side=COG()),
                                            line("Heal absorbs", tog(), "Effects that soak up healing show as a dark part at the end of the health."),
                                            line("Incoming heals", tog(), "Heals being cast on the unit show ahead of its health.")])
    col = card("palette", "Colours", [line("Health colour steps", '<div style="display:flex;gap:6px">' + swatch("#3ddc97") + swatch("#ffc24b") + swatch("#ff4d5e") + '</div>', "Used when the health colour is “By health left”."),
                                      line("State colours", '<div style="display:flex;gap:6px">' + swatch("#8a8f99") + swatch("#5b5f68") + swatch("#5b5f68") + '</div>')])
    st = CSS + frame(34, 30, 280, 40, "Vorte", 46, "#ffc24b", "236K · 46%", power=64, portrait="left", absorb=18)
    st += frame(34, 92, 280, 40, "Shieldbearer", 72, CLASS["WARRIOR"], "72%", power=40, pcolor="#c43a3a", portrait="left", dark=True)
    dk = preview("Live preview", st, 170, [("Low health", None), ("Out of range", None), ("In combat", "cat-combat")], on=(), tag="UNIT FRAME")
    content = head() + scope("Player") + tabs(TABS, 1) + '<div class="body">' + bar + ab + col + '</div>'
    return s6.shell("frames", "frames", "UnitFrames", content, dk, status="Health colour: by health left (curve)")


def power_tab():
    pb = card("speed", "Power bar", [pair(cell("Show power bar", sel("Always", 160), ALL()), cell("Power bar height", sld(30, "6"))),
                                     pair(cell("Power bar place", sel("Inside the frame", 170)), cell("Power colour", sel("Resource type", 170), COG())),
                                     line("Encounter power bar", tog(), "The extra bar some encounters and quests add (alternate power), under the frame.")])
    cp = card("spec", "Class resource", [line("Show class resource", sel("Attached to the player frame", 240), "Combo points, holy power, soul shards, chi, arcane charges, essence, runes and stagger on the player frame, or on their own mover."),
                                         pair(cell("Height", sld(25, "6")), cell("Pip spacing", sld(20, "2"))),
                                         pair(cell("Pip colour", sel("Resource type", 160)), cell("Empty pip opacity", sld(25, "25%"))),
                                         pair(tcell("Sort runes", True), tcell("Stagger bar", True)),
                                         line("Charged combo points", cfield("#ff3d00", "theme"), "The colour of combo points that are charged.")])
    st = CSS + frame(34, 34, 280, 42, "Vorte", 86, CLASS["ROGUE"], "86%", power=72, pcolor="#ffd24a", portrait="left", cp=(7, 4, "#ff6a1a"))
    st += frame(34, 112, 280, 34, "Brewmaster", 92, "#00ff98", "92%", power=60, pcolor="#ffd24a", portrait="hide", cp=(1, 1, "#ffc24b"))
    dk = preview("Live preview", st, 170, [("Low health", None), ("Out of range", None), ("In combat", "cat-combat")], on=("In combat",), tag="UNIT FRAME")
    content = head() + scope("Player") + tabs(TABS, 2) + '<div class="body">' + pb + cp + '</div>'
    return s6.shell("frames", "frames", "UnitFrames", content, dk, status="Class resource: combo points 4 of 7")


def text_tab():
    tg = card("fonts", "Text tags", [line("Name text", '<div class="sel" style="--w:260px"><span style="font-family:Mono;font-size:10.5px">[name]</span></div>', side=COG()),
                                     line("Health text", '<div class="sel" style="--w:260px"><span style="font-family:Mono;font-size:10.5px">[health:current] · [health:percent]</span></div>', side=COG()),
                                     line("Power text", '<div class="sel" style="--w:260px"><span style="font-family:Mono;font-size:10.5px"></span></div>', side=COG()),
                                     line("Extra text", '<div class="sel" style="--w:260px"><span style="font-family:Mono;font-size:10.5px">[level] [classification]</span></div>', side=COG()),
                                     '<div class="rowl"><div class="lt"><div class="ds">Tags: [name] [name:short] [level] [classification] [class] [status] [group] [afk] [health:current] [health:max] [health:percent] [health:current-max] [health:current-percent] [health:deficit] [absorbs] [power:current] [power:max] [power:percent] [power:current-max] [altpower]. Up to 8 tags per text.</div></div></div>'])
    nm = card("user", "Name", [pair(cell("Longest name", sld(40, "18")), cell("Name colour", sel("White", 160))),
                               line("Hide health text at full", tog(False), "The health text fades out while the unit is at full health.")])
    nb = card("grid", "Numbers", [line("Number style", sel("Short (12.3K)", 200), "How health and power numbers are written."),
                                  pair(cell("Decimals for short numbers", sld(50, "1")), cell("Decimals for percent", sld(0, "0")))])
    content = head() + scope("Target") + tabs(TABS, 3) + '<div class="body">' + tg + nm + nb + '</div>'
    return s6.shell("frames", "frames", "UnitFrames", content, dock(states=()), status="Tags compile to one format string")


def icons_tab():
    ic = card("presets", "Status icons", [pair(tcell("Raid marker", True), cell("Icon size", sld(40, "16"))),
                                          pair(tcell("Leader icon", True), tcell("Role icon", True)),
                                          pair(tcell("PvP icon", False), tcell("In combat icon", True)),
                                          line("Threat glow", tog(), "The frame edge glows yellow, orange or red as the unit's threat on you rises."),
                                          line("Ready check", tog(), "Shows ready, not ready or waiting during a ready check.")])
    au = card("auras", "Auras", [pair(cell("Buffs", sel("Above", 140)), cell("Debuffs", sel("Below", 140))),
                                 pair(cell("Which buffs", sel("All", 140)), cell("Which debuffs", sel("Mine only", 140))),
                                 pair(cell("Size", sld(30, "20")), cell("Icons per row", sld(40, "8"))),
                                 line("Colour by dispel type", tog(), "Debuff borders take the colour of their type: magic, curse, disease, poison, enrage or bleed."),
                                 line("Grey out others' debuffs", tog(), "On enemy frames, debuffs you did not cast are shown in grey.")])
    cs = card("castbars", "Cast bar anchor", [line("Cast bar", sel("Below", 160), "Until Phoenix cast bars arrive, Blizzard's own target, focus and boss cast bar is placed here."),
                                              pair(cell("Cast bar height", sld(30, "14")), cell("Cast bar gap", sld(20, "4")))])
    st = CSS + frame(34, 46, 280, 46, "Void-Touched Stalker", 57, HOSTILE, "57%", power=80, pcolor="#e04a3a", portrait="right", info="92 Elite",
                     marker="☾", glow="#ff4d5e", star=True, cast=62, auras=[(0, ""), (5, "3"), (1, "")],
                     debuffs=[(4, "", "#3f8cff", False), (2, "2", "#9b4dff", True), (3, "", "#3ddc97", False)])
    dk = preview("Live preview", st, 170, [("Low health", None), ("Out of range", None), ("In combat", "cat-combat")], on=("In combat",), tag="UNIT FRAME")
    content = head() + scope("Target") + tabs(TABS, 5) + '<div class="body">' + ic + au + cs + '</div>'
    return s6.shell("frames", "frames", "UnitFrames", content, dk, status="Dispel colours from the game's curve")


def world():
    mv = 'outline:1px dashed var(--acc);outline-offset:4px;'
    def lbl(t, x, y):
        return f'<div style="position:absolute;left:{x}px;top:{y}px;font-family:CondBold;font-size:10px;letter-spacing:1px;color:var(--acc);background:rgba(10,10,12,.8);padding:2px 6px">{t}</div>'
    def mov(html):
        return html.replace('class="uf" style="', f'class="uf" style="{mv}', 1)
    body = CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
    body += mov(frame(310, 560, 240, 46, "Vorte", 86, CLASS["PALADIN"], "412K · 86%", power=64, portrait="left", cp=(5, 3, "#ffd24a"), marker="✦"))
    body += mov(frame(890, 560, 240, 46, "TEST · Void-Touched Stalker", 57, HOSTILE, "57%", power=80, pcolor="#e04a3a", portrait="right", info="92 Elite",
                      star=True, cast=40, debuffs=[(4, "", "#3f8cff", False), (2, "2", "#9b4dff", True)], auras=[(0, ""), (5, "3")]))
    body += mov(frame(1150, 566, 120, 24, "Vorte", 79, CLASS["PALADIN"], portrait="hide"))
    body += mov(frame(310, 630, 120, 22, "Felguard", 92, "#3ddc97", portrait="hide", power=50, pcolor="#4da3ff"))
    body += mov(frame(130, 380, 200, 36, "TEST · Mender", 24, CLASS["PRIEST"], "24%", power=40, portrait="left", faded=True))
    body += mov(frame(350, 386, 120, 24, "Ashen Brute", 64, HOSTILE, portrait="hide"))
    for i in range(5):
        body += mov(frame(1180, 160 + i * 62, 200, 40, f"TEST · Boss {i + 1}", [100, 82, 61, 37, 12][i], HOSTILE, f"{[100, 82, 61, 37, 12][i]}%",
                          power=70, pcolor="#e04a3a", portrait="hide", target=(i == 1), cast=(55 if i == 2 else None)))
    body += (lbl("PLAYER", 310, 538) + lbl("TARGET", 890, 538) + lbl("TARGET OF TARGET", 1150, 544) + lbl("PET", 310, 660)
             + lbl("FOCUS", 130, 358) + lbl("FOCUS TARGET", 350, 364) + lbl("BOSS", 1180, 138))
    body += ('<div style="position:absolute;left:520px;top:40px;width:420px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
             'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">TEST FRAMES · LAYOUT MODE</b><br>Sample frames for every unit in your style. '
             'Drag a frame (the five boss frames move as one) to place it; right-click resets. Both close when combat starts.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S8 unit frames with Test frames in Layout mode (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s8_frames": frames_tab, "s8_health": health_tab, "s8_power": power_tab, "s8_text": text_tab,
         "s8_icons": icons_tab, "s8_test": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S8 unit frames (HTML)"), encoding="utf-8")
        w = 1440 if name == "s8_test" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
