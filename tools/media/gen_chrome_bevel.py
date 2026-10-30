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
from PIL import Image, ImageChops, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ember_bevel as eb
from gen_chrome_color import PANEL, _mask

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(HERE, "chrome_bevel")
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


def main():
    names = sorted(r["name"] for r in csv.DictReader(open(os.path.join(ART, "manifest.csv"))) if r["category"] != "panel")
    panels = sorted(PANEL_GLYPHS)
    assert len(names) <= 128 and len(panels) <= 32
    out = os.path.join(ROOT, "Media", "Icons")
    with ProcessPoolExecutor() as ex:
        over = dict(zip([(n, s, z) for n in OVERRIDES for s in STATES for z in (64, 16)],
                        ex.map(square, [(n, s, z, z == 16) for n in OVERRIDES for s in STATES for z in (64, 16)])))
        mine = ["panel-collections"]
        med = dict(zip([(n, s) for n in mine for s in STATES], ex.map(medallion, [(n, s) for n in mine for s in STATES])))
    for n in panels:
        for st in STATES:
            src = os.path.join(ART, "panel_round", f"{n}_{st}_128.png")
            if (n, st) not in med:
                med[(n, st)] = Image.open(src).convert("RGBA")
    for st in STATES:
        for z, tag in ((64, "Bevel64"), (16, "Bevel16")):
            im = Image.new("RGBA", (16 * z, 8 * z), (0, 0, 0, 0))
            for i, n in enumerate(names):
                tile = over.get((n, st, z)) or Image.open(os.path.join(ART, f"{n}_{st}_{z}.png")).convert("RGBA")
                im.alpha_composite(tile, ((i % 16) * z, (i // 16) * z))
            im.save(os.path.join(out, f"{tag}_{st}.tga"))
        im = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
        for i, n in enumerate(panels):
            im.alpha_composite(med[(n, st)], ((i % 8) * 128, (i // 8) * 128))
        im.save(os.path.join(out, f"Panel128_{st}.tga"))
    lines = ["-- Generated by tools/media/gen_chrome_bevel.py: chrome glyph -> cell (0-based). Do not edit.",
             "local _, ns = ...", "ns.ChromeBevelData = {", "    cells = {"]
    lines += [f'        ["{n}"] = {i},' for i, n in enumerate(names)]
    lines += ["    },", "    panels = {"]
    lines += [f'        ["{n}"] = {i},' for i, n in enumerate(panels)]
    lines += ["    },", "}", ""]
    open(os.path.join(ROOT, "UI", "ChromeBevelData.lua"), "w").write("\n".join(lines))
    print(len(names), "chrome icons,", len(panels), "panels")


if __name__ == "__main__":
    main()
