#!/usr/bin/env python3
"""Bags, Data Texts and Skins (2.0 S13b) mockups: HTML mirroring Phoenix_UI_Options/Options/{Bags,DataTexts,Skins}.lua and
their Previews, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from
Locales/enUS.lua, the setting counts from the smoke harness ("bags, data texts and skins depth (S13b)"). Item icons,
panels and windows are CSS stand-ins for the game's art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s13b.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, COG, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["Bags"] = (53, 47)
s6.DEPTH["DataTexts"] = (67, 47)
s6.DEPTH["Skins"] = (34, 28)
OUT = SRC.parent
CSS = s9.CSS + ('<style>.bw{position:absolute;background:rgba(14,15,19,.94);box-shadow:0 0 0 1px #000,0 0 0 2px #2a2e36,0 8px 18px rgba(0,0,0,.6)}'
                '.bt{position:absolute;font-family:CondBold;font-size:13px;color:#ff6a1a}.sec{position:absolute;font-family:CondSemi;font-size:10px;'
                'color:#8a93a3;letter-spacing:.06em}.bslot{position:absolute;width:30px;height:30px;background:#0b0c0f;box-shadow:0 0 0 1px #23262d}'
                '.bslot i{position:absolute;inset:2px;border-radius:2px}.bslot b{position:absolute;right:2px;bottom:1px;font-family:CondBold;font-size:10px;'
                'color:#fff;text-shadow:1px 1px 0 #000}.bslot s{position:absolute;left:2px;top:1px;font-family:CondBold;font-size:9px;color:#ffd24a;'
                'text-decoration:none;text-shadow:1px 1px 0 #000}.dp{position:absolute;height:22px;background:rgba(14,15,19,.94);box-shadow:0 0 0 1px #000,'
                '0 0 0 2px #2a2e36;display:flex;align-items:center;gap:14px;padding:0 10px;font-family:CondSemi;font-size:12px;color:#e6e9ef;white-space:nowrap}'
                '.dp em{font-style:normal;color:#8a93a3;margin-left:3px}.chp{display:inline-flex;align-items:center;gap:4px;padding:3px 8px;margin:2px;'
                'background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;border-radius:3px;font-family:CondSemi;font-size:11px;color:#e6e9ef}'
                '.chp.off{opacity:.45}.swin{position:absolute;background:rgba(14,15,19,.94);box-shadow:0 0 0 1px #000,0 0 0 2px #2a2e36}'
                '.swin .swt{height:22px;background:#1a1d24;font-family:CondBold;font-size:12px;color:#ff6a1a;display:flex;align-items:center;padding:0 8px}'
                '.swin .swx{position:absolute;right:6px;top:4px;font-family:CondBold;font-size:12px;color:#8a93a3}'
                '.stab{position:absolute;bottom:-20px;height:18px;padding:0 9px;background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;font-family:CondSemi;'
                'font-size:10px;color:#8a93a3;display:flex;align-items:center}.stab.on{color:#ff6a1a;box-shadow:0 0 0 1px #ff6a1a}</style>')

Q = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee", 5: "#ff8000"}
FILL = ["#5a3d2b", "#2c4a5e", "#4b2c5e", "#2e5a3a", "#5e512c", "#3a2c5e", "#5e2c35", "#2c5e58"]


def slot(x, y, q=None, count=None, mark="", glow=False, dim=False, ilvl=None, up=False):
    if q is None:
        return f'<div class="bslot" style="left:{x}px;top:{y}px"></div>'
    c = Q[q]
    g = ",0 0 6px 2px #ff6a1a" if glow else ""
    o = "opacity:.45;" if dim else ""
    inner = f'<i style="background:{FILL[(x + y) % len(FILL)]}"></i>'
    if count:
        inner += f"<b>{count}</b>"
    if ilvl:
        inner += f"<s>{ilvl}</s>"
    if mark:
        inner += f'<span style="position:absolute;left:2px;bottom:1px;font-family:CondBold;font-size:8px;color:#ffd24a">{mark}</span>'
    if up:
        inner += '<span style="position:absolute;right:1px;top:0;color:#3ddc97;font-size:11px;font-family:CondBold">▲</span>'
    return f'<div class="bslot" style="left:{x}px;top:{y}px;box-shadow:0 0 0 1px {c}{g};{o}">{inner}</div>'


SECTIONS = [("NEW", [(4, None, "", True, None, True), (3, None, "BoE", True, "684", False)]),
            ("EQUIPMENT", [(4, None, "", False, "678", False), (3, None, "WuE", False, "671", False), (2, None, "", False, "655", False)]),
            ("CONSUMABLES", [(1, "20", "", False, None, False), (1, "4", "", False, None, False), (2, "12", "", False, None, False)]),
            ("REAGENTS", [(1, "200", "", False, None, False), (2, "86", "", False, None, False), (3, "17", "", False, None, False), (1, "5", "", False, None, False)]),
            ("JUNK", [(0, None, "", False, None, False), (0, "3", "", False, None, False)])]


def bag_window(x0=40, y0=10, cols=8, cats=True):
    out = ""
    w = cols * 33 + 14
    rows_html, y = "", 54
    secs = SECTIONS if cats else [("", [it for _, s in SECTIONS for it in s] + [None] * 4)]
    for name, items in secs:
        if name:
            rows_html += f'<div class="sec" style="left:{x0 + 8}px;top:{y0 + y}px">{name}</div>'
            y += 13
        for i, it in enumerate(items):
            sx, sy = x0 + 8 + (i % cols) * 33, y0 + y + (i // cols) * 33
            if it is None:
                rows_html += slot(sx, sy)
            else:
                q, cnt, mk, glow, il, up = it
                rows_html += slot(sx, sy, q, cnt, mk, glow, False, il, up)
                if q == 0:
                    rows_html += f'<div style="position:absolute;left:{sx + 2}px;top:{sy + 2}px;color:#ffd24a">{ico("gold", 10)}</div>'
        y += ((len(items) - 1) // cols + 1) * 33 + 4
    h = y + 30
    out += f'<div class="bw" style="left:{x0}px;top:{y0}px;width:{w}px;height:{h}px"></div>'
    out += rows_html
    out += f'<div class="bt" style="left:{x0 + 8}px;top:{y0 + 6}px">Bags</div>'
    out += f'<div style="position:absolute;left:{x0 + w - 18}px;top:{y0 + 4}px;font-family:CondBold;font-size:12px;color:#8a93a3">✕</div>'
    out += (f'<div style="position:absolute;left:{x0 + 8}px;top:{y0 + 26}px;width:{w - 44}px;height:20px;background:#0b0c0f;box-shadow:0 0 0 1px #2a2e36;'
            f'font-family:Roboto;font-size:11px;color:#8a93a3;display:flex;align-items:center;gap:5px;padding-left:5px">{ico("search", 10)}Search</div>')
    out += (f'<div style="position:absolute;left:{x0 + w - 30}px;top:{y0 + 26}px;width:22px;height:20px;background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;'
            f'display:flex;align-items:center;justify-content:center;color:#ff6a1a">{ico("filter", 11)}</div>')
    out += (f'<div style="position:absolute;left:{x0 + 8}px;top:{y0 + h - 22}px;width:{w - 16}px;display:flex;font-family:CondSemi;font-size:11px;color:#e6e9ef">'
            f'<span>12,483<span style="color:#ffd24a">g</span> 41<span style="color:#c7c7cf">s</span></span><span style="margin-left:12px;color:#8a93a3">◆ 2,150</span>'
            f'<span style="margin-left:auto;color:#8a93a3">31 free</span></div>')
    return out


def bags_head():
    return page_head("items", "Bags", "One bag window in the Phoenix look with categories, search, sort, a gold footer and slot marks; Blizzard's bank and warband bank styled to match.", "Bags")


BTABS = ["Window", "Slots", "Bank & behaviour"]


def p_bags_window():
    v = card("items", "Bag window", [pair(cell("Bag window", sel("Phoenix", 140)), cell("Columns", sld(50, "8"))),
                                      pair(cell("Slot size", sld(40, "36")), cell("Slot spacing", sld(30, "3"))),
                                      pair(cell("Scale", sld(50, "100%")), tcell("Reagent bag section", True)),
                                      line("Categories", '<span class="chp">New</span><span class="chp">Equipment</span><span class="chp">Consumables</span>'
                                           '<span class="chp">Reagents</span><span class="chp off">Quest</span><span class="chp">Junk</span><span class="chp">Other</span>',
                                           "Drag to reorder; right-click hides a section (its items go to Other)."),
                                      pair(cell("Sort sections by", sel("Quality", 140)), tcell("Show empty slots", False))])
    s = card("palette", "Window look", [pair(cell("Background", sel("94%", 100), COG()), cell("Border", sel("Follow Appearance", 160), COG())),
                                        pair(cell("Title", sel("Expressway", 140), COG()), cell("", ""))])
    t = card("layout", "Window tools", [pair(tcell("Search box", True), tcell("Sort button", True)),
                                        pair(tcell("Clean up right to left", False), tcell("Gold footer", True)),
                                        pair(tcell("Currencies in the footer", True), tcell("Free slots", True)),
                                        line("Move the window", '<div class="btn">Layout mode</div>', "Drag Bags in Layout mode; the place is kept per profile.")])
    content = bags_head() + tabs(BTABS, 0) + '<div class="body">' + v + s + t + '</div>'
    stage = preview("Live preview", CSS + fit(bag_window(x0=8, cols=6), 1.0, 360), 360, tag="BAGS")
    return s6.shell("interface", "interface", "Bags", content, stage, status="Phoenix window · 7 categories · Blizzard's frames tucked", reload=True)


def p_bags_slots():
    sl = card("items", "Slots", [pair(tcell("Quality borders", True), cell("Slot border", sel("Solid", 140), COG())),
                                 pair(cell("Stack count", sel("Expressway 12", 160), COG()), tcell("Junk coin", True)),
                                 pair(tcell("Dim junk", False), cell("New item glow", sel("Phoenix", 140))),
                                 pair(tcell("Bind-on-equip / warbound label", True), tcell("Cooldowns", True))])
    inf = card("itemlevel", "Item info", [pair(tcell("Upgrade arrows", True), tcell("Sim upgrade arrows", False)),
                                          line("Item levels on gear", tog(), "Shared with Item Level (same setting there).")])
    content = bags_head() + tabs(BTABS, 1) + '<div class="body">' + sl + inf + '</div>'
    stage = preview("Live preview", CSS + fit(bag_window(x0=8, cols=6, cats=False), 1.0, 360), 360, tag="BAGS")
    return s6.shell("interface", "interface", "Bags", content, stage, status="Combined view · glow on new items · upgrade arrows")


def panels(y=60, second=True, xp=True):
    p1 = ('<span style="color:#3ddc97">144<em>fps</em></span><span>38<em>ms</em></span><span style="color:#ffd24a">12,483g</span>'
          '<span>14:32</span><span>Fire<em>· Frost</em></span><span style="color:#a335ee">+12<em>Ara-Kara</em></span>')
    p2 = '<span>48.2, 61.7</span><span style="color:#3ddc97">97%<em>dur</em></span><span>31<em>free</em></span><span>4<em>friends</em></span><span>60%<em>vol</em></span>'
    out = CSS + f'<div class="dp" style="left:20px;top:{y}px">{p1}</div>'
    if second:
        out += f'<div class="dp" style="left:20px;top:{y + 34}px">{p2}</div>'
    if xp:
        out += (f'<div style="position:absolute;left:20px;top:{y + 70}px;width:420px;height:10px;background:#0b0c0f;box-shadow:0 0 0 1px #000,0 0 0 2px #2a2e36">'
                '<i style="position:absolute;left:0;top:0;bottom:0;width:62%;background:#a335ee"></i><i style="position:absolute;left:62%;top:0;bottom:0;width:14%;background:#3a6fd8;opacity:.6"></i>'
                '<span style="position:absolute;left:0;right:0;top:-3px;text-align:center;font-family:CondSemi;font-size:9px;color:#fff;text-shadow:1px 1px 0 #000">62% · 14% rested</span></div>')
    tip = ('<div class="tt" style="position:absolute;left:250px;top:%dpx;background:#121419;box-shadow:0 0 0 1px #2a2e36;padding:8px 10px;font-family:Roboto;font-size:11px;color:#e6e9ef;width:180px">'
           '<div style="font-family:CondBold;color:#ffd24a">Gold</div><div>Phoenixia - Silvermoon <span style="float:right">9,120g</span></div>'
           '<div>Cinder - Silvermoon <span style="float:right">3,363g</span></div><div style="color:#8a93a3">Warband bank <span style="float:right;color:#e6e9ef">40,000g</span></div>'
           '<div style="color:#8a93a3">Total <span style="float:right;color:#ffd24a">52,483g</span></div></div>') % (y + 96)
    return out + tip


def dt_head():
    return page_head("datatexts", "Data Bar", "Two panels of data texts you drag between, with tooltips, mouseover, widths and an experience/reputation bar.", "DataTexts")


def chiprow(names, off=()):
    return "".join(f'<span class="chp{" off" if n in off else ""}">{n}</span>' for n in names)


def p_dt_panels():
    p = card("datatexts", "Panels", [line("Panel 1", chiprow(["FPS", "Latency", "Gold", "Clock", "Spec", "Key"]), "Drag to reorder or onto the other panel; right-click turns a text off."),
                                      pair(tcell("Second panel", True), cell("Panel width", sld(0, "Auto"))),
                                      line("Panel 2", chiprow(["Coordinates", "Durability", "Bags", "Friends", "Volume", "Guild"], off=("Guild",)), None),
                                      pair(cell("Text alignment", sel("Left", 120)), tcell("Show on mouseover only", False)),
                                      pair(tcell("Tooltips", True), tcell("No tooltips in combat", True))])
    o = card("cog", "Texts", [pair(tcell("Gold: silver and copper", False), tcell("Gold: all characters + warband bank", True)),
                              pair(tcell("Clock: realm time", False), cell("Durability warning below", sld(25, "25%")))])
    content = dt_head() + tabs(["Texts", "Look", "Experience bar"], 0) + '<div class="body">' + p + o + '</div>'
    return s6.shell("interface", "interface", "DataTexts", content, preview("Live preview", fit(panels(), 0.6, 260), 260, tag="DATA BAR"), status="Two panels in Edit Mode · tooltips hidden in combat")


def p_dt_xp():
    x = card("datatexts", "Experience bar", [pair(tcell("Experience bar", True), tcell("Reputation at max level", True)),
                                              pair(tcell("Rested overlay", True), cell("Bar text", sel("On hover", 120))),
                                              pair(cell("Width", sld(52, "520")), cell("Height", sld(20, "10"))),
                                              line("Bar text font", sel("Expressway 10", 160) + COG(), None),
                                              line("Move the bar", '<div class="btn">Edit Mode</div>', "DataTextsXP in Edit Mode, like the panels.")])
    content = dt_head() + tabs(["Texts", "Look", "Experience bar"], 2) + '<div class="body">' + x + '</div>'
    return s6.shell("interface", "interface", "DataTexts", content, preview("Live preview", fit(panels(second=False), 0.6, 260), 260, tag="DATA BAR"), status="XP 62% · rested 14%")


def fit(html, scale, h):
    return f'<div style="position:absolute;left:0;top:0;width:{int(100 / scale)}%;height:{int(h / scale)}px;transform:scale({scale});transform-origin:0 0">{html}</div>'


def skin_stage():
    out = CSS + '<div class="swin" style="left:24px;top:14px;width:250px;height:190px"><div class="swt">Phoenixia</div><div class="swx">✕</div>'
    out += ''.join(f'<div class="bslot" style="left:{8 if i < 4 else 212}px;top:{30 + (i % 4) * 36}px;box-shadow:0 0 0 1px {Q[4 if i % 3 else 3]}"><i style="background:{FILL[i]}"></i></div>' for i in range(8))
    out += '<div style="position:absolute;left:46px;right:46px;top:30px;bottom:12px;background:#0b0c0f;box-shadow:0 0 0 1px #23262d"></div>'
    for i, (n, on) in enumerate([("Character", True), ("Reputation", False), ("Currency", False)]):
        out += f'<div class="stab{" on" if on else ""}" style="left:{6 + i * 76}px">{n}</div>'
    out += '</div>'
    out += ('<div class="swin" style="left:296px;top:14px;width:160px;height:80px"><div class="swt">Ready check</div>'
            '<div style="padding:8px;font-family:Roboto;font-size:11px;color:#e6e9ef">Are you ready?</div>'
            '<div style="position:absolute;left:10px;bottom:8px;display:flex;gap:6px"><div class="btn">Ready</div><div class="btn ghost">Not ready</div></div></div>')
    out += ('<div class="swin" style="left:296px;top:110px;width:160px;height:94px"><div class="swt">Great Vault</div>'
            '<div style="display:flex;gap:6px;padding:8px">' + "".join(f'<div class="bslot" style="position:relative;box-shadow:0 0 0 1px {Q[4]}"><i style="background:{FILL[i]}"></i></div>' for i in range(3)) + '</div></div>')
    return preview("Live preview", fit(out, 0.54, 240), 240, tag="SKINS")


def p_skins():
    head = page_head("skins", "Skins", "Blizzard's windows and dialogs in the Phoenix look: your background and border, a title strip, a close glyph and tabs, each window on or off.", "Skins")
    w = card("skins", "Windows", [pair(tcell("Character", True), tcell("Inspect", True)), pair(tcell("Spellbook and talents", True), tcell("Group finder", True)),
                                  pair(tcell("Collections", True), tcell("Professions", True)), pair(tcell("Auction house", True), tcell("Mail", True)),
                                  pair(tcell("Merchant", True), tcell("Gossip and quests", True)), pair(tcell("Loot", True), tcell("Achievements", True)),
                                  pair(tcell("Encounter journal", True), tcell("Calendar", True)), pair(tcell("Communities", True), tcell("Friends", True)),
                                  pair(tcell("Settings", False), tcell("Great Vault", True)), pair(tcell("Keystone", True), tcell("Trade", True)),
                                  pair(tcell("Dressing room", True), tcell("Game menu", True)), pair(tcell("Popups", True), tcell("Ready check", True))])
    s = card("palette", "Look", [pair(cell("Background", sel("94%", 100), COG()), cell("Border", sel("Follow Appearance", 160), COG())),
                                 pair(cell("Title bar", sel("Phoenix", 120)), cell("Close button", sel("Phoenix", 120))),
                                 pair(tcell("Phoenix tabs", True), cell("", ""))])
    content = head + '<div class="body">' + w + s + '</div>'
    return s6.shell("interface", "interface", "Skins", content, skin_stage(), status="24 windows · load-on-demand ones styled when they load", reload=True)


PAGES = {"s13b_bags_window": p_bags_window, "s13b_bags_slots": p_bags_slots, "s13b_datatexts": p_dt_panels,
         "s13b_datatexts_xp": p_dt_xp, "s13b_skins": p_skins}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S13b Bags, Data Texts and Skins (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
