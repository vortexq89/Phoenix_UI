#!/usr/bin/env python3
"""Builds Phoenix_UI's bundled fonts from a google/fonts checkout and writes Core/FontData.lua.

Every font is OFL 1.1 (Ubuntu: Ubuntu Font Licence 1.0). Variable fonts are pinned to static instances (the WoW client
does not select variable-font instances), then subset to the scripts WoW's western and Russian clients need: Latin,
Latin-1, Latin Extended-A/B, Greek, Cyrillic, general punctuation, currency and a few symbols. Hinting and the kern
feature are kept; the rest of GSUB/GPOS is dropped because the client does no OpenType shaping. CJK clients fall
back to the game font (Core/Media.lua), so no CJK font is shipped (a Noto Sans CJK weight alone is ~16 MB).

Usage (repo root):
    git clone --depth 1 --filter=blob:none --sparse https://github.com/google/fonts.git /tmp/gfonts
    (cd /tmp/gfonts && git sparse-checkout set ofl/<family> ...)   # the families below
    python3 tools/media/gen_fonts.py /tmp/gfonts
"""
import io
import re, os, shutil, sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/gfonts"
OUT = "Media/Fonts"
LICENSES = f"{OUT}/Licenses"
DATA = "Core/FontData.lua"
WEIGHTS = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}

# (key prefix, display family, google/fonts dir, file stem, source, weights, extra axes, licence file, category)
# source "var" = <stem>[axes].ttf, "static" = <stem>-<Weight>.ttf
FAMILIES = [
    ("Inter", "Inter", "ofl/inter", "Inter", "Inter[opsz,wght].ttf", ["Regular", "Medium", "SemiBold", "Bold"], {"opsz": 14}, "OFL.txt", "sans"),
    ("Barlow", "Barlow", "ofl/barlow", "Barlow", "static", ["Regular", "Medium", "SemiBold", "Bold"], {}, "OFL.txt", "sans"),
    ("BarlowSemiCond", "Barlow Semi Condensed", "ofl/barlowsemicondensed", "BarlowSemiCondensed", "static", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "condensed"),
    ("BarlowCond", "Barlow Condensed", "ofl/barlowcondensed", "BarlowCondensed", "static", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "condensed"),
    ("Rajdhani", "Rajdhani", "ofl/rajdhani", "Rajdhani", "static", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "display"),
    ("Oswald", "Oswald", "ofl/oswald", "Oswald", "Oswald[wght].ttf", ["Regular", "Medium", "SemiBold"], {}, "OFL.txt", "condensed"),
    ("Exo2", "Exo 2", "ofl/exo2", "Exo2", "Exo2[wght].ttf", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "display"),
    ("Montserrat", "Montserrat", "ofl/montserrat", "Montserrat", "Montserrat[wght].ttf", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "sans"),
    ("FiraSans", "Fira Sans", "ofl/firasans", "FiraSans", "static", ["Regular", "Medium", "SemiBold", "Bold"], {}, "OFL.txt", "sans"),
    ("FiraCond", "Fira Sans Condensed", "ofl/firasanscondensed", "FiraSansCondensed", "static", ["Medium", "SemiBold"], {}, "OFL.txt", "condensed"),
    ("NotoSans", "Noto Sans", "ofl/notosans", "NotoSans", "NotoSans[wdth,wght].ttf", ["Regular", "Medium", "Bold"], {"wdth": 100}, "OFL.txt", "sans"),
    ("OpenSans", "Open Sans", "ofl/opensans", "OpenSans", "OpenSans[wdth,wght].ttf", ["Regular", "SemiBold", "Bold"], {"wdth": 100}, "OFL.txt", "sans"),
    ("Lato", "Lato", "ofl/lato", "Lato", "static", ["Regular", "Bold"], {}, "OFL.txt", "sans"),
    ("Ubuntu", "Ubuntu", "ufl/ubuntu", "Ubuntu", "static", ["Regular", "Medium", "Bold"], {}, "UFL.txt", "sans"),
    ("Manrope", "Manrope", "ofl/manrope", "Manrope", "Manrope[wght].ttf", ["Medium", "Bold"], {}, "OFL.txt", "sans"),
    ("SpaceGrotesk", "Space Grotesk", "ofl/spacegrotesk", "SpaceGrotesk", "SpaceGrotesk[wght].ttf", ["Medium", "Bold"], {}, "OFL.txt", "sans"),
    ("Sora", "Sora", "ofl/sora", "Sora", "Sora[wght].ttf", ["SemiBold"], {}, "OFL.txt", "sans"),
    ("Titillium", "Titillium Web", "ofl/titilliumweb", "TitilliumWeb", "static", ["Regular", "SemiBold", "Bold"], {}, "OFL.txt", "sans"),
    ("ArchivoNarrow", "Archivo Narrow", "ofl/archivonarrow", "ArchivoNarrow", "ArchivoNarrow[wght].ttf", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "condensed"),
    ("PTSansNarrow", "PT Sans Narrow", "ofl/ptsansnarrow", "PTSansNarrow", "ptsans", ["Regular", "Bold"], {}, "OFL.txt", "condensed"),
    ("SairaSemi", "Saira Semi Condensed", "ofl/sairasemicondensed", "SairaSemiCondensed", "static", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "condensed"),
    ("Khand", "Khand", "ofl/khand", "Khand", "static", ["Medium", "SemiBold"], {}, "OFL.txt", "condensed"),
    ("Teko", "Teko", "ofl/teko", "Teko", "Teko[wght].ttf", ["Medium", "SemiBold"], {}, "OFL.txt", "display"),
    ("Kanit", "Kanit", "ofl/kanit", "Kanit", "static", ["Medium", "SemiBold"], {}, "OFL.txt", "display"),
    ("ChakraPetch", "Chakra Petch", "ofl/chakrapetch", "ChakraPetch", "static", ["Medium", "SemiBold", "Bold"], {}, "OFL.txt", "display"),
    ("Oxanium", "Oxanium", "ofl/oxanium", "Oxanium", "Oxanium[wght].ttf", ["Medium", "Bold"], {}, "OFL.txt", "display"),
    ("Play", "Play", "ofl/play", "Play", "static", ["Regular", "Bold"], {}, "OFL.txt", "display"),
    ("Quantico", "Quantico", "ofl/quantico", "Quantico", "static", ["Regular", "Bold"], {}, "OFL.txt", "display"),
    ("BebasNeue", "Bebas Neue", "ofl/bebasneue", "BebasNeue", "static", ["Regular"], {}, "OFL.txt", "display"),
    ("RussoOne", "Russo One", "ofl/russoone", "RussoOne", "static", ["Regular"], {}, "OFL.txt", "display"),
    ("BlackOps", "Black Ops One", "ofl/blackopsone", "BlackOpsOne", "static", ["Regular"], {}, "OFL.txt", "display"),
    ("Cinzel", "Cinzel", "ofl/cinzel", "Cinzel", "Cinzel[wght].ttf", ["Regular", "Bold"], {}, "OFL.txt", "serif"),
    ("JetBrainsMono", "JetBrains Mono", "ofl/jetbrainsmono", "JetBrainsMono", "JetBrainsMono[wght].ttf", ["Medium", "Bold"], {}, "OFL.txt", "mono"),
    ("RobotoMono", "Roboto Mono", "ofl/robotomono", "RobotoMono", "RobotoMono[wght].ttf", ["Medium"], {}, "OFL.txt", "mono"),
]

UNICODES = (
    list(range(0x20, 0x7F)) + list(range(0xA0, 0x250)) +        # Basic Latin, Latin-1, Latin Extended-A/B
    list(range(0x370, 0x400)) + list(range(0x400, 0x530)) +     # Greek, Cyrillic + Supplement
    list(range(0x1E00, 0x1F00)) +                               # Latin Extended Additional
    list(range(0x2000, 0x2070)) + list(range(0x20A0, 0x20C0)) + # punctuation, currency
    [0x2122, 0x2190, 0x2191, 0x2192, 0x2193, 0x2212, 0x221E, 0x2022, 0x25B2, 0x25BC, 0x25CF, 0x2605, 0x2713, 0x2715]
)

def source_path(d, stem, src, weight):
    if src == "static":
        return f"{SRC}/{d}/{stem}-{weight}.ttf"
    if src == "ptsans":
        return f"{SRC}/{d}/PT_Sans-Narrow-Web-{weight}.ttf"
    return f"{SRC}/{d}/{src}"

def reserved_name(d, lic):
    """OFL fonts with a Reserved Font Name may not be modified under that name, and the Ubuntu Font Licence
    asks the same; those are shipped byte-for-byte as published (static files only)."""
    if lic == "UFL.txt":
        return True
    with open(f"{SRC}/{d}/{lic}", encoding="utf-8") as f:
        head = "".join(f.readline() for _ in range(4))
    return re.search(r"reserved font name", head, re.I) is not None

def build(d, stem, src, weight, axes, raw):
    path = source_path(d, stem, src, weight)
    font = TTFont(path)
    if raw:
        assert "fvar" not in font, f"{path}: reserved-name font must be a static file"
        cmap = font.getBestCmap()
        with open(path, "rb") as f:
            return f.read(), all(c in cmap for c in range(0x410, 0x450))
    if "fvar" in font:
        limits = {a.axisTag: a.defaultValue for a in font["fvar"].axes}
        limits.update(axes)
        limits["wght"] = WEIGHTS[weight]
        font = instancer.instantiateVariableFont(font, limits, updateFontNames=False)
    opts = subset.Options()
    opts.layout_features = ["kern"]
    opts.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
    opts.notdef_outline = True
    opts.hinting = True
    opts.legacy_kern = True
    s = subset.Subsetter(opts)
    s.populate(unicodes=UNICODES)
    s.subset(font)
    cmap = font.getBestCmap()
    cyrillic = all(c in cmap for c in range(0x410, 0x450))
    buf = io.BytesIO(); font.save(buf)
    return buf.getvalue(), cyrillic

def lua_str(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def main():
    os.makedirs(LICENSES, exist_ok=True)
    rows, total, report = [], 0, []
    for key, family, d, stem, src, weights, axes, lic, cat in FAMILIES:
        fam_bytes, raw = 0, reserved_name(d, lic)
        for w in weights:
            data, cyr = build(d, stem, src, w, axes, raw)
            name = f"{stem}-{w}.ttf"
            with open(f"{OUT}/{name}", "wb") as f: f.write(data)
            fam_bytes += len(data)
            rows.append((f"{key}{w}", f"{family} {w}", name, family, w, cat, cyr))
        lic_name = f"{'UFL' if lic == 'UFL.txt' else 'OFL'}-{stem}.txt"
        shutil.copyfile(f"{SRC}/{d}/{lic}", f"{LICENSES}/{lic_name}")
        total += fam_bytes
        report.append((family, len(weights), fam_bytes, lic_name, rows[-1][6]))
    keys = [r[0] for r in rows]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    assert not dupes, f"duplicate font keys: {dupes}"
    with open(DATA, "w", newline="\n") as f:
        f.write("local _, ns = ...\n\n")
        f.write("-- GENERATED by tools/media/gen_fonts.py from google/fonts. Do not edit by hand.\n")
        f.write("-- Licences: Media/Fonts/Licenses (SIL OFL 1.1; Ubuntu Font Licence 1.0 for Ubuntu).\n")
        f.write("-- cyrillic: the subset covers А-я, so the font is registered for ruRU clients too.\n")
        f.write("ns.FontData = {\n")
        for key, label, file, family, weight, cat, cyr in rows:
            f.write(f"    {{ key = {lua_str(key)}, name = {lua_str('Phoenix ' + label)}, file = {lua_str(file)},\n"
                    f"      family = {lua_str(family)}, weight = {lua_str(weight)}, category = {lua_str(cat)}, cyrillic = {'true' if cyr else 'false'} }},\n")
        f.write("}\n")
    for family, n, b, lic, cyr in report:
        print(f"{family:24s} {n} weights {b / 1024:7.0f} KB  {lic}  cyrillic={cyr}")
    print(f"total {total / 1024 / 1024:.2f} MB in {len(rows)} files")

main()
