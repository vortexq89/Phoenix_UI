#!/usr/bin/env python3
"""Phoenix "Ember Bevel" chrome atlases (t169). Original Phoenix art (Phoenix UI licence). UI chrome only (micro
menu, settings nav, tabs and module tiles, macro window controls, window controls, panel corner icons); never
class, spec, ability, spell, item, mount, pet or toy icons.

Sources:
  tools/media/chrome_bevel/*_{64,16}.png  the approved Ember Bevel set (manifest.csv names each icon's source line)
  OVERRIDES below                          re-drawn so look-alike pairs read apart (rendered with ember_bevel.py)
  tools/media/chrome_bevel/panel_round/    the approved round portrait medallions (DESIGN_SYSTEM_V3 §5b), 28 panels;
                                           panel-collections is re-drawn here (medallion()) so it doesn't repeat
                                           the micro menu's cube
Writes, per state (normal, hover, pressed, disabled):
  Media/Icons/Bevel64_<state>.tga   1024x512, 16x8 cells of 64 (4 px glow margin: the frame is 56/64 of a cell)
  Media/Icons/Bevel16_<state>.tga   256x128, 16x8 cells of 16: the simplified small variant
  Media/Icons/Panel128_<state>.tga  1024x512, 8x4 cells of 128: the 28 panel medallions
and UI/ChromeBevelData.lua (name -> cell). Usage: python3 tools/media/gen_chrome_bevel.py"""
import csv, os, sys
from concurrent.futures import ProcessPoolExecutor
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ember_bevel as eb
from gen_chrome_color import PANEL, _mask

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
# the approved themed sets (t169) live outside the repo (large masters); point PUI_CHROME_ART elsewhere if needed
ART = os.environ.get("PUI_CHROME_ART", "/workspace/phoenix-art/out/full/themes")
MANIFEST = os.path.join(HERE, "chrome_bevel", "manifest.csv")
# pre-rendered themes; class and custom accents use "neutral", tinted in game with SetVertexColor
THEMES = {"ember": 20, "frost": 205, "fel": 105, "arcane": 275, "neutral": None}  # hue of each ramp (for overrides)
STATES = ["normal", "hover", "pressed", "disabled"]

# look-alike pairs, re-drawn on the 24 grid (t169): module-actionbars was close to tab-layout, module-groupframes to
# nav-bars, and panel-collections to micro-collections
OVERRIDES = {
    "module-actionbars": '<rect x="4" y="4" width="16" height="16" rx="2.5"/><path d="M12 12V6.5a5.5 5.5 0 015.5 5.5z"/><path d="M7 16.5h3.5"/>',  # one button: cooldown sweep and hotkey
    "module-groupframes": '<rect x="4" y="3.5" width="16" height="3" rx="1"/><rect x="4" y="8.5" width="11" height="3" rx="1"/>'
                          '<rect x="4" y="13.5" width="14" height="3" rx="1"/><rect x="4" y="18.5" width="8" height="3" rx="1"/>',
}
PANEL_GLYPHS = dict(PANEL)
PANEL_GLYPHS["panel-collections"] = ('<ellipse cx="12" cy="16.5" rx="4.2" ry="3.4"/><circle cx="5.6" cy="10.8" r="1.7"/><circle cx="9.3" cy="6.4" r="1.7"/>'
                                    '<circle cx="14.7" cy="6.4" r="1.7"/><circle cx="18.4" cy="10.8" r="1.7"/>')  # a paw: pets and mounts
# the 28th panel: the Great Vault window (Phoenix_UI_Skins/Vault.lua, Skins key "vault")
PANEL_GLYPHS["panel-vault"] = '<rect x="3.5" y="3.5" width="17" height="17" rx="2"/><circle cx="12" cy="12" r="4.5"/><path d="M12 7.5v2M12 14.5v2M7.5 12h2M14.5 12h2"/>'


def glyph_mask(body, M, sw=2.5, scale=0.75):
    n = int(M * scale)
    m = ImageChops.lighter(_mask(body, n, sw, False), _mask(body, n, sw, True).point(lambda v: int(v * 0.62)))
    out = Image.new("L", (M, M), 0)
    out.paste(m, ((M - n) // 2, (M - n) // 2))
    return out


def square(job):
    name, state, size, simple = job
    eb.M, eb.S = 1024, 1024 / 64
    eb.BEVEL, eb.RIVETS = (3, False) if simple else (4, True)
    eb.GLYPHS["_g"] = lambda: glyph_mask(OVERRIDES[name], eb.M, 3.0 if simple else 2.5)
    return eb.down(eb.render("_g", state), size)


def medallion(job):
    """A round medallion at 128 (4 px margin, 120 px disc, 6 px gold rim, 2 px crimson ring at 10 px inset)."""
    name, state = job
    M = 1024
    eb.M, eb.S = M, M / 64
    k = M / 128
    c = M / 2
    def disc(r):
        m = Image.new("L", (M, M), 0); ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255); return m
    R = 54 * k  # matches the approved medallions' disc
    well, _ = eb.frame_layers()  # the painterly obsidian well, cut to the disc
    inner = disc(R - 9 * k)
    img = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    if state in ("hover", "pressed"):
        g = ImageChops.subtract(disc(R + 2 * k), disc(R - 3 * k)).filter(ImageFilter.GaussianBlur(2.5 * k))
        a = 1.0 if state == "pressed" else 0.8
        img = Image.alpha_composite(img, Image.merge("RGBA", (*Image.new("RGB", (M, M), eb.GLOW).split(),
                                                              g.point(lambda v: int(min(255, v * 1.6) * a)))))
    w = Image.new("RGBA", (M, M), (0, 0, 0, 0)); w.paste(well, (0, 0), inner)
    img = Image.alpha_composite(img, w)
    content = Image.new("RGBA", (M, M), (0, 0, 0, 0))
    if state == "pressed": content = Image.alpha_composite(content, eb.rays())
    gl = eb.glyph_layer(glyph_mask(PANEL_GLYPHS[name], M, 2.5, 0.6), {"normal": 1.15, "hover": 1.27, "pressed": 1.4, "disabled": 1.0}[state])
    if state == "pressed": gl = eb.scale_about_centre(gl, 0.94)
    content = Image.alpha_composite(content, gl)
    content.putalpha(ImageChops.multiply(content.split()[3], inner))
    img = Image.alpha_composite(img, content)
        # gold rim, lit from the top: the ember ramp from pale gold down to ember, dark rim lines on both edges
    rim = ImageChops.subtract(disc(R), inner)
    grad = eb.vgrad(int(c - R * 1.2), int(c + R * 1.3))
    img = Image.alpha_composite(img, Image.merge("RGBA", (*grad.split(), rim)))
    for r in (R, R - 9 * k):
        line = ImageChops.subtract(disc(r), disc(r - 1 * k))
        img = Image.alpha_composite(img, Image.merge("RGBA", (*Image.new("RGB", (M, M), eb.RIM).split(), line)))
    img = Image.alpha_composite(img, Image.merge("RGBA", (*[Image.new("L", (M, M), 255)] * 3,
                                                          ImageChops.multiply(eb.gloss().split()[3], inner))))
    if state == "disabled":
        a = img.split()[3]; img = img.convert("L").convert("RGBA"); img.putalpha(a.point(lambda v: int(v * 0.6)))
    return eb.down(img, 128)


def recolour(im, theme):
    """Moves an ember-rendered override into another theme's family: the hue rotated, or grey for neutral."""
    hue = THEMES[theme]
    if theme == "ember":
        return im
    a = im.split()[3]
    if hue is None:
        g = ImageEnhance.Brightness(im.convert("L").convert("RGB")).enhance(1.25)
        out = g.convert("RGBA")
    else:
        h, sat, v = im.convert("RGB").convert("HSV").split()
        shift = int((hue - THEMES["ember"]) / 360 * 255)
        h = h.point(lambda x: (x + shift) % 256)
        out = Image.merge("HSV", (h, sat, v)).convert("RGB").convert("RGBA")
    out.putalpha(a)
    return out


def boost(im, theme, size):
    # arcane's violet ramp is dark at small sizes: lift contrast and brightness on its 16 px cells
    if theme != "arcane" or size != 16:
        return im
    a = im.split()[3]
    rgb = ImageEnhance.Brightness(ImageEnhance.Contrast(im.convert("RGB")).enhance(1.35)).enhance(1.15)
    out = rgb.convert("RGBA"); out.putalpha(a)
    return out


_FILES = {}
def src(theme, fname):
    """Finds an approved file in a theme's category folders (micro/, settings/, panel_round/ ...)."""
    if theme not in _FILES:
        _FILES[theme] = {}
        for sub in os.listdir(os.path.join(ART, theme)):
            d = os.path.join(ART, theme, sub)
            if os.path.isdir(d) and sub != "panel":  # panel/ holds the square references, panel_round/ ships
                for f in os.listdir(d):
                    _FILES[theme][f] = os.path.join(d, f)
    return Image.open(_FILES[theme][fname]).convert("RGBA")


def save(im, path):
    im.save(path, compression="tga_rle")  # transparent margins compress well; WoW reads RLE TGA


def overlays(out):
    """White overlays, tinted in game: the hover/pressed glow in the 4 px margin (square and round) and the burst."""
    M = 1024
    eb.M, eb.S = M, M / 64
    white = lambda a: Image.merge("RGBA", (*[Image.new("L", (M, M), 255)] * 3, a))
    save(eb.down(white(eb.outer_glow(1.0).split()[3]), 64), os.path.join(out, "GlowSquare.tga"))
    save(eb.down(white(eb.rays().split()[3]), 64), os.path.join(out, "Burst.tga"))
    k, c = M / 128, M / 2
    def disc(r):
        m = Image.new("L", (M, M), 0); ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255); return m
    g = ImageChops.subtract(disc(58 * k), disc(52 * k)).filter(ImageFilter.GaussianBlur(3 * k))
    save(eb.down(white(g.point(lambda v: min(255, int(v * 1.8)))), 128), os.path.join(out, "GlowRound.tga"))


def main():
    names = sorted(r["name"] for r in csv.DictReader(open(MANIFEST)) if r["category"] not in ("panel", "panel_round"))
    panels = sorted(PANEL_GLYPHS)
    assert len(names) <= 128 and len(panels) <= 32
    out = os.path.join(ROOT, "Media", "Icons", "Chrome")
    os.makedirs(out, exist_ok=True)
    with ProcessPoolExecutor() as ex:
        keys = [(n, s, z) for n in OVERRIDES for s in STATES for z in (64, 16)]
        over = dict(zip(keys, ex.map(square, [(n, s, z, z == 16) for n, s, z in keys])))
        mine = ["panel-collections"]
        med = dict(zip([(n, s) for n in mine for s in STATES], ex.map(medallion, [(n, s) for n in mine for s in STATES])))
    for theme in THEMES:
        # disabled is grey whatever the theme: one shared set, taken from neutral
        # only the normal look ships per theme (size): hover and pressed are drawn in game from it with the
        # shared glow and light-burst overlays below (UI/ChromeBevel.lua)
        states = ["normal", "disabled"] if theme == "neutral" else ["normal"]
        for st in states:
            tag = "Disabled" if st == "disabled" else f"{theme.capitalize()}_{st}"
            for z in (64, 16):
                im = Image.new("RGBA", (16 * z, 8 * z), (0, 0, 0, 0))
                for i, n in enumerate(names):
                    tile = over.get((n, st, z))
                    tile = recolour(tile, theme) if tile else src(theme, f"{n}_{st}_{z}.png")
                    im.alpha_composite(boost(tile, theme, z), ((i % 16) * z, (i // 16) * z))
                save(im, os.path.join(out, f"{tag}{z}.tga"))
            im = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
            for i, n in enumerate(panels):
                tile = med.get((n, st))
                tile = recolour(tile, theme) if tile else src(theme, f"{n}_{st}_128.png")
                im.alpha_composite(tile, ((i % 8) * 128, (i // 8) * 128))
            save(im, os.path.join(out, f"{tag}Panel.tga"))
    overlays(out)
    lines = ["-- Generated by tools/media/gen_chrome_bevel.py: chrome glyph -> cell (0-based). Do not edit.",
             "local _, ns = ...", "ns.ChromeBevelData = {", "    cells = {"]
    lines += [f'        ["{n}"] = {i},' for i, n in enumerate(names)]
    lines += ["    },", "    panels = {"]
    lines += [f'        ["{n}"] = {i},' for i, n in enumerate(panels)]
    lines += ["    },", "}", ""]
    open(os.path.join(ROOT, "UI", "ChromeBevelData.lua"), "w").write("\n".join(lines))
    print(len(names), "chrome icons,", len(panels), "panels,", len(THEMES), "themes")


if __name__ == "__main__":
    main()
