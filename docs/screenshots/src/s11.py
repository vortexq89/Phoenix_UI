#!/usr/bin/env python3
"""Group frames (2.0 S11) mockups: HTML mirroring Phoenix_UI_Options/Options/GroupFrames.lua and its Preview, drawn with
the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from Locales/enUS.lua, the
setting count from the smoke harness ("group frames depth (S11)"). Icons and textures are CSS stand-ins for the game's
art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s11.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, chips, COG, ALL, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["GroupFrames"] = (191, 68)
OUT = SRC.parent
CSS = s9.CSS + ('<style>.gf{position:absolute;background:#101216;box-shadow:0 0 0 1px #000;overflow:hidden}'
                '.gf>i{position:absolute;left:0;top:0}.gf>u{position:absolute;top:0;'
                'background:repeating-linear-gradient(45deg,rgba(255,255,255,.55) 0 2px,rgba(255,255,255,.15) 2px 5px)}'
                '.gf>s{position:absolute;top:0;background:rgba(61,220,151,.45)}'
                '.gf>b{position:absolute;left:0;right:0;bottom:0}'
                '.gf .t{position:absolute;font-family:CondSemi;color:#fff;text-shadow:1px 1px 0 #000;white-space:nowrap}'
                '.gf .r{position:absolute;width:12px;height:12px;border-radius:50%;font:9px/12px CondBold;text-align:center;color:#000}'
                '.gf .c{position:absolute;width:6px;height:6px;box-shadow:0 0 0 1px #000}'
                '.gf .st{position:absolute;left:0;right:0;text-align:center;font-family:CondBold;letter-spacing:1px}</style>')
CLASS = {"WARRIOR": "#c69b6d", "PALADIN": "#f48cba", "PRIEST": "#ffffff", "DRUID": "#ff7c0a", "MAGE": "#3fc7eb",
         "SHAMAN": "#0070dd", "ROGUE": "#fff468", "HUNTER": "#aad372", "WARLOCK": "#8788ee", "MONK": "#00ff98",
         "DEATHKNIGHT": "#c41e3a", "EVOKER": "#33937f", "DEMONHUNTER": "#a330c9"}
ROLE = {"TANK": ("#4da3ff", "T"), "HEALER": ("#3ddc97", "H"), "DAMAGER": ("#e04a3a", "D")}
DISPEL = {"Magic": "#3399ff", "Curse": "#9900ff", "Disease": "#996600", "Poison": "#009900"}
ROSTER = [("Vorte", "PALADIN", "TANK"), ("Brakka", "WARRIOR", "TANK"), ("Lunelle", "PRIEST", "HEALER"), ("Thornroot", "DRUID", "HEALER"),
          ("Sefa", "SHAMAN", "HEALER"), ("Ilyra", "MAGE", "DAMAGER"), ("Kesh", "ROGUE", "DAMAGER"), ("Marrow", "DEATHKNIGHT", "DAMAGER"),
          ("Quill", "HUNTER", "DAMAGER"), ("Nyx", "WARLOCK", "DAMAGER"), ("Tao", "MONK", "DAMAGER"), ("Ember", "EVOKER", "DAMAGER"),
          ("Vash", "DEMONHUNTER", "DAMAGER"), ("Orin", "PALADIN", "DAMAGER"), ("Rook", "WARRIOR", "DAMAGER"), ("Sable", "PRIEST", "DAMAGER"),
          ("Fenn", "DRUID", "DAMAGER"), ("Ash", "MAGE", "DAMAGER"), ("Wisp", "SHAMAN", "DAMAGER"), ("Grit", "HUNTER", "DAMAGER")]


def state_of(i):
    """The same spread of states the Test group uses (Update.lua's sample states)."""
    return {2: "dispel", 3: "hot", 5: "absorb", 6: "range", 8: "dead", 10: "offline", 11: "aggro", 13: "summon", 15: "res",
            16: "ready", 17: "phase", 18: "range"}.get(i % 20, "")


def unit(x, y, w, h, i, name=None, cls=None, role=None, power=None, big=False):
    n, c, r = ROSTER[i % len(ROSTER)]
    name, cls, role = name or n, cls or c, role or r
    st = state_of(i)
    hp = [96, 71, 44, 88, 100, 62, 81, 100, 0, 55, 100, 39, 77, 100, 92, 68, 100, 84, 58, 100][i % 20]
    col = CLASS[cls]
    op = ".4" if st == "range" else "1"
    edge = ""
    if st == "dispel":
        edge = f"box-shadow:0 0 0 1px #000,inset 0 0 0 2px {DISPEL['Magic']};"
    elif st == "aggro":
        edge = "box-shadow:0 0 0 1px #000,0 0 0 2px #ff3d00;"
    ph = 0
    if power is None:
        power = role == "HEALER" or big
    if power:
        ph = 4 if not big else 5
    hh = h - ph
    out = []
    if st == "offline":
        out.append(f'<i style="width:100%;height:{hh}px;background:#2a2c33"></i>')
    elif st != "dead":
        out.append(f'<i style="width:{hp}%;height:{hh}px;background:linear-gradient(180deg,{col},{col}99)"></i>')
    if st == "absorb":
        out.append(f'<u style="left:{hp}%;width:14%;height:{hh}px"></u>')
    if st == "hot":
        out.append(f'<s style="left:{hp}%;width:9%;height:{hh}px"></s>')
    if ph:
        pc = "#3f8cff" if role == "HEALER" else ("#c41e3a" if cls == "DEATHKNIGHT" else "#e5c72a" if cls == "ROGUE" else "#c62828")
        out.append(f'<b style="height:{ph}px;background:#000"><i style="position:absolute;left:0;top:1px;bottom:0;width:{70 if st != "dead" else 0}%;background:{pc}"></i></b>')
    fs = 11 if w >= 90 else 10
    out.append(f'<div class="t" style="left:4px;top:3px;font-size:{fs}px;color:{"#9aa0aa" if st in ("dead", "offline") else "#fff"}">{name[: 8 if w < 80 else 12]}</div>')
    if st not in ("dead", "offline") and w >= 80:
        out.append(f'<div class="t" style="right:4px;top:3px;font-size:10px;color:#c9ced8">{hp}%</div>')
    rc, rl = ROLE[role]
    if role != "DAMAGER" or w >= 90:
        out.append(f'<div class="r" style="left:{w - 15}px;top:{hh - 15}px;background:{rc}">{rl}</div>')
    label = {"dead": ("DEAD", "#e04a3a"), "offline": ("OFFLINE", "#9aa0aa"), "summon": ("SUMMON", "#c77dff"),
             "res": ("RES", "#3ddc97"), "ready": ("✓", "#3ddc97"), "phase": ("◐", "#4da3ff")}.get(st)
    if label:
        out.append(f'<div class="st" style="top:{hh // 2 - 2}px;font-size:{10 if len(label[0]) > 1 else 13}px;color:{label[1]}">{label[0]}</div>')
    if st in ("dispel", "aggro", "hot", "absorb") and w >= 70:
        out.append(f'<div class="c" style="right:3px;top:{hh - 8}px;background:#3ddc97"></div>')
        if st == "hot":
            out.append(f'<div class="c" style="right:12px;top:{hh - 8}px;background:#ffd24a"></div>')
    if st == "dispel" and w >= 70:
        out.append(s9.aura(w // 2 - 9, hh // 2 - 4, 16, 3, "", edge=DISPEL["Magic"]).replace("position:absolute", "position:absolute;z-index:2"))
    return f'<div class="gf" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;opacity:{op};{edge}">{"".join(out)}</div>'


def raid(x0, y0, n, w, h, per=5, gap=3, ggap=8, cols_down=True):
    out = []
    for i in range(n):
        g, k = divmod(i, per)
        if cols_down:
            out.append(unit(x0 + g * (w + ggap), y0 + k * (h + gap), w, h, i))
        else:
            out.append(unit(x0 + k * (w + gap), y0 + g * (h + ggap), w, h, i))
    return "".join(out)


def head():
    return page_head("groupframes", "Group Frames", "Party, raid, main tank and pet frames drawn by Phoenix from secure group headers.", "GroupFrames")


TABS = ["Layout", "Health", "Power", "Text", "Indicators", "Auras"]


def scope(on="Party (5)"):
    return (f'<div class="scope"><div class="t">{ico("groupframes", 13)}Layout<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips([("Party (5)", None), ("Raid (10-20)", None), ("Large raid (25-40)", None)], on=(on,))}</div></div>')


def stage(kind="party"):
    st = CSS
    if kind == "party":
        for i in range(5):
            st += unit(20 + i * 124, 90, 120, 50, [0, 2, 5, 6, 11][i], power=None)
    elif kind == "raid":
        st += raid(40, 22, 20, 92, 46, gap=2, ggap=6, cols_down=False)
    else:
        st += raid(12, 40, 40, 72, 36, per=5, gap=2, ggap=3)
    states = [("Party (5)", None), ("Raid (10-20)", None), ("Large raid (25-40)", None), ("Out of range", None)]
    on = {"party": "Party (5)", "raid": "Raid (10-20)", "large": "Large raid (25-40)"}[kind]
    return preview("Live preview", st, 250, states, on=(on,), tag="GROUP")


def p_layout():
    mode = card("groupframes", "Group frames", [line("Group frames", sel("Phoenix frames", 220), "Phoenix draws its own party and raid frames from secure group headers. Blizzard keeps its compact frames, styled by Phoenix."),
                                                pair(cell("Test group", f'<div class="btn">{ico("test")}Toggle test group</div>'), cell("Test group size", sel("Raid of 20", 150))),
                                                line("Layout mode", f'<div class="btn">{ico("movers")}Layout mode</div>', "Unlock the movers to drag the party, raid, main tank and pet frames.")])
    size = card("layout", "Size", [pair(cell("Width", sld(46, "92"), ALL()), cell("Height", sld(38, "46"), ALL())),
                                   pair(cell("Scale", sld(50, "1.00")), cell("Unit spacing", sld(20, "2")))])
    grow = card("grid", "Growth", [pair(cell("Unit growth", sel("Right", 140)), cell("Group growth", sel("Down", 140))),
                                   pair(cell("Group spacing", sld(30, "6")), cell("Units per column", sld(25, "5")))])
    sort = card("tracker", "Sorting", [pair(cell("Sort by", sel("Group", 140)), cell("Sort direction", sel("Ascending", 140))),
                                       pair(cell("Role order", sel("Tank, healer, damage", 170)), tcell("Show yourself", True)),
                                       pair(cell("Groups shown", sld(100, "8")), tcell("Groups 1-4 in Mythic", True))])
    extra = card("unitframes", "Main tanks and assists · Pets", [pair(tcell("Show main tank frames", True), tcell("Include main assists", True)),
                                                                pair(tcell("Show pet frames", False), cell("Position", f'<div class="btn">{ico("movers")}Mover</div>'))])
    content = head() + scope("Raid (10-20)") + tabs(TABS, 0) + '<div class="body">' + mode + size + grow + sort + extra + '</div>'
    return s6.shell("frames", "frames", "GroupFrames", content, stage("raid"), status="Raid (10-20) · 92 × 46, sorted by group")


def p_party():
    hp = card("border", "Health bar", [pair(cell("Health colour", sel("Class", 160)), tcell("Smooth bar", True)),
                                       pair(tcell("Absorb shields", True), tcell("Incoming heals", True)),
                                       line("Range fade", sld(40, "40%"), "Fade members who are out of range of your spells."),
                                       '<div class="rowl"><div class="lt"><div class="ds">Dead, offline, absorb and heal colours and the number format are shared with Unit Frames.</div></div></div>'])
    pw = card("datatexts", "Power bar by role", [pair(tcell("Tanks", False), tcell("Healers", True)), pair(tcell("Damage dealers", False), cell("Height", sld(20, "4")))])
    tx = card("fonts", "Text", [pair(cell("Name tag", sel("[name:short]", 160)), cell("Health tag", sel("[health:deficit]", 160))),
                                line("Status text", sel("[status]", 160), "Dead, offline and ghost states from the Unit Frames tag engine.", side=COG())])
    content = head() + scope("Party (5)") + tabs(TABS, 1) + '<div class="body">' + hp + pw + tx + '</div>'
    return s6.shell("frames", "frames", "GroupFrames", content, stage("party"), status="Party (5) · 120 × 50, sorted by role")


def p_indicators():
    ind = card("preview", "Indicators", [pair(tcell("Role icon", True), tcell("Hide role icon in combat", False)),
                                         pair(tcell("Leader and assist", True), tcell("Raid marker", True)),
                                         pair(tcell("Ready check", True), tcell("Summons and resurrections", True)),
                                         pair(tcell("Phase icon", True), tcell("Aggro border", True))])
    dis = card("warning", "Dispel highlight", [pair(cell("Highlight", sel("Border", 140)), tcell("Only what I can dispel", True)),
                                               pair(cell("Highlight opacity", sld(80, "80%")), cell("Colours", '<div style="display:flex;gap:6px">' + "".join(swatch(c) for c in DISPEL.values()) + '</div>'))])
    content = head() + scope("Raid (10-20)") + tabs(TABS, 4) + '<div class="body">' + ind + dis + '</div>'
    return s6.shell("frames", "frames", "GroupFrames", content, stage("raid"), status="Dispel border · aggro glow · ready check")


def p_auras():
    bu = card("auras", "Buffs", [pair(cell("Buff position", sel("Corners", 140)), cell("Filter", sel("My heals over time", 170))),
                                 pair(cell("Icon size", sld(20, "10")), cell("Max auras", sld(40, "4")))])
    de = card("auras", "Debuffs", [pair(cell("Debuff position", sel("Centre", 140)), cell("Filter", sel("Dispellable by the group", 190))),
                                   pair(cell("Icon size", sld(36, "18")), cell("Max auras", sld(30, "3")))])
    df = card("cat-combat", "Defensives", [line("Big defensive", tog(), "Shows a big defensive or external cooldown on the member.", side=COG())])
    pv = card("encounters", "Private auras", [line("Show private auras", tog(), "Boss mechanics the game keeps private, drawn by the game itself in slots on each frame."),
                                              pair(tcell("Cooldown swipe", True), tcell("Countdown numbers", False)),
                                              '<div class="rowl"><div class="lt"><div class="ds">Aura rows ask the game with filter words (my heals, raid, dispellable, crowd control, big defensive); aura data itself is never read, so it works in restricted content.</div></div></div>'])
    content = head() + scope("Raid (10-20)") + tabs(TABS, 5) + '<div class="body">' + bu + de + df + pv + '</div>'
    return s6.shell("frames", "frames", "GroupFrames", content, stage("large"), status="Large raid (25-40) · 72 × 36")


def world():
    body = CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
    body += raid(40, 300, 40, 72, 36, per=5, gap=2, ggap=3)
    body += '<div class="t" style="position:absolute;left:40px;top:278px;font-family:CondBold;color:#ff6a1a;letter-spacing:1px">TEST GROUP · RAID OF 40</div>'
    for i in range(5):
        body += unit(1000 + (i % 1) * 0, 300 + i * 54, 120, 50, [0, 2, 5, 6, 11][i])
    body += '<div class="t" style="position:absolute;left:1000px;top:278px;font-family:CondBold;color:#ff6a1a;letter-spacing:1px">PARTY OF 5</div>'
    for i in range(2):
        body += unit(1180, 300 + i * 44, 110, 40, i, role="TANK", big=True)
    body += '<div class="t" style="position:absolute;left:1180px;top:278px;font-family:CondBold;color:#ff6a1a;letter-spacing:1px">MAIN TANKS</div>'
    body += ('<div style="position:absolute;left:300px;top:60px;width:820px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
             'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">TEST GROUP</b><br>Fake groups of 5, 20 or 40 '
             'where the frames sit: class colours, role icons, a Magic dispel highlight, heals over time, absorbs, an aggro glow, out-of-range fade, dead and offline members, '
             'a pending summon, a resurrection, a ready check and a phased member. Combat ends the test.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S11 group frames with the Test group (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s11_layout": p_layout, "s11_party": p_party, "s11_indicators": p_indicators, "s11_auras": p_auras, "s11_test": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S11 group frames (HTML)"), encoding="utf-8")
        w = 1440 if name == "s11_test" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
