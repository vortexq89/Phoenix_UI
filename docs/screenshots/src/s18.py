#!/usr/bin/env python3
"""Unit Frames II + arena, resource bars and totems (2.0 S18) mockups: HTML mirroring the S18 option pages, drawn with
the S6 shell (s6.py helpers and s6.css) through the S16 page builder, rendered to PNG with headless Chrome. Rows,
headers and labels come from the smoke harness label dump (PUI_LABELS_OUT=labels.tsv lua5.1 tools/smoke/harness.lua .),
counts from PUI_DEPTH_OUT and targets from Config.DEPTH; values are sample values. Previews are CSS stand-ins for game
art; mockups, not screenshots.
Usage (repo root): python3 docs/screenshots/src/s18.py labels.tsv [outdir]"""
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
# (now, target) after S18 on retail: PUI_DEPTH_OUT now, Config.DEPTH targets raised to the S18 counts
s6.DEPTH.update({"UnitFrames": (359, 359), "CastBars": (105, 105), "PvP": (18, 18)})

FOES = [("Arms", "#c69b6d", 0.82, "#ff3d3d", "Kidney Shot"), ("Frost", "#3fc7eb", 0.46, None, None),
        ("Discipline", "#ffffff", 0.67, "#3ddc97", "Pain Suppression")]


def foe(i, spec, colour, hp, glow, aura):
    top = 14 + i * 58
    o = (f'<div style="position:absolute;left:150px;top:{top}px;width:200px;height:40px;background:#121419;box-shadow:0 0 0 1px #000">'
         f'<div style="position:absolute;left:0;top:0;width:{int(hp * 200)}px;height:33px;background:{colour}"></div>'
         f'<div style="position:absolute;left:0;top:34px;width:{int(hp * 170)}px;height:6px;background:#0070dd"></div>'
         f'<div class="ft" style="left:6px;top:9px;font-size:12px;color:#fff;text-shadow:0 0 2px #000">Enemy {i + 1}</div>'
         f'<div class="ft" style="right:6px;top:9px;font-size:12px;color:#fff;text-shadow:0 0 2px #000">{int(hp * 100)}%</div></div>')
    o += (f'<div class="ft" style="left:150px;top:{top + 42}px;font-size:10px;color:#8a93a3">{spec}</div>')
    edge = f'box-shadow:0 0 0 2px {glow},0 0 8px {glow}' if glow else 'box-shadow:0 0 0 1px #000'
    o += (f'<div style="position:absolute;left:354px;top:{top}px;width:40px;height:40px;background:{colour};opacity:.85;{edge}"></div>')
    if aura:
        o += f'<div class="ft" style="left:358px;top:{top + 26}px;font-size:10px;color:#fff">4.2</div>'
    o += (f'<div style="position:absolute;left:396px;top:{top}px;width:40px;height:40px;background:#6b5a2a;box-shadow:0 0 0 1px #000;'
          f'opacity:{.45 if i == 1 else 1}"></div>')
    o += f'<div style="position:absolute;left:438px;top:{top}px;width:40px;height:40px;background:#3a4a5a;box-shadow:0 0 0 1px #000"></div>'
    for k in range(2 if i != 1 else 1):
        imm = i == 0 and k == 1
        o += (f'<div style="position:absolute;left:{120 - k * 26}px;top:{top + 8}px;width:24px;height:24px;background:#5a3a6a;'
              f'box-shadow:0 0 0 {2 if imm else 1}px {"#ff3d3d" if imm else "#000"}"></div>')
    if i == 2:
        o += f'<div style="position:absolute;left:152px;top:{top + 2}px;width:10px;height:10px;border-radius:50%;background:#3ddc97"></div>'
    for k in range(i % 3):
        o += f'<div style="position:absolute;left:{330 - k * 8}px;top:{top + 2}px;width:6px;height:6px;background:#ffd200"></div>'
    return o


def stage_arena():
    o = "".join(foe(i, *f) for i, f in enumerate(FOES))
    return preview("Live preview", fit(CSS + o, 0.62, 200), 200, tag="ARENA · 3 TEST FRAMES")


def stage_resources():
    rows = [("#3ddc97", 12, 0.8, "80%"), ("#ffd200", 8, 0.66, "66"), ("#0070dd", 5, 0.7, ""), (None, 8, 0, ""), ("#ffb000", 6, 0.6, "")]
    o, y = "", 20
    for c, h, v, t in rows:
        if c is None:
            o += "".join(f'<div style="position:absolute;left:{200 + k * 45}px;top:{y}px;width:43px;height:{h}px;background:'
                         f'{"#ff3d00" if k < 3 else "#2a2e36"};box-shadow:0 0 0 1px #000"></div>' for k in range(5))
        else:
            o += (f'<div style="position:absolute;left:200px;top:{y}px;width:223px;height:{h}px;background:#1d2027;box-shadow:0 0 0 1px #000">'
                  f'<div style="width:{int(v * 223)}px;height:{h}px;background:{c}"></div></div>')
            if t:
                o += f'<div class="ft" style="left:290px;top:{y - 2}px;font-size:10px;color:#fff;text-shadow:0 0 2px #000">{t}</div>'
        y += h + 2
    o += "".join(f'<div style="position:absolute;left:{224 + k * 44}px;top:{y + 12}px;width:36px;height:36px;background:#2f4a5a;'
                 f'box-shadow:0 0 0 1px #000"><div class="ft" style="left:10px;top:22px;font-size:10px;color:#fff">{9 + k * 7}</div></div>'
                 for k in range(4))
    o += f'<div class="ft" style="left:200px;top:{y + 56}px;font-size:11px;color:#8a93a3">Druid (cat): health · energy · mana · combo points · Ironfur · totems</div>'
    return preview("Live preview", fit(CSS + o, 0.62, 200), 200, tag="RESOURCE BARS · TOTEMS")


def stage_castbars():
    o = ('<div style="position:absolute;left:150px;top:30px;width:300px;height:20px;background:#1d2027;box-shadow:0 0 0 1px #000">'
         '<div style="width:186px;height:20px;background:#ff6a1a"></div>'
         '<div class="ft" style="left:6px;top:3px;font-size:12px;color:#fff">Fireball</div></div>'
         '<div style="position:absolute;left:150px;top:70px;width:300px;height:4px;background:#1d2027"><div style="width:135px;height:4px;background:#c7cbd3"></div></div>'
         '<div style="position:absolute;left:150px;top:96px;width:300px;height:8px;background:#1d2027;box-shadow:0 0 0 1px #000">'
         '<div style="width:165px;height:8px;background:#ff6a1a"></div><div class="ft" style="left:3px;top:-3px;font-size:9px;color:#c7cbd3">MH</div></div>'
         '<div style="position:absolute;left:150px;top:106px;width:300px;height:4px;background:#1d2027"><div style="width:90px;height:4px;background:#ff6a1a"></div></div>'
         '<div class="ft" style="left:150px;top:126px;font-size:11px;color:#8a93a3">standalone GCD bar · swing with hand labels, dimmed out of melee</div>')
    return preview("Live preview", fit(CSS + o, 0.62, 180), 180, tag="GCD · SWING")


def stage_pvp():
    o = ('<div class="dm" style="left:180px;top:14px;width:260px;height:84px"><div class="h">Arena ready</div></div>'
         '<div class="ft" style="left:270px;top:110px;font-size:14px;color:#ff6a1a">Shadowsight in 0:38</div>')
    return preview("Live preview", fit(CSS + o, 0.62, 180), 180, tag="SHADOWSIGHT")


def build(rows):
    return {
        "s18_unitframes_arena": page(rows, "UnitFrames", "Unit Frames", "unitframes",
                                     "Phoenix frames for you, your target, focus, pet, bosses and arena enemies.",
                                     ["Arena", "Diminishing returns", "Arena widgets", "Click actions"], stage_arena(), "bars",
                                     "DR and trinket: the game's own trackers, restyled on the Phoenix frame · retail only",
                                     ["Frames", "Health", "Power", "Text", "Portrait", "Indicators", "Resources"]),
        "s18_unitframes_resources": page(rows, "UnitFrames", "Unit Frames", "unitframes",
                                         "Phoenix frames for you, your target, focus, pet, bosses and arena enemies.",
                                         ["Resource bars", "Rows", "Totem bar"], stage_resources(), "bars",
                                         "Right-click a totem to destroy it · Layout mode moves the block and the totems",
                                         ["Frames", "Health", "Power", "Text", "Portrait", "Indicators", "Resources"]),
        "s18_castbars_extras": page(rows, "CastBars", "Cast Bars", "castbars", "Phoenix cast bars, GCD bar and swing timer.",
                                    None, stage_castbars(), "bars", "GCD bar retail · swing timer where the client allows"),
        "s18_pvp": page(rows, "PvP", "PvP", "pvp", "Safer queue pops, TAB targeting, arena helpers.", None, stage_pvp(),
                        "content", "Shadowsight from the match clock · retail arenas"),
    }


if __name__ == "__main__":
    labels = sys.argv[1]
    dest = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, doc in build(load(labels)).items():
        html = SRC / f"{name}.html"
        doc = doc.replace("Search %d settings" % s6.SEARCH_N, "Search settings")
        html.write_text(doc.replace("Mockup of Phoenix UI 2.0 S6 settings window v2",
                                    "Mockup of Phoenix UI 2.0 S18 Unit Frames II, arena and resource bars (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
