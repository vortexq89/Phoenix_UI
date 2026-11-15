"""Shared scanner for tools/check_ids.py and tools/ids/refresh.py.

Finds every hard-coded game reference in Phoenix's own Lua (Core/, UI/, Modules/, Phoenix_UI_Options/):
  * file paths   "Interface\\...\\Name" literals, `PREFIX .. "Name"` where PREFIX is a local string that starts
                 with Interface\\, and the values of tables listed in TABLE_PREFIX (e.g. Icons.lua GAME_ART);
                 Phoenix's own Interface\\AddOns\\ paths are checked by check_api.py instead;
  * atlases      SetAtlas("x"), CreateAtlasMarkup("x"), and string values of tables whose name ends in ATLAS;
  * spell IDs    numbers on lines tagged with a `-- spellIDs:` comment (the comment names the spells);
  * sound kits   SOUNDKIT.NAME;
  * enum values  `kind = "Name", fallback = N` rows (Core/Weekly.lua) vs Enum.WeeklyRewardChestThresholdType;
  * file IDs     SetTexture(<number>) / SetNormalTexture(<number>) etc., `iconFileID = <number>` fields, and
                 numbers on lines tagged with a `-- fileID:` comment (the comment names the file)
"""
import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
# One snapshot per game: retail (Midnight 12.1.5) and WoW Forever 1.60.1 (wago product wowf).
SNAPSHOTS = {"retail": "snapshot.json", "forever": "snapshot_forever.json"}


def snapshot_path(flavor=None):
    flavor = flavor or os.environ.get("PUI_FLAVOR", "retail")
    return pathlib.Path(__file__).resolve().parent / SNAPSHOTS[flavor]

DIRS = ("Core", "UI", "Modules", "Phoenix_UI_Options") + tuple(sorted(d.name for d in ROOT.glob("Phoenix_UI_*") if d.is_dir() and d.name not in ("Phoenix_UI_Options", "Phoenix_UI_Data")))
TABLE_PREFIX = {"GAME_ART": "Interface\\Icons\\"}
ENUM_ROWS = {"Core/Weekly.lua": "WeeklyRewardChestThresholdType"}

LITERAL_PATH = re.compile(r'"(Interface\\\\(?!AddOns\\\\)[A-Za-z0-9_\\-]+(?:\\\\[A-Za-z0-9_\-]+)+)"')
PREFIX_DEF = re.compile(r'^\s*local\s+([\w\s,]+?)\s*=\s*((?:"[^"]*"\s*,?\s*)+)$')
ATLAS_CALL = re.compile(r'(?:SetAtlas|CreateAtlasMarkup)\(\s*"([^"]+)"')
ATLAS_TABLE = re.compile(r'local\s+\w*ATLAS\w*\s*=\s*\{([^}]*)\}')
# `-- spellIDs(retail):` / `-- spellIDs(forever):` lines hold IDs one game only uses (checked against that snapshot only).
SPELL_LINE = re.compile(r'--\s*spellIDs(?:\((retail|forever)\))?:')
FILEID_LINE = re.compile(r'--\s*fileID:')
SOUNDKIT = re.compile(r'SOUNDKIT\.([A-Z0-9_]+)')
ENUM_ROW = re.compile(r'kind\s*=\s*"(\w+)"\s*,\s*fallback\s*=\s*(\d+)')
FILEID = re.compile(r'(?::Set(?:Normal|Pushed|Highlight|Disabled|Checked|StatusBar)?Texture\(|\biconFileID\s*=)\s*(\d{4,})\b')


def lua_files():
    for d in DIRS:
        yield from sorted((ROOT / d).rglob("*.lua"))


def norm(path):
    return path.replace("/", "\\").replace("\\\\", "\\").lower()


def scan(flavor=None):
    flavor = flavor or os.environ.get("PUI_FLAVOR", "retail")
    """-> dict kind -> {value: [ 'file:line', ... ]}"""
    refs = {k: {} for k in ("files", "atlases", "spells", "soundkits", "enums", "fileids")}

    def add(kind, value, where):
        refs[kind].setdefault(value, []).append(where)

    for f in lua_files():
        rel = f.relative_to(ROOT).as_posix()
        text = f.read_text(encoding="utf-8")
        lines = text.split("\n")
        prefixes = {}
        for i, line in enumerate(lines, 1):
            m = PREFIX_DEF.match(line)
            if m:
                names = [n.strip() for n in m.group(1).split(",")]
                vals = re.findall(r'"([^"]*)"', m.group(2))
                for n, v in zip(names, vals):
                    if v.replace("\\\\", "\\").lower().startswith("interface\\") and not v.lower().startswith("interface\\\\addons"):
                        prefixes[n] = v.replace("\\\\", "\\")
        for i, line in enumerate(lines, 1):
            where = f"{rel}:{i}"
            code = line.split("--", 1)[0] if not SPELL_LINE.search(line) else line
            for p in LITERAL_PATH.findall(code):
                add("files", p.replace("\\\\", "\\"), where)
            for name, pre in prefixes.items():
                for leaf in re.findall(r'\b' + re.escape(name) + r'\s*\.\.\s*"([^"]+)"', code):
                    add("files", pre + leaf.replace("\\\\", "\\"), where)
            for a in ATLAS_CALL.findall(code):
                add("atlases", a, where)
            for s in SOUNDKIT.findall(code):
                add("soundkits", s, where)
            for n in FILEID.findall(code):
                add("fileids", int(n), where)
            if FILEID_LINE.search(line):
                for n in re.findall(r'\b(\d{4,})\b', line.split("--", 1)[0]):
                    add("fileids", int(n), where)
            sl = SPELL_LINE.search(line)
            if sl and sl.group(1) in (None, flavor):
                body = line.split("--", 1)[0]
                for n in re.findall(r'\[(\d+)\]|\b(\d{2,})\b', body):
                    v = n[0] or n[1]
                    add("spells", int(v), where)
            if rel in ENUM_ROWS:
                for name, val in ENUM_ROW.findall(code):
                    add("enums", f"{ENUM_ROWS[rel]}.{name}={val}", where)
        for m in ATLAS_TABLE.finditer(text):
            line_no = text[:m.start()].count("\n") + 1
            for a in re.findall(r'"([^"]+)"', m.group(1)):
                add("atlases", a, f"{rel}:{line_no}")
        for tname, pre in TABLE_PREFIX.items():
            m = re.search(r'local\s+' + tname + r'\s*=\s*\{(.*?)\n\}', text, re.S)
            if m:
                line_no = text[:m.start()].count("\n") + 1
                for leaf in re.findall(r'=\s*"([^"]+)"', m.group(1)):
                    add("files", pre + leaf, f"{rel}:{line_no}")
        if "GetClassAtlas(" in text:
            add("atlases", "@classicon", f"{rel}")
    return refs
