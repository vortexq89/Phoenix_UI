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
    ("System", [("general", "General", "general", True)]),
    ("Interface", [("skins", "Skins", "skins", True), ("actionbars", "Action Bars", "actionbars", True),
                   ("unitframes", "Unit Frames", "unitframes", True), ("groupframes", "Group Frames", "groupframes", True),
                   ("castbars", "Cast Bars", "castbars", True), ("auras", "Buffs & Debuffs", "auras", True),
                   ("nameplates", "Nameplates", "nameplates", True), ("tooltip", "Tooltip", "tooltip", True),
                   ("itemlevel", "Item Level", "itemlevel", True), ("minimap", "Minimap", "minimap", True),
                   ("datatexts", "Data Bar", "datatexts", True)]),
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
          status_icon="preview", status_cls=""):
    return f'''<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head>
<body><div class="world"></div><div class="win">
<div class="hdr"><div class="emblem"></div><div class="brand">PHOENIX</div><div class="brand-ui">UI</div>
<span class="badge">v2.0.0</span>
<div class="search{" focus" if focus else ""}">{ico("search")}{search}</div>
<div class="ibtn">{ico("editmode")}</div><div class="ibtn">{ico("reload")}</div><div class="ibtn">{ico("close")}</div></div>
{sidebar(active, scroll)}
<div class="content">{body}</div>{overlay}
<div class="ftr">{ico("profiles", "pico")}Profile: Default &nbsp;·&nbsp; 20 modules active<span class="mid {status_cls}">{ico(status_icon)}{status}</span>Phoenix UI · by VortexQ8<span class="grip">{ico("resize")}</span></div>
</div></body></html>'''


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
         ("nameplates", "Nameplates", "Interface", "Bar texture and health percent on Blizzard nameplates.", True),
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
        opt("Hide in combat", tog(False), "Hide unit tooltips while in combat."),
    ])
    body += section("Extra lines", [
        opt("Target", tog(), "Show what the unit is targeting."),
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
    ("Data bar & fallback", lambda n: INDEX[n] >= INDEX["fps"]),
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


PAGES = {"home": home, "module": tooltip, "search": search_page, "profiles": profiles, "icons": icons_page}
SIZES = {"icons": ("1280,1040", "2")}

if __name__ == "__main__":
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn(), encoding="utf-8")
        png = OUT / f"{name}.png"
        size, dpr = SIZES.get(name, ("1280,800", "1"))
        subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={size}", f"--force-device-scale-factor={dpr}",
                        f"--screenshot={png}", html.as_uri()], check=True, capture_output=True)
        print(png.relative_to(ROOT))
