#!/usr/bin/env python3
"""Game-ID check: every hard-coded game reference in Phoenix exists in the pinned 12.1.5 snapshot.

Covers interface file paths (Interface\\Icons\\..., Interface\\Buttons\\...), atlas names (SetAtlas,
CreateAtlasMarkup, *ATLAS tables, GetClassAtlas results), spell IDs (lines tagged `-- spellIDs: Name, Name`, or `-- spellIDs(retail|forever):` for one game;
the names must match the client's SpellName in order), SOUNDKIT constants, Enum fallbacks and numeric
fileDataIDs. The snapshot (tools/ids/snapshot.json) is generated from wago.tools DB2 + Blizzard UI source by
tools/ids/refresh.py; this check runs offline. Exit 1 on any finding.

Rule: prefer runtime lookups (C_Spell.GetSpellTexture, C_ChallengeMode.GetMapUIInfo, C_Texture.GetAtlasInfo)
over literals; any literal that remains must be listed here."""
import json
import os
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "ids"))
import common  # noqa: E402

# PUI_FLAVOR=forever checks the same references against the WoW Forever snapshot (snapshot_forever.json).
SNAP_FLAVOR = os.environ.get("PUI_FLAVOR", "retail")
SNAP = json.loads(common.snapshot_path(SNAP_FLAVOR).read_text(encoding="utf-8"))
problems = []
refs = common.scan(SNAP_FLAVOR)


def check(kind, key, where, snap_key=None):
    entry = SNAP[kind].get(snap_key if snap_key is not None else key)
    if entry is None:
        problems.append(f"{where[0]}: {kind[:-1]} {key!r} is not in the snapshot (run tools/ids/refresh.py)")
    elif entry.get("missing"):
        problems.append(f"{where[0]}: {kind[:-1]} {key!r} does not exist in build {SNAP['build']}")
    return entry


for path, where in sorted(refs["files"].items()):
    check("files", path, where)
for atlas, where in sorted(refs["atlases"].items()):
    if atlas == "@classicon":
        for name in SNAP["atlases"]:
            if name.startswith("classicon-") and SNAP["atlases"][name].get("missing"):
                problems.append(f"{where[0]}: GetClassAtlas target {name!r} missing in {SNAP['build']}")
        continue
    check("atlases", atlas, where)
for sid, where in sorted(refs["spells"].items()):
    check("spells", sid, where, str(sid))
for f in common.lua_files():
    for i, line in enumerate(f.read_text(encoding="utf-8").split("\n"), 1):
        m = re.search(r"--\s*spellIDs(?:\((retail|forever)\))?:\s*(.+)$", line)
        if not m or m.group(1) not in (None, SNAP_FLAVOR):
            continue
        ids = [int(a or b) for a, b in re.findall(r"\[(\d+)\]|\b(\d{2,})\b", line.split("--", 1)[0])]
        # a name the other game spells differently reads "Retail Name (Forever: Forever Name)"
        names = []
        for n in m.group(2).split(","):
            alt = re.match(r"^(.*?)\s*\(Forever:\s*(.*?)\)$", n.strip())
            names.append((alt.group(2) if SNAP_FLAVOR == "forever" else alt.group(1)) if alt else n.strip())
        actual = [SNAP["spells"].get(str(s), {}).get("name") for s in ids]
        if names != actual:
            problems.append(f"{f.relative_to(common.ROOT)}:{i}: spellIDs comment {names} != client names {actual}")
for k, where in sorted(refs["soundkits"].items()):
    check("soundkits", k, where)
for e, where in sorted(refs["enums"].items()):
    name, val = e.split("=")
    entry = check("enums", name, where)
    if entry and not entry.get("missing") and entry["value"] != int(val):
        problems.append(f"{where[0]}: fallback {name}={val}, client has {entry['value']}")
for fid, where in sorted(refs["fileids"].items()):
    check("fileids", fid, where, str(fid))

# Stale snapshot rows (reference removed from code) keep the snapshot honest.
used = {"files": set(refs["files"]), "spells": {str(s) for s in refs["spells"]}, "soundkits": set(refs["soundkits"]),
        "enums": {e.split("=")[0] for e in refs["enums"]}, "fileids": {str(i) for i in refs["fileids"]},
        "atlases": set(refs["atlases"]) | ({n for n in SNAP["atlases"] if n.startswith("classicon-")}
                                            if "@classicon" in refs["atlases"] else set())}
for kind, keys in used.items():
    for stale in sorted(set(SNAP[kind]) - keys):
        problems.append(f"snapshot: unused {kind[:-1]} {stale!r} (run tools/ids/refresh.py)")

for p in problems:
    print(p)
total = sum(len(v) for v in refs.values())
print(f"check_ids: {total} game references vs build {SNAP['build']}, {len(problems)} problems")
sys.exit(1 if problems else 0)
