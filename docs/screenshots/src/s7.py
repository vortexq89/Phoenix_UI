#!/usr/bin/env python3
"""Action bars (2.0 S7) mockups: HTML mirroring Phoenix_UI_Options/Options/{ActionBars,CooldownText}.lua and
Previews/ActionBars.lua, drawn with the S6 shell (s6.py helpers and s6.css), rendered to PNG with headless Chrome.
Labels come from Locales/enUS.lua, setting counts from the smoke harness ("action bars depth"). Button art is CSS,
standing in for the shipped Mask*/Ring* textures; these are mockups, not in-game screenshots.
Usage (repo root): python3 docs/screenshots/src/s7.py [outdir]"""
import pathlib
import subprocess
import sys

SRC = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import s6  # noqa: E402
from s6 import ico, card, line, pair, cell, tcell, tog, sel, sld, swatch, cfield, chips, style_face, COG, preview, page_head, tabs  # noqa: E402

s6.DEPTH["ActionBars"] = (116, 114)
s6.DEPTH["CooldownText"] = (15, 12)
OUT = SRC.parent

ICONS = ["#b0452a,#3a0d06", "#2b6fd6,#0b1d3d", "#d4a017,#4a3404", "#7b3fd0,#22103d", "#2fa86a,#0b3320", "#c43a3a,#3d0b0b",
         "#3fb6c9,#0b2d33", "#d0662a,#3d1a08", "#8a8f99,#25282e", "#e05aa0,#3d0b26", "#6a9a2a,#1c2a08", "#b08a5a,#2e2416"]
RADIUS = {"square": "0", "rounded": "22%", "circle": "50%", "hexagon": "0"}
HEX = "clip-path:polygon(25% 3%,75% 3%,98% 50%,75% 97%,25% 97%,2% 50%)"


def button(i, size=40, shape="square", key="", count="", cd=None, state=None, glow=None, empty=False):
    r = RADIUS[shape]
    clip = HEX if shape == "hexagon" else ""
    edge = "box-shadow:0 0 0 1px #000,0 3px 6px rgba(0,0,0,.65)" if shape != "hexagon" else ""
    if empty:
        return (f'<div class="ab" style="width:{size}px;height:{size}px;border-radius:{r};{clip};background:rgba(20,22,27,.4);'
                f'box-shadow:inset 0 0 0 1px rgba(255,255,255,.06)"></div>')
    c1, c2 = ICONS[i % len(ICONS)].split(",")
    tint = {"range": "filter:sepia(1) saturate(6) hue-rotate(-50deg) brightness(.7)",
            "power": "filter:sepia(1) saturate(4) hue-rotate(180deg) brightness(.6)",
            "unusable": "filter:grayscale(1) brightness(.45)"}.get(state, "")
    sw = ""
    if cd is not None:
        sw = (f'<div style="position:absolute;inset:0;border-radius:{r};{clip};background:conic-gradient(transparent 0 {cd}%,rgba(0,0,0,.72) {cd}% 100%)"></div>'
              f'<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:CondBold;font-size:{round(size * .4)}px;'
              f'color:#fff;text-shadow:0 0 2px #000,1px 1px 0 #000">{cd // 10 if cd < 30 else "1m" if cd > 80 else cd // 4}</div>')
    gl = ""
    if glow == "proc":
        gl = f'<div style="position:absolute;inset:-4px;border-radius:{r};border:2px dashed #ffd24a;box-shadow:0 0 10px #ffb02e"></div>'
    elif glow == "assist":
        gl = f'<div style="position:absolute;inset:-3px;border-radius:{r};box-shadow:0 0 0 2px #3fc7eb,0 0 12px #3fc7eb"></div>'
    kc = "#ff5a5a" if state == "range" else "#e8ecf2"
    return (f'<div class="ab" style="width:{size}px;height:{size}px">'
            f'<div style="position:absolute;inset:0;border-radius:{r};{clip};{edge};overflow:hidden;'
            f'background:radial-gradient(circle at 35% 30%,{c1},{c2});{tint}"></div>{sw}{gl}'
            f'<span style="position:absolute;right:2px;top:1px;font-family:CondBold;font-size:{round(size * .28)}px;color:{kc};text-shadow:1px 1px 0 #000">{key}</span>'
            f'<span style="position:absolute;right:2px;bottom:1px;font-family:CondBold;font-size:{round(size * .3)}px;color:#fff;text-shadow:1px 1px 0 #000">{count}</span></div>')


KEYS = ["1", "2", "3", "4", "5", "6", "Q", "E", "R", "F", "S-1", "M4"]


def bar(n=12, size=40, gap=2, shape="square", rows=1, specials=None, empty=(), backdrop=False, x=0, y=0, absolute=True, keys=KEYS):
    specials = specials or {}
    per = -(-n // rows)
    items = []
    for i in range(n):
        s = specials.get(i, {})
        items.append(button(i, size, shape, key=keys[i % len(keys)], empty=i in empty, **s))
    bd = "background:rgba(14,15,19,.55);box-shadow:0 0 0 1px #000;padding:3px;" if backdrop else ""
    pos = f"position:absolute;left:{x}px;top:{y}px;" if absolute else ""
    return (f'<div style="{pos}{bd}display:grid;grid-template-columns:repeat({per},{size}px);gap:{gap}px">' + "".join(items) + "</div>")


SAMPLE = {0: {"glow": "proc"}, 2: {"cd": 62}, 3: {"state": "range"}, 5: {"state": "power"}, 6: {"glow": "assist"},
          8: {"state": "unusable"}, 9: {"count": "3"}, 10: {"cd": 18}}

CSS = '<style>.ab{position:relative;flex:none}</style>'


def scope(on="Bar 1"):
    items = [(n, None) for n in ("Bar 1", "Bar 2", "Bar 3", "Bar 4", "Bar 5", "Bar 6", "Bar 7", "Bar 8", "Pet bar", "Stance bar", "Item bar")]
    return (f'<div class="scope"><div class="t">{ico("actionbars", 13)}Bar<span class="h">Shift-click to edit several</span>'
            f'<span class="all">ALL {tog(False)}</span></div><div class="r">{chips(items, on=(on,))}'
            f'<div style="margin-left:auto;display:flex;align-items:center;gap:8px;font-family:Cond;font-size:11px;color:var(--muted)">Apply all settings from {sel("Bar 2", 110)}</div></div></div>')


def dock(shape="square", states=("Cooldown",), rows=2, n=12):
    st = bar(n, 34, 3, shape, rows, SAMPLE, empty=(11,) if "Empty slots" in states else (), backdrop=True, x=14, y=40 if rows == 1 else 18)
    return preview("Live preview", CSS + st, 150 if rows == 1 else 170, [("Cooldown", "clock"), ("Empty slots", "grid")], on=states, tag="ACTION BAR")


def head():
    return page_head("actionbars", "Action Bars", "Phoenix's own secure bars: layout, paging, fading, shapes, glows and range feedback.", "ActionBars")


def bars_tab():
    mode = card("actionbars", "Bars", [line("Bars owned by", sel("Phoenix", 200), "Phoenix: Phoenix lays out, pages and fades every bar. Blizzard: Edit Mode keeps the bars and Phoenix only styles the buttons. Needs a reload."),
                                       line("Move the bars", f'<div class="btn">{ico("editmode")}Layout mode</div>', "Opens Layout mode: drag a bar, scroll to scale it, shift-scroll for opacity, right-click to reset.")])
    lay = card("layout", "Layout", [pair(cell("Buttons", sld(100, "12")), cell("Lines", sld(18, "2"), COG())),
                                    pair(cell("Button width", sld(45, "40")), tcell("Square buttons", True)),
                                    pair(cell("Horizontal spacing", sld(20, "2")), cell("Vertical spacing", sld(20, "2"))),
                                    pair(cell("Grow", sel("Right", 160)), cell("Wrap", sel("Down", 160))),
                                    pair(tcell("Show empty buttons", False), tcell("Click-through", False))], gate=True)
    vis = card("preview", "Visibility", [pair(tcell("In combat", True), tcell("Out of combat", True)),
                                         line("Fade out of combat", tog(), "Dim the bar while you are out of combat; hover, dragging a spell or the spellbook bring it back.", side=COG()),
                                         pair(tcell("Mouseover only", False), tcell("Hide in vehicles", True)),
                                         line("Visibility macro", '<div class="sel" style="--w:240px"><span style="font-family:Mono;font-size:10.5px">[mod:alt] show; hide</span></div>', "Overrides the combat rules above.")])
    pg = card("chevron-right", "Paging (bar 1)", [pair(tcell("Form and stance pages", True), tcell("Skyriding page", True)),
                                                   pair(cell("Shift switches to", sel("Page 2", 140)), cell("Ctrl switches to", sel("Off", 140))),
                                                   line("Page arrows", tog(False), "Small arrows beside bar 1 with the page number; they work in combat.")])
    content = head() + scope("Bar 1") + tabs(["Bars", "Buttons", "Text", "Extra bars"], 0) + '<div class="body">' + mode + lay + vis + pg + '</div>'
    return s6.shell("bars", "bars", "ActionBars", content, dock(rows=2), status="Bar 1 · 2 lines · applies after combat")


def buttons_tab():
    shapes = ''.join(f'<div class="scard{" on" if k == "circle" else ""}"><div class="sm" style="width:40px;height:40px;margin:0 auto;border-radius:{RADIUS[k]};{HEX if k == "hexagon" else ""};'
                     f'background:radial-gradient(circle at 35% 30%,#2b6fd6,#0b1d3d);box-shadow:0 0 0 1px #000"></div><div class="n">{k.title()}</div></div>'
                     for k in ("square", "rounded", "circle", "hexagon"))
    pop = f'<div class="pop" style="left:560px;top:250px"><h4>Button shape</h4><div class="sgrid" style="grid-template-columns:repeat(4,1fr)">{shapes}</div></div>'
    art = card("theme", "Button art", [line("Phoenix button art", tog(), "Replace Blizzard's button frame with the shape and border below."),
                                       pair(cell("Button shape", sel("Circle", 180)), cell("Border", style_face("Shadow", "solid"), COG())),
                                       pair(cell("Icon zoom", sld(30, "8%")), cell("Empty slot background", sld(40, "40%")))])
    fb = card("warning", "Feedback", [pair(cell("Out of range colour", cfield("#ff4d5e")), cell("Not-enough-power colour", cfield("#4d7dff"))),
                                      pair(cell("Unusable colour", cfield("#6b6f78")), cell("Tint", sel("Icon", 140))),
                                      pair(cell("Proc glow", sel("Pixel lines", 160), COG()), cell("Assisted highlight", sel("Soft glow", 160), COG())),
                                      pair(cell("Pressed look", sel("Accent", 140)), cell("Mouseover look", sel("Accent", 140)))])
    cd = card("clock", "Cooldowns", [pair(tcell("Grey icons on cooldown", False), cell("Cooldown swipe opacity", sld(80, "80%"))),
                                     pair(tcell("Ready flash", False), tcell("Global cooldown swipe", True)),
                                     pair(cell("Hide button tooltips", sel("In combat", 140)), tcell("Lock action buttons", True))])
    content = head() + scope("Bar 1") + tabs(["Bars", "Buttons", "Text", "Extra bars"], 1) + '<div class="body">' + art + fb + cd + '</div>'
    return s6.shell("bars", "bars", "ActionBars", content, dock("circle"), overlay=pop, status="Previewing Circle (hover)")


def text_tab():
    hk = card("fonts", "Hotkeys", [pair(tcell("Show hotkeys", True), tcell("Short hotkey names", True)),
                                   line("Hotkey font", sel("Roboto Condensed Bold · 12 · Outline", 260, icon="fonts"), "S-1 instead of Shift-1, M4 instead of Mouse Button 4, N5 for numpad.", side=COG())])
    mc = card("fonts", "Macro names", [line("Macro font", sel("Roboto Condensed · 10 · Outline", 260, icon="fonts"), side=COG())], gate=False)
    ct = card("fonts", "Counts and charges", [line("Count font", sel("Roboto Condensed Bold · 13 · Outline", 260, icon="fonts"), side=COG())])
    cdn = card("cooldowntext", "Cooldown numbers", [line("Countdown numbers", tog(), "Blizzard's own countdown on cooldowns (game setting)."),
                                                    pair(cell("Number size on bars", sld(0, "Auto")), tcell("Numbers on charge recharges", False))])
    content = head() + scope("Bar 2") + tabs(["Bars", "Buttons", "Text", "Extra bars"], 2) + '<div class="body">' + hk + mc + ct + cdn + '</div>'
    return s6.shell("bars", "bars", "ActionBars", content, dock("rounded", ("Cooldown", "Empty slots")), status="Text applies to every bar")


def extra_tab():
    ex = card("actionbars", "Extra and zone abilities", [pair(tcell("Phoenix style", True), cell("Extra button scale", sld(50, "100%"))),
                                                         line("Hide decorative art", tog(), "The ornate frame behind the extra action and zone abilities."),
                                                         line("Vehicle exit button", tog(), "Leave a vehicle or land a flight path early; movable in Layout mode.", side=COG())])
    menus = card("interface", "Menus", [pair(cell("Game menu buttons", sel("On mouseover", 160)), cell("Bag buttons", sel("Always shown", 160)))])
    items = card("items", "Item bar", ['<div class="rowl"><div class="lt"><div class="ds">The item bar works with Phoenix bars. Turn it on and place it in the Bars tab.</div></div></div>',
                                       line("Usable quest items", tog(), "Quest items in your bags that have a use appear on the bar by themselves."),
                                       line("Extra items", '<div class="sel" style="--w:240px"><span style="font-family:Mono;font-size:10.5px">5512, 171267, 207023</span></div>',
                                            "Item IDs separated by spaces or commas; shown while you carry them.")])
    stage = CSS + bar(4, 38, 4, "rounded", 1, {0: {"count": "2"}, 2: {"cd": 44}}, backdrop=True, x=20, y=40, keys=["", "", "", ""])
    stage += ('<div style="position:absolute;left:230px;top:30px;width:58px;height:58px;border-radius:22%;background:radial-gradient(circle at 35% 30%,#d4a017,#4a3404);'
              'box-shadow:0 0 0 1px #000,0 0 10px rgba(255,180,40,.5)"></div><div style="position:absolute;left:300px;top:44px;width:30px;height:30px;border-radius:50%;'
              'background:#2a2d35;box-shadow:0 0 0 1px #000;display:flex;align-items:center;justify-content:center;color:#ff6a6a;font-family:CondBold">✕</div>')
    dk = preview("Live preview", stage, 130, tag="EXTRA")
    content = head() + tabs(["Bars", "Buttons", "Text", "Extra bars"], 3) + '<div class="body">' + ex + menus + items + '</div>'
    return s6.shell("bars", "bars", "ActionBars", content, dk, status="Item bar: 3 items carried")


def cooldowntext():
    cd = card("cooldowntext", "Countdown numbers", [line("Countdown numbers", tog(), "Blizzard's own countdown on cooldowns (game setting)."),
                                                     pair(cell("Font", sel("Default", 180, icon="fonts")), cell("Size", sld(40, "16"), COG())),
                                                     pair(cell("Colour", cfield("#ffffff")), tcell("Scale with icon size", True))])
    tm = card("clock", "Timing", [pair(cell("Tenths below", sld(30, "3 s")), cell("Shortest cooldown with numbers", sld(15, "1.5 s"))),
                                  line("Hide on buff and debuff icons", tog(False), "Aura timers already show their own duration text.")])
    rm = card("palette", "Colour by time left", [line("Colour numbers by time left", tog(), "Action buttons only. Red when nearly ready, then seconds and minutes colours."),
                                                 line("Colours", '<div style="display:flex;gap:6px">' + swatch("#ff4d5e") + swatch("#ffc24b") + swatch("#e8ecf2") + '</div>'),
                                                 line("Almost ready below", sld(30, "3 s"), "Seconds left when the almost-ready colour takes over.")], gate=True)
    nums = [(18, "2.4", "#ff4d5e", 1.0), (36, "12", "#ffc24b", 1.0), (54, "1m", "#e8ecf2", 1.0), (24, "8", "#ffc24b", 0.67)]
    stage = CSS + '<div style="position:absolute;left:20px;top:28px;display:flex;gap:14px;align-items:flex-end">'
    for i, (p, t, c, sc) in enumerate(nums):
        s = round(48 * sc)
        stage += (f'<div class="ab" style="width:{s}px;height:{s}px"><div style="position:absolute;inset:0;background:radial-gradient(circle at 35% 30%,{ICONS[i].split(",")[0]},{ICONS[i].split(",")[1]});box-shadow:0 0 0 1px #000"></div>'
                  f'<div style="position:absolute;inset:0;background:conic-gradient(transparent 0 {p}%,rgba(0,0,0,.7) {p}% 100%)"></div>'
                  f'<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:CondBold;font-size:{round(16 * s / 36)}px;color:{c};text-shadow:1px 1px 0 #000">{t}</div></div>')
    stage += '</div><div style="position:absolute;left:20px;bottom:10px;font-family:Cond;font-size:10px;color:#8a93a3">Scaled to the icon · colour by time left</div>'
    dk = preview("Live preview", stage, 140, tag="COOLDOWN TEXT")
    content = (page_head("cooldowntext", "Cooldown Text", "Countdown numbers on every cooldown: font, size, timing and colour.", "CooldownText")
               + '<div class="body">' + cd + tm + rm + '</div>')
    return s6.shell("bars", "bars", "CooldownText", content, dk, status="Live: changes apply as you make them")


def world():
    mv = 'outline:1px dashed var(--acc);outline-offset:3px;'
    def lbl(t, x, y):
        return f'<div style="position:absolute;left:{x}px;top:{y}px;font-family:CondBold;font-size:10px;letter-spacing:1px;color:var(--acc);background:rgba(10,10,12,.8);padding:2px 6px">{t}</div>'
    b1 = bar(12, 44, 3, "rounded", 1, SAMPLE, x=438, y=760)
    b2 = bar(12, 40, 3, "rounded", 1, {4: {"cd": 50}}, x=462, y=710)
    b3 = bar(12, 40, 3, "rounded", 1, {}, x=462, y=663, keys=["S-" + k for k in KEYS])
    b4 = bar(12, 36, 3, "rounded", 12, {}, x=1290, y=240, keys=["C-" + k for k in KEYS])
    pet = bar(10, 30, 3, "circle", 1, {1: {"state": "range"}}, x=559, y=622, keys=["", "", "", "", "", "", "", "", "", ""])
    ex = ('<div style="position:absolute;left:1060px;top:604px;width:40px;height:40px;border-radius:50%;background:#2a2d35;box-shadow:0 0 0 1px #000;'
          f'display:flex;align-items:center;justify-content:center;color:#ff6a6a;font-family:CondBold;font-size:18px;{mv}">✕</div>')
    wrap = lambda html: html.replace('style="position:absolute;', f'style="{mv}position:absolute;', 1)
    body = (CSS + '<div style="position:absolute;inset:0;background:radial-gradient(ellipse at 50% 30%,#2c3a4a,#0d1015 70%)"></div>'
            + wrap(b1) + wrap(b2) + wrap(b3) + wrap(b4) + wrap(pet) + ex
            + lbl("BAR 1", 438, 742) + lbl("BAR 2", 462, 692) + lbl("BAR 3", 462, 645) + lbl("BAR 4", 1290, 222) + lbl("PET BAR", 559, 604) + lbl("VEHICLE EXIT", 1040, 586)
            + '<div style="position:absolute;left:520px;top:40px;width:400px;padding:12px 16px;background:#16181e;border:1px solid var(--acc);box-shadow:0 0 12px rgba(255,61,0,.45);'
              'font-family:Roboto;font-size:12px;color:#c9ced8"><b style="font-family:CondBold;letter-spacing:1px;color:#fff">LAYOUT MODE</b><br>Drag a bar, the pet bar or the vehicle exit to move it. '
              'Positions save per profile; Layout mode closes in combat.</div>')
    return (f'<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="s6.css"></head><body style="--bw:1440px;--bh:880px">'
            f'<div style="position:absolute;left:0;top:0;width:1440px;height:860px;overflow:hidden">{body}</div>'
            '<div class="cap">Mockup of Phoenix UI 2.0 S7 action bars in Layout mode (HTML, not an in-game screenshot)</div></body></html>')


PAGES = {"s7_bars": bars_tab, "s7_buttons": buttons_tab, "s7_text": text_tab, "s7_extra": extra_tab,
         "s7_cooldowntext": cooldowntext, "s7_layout": world}

if __name__ == "__main__":
    dest = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    dest.mkdir(parents=True, exist_ok=True)
    for name, fn in PAGES.items():
        html = SRC / f"{name}.html"
        html.write_text(fn().replace("Mockup of Phoenix UI 2.0 S6 settings window v2", "Mockup of Phoenix UI 2.0 S7 action bars (HTML)"), encoding="utf-8")
        w = 1440 if name == "s7_layout" else 1360
        png = dest / f"{name}.png"
        subprocess.run(["google-chrome", "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
                        "--allow-file-access-from-files", f"--window-size={w},880", f"--screenshot={png}", html.as_uri()],
                       check=True, capture_output=True)
        print(png)
