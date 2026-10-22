#!/usr/bin/env python3
"""Rebuild tools/ids/snapshot.json from live game data for every game reference Phoenix uses.

    python3 tools/ids/refresh.py [--build 12.1.5.70448] [--ui-source PATH] [--cache DIR]
    python3 tools/ids/refresh.py --flavor forever [--build 1.60.1.70532] ...   # -> snapshot_forever.json

Sources (all public):
  * wago.tools DB2 CSV: ManifestInterfaceData (interface file paths -> fileDataID), UiTextureAtlasElement +
    UiTextureAtlasMember (atlas names and sizes), SpellName (spell IDs -> names); build from /api/builds/wow/latest.
  * Blizzard UI source for the same build (Gethe/wow-ui-source, `live`) for SOUNDKIT constants, and Ketho's
    BlizzardInterfaceResources (`live`) Resources/LuaEnum.lua for Enum values. --ui-source / --enum-source take
    local checkouts; otherwise raw GitHub is used.
Unknown references are written with "missing": true so check_ids.py fails until the code is fixed."""
import argparse
import csv
import io
import json
import pathlib
import re
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import common  # noqa: E402

UI_RAW = "https://raw.githubusercontent.com/Gethe/wow-ui-source/live/"
BIR_RAW = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/live/"
CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
           "DRUID", "DEMONHUNTER", "EVOKER"]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Phoenix_UI-ids-refresh"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode("utf-8")


def table(name, build, cache):
    path = cache / f"{name}.csv" if cache else None
    if path and path.exists():
        text = path.read_text(encoding="utf-8")
    else:
        text = fetch(f"https://wago.tools/db2/{name}/csv?build={build}")
        if path:
            path.write_text(text, encoding="utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def source(rel, local_root, raw_base):
    if local_root:
        return (pathlib.Path(local_root) / rel).read_text(encoding="utf-8")
    return fetch(raw_base + rel)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build")
    ap.add_argument("--ui-source")
    ap.add_argument("--enum-source", help="local BlizzardInterfaceResources checkout")
    ap.add_argument("--cache")
    ap.add_argument("--flavor", choices=common.SNAPSHOTS, default="retail",
                    help="forever: WoW Forever (wago product wowf, the `forever` source branches)")
    a = ap.parse_args()
    global UI_RAW, BIR_RAW
    product, branch = ("wow", "live") if a.flavor == "retail" else ("wowf", "forever")
    UI_RAW, BIR_RAW = UI_RAW.replace("/live/", f"/{branch}/"), BIR_RAW.replace("/live/", f"/{branch}/")
    build = a.build or json.loads(fetch(f"https://wago.tools/api/builds/{product}/latest"))["version"]
    cache = pathlib.Path(a.cache) if a.cache else None
    if cache:
        cache.mkdir(parents=True, exist_ok=True)
    refs = common.scan()

    manifest = {}
    for r in table("ManifestInterfaceData", build, cache):
        manifest[common.norm(r["FilePath"] + r["FileName"]).rsplit(".", 1)[0]] = int(r["ID"])
    elements = {r["Name"].lower(): r["Name"] for r in table("UiTextureAtlasElement", build, cache)}
    members = {r["CommittedName"].lower(): r for r in table("UiTextureAtlasMember", build, cache)}
    spells = {int(r["ID"]): r["Name_lang"] for r in table("SpellName", build, cache)}

    soundkit_src = source("Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua", a.ui_source, UI_RAW)
    soundkits = {k: int(v) for k, v in re.findall(r"\b([A-Z0-9_]+)\s*=\s*(\d+)", soundkit_src)}
    enum_src = source("Resources/LuaEnum.lua", a.enum_source, BIR_RAW) if refs["enums"] else ""

    snap = {"build": build, "files": {}, "atlases": {}, "spells": {}, "soundkits": {}, "enums": {}, "fileids": {}}
    for p in sorted(refs["files"]):
        fid = manifest.get(common.norm(p))
        snap["files"][p] = {"fileDataID": fid} if fid else {"missing": True}
    want_atlas = set(refs["atlases"])
    if "@classicon" in want_atlas:
        want_atlas.discard("@classicon")
        want_atlas |= {"classicon-" + c.lower() for c in CLASSES}
    for name in sorted(want_atlas):
        m = members.get(name.lower())
        if m:
            snap["atlases"][name] = {"width": int(m["Width"]), "height": int(m["Height"])}
        elif name.lower() in elements:
            snap["atlases"][name] = {}
        else:
            snap["atlases"][name] = {"missing": True}
    for sid in sorted(refs["spells"]):
        snap["spells"][str(sid)] = {"name": spells[sid]} if sid in spells else {"missing": True}
    for k in sorted(refs["soundkits"]):
        snap["soundkits"][k] = {"id": soundkits[k]} if k in soundkits else {"missing": True}
    for e in sorted(refs["enums"]):
        name = e.split("=")[0]
        enum, key = name.split(".")
        m = re.search(r"\b" + enum + r"\s*=\s*\{(.*?)\}", enum_src, re.S)
        got = m and re.search(r"\b" + key + r"\s*=\s*(\d+)", m.group(1))
        snap["enums"][name] = {"value": int(got.group(1))} if got else {"missing": True}
    for fid in sorted(refs["fileids"]):
        snap["fileids"][str(fid)] = {"path": next((k for k, v in manifest.items() if v == fid), None)} \
            if fid in manifest.values() else {"missing": True}

    out = common.snapshot_path(a.flavor)
    out.write_text(json.dumps(snap, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    missing = sum(1 for k in snap if isinstance(snap[k], dict) for v in snap[k].values() if isinstance(v, dict) and v.get("missing"))
    print(f"refresh: build {build}, {sum(len(snap[k]) for k in snap if k != 'build')} references, {missing} missing -> {out}")


if __name__ == "__main__":
    main()
