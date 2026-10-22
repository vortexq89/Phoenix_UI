#!/usr/bin/env python3
"""Merges positions recorded by Phoenix UI's local NPC collector into Phoenix_UI_Data/NPCs_Collected.lua.

The collector (Modules/Quests/Collector.lua, opt-in, off by default) keeps NPC ID + map + position, and vignette
ID + map + position, in PhoenixUIDB (WTF/Account/<account>/SavedVariables/Phoenix_UI.lua). It never uploads
anything; this script is how a maintainer folds their *own* recordings into the shipped data.

  python3 tools/questdata/merge_collected.py --flavor retail  path/to/Phoenix_UI.lua [more.lua ...]
  python3 tools/questdata/merge_collected.py --flavor forever path/to/Phoenix_UI.lua --dry-run

Only the collector's tables are read (no names, realms or GUIDs exist in them). NPCs the AllTheThings slices
already place on that map are skipped, so the file only adds what the source data lacks. Positions are
averaged with what the file already holds for the same NPC and map, weighted by sightings.
"""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "Phoenix_UI_Data" / "NPCs_Collected.lua"
SLICE_FILES = {"retail": ["NPCs_Midnight.lua", "NPCs_WarWithin.lua"], "forever": ["NPCs_Forever.lua"]}

# Reads one SavedVariables file in a sandbox and prints the collector's records, one per line.
DUMP = r"""
local f = assert(loadfile(arg[1]))
local env = {}
setfenv(f, env)
f()
local db = env.PhoenixUIDB
local q = type(db) == "table" and type(db.global) == "table" and type(db.global.modules) == "table"
    and db.global.modules.Quests
if type(q) ~= "table" then return end
for npc, maps in pairs(type(q.collected) == "table" and q.collected or {}) do
    if type(npc) == "number" and type(maps) == "table" then
        for map, r in pairs(maps) do
            if type(map) == "number" and type(r) == "table" and type(r.x) == "number" and type(r.y) == "number" then
                print(("N|%d|%d|%.4f|%.4f|%d|%d"):format(npc, map, r.x, r.y, tonumber(r.k) or 0, tonumber(r.n) or 1))
            end
        end
    end
end
for id, v in pairs(type(q.vignettes) == "table" and q.vignettes or {}) do
    if type(id) == "number" and type(v) == "table" and type(v.map) == "number" and type(v.x) == "number" then
        print(("V|%d|%d|%.4f|%.4f"):format(id, v.map, v.x, v.y))
    end
end
"""

BLOCK = re.compile(r'D:Collected\("(\w+)", \{\n(.*?)\}, \{\n(.*?)\}\)', re.S)
ROW = re.compile(r'\s*\[(\d+)\] = "([^"]*)",')


def read_existing():
    out = {"retail": ({}, {}), "forever": ({}, {})}
    if not OUT.exists():
        return out
    for flavor, npcs, vigs in BLOCK.findall(OUT.read_text(encoding="utf-8")):
        n, v = out.setdefault(flavor, ({}, {}))
        for line in npcs.splitlines():
            m = ROW.match(line)
            if m:
                for rec in filter(None, m.group(2).split(";")):
                    npc, x, y, k, *cnt = rec.split(",")
                    n[(int(npc), int(m.group(1)))] = [int(x) / 1000, int(y) / 1000, int(k), int(cnt[0]) if cnt else 1]
        for line in vigs.splitlines():
            m = ROW.match(line)
            if m:
                mp, x, y = m.group(2).split(",")
                v[int(m.group(1))] = (int(mp), int(x) / 1000, int(y) / 1000)
    return out


def known(flavor):
    """(npcID, mapID) pairs the source-data slices already place."""
    pairs = set()
    for name in SLICE_FILES[flavor]:
        path = ROOT / "Phoenix_UI_Data" / name
        if not path.exists():
            continue
        for m in ROW.finditer(path.read_text(encoding="utf-8")):
            for rec in filter(None, m.group(2).split(";")):
                if rec.count(",") == 3:
                    pairs.add((int(rec.split(",")[0]), int(m.group(1))))
    return pairs


def render(data):
    lines = ["-- Phoenix_UI_Data NPC positions recorded with Phoenix UI's local collector (Quests > Automation > Record NPC",
             "-- positions) and merged by tools/questdata/merge_collected.py; do not edit. Facts noted in the game client by the",
             "-- maintainer's own characters: NPC ID, map, position (and vignette ID / position). No names, realms or GUIDs.",
             "-- Record: npcID,x,y,kind,sightings (x/y in 0.1 %; kind 0 talked to, 1 quest, 2 vendor, 3 trainer, 5 flight master)",
             "local _, D = ..."]
    for flavor in ("retail", "forever"):
        npcs, vigs = data[flavor]
        by_map = {}
        for (npc, mp), (x, y, k, n) in sorted(npcs.items()):
            by_map.setdefault(mp, []).append(f"{npc},{round(x * 1000)},{round(y * 1000)},{k},{n}")
        lines.append(f'D:Collected("{flavor}", {{')
        for mp in sorted(by_map):
            lines.append(f'    [{mp}] = "' + ";".join(by_map[mp]) + '",')
        lines.append("}, {")
        for vid, (mp, x, y) in sorted(vigs.items()):
            lines.append(f'    [{vid}] = "{mp},{round(x * 1000)},{round(y * 1000)}",')
        lines.append("})")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flavor", choices=("retail", "forever"), required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("saved", nargs="+")
    a = ap.parse_args()
    data = read_existing()
    npcs, vigs = data[a.flavor]
    skip = known(a.flavor)
    added = refined = skipped = 0
    for path in a.saved:
        proc = subprocess.run(["lua5.1", "-e", DUMP.replace("arg[1]", repr(str(pathlib.Path(path).resolve())))],
                              capture_output=True, text=True)
        if proc.returncode:
            print(f"{path}: {proc.stderr.strip()}", file=sys.stderr)
            continue
        for line in proc.stdout.splitlines():
            p = line.split("|")
            if p[0] == "N":
                npc, mp, x, y, k, n = int(p[1]), int(p[2]), float(p[3]), float(p[4]), int(p[5]), int(p[6])
                if (npc, mp) in skip or not (0 <= x <= 1 and 0 <= y <= 1):
                    skipped += 1
                    continue
                cur = npcs.get((npc, mp))
                if cur:
                    t = cur[3] + n
                    npcs[(npc, mp)] = [(cur[0] * cur[3] + x * n) / t, (cur[1] * cur[3] + y * n) / t, max(cur[2], k), t]
                    refined += 1
                else:
                    npcs[(npc, mp)] = [x, y, k, n]
                    added += 1
            elif p[0] == "V":
                vigs.setdefault(int(p[1]), (int(p[2]), float(p[3]), float(p[4])))
    text = render(data)
    print(f"{a.flavor}: {added} new NPC spots, {refined} refined, {skipped} already in the source data; {len(vigs)} vignettes")
    if not a.dry_run:
        OUT.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
