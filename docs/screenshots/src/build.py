#!/usr/bin/env python3
"""Builds the settings-window mockups (HTML) and renders them to PNG with headless Chrome.
Usage (repo root): python3 tools/media/gen_icons.py && python3 docs/screenshots/src/build.py
Content mirrors the real pages: module list/order from Modules/*, labels from Locales/enUS.lua.
Icons are masks into docs/screenshots/assets/icons96.png, the same Phosphor atlas the addon ships
(names and order from tools/media/icon_map.py), so the mockups show exactly the in-game glyphs."""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
OUT = SRC.parent
ROOT = OUT.parent.parent
CHROME = "google-chrome"
sys.path.insert(0, str(ROOT / "tools" / "media"))
from icon_map import ICONS  # noqa: E402

INDEX = {name: i for i, (name, _) in enumerate(ICONS)}
COLS, CELL, GUTTER = 10, 96, 3

NAV = [
    (None, [("home", "Home", "home", None)]),
    ("System", [("general", "General", "general", True), ("bugs", "Bugs", "bugs", True)]),
    ("Interface", [("skins", "Skins", "skins", True), ("actionbars", "Action Bars", "actionbars", True),
                   ("unitframes", "Unit Frames", "unitframes", True), ("groupframes", "Group Frames", "groupframes", True),
                   ("castbars", "Cast Bars", "castbars", True), ("auras", "Buffs & Debuffs", "auras", True),
                   ("nameplates", "Nameplates", "nameplates", True), ("tooltip", "Tooltip", "tooltip", True),
                   ("itemlevel", "Item Level", "itemlevel", True), ("minimap", "Minimap", "minimap", True),
                   ("datatexts", "Data Bar", "datatexts", True), ("movers", "Movers", "movers", True)]),
    ("Combat", [("cooldowntext", "Cooldown Text", "cooldowntext", True), ("combattext", "Combat Text", "combattext", None),
                ("damagemeter", "Damage Meter", "damagemeter", True), ("spellhistory", "Spell History", "spellhistory", False),
                ("pvp", "PvP", "pvp", True)]),
    ("Social", [("chat", "Chat", "chat", True), ("afk", "AFK Screen", "afk", True)]),
    ("Utility", [("quality", "Quality of Life", "quality", True), ("automation", "Automation", "automation", True),
                 ("mythicplus", "Mythic+", "mythicplus", True)]),
    ("Phoenix", [("profiles", "Profiles", "profiles", None), ("about", "About", "about", None)]),
]


CATEGORY_ICON = {"System": "cat-system", "Interface": "cat-interface", "Combat": "cat-combat", "Social": "cat-social",
                 "Utility": "cat-utility", "Phoenix": "cat-phoenix"}


def ico(name, cls="", size=None):
    i = INDEX[name]
    col, row = i % COLS, i // COLS
    inner = CELL - 2 * GUTTER
    x, y = -(col * CELL + GUTTER) / inner, -(row * CELL + GUTTER) / inner
    s = f";--s:{size}px" if size else ""
    return f'<span class="ico {cls}" style="--x:{x:.5f};--y:{y:.5f}{s}"></span>'


def sidebar(active, scroll=0):
    rows = []
    for group, items in NAV:
        if group:
            rows.append(f'<div class="grp">{ico(CATEGORY_ICON[group])}{group}</div>')
        for key, label, icon, on in items:
            dot = "" if on is None else f'<span class="dot{"" if on else " off"}"></span>'
            rows.append(f'<div class="nav{" active" if key == active else ""}">{ico(icon)}{label}{dot}</div>')
    return (f'<div class="side"><div style="margin-top:-{scroll}px">{"".join(rows)}</div>'
            '<div style="position:absolute;right:3px;top:12px;width:3px;height:180px;background:#2a2e37"></div></div>')


def shell(active, body, search="Search settings…", focus=False, status="Changes apply instantly", scroll=0, overlay="",
          status_icon="preview", status_cls="", head="", above=""):
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css">{head}</head>
<body><div class="world"></div><div class="win">
<div class="hdr"><div class="emblem"></div><div class="brand">PHOENIX</div><div class="brand-ui">UI</div>
<span class="badge">v2.0.0</span>
<div class="search{" focus" if focus else ""}">{ico("search")}{search}</div>
<div class="ibtn">{ico("editmode")}</div><div class="ibtn">{ico("reload")}</div><div class="ibtn">{ico("close")}</div></div>
{sidebar(active, scroll)}
<div class="content">{body}</div>{overlay}
<div class="ftr">{ico("profiles", "pico")}Profile: Default &nbsp;·&nbsp; 20 modules active<span class="mid {status_cls}">{ico(status_icon)}{status}</span>
<span class="scl">WINDOW SCALE</span><span class="sl"><span style="width:43%"></span></span><span class="val">1.00</span>
{btn("Reload UI", "reload", "primary")}{btn("Close", "close")}<span class="grip">{ico("resize")}</span></div>
</div>{above}</body></html>'''


def opt(label, ctl, desc=None, badge="", hl=False):
    d = f"<i>{desc}</i>" if desc else ""
    return (f'<div class="opt{" d" if desc else ""}{" hl" if hl else ""}"><div class="l"><b>{label}</b>{d}</div>'
            f'{badge}<div class="ctl">{ctl}</div></div>')


def tog(on=True):
    return f'<span class="tog{" on" if on else ""}">{ico("check") if on else ""}</span>'


def dd(text, icon=None):
    return f'<span class="dd">{ico(icon) if icon else ""}{text}{ico("chevron-down", "chev")}</span>'


def btn(label, icon=None, variant=""):
    return f'<span class="btn {variant}">{ico(icon) if icon else ""}{label}</span>'


def badge(text, cls, icon=None):
    return f'<span class="badge {cls}">{ico(icon) if icon else ""}{text}</span>'


def sl(pct, val):
    return f'<span class="sl"><span style="width:{pct}%"></span></span><span class="val">{val}</span>'


def section(title, rows, icon=None):
    head = f'<div class="sech i">{ico(icon)}{title}</div>' if icon else f'<div class="sech">{title}</div>'
    return f'<div class="sec">{head}{"".join(rows)}</div>'


def page_head(icon, title, desc, toggle=True, state='<span class="badge ok">Active</span>'):
    ctl = (f'<div class="pctl"><div class="row">Enabled {tog(True)}</div>{state}</div>' if toggle else "")
    return (f'<div class="phead"><div class="picon">{ico(icon)}</div><div><div class="ptitle">{title}</div>'
            f'<div class="pdesc">{desc}</div></div>{ctl}</div>')


# ---------------------------------------------------------------- home
CARDS = [("general", "General", "System", "Theme, fonts and textures shared by every module.", True),
         ("actionbars", "Action Bars", "Interface", "Crisp square buttons, readable text and range feedback.", True),
         ("unitframes", "Unit Frames", "Interface", "Textures, colors and fonts for player, target, focus and pet.", True),
         ("castbars", "Cast Bars", "Interface", "Flat cast bars with icon, timer and latency.", True),
         ("nameplates", "Nameplates", "Interface", "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.", True),
         ("tooltip", "Tooltip", "Interface", "A cleaner tooltip with class borders, health bar and extra lines.", True),
         ("damagemeter", "Damage Meter", "Combat", "Phoenix skin for Blizzard's damage meter.", True),
         ("spellhistory", "Spell History", "Combat", "A strip of your most recent casts.", False),
         ("automation", "Automation", "Utility", "Repair, sell junk, accept invites and more.", True)]


def card(icon, label, cat, desc, on):
    bg = "var(--accent-soft)" if on else "var(--bg-sunken)"
    col = "var(--accent)" if on else "var(--muted)"
    return f'''<div style="background:var(--bg-raised);border:1px solid var(--border);height:108px;padding:14px;position:relative">
<div style="display:flex;gap:10px;align-items:center"><div style="width:34px;height:34px;display:grid;place-items:center;background:{bg};color:{col}">{ico(icon)}</div>
<div><div style="font-size:13px">{label}</div><div style="font-family:Cond;font-size:10.5px;letter-spacing:1.2px;color:var(--muted);margin-top:3px;text-transform:uppercase">{cat}</div></div>
<div style="margin-left:auto">{tog(on)}</div></div>
<div style="font-family:Roboto;color:var(--text2);font-size:11.5px;margin-top:12px;line-height:1.45">{desc}</div></div>'''


def home():
    swatches = "".join(
        f'<span title="{n}" style="width:22px;height:22px;background:{c};border:1px solid #000;'
        f'box-shadow:0 0 0 {2 if i == 0 else 1}px {"#fff" if i == 0 else "#3a3f4b"}"></span>'
        for i, (n, c) in enumerate([("Ember", "#ff6a1a"), ("Frost", "#2fa8ff"), ("Fel", "#5bd43b"),
                                    ("Arcane", "#a35bff"), ("Class", "#3fc7eb")]))
    hero = f'''<div style="position:relative;height:150px;border:1px solid var(--border);background:
linear-gradient(100deg, rgba(255,106,26,.20), rgba(255,61,0,.05) 45%, transparent 70%), var(--bg-raised);padding:22px 24px;display:flex;align-items:center;overflow:hidden">
<div style="position:absolute;right:-60px;top:-80px;width:340px;height:340px;background:radial-gradient(circle, rgba(255,106,26,.22), transparent 65%)"></div>
<div><div style="width:300px;height:64px;background:url(../assets/logo.png) left center / contain no-repeat"></div>
<div style="font-family:Roboto;color:var(--text2);margin-top:8px;font-size:13px">A flat, consistent look for the default 12.x interface.</div>
<div style="display:flex;gap:10px;margin-top:16px;align-items:center"><span style="font-family:CondBold;font-size:10.5px;letter-spacing:1.6px;color:var(--muted)">ACCENT</span>{swatches}</div></div>
<div style="position:absolute;right:-40px;top:-30px;width:220px;height:220px;background:url(../assets/emblem.png) center / contain no-repeat;opacity:.10"></div>
<div style="margin-left:auto;display:flex;gap:10px;position:relative">{btn("Profiles", "profiles")}{btn("Edit Mode", "editmode", "primary")}</div></div>'''
    chips = "".join(f'''<div class="chip">{ico(i)}<div>
<div style="font-family:CondBold;font-size:20px;color:{c}">{v}</div><div style="font-family:Cond;font-size:11px;color:var(--muted);letter-spacing:1px;margin-top:2px;text-transform:uppercase">{k}</div></div></div>'''
                    for i, v, k, c in [("addon", "20 / 22", "Modules enabled", "var(--text)"),
                                       ("profiles", "Default", "Active profile", "var(--text)"),
                                       ("theme", "Phoenix Ember", "Theme", "var(--accent)")])
    grid = "".join(card(*c) for c in CARDS)
    body = (hero + f'<div style="display:flex;gap:12px;margin:14px 0">{chips}</div>'
            '<div class="sech" style="padding:4px 0 10px">Modules</div>'
            f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">{grid}</div>')
    return shell("home", body)


def tooltip(highlight=False, search="Search settings…", focus=False):
    body = page_head("tooltip", "Tooltip", "A cleaner tooltip with class borders, health bar and extra lines.")
    rel = badge("Reload", "warn", "reload")
    body += section("Style", [
        opt("Phoenix style", tog(), "Dark background and thin border."),
        opt("Health bar", tog(), "Restyle the unit health bar."),
        opt("Class border", tog(), "Color the border by the player's class.", hl=highlight),
        opt("Item quality border", tog(), "Color the border by item quality."),
    ])
    body += section("Behavior", [
        opt("Anchor", dd("Cursor"), "Where tooltips that use the default position appear."),
        opt("Hide in combat", tog(False), "Hide unit tooltips while in combat. Hold Shift, Ctrl or Alt to see them anyway."),
    ])
    body += section("Extra lines", [
        opt("Target", tog(), "Show what the unit is targeting."),
        opt("Mythic+ rating", tog(), "Show a player's current season rating in Blizzard's rarity color."),
        opt("IDs", tog(False), "Show item and spell IDs.", badge=rel),
    ])
    return shell("tooltip", body, search=search, focus=focus)


def search_page():
    page = tooltip(highlight=True, search="class colo", focus=True)
    results = [("tooltip", "Class border", "Tooltip · Style"), ("unitframes", "Class-colored health", "Unit Frames · Bars"),
               ("castbars", "Class color", "Cast Bars · Style"), ("general", "Theme", "General · Appearance")]
    rows = "".join(f'''<div style="display:flex;align-items:center;gap:10px;height:42px;padding:0 12px;{"background:rgba(255,106,26,.10);box-shadow:inset 2px 0 0 var(--accent);" if i == 0 else ""}">
<span style="width:28px;height:28px;display:grid;place-items:center;background:var(--accent-soft);color:var(--accent)">{ico(icon, "sm")}</span><div><div style="font-size:12.5px">{label}</div><div style="font-family:Roboto;font-size:11px;color:var(--muted);margin-top:2px">{where}</div></div>
<span style="margin-left:auto;color:{"var(--accent)" if i == 0 else "var(--muted)"}">{ico("chevron-right", "xs")}</span></div>'''
                   for i, (icon, label, where) in enumerate(results))
    overlay = f'''<div style="position:absolute;left:560px;top:50px;width:300px;background:#16181e;border:1px solid var(--border-strong);box-shadow:0 16px 40px rgba(0,0,0,.7);z-index:5">
<div style="font-family:CondBold;font-size:10.5px;letter-spacing:1.6px;color:var(--muted);padding:10px 12px 6px">4 RESULTS</div>{rows}</div>'''
    return page.replace('<div class="ftr">', overlay + '<div class="ftr">')


def profiles():
    body = page_head("profiles", "Profiles", "Switch, share and back up your settings.", toggle=False)
    body += section("Active profile", [
        opt("Profile", dd("Default", "user"), "The profile this character uses."),
        opt("New profile", '<span class="input">Raid</span>' + btn("Create", "add"), "Create a profile with default settings."),
        opt("Duplicate profile", '<span class="input">Default copy</span>' + btn("Duplicate", "duplicate"),
            "Copy the current profile under a new name."),
        opt("Reset profile", btn("Reset", "reset", "danger"), "Return every setting in this profile to its default."),
    ], "profiles")
    body += section("Specializations", [
        opt("Profile per specialization", tog(), "Switch profile automatically when you change specialization."),
        opt("Frost", dd("Default", "user")), opt("Fire", dd("Raid", "user")),
    ], "spec")
    body += section("Export", [opt("Export string", btn("Generate", "export", "primary"),
                                   "Create a string you can share or keep as a backup.")], "export")
    return shell("profiles", body, status="Export string ready – press Ctrl+A, Ctrl+C.", status_icon="success",
                 status_cls="ok")


# ---------------------------------------------------------------- icon close-up
GROUPS = [
    ("Pages & modules", lambda n: INDEX[n] < INDEX["cat-system"]),
    ("Categories", lambda n: n.startswith("cat-")),
    ("Actions & controls", lambda n: INDEX["search"] <= INDEX[n] < INDEX["fps"]),
    ("Data bar & fallback", lambda n: INDEX["fps"] <= INDEX[n] <= INDEX["question"]),
    ("Bugs", lambda n: INDEX["bugs"] <= INDEX[n] < INDEX["movers"]),
    ("Movers", lambda n: INDEX[n] >= INDEX["movers"]),
]
STATES = [("Normal", "var(--text2)"), ("Hover", "var(--text)"), ("Active", "var(--accent)"),
          ("Danger", "var(--danger)"), ("Disabled", "rgba(107,113,128,.6)")]


def icons_page():
    names = [n for n, _ in ICONS]
    groups = []
    for title, pred in GROUPS:
        tiles = "".join(f'<div class="itile">{ico(n)}<span>{n}</span></div>' for n in names if pred(n))
        groups.append(f'<div class="igrp"><div class="sech">{title}</div><div class="igrid">{tiles}</div></div>')
    sizes = "".join(f'<div class="isz">{ico("cat-phoenix", size=px)}<span>{px}</span></div>' for px in (12, 16, 20, 24, 32, 48))
    states = "".join(f'<div class="ist" style="color:{c}">{ico("delete" if n == "Danger" else "reload")}<span>{n}</span></div>'
                     for n, c in STATES)
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head>
<body class="icons"><div class="world"></div><div class="sheet">
<div class="ihead"><div class="ilogo"></div><div class="imeta"><b>Phoenix icon set</b>
<i>{len(ICONS)} Phosphor duotone glyphs (MIT) · white RLE TGA atlases, 24 / 48 / 96 px cells · tinted by theme tokens</i></div>
<div class="iemb"></div></div>
<div class="irow"><div class="ibox"><div class="sech">Sizes</div><div class="iflex">{sizes}</div></div>
<div class="ibox"><div class="sech">States</div><div class="iflex">{states}</div></div></div>
{"".join(groups)}</div></body></html>'''


# ---------------------------------------------------------------- bug viewer (Modules/Bugs/Viewer.lua)
BUGS = [
    ("error", "Interface/AddOns/RareScanner/Core.lua:812: attempt to index field 'vignette' (a nil value)",
     "RareScanner", 14, "21:42"),
    ("taint", "[ADDON_ACTION_BLOCKED] AddOn 'ShinyBags' tried to call the protected function 'UseContainerItem()'.",
     "ShinyBags", 2, "21:39"),
    ("error", "Interface/AddOns/Phoenix_UI/Modules/Tooltip/Tooltip.lua:233: bad argument #1 to 'format'",
     "Phoenix_UI", 1, "21:31"),
    ("warning", "Interface/AddOns/OldQuestLog/OldQuestLog.lua:41: GetQuestLogTitle is deprecated",
     "OldQuestLog", 6, "21:30"),
    ("error", "Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua:418: secret value compared",
     "Blizzard", 3, "21:12"),
    ("error", "Interface/AddOns/WeakAuras/RegionTypes/Icon.lua:96: attempt to perform arithmetic on a nil value",
     "WeakAuras", 1, "21:05"),
]
KIND = {"error": ("error", "Lua error", "var(--danger)"), "taint": ("taint", "Blocked action", "var(--warn)"),
        "warning": ("warning", "Lua warning", "var(--info)")}
STACK = """[Interface/AddOns/RareScanner/Core.lua]:812: in function 'UpdateVignette'
[Interface/AddOns/RareScanner/Core.lua]:640: in function <Interface/AddOns/RareScanner/Core.lua:621>
[C]: in function 'securecallfunction'
[Interface/AddOns/Blizzard_SharedXMLBase/CallbackRegistry.lua]:144: in function 'TriggerEvent'"""
LOCALS = """self = <table> {
 vignettes = <table> {}
 lastScan = 18342.512
}
guid = "Vignette-0-4227-2552-14-6214-0000A3F1C2"
info = nil"""


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def bugs_page():
    rows = []
    for i, (kind, msg, src, count, at) in enumerate(BUGS):
        icon, label, col = KIND[kind]
        rows.append(f'<div class="brow{" sel" if i == 0 else ""}"><span class="bk" style="color:{col}">{ico(icon)}</span>'
                    f'<div class="bt"><b>{esc(msg.split(": ", 1)[-1] if kind != "taint" else msg)}</b>'
                    f'<i>{label} · {src} · session 42</i></div><span class="bc">{count}×</span></div>')
    kind, msg, src, count, _ = BUGS[0]
    report = (f"Report 3f9a0c17be42d905-42-1\nKind: error   Source: {src}   Count: {count}\n"
              f"First seen: 21:18:04   Last seen: 21:42:51\nPhoenix UI 2.0.0 · WoW 12.1.5.70448 · enUS\n\n"
              f"Message:\n{msg}\n\nStack:\n{STACK}\n\nLocals:\n{LOCALS}")
    viewer = f'''<div class="bview">
<div class="bhdr"><span class="bico">{ico("bugs")}</span><b>Bug reports</b>{badge("6 this session · 27 hits", "danger")}
<div class="search sm">{ico("search")}Search</div>{dd("This session", "clock")}<div class="ibtn">{ico("close")}</div></div>
<div class="blist">{"".join(rows)}<div class="bthumb"></div></div>
<div class="bdet"><div class="bbadges">{badge("Lua error", "danger", "error")}{badge("RareScanner", "info", "addon")}
{badge("14×", "warn")}<span class="bseen">First 21:18 · last 21:42</span></div>
<div class="bmsg">{esc(msg)}</div><pre class="bbox">{esc(report)}</pre></div>
<div class="bftr"><div class="ibtn">{ico("chevron-left")}</div><div class="ibtn">{ico("chevron-right")}</div>
<span class="bpos">1 / 6</span><span class="bstat">{ico("warning")}3 repeats skipped by flood protection.</span>
{btn("Upload", "upload", "ghost")}{btn("Copy", "copy", "primary")}{btn("Clear", "delete", "danger")}</div></div>'''
    minimap = f'''<div class="mm"><div class="mmz">Dornogal</div><div class="bugind pulse">{ico("bugs")}<span>6</span></div></div>
<div class="dbar">{ico("fps")}<b>144</b> fps<span class="sep"></span>{ico("latency")}<b>32</b> ms<span class="sep"></span>
<span class="dbug pulse">{ico("bugs")}<b>6</b> bugs</span><span class="sep"></span>{ico("clock")}<b>21:42</b></div>'''
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head>
<body><div class="world"></div>{minimap}{viewer}</body></html>'''


# ---------------------------------------------------------------- movers unlock mode (Modules/Movers)
def movers_page():
    gx = "".join(f'<div class="gx" style="left:{x}px"></div>' for x in range(0, 1281, 32))
    gy = "".join(f'<div class="gy" style="top:{y}px"></div>' for y in range(0, 801, 32))
    handles = [("Zone text", 440, 150, 400, 70, False, "TOP 0, -150"),
               ("Top-center widgets", 520, 20, 240, 40, False, "TOP 0, -20"),
               ("Error and quest messages", 390, 250, 500, 60, True, "TOP 0, -250"),
               ("Boss banner (kill and loot)", 470, 330, 340, 110, False, "TOP 0, -330"),
               ("Alerts (achievements, loot toasts)", 90, 520, 300, 80, False, "BOTTOMLEFT 90, 200"),
               ("Event toasts (level up, scenario)", 470, 470, 340, 70, False, "CENTER 0, -105"),
               ("Ready check", 900, 300, 300, 100, False, "RIGHT -80, 50"),
               ("Bug indicator", 1110, 190, 140, 44, False, "TOPRIGHT -30, -190")]
    hs = "".join(f'<div class="mh{" sel" if sel else ""}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px">'
                 f'<b>{name}</b><i>{pos}</i></div>' for name, x, y, w, h, sel, pos in handles)
    tool = f'''<div class="mtool"><div class="mrow"><span class="bico">{ico("movers")}</span><b>Movers</b>
<div class="ibtn">{ico("chevron-left")}</div><span class="mname">Error and quest messages</span><div class="ibtn">{ico("chevron-right")}</div>
<span class="mpos">TOP 0, -250</span><div class="ibtn hot on">{ico("grid")}</div><div class="ibtn hot on">{ico("snap")}</div>
{btn("Done", "check", "primary")}</div>
<div class="mrow"><div class="ibtn">{ico("arrow-left")}</div><div class="ibtn">{ico("arrow-up")}</div><div class="ibtn">{ico("arrow-down")}</div>
<div class="ibtn">{ico("arrow-right")}</div><span class="mlab">{ico("resize", "sm")}</span>{sl(40, "1.10")}
<span class="mlab">{ico("opacity", "sm")}</span>{sl(85, "90%")}{btn("Reset", "reset")}</div></div>'''
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head>
<body><div class="world"></div><div class="grid">{gx}{gy}<div class="gx mid" style="left:640px"></div>
<div class="gy mid" style="top:400px"></div></div>{hs}{tool}</body></html>'''


# ---------------------------------------------------------------- mythic+ timer (Modules/MythicPlus/Timer.lua)
def mplus_page():
    chests = [("+3", "1:24", "var(--accent)"), ("+2", "8:00", "var(--text2)"), ("+1", "14:36", "var(--text2)")]
    chest = "".join(f'<span style="flex:1;text-align:{a}">{t}&nbsp;&nbsp;<span style="color:{c}">{v}</span></span>'
                    for (t, v, c), a in zip(chests, ("left", "center", "right")))
    bosses = [("Vexamus", "5:58", True), ("Overgrown Ancient", "12:40", True), ("Crawth", "", False),
              ("Echo of Doragosa", "", False)]
    rows = "".join(f'''<div class="mprow"><span style="color:{"var(--ok)" if done else "var(--muted)"}">{ico("boss", "sm")}</span>
<span class="mpl" style="color:{"var(--text2)" if done else "var(--text)"}">{name}</span><span class="mpv" style="color:{"var(--ok)" if done else "var(--text2)"}">{at}</span></div>'''
                   for name, at, done in bosses)
    timer = f'''<div class="mpt">
<div style="display:flex;align-items:center;gap:8px"><span class="mplvl">+12</span><span class="mpname">Algeth&#39;ar Academy</span>
<span style="margin-left:auto;color:var(--danger)">{ico("deaths", "sm")}</span><span class="mpnum">3&nbsp;&nbsp;−15s</span></div>
<div class="mpaff">Fortified&nbsp;&nbsp;·&nbsp;&nbsp;Bolstering</div>
<div style="display:flex;align-items:baseline;margin-top:8px"><span class="mpclock">18:24</span><span class="mplim">/ 33:00</span>
<span class="mppb">Best 28:32</span></div>
<div class="mpbar"><span style="width:55.8%"></span><i style="left:60%"></i><i style="left:80%"></i></div>
<div class="mpchest">{chest}</div>
<div class="mprow" style="margin-top:10px"><span style="color:var(--muted)">{ico("forces", "sm")}</span><span class="mpl">Enemy forces</span>
<span class="mpv" style="color:var(--text)">72.40%</span></div><div class="mpfb"><span style="width:72.4%"></span></div>{rows}</div>'''
    plates = "".join(f'''<div class="np" style="left:{x}px;top:{y}px"><div class="npn">{n}</div><div class="npb"><span style="width:{w}%"></span>
<b>{w}%</b></div><span class="npf">{f}</span></div>''' for n, x, y, w, f in
                     [("Spellbound Battleaxe", 330, 300, 64, "+4"), ("Arcane Ravager", 520, 360, 88, "+7"), ("Vile Lasher", 400, 440, 100, "")])
    css = """<style>
.mpt{position:absolute;right:120px;top:150px;width:256px;padding:12px;background:var(--bg-base);border:1px solid var(--border);
 box-shadow:0 0 24px rgba(0,0,0,.6);transform:scale(1.5);transform-origin:top right;font-family:RobotoMedium;font-size:12px}
.mplvl{font-family:CondSemi;font-size:16px;color:var(--accent)} .mpname{font-family:Inter;font-size:14px}
.mpnum{font-family:CondSemi;color:var(--text2)} .mpaff{font-family:Cond;font-size:10px;color:var(--muted);margin-top:4px}
.mpclock{font-family:CondBold;font-size:28px;text-shadow:1px 1px 0 #000} .mplim{font-family:CondSemi;font-size:14px;color:var(--muted);margin-left:6px}
.mppb{margin-left:auto;font-family:Cond;font-size:10px;color:var(--muted)}
.mpbar{position:relative;height:6px;margin-top:8px;background:var(--bg-sunken);border:1px solid #000}
.mpbar span{position:absolute;left:0;top:0;bottom:0;background:var(--accent)} .mpbar i{position:absolute;top:0;bottom:0;width:1px;background:rgba(236,238,242,.7)}
.mpchest{display:flex;margin-top:6px;font-family:Cond;font-size:10px;color:var(--text2)}
.mprow{display:flex;align-items:center;gap:8px;height:20px} .mpl{flex:1} .mpv{font-family:CondSemi}
.mpfb{height:4px;margin-left:22px;background:var(--bg-sunken);border:1px solid #000;position:relative}
.mpfb span{position:absolute;left:0;top:0;bottom:0;background:var(--accent2)}
.np{position:absolute;width:150px;font-family:CondSemi} .npn{font-size:11px;color:#ffd5d5;text-align:center;text-shadow:1px 1px 0 #000}
.npb{position:relative;height:10px;margin-top:2px;background:var(--bg-sunken);border:1px solid #000}
.npb span{position:absolute;left:0;top:0;bottom:0;background:#c8323c} .npb b{position:absolute;inset:0;font-size:9px;text-align:center;line-height:10px;color:var(--text);text-shadow:1px 1px 0 #000}
.npf{position:absolute;left:154px;top:14px;font-size:11px;color:var(--accent2);text-shadow:1px 1px 0 #000}
</style>"""
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css">{css}</head>
<body><div class="world"></div>{plates}{timer}</body></html>'''


# ---------------------------------------------------------------- options 2.1 (UI/Config/Renderer.lua, UI/Previews)
FONT_DATA = ROOT / "Core" / "FontData.lua"
TEX_DATA = ROOT / "Core" / "TextureData.lua"
BARS = OUT / "assets" / "bars"


def font_data():
    import re
    text = FONT_DATA.read_text(encoding="utf-8")
    pat = re.compile(r'key = "(\w+)", name = "Phoenix ([^"]+)", file = "([^"]+)",\s*family = "([^"]+)", weight = "([^"]+)", '
                     r'category = "(\w+)", cyrillic = (\w+)')
    return [dict(key=k, name=n, file=f, family=fam, weight=w, cat=c, cyr=cy == "true")
            for k, n, f, fam, w, c, cy in pat.findall(text)]


def bar_data():
    import re
    text = TEX_DATA.read_text(encoding="utf-8").split("borders = {")[0]
    return [dict(key=k, name=n, file=f, style=st)
            for k, n, f, st in re.findall(r'key = "(\w+)", name = "Phoenix ([^"]+)", file = "(\w+)", style = "(\w+)"', text)]


def export_bars():
    """The shipped TGA statusbars as PNG, so the mockups tint the real art (multiply = SetVertexColor)."""
    from PIL import Image
    BARS.mkdir(parents=True, exist_ok=True)
    for b in bar_data():
        png = BARS / f"{b['file']}.png"
        src = ROOT / "Media" / "Textures" / f"{b['file']}.tga"
        if not png.exists() or png.stat().st_mtime < src.stat().st_mtime:
            Image.open(src).save(png, optimize=True)


def faces(fonts):
    return "<style>" + "".join(f'@font-face{{font-family:"F-{f["key"]}";src:url("../../../Media/Fonts/{f["file"]}")}}'
                               for f in fonts) + "</style>"


def bar(pct, color, tex="BarSatin", h=14, w=None, border="1px solid #000", text="", cls=""):
    width = f"width:{w}px;" if w else ""
    inner = f'<b>{text}</b>' if text else ""
    return (f'<span class="pbar {cls}" style="{width}height:{h}px;border:{border}">'
            f'<span style="width:{pct}%;background-color:{color};background-image:url(../assets/bars/{tex}.png)"></span>{inner}</span>')


def cog(open_=False):
    return f'<span class="cog{" on" if open_ else ""}">{ico("cog")}</span>'


def tabs(names, active=0):
    return '<div class="tabs">' + "".join(f'<span class="{"on" if i == active else ""}">{n}</span>'
                                          for i, n in enumerate(names)) + "</div>"


def seg(items, active, multi=()):
    return '<span class="seg">' + "".join(
        f'<span class="{"on" if i == active or i in multi else ""}">{t}</span>' for i, t in enumerate(items)) + "</span>"


def preview_card(stage, h):
    return (f'<div class="sec pv"><div class="sech i">{ico("preview")}Live preview<span class="hint">Sample data, redrawn as you change settings</span></div>'
            f'<div class="stage" style="height:{h}px">{stage}</div></div>')


def card2(title, rows, wide=False):
    return f'<div class="sec c2{" wide" if wide else ""}"><div class="sech">{title}</div>{"".join(rows)}</div>'


def row(label, ctl, desc=None, gear=None, hl=False):
    d = f"<i>{desc}</i>" if desc else ""
    return (f'<div class="opt{" d" if desc else ""}{" hl" if hl else ""}"><div class="l"><b>{label}</b>{d}</div>'
            f'<div class="ctl c2">{ctl}{gear or ""}</div></div>')


def dd2(text, face=None, tex=None):
    style = f' style="font-family:{face}"' if face else ""
    strip = (f'<span class="ddbar" style="background-image:url(../assets/bars/{tex}.png)"></span>' if tex else "")
    return f'<span class="dd c2">{strip}<span class="ddl"{style}>{text}</span>{ico("chevron-down", "chev")}</span>'


def sl2(pct, val):
    return f'<span class="sl c2"><span style="width:{pct}%"></span></span><span class="val">{val}</span>'


def sw(color):
    return f'<span class="sw" style="background:{color}"></span>'


def popover(title, rows, left, top, width=300):
    body = "".join(f'<div class="prow"><b>{l}</b><span class="ctl c2">{c}</span></div>' for l, c in rows)
    return (f'<div class="pop" style="left:{left}px;top:{top}px;width:{width}px"><div class="poph">{ico("cog", "xs")}{title}</div>'
            f'{body}</div>')


def plate(name, pct, color, forces="", tex="BarEmber"):
    f = f'<span class="npf2">{forces}</span>' if forces else ""
    return (f'<div class="np2"><div class="npn2" style="color:{color}">{name}</div>'
            f'<div style="position:relative">{bar(pct, color, tex, 15, 187, "1px solid #000", f"{pct}%")}{f}</div></div>')


def nameplates_page():
    stage = (plate("Ashen Brute", 72, "#ff4d5e", "+4") + plate("Ember Wisp", 100, "#ffc24b")
             + plate("Phoenix Guard", 46, "#3ddc97"))
    body = page_head("nameplates", "Nameplates", "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.")
    body += tabs(["Appearance", "Text", "Game settings"], 1)
    body += preview_card(f'<div class="plates">{stage}</div>', 110)
    body += card2("Text", [
        row("Health percent", tog(), "Show health percent on the bar."),
        row("Health text font", dd2("Barlow Condensed SemiBold", "F-BarlowCondSemiBold"), gear=cog(True)),
        row("Restyle names", tog(), "Use your font settings for the unit names above the plates."),
        row("Name font", dd2("Default"), gear=cog()),
        row("Enemy forces", tog(), "In Mythic+, how much enemy forces each mob is worth (+4) beside its health bar."),
        row("Enemy forces font", dd2("Default"), gear=cog()),
    ], wide=True)
    pop = popover("Health text font", [
        ("Font size", sl2(45, "11")), ("Outline", dd2("Outline")), ("Drop shadow", tog()),
        ("Text colour", sw("#eceef2") + btn("Reset", None, "ghost")), ("Position", dd2("Center")),
        ("Horizontal offset", sl2(50, "0")), ("Vertical offset", sl2(50, "0")),
    ], 810, 527, 340)
    # cog popovers live on UIParent (clamped to the screen), so this one may hang below the window
    return shell("nameplates", body, above=pop, head=faces(font_data()))


UNIT_ROWS = ["Player", "Target", "Focus", "Pet"]


def unitframe_sample():
    return f'''<div class="uf"><div class="ufp" style="background-image:url(../assets/emblem.png)"></div>
<div class="ufb"><div class="ufn"><span style="font-family:F-InterSemiBold">Phoenixia</span><span style="color:var(--warn)">90</span></div>
{bar(86, "#3fc7eb", "BarSmooth", 27, 227, "1px solid #ff6a1a", "55.2K", "big")}
{bar(64, "#4da3ff", "BarSmooth", 14, 227, "1px solid #000", "64%", "small")}</div></div>'''


def unitframes_page():
    body = page_head("unitframes", "Unit Frames", "Textures, colors and fonts for player, target, focus and pet.")
    scope = (f'<div class="scope"><div class="srow"><span class="slab">FRAME</span>{seg(UNIT_ROWS, 0)}'
             f'<span class="slab" style="margin-left:22px">APPLY TO</span>{seg(["This", "All", "Multiple"], 2)}</div>'
             f'<div class="srow"><span class="shint">Changes also go to the frames picked here</span>{seg(UNIT_ROWS, -1, (0, 1, 2))}</div>'
             f'<div class="srow"><span class="slab">APPLY ALL SETTINGS FROM</span>{dd2("Target")}{btn("Copy", "copy")}</div></div>')
    body += scope + preview_card(unitframe_sample(), 120)
    left = card2("Bars", [
        row("Phoenix bar texture", tog(), "Use the bar texture from General."),
        row("Bar texture", dd2("Smooth", tex="BarSmooth")),
        row("Health bar border", dd2("Glow"), gear=cog()),
        row("Background opacity", sl2(60, "60%"), gear=cog()),
    ]) + card2("Colours", [
        row("Class-colored health", tog(), "Color player health bars by class."),
        row("Power colors", tog(), "Color power bars by resource type."),
    ])
    right = card2("Text", [
        row("Phoenix fonts", tog(), "Use the unit font for names and values."),
        row("Name font", dd2("Inter SemiBold", "F-InterSemiBold"), gear=cog()),
        row("Health text font", dd2("Barlow Condensed Bold", "F-BarlowCondBold"), gear=cog()),
        row("Power text font", dd2("Default"), gear=cog()),
    ])
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("unitframes", body, status="Applied to Player, Target and Focus", status_icon="success", status_cls="ok",
                 head=faces(font_data()))


def general_page(picker):
    fonts, bars = font_data(), bar_data()
    body = page_head("general", "General", "Theme, fonts and textures shared by every module.")
    sample = (f'<div class="tpv"><div class="tph">SECTION HEADING</div><div class="tpb">Option label in the interface font</div>'
              f'<div class="tpd">Descriptions and hints use the lighter weight.</div></div><div class="tpbars">'
              + bar(82, "#ff6a1a", "BarSatin", 16, 300, text="82%") + bar(64, "#3ddc97", "BarSatin", 16, 300, text="64%")
              + bar(40, "#4da3ff", "BarSatin", 16, 300, text="40%") + "</div>")
    body += preview_card(f'<div class="theme">{sample}</div>', 120)
    left = card2("Appearance", [
        row("Theme", dd2("Phoenix Ember"), "Accent colour for every Phoenix element."),
        row("Bar texture", dd2("Satin", tex="BarSatin"), "Status bar texture for unit frames, cast bars, nameplates and meters.",
            hl=picker == "bar"),
    ])
    right = card2("Typography", [
        row("UI font", dd2("Inter Medium", "F-InterMedium"), "Font used for labels and text Phoenix draws."),
        row("Unit font", dd2("Barlow Condensed SemiBold", "F-BarlowCondSemiBold"), "Font used for names and numbers on frames.",
            hl=picker == "font"),
        row("Font scale", sl2(33, "100%"), "Scales every Phoenix font."),
    ])
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    if picker == "font":
        # type-to-filter, a heading per family, every name drawn in its own face (UI/Widgets/Dropdown.lua, preview = "font")
        items, last = [], None
        for f in fonts:
            if "cond" not in f["name"].lower():
                continue
            if f["family"] != last:
                items.append(f'<div class="ph">{f["family"].upper()}</div>')
                last = f["family"]
            on = f["key"] == "BarlowCondSemiBold"
            items.append(f'<div class="pi{" on" if on else ""}" style="font-family:F-{f["key"]}">{f["name"]}'
                         f'{ico("check", "xs") if on else ""}</div>')
        pop = (f'<div class="pick" style="left:944px;top:507px;width:240px"><div class="pin focus">{ico("search", "xs")}cond<span class="caret"></span></div>'
               + "".join(items[:11]) + '<div class="pthumb"></div></div>')
    else:
        # the shipped statusbars as accent-tinted strips with the name on top (preview = "bar")
        rows = "".join(f'<div class="pb{" on" if b["key"] == "Satin" else ""}"><span class="pbs" style="background-image:url(../assets/bars/{b["file"]}.png)"></span>'
                       f'<span class="pbl">{b["name"]}</span>{ico("check", "xs") if b["key"] == "Satin" else ""}</div>' for b in bars[:11])
        pop = (f'<div class="pick bars" style="left:528px;top:513px;width:210px"><div class="pin">{ico("search", "xs")}Filter</div>'
               f'<div class="ph">PHOENIX</div>{rows}<div class="pthumb"></div></div>')
    # dropdown popups are parented to UIParent, so they may hang below the settings window
    return shell("general", body, above=pop, head=faces(fonts))


def media_sheet():
    """Close-up of everything the addon ships: the font families (each in its own face) and the statusbars."""
    fonts, bars = font_data(), bar_data()
    fams = {}
    for f in fonts:
        fams.setdefault(f["family"], []).append(f)
    cells = []
    for fam, fs in fams.items():
        mid = next((f for f in fs if f["weight"] in ("Medium", "Regular", "SemiBold")), fs[0])
        cyr = " · Кириллица" if fs[0]["cyr"] else ""
        cells.append(f'<div class="fc"><div class="fs" style="font-family:F-{mid["key"]}">{fam}</div>'
                     f'<div class="fw">{" · ".join(f["weight"] for f in fs)}{cyr}</div>'
                     f'<div class="fx" style="font-family:F-{fs[-1]["key"]}">Pyroblast 1.24M 87% +4</div></div>')
    strips = "".join(f'<div class="bs"><span class="bsb" style="background-image:url(../assets/bars/{b["file"]}.png)"><b>{b["name"]}</b></span>'
                     f'<span class="bst">{b["style"]}</span></div>' for b in bars)
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css">{faces(fonts)}</head>
<body class="media"><div class="world"></div><div class="sheet">
<div class="ihead"><div class="ilogo"></div><div class="imeta"><b>Fonts and textures</b>
<i>{len(fonts)} font files in {len(fams)} families plus the Roboto / Roboto Condensed core set (SIL OFL 1.1, Ubuntu Font Licence) and {len(bars)} original statusbars, registered with LibSharedMedia as "Phoenix …".</i></div></div>
<div class="sech" style="padding-left:0;margin-top:14px">Fonts</div><div class="fgrid">{"".join(cells)}</div>
<div class="sech" style="padding-left:0;margin-top:8px">Statusbars</div><div class="bgrid">{strips}</div></div></body></html>'''


PAGES = {"home": home, "module": tooltip, "search": search_page, "profiles": profiles, "icons": icons_page,
         "bugs": bugs_page, "movers": movers_page, "mplus": mplus_page, "nameplates": nameplates_page,
         "unitframes": unitframes_page, "fonts": lambda: general_page("font"),
         "textures": lambda: general_page("bar"), "media": media_sheet}
SIZES = {"icons": ("1280,1240", "2"), "media": ("1280,1420", "1")}

if __name__ == "__main__":
    export_bars()
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn(), encoding="utf-8")
        png = OUT / f"{name}.png"
        size, dpr = SIZES.get(name, ("1280,800", "1"))
        subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={size}", f"--force-device-scale-factor={dpr}",
                        f"--screenshot={png}", html.as_uri()], check=True, capture_output=True)
        print(png.relative_to(ROOT))
