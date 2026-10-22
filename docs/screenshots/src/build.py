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

# The 13 sidebar groups of UI/Config/Groups.lua: (key, label, icon, entries); entries are (key, label, icon, on)
# with on = None for pages without an enable switch.
SIDEBAR = [
    ("home", "Home", "home", [("home", "Home", "home", None)]),
    ("general", "General", "general", [("general", "General", "general", None)]),
    ("appearance", "Appearance & Media", "theme", [("fonts", "Fonts", "fonts", None), ("textures", "Textures", "textures", None),
                                                   ("sounds", "Sounds", "sound", None)]),
    ("unitframes", "Unit Frames", "unitframes", [("unitframes", "Unit Frames", "unitframes", True),
                                                 ("groupframes", "Group Frames", "groupframes", True)]),
    ("nameplates", "Nameplates", "nameplates", [("nameplates", "Nameplates", "nameplates", True)]),
    ("actionbars", "Action Bars & Cooldowns", "actionbars", [("actionbars", "Action Bars", "actionbars", True),
                                                             ("cooldowntext", "Cooldown Text", "cooldowntext", True)]),
    ("combat", "Combat", "cat-combat", [("castbars", "Cast Bars", "castbars", True), ("auras", "Buffs & Debuffs", "auras", True),
                                        ("tracker", "Auras & Cooldowns", "tracker", True),
                                        ("encounters", "Encounters", "encounters", True),
                                        ("combattext", "Combat Text", "combattext", None),
                                        ("spellhistory", "Spell History", "spellhistory", False),
                                        ("damagemeter", "Damage Meter", "damagemeter", True)]),
    ("group", "Group & Mythic+", "mythicplus", [("mythicplus", "Mythic+", "mythicplus", True), ("pvp", "PvP", "pvp", True)]),
    ("social", "Chat & Social", "chat", [("chat", "Chat", "chat", True), ("afk", "AFK Screen", "afk", True)]),
    ("maps", "Maps, Minimap & Data", "maps", [("minimap", "Minimap", "minimap", True), ("datatexts", "Data Bar", "datatexts", True)]),
    ("items", "Tooltips & Items", "items", [("tooltip", "Tooltip", "tooltip", True), ("itemlevel", "Item Level", "itemlevel", True),
                                            ("bags", "Bags", "items", True)]),
    ("qol", "Quality of Life", "quality", [("quality", "Quality of Life", "quality", True),
                                           ("automation", "Automation", "automation", True), ("skins", "Skins", "skins", True)]),
    ("tools", "Tools", "cat-utility", [("movers", "Movers", "movers", True), ("profiles", "Profiles", "profiles", None),
                                       ("presets", "Presets", "presets", None), ("bugs", "Bugs", "bugs", True),
                                       ("diagnostics", "Diagnostics", "diagnostics", None), ("about", "About", "about", None)]),
]
HIDDEN = set()  # entries not shipped yet


def ico(name, cls="", size=None):
    i = INDEX[name]
    col, row = i % COLS, i // COLS
    inner = CELL - 2 * GUTTER
    x, y = -(col * CELL + GUTTER) / inner, -(row * CELL + GUTTER) / inner
    s = f";--s:{size}px" if size else ""
    return f'<span class="ico {cls}" style="--x:{x:.5f};--y:{y:.5f}{s}"></span>'


def sidebar(active, scroll=0, expand=()):
    rows = []
    for gkey, glabel, gicon, entries in SIDEBAR:
        entries = [e for e in entries if e[0] not in HIDDEN]
        if len(entries) == 1:
            key, _, _, on = entries[0]
            dot = "" if on is None else f'<span class="dot{"" if on else " off"}"></span>'
            rows.append(f'<div class="gh single{" active" if key == active else ""}">{ico(gicon)}{glabel}{dot}</div>')
            continue
        has = any(e[0] == active for e in entries)
        open_ = has or gkey in expand
        rows.append(f'<div class="gh{" open" if open_ else ""}{" lit" if has else ""}">{ico(gicon)}{glabel}'
                    f'{ico("chevron-down" if open_ else "chevron-right", "chev")}</div>')
        if open_:
            for key, label, icon, on in entries:
                dot = "" if on is None else f'<span class="dot{"" if on else " off"}"></span>'
                rows.append(f'<div class="nav sub{" active" if key == active else ""}">{ico(icon)}{label}{dot}</div>')
            rows.append('<div style="height:4px"></div>')
    return (f'<div class="side"><div style="margin-top:-{scroll}px">{"".join(rows)}</div>'
            '<div style="position:absolute;right:3px;top:12px;width:3px;height:180px;background:#2a2e37"></div></div>')


def shell(active, body, search="Search settings…", focus=False, status="Changes apply instantly", scroll=0, overlay="",
          status_icon="preview", status_cls="", head="", above="", expand=()):
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css">{head}</head>
<body><div class="world"></div><div class="win">
<div class="hdr"><div class="emblem"></div><div class="brand">PHOENIX</div><div class="brand-ui">UI</div>
<span class="badge">v2.0.0-beta1</span>
<div class="search{" focus" if focus else ""}">{ico("search")}{search}</div>
<div class="ibtn">{ico("editmode")}</div><div class="ibtn">{ico("reload")}</div><div class="ibtn">{ico("close")}</div></div>
{sidebar(active, scroll, expand)}
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
    body = (hero + f'<div style="display:flex;gap:12px;margin:14px 0">{chips}</div>' + week_card()
            + '<div class="sech" style="padding:4px 0 10px">Modules</div>'
            f'<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">{grid}</div>')
    return shell("home", body, head=WEEK_CSS)


WEEK_CSS = """<style>
.wk{border:1px solid var(--border);background:var(--bg-raised);padding:12px 16px;margin:0 0 14px;display:grid;grid-template-columns:1fr 1fr 1fr 1.25fr;gap:18px}
.wkh{grid-column:1/-1;font-family:CondBold;font-size:10.5px;letter-spacing:1.6px;color:var(--muted);margin-bottom:-8px}
.wkt b{display:block;font-family:CondSemi;font-size:13px;font-weight:normal;color:var(--text)}
.wkp{display:flex;gap:6px;margin:8px 0 6px} .wkp i{width:30px;height:8px;background:var(--bg-sunken);border:1px solid #000}
.wkp i.on{background:var(--accent);box-shadow:0 0 8px rgba(255,106,26,.45)}
.wkt span{font-family:Roboto;font-size:11.5px;color:var(--text2)}
.wks{border-left:1px solid var(--border);padding-left:18px} .wks .rt{font-family:CondBold;font-size:26px;color:#ff8000;line-height:28px}
.wks .lb{font-family:Cond;font-size:10.5px;letter-spacing:1px;color:var(--muted);text-transform:uppercase}
.wks .sub{font-family:Roboto;font-size:11.5px;color:var(--text2);margin-top:4px}
</style>"""


def week_card():
    tracks = [("Dungeons", 2, "6 / 8 runs · next at 8"), ("Raid", 1, "3 / 4 bosses · next at 4"), ("World", 3, "All unlocked")]
    cells = "".join(f'<div class="wkt"><b>{n}</b><div class="wkp">{"".join(f"<i class={chr(34)}on{chr(34)}></i>" if k < on else "<i></i>" for k in range(3))}</div>'
                    f'<span>{t}</span></div>' for n, on, t in tracks)
    return (f'<div class="wk"><div class="wkh">THIS WEEK</div>{cells}<div class="wks"><div class="lb">Mythic+ rating</div>'
            '<div class="rt">2,846</div><div class="sub">6 runs this week · best +14</div></div></div>')


def vault_page():
    page = home()
    # scroll past the hero so the weekly card sits under the stats, as after a short scroll in game
    assert '</div>\n<div class="ftr">' in page
    return page.replace('<div class="content">', '<div class="content"><div style="margin-top:-164px">', 1).replace(
        '</div>\n<div class="ftr">', '</div></div>\n<div class="ftr">', 1)


TT_CSS = """<style>
.tt{position:relative;width:250px;padding:10px 10px 8px;background:rgba(10,11,14,.94);border:1px solid #3fc7eb;font-family:F-InterRegular;font-size:12px;line-height:15px}
.tt b{display:block;font-family:F-InterSemiBold;font-size:14px;color:#3fc7eb;margin-bottom:3px;font-weight:normal}
.tt span{display:block;margin-top:3px;color:var(--text)} .tt .g{color:var(--ok)} .tt .a{color:var(--accent2)} .tt .r{color:var(--danger)}
.ttbar{position:absolute;left:2px;right:2px;bottom:-8px}
</style>"""


def tooltip_sample():
    return (f'<div style="display:grid;place-items:center;height:100%"><div class="tt"><b>Phoenixia</b>'
            '<span class="g">&lt;Ashes of Al&#39;ar&gt;</span><span>Level 90 Blood Elf Mage</span><span>Damage</span>'
            '<span>Mythic+ rating: <em class="a" style="font-style:normal">3,105</em></span>'
            '<span>Target: <em class="r" style="font-style:normal">Ashen Brute</em></span>'
            f'<div class="ttbar">{bar(82, "#3ddc97", "BarSatin", 6, 246, "1px solid #000")}</div></div></div>')


def tooltip(highlight=False, search="Search settings…", focus=False):
    body = page_head("tooltip", "Tooltip", "A cleaner tooltip with class borders, health bar and extra lines.")
    body += tabs(["Appearance", "Content"], 0)
    body += preview_card(tooltip_sample(), 176)
    left = card2("Style", [
        row("Phoenix style", tog(), "Dark background and thin border."),
        row("Health bar", tog(), "Restyle the unit health bar."),
        row("Bar texture", dd2("Satin", tex="BarSatin")),
        row("Bar height", sl2(30, "6")),
        row("Class border", tog(), "Color the border by the player's class.", hl=highlight),
        row("Item quality border", tog(), "Color the border by item quality."),
    ])
    right = card2("Text", [
        row("Restyle tooltip text", tog(), "Use your fonts for every tooltip line."),
        row("Title font", dd2("Inter SemiBold", "F-InterSemiBold"), gear=cog()),
        row("Line font", dd2("Inter", "F-InterRegular"), gear=cog()),
    ])
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("tooltip", body, search=search, focus=focus, head=faces(font_data()) + TT_CSS)


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
    ("Pages & modules", lambda n: INDEX[n] < INDEX["cat-combat"]),
    ("Groups & brand", lambda n: n.startswith("cat-")),
    ("Actions & controls", lambda n: INDEX["search"] <= INDEX[n] < INDEX["fps"]),
    ("Data bar & fallback", lambda n: INDEX["fps"] <= INDEX[n] <= INDEX["question"]),
    ("Bugs", lambda n: INDEX["bugs"] <= INDEX[n] < INDEX["movers"]),
    ("Movers & Mythic+", lambda n: INDEX["movers"] <= INDEX[n] < INDEX["cog"]),
    ("Options 2.0", lambda n: INDEX[n] >= INDEX["cog"]),
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
    bosses = [("Vexamus", "5:58", True, '<em class="dg">-0:21</em>'), ("Overgrown Ancient", "12:40", True, '<em class="dr">+0:34</em>'),
              ("Crawth", "", False, '<em class="dm">19:05</em>'), ("Echo of Doragosa", "", False, '<em class="dm">27:40</em>')]
    rows = "".join(f'''<div class="mprow"><span style="color:{"var(--ok)" if done else "var(--muted)"}">{ico("boss", "sm")}</span>
<span class="mpl" style="color:{"var(--text2)" if done else "var(--text)"}">{name}</span>{d}<span class="mpv" style="color:{"var(--ok)" if done else "var(--text2)"}">{at}</span></div>'''
                   for name, at, done, d in bosses)
    timer = f'''<div class="mpt">
<div style="display:flex;align-items:center;gap:8px"><span class="mplvl">+12</span><span class="mpname">Algeth&#39;ar Academy</span>
<span style="margin-left:auto;color:var(--danger)">{ico("deaths", "sm")}</span><span class="mpnum">3&nbsp;&nbsp;−15s</span></div>
<div class="mpaff">Fortified&nbsp;&nbsp;·&nbsp;&nbsp;Bolstering</div>
<div style="display:flex;align-items:baseline;margin-top:8px"><span class="mpclock">18:24</span><span class="mplim">/ 33:00</span>
<span class="mppb">Best 28:32</span></div>
<div class="mpbar"><span style="width:55.8%"></span><i style="left:60%"></i><i style="left:80%"></i></div>
<div class="mpchest">{chest}</div>
<div class="mprow" style="margin-top:10px"><span style="color:var(--muted)">{ico("forces", "sm")}</span><span class="mpl">Enemy forces</span>
<span class="mpv" style="color:var(--text)">72.40% <span style="color:var(--accent2)">+4.10%</span></span></div><div class="mpfb"><span style="width:72.4%"></span></div>{rows}</div>'''
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
.mprow em{font-style:normal;font-family:CondSemi;font-size:11px} .dg{color:var(--ok)} .dr{color:var(--danger)} .dm{color:var(--muted)}
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


def preview_card(stage, h, chips=None, stuck=False):
    if chips:
        tools = '<span class="chips">' + "".join(f'<span class="{"on" if on else ""}">{ico(i)}{t}</span>' for t, i, on in chips) + "</span>"
    else:
        tools = '<span class="hint">Sample data, redrawn as you change settings</span>'
    return (f'<div class="sec pv{" stuck" if stuck else ""}"><div class="sech i">{ico("preview")}Live preview'
            f'<span class="tools">{tools}<span class="fold">{ico("hide")}</span></span></div>'
            f'<div class="stage" style="height:{h}px">{stage}</div></div>')


def card2(title, rows, wide=False, icon=None, reset=False):
    head = f'<div class="sech i">{ico(icon)}{title}</div>' if icon else f'<div class="sech">{title}</div>'
    r = f'<span class="secr">{ico("reset")}</span>' if reset else ""
    return f'<div class="sec c2{" wide" if wide else ""}">{head}{r}{"".join(rows)}</div>'


def row(label, ctl, desc=None, gear=None, hl=False, reset=False):
    d = f"<i>{desc}</i>" if desc else ""
    r = f'<span class="rst">{ico("reset")}</span>' if reset else ""
    return (f'<div class="opt{" d" if desc else ""}{" hl" if hl else ""}"><div class="l"><b>{label}</b>{d}</div>'
            f'<div class="ctl c2">{r}{gear or ""}{ctl}</div></div>')


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


def nameplates_page(pinned=False):
    stage = (plate("Ashen Brute", 72, "#ff4d5e", "+4") + plate("Ember Wisp", 100, "#ffc24b")
             + plate("Phoenix Guard", 46, "#3ddc97"))
    body = page_head("nameplates", "Nameplates", "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.")
    chips = [("Low health", "warning", True), ("Targeted", "nameplates", True)] if pinned else None
    if pinned:
        body = preview_card(f'<div class="plates">{stage}</div>', 110, chips, stuck=True)
        body += card2("Bar", [
            row("Bar texture", dd2("Ember", tex="BarEmber"), reset=True),
            row("Health bar height", sl2(55, "12"), reset=True),
            row("Target highlight", dd2("Glow")),
        ], wide=True, reset=True)
    else:
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
    if pinned:
        return shell("nameplates", body, head=faces(font_data()), status="Preview pinned while you scroll", status_icon="preview")
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


def mlink():
    return f'<span class="lnk">{ico("arrow-right")}</span>'


def font_cards(fonts, sel, hover, n=12):
    cards = []
    for f in fonts[:n]:
        cls = " on" if f["key"] == sel else (" hov" if f["key"] == hover else "")
        ok = f'<span class="ok">{ico("check")}</span>' if f["key"] == sel else ""
        cards.append(f'<div class="mc font{cls}"><span class="nm">{f["name"]}</span>{ok}'
                     f'<span class="smp" style="font-family:F-{f["key"]}">Pyroblast 1.24M  87%  +4</span></div>')
    return "".join(cards)


def bar_cards(bars, sel, hover, n=18):
    cards = []
    for b in bars[:n]:
        cls = " on" if b["key"] == sel else (" hov" if b["key"] == hover else "")
        ok = f'<span class="ok">{ico("check")}</span>' if b["key"] == sel else ""
        cards.append(f'<div class="mc bar{cls}"><span class="strip" style="background-image:url(../assets/bars/{b["file"]}.png)"></span>'
                     f'<span class="nm">{b["name"]}</span>{ok}</div>')
    return "".join(cards)


def appearance_page(kind):
    fonts, bars = font_data(), bar_data()
    if kind == "font":
        body = page_head("fonts", "Fonts", "Every font Phoenix draws, gathered in one place.", toggle=False, state="")
        spec = ('<div class="spec"><div class="big" style="font-family:F-InterSemiBold">Phoenixia  55.2K  86%</div>'
                '<div class="small" style="font-family:F-InterSemiBold">The quick ember fox jumps over the lazy wyrm. 0123456789</div>'
                '<span class="nm">INTER SEMIBOLD</span></div>')
        top = card2("Everywhere at once", [spec, row("Font for every element", dd2("Inter SemiBold", "F-InterSemiBold")
                                                    + btn("Apply to all", "check") + btn("Use theme", "theme", "ghost"))],
                    wide=True, icon="fonts")
        mods = [("Unit Frames", "unitframes", [("Name font", "Inter SemiBold", "F-InterSemiBold", "Applies to Player, Target, Focus, Pet"),
                                              ("Health text font", "Barlow Condensed Bold", "F-BarlowCondBold", None)]),
                ("Nameplates", "nameplates", [("Health text font", "Barlow Condensed SemiBold", "F-BarlowCondSemiBold", None),
                                              ("Name font", "Default", None, None)]),
                ("Cast Bars", "castbars", [("Spell name font", "Default", None, None), ("Timer font", "Default", None, None)])]
        cards = "".join(card2(t, [row(l, dd2(v, face), desc=d, gear=mlink(), reset=v != "Default") for l, v, face, d in rs], icon=i)
                        for t, i, rs in mods)
        grid = font_cards(fonts, "InterSemiBold", "BarlowCondSemiBold")
        pop = (f'<div class="mp" style="left:520px;top:300px"><div class="mph"><span class="input">{ico("search", "xs")}&nbsp;Filter fonts</span>'
               f'{dd2("All styles")}<span class="cnt">{len(fonts)} fonts</span></div><div class="mpg c2">{grid}</div><div class="mpthumb"></div></div>')
        return shell("fonts", body + top + cards, above=pop, head=faces(fonts),
                     status="Hover a font to try it on every element", status_icon="preview")
    body = page_head("textures", "Textures", "Every bar texture Phoenix uses, gathered in one place.", toggle=False, state="")
    sample = ('<div class="tpbars" style="padding:14px 24px">' + bar(82, "#ff6a1a", "BarGlass", 18, 520, text="Health 82%")
              + bar(64, "#4da3ff", "BarGlass", 18, 520, text="Mana 64%") + bar(40, "#ffc24b", "BarGlass", 18, 520, text="Cast 1.2s") + "</div>")
    top = card2("Everywhere at once", [sample, row("Texture for every bar", dd2("Glass", tex="BarGlass")
                                                  + btn("Apply to all", "check") + btn("Use theme", "theme", "ghost"))],
                wide=True, icon="textures")
    mods = [("Unit Frames", "unitframes", [("Bar texture", "Smooth", "BarSmooth"), ("Power bar texture", "Default", None)]),
            ("Nameplates", "nameplates", [("Bar texture", "Ember", "BarEmber")])]
    cards = "".join(card2(t, [row(l, dd2(v, tex=tx), gear=mlink(), reset=tx is not None) for l, v, tx in rs], icon=i) for t, i, rs in mods)
    sel = next((b["key"] for b in bars if b["file"] == "BarSmooth"), "Smooth")
    hov = next((b["key"] for b in bars if b["file"] == "BarGlass"), "")
    pop = (f'<div class="mp" style="left:520px;top:330px"><div class="mph"><span class="input">{ico("search", "xs")}&nbsp;Filter textures</span>'
           f'{dd2("All styles")}<span class="cnt">{len(bars)} textures</span></div><div class="mpg c3">{bar_cards(bars, sel, hov)}</div>'
           '<div class="mpthumb"></div></div>')
    return shell("textures", body + top + cards, above=pop, head=faces(fonts), status="Glass previewed on the sample bars",
                 status_icon="preview")


def sidebar_shot():
    body = page_head("castbars", "Cast Bars", "Player, target and focus cast bars with latency and interrupt markers.")
    cast = ('<div class="tpbars" style="padding:30px 120px">' + bar(62, "#ffc24b", "BarSatin", 22, 520, text="Pyroblast  1.4 / 3.5")
            + bar(100, "#ff4d5e", "BarSatin", 22, 520, text="Interrupted") + "</div>")
    chips = [("Interrupted", "error", False)]
    body += tabs(["Player", "Target", "Focus"], 0) + preview_card(cast, 120, chips)
    body += card2("Bar", [row("Bar texture", dd2("Satin", tex="BarSatin")), row("Width", sl2(60, "260"), reset=True),
                          row("Latency marker", tog(), "Shades the part of the cast that your latency eats.")], wide=True)
    return shell("castbars", body, expand=("tools",), head=faces(font_data()))


def diagnostics_page():
    # mirrors UI/Config/Diagnostics.lua; the counts are what Core/Diag.lua checks (Core/TextureData.lua, icon tiers)
    import re
    tex = (ROOT / "Core" / "TextureData.lua").read_text(encoding="utf-8")
    n = {k: len(re.findall(r'file = "', tex.split(k + " = {")[1].split("\n    }")[0])) for k in ("bars", "glows", "borders")}
    kinds = [("icons", 3), ("brand", 5), ("bar", n["bars"]), ("glow", n["glows"]), ("border", n["borders"]), ("shape", 4)]
    total = sum(c for _, c in kinds)
    summary = "  ·  ".join(f"{k} {c}/{c}" for k, c in kinds)
    body = page_head("diagnostics", "Diagnostics", "Checks that every Phoenix file loaded, and builds a report for bug reports.",
                     toggle=False, state="")
    v = lambda t, w=False: f'<span class="val2"><span class="d{" w" if w else ""}"></span>{t}</span>'
    left = card2("Last check", [
        row("Last run", '<span class="val2">2026-10-22 14:05</span>'),
        row("Media files", v(f"{total} of {total} loaded")),
        row("Game client", '<span class="val2">12.1.5  ·  120105  ·  enUS</span>'),
        row("Display", '<span class="val2">2560x1440  ·  UI scale 0.71</span>'),
        row("Run the check", btn("Run", "diagnostics", "primary"), "Loads every Phoenix texture and compares its size with the file."),
    ], icon="diagnostics")
    right = card2("Icons", [
        row("Icon source", dd2("Automatic"), "Automatic uses the game's own icons only when the check finds that the Phoenix icon sheet did not load."),
        row("In use now", v("Phoenix icons")),
    ], icon="preview") + card2("Files by kind", [
        f'<div class="opt d"><div class="l"><b>Loaded</b><i>{summary}</i></div></div>',
    ], icon="textures")
    report = (f"Phoenix UI 2.0.0-beta1 · WoW 12.1.5 (120105) · enUS\nScreen 2560x1440 · UI scale 0.71 · icons: auto\n"
              f"Media {total}/{total} loaded · {summary.replace('  ·  ', ' · ')}\n"
              "glyph home Icons24 16x16 loaded=true visible=true alpha=1\nglyph general Icons24 16x16 loaded=true visible=true alpha=1")
    rep = card2("Report", ['<div class="opt"><div class="l"><i>Click in the box, select all and copy it into your bug report. '
                           'It holds no character or account names.</i></div></div>', f'<div class="ta">{report}</div>'],
                wide=True, icon="copy")
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>' + rep
    return shell("diagnostics", body, status="Check finished: everything loaded", status_icon="success", status_cls="ok")


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


KEYS_CSS = """<style>
.ks{width:420px;margin:0 auto;padding-top:8px} .ksr{display:flex;align-items:center;gap:10px;height:24px;border-bottom:1px solid rgba(255,255,255,.04);font-family:RobotoMedium;font-size:12.5px}
.ksr .n{width:130px} .ksr .k{flex:1;color:var(--text)} .ksr .k em{font-style:normal;font-family:CondSemi;color:var(--accent);margin-right:6px}
.ksr .r{font-family:CondSemi;width:60px;text-align:right} .ksr .mut{color:var(--muted)}
</style>"""


def keys_list():
    party = [("Phoenixia", "#3fc7eb", "14", "Ember Spire", "3,105", "#ff8000"),
             ("Ashbringer", "#f48cba", "12", "Ashen Vault", "2,640", "#a335ee"),
             ("Cindermaw", "#c69b6d", "10", "Cinder Deeps", "2,210", "#a335ee"),
             ("Emberleaf", "#ff7c0a", "", "", "1,880", "#0070dd"),
             ("Quickfuse", "#3fc7eb", None, "", "", "")]
    rows = []
    for n, c, lvl, dg, rt, rc in party:
        if lvl is None:
            k = '<span class="k mut">Unknown (no compatible addon)</span>'
        elif not lvl:
            k = '<span class="k mut">No keystone</span>'
        else:
            k = f'<span class="k"><em>+{lvl}</em>{dg}</span>'
        rows.append(f'<div class="ksr"><span class="n" style="color:{c}">{n}</span>{k}<span class="r" style="color:{rc or "var(--muted)"}">{rt}</span></div>')
    return f'<div class="ks">{"".join(rows)}</div>'


def keystones_page():
    body = page_head("mythicplus", "Mythic+", "Timer, keystone helpers and party keystones for Mythic+ dungeons.")
    body += preview_card(keys_list(), 140)
    left = card2("Mythic+ timer", [
        row("Run timer", tog(), "Clock against the +1, +2 and +3 limits, with the time left for each chest."),
        row("Boss splits", tog(), "Each boss with the run time it died at. Splits survive a reload."),
        row("Compare with your best run", tog(), "Ahead (green) or behind (red) against your fastest timed run of this dungeon and level.", hl=True),
        row("Current pull", tog(), "In combat, adds the forces of the enemies you are fighting to the forces line (+4.10%)."),
    ])
    right = card2("Party keystones", [
        row("Share keystones with the party", tog(), "With Phoenix UI, BigWigs, DBM or any LibKeystone addon. Only outside instances."),
        row("Ask the party", btn("Refresh", "reload"), "Requests every member's keystone again."),
    ])
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("mythicplus", body, head=KEYS_CSS)


# ---------------------------------------------------------------- Auras & Cooldowns, UF test mode, Presets
# Spell-like tiles: a coloured glow and a glyph from the same atlas (the real viewers show your spell icons).
SPELLS = [("#ff6a1a", "#5a1500", "cat-combat"), ("#ffb23f", "#4a2a00", "speed"), ("#b46bff", "#250a45", "theme"),
          ("#4da3ff", "#06203f", "opacity"), ("#3ddc97", "#063622", "heart"), ("#ff4d5e", "#3d0710", "warning"),
          ("#ffc24b", "#3b2a00", "spec"), ("#7fd8ff", "#06283a", "clock")]


def spell(i, size, timer="", count="", cd=0, square=True):
    c1, c2, g = SPELLS[i % len(SPELLS)]
    rad = "0" if square else "50%"
    ring = "" if square else '<span class="ring"></span>'
    sw_ = f'<span class="swipe" style="height:{cd}%"></span>' if cd else ""
    t = f'<b class="tm">{timer}</b>' if timer else ""
    n = f'<b class="ct">{count}</b>' if count else ""
    return (f'<span class="spl{"" if square else " rnd"}" style="width:{size}px;height:{size}px;border-radius:{rad};'
            f'background:radial-gradient(circle at 35% 30%, {c1}, {c2} 78%)">{ico(g, "", int(size * .52))}{sw_}{t}{n}{ring}</span>')


def tracker_page():
    body = page_head("tracker", "Auras & Cooldowns",
                     "Phoenix style for Blizzard's Cooldown Manager and fading out of combat.")
    scope = (f'<div class="scope"><div class="srow"><span class="slab">VIEWER</span>'
             f'{seg(["Essential", "Utility", "Buffs", "Bars"], 0)}</div></div>')
    essential = "".join(spell(i, 52, t, c, cd) for i, (t, c, cd) in enumerate(
        [("", "", 0), ("8", "", 62), ("", "", 0), ("24", "2", 30), ("", "", 0), ("1:12", "", 85), ("", "", 0)]))
    utility = "".join(spell(i + 3, 32, t, "", cd) for i, (t, cd) in enumerate([("", 0), ("41", 70), ("", 0), ("2:30", 90), ("", 0), ("", 0)]))
    bars = "".join(f'<div class="tbr">{spell(i, 22, "", c)}{bar(v, "#ff6a1a", "BarSatin", 18, 300, "1px solid #000")}'
                   f'<span class="tbn">{n}</span><span class="tbt">{t}</span></div>'
                   for i, (n, v, t, c) in enumerate([("Combustion", 82, "14.2", ""), ("Heating Up", 46, "6.8", "3"),
                                                     ("Arcane Intellect", 20, "2.1", "")]))
    del utility, bars  # the preview shows the viewer picked in the scope bar (Essential here)
    stage = f'<div class="trk one"><div class="trow">{essential}</div></div>'

    body += scope + tabs(["Appearance", "Text", "Behaviour"], 0) + preview_card(stage, 120)
    left = card2("Icons", [
        row("Phoenix style", tog(), "Dress the Cooldown Manager items: crop, border and fonts."),
        row("Square icons", tog(), "Square, cropped icons instead of Blizzard's round ones.", gear=cog()),
        row("Border", dd2("Solid"), gear=cog(), reset=True),
        row("Hide debuff border", tog(False)),
    ], icon="tracker", reset=True)
    right = card2("Out of combat", [
        row("Fade out of combat", tog(), "Dims the viewers until you enter combat."),
        row("Faded opacity", sl2(35, "0.35")),
    ], icon="tracker")
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("tracker", body, head=faces(font_data()), status="Viewer skin applied live", status_icon="success", status_cls="ok")


def uf_test_frame(tag, name, pct, color, hp, left, top, lvl="92", portrait="emblem"):
    return (f'<div class="uft" style="left:{left}px;top:{top}px"><span class="uftag">{ico("test", "xs")}{tag}</span>'
            f'<div class="uf static"><div class="ufp" style="background-image:url(../assets/{portrait}.png)"></div>'
            f'<div class="ufb"><div class="ufn"><span style="font-family:F-InterSemiBold">{name}</span><span style="color:var(--warn)">{lvl}</span></div>'
            f'{bar(pct, color, "BarSmooth", 22, 190, "1px solid #000", hp, "big")}'
            f'{bar(50, "#4da3ff", "BarSmooth", 11, 190, "1px solid #000", "", "small")}'
            f'<div class="ufa">{"".join(spell(i, 15, "", c) for i, c in enumerate(["", "2", "", "4"]))}</div></div></div></div>')


def uf_test_page():
    body = page_head("unitframes", "Unit Frames", "Textures, colours, portraits, icons, auras and fonts for your unit frames.")
    scope = (f'<div class="scope"><div class="srow"><span class="slab">FRAME</span>'
             f'{seg(["Player", "Target", "Focus", "Pet", "Boss"], 4)}</div></div>')
    body += scope + tabs(["Appearance", "Text"], 0)
    left = card2("Testing", [
        row("Test frames", btn("Hide test frames", "test", "primary"),
            "Shows sample target, focus and boss frames where the real ones sit. They close in combat."),
    ], icon="test") + card2("Portrait & icons", [
        row("Portrait", dd2("Class icon")),
        row("Leader icon", tog()), row("Raid marker", tog()), row("PvP icon", tog(False)),
    ])
    right = card2("Range", [
        row("Fade out of range", tog(), "Group members you target or focus fade when out of range.", gear=cog()),
    ]) + card2("Auras", [
        row("Phoenix aura icons", tog(), "Crops the icons under target, focus and boss frames."),
        row("Border", dd2("None"), gear=cog()),
    ])
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    frames = (uf_test_frame("TEST · Boss 1", "Ragnaros", 72, "#ff4d5e", "48.6M", 1236, 120, "??")
              + uf_test_frame("TEST · Boss 2", "Ashen Brute", 100, "#ff4d5e", "12.1M", 1236, 230, "??")
              + uf_test_frame("TEST · Target", "Ashen Brute", 58, "#ff4d5e", "1.24M", 1236, 470)
              + uf_test_frame("TEST · Focus", "Ember Wisp", 100, "#ffc24b", "410K", 1236, 600))
    wide = "<style>body{width:1560px}</style>"
    return shell("unitframes", body, above=frames, head=faces(font_data()) + wide,
                 status="Test frames shown; they close when combat starts", status_icon="test")


LOOKS = [("Ember", "The Phoenix default: ember accents, Satin bars, soft shadows.", "#ff6a1a", "#ffb23f", "BarSatin", "F-InterSemiBold", True),
         ("Clean", "Frost blue, flat bars, Inter fonts and crisp solid borders.", "#4da3ff", "#7fd8ff", "BarFlat", "F-InterSemiBold", False),
         ("Vivid", "Arcane violet, glossy bars, Barlow fonts and a soft glow.", "#b46bff", "#ff6ad5", "BarGloss", "F-BarlowCondBold", False)]


def look_card(name, desc, a1, a2, tex, face, on):
    bars = (bar(82, a1, tex, 16, 250, "1px solid #000") + bar(58, a2, tex, 10, 250, "1px solid #000")
            + bar(34, "#3ddc97", tex, 10, 250, "1px solid #000"))
    mark = f'<span class="ok">{ico("check")}</span>' if on else ""
    return (f'<div class="look{" on" if on else ""}"><div class="lstrip" style="background:linear-gradient(90deg,{a1},{a2})"></div>{mark}'
            f'<div class="lname" style="font-family:{face}">{name}</div><div class="lbars">{bars}</div>'
            f'<div class="ldesc">{desc}</div>{btn("Applied" if on else "Apply", "check" if on else "theme", "primary" if not on else "")}</div>')


def presets_page():
    body = page_head("presets", "Presets", "Complete looks in one click, with Undo.", toggle=False, state="")
    intro = ('<div class="pintro">Each look sets the theme colour, fonts and bar texture under General, the border style of auras, '
             'plates, cast bars, group frames and the tracker, and puts every font and texture row back on Default so it follows '
             'the look. Nothing else changes.</div>')
    looks = "".join(look_card(*l) for l in LOOKS)
    body += card2("Looks", [intro, f'<div class="looks">{looks}</div>'], wide=True, icon="presets")
    body += card2("Undo and welcome", [row("Undo the last preset", btn("Undo", "reset"), "Puts back every setting the last preset changed (this session)."),
                       row("Welcome picker", btn("Open", "presets"), "Opens the window new users see on their first login."),
                       row("Module picker", btn("Choose modules", "presets"), "Opens the module list new users see after picking a look.")],
                  wide=True)
    return shell("presets", body, head=faces(font_data()), status="Ember applied: 34 settings changed", status_icon="success",
                 status_cls="ok")

# ---------------------------------------------------------------- P2 item 10: bags, data bar order, minimap bin
QUAL = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee"}
BAG_ITEMS = [(0, 701, 4, "", True), (5, 0, 1, "20", False), (2, 688, 3, "", False), (3, 0, 2, "5", False),
             (6, 714, 4, "", True), (1, 0, 1, "200", False), (4, 672, 2, "", False), (7, 0, 3, "3", False),
             (0, 695, 4, "", False), (2, 0, 1, "12", False), (5, 0, 0, "8", False), None]


def bag_slot(it):
    if not it:
        return '<span class="bslot empty"></span>'
    i, lvl, q, cnt, up = it
    c1, c2, g = SPELLS[i % len(SPELLS)]
    border = QUAL[q] if q >= 2 else "#000"
    lv = f'<b class="blv" style="color:{QUAL[q]}">{lvl}</b>' if lvl else ""
    ct = f'<b class="bct">{cnt}</b>' if cnt else ""
    ar = f'<span class="bup">{ico("arrow-up", "", 14)}</span>' if up else ""
    return (f'<span class="bslot" style="border-color:{border};background:radial-gradient(circle at 35% 30%, {c1}, {c2} 78%)">'
            f'{ico(g, "", 20)}{lv}{ct}{ar}</span>')


def tip(title, lines, left, top):
    body = "".join(f"<i>{l}</i>" for l in lines)
    return f'<div class="rtip" style="left:{left}px;top:{top}px"><b>{title}</b>{body}</div>'


def bags_page():
    body = page_head("items", "Bags", "Phoenix look for the bag windows, quality borders and upgrade arrows on better gear.")
    slots = "".join(bag_slot(it) for it in BAG_ITEMS)
    stage = f'<div class="bwin"><div class="bwt">Backpack</div><div class="bgrid">{slots}</div></div>'
    body += preview_card(stage, 170)
    left = card2("Look", [
        row("Phoenix bag windows", tog(), "Themed panel behind the bags, cropped icons with thin borders and a dark slot background."),
        row("Quality borders", tog(), "Colour the border of uncommon and better items by quality."),
        row("Stack count size", sl2(40, "12")),
    ], icon="items", reset=True)
    right = card2("On the items", [
        row("Upgrade arrows", tog(), "A green arrow on gear you can use with a higher item level than what you wear in that slot.", hl=True),
        row("Item level on gear", tog(), "Same switch as Item Level › Bags; size and colour are set there.",
            gear=f'<span class="cog">{ico("chevron-right")}</span>'),
    ], icon="itemlevel")
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    over = tip("Upgrade arrows", ["Default: On", "Right-click the row to reset it."], 682, 335)
    return shell("bags", body, overlay=over, head=faces(font_data()), status="Bag windows restyled live", status_icon="success",
                 status_cls="ok")


DT = [("fps", "fps", "144", "fps", ""), ("latency", "latency", "38", "ms", "ok"), ("items", "bags", "24", "free", "ok"),
      ("itemlevel", "itemlevel", "712.4", "ilvl", ""), ("friends", "friends", "7", "online", ""), ("guild", "guild", "31", "online", ""),
      ("mail", "mail", "New", "", "ok"), ("clock", "clock", "21:42", "", ""), ("bugs", "bugs", "0", "bugs", "ok")]
CHIPS = [("fps", "Frame rate", True), ("latency", "Latency", True), ("items", "Free bag slots", True), ("itemlevel", "Item level", True),
         ("friends", "Friends online", True), ("guild", "Guild online", True), ("mail", "Mail", True), ("speed", "Movement speed", False),
         ("durability", "Durability", False), ("gold", "Gold", False), ("clock", "Clock", True), ("bugs", "Bug count", True)]


def databar_page():
    body = page_head("datatexts", "Data Bar",
                     "A slim bar of live info — FPS, latency, gold, bags, friends and more — in the order you choose.")
    segs = "".join(f'<span class="dts">{ico(i, "", 13)}<b class="{c}">{v}</b><i>{u}</i></span>' for i, _, v, u, c in DT)
    body += preview_card(f'<div class="dtbar">{segs}</div>', 90)
    chips = ""
    for n, (i, label, on) in enumerate(CHIPS):
        mark = '<span class="dmark"></span>' if n == 2 else ""
        drag = " drag" if n == 9 else ""
        chips += f'{mark}<span class="dchip{"" if on else " off"}{drag}">{ico(i, "", 13)}{label}</span>'
    order = (f'<div class="opt d full"><div class="l"><b>Order</b><i>Drag the segments into the order the bar shows them. '
             f'Dimmed ones are switched off.</i></div><span class="rst">{ico("reset")}</span><div class="dchips">{chips}</div></div>')
    seg_rows = [row("Free bag slots", tog(), "Free slots across your bags; amber under 10, red under 3. Click to open your bags."),
                row("Item level", tog(), "Your equipped average item level. Click to open the character pane."),
                row("Friends online", tog(), "Friends and Battle.net friends online. Click to open the friends list."),
                row("Guild online", tog(), "Guild members online. Click to open the guild window."),
                row("Mail", tog(), "Lights up when new mail is waiting.")]
    body += card2("Segments", [order] + seg_rows, wide=True, icon="datatexts")
    return shell("datatexts", body, head=faces(font_data()), status="Order saved; the bar follows at once",
                 status_icon="success", status_cls="ok")


def minimap_page():
    body = page_head("minimap", "Minimap", "Square minimap, coordinates, a themed zone name and a bin for addon buttons.")
    cells = "".join(f'<span class="mcell">{ico(i, "", 13)}</span>' for i in ["items", "maps", "chat", "bugs", "tracker", "sound"])
    stage = (f'<div class="mmz">Silvermoon City</div><div class="mm"><span class="mlake"></span><span class="mroad"></span>'
             f'<span class="mbin">{ico("bin", "", 11)}</span><b class="mco">48.2  61.7</b></div><div class="mfly">{cells}</div>')
    body += preview_card(stage, 190)
    left = card2("Shape", [row("Square minimap", tog(), "Square mask with a thin border."),
                           row("Size", btn("Edit Mode", "editmode"), "Set in Edit Mode (Minimap › Size, 50–200 %)."),
                           row("Zone text", tog(), "Restyle the zone name.")], icon="minimap")
    right = card2("Button bin", [
        row("Collect addon buttons", tog(), "Gathers the minimap buttons other addons add (LibDBIcon) into one flyout opened from the corner glyph."),
        row("Columns", sl2(40, "3"), "Buttons per row in the flyout."),
        row("Open the bin", btn("Show", "bin"), "Shows the flyout now so you can check which buttons it holds."),
    ], icon="bin")
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("minimap", body, head=faces(font_data()), status="6 addon buttons in the bin", status_icon="bin")


# ---------------------------------------------------------------- Stage 1: Encounters, module picker
ENC_CSS = """<style>
.ebars{display:flex;flex-direction:column;gap:4px}
.ebar{position:relative;display:flex;align-items:center;height:22px;background:rgba(10,11,14,.55);border:1px solid #000}
.ebar .ei{width:22px;height:22px;flex:none;border-right:1px solid #000;display:flex;align-items:center;justify-content:center}
.ebar .ef{position:relative;flex:1;height:100%}
.ebar .ef>span{position:absolute;left:0;top:0;bottom:0;background-size:100% 100%;background-blend-mode:multiply}
.ebar .en{position:absolute;left:6px;top:3px;font-family:F-InterSemiBold;font-size:12px;color:#fff;text-shadow:1px 1px 0 #000}
.ebar .et{position:absolute;right:6px;top:3px;font-family:F-InterSemiBold;font-size:12px;color:#fff;text-shadow:1px 1px 0 #000}
.ebar.dim{opacity:.55}
.ewarn{font-family:F-InterBold;font-size:22px;text-align:center;text-shadow:2px 2px 0 #000,-1px -1px 0 #000;display:flex;align-items:center;justify-content:center;gap:8px}
.ewarn .wi{width:26px;height:26px;border:1px solid #000;display:inline-flex;align-items:center;justify-content:center}
.estage{position:absolute;left:0;right:0;top:0;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px}
.encnote{margin:0 0 10px;padding:9px 12px;border:1px solid rgba(77,163,255,.35);background:rgba(77,163,255,.08);font-size:12px;color:var(--text2);border-radius:3px}
.scene{position:absolute;left:1290px;top:0;width:270px;height:800px}
.scene .lbl{font-family:CondBold;font-size:11px;letter-spacing:.08em;color:var(--warn);margin:0 0 4px}
.mp{position:absolute;left:290px;top:120px;width:700px;background:#14161b;border:1px solid #2a2e37;box-shadow:0 18px 60px rgba(0,0,0,.7);border-radius:4px;z-index:5}
.mp .mph{display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid #2a2e37;font-family:F-InterBold;font-size:16px}
.mp .mpi{padding:10px 16px;color:var(--text2);font-size:12px}
.mp .mpg{display:grid;grid-template-columns:1fr 1fr;gap:6px 14px;padding:4px 16px 12px}
.mp .mpr{display:flex;align-items:center;gap:8px;padding:6px 8px;background:rgba(255,255,255,.025);border:1px solid rgba(255,255,255,.04);border-radius:3px}
.mp .mpr b{font-family:F-InterSemiBold;font-size:12px;display:block}.mp .mpr i{font-style:normal;font-size:10.5px;color:var(--text3)}
.mp .mpr .tx{flex:1;min-width:0}.mp .mpf{display:flex;justify-content:flex-end;gap:8px;padding:10px 16px;border-top:1px solid #2a2e37}
.dimall{position:absolute;inset:0;background:rgba(0,0,0,.55);z-index:4}
</style>"""
ENC_ICON = [("#ff6a1a", "#5a1500", "castbars"), ("#b46bff", "#250a45", "auras"), ("#ffc24b", "#3b2a00", "cat-combat"),
            ("#3ddc97", "#063622", "encounters"), ("#4da3ff", "#06203f", "break")]


def ebar(name, pct, left, i, color="#ff6a1a", dim=False, w=260):
    c1, c2, g = ENC_ICON[i % len(ENC_ICON)]
    return (f'<div class="ebar{" dim" if dim else ""}" style="width:{w}px"><span class="ei" style="background:radial-gradient(circle at 35% 30%, {c1}, {c2} 78%)">'
            f'{ico(g, "", 13)}</span><span class="ef"><span style="width:{pct}%;background-color:{color};'
            f'background-image:url(../assets/bars/BarSatin.png)"></span><b class="en">{name}</b><b class="et">{left}</b></span></div>')


def ewarn(text, color, size=22, icon="castbars"):
    return (f'<div class="ewarn" style="color:{color};font-size:{size}px"><span class="wi" style="background:radial-gradient(circle at 35% 30%, #ff6a1a, #5a1500 78%)">'
            f'{ico(icon, "", 15)}</span>{text}</div>')


def enc_sample_bars(w=260):
    return ('<div class="ebars">' + ebar("Pull", 48, "6", 4, "#4da3ff", w=w) + ebar("Crushing Slam", 66, "21", 2, w=w)
            + ebar("Shadow Volley", 30, "9.4", 1, w=w) + ebar("Searing Breath", 12, "3.2", 0, "#ff4d5e", w=w) + '</div>')


def encounters_page(tab=None):
    """tab None: top of the page (overview); otherwise scrolled to that tab with the preview pinned."""
    body = page_head("encounters", "Encounters",
                     "Boss timers and warnings in Phoenix style, pull and break timers, the countdown voice and a BigWigs bar style.")
    stage = f'<div class="estage">{ewarn("Searing Breath on you!", "#ff4d5e")}{enc_sample_bars()}</div>'
    body += preview_card(stage, 196, stuck=tab is not None)
    if tab is None:
        body += card2("Overview", [
            row("Boss warnings and timeline", tog(), "The game's master switch for boss timers and boss warnings (Options → Gameplay → Combat Warnings). "
            "Phoenix can only draw them while it is on."),
            row("Test", btn("Run test", "test", "primary"), "Puts the game's sample boss timers and warnings on screen for about 30 seconds, "
            "so you see your settings on the real bars."),
            '<div class="encnote">Boss timers and alerts come from the game itself (the encounter timeline). Spell names stay hidden from '
            'addons during a fight, so Phoenix shows them without reading them. Move the bars and the banner in Edit Mode.</div>',
        ], wide=True, icon="encounters")
    body += tabs(["Timeline", "Warnings", "Pull & break", "Sounds", "BigWigs"], tab or 0)
    if tab in (None, 0):
        left = card2("Boss timeline", [
            row("Show boss timers as", dd2("Phoenix"), "Phoenix bars replace the game's timeline: it is switched off while Phoenix draws "
                "and switched back on when you change this."),
            row("Hide long countdowns", tog(False), "Leaves out abilities that are still far away. Phoenix bars follow it too."),
            row("Hide queued abilities", tog(False), "Leaves out abilities whose timer ran out but which the boss has not cast yet."),
            row("Show cast counts", tog()),
            row("Role and effect icons", tog(), gear=cog()),
        ], icon="encounters", reset=True)
        right = card2("Phoenix bars", [
            row("Width", sl2(52, "260")), row("Height", sl2(30, "22")), row("Most bars shown", sl2(40, "8")),
            row("New bars", seg(["Grow up", "Grow down"], 0)),
            row("Bar texture", dd2("Satin", tex="BarSatin"), reset=True),
            row("Emphasise when close", tog(), "Recolours a bar in its last seconds.", gear=cog()),
            row("Ability name", dd2("Inter SemiBold", "F-InterSemiBold"), gear=cog()),
        ], icon="castbars", reset=True)
        status = "Phoenix draws the timeline; Blizzard's is off until you hand it back"
    else:
        left = card2("Pull timer", [
            row("Seconds", sl2(16, "10")),
            row("Start a pull", btn("Pull", "encounters", "primary"), "Starts the game's group countdown, which everyone and every boss mod "
                "sees. Needs leader or assist in a group. Also: /pui encounters pull 10"),
            row("Cancel the pull", btn("Cancel", "close"), "Stops a running pull countdown for the whole group."),
        ], icon="encounters")
        left += card2("Countdown voice", [
            row("Speak the countdown", tog(), "A voice counts the last seconds down to 1."),
            row("Voice", dd2("Jim")), row("Start at", sl2(40, "5")),
            row("Pull timers", tog(), "While DBM or BigWigs is loaded, their own voice counts instead."),
        ], icon="sound")
        right = card2("Break timer", [
            row("Minutes", sl2(8, "5")),
            row("Share with the group", tog(), "Sends the break so DBM, BigWigs and Phoenix users in your group see it too."),
            row("Start a break", btn("Break", "break", "primary"), "Also: /pui encounters break 5"),
            row("End the break", btn("Cancel", "close"), "Removes the break bar, and from the group when it was shared."),
        ], icon="break")
        status = "Pull and break timers reach DBM and BigWigs users too"
    body += f'<div class="cols"><div class="col">{left}</div><div class="col">{right}</div></div>'
    return shell("encounters", body, head=faces(font_data()) + ENC_CSS, status=status, status_icon="success", status_cls="ok")


def encounters_test():
    html = encounters_page()
    scene = ('<div class="scene"><div style="position:absolute;top:150px;left:0;right:0">'
             f'<div class="lbl">BOSS WARNINGS · TEST</div>{ewarn("Critical sample warning", "#ff4d5e", 20)}'
             f'{ewarn("Medium sample warning", "#ffc24b", 17)}{ewarn("Minor sample warning", "#ffffff", 14)}</div>'
             '<div style="position:absolute;top:470px;left:5px"><div class="lbl">BOSS TIMELINE · TEST</div><div class="ebars">'
             + ebar("Test 4", 92, "24", 3, w=260) + ebar("Test 3", 70, "18", 2, w=260) + ebar("Test 2", 40, "9.8", 1, dim=True, w=260)
             + ebar("Test 1", 14, "3.1", 0, "#ff4d5e", w=260) + '</div></div></div>')
    html = html.replace("</body>", scene + "<style>body{width:1560px}</style></body>")
    return html.replace("Phoenix draws the timeline; Blizzard's is off until you hand it back", "Test running: sample boss timers for about 30 seconds.")


MODPICK = [("unitframes", "Unit Frames", True), ("groupframes", "Group Frames", True), ("castbars", "Cast Bars", True),
           ("auras", "Buffs & Debuffs", True), ("nameplates", "Nameplates", True), ("tracker", "Auras & Cooldowns", True),
           ("encounters", "Encounters", True), ("damagemeter", "Damage Meter", False), ("spellhistory", "Spell History", False),
           ("items", "Bags", True), ("minimap", "Minimap", True), ("chat", "Chat", True), ("afk", "AFK Screen", False),
           ("mythicplus", "Mythic+", True)]
MODDESC = {"unitframes": "Textures, colors and fonts for player, target, focus and pet frames.",
           "groupframes": "Party and raid frame styling.", "castbars": "Flat cast bars with icon, timer and latency.",
           "auras": "Cropped icons, crisp borders and readable timers.",
           "nameplates": "Bar texture, health percent and Mythic+ enemy forces on Blizzard nameplates.",
           "tracker": "Phoenix style for Blizzard's Cooldown Manager and fading out of combat.",
           "encounters": "Boss timers and warnings in Phoenix style, pull and break timers, the countdown voice and a BigWigs bar style.",
           "damagemeter": "Phoenix skin for Blizzard's damage meter, plus an optional Details! style.",
           "spellhistory": "A strip of your most recent casts.",
           "items": "Phoenix look for the bag windows, quality borders and upgrade arrows on better gear.",
           "minimap": "Square minimap, coordinates, a themed zone name and a bin for addon buttons.",
           "chat": "Clickable links, copy, faster scrolling and an edit box history that survives a reload.",
           "afk": "A calm full-screen view of your character while you're away.",
           "mythicplus": "Run timer with chest limits, boss splits and enemy forces, plus keystone helpers."}


def modpicker_page():
    html = presets_page()
    rows = "".join(f'<div class="mpr">{ico(k)}<span class="tx"><b>{n}</b><i>{MODDESC[k]}</i></span>{tog(on)}</div>'
                   for k, n, on in MODPICK)
    pop = (f'<div class="dimall"></div><div class="mp"><div class="mph">{ico("presets")}Choose your modules</div>'
           '<div class="mpi">Everything is on by default. Switch off what you don\'t need; you can change it any time on the Home page '
           'or under Tools → Presets.</div>'
           f'<div class="mpg">{rows}</div><div class="mpf">{btn("Keep all", "close")}{btn("Apply and reload", "reload", "primary")}</div></div>')
    html = html.replace("</head>", ENC_CSS + "</head>").replace("</body>", pop + "</body>")
    return html.replace('row("Welcome picker"', 'row("Welcome picker"')


PAGES = {"home": home, "module": tooltip, "search": search_page, "profiles": profiles, "icons": icons_page,
         "bugs": bugs_page, "movers": movers_page, "mplus": mplus_page, "nameplates": nameplates_page,
         "unitframes": unitframes_page, "fonts": lambda: appearance_page("font"),
         "textures": lambda: appearance_page("bar"), "media": media_sheet, "pinned": lambda: nameplates_page(True),
         "diagnostics": diagnostics_page, "sidebar": sidebar_shot,
         "vault": vault_page, "keystones": keystones_page, "tracker": tracker_page, "uftest": uf_test_page,
         "presets": presets_page, "bags": bags_page, "databar": databar_page, "minimap": minimap_page,
         "encounters": encounters_page, "encounters_timeline": lambda: encounters_page(0), "encounters_timers": lambda: encounters_page(2), "encounters_test": encounters_test,
         "modpicker": modpicker_page}
SIZES = {"icons": ("1280,1240", "2"), "media": ("1280,1420", "1"), "uftest": ("1560,800", "1"), "encounters_test": ("1560,800", "1")}

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
