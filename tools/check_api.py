#!/usr/bin/env python3
"""Static API check against the 12.1.5 reference (.luacheck/reference_12.1.5.json).

Checks, for Core/, UI/, Modules/ and Locales/:
  * every `:Method(` call names a method that exists in the client (C API docs + FrameXML) or is
    defined by Phoenix_UI itself;
  * events passed to Events:On/OnUnit and RegisterEvent/RegisterUnitEvent exist;
  * CVars passed to C_CVar.GetCVar*/SetCVar and Combat.CVarAccessors exist;
  * templates in CreateFrame(..., "Template") and atlases in SetAtlas("...") exist;
  * forbidden 12.x patterns (combat log, string execution, keyboard propagation) are absent;
  * every file listed by the TOC/XML chain exists with exact case, and every addon .lua file is loaded
    exactly once.
Exit code 1 on any finding. Run from anywhere: python3 tools/check_api.py"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REF = json.loads((ROOT / ".luacheck" / "reference_12.1.5.json").read_text(encoding="utf-8"))
METHODS, EVENTS = set(REF["methods"]), set(REF["events"])
CVARS = {c.lower() for c in REF["cvars"]}
TEMPLATES, ATLASES = set(REF["templates"]), set(REF["atlases"])
# Lua string methods ("x":format() etc.).
LUA_METHODS = {"byte", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper"}
# Client methods the generated reference misses: GameTooltip intrinsics and `--[[static]] function`
# constructors in Blizzard_ObjectAPI (verified in wow-ui-source 12.1.5).
CLIENT_EXTRA = {"AddDoubleLine", "AddLine", "NumLines", "SetOwner", "CreateFromEquipmentSlot", "CreateFromBagAndSlot"}
# Public API of optional third-party addons we integrate with (Details! "API UI.txt"); always pcall'd.
THIRD_PARTY = {"GetInstance", "SetBarSettings", "SetBarTextSettings", "InstanceColor", "AttributeMenu"}
EXTRA_METHODS = LUA_METHODS | CLIENT_EXTRA | THIRD_PARTY
# Phoenix-internal messages travel through Events:Fire/Listen, never through the client.
INTERNAL_EVENT = re.compile(r"^PUI_")
FORBIDDEN = [
    (re.compile(r"(?:On|OnUnit|RegisterEvent|RegisterUnitEvent)\(\s*\"COMBAT_LOG_EVENT"),
     "combat-log events are unavailable to addons in 12.x"),
    (re.compile(r"CombatLogGetCurrentEventInfo"), "combat log API is unavailable in 12.x"),
    (re.compile(r"\b(loadstring|RunScript|setfenv|getfenv)\s*\("), "no dynamic code execution"),
    (re.compile(r"SetPropagateKeyboardInput"), "restricted in combat; causes ADDON_ACTION_BLOCKED"),
    (re.compile(r"\b_G\s*\[[^\]]+\]\s*=(?!=)"), "no global writes"),
]

CODE_DIRS = ("Core", "UI", "Modules", "Locales")
sources = sorted(p for d in CODE_DIRS for p in (ROOT / d).rglob("*.lua"))
problems = []


def strip_comments(text):
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def strip_strings(text):
    return re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', text)


def report(path, text, pos, msg):
    line = text.count("\n", 0, pos) + 1
    problems.append(f"{path.relative_to(ROOT)}:{line}: {msg}")


# Methods Phoenix defines itself: function X:Name / X.Name = function / Name = function in tables.
own = set()
for path in sources + sorted((ROOT / "Libs").rglob("*.lua")):
    t = path.read_text(encoding="utf-8")
    own.update(re.findall(r"function\s+[\w.]+[:.](\w+)\s*\(", t))
    own.update(re.findall(r"\b(\w+)\s*=\s*function\b", t))
    own.update(re.findall(r"[\w\]]\.(\w+)\s*=", t))

for path in sources:
    raw = path.read_text(encoding="utf-8")
    code = strip_comments(raw)
    bare = strip_strings(code)
    for m in re.finditer(r":(\w+)\s*\(", bare):
        name = m.group(1)
        if name not in METHODS and name not in own and name not in EXTRA_METHODS:
            report(path, bare, m.start(), f"unknown method :{name}()")
    for m in re.finditer(r"(?:Events:On(?:Unit)?|Register(?:Unit)?Event|EventRegistry:RegisterFrameEventAndCallback)\(\s*\"(\w+)\"", code):
        ev = m.group(1)
        if ev not in EVENTS and not INTERNAL_EVENT.match(ev):
            report(path, code, m.start(), f"unknown event {ev}")
    for m in re.finditer(r"(?:GetCVar(?:Bool|Default)?|SetCVar|CVarAccessors)\(\s*\"(\w+)\"", code):
        if m.group(1).lower() not in CVARS:
            report(path, code, m.start(), f"unknown CVar {m.group(1)}")
    for m in re.finditer(r"CreateFrame\(\s*\"\w+\"\s*,[^,()]*,[^,()]*,\s*\"([\w, ]+)\"", code):
        for tpl in (t.strip() for t in m.group(1).split(",")):
            if tpl and tpl not in TEMPLATES:
                report(path, code, m.start(), f"unknown template {tpl}")
    for m in re.finditer(r"SetAtlas\(\s*\"([^\"]+)\"", code):
        if m.group(1) not in ATLASES:
            report(path, code, m.start(), f"unknown atlas {m.group(1)}")
    for pat, why in FORBIDDEN:
        for m in pat.finditer(code):
            report(path, code, m.start(), f"forbidden: {m.group(0).strip()} ({why})")

# ---------------------------------------------------------------- load chain
loaded = []


def exact(path):
    """True if path exists with exactly this case (Windows/macOS clients are case-insensitive, CI is not)."""
    cur = ROOT
    for part in path.relative_to(ROOT).parts:
        if part not in {c.name for c in cur.iterdir()} if cur.is_dir() else set():
            return False
        cur = cur / part
    return True


def walk_xml(xml):
    text = re.sub(r"<!--.*?-->", "", xml.read_text(encoding="utf-8"), flags=re.S)
    for m in re.finditer(r"<(Script|Include)\s+file=[\"']([^\"']+)[\"']", text):
        target = (xml.parent / m.group(2).replace("\\", "/"))
        if not exact(target):
            problems.append(f"{xml.relative_to(ROOT)}: missing or wrong-case file {m.group(2)}")
            continue
        if m.group(1) == "Include" or target.suffix == ".xml":
            walk_xml(target)
        else:
            loaded.append(target)


toc = ROOT / "Phoenix_UI.toc"
for line in toc.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    target = ROOT / line.replace("\\", "/")
    if not exact(target):
        problems.append(f"Phoenix_UI.toc: missing or wrong-case file {line}")
    elif target.suffix == ".xml":
        walk_xml(target)
    else:
        loaded.append(target)

counts = {}
for p in loaded:
    counts[p] = counts.get(p, 0) + 1
for p, n in counts.items():
    if n > 1:
        problems.append(f"{p.relative_to(ROOT)}: loaded {n} times")
for p in sources:
    if p not in counts:
        problems.append(f"{p.relative_to(ROOT)}: never loaded (dead file)")

for line in problems:
    print(line)
print(f"check_api: {len(sources)} files, {len(loaded)} loaded, {len(problems)} problems")
sys.exit(1 if problems else 0)
