#!/usr/bin/env python3
"""Chat, Minimap and Tooltip (2.0 S13a) mockups: HTML mirroring Phoenix_UI_Options/Options/{Chat,Minimap,Tooltip}.lua and
their Previews, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome. Labels come from
Locales/enUS.lua, the setting counts from the smoke harness ("chat, minimap and tooltip depth (S13a)"). The map, chat
lines and tooltip are CSS stand-ins for the game's art; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s13a.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, COG, preview, page_head, tabs  # noqa: E402
import s9  # noqa: E402

s6.DEPTH["Chat"] = (58, 51)
s6.DEPTH["Minimap"] = (47, 41)
s6.DEPTH["Tooltip"] = (54, 45)
OUT = SRC.parent
CSS = s9.CSS + ('<style>.cw{position:absolute;background:rgba(10,11,14,.72);box-shadow:0 0 0 1px #2a2e36}'
                '.cw p{margin:0;font-family:Roboto;font-size:12px;line-height:19px;white-space:nowrap;text-shadow:1px 1px 0 #000}'
                '.ts{color:#8a93a3}.ctab{position:absolute;font-family:CondSemi;font-size:11px;color:#8a93a3}'
                '.mm{position:absolute;overflow:hidden;background:radial-gradient(circle at 30% 35%,#3c5230 0 22%,transparent 23%),'
                'radial-gradient(circle at 70% 70%,#455a32 0 25%,transparent 26%),radial-gradient(circle at 72% 28%,#26476a 0 14%,transparent 15%),#29301f}'
                '.mm:after{content:"";position:absolute;left:-10%;right:-10%;top:52%;height:5px;background:#8c7854;transform:rotate(-24deg)}'
                '.tt{position:absolute;background:#121419;box-shadow:0 0 0 1px #3fc7eb,0 4px 14px rgba(0,0,0,.7);padding:9px 11px;font-family:Roboto;font-size:12px;color:#e6e9ef}'
                '.tt div{line-height:17px;white-space:nowrap}.tb{position:absolute;bottom:-8px;left:1px;right:1px;height:5px;background:#3ddc97;box-shadow:0 0 0 1px #000}'
                '.cbb{position:absolute;width:20px;height:20px;background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;font-family:CondBold;font-size:11px;'
                'display:flex;align-items:center;justify-content:center}</style>')

CH = {"guild": "#40ff40", "trade": "#ffc0c0", "whisper": "#ff80ff", "party": "#aaaaff", "system": "#ffff00"}
ROLE = {"tank": "#4aa3ff", "healer": "#3ddc97", "dps": "#ff5a4a"}


def role(r):
    return f'<b style="display:inline-block;width:10px;height:10px;border-radius:2px;background:{ROLE[r]};margin-right:3px;vertical-align:-1px"></b>'


def chat_stage(short=True, bar=True, top=False, skin=True):
    ts = '<span class="ts">15:27</span> '
    hi = '<span style="color:#ff6a1a">Phoenixia</span>'
    lines = [(CH["guild"], role("tank") + "[Guild] [Phoenixia]: Ara-Kara +12 tonight, need a tank"),
             (CH["trade"], f'[{"2" if short else "2. Trade"}] [Brontus]: WTS <span style="color:#a335ee">[Emberforged Greatsword (684)]</span>'),
             (CH["whisper"], "[Cinder] whispers: inv please"),
             (CH["party"], role("healer") + '[Party] [Emberlynn]: route is here <span style="color:#4ab8ff">phoenix-ui.gg/keys</span>'),
             (CH["party"], role("dps") + f"[Party] [Emberlynn]: {hi}, can you lead?"),
             (CH["system"], "Phoenixia has come online.")]
    body = "".join(f'<p style="color:{c}">{ts}{t}</p>' for c, t in lines)
    bd = "box-shadow:0 0 0 1px #000,0 0 0 2px #2a2e36" if skin else ""
    out = CSS + f'<div class="cw" style="left:30px;top:{58 if top else 34}px;width:440px;height:124px;padding:4px 8px;{bd}">{body}</div>'
    ty = (58 if top else 34) - 16
    for i, (n, c) in enumerate([("General", "#ff6a1a"), ("Guild", "#8a93a3"), ("Whispers", "#ff80ff")]):
        out += f'<div class="ctab" style="left:{40 + i * 80}px;top:{ty}px;color:{c}">{n}</div>'
    ey = 8 if top else 166
    out += (f'<div class="cw" style="left:30px;top:{ey + (0 if top else 0)}px;width:440px;height:22px;padding:0 8px;display:flex;align-items:center;'
            f'font-family:Roboto;font-size:12px;color:#e6e9ef">Say: on my way<span style="margin-left:auto;color:#ffd24a">★</span></div>')
    if bar:
        for i, (l, c) in enumerate([("S", "#fff"), ("P", "#aaaaff"), ("I", "#ff7f00"), ("R", "#ff7f00"), ("G", "#40ff40"), ("%", "#fff"), ("✓", "#3ddc97"), ("10", "#ff6a1a"), ("★", "#ffd24a")]):
            out += f'<div class="cbb" style="left:{290 + i * 22 - 120}px;top:{ty - 26}px;color:{c}">{l}</div>'
    return preview("Live preview", out, 200, tag="CHAT")


def chat_head():
    return page_head("chat", "Chat", "Styled windows and tabs, timestamps, class colours, short channels, keywords, item levels on links, copy and links, a chat bar and an edit box history that survives a reload.", "Chat")


CTABS = ["Window", "Messages", "Input"]


def p_chat_window():
    w = card("chat", "Chat window", [line("Style chat windows", tog(), "Swap Blizzard's window background for your own background and border."),
                                     pair(cell("Background", sel("Solid", 140), COG()), cell("Border", sel("Pixel", 140), COG())),
                                     line("Window size", '<span class="badge">430 × 120</span> <div class="btn">Edit Mode</div>', "Set in Edit Mode (Chat Frame) so it follows your layouts. Shown here for reference."),
                                     pair(cell("Fade old lines", tog(), COG()), cell("Lines kept", sld(25, "512"))),
                                     pair(tcell("Hide chat in combat", False), tcell("Side buttons", False)),
                                     pair(tcell("Jump-to-bottom button", True), tcell("Copy button", True))])
    t = card("layout", "Tabs", [pair(tcell("Flashing tabs in the accent colour", True), tcell("Coloured whisper tabs", True)),
                                pair(tcell("Fade idle tabs", True), cell("Selected tab colour", swatch("#ff6a1a")))])
    content = chat_head() + tabs(CTABS, 0) + '<div class="body">' + w + t + '</div>'
    return s6.shell("interface", "interface", "Chat", content, chat_stage(), status="Styled windows · chat bar above · timestamps 15:27")


def p_chat_messages():
    m = card("fonts", "Text", [pair(cell("Timestamps", sel("15:27", 140)), cell("Class-coloured names", sel("Per channel (game setting)", 200))),
                               pair(tcell("Short channel names", True), cell("Clickable URLs", tog(), COG())),
                               pair(tcell("Item levels on links", True), tcell("Icons on links", True)),
                               line("Role icons on names", tog(), "Group members' names get their tank, healer or damage icon.")])
    k = card("bell", "Keywords", [line("Highlight words", '<div class="sel" style="width:240px">keys, ara-kara</div>', "Comma-separated words to highlight in other players' messages (whole words, any case)."),
                                  pair(tcell("Highlight my name", True), cell("Highlight colour", swatch("#ff6a1a"))),
                                  pair(cell("Keyword sound", sel("Phoenix: Ping", 160)), cell("Spam filter (seconds)", sld(25, "30")))])
    content = chat_head() + tabs(CTABS, 1) + '<div class="body">' + m + k + '</div>'
    return s6.shell("interface", "interface", "Chat", content, chat_stage(), status="Restricted chat: filters skip secret messages")


def mm_stage(shape="SQUARE"):
    h = 104 if shape == "RECTANGLE" else 130
    radius = "50%" if shape == "ROUND" else "0"
    border = "" if shape == "ROUND" else "box-shadow:0 0 0 2px #000,0 6px 14px rgba(0,0,0,.6);"
    top = 34 + (130 - h) // 2
    out = CSS + f'<div class="mm" style="left:90px;top:{top}px;width:130px;height:{h}px;border-radius:{radius};{border}"></div>'
    out += f'<div style="position:absolute;left:90px;width:130px;top:{top - 18}px;text-align:center;font-family:CondBold;font-size:12px;color:#3ddc97;text-shadow:1px 1px 0 #000">Silvermoon City</div>'
    out += f'<div style="position:absolute;left:90px;width:130px;top:{top + h - 18}px;text-align:center;font-family:CondSemi;font-size:11px;color:#fff;text-shadow:1px 1px 0 #000">48.2  61.7</div>'
    out += f'<div style="position:absolute;left:90px;width:130px;top:{top + h + 6}px;text-align:center;font-family:CondSemi;font-size:11px;color:#fff">14:32</div>'
    for x, y, i in [(4, 4, "search"), (4, 24, "mail"), (24, 4, "heart"), (104, 4, "layout"), (4, h - 18, "maps")]:
        out += f'<div style="position:absolute;left:{90 + x}px;top:{top + y}px;color:#c9ced8">{ico(i, 12)}</div>'
    out += f'<div style="position:absolute;left:{90 + 92}px;top:{top + h - 22}px;width:18px;height:18px;background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;display:flex;align-items:center;justify-content:center;color:#ff6a1a">{ico("bin", 11)}</div>'
    out += '<div style="position:absolute;left:234px;top:34px;padding:6px;background:#1a1d24;box-shadow:0 0 0 1px #2a2e36;display:grid;grid-template-columns:repeat(4,24px);gap:2px">'
    out += "".join(f'<div style="width:24px;height:24px;background:#101216;box-shadow:0 0 0 1px #23262d;display:flex;align-items:center;justify-content:center;color:#c9ced8">{ico(n, 12)}</div>'
                   for n in ["items", "maps", "chat", "bugs", "tracker", "sound"])
    out += '</div>'
    return preview("Live preview", out, 200, tag="MINIMAP")


def mm_head():
    return page_head("minimap", "Minimap", "Round, square or rectangular minimap with your border, styled zone, clock and coordinates, tidy Blizzard buttons and a bin for addon buttons.", "Minimap")


def p_mm_appearance():
    s = card("minimap", "Shape", [pair(cell("Map shape", sel("Rectangle", 150)), cell("Rectangle height", sel("80%", 100))),
                                  line("Size", '<span class="badge">100%</span> <div class="btn">Edit Mode</div>', "Set in Edit Mode (Minimap > Size, 50–200 %) so it follows your layouts."),
                                  pair(cell("Map border", sel("Pixel", 140), COG()), cell("Border colour", swatch("#000000")))])
    t = card("fonts", "Text", [pair(cell("Zone text", tog(), COG()), tcell("PvP colours", True)),
                               pair(cell("Clock", tog(), COG()), cell("Coordinates", tog(), COG())),
                               pair(cell("Precision", sel("48.2  61.7", 140)), cell("Coordinate text", sel("Bottom · 0, 8", 150)))])
    content = mm_head() + tabs(["Appearance", "Buttons"], 0) + '<div class="body">' + s + t + '</div>'
    return s6.shell("interface", "interface", "Minimap", content, mm_stage("RECTANGLE"), status="Rectangle 80% · border from the S6 style library", reload=True)


def p_mm_buttons():
    b = card("minimap", "Blizzard buttons", [pair(tcell("Calendar", True), tcell("Tracking", True)),
                                             pair(tcell("Mail", True), tcell("Crafting orders", True)),
                                             pair(tcell("Instance difficulty", True), tcell("Expansion button", False)),
                                             pair(tcell("Addon compartment", False), tcell("Zoom buttons", False))])
    z = card("search", "Zoom", [pair(tcell("Mouse wheel zoom", True), cell("Zoom out after (seconds)", sld(25, "15")))])
    bn = card("bin", "Button bin", [pair(tcell("Collect addon buttons", True), cell("Columns", sld(45, "4"))),
                                    pair(cell("Button size", sld(45, "28")), tcell("Show the bin glyph on hover", False)),
                                    line("Keep on the minimap", '<div class="sel" style="width:200px">BugSack</div>', "Comma-separated button names (as the addon registers them) that stay on the minimap.")])
    e = card("maps", "Extras", [pair(tcell("Who pinged", True), tcell("World map coordinates", True))])
    content = mm_head() + tabs(["Appearance", "Buttons"], 1) + '<div class="body">' + b + z + bn + e + '</div>'
    return s6.shell("interface", "interface", "Minimap", content, mm_stage("SQUARE"), status="LibDBIcon buttons collected · 6 in the bin")


def tt_stage():
    rows = ['<div style="font-family:CondBold;font-size:14px;color:#3fc7eb">Phoenixia</div>',
            '<div style="color:#3ddc97">&lt;Ashen Wings&gt; <span style="color:#999">(Officer)</span></div>',
            '<div>Level 90 Blood Elf Mage</div>', '<div>Realm: Silvermoon</div>', '<div>Damage</div>',
            '<div>Item level: 684</div>', '<div>Specialization: Fire Mage</div>', '<div>Mount: Ashes of Al\'ar <span style="color:#33ff33">(owned)</span></div>',
            '<div>Mythic+ rating: <span style="color:#ff8000">3,105</span></div>', '<div>Target: <span style="color:#ff5a4a">Void-Touched Stalker</span></div>',
            '<div>Targeted by (2): <span style="color:#fff">Lumina</span>, Brontus</div>']
    out = CSS + f'<div class="tt" style="left:70px;top:14px;width:230px">{"".join(rows)}<div class="tb"><span style="position:absolute;left:0;right:0;top:-5px;text-align:center;font-family:CondSemi;font-size:9px;color:#fff">82%</span></div></div>'
    return preview("Live preview", out, 260, tag="TOOLTIP")


def p_tooltip():
    head = page_head("tooltip", "Tooltip", "A cleaner tooltip with class borders and names, health bar, cursor or mover anchoring, inspect, mount, guild rank, targeted-by lines and IDs.", "Tooltip")
    beh = card("cog", "Behavior", [pair(cell("Anchor", sel("Cursor", 150)), cell("Scale", sld(50, "100%"))),
                                   pair(cell("Cursor offset X", sld(20, "16")), cell("Cursor offset Y", sld(30, "16"))),
                                   pair(tcell("Hide in combat", True), cell("Show anyway with", sel("Shift, Ctrl or Alt", 170))),
                                   pair(cell("What to hide", sel("Units only", 140)), cell("", ""))])
    un = card("heart", "Units", [pair(tcell("Class-coloured names", True), tcell("Reaction-coloured NPC names", True)),
                                 pair(tcell("Guild rank", True), tcell("Realm line", True)),
                                 pair(tcell("Hide the PvP line", False), tcell("Health percent", True))])
    ln = card("tooltip", "Extra lines", [pair(tcell("Target", True), tcell("Targeted by", True)),
                                         pair(tcell("Item level and specialization", True), tcell("Mount", True)),
                                         pair(tcell("Item counts", True), cell("IDs", tog(), COG()))])
    content = head + tabs(["Appearance", "Content"], 1) + '<div class="body">' + beh + un + ln + '</div>'
    return s6.shell("interface", "interface", "Tooltip", content, tt_stage(), status="Secret values skipped, never compared")


PAGES = {"s13a_chat_window": p_chat_window, "s13a_chat_messages": p_chat_messages, "s13a_minimap": p_mm_appearance,
         "s13a_minimap_buttons": p_mm_buttons, "s13a_tooltip": p_tooltip}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S13a Chat, Minimap and Tooltip (HTML)"), encoding="utf-8")
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", "--window-size=1360,880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
