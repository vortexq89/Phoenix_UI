#!/usr/bin/env python3
"""Builds the Phoenix_UI_Data addon's quest slices (docs/plan_v2/research/NPC_DATA.md, docs/QUEST_DATA.md).

Sources (facts only, see Phoenix_UI_Data/LICENSE-ATT.txt and docs/QUEST_DATA.md):
  * AllTheThings source DB (github.com/ATTWoWAddon/AllTheThings, MIT): quest -> giver NPC, giver coordinates,
    prerequisites, faction/race/class limits, minimum level, daily/weekly flags, English names from the DB's
    comments. Read by tools/questdata/att_extract.lua (Phoenix's own reader, run with lua5.1).
  * Blizzard client tables via wago.tools CSV (retail only): QuestPOIBlob + QuestPOIPoint (turn-in areas,
    ObjectiveIndex -1) converted to map coordinates with UiMapAssignment.
Nothing is taken from Wowhead, Questie, HandyNotes plugins or private-server databases.

  python3 tools/questdata/build_questdata.py --att DIR [--cache DIR] [--slice midnight ...]
  python3 tools/questdata/build_questdata.py --fetch --cache /tmp/qd     # sparse-clones ATT into the cache

Each slice becomes Phoenix_UI_Data/Quests_<Slice>.lua; Phoenix_UI_Data/Manifest.lua lists them with counts.
"""
import argparse
import csv
import io
import json
import pathlib
import re
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "Phoenix_UI_Data"
EXTRACT = pathlib.Path(__file__).resolve().parent / "att_extract.lua"
ATT_URL = "https://github.com/ATTWoWAddon/AllTheThings.git"
BUILDS = {"retail": "12.1.5.70448", "forever": "1.60.1.70532"}

# slice key -> (flavor, expansion number, label, ATT folders under .contrib/.db)
SLICES = {
    "midnight": ("retail", 12, "Midnight", ["standard/02 - Outdoor Zones/16 Quel'Thalas"]),
    "tww": ("retail", 11, "The War Within", ["standard/02 - Outdoor Zones/15 Khaz Algar"]),
    "forever": ("forever", 1, "Azeroth (WoW Forever)", ["forever/zones"]),
}
FILES = {"midnight": "Midnight", "tww": "WarWithin", "forever": "Forever"}
SKIP_FILES = ("World Quests.lua", "Achievements.lua", "Zone Rewards.lua", "Zone Drops.lua", "Treasures.lua",
              "Battle Pets & Wild Pets.lua", "Exploration.lua", "Flight Paths.lua", "Rares.lua")
SKIP_FLAGS = {"isWorldQuest"}
FLAG_BITS = {"isDaily": 1, "isWeekly": 2, "isBreadcrumb": 4, "repeatable": 8, "isMonthly": 2, "isYearly": 8}
ALLIANCE = {1, 3, 4, 7, 11, 22, 25, 29, 30, 32, 34, 37, 52, 85, 86, 95}
HORDE = {2, 5, 6, 8, 9, 10, 26, 27, 28, 31, 35, 36, 70, 84, 91, 96}
NEVER_OR_REMOVED = {1, 2}  # ATT phases NEVER_IMPLEMENTED, REMOVED_FROM_GAME


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Phoenix_UI-questdata"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read().decode("utf-8")


def table(name, build, cache):
    path = cache / f"{name}.{build}.csv"
    if path.exists():
        text = path.read_text(encoding="utf-8")
    else:
        text = fetch(f"https://wago.tools/db2/{name}/csv?build={build}")
        path.write_text(text, encoding="utf-8")
    if text.startswith("{"):
        return []
    return list(csv.DictReader(io.StringIO(text)))


def vtuple(text):
    return tuple(int(x) for x in re.findall(r"\d+", text))


def removed(timeline, flavor):
    """True when the last timeline event at or before the client's build is a removal."""
    now = vtuple(BUILDS[flavor])
    last = None
    for ev in filter(None, timeline.split(";")):
        kind, _, ver = ev.partition(" ")
        v = vtuple(ver)
        if v[:len(now)] <= now:
            last = kind
    return last in ("removed", "deleted")


NAME_RE = [
    (re.compile(r'"n",\s*(\d+)\s*\}\s*,?\s*--\s*(.+)$'), "npc"),
    (re.compile(r'\bqg"?\]?\s*=\s*(\d+)\s*,?\s*--\s*(.+)$'), "npc"),
    (re.compile(r'^\s*n\((\d+)\s*,.*--\s*(.+)$'), "npc"),
    (re.compile(r'^\s*q\((\d+)\s*,.*--\s*(.+)$'), "quest"),
]
LIST_START = re.compile(r'\b(qgs|sourceQuests)"?\]?\s*=\s*\{\s*$')
LIST_ITEM = re.compile(r'^\s*(\d+)\s*,?\s*--\s*(.+)$')


def clean(name):
    name = re.sub(r"\s*\((?:mobileNPC|[A-Z!]+!?|PQI!|QI!|.*?NPC.*?)\)\s*", " ", name).strip()
    name = re.sub(r"\s+\[.*?\]$", "", name).strip()
    return name if name and len(name) < 80 and "TODO" not in name.upper() else None


def comment_names(files):
    npcs, quests = {}, {}
    for f in files:
        mode = None
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.lstrip().startswith("--"):
                continue
            m = LIST_START.search(line)
            if m:
                mode = "npc" if m.group(1) == "qgs" else "quest"
                continue
            if mode:
                if "}" in line:
                    mode = None
                else:
                    m = LIST_ITEM.match(line)
                    if m and clean(m.group(2)):
                        (npcs if mode == "npc" else quests).setdefault(int(m.group(1)), clean(m.group(2)))
                    continue
            for rx, kind in NAME_RE:
                m = rx.search(line)
                if m and clean(m.group(2)):
                    (npcs if kind == "npc" else quests).setdefault(int(m.group(1)), clean(m.group(2)))
    return npcs, quests


def extract(att, flavor, folders):
    db = att / ".contrib" / ".db"
    files = []
    for folder in folders:
        files += sorted(p for p in (db / folder).rglob("*.lua") if p.name not in SKIP_FILES)
    proc = subprocess.run(["lua5.1", str(EXTRACT), flavor, str(db / "shared")] + [str(p) for p in files],
                          capture_output=True, text=True, check=True)
    for line in proc.stderr.splitlines():
        if "raceIDs.lua:200" not in line:  # the DB's race list builder needs its parser; the lists are read first
            print("  att:", line, file=sys.stderr)
    return proc.stdout.splitlines(), files


def turnins(build, cache):
    """questID -> (uiMapID, x, y) for the centre of the turn-in area (QuestPOIBlob ObjectiveIndex -1)."""
    blobs = {r["ID"]: r for r in table("QuestPOIBlob", build, cache) if r["ObjectiveIndex"] == "-1"}
    if not blobs:
        return {}
    pts = {}
    for r in table("QuestPOIPoint", build, cache):
        if r["QuestPOIBlobID"] in blobs:
            pts.setdefault(r["QuestPOIBlobID"], []).append((float(r["X"]), float(r["Y"])))
    assign = {}
    for r in table("UiMapAssignment", build, cache):
        if r["WMOGroupID"] == "0" and r["WMODoodadPlacementID"] == "0":
            assign.setdefault(r["UiMapID"], []).append(r)
    out = {}
    for bid, b in blobs.items():
        p = pts.get(bid)
        if not p:
            continue
        wx, wy = sum(x for x, _ in p) / len(p), sum(y for _, y in p) / len(p)
        for a in assign.get(b["UiMapID"], []):
            if a["MapID"] != b["MapID"]:
                continue
            x0, y0, x1, y1 = (float(a[k]) for k in ("Region_0", "Region_1", "Region_3", "Region_4"))
            if not (x0 <= wx <= x1 and y0 <= wy <= y1) or x1 == x0 or y1 == y0:
                continue
            u0, v0, u1, v1 = (float(a[k]) for k in ("UiMin_0", "UiMin_1", "UiMax_0", "UiMax_1"))
            mx = u0 + (u1 - u0) * (y1 - wy) / (y1 - y0)
            my = v0 + (v1 - v0) * (x1 - wx) / (x1 - x0)
            q = int(b["QuestID"])
            if q not in out and 0 <= mx <= 1 and 0 <= my <= 1:
                out[q] = (int(b["UiMapID"]), round(mx * 1000), round(my * 1000))
            break
    return out


def ints(text):
    return [int(x) for x in text.split(",") if x.strip().lstrip("-").isdigit()]


def build_slice(key, att, cache, stats):
    flavor, expansion, label, folders = SLICES[key]
    lines, files = extract(att, flavor, folders)
    npc_pos, quests = {}, {}
    for line in lines:
        p = line.split("|")
        if p[0] == "N" and p[2] and p[3]:
            npc_pos.setdefault(int(p[1]), (int(p[2]), float(p[3]), float(p[4])))
        elif p[0] == "Q":
            quests.setdefault(int(p[1]), []).append(p)
    tin = turnins(BUILDS[flavor], cache) if flavor == "retail" else {}
    npc_names, quest_names = comment_names(files)
    by_map, used_npcs, dropped = {}, set(), {"removed": 0, "world": 0, "nocoord": 0}
    for qid, rows in sorted(quests.items()):
        r = rows[0]
        flags = set(filter(None, r[11].split(",")))
        if flags & SKIP_FLAGS:
            dropped["world"] += 1
            continue
        if removed(r[12], flavor) or (r[13].isdigit() and int(r[13]) in NEVER_OR_REMOVED):
            dropped["removed"] += 1
            continue
        npcs = ints(r[5])
        spots = [(int(x[2]), float(x[3]), float(x[4])) for x in rows if x[2] and x[3] and x[4]]
        if not spots:
            spots = [npc_pos[n] for n in npcs if n in npc_pos][:1]
        if not spots:
            dropped["nocoord"] += 1
            continue
        races = set(ints(r[8]))
        side = 0
        if races and races <= ALLIANCE:
            side = 1
        elif races and races <= HORDE:
            side = 2
        race_list = sorted(races) if races and races not in (ALLIANCE, HORDE) and not (
            races >= ALLIANCE - {95} and side == 1) and not (races >= HORDE - {96} and side == 2) else []
        bits = 0
        for f in flags:
            bits |= FLAG_BITS.get(f, 0)
        lvl = int(r[10]) if r[10].isdigit() else 0
        pre = "/".join(str(x) for x in ints(r[6]))
        need = r[7] if r[7].isdigit() else ""
        ti = tin.get(qid)
        seen = set()
        for mp, x, y in spots:
            if (mp, x, y) in seen or not (0 <= x <= 100 and 0 <= y <= 100):
                continue
            seen.add((mp, x, y))
            npc = npcs[0] if npcs else 0
            used_npcs.update(npcs[:1])
            fields = [qid, npc, round(x * 10), round(y * 10), lvl, side, bits,
                      "/".join(str(c) for c in sorted(set(ints(r[9])))), "/".join(str(c) for c in race_list),
                      pre, need, ti[0] if ti else "", ti[1] if ti else "", ti[2] if ti else ""]
            by_map.setdefault(mp, []).append(",".join(str(f) for f in fields))
    stats[key] = {"label": label, "flavor": flavor, "expansion": expansion, "quests": sum(len(v) for v in by_map.values()),
                  "unique": len({int(x.split(",")[0]) for v in by_map.values() for x in v}), "maps": len(by_map),
                  "turnins": sum(1 for v in by_map.values() for x in v if x.split(",")[11]), "dropped": dropped,
                  "npcs": len(used_npcs)}
    lua = [f"-- Phoenix_UI_Data quest slice '{key}' ({label}). Generated by tools/questdata/build_questdata.py; do not edit.",
           "-- Facts from AllTheThings (MIT, see LICENSE-ATT.txt)" + (" and Blizzard QuestPOI tables (turn-ins)." if tin else "."),
           "-- Record: questID,npcID,x,y,minLevel,side(1 A,2 H),flags(1 daily,2 weekly,4 breadcrumb,8 repeatable),",
           "--         classIDs/,raceIDs/,prerequisites/,prerequisitesNeeded,turnInMap,turnInX,turnInY (x/y in 0.1 %)",
           "local _, D = ...",
           f'if not D:Slice("{key}", "{flavor}", {expansion}) then return end',
           f'D.quests["{key}"] = {{']
    for mp in sorted(by_map):
        lua.append(f'    [{mp}] = "' + ";".join(by_map[mp]) + '",')
    lua.append("}")
    names = {n: npc_names[n] for n in sorted(used_npcs) if n in npc_names}
    lua.append(f'D:Names("{key}", {{')
    for n, name in names.items():
        lua.append(f"    [{n}] = {json.dumps(name, ensure_ascii=False)},")
    lua.append("}, {")
    for q in sorted({int(x.split(",")[0]) for v in by_map.values() for x in v}):
        if q in quest_names:
            lua.append(f"    [{q}] = {json.dumps(quest_names[q], ensure_ascii=False)},")
    lua.append("})")
    (OUT / f"Quests_{FILES[key]}.lua").write_text("\n".join(lua) + "\n", encoding="utf-8")


def att_commit(att):
    try:
        return subprocess.run(["git", "-C", str(att), "log", "-1", "--format=%H %cs"], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--att", help="AllTheThings checkout (needs .contrib/.db)")
    ap.add_argument("--fetch", action="store_true", help="sparse-clone AllTheThings into <cache>/att")
    ap.add_argument("--cache", default="/tmp/phoenix_questdata")
    ap.add_argument("--slice", nargs="*", default=list(SLICES))
    a = ap.parse_args()
    cache = pathlib.Path(a.cache)
    cache.mkdir(parents=True, exist_ok=True)
    att = pathlib.Path(a.att) if a.att else cache / "att"
    if a.fetch and not att.exists():
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", ATT_URL, str(att)], check=True)
        dirs = {".contrib/.db/shared", ".contrib/.db/forever/.config/constants"}
        dirs |= {".contrib/.db/" + f for s in SLICES.values() for f in s[3]}
        subprocess.run(["git", "-C", str(att), "sparse-checkout", "set"] + sorted(dirs), check=True)
    stats = {}
    for key in a.slice:
        build_slice(key, att, cache, stats)
    commit = att_commit(att)
    man = ["-- Phoenix_UI_Data manifest. Generated by tools/questdata/build_questdata.py; do not edit.",
           "local _, D = ...",
           f'D.source = {{ att = "{commit}", retail = "{BUILDS["retail"]}", forever = "{BUILDS["forever"]}" }}',
           "D.manifest = {"]
    for key, s in stats.items():
        man.append(f'    {{ key = "{key}", flavor = "{s["flavor"]}", expansion = {s["expansion"]}, quests = {s["unique"]}, '
                   f'maps = {s["maps"]}, turnins = {s["turnins"]} }},')
    man.append("}")
    (OUT / "Manifest.lua").write_text("\n".join(man) + "\n", encoding="utf-8")
    print(json.dumps({"att": commit, "slices": stats}, indent=1))


if __name__ == "__main__":
    main()
