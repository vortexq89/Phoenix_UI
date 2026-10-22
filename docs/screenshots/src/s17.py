#!/usr/bin/env python3
"""NPC locations + gap rows (2.0 S17) mockups: HTML mirroring the S17 option pages, drawn with the S6 shell (s6.py
helpers and s6.css) through the S16 page builder, rendered to PNG with headless Chrome. Rows, headers and labels
come from the smoke harness label dump (PUI_LABELS_OUT=labels.tsv lua5.1 tools/smoke/harness.lua . retail), counts
from PUI_DEPTH_OUT and targets from Config.DEPTH; values are sample values. Previews are CSS stand-ins for game art;
mockups, not screenshots.
Usage (repo root): python3 docs/screenshots/src/s17.py labels.tsv [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import preview  # noqa: E402
import s16  # noqa: E402
from s16 import CSS, fit, load, page  # noqa: E402

OUT = SRC.parent
# (now, target) after S17 on retail: PUI_DEPTH_OUT now, Config.DEPTH targets (unchanged since S16)
s6.DEPTH.update({"Tracker": (93, 59), "UnitFrames": (209, 150), "Chat": (61, 51), "Minimap": (49, 41), "Tooltip": (58, 45),
                 "Bags": (56, 42), "ItemLevel": (20, 19), "DataTexts": (77, 47), "Skins": (36, 28), "General": (52, 21),
                 "Quests": (43, 27)})

PINS = [(90, 60, "#ffd200", "vendor"), (150, 96, "#3fc7eb", "trainer"), (220, 70, "#3ddc97", "flight"),
        (300, 120, "#ff3d3d", "rare"), (120, 140, "#ff6a1a", "giver"), (360, 54, "#ffd200", "vendor")]


def stage_npcs():
    o = '<div style="position:absolute;inset:0;background:radial-gradient(circle at 40% 50%,#2b3a2e,#141a16 70%)"></div>'
    o += "".join(f'<div style="position:absolute;left:{x}px;top:{y}px;width:16px;height:16px;border-radius:50%;background:#121419;'
                 f'box-shadow:0 0 0 2px {c},0 0 8px {c}"></div>' for x, y, c, _ in PINS)
    o += ('<div class="dm" style="left:430px;top:16px;width:230px;height:120px"><div class="h">Search NPCs: smith</div>'
          '<div class="b"><span>Armorer Hollis · Silvermoon 48.2, 61.0</span></div>'
          '<div class="b"><span>Blacksmith Jorra · Eversong 39.7, 55.4</span></div>'
          '<div class="b"><span>Smith Aldren · Dornogal 51.1, 72.9</span></div></div>')
    o += '<div class="ft" style="left:20px;top:168px;font-size:12px;color:#e6e9ef">/way 48.2 61.0 · giver at Silvermoon 48.2, 61.0</div>'
    return preview("Live preview", fit(CSS + o, 0.48, 200), 200, tag="NPC LOCATIONS")


def stage_tooltip():
    o = ('<div class="dm" style="left:20px;top:14px;width:300px;height:150px"><div class="h" style="color:#a335ee">'
         'Mythic Keystone</div>'
         '<div class="ft" style="left:10px;top:30px;font-size:12px;color:#e6e9ef">Ara-Kara +12 · Tyrannical, Bolstering</div>'
         '<div class="ft" style="left:10px;top:52px;font-size:12px;color:#ffd200">Timer 33:00 · season best +14 in 30:00</div>'
         '<div class="ft" style="left:10px;top:74px;font-size:12px;color:#3ddc97">Collected</div>'
         '<div class="ft" style="left:10px;top:96px;font-size:12px;color:#c7cbd3">Sell price 12g 34s 50c</div></div>')
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="TOOLTIP")


POWERS = ["#0070dd", "#ff0000", "#ff8040", "#ffff00", "#00d1ff", "#4d85e6", "#0080ff", "#9900ff", "#c942fd", "#ff9c00"]
DISPELS = [("Magic", "#3399ff"), ("Curse", "#9900ff"), ("Disease", "#996600"), ("Poison", "#009900"), ("Bleed", "#cc0000")]


def stage_colours():
    o = "".join(f'<div style="position:absolute;left:{20 + i * 34}px;top:30px;width:28px;height:28px;border-radius:3px;background:{c};'
                f'box-shadow:0 0 0 1px #000"></div>' for i, c in enumerate(POWERS))
    o += "".join(f'<div class="ft" style="left:{20 + i * 70}px;top:90px;font-size:12px;color:{c}">{n}</div>' for i, (n, c) in enumerate(DISPELS))
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="POWER AND DISPEL COLOURS")


def stage_interface():
    stats = "".join(f'<div style="height:16px;margin:0 6px;background:{"#1d2027" if i % 2 else "transparent"}">'
                    f'<span style="font-family:CondSemi;font-size:11px;color:#8a93a3">{n}</span>'
                    f'<em style="float:right;font-style:normal;font-family:CondBold;font-size:11px;color:#e6e9ef">{v}</em></div>'
                    for i, (n, v) in enumerate([("Critical Strike", "24%"), ("Haste", "18%"), ("Mastery", "41%"), ("Versatility", "9%")]))
    o = f'<div class="dm" style="left:20px;top:14px;width:200px;height:96px"><div class="h">Enhancements</div>{stats}</div>'
    o += ('<div class="dm" style="left:250px;top:14px;width:260px;height:56px"><div class="h">Achievement earned</div>'
          '<div class="ft" style="left:10px;top:30px;font-size:12px;color:#ffd200">Phoenix Rising · 10 points</div></div>')
    o += "".join(f'<div style="position:absolute;left:{540 + i * 22}px;top:20px;width:18px;height:18px;background:#5a4a3a;'
                 f'box-shadow:0 0 0 1px #000;opacity:{1 if i == 1 else .35}"></div>' for i in range(5))
    o += '<div class="ft" style="left:540px;top:46px;font-size:11px;color:#8a93a3">bag bar · hover dims others</div>'
    return preview("Live preview", fit(CSS + o, 0.48, 180), 180, tag="STATS · TOASTS · BAG BAR")


def build(rows):
    return {
        "s17_quests_npcs": page(rows, "Quests", "Quests", "maps", "Objective tracker, waypoint arrow, quest and NPC pins, and NPC search.",
                                ["NPC locations", "Map pins", "NPC position recording"], stage_npcs(), "content",
                                "NPC data: AllTheThings (MIT) · your own recordings stay in your SavedVariables",
                                ["Tracker", "Map", "Automation"]),
        "s17_tooltip": page(rows, "Tooltip", "Tooltip", "tooltip", "Dark style, class and quality borders and extra lines.",
                            ["Extra lines"], stage_tooltip(), "interface", "Keystone details are retail-only"),
        "s17_general_colours": page(rows, "General", "General", "general", "Theme, fonts and textures shared by every module.",
                                    ["Power colours"], stage_colours(), "phoenix", "Cleared colour = the game's own"),
        "s17_interface": page(rows, "Skins", "Skins", "skins", "Phoenix styling for Blizzard windows, dialogs and toasts.",
                              ["Dialogs"], stage_interface(), "interface", "Alerts, stats panel and bag bar: art faded, nothing moved"),
    }


if __name__ == "__main__":
    labels = sys.argv[1]
    dest = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, doc in build(load(labels)).items():
        html = SRC / f"{name}.html"
        doc = doc.replace("Search %d settings" % s6.SEARCH_N, "Search settings")
        html.write_text(doc.replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S17 NPC locations and gap rows (HTML)"),
                        encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
