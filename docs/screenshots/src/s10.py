#!/usr/bin/env python3
"""Nameplates (2.0 S10) mockups: HTML mirroring Phoenix_UI_Options/Options/NamePlates.lua and its Preview, drawn with
the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from Locales/enUS.lua, the
setting count from the smoke harness ("nameplates depth (S10)"). Icons and textures are CSS stand-ins for the game's
art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s10.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, chips, style_face, COG, ALL, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["NamePlates"] = (272, 100)
OUT = SRC.parent
CSS = s9.CSS + ('<style>.pl{position:absolute}.pl .hb{position:absolute;background:#14161b;box-shadow:0 0 0 1px #000;overflow:hidden}'
                '.pl .hb>i{position:absolute;left:0;top:0;bottom:0}.pl .hb>u{position:absolute;top:0;bottom:0;'
                'background:repeating-linear-gradient(45deg,rgba(255,255,255,.55) 0 2px,rgba(255,255,255,.15) 2px 5px)}'
                '.pl .hb>em{position:absolute;top:-1px;bottom:-1px;width:1px;background:#fff}'
                '.pl .t{position:absolute;font-family:CondSemi;color:#fff;text-shadow:1px 1px 0 #000;white-space:nowrap}'
                '.pl .mk{position:absolute;font-size:15px;line-height:16px}.pl .bd{position:absolute;font-size:11px;font-family:CondBold}'
                '.pl .ar{position:absolute;color:#ff6a1a;font-size:14px;font-family:CondBold;text-shadow:0 0 6px #ff3d00}'
                '.pl .cp{position:absolute;display:flex;gap:2px}.pl .cp i{width:12px;height:4px;box-shadow:0 0 0 1px #000}</style>')
HOST, NEUT, FRIEND, QUEST, EXEC = "#e04a3a", "#ffc24b", "#3ddc97", "#c77dff", "#ff2d55"


def plate(x, y, name, hp, color, w=140, h=12, pct=None, level="", absorb=0, target=False, effect="glow", arrows=False,
          focus=False, hover=False, marker=None, quest=False, elite=False, rare=False, cast=None, debuffs=0, buffs=0,
          cp=0, execute=None, info="", name_only=False, forces=""):
    out = []
    if name_only:
        out.append(f'<div class="t" style="left:{-w // 2}px;width:{w}px;text-align:center;top:-7px;font-size:12px;color:{color}">{name}</div>')
        if info:
            out.append(f'<div class="t" style="left:{-w // 2}px;width:{w}px;text-align:center;top:8px;font-size:10px;color:#c9ced8">&lt;{info}&gt;</div>')
        return f'<div class="pl" style="left:{x}px;top:{y}px">{"".join(out)}</div>'
    L = -w // 2
    st = ""
    if target and effect == "glow":
        st = "box-shadow:0 0 0 1px #000,0 0 9px 2px #ff6a1a;"
    elif target and effect == "border":
        st = "box-shadow:0 0 0 1px #ff6a1a;"
    fill = EXEC if execute else color
    inner = f'<i style="width:{hp}%;background:linear-gradient(180deg,{fill},{fill}aa)"></i>'
    if absorb:
        inner += f'<u style="left:{hp}%;width:{absorb}%"></u>'
    if execute:
        inner += f'<em style="left:{execute}%"></em>'
    if hover:
        inner += '<i style="width:100%;background:rgba(255,255,255,.18)"></i>'
    if focus:
        inner += '<i style="width:3px;background:#4da3ff"></i>'
    out.append(f'<div class="hb" style="left:{L}px;top:0;width:{w}px;height:{h}px;{st}">{inner}</div>')
    if pct:
        out.append(f'<div class="t" style="left:{L}px;width:{w - 4}px;text-align:right;top:{h // 2 - 6}px;font-size:10px">{pct}</div>')
    if level:
        out.append(f'<div class="t" style="left:{L + 3}px;top:{h // 2 - 6}px;font-size:10px;color:{NEUT if "+" in level else "#ffd24a"}">{level}</div>')
    out.append(f'<div class="t" style="left:{L}px;width:{w}px;text-align:center;top:-15px;font-size:11px">{name}</div>')
    if marker:
        out.append(f'<div class="mk" style="left:{L - 22}px;top:{h // 2 - 8}px">{marker}</div>')
    bx = L + w + 3
    if quest:
        out.append(f'<div class="bd" style="left:{L + w // 2 + len(name) * 3 + 6}px;top:-15px;color:#ffd24a">!</div>')
    if elite or rare:
        out.append(f'<div class="bd" style="left:{bx}px;top:{h // 2 - 7}px;color:{"#c9ced8" if rare else "#ffd24a"}">{"★" if rare else "◆"}</div>')
        bx += 14
    if forces:
        out.append(f'<div class="t" style="left:{bx}px;top:{h // 2 - 6}px;font-size:10px;color:#3ddc97">{forces}</div>')
    if target and (arrows or effect == "arrows"):
        out.append(f'<div class="ar" style="left:{L - 16}px;top:{h // 2 - 9}px">›</div><div class="ar" style="left:{L + w + 6}px;top:{h // 2 - 9}px">‹</div>')
    yb = h + 2
    if cast:
        kind, nm, p = cast
        out.append(s9.castbar(L, yb, w, 13, nm, "", p, kind, icon="left", shield=(kind == "locked"),
                              glow=False).replace('font-size:10px', 'font-size:9px'))
        yb += 15
    if cp:
        out.append(f'<div class="cp" style="left:{L + w // 2 - cp * 7}px;top:{yb}px">'
                   + "".join(f'<i style="background:{"#fff468" if i < 3 else "#2a2c33"}"></i>' for i in range(cp)) + '</div>')
    for i in range(debuffs):
        out.append(s9.aura(L + i * 22, -40, 20, i + 2, "", "#fff", stack=("3" if i == 1 else ""),
                           edge="#9b4dff" if i == 0 else "#000"))
    for i in range(buffs):
        out.append(s9.aura(bx + 22 + i * 20, h // 2 - 9, 18, 0, "", edge="#3f8cff"))
    return f'<div class="pl" style="left:{x}px;top:{y}px">{"".join(out)}</div>'


def head():
    return page_head("nameplates", "Nameplates", "Phoenix's own enemy and friendly nameplates: health, cast bars, tags, auras, highlights, threat and zones.", "NamePlates")


TABS = ["Plates", "Health", "Target", "Cast bar", "Text", "Auras", "Indicators", "Zones", "Game"]


def scope(on="Enemy"):
    return (f'<div class="scope"><div class="t">{ico("nameplates", 13)}Plate<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips([("Enemy", None), ("Friendly", None)], on=(on,))}</div></div>')


def stage(state):
    st = CSS
    low = state == "Low health"
    st += plate(165, 62, "Void-Touched Stalker", 18 if low else 73, HOST, pct="18%" if low else "73%", level="92+", absorb=12,
                target=True, marker="☠", elite=True, cast=("cast", "Shadow Bolt Volley", 56), debuffs=3, buffs=1, cp=5,
                execute=20 if low else None, forces="+4", w=170, h=14)
    st += plate(165, 162, "Nexus Warden", 17, NEUT, pct="17%", level="90", quest=True, rare=True, focus=True, marker="✖",
                cast=("locked", "Arcane Shield", 34), debuffs=1, execute=20, w=170, h=14)
    st += plate(165, 222, "Vorte", 77, "#ffffff", name_only=True, info="Phoenix")
    return preview("Live preview", st, 250, [("Target", "preview"), ("Low health", None), ("Raid markers", None), ("Quest mob", None), ("Absorbs", None)],
                   on=(state, "Target"), tag="NAMEPLATE")


def p_plates():
    mode = card("nameplates", "Plates drawn by", [line("Plates drawn by", sel("Phoenix", 200), "Phoenix draws its own plates over the game's (health, cast bar, auras, icons). Blizzard keeps the game's plates and Phoenix only restyles them. Needs a reload."),
                                                  line("Test plates", f'<div class="btn">{ico("test")}Toggle test plates</div>', "Shows three sample plates mid-screen: a casting elite, a rare quest mob and a friendly player.")])
    look = card("theme", "Look", [pair(cell("Bar texture", sel("Satin", 180, sw="linear-gradient(180deg,#e04a3a,#8a2014)")), cell("Border", style_face("Pixel", "pixel"), COG() + ALL())),
                                  line("Background", sel("Sunken · 75%", 180), side=COG())])
    size = card("layout", "Size", [pair(cell("Width", sld(52, "140"), ALL()), cell("Height", sld(24, "12"), ALL())),
                                   line("Names only", tog(False), "Friendly plates show the name without a health bar.", off=True)])
    click = card("movers", "Click area", [line("Set the click area", tog(), "Phoenix sets the plate size the game uses for clicks and stacking. Off: the game's size."),
                                          pair(cell("Enemy width", sld(52, "140")), cell("Enemy height", sld(30, "30"))),
                                          pair(cell("Friendly width", sld(40, "110")), cell("Friendly height", sld(24, "24"))),
                                          line("Click through friendly plates", tog(), "Friendly plates take no clicks, so you click what is behind them."),
                                          '<div class="rowl"><div class="lt"><div class="ds">The click area only changes out of combat (a game rule); changes made in combat apply when it ends.</div></div></div>'], gate=True)
    content = head() + scope("Enemy") + tabs(TABS, 0) + '<div class="body">' + mode + look + size + click + '</div>'
    return s6.shell("frames", "frames", "NamePlates", content, stage("Target"), status="Enemy · 140 × 12, click area 140 × 30")


def p_health():
    bar = card("border", "Health bar", [pair(cell("Health colour", sel("Reaction", 160)), tcell("Class colour for players", True)),
                                        pair(tcell("Smooth bar", True), tcell("Absorb shields", True)),
                                        line("Reaction colours", '<div style="display:flex;gap:6px">' + swatch(HOST) + swatch(NEUT) + swatch(FRIEND) + swatch("#8a8f99") + '</div>', "Colours for hostile, neutral and friendly units and for mobs someone else has tagged.")])
    thr = card("warning", "Threat", [line("Threat colours", tog(), "Tanks see safe, wobbling and lost threat; everyone else sees when a mob turns to them."),
                                     line("Role for threat", sel("Automatic", 160), "Automatic follows your spec. Tanks see green while they hold aggro; everyone else sees red when they pull it."),
                                     line("Off-tank colour", swatch("#4da3ff"), "Tanks: the colour when another tank in your group holds the mob.")], gate=True)
    ex = card("cat-combat", "Execute range", [line("Execute colour", tog(), "Enemies under the threshold turn the execute colour. Drawn through the game's health curve, so it works on secret health too.", side=COG()),
                                              pair(cell("Threshold (%)", sld(20, "20")), tcell("Threshold mark", True))], gate=True)
    q = card("tracker", "Quest mobs", [line("Quest mob colour", tog(False), "Mobs that belong to one of your active quests get their own health colour.", side=COG()),
                                      line("Quest icon", tog(), "A quest mark beside the name of quest mobs.")])
    content = head() + scope("Enemy") + tabs(TABS, 1) + '<div class="body">' + bar + thr + ex + q + '</div>'
    return s6.shell("frames", "frames", "NamePlates", content, stage("Low health"), status="Execute at 20 % · tank view")


def p_target():
    hl = card("preview", "Target and focus", [line("Target effect", sel("Glow", 160), "How your target's plate stands out: a glow, a border or arrows.", side=COG()),
                                              line("Arrows too", tog(False), "Arrows beside your target's plate as well as the effect."),
                                              pair(tcell("Colour your target", False), tcell("Colour your focus", True)),
                                              line("Focus mark", tog(), "A stripe on the left edge of your focus's plate.", side=COG()),
                                              pair(tcell("Mouseover highlight", True), cell("Highlight strength", sld(25, "25%"))),
                                              line("Class resource on the target", tog(), "Your combo points, holy power and the like under your target's plate (Unit Frames' class resource style).")])
    sel_ = card("general", "Selection", [pair(cell("Target scale", sld(30, "1.20")), cell("Alpha of other plates", sld(80, "80%"))),
                                         line("Behind walls", sld(40, "40%"), "Opacity of plates whose unit is out of sight (game setting).")])
    content = head() + scope("Enemy") + tabs(TABS, 2) + '<div class="body">' + hl + sel_ + '</div>'
    return s6.shell("frames", "frames", "NamePlates", content, stage("Target"), status="Target glow · focus stripe")


def p_auras():
    tx = card("fonts", "Tags", [pair(cell("Name tags", sel("[name]", 160)), cell("Health tags", sel("[health:percent]", 160))),
                                pair(cell("Level tags", sel("[level][classification]", 160)), cell("Info tags", sel("[guild]", 160))),
                                line("Mythic+ enemy forces", tog(), "In Mythic+, how much enemy forces each mob is worth (+4) beside its health bar.", side=COG())])
    au = card("auras", "Auras on plates", [pair(cell("Debuffs", sel("Mine", 140)), tcell("Crowd control first", True)),
                                           pair(cell("Icon size", sld(30, "20")), cell("Max auras", sld(40, "6"))),
                                           line("Buffs", sel("Purgeable", 140), "Enemy buffs: the ones you can dispel or purge, the important ones or all."),
                                           '<div class="rowl"><div class="lt"><div class="ds">Aura rows ask the game with filter words (yours, important, dispellable, crowd control); aura data itself is never read, so it works in restricted content.</div></div></div>'])
    content = head() + scope("Enemy") + tabs(TABS, 5) + '<div class="body">' + tx + au + '</div>'
    return s6.shell("frames", "frames", "NamePlates", content, stage("Raid markers"), status="Debuffs: mine · buffs: purgeable")


def p_zones():
    z = card("maps", "By zone", [line("Change plates by zone", tog(), "A different scale and friendly plates in the open world, in dungeons and raids, and in battlegrounds and arenas.")])
    rows = []
    for name, fr, sc in (("Open world", "Plates", "100%"), ("Dungeons and raids", "Names only", "90%"), ("Battlegrounds and arenas", "Plates", "100%")):
        rows.append(card("encounters" if "Dungeons" in name else ("pvp" if "Battle" in name else "maps"), name,
                         [pair(cell("Scale", sld(45, sc)), cell("Friendly players", sel(fr, 140))),
                          pair(tcell("Hide enemies out of combat", name == "Open world"), tcell("Enemy minions", "Dungeons" not in name))]))
    st = card("grid", "Stacking and distance", [pair(tcell("Stack enemy plates", True), tcell("Stack friendly plates", False)),
                                                pair(cell("Vertical spacing", sld(36, "1.10")), cell("Max distance", sld(70, "41")))])
    content = head() + scope("Enemy") + tabs(TABS, 7) + '<div class="body">' + z + "".join(rows) + st + '</div>'
    return s6.shell("frames", "frames", "NamePlates", content, stage("Quest mob"), status="Dungeons: friendly names only, scale 90%")


def world():
    body = CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
    body += plate(470, 330, "TEST · Void-Touched Stalker", 73, HOST, pct="73%", level="92+", absorb=12, target=True, marker="☠",
                  elite=True, cast=("cast", "Shadow Bolt Volley", 56), debuffs=3, buffs=1, cp=5, forces="+4")
    body += plate(740, 330, "TEST · Nexus Warden", 17, NEUT, pct="17%", level="90", quest=True, rare=True, focus=True,
                  marker="✖", cast=("locked", "Arcane Shield", 34), debuffs=1, execute=20)
    body += plate(980, 330, "Vorte", 77, "#ffffff", name_only=True, info="Phoenix")
    for i, (n, hp, c) in enumerate((("Shadowguard Adept", 100, HOST), ("Shadowguard Adept", 64, HOST), ("Nexus Sprite", 41, NEUT))):
        body += plate(560 + i * 170, 520 + (i % 2) * 22, n, hp, c, pct=f"{hp}%", debuffs=(1 if i == 1 else 0), hover=(i == 2))
    body += ('<div style="position:absolute;left:420px;top:60px;width:600px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
             'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">TEST PLATES</b><br>A casting elite on target (glow, skull, '
             'class resource, forces, absorbs), a rare quest mob as focus under the execute threshold, and a friendly player as a name with guild. Below: live plates with '
             'threat colours and a mouseover highlight.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S10 nameplates with Test plates (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s10_plates": p_plates, "s10_health": p_health, "s10_target": p_target, "s10_auras": p_auras, "s10_zones": p_zones, "s10_test": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S10 nameplates (HTML)"), encoding="utf-8")
        w = 1440 if name == "s10_test" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
