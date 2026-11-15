"""Enumerate every user-facing setting EllesmereUI's options code defines.

Reads EllesmereUIOptions/**.lua (read-only copy of the user's I:\\ drive) and finds each widget table
{ type="toggle|slider|dropdown|colorpicker|...", text|label="..." , min=, max=, step=, ... }
plus W:SectionHeader(parent, "TITLE"). Output: data/eui_settings.json + per-file counts.
"""
import json, re, pathlib, collections
import os
ROOT = pathlib.Path(os.environ.get("EUI_ROOT","/workspace/i_drive/EllesmereUIOptions"))
TYPES = {"slider", "toggle", "dropdown", "colorpicker", "multiSwatch", "multiswatch", "input", "checkbox",
         "segmented", "keybind", "multi", "reorder", "reordercheck", "labeledButton", "button"}
SETTING = TYPES - {"button", "labeledButton"}
tre = re.compile(r'type\s*=\s*"([A-Za-z]+)"')
sec = re.compile(r'(?:W|Widgets):SectionHeader\(\s*\w+\s*,\s*(?:MH\()?"([^"]+)"')
page = re.compile(r'(?:RegisterPage|pageName|PAGE_[A-Z_]+)\s*=\s*"([^"]+)"')

def block(s, i):
    # find enclosing { ... } around index i
    depth, j = 0, i
    while j > 0:
        c = s[j]
        if c == "}": depth += 1
        elif c == "{":
            if depth == 0: break
            depth -= 1
        j -= 1
    k, depth = j, 0
    while k < len(s):
        c = s[k]
        if c == "{": depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0: break
        k += 1
    return s[j:k + 1]

def field(b, name):
    m = re.search(r'\b' + name + r'\s*=\s*("([^"]*)"|-?[\d.]+)', b)
    if not m: return None
    return m.group(2) if m.group(2) is not None else m.group(1)

out = []
single = re.compile(r'(?:W|Widgets):(Toggle|Slider|Dropdown|ColorPicker)\(\s*\w+\s*,\s*"([^"]+)"')
for f in sorted(ROOT.rglob("*.lua")):
    s = f.read_text(encoding="utf-8", errors="replace")
    events = [(m.start(), "section", m.group(1)) for m in sec.finditer(s)]
    events += [(m.start(), "w", m.group(1)) for m in tre.finditer(s) if m.group(1) in TYPES]
    events += [(m.start(), "single", (m.group(1).lower().replace("colorpicker","colorpicker"), m.group(2))) for m in single.finditer(s)]
    events.sort()
    cur = ""
    for pos, kind, val in events:
        if kind == "section":
            cur = val; continue
        if kind == "single":
            out.append({"file": str(f.relative_to(ROOT)), "section": cur, "type": val[0], "label": val[1], "min": None, "max": None, "step": None, "line": s.count("\n", 0, pos) + 1}); continue
        b = block(s, pos)
        if len(b) > 4000: b = b[:4000]
        label = field(b, "text") or field(b, "label") or field(b, "tooltip")
        if not label:
            continue
        out.append({"file": str(f.relative_to(ROOT)), "section": cur, "type": val, "label": label,
                    "min": field(b, "min"), "max": field(b, "max"), "step": field(b, "step"),
                    "line": s.count("\n", 0, pos) + 1})
# dedupe identical (file, section, type, label)
seen, uniq = set(), []
for r in out:
    k = (r["file"], r["section"], r["type"], r["label"])
    if k in seen: continue
    seen.add(k); uniq.append(r)
pathlib.Path(os.environ.get("OUT","/workspace/phoenix_plan_v2/data/eui_settings.json")).write_text(json.dumps(uniq, indent=1))
c = collections.Counter(r["file"] for r in uniq if r["type"] in SETTING)
for k, v in sorted(c.items(), key=lambda x: -x[1]): print(f"{v:5d} {k}")
print("total settings", sum(c.values()), "rows", len(uniq))
