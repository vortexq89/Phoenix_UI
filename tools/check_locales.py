#!/usr/bin/env python3
"""Locale coverage: every key the code uses must exist in Locales/enUS.lua, and every enUS key must be used.
Every translation (Locales/<locale>.lua) must define exactly the enUS keys, with the same format specifiers,
line breaks and colour codes, and be listed in Locales/Locales.xml.

Keys are found as L.KEY / L["KEY"] and as UPPER_SNAKE string literals in option schemas and module
definitions (label/desc/text/button/title fields, value labels). Exit code 1 on any problem."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = [p for d in ("Core", "UI", "Modules", "Phoenix_UI_Options") + tuple(x.name for x in ROOT.glob("Phoenix_UI_*") if x.is_dir() and x.name != "Phoenix_UI_Data") for p in (ROOT / d).rglob("*.lua")]
KEY = r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*"
USE_PATTERNS = [
    re.compile(r"\bL\.(" + KEY + r")\b"),
    re.compile(r"\bL\[\"(" + KEY + r")\"\]"),
    re.compile(r"\b(?:label|desc|text|button|title|err|status|heading)\s*=\s*\"(" + KEY + r")\""),
    re.compile(r"\breturn\s+(?:nil|false),\s*\"(" + KEY + r")\""),
    re.compile(r"\"(CAT_[A-Z]+)\""),
    re.compile(r"\blabel\s+or\s+\"(" + KEY + r")\""),
    re.compile(r"\bOpt\.\w+\([^,()]+,\s*\"(" + KEY + r")\""),  # ns.Opt row builders: Opt.Text(path, "KEY")
    re.compile(r"\bsample\s*=\s*\"(" + KEY + r")\""),          # preview sample captions  # option kit defaults: label = label or "KEY"
]
# Locale keys built dynamically: prefix .. VALUE
DYNAMIC = re.compile(r"L\[\"(" + KEY + r"_)\"\s*\.\.")

used, dynamic_prefixes = {}, set()
for path in SRC:
    text = path.read_text(encoding="utf-8")
    for pat in USE_PATTERNS:
        for m in pat.finditer(text):
            used.setdefault(m.group(1), str(path.relative_to(ROOT)))
    dynamic_prefixes.update(DYNAMIC.findall(text))
    for block in re.findall(r"\blabels\s*=\s*\{([^}]*)\}", text):  # swatch group captions
        for key in re.findall(r"\"(" + KEY + r")\"", block):
            used.setdefault(key, str(path.relative_to(ROOT)))

en = (ROOT / "Locales" / "enUS.lua").read_text(encoding="utf-8")
defined = set(re.findall(r"^\s*(" + KEY + r")\s*=", en, re.M))
dupes = sorted({k for k in re.findall(r"^\s*(" + KEY + r")\s*=", en, re.M)
                if len(re.findall(r"^\s*" + k + r"\s*=", en, re.M)) > 1})

missing = sorted(k for k in used if k not in defined)
unused = sorted(k for k in defined if k not in used and not any(k.startswith(p) for p in dynamic_prefixes))
for k in missing:
    print(f"missing: {k}  (first used in {used[k]})")
for k in unused:
    print(f"unused:  {k}")
for k in dupes:
    print(f"duplicate: {k}")
print(f"{len(used)} keys used, {len(defined)} defined, {len(missing)} missing, {len(unused)} unused, {len(dupes)} duplicate")

# ---------------------------------------------------------------- translations
ENTRY = re.compile(r'^\s*(' + KEY + r')\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$', re.M)
SPEC = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?[sdifgxXc]")
MARKS = ("\\n", "|c", "|r", "|T", "|t")
en_values = dict(ENTRY.findall(en))
xml = (ROOT / "Locales" / "Locales.xml").read_text(encoding="utf-8")
problems = 0
for path in sorted((ROOT / "Locales").glob("*.lua")):
    if path.name in ("Locales.lua", "enUS.lua"):
        continue
    text = path.read_text(encoding="utf-8")
    entries = ENTRY.findall(text)
    keys = [k for k, _ in entries]
    have = dict(entries)
    bad = []
    bad += [f"missing {k}" for k in sorted(defined - set(have))]
    bad += [f"unknown {k}" for k in sorted(set(have) - defined)]
    bad += [f"duplicate {k}" for k in sorted({k for k in keys if keys.count(k) > 1})]
    for k, v in have.items():
        ev = en_values.get(k)
        if ev is None:
            continue
        if sorted(SPEC.findall(ev)) != sorted(SPEC.findall(v)):
            bad.append(f"{k}: format specifiers differ from enUS")
        bad += [f"{k}: {m!r} count differs from enUS" for m in MARKS if ev.count(m) != v.count(m)]
    if f'file="{path.name}"' not in xml:
        bad.append("not listed in Locales.xml")
    for b in bad:
        print(f"{path.stem}: {b}")
    problems += len(bad)
    print(f"{path.stem}: {len(have)}/{len(defined)} keys")
sys.exit(1 if missing or unused or dupes or problems else 0)
