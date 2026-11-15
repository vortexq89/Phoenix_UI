#!/usr/bin/env python3
"""Remaining modules (2.0 S16) mockups: HTML mirroring the S16 option pages, drawn with the S6 shell (s6.py helpers and
s6.css), rendered to PNG with headless Chrome. Rows, headers and labels come from the smoke harness label dump
(PUI_LABELS_OUT=labels.tsv lua5.1 tools/smoke/harness.lua . retail), counts and targets from Config:Depth; values
are sample values. Previews are CSS stand-ins for game art; mockups, not screenshots.
Usage (repo root): python3 docs/screenshots/src/s16.py labels.tsv [outdir]"""
import collections
import html as H
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import card, pair, cell, tcell, sel, sld, swatch, COG, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402
import s15  # noqa: E402,F401  (adds Group Finder to the Content group)

OUT = SRC.parent
# (now, target) after S16: Config:Depth on the smoke harness (retail), targets from GAP_MATRIX.md without link/api rows
s6.DEPTH.update({"ActionBars": (117, 112), "CooldownText": (15, 12), "Tracker": (92, 59), "UnitFrames": (205, 150),
                 "GroupFrames": (194, 67), "NamePlates": (276, 100), "CastBars": (103, 55), "Auras": (64, 41),
                 "CombatText": (30, 26), "DamageMeter": (24, 24), "SpellHistory": (13, 12), "Chat": (59, 51),
                 "Minimap": (48, 41), "Tooltip": (55, 45), "Bags": (55, 42), "ItemLevel": (19, 19), "DataTexts": (68, 47),
                 "Skins": (35, 28), "General": (31, 21), "profiles": (15, 8), "Movers": (17, 11), "Quality": (22, 11),
                 "Automation": (15, 13), "AFK": (12, 4), "Bugs": (12, 12), "Quests": (38, 27), "GroupFinder": (58, 13),
                 "MythicPlus": (34, 31), "Encounters": (64, 63), "PvP": (10, 4), "Sim": (11, 8), "diagnostics": (9, 3)})
# Groups.lua after the S16 consistency pass: Cooldown Text beside Action Bars, Content sub-headings
for g in s6.GROUPS:
    if g[0] == "bars":
        g[3].sort(key=lambda e: ["ActionBars", "CooldownText", "Tracker"].index(e[0]))
    if g[0] == "content":
        by = {e[0]: e for e in g[3] if isinstance(e, tuple)}
        quests = by.get("Quests", ("Quests", "Quests", "quests", True))
        g[3][:] = [{"h": "Questing & groups"}, quests, by["GroupFinder"], {"h": "Dungeons, raids & PvP"}, by["MythicPlus"],
                   by["Encounters"], by["PvP"], {"h": "Gear"}, by["Sim"]]

CSS = s9.CSS + ('<style>.mk{position:absolute;display:flex;gap:4px;padding:4px;background:#121419;box-shadow:0 0 0 1px #000}'
                '.mk b{width:20px;height:20px;border-radius:3px;box-shadow:0 0 0 1px #000;display:block}'
                '.dm{position:absolute;background:rgba(14,15,19,.92);box-shadow:0 0 0 1px #2a2e36}'
                '.dm .h{height:22px;background:#1d2027;border-bottom:1px solid #ff3d00;font-family:CondBold;font-size:12px;color:#e6e9ef;padding:3px 8px}'
                '.dm .b{position:relative;height:18px;margin:3px 6px;background:#16181d}.dm .b i{position:absolute;left:0;top:0;bottom:0}'
                '.dm .b span{position:absolute;left:6px;top:2px;font-family:CondSemi;font-size:11px;color:#fff;text-shadow:0 1px 1px #000}'
                '.dm .b em{position:absolute;right:6px;top:2px;font-style:normal;font-family:CondBold;font-size:11px;color:#fff}'
                '.ft{position:absolute;font-family:CondBold;text-shadow:0 1px 2px #000}'
                '.mv{position:absolute;box-shadow:0 0 0 1px #ff3d00;background:rgba(255,61,0,.16);font-family:CondSemi;font-size:11px;color:#fff;'
                'display:flex;align-items:center;justify-content:center}'
                '.grid{position:absolute;inset:0;background-image:linear-gradient(rgba(255,255,255,.05) 1px,transparent 1px),'
                'linear-gradient(90deg,rgba(255,255,255,.05) 1px,transparent 1px);background-size:32px 32px}'
                '.cc{position:absolute;display:grid;grid-template-columns:repeat(7,1fr);gap:6px}'
                '.cc div{font-family:CondSemi;font-size:11px;padding:4px 6px;background:#16181d;box-shadow:0 0 0 1px #000}'
                '.link{display:inline-flex;align-items:center;gap:4px;padding:2px 8px;background:#1d2027;box-shadow:0 0 0 1px #2a2e36;'
                'font-family:CondSemi;font-size:11px;color:#ff6a1a}</style>')


def load(path):
    rows = collections.defaultdict(list)
    for ln in open(path, encoding="utf-8"):
        p = ln.rstrip("\n").split("\t")
        if len(p) >= 4:
            rows[p[0]].append((p[1], p[2], p[3].split(":", 1)[0]))
    return rows


def ctl(label, kind):
    label = H.escape(label)
    if kind == "toggle":
        return tcell(label, True)
    if kind == "range":
        return cell(label, sld(45, "45"))
    if kind in ("select", "style", "font", "texture", "sound"):
        return cell(label, sel("Phoenix" if kind in ("font", "texture", "style") else "Default", 140), COG() if kind == "style" else "")
    if kind == "color":
        return cell(label, swatch("#ff3d00"))
    if kind == "colors":
        return cell(label, swatch("#ff3d00") + swatch("#3ddc97") + swatch("#3fc7eb"))
    if kind == "button":
        return cell(label, '<span class="link">Open ›</span>')
    if kind == "input":
        return cell(label, sel("", 140))
    return cell(label, "")


def cards(rows, heads, icon):
    by = collections.OrderedDict()
    for head, label, kind in rows:
        if " > " in label or not label:
            continue  # behind a cog
        by.setdefault(head or "Settings", []).append(ctl(label, kind))
    out = ""
    for head, cells in by.items():
        if heads and head not in heads:
            continue
        pairs = [pair(cells[i], cells[i + 1] if i + 1 < len(cells) else cell("", "")) for i in range(0, len(cells), 2)]
        out += card(icon, H.escape(head), pairs[:5])
    return out


def fit(html, scale, h):
    return f'<div style="position:absolute;left:0;top:0;width:{int(100 / scale)}%;height:{int(h / scale)}px;transform:scale({scale});transform-origin:0 0">{html}</div>'


MARKS = ["#ffd200", "#ff7c0a", "#a335ee", "#3ddc97", "#c7cbd3", "#3fc7eb", "#ff3d3d", "#ffffff", "#2a2e36"]


def stage_quality():
    bar = "".join(f'<div style="position:absolute;left:{20 + i * 24}px;top:20px;width:20px;height:20px;border-radius:3px;'
                  f'background:{c};box-shadow:0 0 0 1px #000"></div>' for i, c in enumerate(MARKS))
    ring = '<div style="position:absolute;left:150px;top:70px;width:40px;height:40px;border-radius:50%;box-shadow:0 0 0 3px #ff3d00,0 0 10px #ff3d00"></div>'
    alert = '<div class="ft" style="left:20px;top:80px;font-size:20px;color:#ff6a1a;letter-spacing:.08em">+ COMBAT</div>'
    return preview("Live preview", CSS + bar + ring + alert, 180, tag="QUALITY OF LIFE")


def stage_dm():
    bars = [("Vortexq", 92, "#c69b6d", "1.42M"), ("Aeriel", 81, "#3fc7eb", "1.25M"), ("Thalor", 66, "#aad372", "1.02M"), ("Mirae", 52, "#f48cba", "804K")]
    o = '<div class="dm" style="left:20px;top:14px;width:300px;height:118px"><div class="h">Damage Done</div>'
    for n, w, c, v in bars:
        o += f'<div class="b"><i style="width:{w}%;background:linear-gradient(180deg,{c},{c}aa)"></i><span>{n}</span><em>{v}</em></div>'
    return preview("Live preview", fit(CSS + o + '</div>', 0.48, 180), 180, tag="DAMAGE METER")


def stage_ct():
    o = ''.join(f'<div class="ft" style="left:{x}px;top:{y}px;font-size:{s}px;color:{c};opacity:{a}">{t}</div>' for x, y, s, c, a, t in [
        (60, 120, 16, "#ff4d40", 1, "-12,480"), (80, 84, 16, "#ff4d40", .8, "-8,112 ×3"), (60, 46, 22, "#ff4d40", .55, "-31,904"),
        (420, 120, 16, "#4dff59", 1, "+18,200"), (240, 30, 14, "#ffd966", 1, "+Bloodlust"), (240, 64, 14, "#b3b3b3", .8, "Dodge")])
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="SCROLL AREAS")


def stage_movers():
    o = '<div class="grid"></div>' + ''.join(f'<div class="mv" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px">{t}</div>' for x, y, w, h, t in [
        (40, 20, 220, 30, "Zone text"), (40, 54, 220, 22, "Error messages"), (300, 20, 160, 60, "Boss banner"), (300, 90, 160, 40, "Alerts")])
    o += '<div class="ft" style="left:300px;top:136px;font-size:11px;color:#e6e9ef">x 312  y -80</div>'
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="MOVERS")


CLASSES = [("Warrior", "#c69b6d"), ("Paladin", "#f48cba"), ("Hunter", "#aad372"), ("Rogue", "#fff468"), ("Priest", "#ffffff"),
           ("Death Knight", "#c41e3a"), ("Shaman", "#0070dd"), ("Mage", "#3fc7eb"), ("Warlock", "#8788ee"), ("Monk", "#00ff98"),
           ("Druid", "#ff7c0a"), ("Demon Hunter", "#a330c9"), ("Evoker", "#33937f")]


def stage_general():
    o = '<div class="cc" style="left:20px;top:20px;right:20px">' + "".join(f'<div style="color:{c}">{n}</div>' for n, c in CLASSES) + '</div>'
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="THEME")


def page(rows, key, title, icon, desc, heads, stage, rail, status, tabset=None):
    content = page_head(icon, title, desc, key) + (tabs(tabset, 0) if tabset else "") + '<div class="body">' + cards(rows.get(key, []), heads, icon) + '</div>'
    return s6.shell(rail, rail, key, content, stage, status=status)


def build(rows):
    return {
        "s16_quality": page(rows, "Quality", "Quality of Life", "quality",
                            "Small fixes for the default UI: hidden banners, a raid markers bar, cursor ring, combat alerts and safe game options.",
                            None, stage_quality(), "phoenix", "Game settings are set out of combat · one owner page per setting",
                            ["Interface", "Game"]),
        "s16_automation": page(rows, "Automation", "Automation", "automation",
                               "Repair, sell junk, faster loot, invites, duels and dialogs – automatically.", None,
                               preview("Live preview", CSS + '<div class="ft" style="left:20px;top:60px;font-size:13px;color:#8a93a3">'
                                       'Automation has no visual: each switch acts on a game event · Shift pauses gossip</div>', 180, tag="AUTOMATION"),
                               "phoenix", "Links: quests → Quests · role checks → Group Finder"),
        "s16_damagemeter": page(rows, "DamageMeter", "Damage Meter", "damagemeter",
                                "Phoenix skin for Blizzard's damage meter, plus an optional Details! style.", None, stage_dm(), "combat",
                                "Bar size, class colours and the second window stay in Edit Mode (linked)"),
        "s16_combattext": page(rows, "CombatText", "Combat Text", "combattext",
                               "The game's floating combat text options, plus Phoenix scroll areas for what hits you and your target.",
                               None, stage_ct(), "combat", "Amounts may be secret: shown, never read", ["Blizzard", "Phoenix scroll areas"]),
        "s16_movers": page(rows, "Movers", "Movers", "movers",
                           "Move, scale and fade the Blizzard frames Edit Mode cannot reach, like zone text, alerts and the boss banner.",
                           None, stage_movers(), "phoenix", "Out of combat only · Edit Mode frames are never touched"),
        "s16_general": page(rows, "General", "General", "general", "Theme, fonts and textures shared by every module.",
                            None, stage_general(), "phoenix", "Class colour overrides apply to every page"),
    }


if __name__ == "__main__":
    labels = sys.argv[1]
    dest = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, doc in build(load(labels)).items():
        html = SRC / f"{name}.html"
        doc = doc.replace("Search %d settings" % s6.SEARCH_N, "Search settings")
        html.write_text(doc.replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S16 remaining modules (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
