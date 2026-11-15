#!/usr/bin/env python3
"""Settings window v2 (2.0 S6) mockups: HTML mirroring Phoenix_UI_Options/Config/{Window,Renderer,Home,Profiles}.lua,
rendered to PNG with headless Chrome. Layout sizes come from those files, labels from Locales/enUS.lua, icons from
the shipped Phosphor atlas (docs/screenshots/assets/icons96.png), setting counts and depth targets from the smoke
harness (Config:Depth, Config:SearchCount) at build time.
Usage (repo root): python3 docs/screenshots/src/s6.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
OUT = SRC.parent
ROOT = OUT.parent.parent
sys.path.insert(0, str(ROOT / "tools" / "media"))
from icon_map import ICONS  # noqa: E402

INDEX = {name: i for i, (name, _) in enumerate(ICONS)}
COLS, CELL, GUTTER = 10, 96, 3

# (now, target) per page: Config:Depth on the smoke harness, 2.0 S6
DEPTH = {"UnitFrames": (44, 150), "GroupFrames": (20, 68), "NamePlates": (64, 100), "CastBars": (27, 55), "Auras": (16, 41),
         "ActionBars": (34, 114), "Tracker": (30, 59), "CooldownText": (3, 12), "CombatText": (16, 26), "DamageMeter": (2, 31),
         "SpellHistory": (6, 12), "Chat": (17, 51), "Minimap": (6, 41), "DataTexts": (38, 47), "Tooltip": (31, 45),
         "Bags": (6, 47), "ItemLevel": (4, 19), "Skins": (3, 28), "MythicPlus": (11, 32), "Encounters": (63, 65),
         "PvP": (3, 8), "Sim": (9, 8), "General": (12, 23), "profiles": (15, 8), "Movers": (12, 11), "Quality": (4, 11),
         "Automation": (8, 14), "AFK": (1, 4), "Bugs": (12, 12), "diagnostics": (9, 3)}
SEARCH_N = 607

# Groups.lua Config.GROUPS: key, label, icon, entries ({"h": heading} or (key, label, icon, on))
GROUPS = [
    ("home", "Home", "home", [("home", "Home", "home", None)]),
    ("frames", "Frames", "unitframes", [("UnitFrames", "Unit Frames", "unitframes", True), ("GroupFrames", "Group Frames", "groupframes", True),
                                        ("NamePlates", "Nameplates", "nameplates", True), ("CastBars", "Cast Bars", "castbars", True),
                                        ("Auras", "Buffs & Debuffs", "auras", True)]),
    ("bars", "Bars", "actionbars", [("ActionBars", "Action Bars", "actionbars", True), ("Tracker", "Auras & Cooldowns", "tracker", True),
                                    ("CooldownText", "Cooldown Text", "cooldowntext", True)]),
    ("combat", "Combat", "cat-combat", [("CombatText", "Combat Text", "combattext", None), ("DamageMeter", "Damage Meter", "damagemeter", True),
                                        ("SpellHistory", "Spell History", "spellhistory", False)]),
    ("interface", "Interface", "interface", [{"h": "Chat & maps"}, ("Chat", "Chat", "chat", True), ("Minimap", "Minimap", "minimap", True),
                                             ("DataTexts", "Data Bar", "datatexts", True), {"h": "Tooltips & items"},
                                             ("Tooltip", "Tooltip", "tooltip", True), ("Bags", "Bags", "items", True),
                                             ("ItemLevel", "Item Level", "itemlevel", True), {"h": "Windows"}, ("Skins", "Skins", "skins", True)]),
    ("content", "Content", "content", [("MythicPlus", "Mythic+", "mythicplus", True), ("Encounters", "Encounters", "encounters", True),
                                       ("PvP", "PvP", "pvp", True), ("Sim", "Sim", "sim", True)]),
    ("phoenix", "Phoenix", "cat-phoenix", [{"h": "Look"}, ("General", "General", "general", None), ("fonts", "Fonts", "fonts", None),
                                           ("textures", "Textures", "textures", None), ("sounds", "Sounds", "sound", None),
                                           ("presets", "Presets", "presets", None), {"h": "Setup"}, ("profiles", "Profiles", "profiles", None),
                                           ("Movers", "Movers", "movers", True), {"h": "Utility"}, ("Quality", "Quality of Life", "quality", True),
                                           ("Automation", "Automation", "automation", True), ("AFK", "AFK Screen", "afk", True),
                                           {"h": "Support"}, ("Bugs", "Bugs", "bugs", True), ("diagnostics", "Diagnostics", "diagnostics", None),
                                           ("about", "About", "about", None)]),
]


def ico(name, size=None, style=""):
    i = INDEX[name]
    col, row = i % COLS, i // COLS
    inner = CELL - 2 * GUTTER
    x, y = -(col * CELL + GUTTER) / inner, -(row * CELL + GUTTER) / inner
    s = f";--s:{size}px" if size else ""
    return f'<span class="ico" style="--x:{x:.5f};--y:{y:.5f}{s};{style}"></span>'


def top(search="Search %d settings…" % SEARCH_N, focus=False, profile="Default", ww=1280):
    # Window.lua h:Arrange: the search centres between the brand and the tools and narrows (160-360) before overlapping
    left, right = 270, 468
    room = ww - left - right
    w = max(160, min(360, room))
    x = left + max(0, (room - w) / 2)
    return f'''<div class="top"><div class="emblem"></div><div class="brand">PHOENIX</div><div class="brandui">UI</div><span class="badge acc" style="margin-left:10px">v2.0.0-beta1</span>
<div class="search{' focus' if focus else ''}" style="left:{x:.0f}px;width:{w}px">{ico('search')}<span>{search}</span></div>
<div class="tr"><div class="dd" style="min-width:176px">{ico('profiles')}<span>{profile}</span><span class="chev">{ico('chevron-down', 11)}</span></div>
<div class="btn">{ico('layout')}Layout</div><div class="btn">{ico('test')}Test frames</div><div class="x">{ico('close', 15)}</div></div></div>'''


def rail(active):
    out = []
    for key, label, icon, _ in GROUPS:
        out.append(f'<div class="rb{" on" if key == active else ""}">{ico(icon, 20)}<span class="lab">{label}</span></div>')
    return '<div class="rail">' + "".join(out) + '</div>'


def meter(key):
    if key not in DEPTH:
        return ""
    now, target = DEPTH[key]
    pct = min(100, round(now * 100 / target))
    return f'<div class="meter"><i class="{"full" if now >= target else ""}" style="width:{pct}%"></i></div>'


def mlist(group, active):
    g = next(x for x in GROUPS if x[0] == group)
    out = [f'<div class="list"><div class="lh">{g[1]}</div>']
    for e in g[3]:
        if isinstance(e, dict):
            out.append(f'<div class="sub">{e["h"]}</div>')
            continue
        key, label, icon, on = e
        dot = "" if on is None else f'<span class="dot{"" if on else " off"}"></span>'
        out.append(f'<div class="nr{" on" if key == active else ""}">{ico(icon)}<div class="nm">{label}{dot}</div>{meter(key)}</div>')
    return "".join(out) + "</div>"


def foot(status="Live: changes apply as you make them", reload=False):
    rl = '<div class="btn primary sm">' + ico('reload') + 'Reload UI</div>' if reload else ''
    return f'''<div class="foot"><span class="ok">{ico('success')}</span>Changes save automatically
<span class="mut" style="margin-left:14px">{ico('preview')}</span><span class="mut">{status}</span>
<div class="r"><span class="mut">Pixel-perfect UI scale: 0.53</span><span class="mut">Window</span>
<div class="sld" style="--w:132px"><div class="tk"><i style="width:50%"></i><b style="left:50%"></b></div><div class="v">100%</div></div>{rl}</div></div>'''


def page_head(icon, title, desc, key, toggle=True, state="Active", reset=True):
    now = DEPTH.get(key, (0, 0))[0]
    tg = f'<span class="en">ENABLED</span><div class="tog on"></div>' if toggle else ""
    st = f'<span class="badge ok">{state}</span>' if state else ""
    rs = f'<div class="btn ghost">{ico("reset")}Reset module</div>' if reset else ""
    return f'''<div class="ph"><div class="ib">{ico(icon, 22)}</div><h1>{title}</h1><p>{desc}</p>
<div class="bg"><span class="badge">{ico('cog', 10)}{now} settings</span>{st}</div>
<div class="rt">{rs}{tg}</div></div>'''


def tabs(names, active=0):
    return '<div class="tabs">' + "".join(f'<div class="tab{" on" if i == active else ""}">{n}</div>' for i, n in enumerate(names)) + '</div>'


def card(icon, title, rows, gate=None, reset=False):
    g = ""
    if gate is not None:
        g = f'<div class="gate">{"<span class=rs>" + ico("reset", 13) + "</span>" if reset else ""}<div class="tog{" on" if gate else ""}"></div></div>'
    elif reset:
        g = f'<div class="gate"><span class="rs">{ico("reset", 13)}</span></div>'
    return f'<div class="card"><div class="ch">{ico(icon, 14)}{title}{g}</div>{"".join(rows)}</div>'


def line(label, ctl, desc=None, side="", off=False, cls=""):
    d = f'<div class="ds">{desc}</div>' if desc else ""
    return f'<div class="rowl{" off" if off else ""} {cls}"><div class="lt"><div class="lb">{label}</div>{d}</div><div class="side">{side}</div><div class="ctl">{ctl}</div></div>'


def pair(a, b):
    return f'<div class="pair">{a}{b}</div>'


def cell(label, ctl, side="", off=False):
    return f'<div class="cell{" off" if off else ""}"><div class="cl">{label}</div><div class="si">{side}</div><div class="cc">{ctl}</div></div>'


def tcell(label, on=True, side="", off=False):
    return f'<div class="cell t{" off" if off else ""}"><div class="cl">{label}</div><div class="si" style="position:static;margin-right:8px">{side}</div><div class="tog{" on" if on else ""}"></div></div>'


def tog(on=True):
    return f'<div class="tog{" on" if on else ""}"></div>'


def sel(text, w=200, sw=None, icon=None):
    s = f'<span class="sw" style="background:{sw}"></span>' if sw else ""
    i = ico(icon, 13) if icon else ""
    return f'<div class="sel" style="--w:{w}px">{i}{s}<span>{text}</span><span class="chev">{ico("chevron-down", 11)}</span></div>'


def sld(pct, val, w=200):
    return f'<div class="sld" style="--w:{w}px"><div class="tk"><i style="width:{pct}%"></i><b style="left:{pct}%"></b></div><div class="v">{val}</div></div>'


def swatch(color):
    return f'<div class="swc"><i style="background:{color}"></i></div>'


def cfield(color, lit=None):
    ch = (f'<span class="chip{" on" if lit == "class" else ""}">Class</span>'
          f'<span class="chip{" on" if lit == "theme" else ""}">Theme</span>')
    return f'<div style="display:flex;gap:6px;align-items:center">{ch}{swatch(color)}</div>'


def chips(items, on=(), ex=()):
    return '<div class="chips">' + "".join(
        f'<span class="chip{" on" if v in on else ""}{" ex" if v in ex else ""}">{(ico(i, 11) if i else "")}{v}</span>'
        for v, i in items) + '</div>'


def style_face(label, kind="ember"):
    edge = {"ember": "border:1px solid var(--acc);box-shadow:0 0 6px rgba(255,61,0,.6)", "solid": "border:1px solid #000",
            "pixel": "border:1px solid #000", "theme": "border:1px solid #000"}[kind]
    return f'<div class="sel" style="--w:200px"><span style="width:22px;height:14px;background:#23262e;{edge}"></span><span>{label}</span><span class="chev">{ico("chevron-down", 11)}</span></div>'


def COG():
    return f'<span class="sib">{ico("cog", 13)}</span>'


def ALL():
    return f'<span class="sib">{ico("apply-all", 13)}</span>'


def RESET():
    return f'<span class="sib acc">{ico("reset", 13)}</span>'


def preview(title, stage, h=200, states=(), on=(), tag=None, docked=True, world=True):
    st = f'<div style="padding:0 16px 10px">{chips(states, on)}</div>' if states else ""
    tg = f'<span class="tag">{tag}</span>' if tag else ""
    hint = '<div class="hint">Sample data, redrawn as you change settings</div>' if docked else ""
    wb = f'<div class="wb"><div class="btn">{ico("test")}Show in world</div></div>' if world else '<div style="height:14px"></div>'
    return (f'<div class="card pv"><div class="ch">{ico("preview", 14)}Live preview{tg}<span class="rs" style="margin-left:{8 if tag else "auto"}px;color:var(--muted)">{ico("hide", 12)}</span></div>'
            f'{st}<div class="stage" style="--sh:{h}px">{stage}</div>{hint}{wb}</div>')


def plates():
    def plate(x, y, name, hp, pct, tgt=False, cast=None, auras=2, color=None):
        au = '<div class="au">' + "<b></b>" * auras + '</div>' if auras else ""
        cb = f'<div class="cb"><i style="width:{cast}%"></i></div>' if cast else ""
        c = f'background:{color}' if color else ""
        return (f'<div class="np{" tgt" if tgt else ""}" style="left:{x}px;top:{y}px">{au}<div class="nm">{name}</div>'
                f'<div class="hb"><i style="width:{hp}%;{c}"></i><span>{pct}</span></div>{cb}</div>')
    return (plate(14, 26, "Void-Touched Stalker", 82, "82%", cast=58, color="linear-gradient(180deg,#ff8a45,#e0560f)", tgt=True)
            + plate(170, 44, "Nexus Warden", 46, "46%", auras=1, color="linear-gradient(180deg,#ffd166,#d39a1a)")
            + plate(92, 112, "Shadowguard Adept", 100, "100%", auras=0, color="linear-gradient(180deg,#5ee0a0,#24a86a)", cast=None)
            + '<div style="position:absolute;left:12px;bottom:8px;font-family:Cond;font-size:10px;color:#8a93a3">Tank view · threat colours</div>')


def shell(rail_key, list_key, active, content, dock=None, search=None, focus=False, ww=1280, status=None, reload=False, overlay=""):
    dockw = 384 if dock is not None else 0
    st = ('--ww:%dpx;' % ww) + ('--dock:%dpx;' % dockw)
    body = f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head>
<body style="--bw:{ww + 80}px;--bh:880px"><div class="world"></div><div class="win" style="{st}">
{top(search or "Search %d settings…" % SEARCH_N, focus, ww=ww)}{rail(rail_key)}{mlist(list_key, active)}
<div class="content{"" if dock is not None else " full"}">{content}</div>
{f'<div class="dock">{dock}</div>' if dock is not None else ''}{overlay}{foot(status or "Live: changes apply as you make them", reload)}</div>
<div class="cap">Mockup of Phoenix UI 2.0 S6 settings window v2 · drawn from Window.lua / Renderer.lua sizes, enUS labels, shipped icon atlas</div></body></html>'''
    return body


# ------------------------------------------------------------------ screens
def nameplates():
    style = card("theme", "Style", [line("Phoenix bar texture", tog(), "Flat Phoenix status bar on every plate. Needs a reload.", side=COG() if False else ""),
                                    pair(cell("Bar texture", sel("Satin", 220, sw="linear-gradient(180deg,#e0560f,#a83a06)")), cell("Border", style_face("Follow Appearance", "theme"), COG()))])
    cast = card("castbars", "Cast bar", [pair(cell("Bar texture", sel("Default", 220)), cell("Cast bar colour", cfield("#ff6a1a", "theme"))),
                                         line("Cast bar font", sel("Roboto Condensed Bold · 11", 220, icon="fonts"), side=COG())], gate=True)
    threat = card("warning", "Threat", [line("Threat colours", '<div style="display:flex;gap:6px">' + swatch("#3ddc97") + swatch("#ffc24b") + swatch("#ff4d5e") + '</div>',
                                             "Pick the safe, losing and lost aggro colours.", side=RESET(), cls="flash")], gate=True, reset=True)
    hl = card("preview", "Target and focus", [line("Colour your target", tog(), "The plate of your current target takes this colour so it stands out in a pack.", side=COG()),
                                              line("Colour your focus", tog(False), "Your focus target's plate takes this colour.", side=COG())])
    content = (page_head("nameplates", "Nameplates", "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.", "NamePlates")
               + tabs(["Appearance", "Colours", "Text", "Game"], 1) + '<div class="body">' + hl + threat + '</div>')
    dock = preview("Live preview", plates(), 196, [("Target", "preview"), ("Casting", "castbars"), ("Tank", "warning"), ("Low health", None)],
                   on=("Target", "Tank"), tag="NAMEPLATE")
    _ = style, cast
    return shell("frames", "frames", "NamePlates", content, dock, status="Threat colours reset to default")


def unitframes():
    scope = (f'<div class="scope"><div class="t">{ico("unitframes", 13)}Frame<span class="h">Shift-click to edit several</span>'
             f'<span class="all">ALL {tog(False)}</span></div><div class="r">'
             + chips([("Player", None), ("Target", None), ("Focus", None), ("Pet", None), ("Boss", None)], on=("Player",), ex=("Target",))
             + f'<div style="margin-left:auto;display:flex;align-items:center;gap:8px;font-family:Cond;font-size:11px;color:var(--muted)">Apply all settings from {sel("Focus", 120)}</div></div></div>')
    bars = card("textures", "Bars", [line("Phoenix textures", tog(), "Flat Phoenix status bars on the player, target, focus and pet frames. Needs a reload."),
                                     pair(cell("Bar texture", sel("Satin", 200, sw="linear-gradient(180deg,#3ddc97,#1f8a5c)"), ALL()),
                                          cell("Health bar border", style_face("Ember", "ember"), COG() + ALL())),
                                     pair(cell("Background opacity", sld(60, "60%", 200), COG() + ALL()), cell("Portrait", sel("Class icon", 200), ALL()))])
    icons = card("presets", "Icons", [pair(tcell("Leader icon", True, ALL()), tcell("Raid marker", True, ALL())), pair(tcell("PvP icon", False, ALL()), '<div class="cell t"></div>')])
    auras = card("auras", "Auras", [line("Aura border", style_face("Follow Appearance", "theme"), side=COG())], gate=True)
    content = (page_head("unitframes", "Unit Frames", "Textures, colors and fonts for player, target, focus and pet frames.", "UnitFrames")
               + scope + tabs(["Appearance", "Text"], 0) + '<div class="body">' + bars + icons + auras + '</div>')
    uf = ('<div style="position:absolute;left:34px;top:46px;width:248px">'
          '<div style="display:flex;gap:8px"><div style="width:46px;height:46px;border:1px solid var(--acc);box-shadow:0 0 8px rgba(255,61,0,.55);background:radial-gradient(circle at 40% 35%,#c8a2ff,#4b2a7a)"></div>'
          '<div style="flex:1"><div style="display:flex;justify-content:space-between;font-family:CondSemi;font-size:12px"><span>Vorte</span><span>412K</span></div>'
          '<div style="height:18px;border:1px solid var(--acc);box-shadow:0 0 8px rgba(255,61,0,.55);margin-top:3px;background:#0d1a14;position:relative"><i style="position:absolute;left:0;top:0;bottom:0;width:86%;background:linear-gradient(180deg,#5ee0a0,#24a86a)"></i></div>'
          '<div style="height:7px;border:1px solid #000;margin-top:2px;background:#0a1020;position:relative"><i style="position:absolute;left:0;top:0;bottom:0;width:64%;background:#4da3ff"></i></div></div></div></div>')
    dock = preview("Live preview", uf, 150, [("In combat", "cat-combat"), ("Low health", None), ("Dead", None)], tag="PLAYER")
    return shell("frames", "frames", "UnitFrames", content, dock, status="Editing Player + Target")


def general():
    pick = ['none', 'pixel', 'solid', 'thick', 'inset', 'shadow', 'glow', 'ember']
    names = {'none': 'None', 'pixel': 'Pixel', 'solid': 'Solid', 'thick': 'Thick', 'inset': 'Inset', 'shadow': 'Shadow', 'glow': 'Glow', 'ember': 'Ember'}
    samp = {'none': '', 'pixel': 'border:1px solid #000', 'solid': 'border:1px solid #000', 'thick': 'border:3px solid #000',
            'inset': 'border:1px solid #000;box-shadow:inset 0 0 0 1px rgba(255,255,255,.12)', 'shadow': 'border:1px solid #000;box-shadow:0 4px 10px rgba(0,0,0,.8)',
            'glow': 'box-shadow:0 0 8px rgba(255,255,255,.35)', 'ember': 'border:1px solid var(--acc);box-shadow:0 0 9px rgba(255,61,0,.75)'}
    cards = "".join(f'<div class="scard{" on" if k == "ember" else ""}{" hov" if k == "inset" else ""}"><div class="sm" style="{samp[k]}"></div><div class="n">{names[k]}</div></div>' for k in pick)
    pop = f'<div class="pop" style="left:{276 + 24 + 230}px;top:{52 + 96 + 48 + 14 + 42 + 54}px"><h4>Border style</h4><div class="sgrid">{cards}</div></div>'
    look = card("theme", "Appearance", [line("Theme", sel("Ember", 200, icon="theme"), "The accent colour of every Phoenix panel."),
                                        line("Bar texture", sel("Satin", 200, sw="linear-gradient(180deg,#ff7a2e,#c4460a)"), "Status bar texture for unit frames, cast bars, nameplates and meters.")])
    borders = card("border", "Borders &amp; shadows", [
        line("Border style", style_face("Ember", "ember"), "The default border of every frame and panel whose border follows Appearance."),
        pair(cell("Border size", sld(25, "1")), cell("Shadow depth", sld(75, "75%"))),
        line("Border colour", cfield("#000", "theme"), "Colour of those borders. Theme keeps the theme's dark edge, Class uses your class colour."),
        line("Glow colour", cfield("#3fc7eb", "class"), "Colour of Ember borders and glow shadows. Theme follows the accent colour.", side=RESET())])
    typo = card("fonts", "Typography", [pair(cell("Interface font", sel("Default", 200, icon="fonts")), cell("Font scale", sld(40, "100%")))])
    content = (page_head("general", "General", "Theme, fonts and textures shared by every module.", "General", toggle=False, state=None)
               + '<div class="body">' + look + borders + typo + '</div>')
    th = ('<div style="position:absolute;inset:18px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.55)">'
          '<div style="height:28px;border-bottom:1px solid #23262e;display:flex;align-items:center;padding:0 10px;font-family:CondBold;font-size:10.5px;letter-spacing:1.4px;color:#a3a9b6">SECTION HEADING</div>'
          '<div style="padding:12px 10px;font-family:Roboto;font-size:11.5px;color:#a3a9b6">Every border set to Follow Appearance<br>now draws Ember with a class-coloured glow.</div>'
          '<div style="position:absolute;left:10px;right:10px;bottom:12px;height:12px;border:1px solid #000;background:#1b1206"><i style="display:block;width:68%;height:100%;background:linear-gradient(90deg,#ff6a1a,#ffb23f)"></i></div></div>')
    dock = preview("Live preview", th, 170, tag="THEME", world=False)
    return shell("phoenix", "phoenix", "General", content, dock, overlay=pop, status="Previewing Inset (hover)")


def home():
    cards = []
    sample = [("unitframes", "Unit Frames", "FRAMES", "Textures, colors and fonts for player, target, focus and pet frames.", "UnitFrames", True),
              ("groupframes", "Group Frames", "FRAMES", "Party and raid frames: texture, role icons and range fade.", "GroupFrames", True),
              ("nameplates", "Nameplates", "FRAMES", "Bar texture, health percent and Mythic+ enemy forces on nameplates.", "NamePlates", True),
              ("castbars", "Cast Bars", "FRAMES", "Player, target and focus cast bars with latency and interrupt marks.", "CastBars", True),
              ("auras", "Buffs & Debuffs", "FRAMES", "Your buff and debuff icons: size, timers and borders.", "Auras", False)]
    for i, (icon, label, cat, desc, key, on) in enumerate(sample):
        now, target = DEPTH[key]
        pct = min(100, round(now * 100 / target))
        cards.append(f'''<div class="mc{" hov" if i == 2 else ""}"><div class="ib{"" if on else " off"}">{ico(icon, 18)}</div><div class="nm">{label}</div><div class="ct">{cat}</div>
<div class="tog{" on" if on else ""}"></div><div class="ds">{desc}</div><div class="dm"><i style="width:{pct}%"></i></div><div class="dn">{now} / {target}</div></div>''')
    content = (f'''<div class="hero"><div class="logo"></div><div class="em"></div><div class="tl">A flat, unified look for the default interface.</div>
<div class="ac">ACCENT <i class="on" style="background:linear-gradient(0deg,#ff6a1a,#ffb23f)"></i><i style="background:linear-gradient(0deg,#3a8bff,#9fd4ff)"></i>
<i style="background:linear-gradient(0deg,#3ddc6a,#c4ff7a)"></i><i style="background:linear-gradient(0deg,#9a5cff,#e0b8ff)"></i><i style="background:linear-gradient(0deg,#3fc7eb,#bdf0ff)"></i></div>
<div class="bt"><div class="btn">{ico('profiles')}Profiles</div><div class="btn primary">{ico('editmode')}Open Edit Mode</div></div></div>
<div class="stats"><div class="stat">{ico('addon')}<div><b>24 / 27</b><span>Modules enabled</span></div></div>
<div class="stat">{ico('profiles')}<div><b>Default</b><span>Active profile</span></div></div><div class="stat">{ico('theme')}<div><b>Ember</b><span>Theme</span></div></div></div>
<div class="gt">MODULES</div><div class="fchips">{chips([("All", None), ("Frames", "unitframes"), ("Bars", "actionbars"), ("Combat", "cat-combat"), ("Interface", "interface"), ("Content", "content"), ("Phoenix", "cat-phoenix"), ("Off", None)], on=("Frames",))}</div>
<div class="grid">{"".join(cards)}</div>''')
    hl = [("success", "var(--ok)", "Every module is running"), ("reload", "var(--warn)", "2 modules wait for a reload"),
          ("bugs", "var(--ok)", "No errors this session"), ("lock", "var(--ok)", "Out of combat: changes apply now")]
    health = card("success", "Health checks", ['<div style="padding-bottom:10px">' + "".join(f'<div class="hl"><span style="color:{c}">{ico(i, 12)}</span>{t}</div>' for i, c, t in hl) + '</div>'])
    qa = card("presets", "Quick actions", [f'<div class="qa"><div class="btn">{ico("layout")}Layout</div><div class="btn">{ico("test")}Test frames</div>'
                                           f'<div class="btn">{ico("profiles")}Profiles</div><div class="btn">{ico("presets")}Presets</div></div>'])
    news = card("bell", "What's new", ['<div class="news"><div>·  A new settings window: icon rail, page list and a pinned live preview.</div>'
                                       '<div>·  Borders, shadows and glow are set once under Appearance for every module.</div>'
                                       '<div>·  Colours can follow your class or the theme.</div><div>·  Export single modules and preview what an import changes.</div></div>'])
    return shell("home", "home", "home", content, health + qa + news, status="Live: changes apply as you make them", reload=True)


def profiles():
    chars = card("user", "Characters", [line("Vorte - Silvermoon", sel("Default", 200, icon="user"), "This character (switches now)"),
                                        line("Ashenmane - Silvermoon", sel("Healer", 200, icon="user")),
                                        line("Kaelith - Draenor", sel("Default", 200, icon="user"))])
    mods = [("Unit Frames", "unitframes"), ("Nameplates", "nameplates"), ("Cast Bars", "castbars"), ("Action Bars", "actionbars"), ("Chat", "chat"),
            ("Minimap", "minimap"), ("Tooltip", "tooltip"), ("Bags", "items"), ("Data Bar", "datatexts"), ("Encounters", "encounters"), ("Mythic+", "mythicplus"), ("General", "general")]
    exp = card("export", "Export", [f'<div class="rowl" style="flex-direction:column;align-items:stretch"><div class="lt"><div class="lb">Modules to export</div>'
                                    f'<div class="ds">Pick modules to share only those. With none picked, the whole profile is exported.</div></div>'
                                    f'<div style="margin-top:10px">{chips(mods, on=("Unit Frames", "Nameplates", "Cast Bars"))}</div></div>',
                                    line("Export string", f'<div class="btn primary">{ico("export")}Generate</div>', "A text you can paste anywhere; it holds the modules picked above.")])
    imp = card("import", "Import", [f'<div class="rowl" style="flex-direction:column;align-items:stretch"><div class="lb">Import string</div>'
                                    f'<div class="ta" style="margin:8px 0">!PUI1!eNrtWVtv2zYU/iuCnpsGkmzLlt8ctFgwdGjQZN2wIQ9HEm0zpkiBpJw4Rf/7DiXZluRbnLTDhuXFli...</div>'
                                    f'<div class="diff"><span class="ok">"Raid Healer": 4 modules, 23 settings change.</span><br>Group Frames (12), Nameplates (7), Unit Frames (4), <span class="m">Chat</span></div></div>',
                                    line("Import as", f'<div style="display:flex;gap:8px"><div class="sel" style="--w:180px"><span>Raid Healer</span></div><div class="btn primary">{ico("import")}Import</div></div>'),
                                    line("Merge into this profile", f'<div class="btn">{ico("import")}Merge</div>', "Writes only the modules in the string into the active profile and keeps everything else.")])
    active = card("profiles", "Active profile", [line("Profile", sel("Default", 200, icon="user"), "Profile this character uses."),
                                                 line("Start from a preset", f'<div class="btn">{ico("presets")}Open presets</div>', "Complete looks you can apply to this profile in one click.")])
    content = (page_head("profiles", "Profiles", "Switch, share and back up your settings.", "profiles", toggle=False, state=None, reset=False)
               + '<div class="body" style="display:grid;grid-template-columns:1fr 1fr;align-items:start">' + '<div style="display:flex;flex-direction:column;gap:12px">' + active + chars + '</div>'
               + '<div style="display:flex;flex-direction:column;gap:12px">' + exp + imp + '</div></div>')
    return shell("phoenix", "phoenix", "profiles", content, None, status="Valid string: preview below")


def search():
    rows = [("nameplates", "<mark>Health</mark> text", "Frames  ›  Nameplates  ›  Text"),
            ("unitframes", "<mark>Health</mark> font", "Frames  ›  Unit Frames  ›  Text  ›  Text"),
            ("unitframes", "<mark>Health</mark> bar border", "Frames  ›  Unit Frames  ›  Appearance  ›  Bars"),
            ("groupframes", "<mark>Health</mark> text", "Frames  ›  Group Frames  ›  Text"),
            ("nameplates", "<mark>Health</mark> font", "Frames  ›  Nameplates  ›  Text  ›  Text"),
            ("tooltip", "<mark>Health</mark> bar", "Interface  ›  Tooltip  ›  Style"),
            ("datatexts", "Low <mark>health</mark> warning", "Interface  ›  Data Bar  ›  Segments")]
    rr = "".join(f'<div class="rr{" hot" if i == 1 else ""}"><div class="ib">{ico(icon, 14)}</div><div><b>{t}</b><span>{p}</span></div><span class="go">{ico("chevron-right", 12)}</span></div>'
                 for i, (icon, t, p) in enumerate(rows))
    ov = f'<div class="res"><div class="hd">7 RESULTS FOR “HP” · SYNONYM: HEALTH</div>{rr}</div>'
    return shell("frames", "frames", "UnitFrames", "", None, search="hp", focus=True, overlay=ov, status="Enter opens the first result")


def narrow():
    content = (page_head("nameplates", "Nameplates", "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.", "NamePlates")
               + tabs(["Appearance", "Colours", "Text", "Game"], 1) + '<div class="body">'
               + preview("Live preview", plates(), 170, [("Target", "preview"), ("Casting", "castbars"), ("Tank", "warning")], on=("Target",), tag="NAMEPLATE", docked=False)
               + card("warning", "Threat", [line("Threat colours", '<div style="display:flex;gap:6px">' + swatch("#3ddc97") + swatch("#ffc24b") + swatch("#ff4d5e") + '</div>',
                                                 "Pick the safe, losing and lost aggro colours.", off=True)], gate=False) + '</div>')
    return shell("frames", "frames", "NamePlates", content, None, ww=1000, status="Narrow window: preview stays in the page")


PAGES = {"s6_home": home, "s6_nameplates": nameplates, "s6_unitframes": unitframes, "s6_general": general,
         "s6_profiles": profiles, "s6_search": search, "s6_narrow": narrow}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn(), encoding="utf-8")
        w = 1080 if name == "s6_narrow" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
