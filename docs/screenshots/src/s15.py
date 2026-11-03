#!/usr/bin/env python3
"""Group Finder (2.0 S15) mockups: HTML mirroring Phoenix_UI_Options/Options/GroupFinder.lua, Previews/GroupFinder.lua
and Modules/GroupFinder/Panel.lua, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless
Chrome. Labels come from Locales/enUS.lua, the setting count from the smoke harness ("group finder depth (S15)").
The group list, panel and Group Finder window are CSS stand-ins for the game's art; mockups, not screenshots.
Usage (repo root): python3 docs/screenshots/src/s15.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, sel, sld, COG, preview, page_head, tabs, chips  # noqa: E402
import s9  # noqa: E402
import s14  # noqa: E402,F401  (adds Quests to the Content group)

s6.DEPTH["GroupFinder"] = (57, 14)
for g in s6.GROUPS:
    if g[0] == "content" and not any(isinstance(e, tuple) and e[0] == "GroupFinder" for e in g[3]):
        g[3].insert(1, ("GroupFinder", "Group Finder", "search", True))
OUT = SRC.parent
CSS = s9.CSS + ('<style>.gl{position:absolute;background:#121419;box-shadow:0 0 0 1px #000}'
                '.ge{position:absolute;height:44px;background:#1a1d24;box-shadow:0 0 0 1px #000}'
                '.ge.m{box-shadow:0 0 0 1px #ff3d00,0 0 6px rgba(255,61,0,.55)}.ge.d{opacity:.3}'
                '.gn{position:absolute;left:10px;top:6px;font-family:CondBold;font-size:13px;color:#e6e9ef;white-space:nowrap}'
                '.ga{position:absolute;left:10px;top:24px;font-family:Roboto;font-size:11px;color:#8a93a3;white-space:nowrap}'
                '.gs{position:absolute;right:90px;top:20px;font-family:CondBold;font-size:13px}.gk{position:absolute;right:90px;top:5px;font-family:CondSemi;font-size:11px;color:#e6e9ef}'
                '.gr{position:absolute;right:8px;top:6px;display:flex;gap:2px}.gr i{width:14px;height:14px;border-radius:50%;box-shadow:0 0 0 1px #000;background:#2a2e36}'
                '.gb{position:absolute;right:8px;top:24px;display:flex;gap:2px}.gb i{width:14px;height:3px}'
                '.gp{position:absolute;background:rgba(14,15,19,.94);box-shadow:0 0 0 1px #ff3d00,0 0 10px rgba(255,61,0,.35);padding:10px;'
                'font-family:Roboto;font-size:11px;color:#c7cbd3}.gp h4{margin:0 0 8px;font-family:CondBold;font-size:14px;color:#ff6a1a;letter-spacing:.04em}'
                '.gp .l{font-family:CondSemi;font-size:10px;color:#8a93a3;letter-spacing:.06em;margin:8px 0 4px}'
                '.gp .ch{display:flex;flex-wrap:wrap;gap:4px}.gp .ch span{padding:2px 6px;background:#1d2027;box-shadow:0 0 0 1px #2a2e36;font-size:10px}'
                '.gp .ch span.on{background:#3a1a0d;box-shadow:0 0 0 1px #ff3d00;color:#fff}'
                '.gp .sl{height:4px;background:#2a2e36;position:relative;margin:4px 0 2px}.gp .sl i{position:absolute;left:0;top:0;bottom:0;background:#ff3d00}'
                '.gp .ex{background:#0b0c0f;box-shadow:0 0 0 1px #2a2e36;padding:4px 6px;font-family:monospace;font-size:10px;color:#e6e9ef}'
                '.gp .mr{display:flex;justify-content:space-between;padding:3px 4px;border-bottom:1px solid #1d2027}'
                '.gtip{position:absolute;background:#121419;box-shadow:0 0 0 1px #2a2e36;padding:8px 10px;font-family:Roboto;font-size:11px;color:#e6e9ef;width:220px;line-height:1.5}'
                '.pve{position:absolute;background:#1b1712;box-shadow:0 0 0 1px #000,0 0 0 3px #3b2f22;overflow:hidden}'
                '.pve .t{position:absolute;left:0;right:0;top:0;height:26px;background:#2a2219;font-family:CondBold;font-size:13px;color:#ffd200;text-align:center;line-height:26px}</style>')

CLS = {"WARRIOR": "#c69b6d", "MAGE": "#3fc7eb", "ROGUE": "#fff468", "PALADIN": "#f48cba", "PRIEST": "#ffffff", "DRUID": "#ff7c0a",
       "HUNTER": "#aad372", "SHAMAN": "#0070dd", "DEATHKNIGHT": "#c41e3a", "EVOKER": "#33937f", "WARLOCK": "#8788ee"}
GROUPS = [("Weekly push, chill", "Magisters' Terrace (Mythic Keystone)", 2850, "+14", "#a335ee", ["WARRIOR", "MAGE", "ROGUE"], "m"),
          ("Timing for the vault", "Magisters' Terrace (Mythic Keystone)", 1650, "+8", "#0070dd", ["PALADIN", "PRIEST", "DRUID", "HUNTER"], "d"),
          ("Need heal + dps, voice", "Windrunner Spire (Mythic Keystone)", 3200, "+17", "#ff8000", ["SHAMAN", "DEATHKNIGHT"], "m"),
          ("LF tank, no leavers", "Windrunner Spire (Mythic Keystone)", 2400, "+12", "#a335ee", ["EVOKER", "WARLOCK", "MAGE", "PRIEST"], "d"),
          ("Heroic fresh-ish, 3/8", "The Voidspire (Heroic)", 0, "", "#fff", [], "")]


def fit(html, scale, h):
    return f'<div style="position:absolute;left:0;top:0;width:{int(100 / scale)}%;height:{int(h / scale)}px;transform:scale({scale});transform-origin:0 0">{html}</div>'


def entries(x, y, w, n=5):
    o = ""
    for i, (name, act, score, key, col, classes, state) in enumerate(GROUPS[:n]):
        o += f'<div class="ge {state}" style="left:{x}px;top:{y + i * 50}px;width:{w}px"><div class="gn">{name}</div><div class="ga">{act}</div>'
        if score:
            o += f'<div class="gk">{key}</div><div class="gs" style="color:{col}">{score}</div>'
        o += '<div class="gr">' + "".join('<i></i>' for _ in range(5 if score else 3)) + '</div>'
        o += '<div class="gb">' + "".join(f'<i style="background:{CLS[c]}"></i>' for c in classes) + '</div></div>'
    return o


def panel(x, y, w=250, rows=True):
    o = f'<div class="gp" style="left:{x}px;top:{y}px;width:{w}px"><h4>PHOENIX FILTERS <span style="float:right;color:#e6e9ef;font-size:12px">2 / 5</span></h4>'
    o += '<div class="l">PRESET</div><div class="ex" style="font-family:Roboto">Push score (2500+, Bloodlust, recent)</div>'
    o += '<div class="l">GAME FILTERS</div><div class="ch"><span>Normal</span><span>Heroic</span><span>Mythic</span><span class="on">Mythic+</span></div>'
    o += '<div class="l">FREE SPOT FOR</div><div class="ch"><span>Tank</span><span class="on">Healer</span><span>Damage</span><span class="on">Bloodlust</span><span>Battle res</span></div>'
    o += '<div class="l">LEADER SCORE 2500</div><div class="sl"><i style="width:62%"></i></div>'
    o += '<div class="l">LISTED FOR AT MOST 30 MIN</div><div class="sl"><i style="width:17%"></i></div>'
    o += '<div class="l">FILTER EXPRESSION</div><div class="ex">healfree &gt; 0 and age &lt; 30</div><div style="color:#3ddc97;margin-top:3px">2 groups match</div>'
    if rows:
        o += '<div class="l">BEST MATCHES · LEADER SCORE ↓</div>'
        o += '<div class="mr"><span>WS</span><span style="color:#ff8000">3200</span><span>+17 2/5</span></div>'
        o += '<div class="mr"><span>MT</span><span style="color:#a335ee">2850</span><span>+14 3/5</span></div>'
    return o + '</div>'


def stage():
    html = CSS + f'<div class="gl" style="left:10px;top:10px;width:380px;height:262px"></div>' + entries(16, 16, 368, 5) + panel(400, 10, 200, rows=False)
    return preview("Live preview", fit(html, 0.6, 220), 220, tag="GROUP FINDER")


def head():
    return page_head("search", "Group Finder", "Filters, sorting, highlights and sign-up helpers for the premade group list, and applicant details for leaders.", "GroupFinder")


TABS = ["Filters", "Helpers"]


def p_filters():
    p = card("search", "Filter panel", [pair(tcell("Show the filter panel", True), cell("Preset", sel("Push score", 150))),
                                        pair(cell("Panel background", sel("Theme 94%", 140), COG()), cell("Panel border", sel("Ember", 140), COG()))])
    g = card("filter", "Game filters", [line("Difficulty", chips([("Normal", None), ("Heroic", None), ("Mythic", None), ("Mythic+", None)], on=("Mythic+",)),
                                             "The game's own dungeon filters: groups that fail them are removed from the list by the game."),
                                        pair(tcell("Needs my role", False), cell("Minimum leader rating", sld(0, "0")))])
    f = card("friends", "Phoenix filters", [pair(tcell("Free healer place", True), tcell("Has Bloodlust", True)),
                                            pair(cell("Minimum leader score", sld(62, "2500")), cell("Listed for at most (minutes)", sld(17, "30"))),
                                            pair(cell("Leader's best key: at least", sld(0, "any")), cell("Leader's best key: at most", sld(0, "any"))),
                                            pair(cell("Raid bosses defeated", sel("Any", 120)), cell("Voice chat", sel("Any", 120))),
                                            line("Filter expression", '<div class="sel" style="--w:260px"><span style="font-family:monospace">healfree &gt; 0 and age &lt; 30</span></div>',
                                                 "Advanced: combine words with and, or, not, comparisons and + - * /.")])
    r = card("tracker", "Results", [pair(cell("Groups that don't match", sel("Dim them", 140)), cell("Dimmed opacity", sld(30, "30%"))),
                                    pair(tcell("Outline matches", True), cell("Sort matches by", sel("Leader score", 140)))])
    content = head() + tabs(TABS, 0) + '<div class="body">' + p + g + f + r + '</div>'
    return s6.shell("content", "content", "GroupFinder", content, stage(), status="Dims, never removes: Blizzard's list stays untainted", reload=True)


def p_helpers():
    s = card("automation", "Sign up", [pair(tcell("Click a selected group again to sign up", True), tcell("Enter signs up", False)),
                                       line("Accept role checks with a key", sel("Space", 120),
                                            "While a role check is shown, this key presses Accept. Phoenix never accepts a role check or signs you up without your input.")])
    li = card("tracker", "Group list", [pair(tcell("Leader score and best key", True), tcell("Class-colour strip", True)),
                                        pair(tcell("Details in the group tooltip", True), tcell("Raid lockout hint", True)),
                                        pair(tcell("Ember style in the list", True), tcell("Phoenix look for the Group Finder window", True, side='<span class="chip">Skins</span>'))])
    a = card("friends", "Applicants (your group)", [pair(tcell("Best key in your dungeon", True), tcell("Spec icons", True)),
                                                    pair(cell("Highlight applicants from score", sld(75, "3000")), cell("", ""))])
    content = head() + tabs(TABS, 1) + '<div class="body">' + s + li + a + '</div>'
    html = CSS + entries(16, 16, 368, 3) + (
        '<div class="gtip" style="left:120px;top:70px"><div style="font-family:CondBold;color:#ffd200">Magisters\' Terrace (Mythic Keystone)</div>'
        '<div style="color:#f48cba">Tank  Paladin</div><div style="color:#ffffff">Healer  Priest</div><div>Leader score <b style="color:#0070dd">1650</b></div>'
        '<div>Leader\'s best key here <b>+8</b> <span style="color:#8a93a3">(untimed)</span></div><div style="color:#ff6a1a">Phoenix filter: declined you before</div></div>')
    return s6.shell("content", "content", "GroupFinder", content, preview("Live preview", fit(html, 0.6, 220), 220, tag="GROUP FINDER"),
                    status="Every sign-up starts from your click or key · out of combat")


def p_ingame():
    html = ('<div class="world"></div>' + CSS + '<div class="pve" style="left:150px;top:90px;width:560px;height:620px"><div class="t">Premade Groups — Dungeons</div></div>'
            + entries(170, 140, 520, 5)
            + '<div style="position:absolute;left:170px;top:400px;font-family:CondBold;font-size:12px;color:#ff6a1a">Click again to sign up</div>'
            + panel(722, 90, 270)
            + '<div class="gtip" style="left:400px;top:450px"><div style="font-family:CondBold;color:#ffd200">Windrunner Spire (Mythic Keystone)</div>'
              '<div style="color:#0070dd">Tank  Shaman</div><div style="color:#c41e3a">Damage  Death Knight  (leader)</div>'
              '<div>Leader score <b style="color:#ff8000">3200</b> · best key here <b>+17</b></div><div style="color:#3ddc97">Bloodlust · Battle res</div></div>')
    return ('<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1360px;--bh:880px">'
            + html + '<div class="cap">Mockup of Phoenix UI 2.0 S15 Group Finder in game (HTML) · CSS stand-ins for the Group Finder window</div></body></html>')


PAGES = {"s15_groupfinder_filters": p_filters, "s15_groupfinder_helpers": p_helpers, "s15_groupfinder_ingame": p_ingame}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S15 Group Finder (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
