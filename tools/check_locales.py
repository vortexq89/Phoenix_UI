#!/usr/bin/env python3
"""Locale coverage: every key the code uses must exist in Locales/enUS.lua, and every enUS key must be used.

Keys are found as L.KEY / L["KEY"] and as UPPER_SNAKE string literals in option schemas and module
definitions (label/desc/text/button/title fields, value labels). Exit code 1 on any problem."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = [p for d in ("Core", "UI", "Modules") for p in (ROOT / d).rglob("*.lua")]
KEY = r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*"
USE_PATTERNS = [
    re.compile(r"\bL\.(" + KEY + r")\b"),
    re.compile(r"\bL\[\"(" + KEY + r")\"\]"),
    re.compile(r"\b(?:label|desc|text|button|title|err|status)\s*=\s*\"(" + KEY + r")\""),
    re.compile(r"\breturn\s+(?:nil|false),\s*\"(" + KEY + r")\""),
    re.compile(r"\"(CAT_[A-Z]+)\""),
    re.compile(r"\blabel\s+or\s+\"(" + KEY + r")\""),  # option kit defaults: label = label or "KEY"
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
sys.exit(1 if missing or unused or dupes else 0)
