#!/usr/bin/env python3
"""Builds docs/plan_v2/PARITY.md and data/parity.json from parity.py.

With INV=<dir of the box-only option dump> it recounts every feature's options from the dump and reports
options no feature claims (must be none); without INV it reuses the counts frozen in parity.json.
  INV=/workspace/audit_i/out python3 docs/plan_v2/data/parity_build.py
"""
import collections, json, os, pathlib, re, sys
HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import parity  # noqa: E402

OUT_JSON = HERE / "parity.json"
OUT_MD = HERE.parent / "PARITY.md"
STATUS = ["done", "part", "miss", "imp", "skip"]
LABEL = {"done": "done", "part": "partial", "miss": "missing", "imp": "impossible", "skip": "skipped"}


def load_inventory(inv):
    keys = collections.defaultdict(list)
    for f in sorted(pathlib.Path(inv).glob("*.tsv")):
        for line in f.read_text(encoding="utf-8").splitlines():
            p = line.split("\t")
            if len(p) < 4:
                continue
            stem = os.path.basename(p[0]).replace("_Options.lua", "").replace(".lua", "").replace(".xml", "")
            keys[stem + "::" + p[1]].append(p[3])
    return keys


def count(features, inv):
    keys = load_inventory(inv)
    left = {k: list(v) for k, v in keys.items()}
    for f in features:
        f["n_calc"] = 0
    # pass 0: "key~regex" claims; pass 1: exact keys; pass 2: "Stem::" takes what is left in every section of that file
    for pas in (0, 1, 2):
        for f in features:
            for k in f["keys"]:
                key, _, rx = k.partition("~")
                if (pas == 0) != bool(rx):
                    continue
                if pas == 2 and not key.endswith("::"):
                    continue
                for kk in ([x for x in left if x.startswith(key)] if pas == 2 else [key]):
                    labels = left.get(kk, [])
                    if rx:
                        took = [x for x in labels if re.search(rx, x, re.I)]
                        left[kk] = [x for x in labels if not re.search(rx, x, re.I)]
                    else:
                        took, left[kk] = labels, []
                    f["n_calc"] += len(took)
    for f in features:
        if f["keys"]:
            f["n"] = f["n_calc"]
        del f["n_calc"]
    unclaimed = {k: len(v) for k, v in left.items() if v}
    return unclaimed, sum(len(v) for v in keys.values())


def main():
    feats = [dict(f) for f in parity.FEATURES]
    inv = os.environ.get("INV")
    total_options = None
    if inv:
        unclaimed, total_options = count(feats, inv)
        if unclaimed:
            for k, v in sorted(unclaimed.items()):
                print("UNCLAIMED", k, v)
    else:
        frozen = {(x["addon"], x["feature"]): x["n"] for x in json.loads(OUT_JSON.read_text())["features"]}
        for f in feats:
            if f["n"] is None:
                f["n"] = frozen.get((f["addon"], f["feature"]), 0)
            total_options = None
    for i, f in enumerate(feats, 1):
        f["id"] = i
        if f["status"] in ("part", "miss") and not f["stage"]:
            raise SystemExit(f"no stage for {f['addon']}: {f['feature']}")
        if f["status"] == "imp" and not f["note"]:
            raise SystemExit(f"impossible without a reason: {f['feature']}")
    by_addon = collections.OrderedDict()
    for f in feats:
        a = by_addon.setdefault(f["addon"], {"features": 0, "options": 0, **{s: 0 for s in STATUS}})
        a["features"] += 1
        a["options"] += f["n"] or 0
        a[f["status"]] += 1
    tot = {"features": len(feats), "options": sum(f["n"] or 0 for f in feats), **{s: sum(1 for f in feats if f["status"] == s) for s in STATUS}}
    stages = collections.OrderedDict()
    for f in sorted(feats, key=lambda x: (x["stage"] or "", x["owner"])):
        if f["stage"]:
            stages.setdefault(f["stage"], []).append(f)
    data = {"generated": "2026-10-22", "totals": tot, "addons": by_addon, "features": feats,
            "stages": {k: [f["id"] for f in v] for k, v in stages.items()}}
    if total_options is not None:
        data["inventory_options"] = total_options
        data["encounters"] = encounters(inv)
    else:
        old = json.loads(OUT_JSON.read_text())
        data["inventory_options"] = old.get("inventory_options")
        data["encounters"] = old["encounters"]
    OUT_JSON.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    write_md(feats, by_addon, tot, stages, data)
    print(json.dumps(tot))


MIDNIGHT = {
    "BigWigs_TheVoidspire": ("Raid", "The Voidspire"), "BigWigs_TheDreamrift": ("Raid", "The Dreamrift"),
    "BigWigs_MarchOnQuelDanas": ("Raid", "March on Quel'Danas"), "BigWigs_TheVenomousAbyss": ("Raid", "The Venomous Abyss"),
    "BigWigs_TheUnbindingOfKithix": ("Raid", "The Unbinding of Kith'ix"), "BigWigs_Sporefall": ("Raid", "Sporefall"),
    "BigWigs_MidnightLairs": ("Lair", "Midnight lairs"), "BigWigs_MidnightWorld": ("World", "Midnight world bosses"),
}
LW_NAMES = {"AltarOfFangs": "Altar of Fangs", "DenOfNalorakk": "Den of Nalorakk", "MagistersTerrace": "Magisters' Terrace",
            "MaisaraCaverns": "Maisara Caverns", "MurderRow": "Murder Row", "NexusPointXenas": "Nexus-Point Xenas",
            "TheBlindingVale": "The Blinding Vale", "VoidscarArena": "Voidscar Arena", "WindrunnerSpire": "Windrunner Spire",
            "Delves": "Delves", "Trash.lua": "Shared trash (several dungeons)"}


def encounters(inv):
    mods = json.loads((pathlib.Path(inv) / "encounters.json").read_text())
    rows, legacy = [], collections.OrderedDict()
    for m in mods:
        a = m["addon"]
        if a in MIDNIGHT:
            kind, name = MIDNIGHT[a]
        elif a == "LittleWigs":
            sub = m["path"].split("/Midnight/")[1].split("/")[0]
            kind, name = ("Delve" if sub == "Delves" else "Dungeon"), LW_NAMES.get(sub, sub)
        else:
            fam = "BigWigs" if a.startswith("BigWigs") else "LittleWigs"
            exp = a.split("_", 1)[1] if "_" in a else a
            e = legacy.setdefault((exp, fam), {"modules": 0, "timeline": 0, "options": 0})
            e["modules"] += 1
            e["timeline"] += 1 if m["timeline"] else 0
            e["options"] += m["options"] or 0
            continue
        r = next((x for x in rows if x["name"] == name), None)
        if not r:
            r = {"kind": kind, "name": name, "source": "BigWigs" if a.startswith("BigWigs") else "LittleWigs",
                 "modules": 0, "bosses": 0, "trash": 0, "timeline": 0, "options": 0}
            rows.append(r)
        r["modules"] += 1
        r["trash"] += 1 if m["trash"] else 0
        r["bosses"] += 0 if m["trash"] else 1
        r["timeline"] += 1 if m["timeline"] else 0
        r["options"] += m["options"] or 0
    return {"midnight": rows, "legacy": [{"expansion": k[0], "source": k[1], **v} for k, v in legacy.items()]}


LICENCES = [
    ("EllesmereUI + modules", "All rights reserved", "study only"),
    ("EllesmereUI_WindTools", "WindTools licence (ElvUI/NDui only, no redistribution)", "study only"),
    ("BigWigs, LittleWigs, BugGrabber, BugSack", "All rights reserved (fork on GitHub allowed)", "study only; Phoenix keeps its bar-style bridge (public API)"),
    ("Auctionator", "All rights reserved", "study only"),
    ("Questie, QuestieDB, QuestieTrace", "GPL-3.0 (contributions after 2026-10-21)", "not used: GPL cannot go into MIT Phoenix; data also Classic-era"),
    ("PremadeGroupsFilter", "GPL-2.0", "ideas only"),
    ("MoveAny", "GPL-3.0 on GitHub / ARR on CurseForge", "study only"),
    ("sArena Reloaded", "MIT (original sArena) + ARR (Reloaded additions)", "study only; spell IDs are game facts"),
    ("AutoQueue", "no licence file (ARR by default)", "study only"),
    ("TrufiGCD", "MIT", "reusable with notice; nothing copied so far"),
    ("idTip", "BSD-2-Clause", "reusable with notice; nothing copied so far"),
    ("Simulationcraft", "Unlicense", "reusable; Phoenix's /simc export is its own code"),
    ("WoW-API-main", "API reference", "facts only"),
]

FACTS = [
    "Encounter data: BigWigs + LittleWigs encode journal-instance, encounter and boss NPC IDs and the spell IDs of every ability for 1,339 modules (table below). Midnight modules map the game's timeline durations to abilities; Phoenix must author its own per-boss tables (S21) from the Encounter Journal API and in-game logs, not copy theirs.",
    "Mythic+: EllesmereUI MythicTimer and WindTools keep the current-season dungeon list (challenge map IDs, teleport spell IDs), affix IDs and boss objective order. Phoenix already reads these from C_ChallengeMode / C_MythicPlus at run time and keeps only teleport spell IDs as data.",
    "Spells: sArena keeps ~1,400 spell-keyed entries (DR categories, trinkets, racials, interrupts, dispels); AuraBuffReminders ~300 spell IDs (raid buffs, flasks, food, poisons, pets); CooldownManager and QoL small lists (movement, battle res, bloodlust). Spell IDs are game facts; Phoenix keeps its own lists.",
    "Quests / NPCs: Questie + QuestieDB ship Classic-era quest, NPC, object and item databases, plus a separate WoW Forever NPC table; GPL, so not used. Phoenix uses AllTheThings (MIT) + DB2 + its own collector (S17).",
    "Minimap buttons: EllesmereUI Minimap and WindTools collect addon buttons by LibDBIcon name and by children of Minimap; Phoenix's button bar does the same (done).",
    "Ability history: TrufiGCD shows the last casts of player / party / arena from UNIT_SPELLCAST_SUCCEEDED with a spell blocklist; Phoenix's Spell History does this for the player and the party (secret-safe), arena is S18.",
    "Tooltip IDs: idTip knows 27 ID kinds (spell, item, unit/NPC, quest, achievement, currency, mount, pet, talent, toy, macro, visual, …); Phoenix shows 8 today, the rest are S26.",
    "Movable frames: MoveAny lists ~150 Blizzard frames by global name (bars, unit frames, class power, cooldown viewers, chat, minimap, widgets, alerts); Phoenix's Movers cover those frames through its own anchors and Edit Mode, with the rest in S26.",
    "Arena: sArena tracks DR per category with the Midnight DR rules, trinkets/racials, cast bars, class icons with auras, pet frames, layouts; most needs C_PvP / arena unit APIs that are still plain, the enemy dispel and enemy aura parts are secret.",
    "Auction House: Auctionator offers shopping lists, price database from a full scan, undercut / cancel, selling shortcuts, tooltips with prices. Searching, posting and cancelling need a hardware event (your click); scanning (ReplicateItems) and price reading do not.",
    "Group Finder: AutoQueue accepts role checks (CompleteLFGRoleCheck, not protected) and clicks Sign Up / Enter Dungeon from timers; PGF filters listings by an expression language over activity and member data.",
]


def esc(s):
    return str(s).replace("|", "\\|")


def write_md(feats, by_addon, tot, stages, data):
    L = ["# Feature-parity audit — every addon on I:\\ (2026-10-22)", "",
         "Generated by `data/parity_build.py` from `data/parity.py`. Each row is one user-facing feature of a reference addon, "
         "in our own words, with the number of that addon's options it covers, the **one** Phoenix page that owns it and its "
         "status. Option counts come from a box-only dump of the copies (labels are not committed: most of these addons are "
         "All Rights Reserved or GPL). Clean-room rule: we learn what they do and write our own code.", "",
         "**Status:** done · partial (Phoenix has a shallower form) · missing (not built yet; the *Stage* column says when) · "
         "impossible (not possible in the 12.x / Forever API; the note gives the reason) · skipped (decided not to build: "
         "a recorded scope cut, or the addon's own tooling).", "",
         "## Counts per addon", "",
         "| Addon | Features | Options covered | Done | Partial | Missing | Impossible | Skipped |",
         "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for a, c in by_addon.items():
        L.append(f"| {esc(a)} | {c['features']} | {c['options']} | {c['done']} | {c['part']} | {c['miss']} | {c['imp']} | {c['skip']} |")
    L.append(f"| **Total** | **{tot['features']}** | **{tot['options']}** | **{tot['done']}** | **{tot['part']}** | **{tot['miss']}** | **{tot['imp']}** | **{tot['skip']}** |")
    L += ["", "## Impossible (with the API reason)", "", "| Addon | Feature | Phoenix page | Why |", "|---|---|---|---|"]
    for f in feats:
        if f["status"] == "imp":
            L.append(f"| {esc(f['addon'])} | {esc(f['feature'])} | {f['owner']} | {esc(f['note'])} |")
    L += ["", "## Stages that close the partial and missing rows", ""]
    for st, fs in stages.items():
        owners = collections.Counter(f["owner"] for f in fs)
        L.append(f"- **{st}** — {len(fs)} features ({sum(1 for f in fs if f['status'] == 'part')} partial, "
                 f"{sum(1 for f in fs if f['status'] == 'miss')} missing): " + ", ".join(f"{o} {n}" for o, n in owners.most_common()))
    enc = data["encounters"]
    L += ["", "## Encounter modules: BigWigs / LittleWigs vs Phoenix", "",
          "Phoenix draws **every** boss timer and alert the game sends (C_EncounterTimeline, ENCOUNTER_WARNING) for any "
          "encounter, in its own bars and banners, and styles BigWigs' bars when BigWigs is loaded. What it lacks is "
          "per-boss data: ability names for counts, sounds, nameplate icons and say-messages (stage S21); colours stay by severity because spell IDs are secret.", "",
          "| Kind | Instance | Source | Boss modules | Trash modules | Use the game timeline | Their options | Phoenix today |",
          "|---|---|---|---:|---:|---:|---:|---|"]
    for r in enc["midnight"]:
        n = r["bosses"] + r["trash"]
        if r["timeline"] >= n:
            today = "generic timeline bars + warnings; per-boss data S21"
        elif r["timeline"]:
            today = f"generic bars for the {r['timeline']} with a game timeline; {n - r['timeline']} without (S21 decides)"
        else:
            today = "no game timeline: nothing to draw (their modules use their own event logic)"
        L.append(f"| {r['kind']} | {esc(r['name'])} | {r['source']} | {r['bosses']} | {r['trash']} | {r['timeline']} | {r['options']} | {today} |")
    L += ["", "Older content (shipped by BigWigs / LittleWigs for 12.1, built on the combat log):", "",
          "| Expansion | Source | Modules | Use the game timeline | Their options |", "|---|---|---:|---:|---:|"]
    for r in enc["legacy"]:
        L.append(f"| {r['expansion']} | {r['source']} | {r['modules']} | {r['timeline']} | {r['options']} |")
    L += ["", "Phoenix today for older content: the generic timeline bars wherever the game sends a timeline (a few "
          "Dragonflight / Legion / WoD / Wrath dungeon bosses do), nothing per-boss. Combat-log modules are outside Phoenix's "
          "12.x rule (it never reads the combat log); see the impossible table.", "",
          "## Licences of the reference addons", "", "| Addon | Licence | How Phoenix may use it |", "|---|---|---|"]
    for a, lic, use in LICENCES:
        L.append(f"| {a} | {lic} | {use} |")
    L += ["", "Nothing from these addons is copied into Phoenix. Every row here is our own description.", "",
          "## Game facts they encode", ""] + [f"- {x}" for x in FACTS]
    L += ["", "## Every feature", ""]
    for a in by_addon:
        L += [f"### {a}", "", "| # | Their settings | Feature | Options | Phoenix page | Status | Stage | Notes |", "|---:|---|---|---:|---|---|---|---|"]
        for f in feats:
            if f["addon"] != a:
                continue
            where = " · ".join(k.split("~")[0].replace("::", " › ").rstrip(" ›") for k in f["keys"][:3]) + (" …" if len(f["keys"]) > 3 else "")
            L.append(f"| {f['id']} | {esc(where) or '—'} | {esc(f['feature'])} | {f['n'] or 0} | {f['owner']} | {LABEL[f['status']]} | {f['stage'] or ''} | {esc(f['note'])} |")
        L.append("")
    OUT_MD.write_text("\n".join(L) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
