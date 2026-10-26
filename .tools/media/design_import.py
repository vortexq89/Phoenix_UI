#!/usr/bin/env python3
"""Imports the approved design package (ship/Media) into Phoenix_UI_Media and
adds the extra UI font weights it needs, then rewrites the manifest.

  python3 .tools/media/design_import.py /workspace/pui_design/ship/Media
"""
import json, os, shutil, sys, urllib.request
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import manifest as mm

SRC = sys.argv[1]
DST = mm.MEDIA
ROOT = mm.ROOT
ORIG = "Original (Phoenix UI)"
AUTHOR = "Phoenix UI (VortexQ8)"
SOURCE = "Phoenix UI design package v3 (pui_design/src)"
entries = json.load(open(mm.MANIFEST, encoding="utf-8"))
have = {e["file"] for e in entries}


def add(rel, kind, name, licence=ORIG, author=AUTHOR, source=SOURCE, changes="none", **extra):
    if rel in have:
        for e in entries:
            if e["file"] == rel:
                e.update(type=kind, name=name, licence=licence, author=author, source=source, changes=changes, **extra)
        return
    have.add(rel)
    entries.append(dict(file=rel, type=kind, name=name, source=source, author=author, licence=licence, changes=changes, **extra))


def nice(stem):
    out = ""
    for i, ch in enumerate(stem.replace("_", " ")):
        if i and ch.isupper() and stem[i - 1].islower():
            out += " "
        out += ch
    return out.strip()


KIND = {"StatusBar": "statusbar", "Panel": "background"}
for dp, _, fns in os.walk(SRC):
    for f in sorted(fns):
        if not (f.endswith(".tga") or f.endswith(".ogg")):
            continue
        rel_src = os.path.relpath(os.path.join(dp, f), SRC).replace(os.sep, "/")
        parts = rel_src.split("/")
        if parts[0] == "Sounds":
            rel = "Sounds/Phoenix_" + f
            kind, name = "sound", "Phoenix: " + nice(f[:-4])
        elif parts[0] == "Icons":
            rel = rel_src
            kind = "icon" if parts[1] == "Abilities" else "moduleicon"
            name = ("Ability " if parts[1] == "Abilities" else "Module ") + "/".join(parts[2:-1] + [f[:-4]]) if parts[1] != "Abilities" else "Ability " + f[:-4]
        else:
            rel = rel_src
            kind = KIND.get(parts[1], "texture")
            name = nice(f[:-4]) if kind in ("statusbar", "background") else "/".join(parts[1:])[:-4]
            if kind == "statusbar":
                name = "Phoenix " + name
            if kind == "background":
                name = "Phoenix " + name
        os.makedirs(os.path.dirname(os.path.join(DST, rel)), exist_ok=True)
        shutil.copyfile(os.path.join(dp, f), os.path.join(DST, rel))
        add(rel, kind, name, changes="none" if parts[0] != "Sounds" else "renamed with Phoenix_ prefix")

# LibSharedMedia borders are backdrop edge files (8 segments in a row); cut
# them from the design's 1px and soft nine-slice outlines.
def edge_from_nineslice(src_rel, out_rel, name, seg):
    im = Image.open(os.path.join(DST, src_rel)).convert("RGBA")
    w, h = im.size
    m = seg
    left = im.crop((0, m, m, h - m)).resize((m, m))
    right = im.crop((w - m, m, w, h - m)).resize((m, m))
    top = im.crop((m, 0, w - m, m)).resize((m, m)).rotate(90, expand=True)
    bottom = im.crop((m, h - m, w - m, h)).resize((m, m)).rotate(90, expand=True)
    corners = [im.crop((0, 0, m, m)), im.crop((w - m, 0, w, m)), im.crop((0, h - m, m, h)), im.crop((w - m, h - m, w, h))]
    strip = Image.new("RGBA", (m * 8, m))
    for i, p in enumerate([left, right, top, bottom] + corners):
        strip.paste(p, (i * m, 0))
    strip.save(os.path.join(DST, out_rel))
    add(out_rel, "border", name, changes="backdrop edge strip cut from " + src_rel)

edge_from_nineslice("Textures/NineSlice/Border_1px.tga", "Border/PhoenixLine.tga", "Phoenix Line", 8)
edge_from_nineslice("Textures/NineSlice/Border_Soft.tga", "Border/PhoenixSoft.tga", "Phoenix Soft", 16)

# Extra static weights the design uses (Inter Bold, Rajdhani Bold), OFL.
RAW = "https://raw.githubusercontent.com/google/fonts/main/ofl/%s/%s"
for name, d, f, ax, out in [("Inter Bold", "inter", "Inter[opsz,wght].ttf", {"wght": 700, "opsz": 14}, "Inter-Bold.ttf"),
                            ("Rajdhani Bold", "rajdhani", "Rajdhani-Bold.ttf", None, "Rajdhani-Bold.ttf")]:
    tmp = "/tmp/" + d + "_" + f.replace("[", "_").replace("]", "_").replace(",", "_")
    if not os.path.exists(tmp):
        urllib.request.urlretrieve(RAW % (d, urllib.request.quote(f)), tmp)
    font = TTFont(tmp)
    if ax:
        font = instancer.instantiateVariableFont(font, ax, updateFontNames=False)
    for t in ("STAT", "MVAR", "HVAR", "avar", "fvar", "gvar"):
        if t in font:
            del font[t]
    font.save(os.path.join(DST, "Fonts", out))
    add("Fonts/" + out, "font", name, licence="SIL OFL 1.1", author=TTFont(tmp)["name"].getDebugName(0) or "",
        source="https://github.com/google/fonts/tree/main/ofl/" + d, changes=("static instance " + json.dumps(ax)) if ax else "none",
        coverage="Latin, Devanagari" if d == "rajdhani" else "Latin, Cyrillic, Greek")
    lic = os.path.join(mm.CHILD, "Licenses", d + "-OFL.txt")
    if not os.path.exists(lic):
        urllib.request.urlretrieve(RAW % (d, "OFL.txt"), lic)

json.dump(entries, open(mm.MANIFEST, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
mm.write_lua(entries)
mm.write_md(entries)
print("entries", len(entries))
