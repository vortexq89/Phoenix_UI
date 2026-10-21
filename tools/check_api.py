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
    exactly once;
  * icons: every literal icon name passed to the icon API exists in Core/IconData.lua, every atlas glyph
    is referenced somewhere, and every atlas/brand texture named in Lua exists with exact case;
  * media: every file under Media/ (tga/ttf) is referenced (no dead media), every Media.textures key
    is used, every font/texture/licence named by Core/FontData.lua, Core/TextureData.lua and Core/Media.lua
    exists with exact case, and the TOC IconTexture exists with exact case.
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

# ---------------------------------------------------------------- icons & media
icon_data = (ROOT / "Core" / "IconData.lua").read_text(encoding="utf-8")
ICON_NAMES = set(re.findall(r'\["([a-z0-9-]+)"\]\s*=\s*\d+', icon_data))
ICON_TIERS = re.findall(r'file\s*=\s*"([^"]+)"', icon_data)
code = {p: strip_comments(p.read_text(encoding="utf-8")) for p in sources if p.name != "IconData.lua"}
literals = set()
for text in code.values():
    literals.update(re.findall(r'"([^"\\\n]*)"', text))
# Literal icon names in icon-taking positions: icon fields, W.Icon / Icons:Create/Apply/Markup,
# (Icon)Button icon args, Badge/Popup/Card icon args and the category/status icon maps.
ICON_USE = [
    re.compile(r'\bicon\s*=\s*"([^"]+)"'),
    re.compile(r'W\.Icon\([^,()]+,\s*"([^"]+)"'),
    re.compile(r'Icons:(?:Create|Apply)\([^,()]+,\s*"([^"]+)"'),
    re.compile(r'Icons:Markup\(\s*"([^"]+)"'),
    re.compile(r'W:IconButton\([^,()]+,\s*"([^"]+)"'),
    re.compile(r'W:Button\([^,()]+,[^,()]+(?:\([^()]*\))?,\s*"[^"]*",\s*"([^"]+)"'),
    re.compile(r'W:(?:Popup|Badge)\([^()]*(?:\([^()]*\)[^()]*)*,\s*"([a-z0-9-]+)"\)'),
    re.compile(r'\["?[\w.]+"?\]\s*=\s*"((?:cat|state)-?[a-z-]*|success|warning|error|about)"'),
    re.compile(r'(?:,|\{)\s*\w+\s*=\s*"(cat-[a-z]+)"'),
    re.compile(r'\bor\s+"([a-z0-9-]+)"\s*,\s*\d+\)'),
]
for path, text in code.items():
    for rx in ICON_USE:
        for m in rx.finditer(text):
            name = m.group(1)
            if name not in ICON_NAMES and not name.startswith("state."):
                report(path, text, m.start(), f"unknown icon '{name}' (not in Core/IconData.lua)")
module_keys = set()
for text in code.values():
    module_keys.update(k.lower() for k in re.findall(r'NewModule\(\s*"(\w+)"', text))
for name in sorted(ICON_NAMES - literals - module_keys):
    problems.append(f"Core/IconData.lua: icon '{name}' is never used (dead glyph)")

def media_exists(rel):
    return exact(ROOT / rel)

for tier in ICON_TIERS:
    if not media_exists(f"Media/Icons/{tier}.tga"):
        problems.append(f"Core/IconData.lua: missing or wrong-case Media/Icons/{tier}.tga")
if not media_exists("Media/Icons/LICENSE"):
    problems.append("Media/Icons/LICENSE: icon licence is missing")
icons_lua = code[ROOT / "Core" / "Icons.lua"]
for brand in re.findall(r'file\s*=\s*"([^"]+)"', icons_lua):
    if not media_exists(f"Media/Textures/{brand}.tga"):
        problems.append(f"Core/Icons.lua: missing or wrong-case Media/Textures/{brand}.tga")
for m in re.finditer(r'TEXTURES\s*\.\.\s*"([^"]+)"', "\n".join(code.values())):
    if not media_exists(f"Media/Textures/{m.group(1)}.tga"):
        problems.append(f"missing or wrong-case Media/Textures/{m.group(1)}.tga")

for data, folder, ext in (("FontData.lua", "Fonts", ""), ("TextureData.lua", "Textures", ".tga")):
    for name in re.findall(r'file\s*=\s*"([^"]+)"', code[ROOT / "Core" / data]):
        if not media_exists(f"Media/{folder}/{name}{ext}"):
            problems.append(f"Core/{data}: missing or wrong-case Media/{folder}/{name}{ext}")
for name in re.findall(r'core\("\w+", "[^"]+", "([^"]+)"', code[ROOT / "Core" / "Media.lua"]):
    if not media_exists(f"Media/Fonts/{name}"):
        problems.append(f"Core/Media.lua: missing or wrong-case Media/Fonts/{name}")
for f in sorted((ROOT / "Media" / "Fonts").glob("*.ttf")):
    lic = sorted((ROOT / "Media" / "Fonts" / "Licenses").glob("*"))
    stem = f.stem.split("-")[0].replace("_", "")
    if not any(stem.lower().startswith(l.stem.split("-", 1)[-1].lower()) for l in lic):
        problems.append(f"{f.relative_to(ROOT)}: no licence file in Media/Fonts/Licenses")

toc_text = toc.read_text(encoding="utf-8")
icon_tex = re.search(r"^## IconTexture:\s*Interface\\AddOns\\Phoenix_UI\\(\S+)", toc_text, re.M)
toc_icon = icon_tex and icon_tex.group(1).replace("\\", "/")
if not toc_icon or not any(media_exists(toc_icon + ext) for ext in ("", ".tga", ".blp", ".png")):
    problems.append("Phoenix_UI.toc: IconTexture is missing or has the wrong case")
all_text = "\n".join(code.values()) + "\n" + toc_text
for f in sorted((ROOT / "Media").rglob("*")):
    if f.suffix.lower() not in (".tga", ".ttf", ".blp", ".png"):
        continue
    stem = f.stem
    used = stem in literals or f.name in literals or stem in ICON_TIERS or (toc_icon and toc_icon.endswith(stem))
    if not used:
        problems.append(f"{f.relative_to(ROOT)}: never referenced (dead media)")
media_lua = code[ROOT / "Core" / "Media.lua"]
tex_block = re.search(r"M\.textures\s*=\s*\{(.*?)\n\}", media_lua, re.S)
others = "\n".join(t for p, t in code.items() if p.name != "Media.lua")
for key in re.findall(r"^\s*(\w+)\s*=", tex_block.group(1), re.M) if tex_block else []:
    if not re.search(r"textures\." + key + r"\b", others):
        problems.append(f"Core/Media.lua: Media.textures.{key} is never used")

for line in problems:
    print(line)
print(f"check_api: {len(sources)} files, {len(loaded)} loaded, {len(problems)} problems")
sys.exit(1 if problems else 0)
