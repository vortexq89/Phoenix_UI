#!/usr/bin/env python3
"""Quests (2.0 S14) mockups: HTML mirroring Phoenix_UI_Options/Options/Quests.lua and Previews/Quests.lua, drawn with
the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from Locales/enUS.lua, the
setting count from the smoke harness ("quests depth (S14)"). The map, pins, tracker and arrow are CSS stand-ins for
the game's art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s14.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, sel, sld, COG, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["Quests"] = (38, 27)
for g in s6.GROUPS:
    if g[0] == "content" and not any(isinstance(e, tuple) and e[0] == "Quests" for e in g[3]):
        g[3].insert(0, ("Quests", "Quests", "maps", True))
OUT = SRC.parent
CSS = s9.CSS + ('<style>.qt{position:absolute;font-family:CondBold;font-size:14px;color:#ff6a1a}.qr{position:absolute;height:1px;background:#ff6a1a;opacity:.4}'
                '.qn{position:absolute;font-family:CondBold;font-size:13px;white-space:nowrap}.qo{position:absolute;font-family:Roboto;font-size:12px;color:#c7cbd3;white-space:nowrap}'
                '.qb{position:absolute;width:170px;height:12px;background:#0b0c0f;box-shadow:0 0 0 1px #000}.qb i{position:absolute;left:0;top:0;bottom:0;background:#ff6a1a}'
                '.qmap{position:absolute;background:#333d29;box-shadow:0 0 0 1px #000,0 0 0 2px #2a2e36;overflow:hidden}'
                '.qpin{position:absolute;width:18px;height:18px;margin:-9px 0 0 -9px;font-family:CondBold;font-size:16px;line-height:18px;text-align:center;'
                'text-shadow:0 0 2px #000,1px 1px 0 #000}.qtip{position:absolute;background:#121419;box-shadow:0 0 0 1px #2a2e36;padding:8px 10px;'
                'font-family:Roboto;font-size:11px;color:#e6e9ef;width:200px;line-height:1.45}.qarrow{position:absolute;color:#ff6a1a;font-size:46px;line-height:46px}'
                '.qcap{position:absolute;font-family:CondSemi;font-size:10px;color:#8a93a3;letter-spacing:.06em}</style>')

PINS = [("!", "#ffd200", 0.30, 0.35), ("!", "#3fa9ff", 0.66, 0.28), ("?", "#ffd200", 0.52, 0.70), ("!", "#ffd200", 0.20, 0.74), ("!", "#ffd200", 0.78, 0.62)]


def fit(html, scale, h):
    return f'<div style="position:absolute;left:0;top:0;width:{int(100 / scale)}%;height:{int(h / scale)}px;transform:scale({scale});transform-origin:0 0">{html}</div>'


def tracker(x=16, y=14):
    o = f'<div class="qt" style="left:{x}px;top:{y}px">Quests</div><div class="qr" style="left:{x}px;top:{y + 20}px;width:250px"></div>'
    o += f'<div class="qn" style="left:{x + 8}px;top:{y + 28}px;color:#ffd200">[82] The Sunwell\'s Call</div>'
    o += f'<div class="qo" style="left:{x + 20}px;top:{y + 47}px">- Wretched cleansed: 5/8</div>'
    o += f'<div class="qo" style="left:{x + 20}px;top:{y + 63}px">- Speak with the Magister</div>'
    o += f'<div class="qb" style="left:{x + 20}px;top:{y + 82}px"><i style="width:60%"></i></div>'
    o += f'<div class="qn" style="left:{x + 8}px;top:{y + 104}px;color:#40c040">[80+G] Shadows over Eversong</div>'
    o += f'<div class="qo" style="left:{x + 20}px;top:{y + 123}px">- Void rift sealed</div>'
    return o


def mapcard(x, y, size=150, tip=False):
    o = f'<div class="qmap" style="left:{x}px;top:{y}px;width:{size}px;height:{size}px">'
    o += f'<i style="position:absolute;left:{size * .45}px;top:{size * .5}px;width:{size * .4}px;height:{size * .3}px;border-radius:50%;background:#26475f"></i>'
    o += f'<i style="position:absolute;left:-10px;top:{size * .55}px;width:{size + 20}px;height:5px;background:#7a6a4e;transform:rotate(-20deg)"></i>'
    for g, c, px, py in PINS:
        o += f'<div class="qpin" style="left:{px * size}px;top:{py * size}px;color:{c}">{g}</div>'
    o += '</div>'
    if tip:
        o += (f'<div class="qtip" style="left:{x + size * .3 + 16}px;top:{y + size * .35 - 6}px"><div style="font-family:CondBold;color:#ffd200">A Request from the Captain</div>'
              '<div style="color:#c7cbd3">Given by Captain Kelira</div><div style="color:#c7cbd3">Requires level 80</div><div style="color:#4db3ff">Daily</div>'
              '<div style="color:#8a93a3">Click: point the arrow here</div></div>')
    return o


def arrow(x, y, deg=-30, size=46):
    return (f'<div class="qarrow" style="left:{x}px;top:{y}px;width:{size}px;height:{size}px;font-size:{size}px;transform:rotate({deg}deg);text-align:center">{ico("arrow-up", size)}</div>'
            f'<div style="position:absolute;left:{x - 40}px;width:{size + 80}px;top:{y + size + 6}px;text-align:center;font-family:CondBold;font-size:12px;color:#ff6a1a;text-shadow:1px 1px 0 #000">The Sunwell\'s Call</div>'
            f'<div style="position:absolute;left:{x - 40}px;width:{size + 80}px;top:{y + size + 22}px;text-align:center;font-family:CondSemi;font-size:12px;color:#e6e9ef;text-shadow:1px 1px 0 #000">214 yd&nbsp;&nbsp;0:31</div>')


def stage():
    html = CSS + tracker() + mapcard(16, 170, 130) + '<div class="qcap" style="left:56px;top:306px">MAP PINS</div>' + arrow(240, 200)
    return preview("Live preview", fit(html, 0.62, 220), 220, tag="QUESTS")


def head():
    return page_head("maps", "Quests", "Quest tracker styling, map and minimap quest pins, a waypoint arrow and quest automation.", "Quests")


QTABS = ["Tracker", "Quest helper", "Automation"]


def p_tracker():
    t = card("tracker", "Objective tracker", [line("Restyle the tracker", s6.tog(), "Phoenix fonts, colours and bars on Blizzard's objective tracker. Blizzard keeps running it."),
                                               pair(cell("Width", sld(0, "Blizzard")), cell("Maximum height", sld(0, "Edit Mode"))),
                                               pair(cell("Header and quest title font", sel("Expressway 14", 160), COG()), cell("Objective font", sel("Roboto 12", 160), COG())),
                                               pair(cell("Progress bar texture", sel("Default", 140)), tcell("Colour titles by difficulty", True)),
                                               pair(tcell("Show level and tag", True), cell("Auto-collapse", sel("In instances", 140))),
                                               pair(tcell("Click a quest to focus it", True), cell("", ""))])
    i = card("items", "Quest items", [pair(tcell("Item bar", True, side='<span class="chip">Action Bars</span>'), tcell("Add usable quest items", True))])
    content = head() + tabs(QTABS, 0) + '<div class="body">' + t + i + '</div>'
    return s6.shell("content", "content", "Quests", content, stage(), status="Tracker restyled · [82+G] tags · collapses in instances", reload=True)


def p_helper():
    a = card("arrow-up", "Waypoint arrow", [pair(tcell("Show the arrow", True), cell("Arrow style", sel("Phoenix", 120))),
                                            pair(cell("Arrow size", sld(30, "44")), tcell("Distance", True)), pair(tcell("Arrival time", True), cell("", ""))])
    p = card("maps", "Map pins", [pair(tcell("Available quest lines", True), tcell("Quest givers from data", True)),
                                  pair(tcell("Turn-in spots", True), tcell("Pins on the minimap", True)),
                                  pair(cell("Pin size", sld(36, "18")), tcell("Hide low-level quests", True))])
    e = card("filter", "Expansions", [pair(tcell("Midnight (Quel'Thalas)", True), tcell("The War Within (Khaz Algar)", True))])
    content = head() + tabs(QTABS, 1) + '<div class="body">' + a + p + e + '</div>'
    html = CSS + mapcard(16, 10, 210, tip=True) + arrow(150, 250, -55, 54)
    return s6.shell("content", "content", "Quests", content, preview("Live preview", fit(html, 0.62, 220), 220, tag="QUESTS"),
                    status="Phoenix_UI_Data: 952 + 1384 quests · ATT (MIT) + QuestPOI")


def p_auto():
    a = card("automation", "Quest automation", [pair(tcell("Auto-accept quests", True), tcell("Auto-turn in quests", True)),
                                                line("Choose reward", sel("Highest vendor value", 200), "With several rewards: let you pick, take the one that sells for most, or the best Sim upgrade."),
                                                pair(tcell("Quest tooltips", True), cell("", ""))])
    c = card("friends", "Community data", [line("Contribute quest positions", s6.tog(False),
                                                "Opt-in for a future update: nothing is recorded or sent yet. When the collector ships it will only note quest-giver positions, never names or chat.")])
    content = head() + tabs(QTABS, 2) + '<div class="body">' + a + c + '</div>'
    return s6.shell("content", "content", "Quests", content, stage(),
                    status="Hold Shift to do it yourself · never pays gold")


PAGES = {"s14_quests_tracker": p_tracker, "s14_quests_helper": p_helper, "s14_quests_auto": p_auto}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S14 Quests (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
