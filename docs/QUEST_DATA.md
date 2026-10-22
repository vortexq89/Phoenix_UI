# Quest data (Phoenix_UI_Data)

The Quests page (plan v2 stage S14) draws quest-giver and turn-in pins from a separate, **load-on-demand** addon,
`Phoenix_UI_Data`. Phoenix loads it only while *Quest givers from data*, *Turn-in spots* or *Quest tooltips* is on.
This file records where every fact comes from, what the licences allow, how the data is built and checked, and
what is still to do.

## Sources and licences

| Fact | Source | Licence / terms | Used for |
|---|---|---|---|
| Quest giver NPC, giver coordinates (per uiMap), prerequisites (all or *N of*), side, race and class restrictions, minimum level, daily/weekly/repeatable/breadcrumb, English quest and NPC names | [AllTheThings](https://github.com/AllTheThings/AllTheThings) source database, `.contrib/.db` (retail: `standard/02 - Outdoor Zones`; Forever: `forever/zones`) | MIT (`Phoenix_UI_Data/LICENSE-ATT.txt` keeps the notice) | giver pins, availability filter, tooltips |
| Turn-in spot per quest (retail) | Blizzard client tables `QuestPOIBlob` (objective index −1), `QuestPOIPoint`, `UiMapAssignment`, read as CSV from wago.tools for build 12.1.5.70448 | Game data the client already ships; facts only | turn-in pins |
| Available quest lines, quest titles (localized), objectives and progress, levels, tags | Runtime API: `C_QuestLine`, `C_QuestLog`, `C_GossipInfo` | the game | everything live |

Phoenix copies **no code** from these projects. `tools/questdata/att_extract.lua` is Phoenix's own reader: it
evaluates the database files in a stub environment (with a small `#if` preprocessor for the build-version
directives) and prints facts. The facts are rewritten into Phoenix's own packed format.

**Not used:** Wowhead (its terms forbid scraping), Questie/QuestieDB (all rights reserved per its own licence
note), TrinityCore/CMaNGOS world databases (GPL, and server-side data), HandyNotes/RareScanner data.

## Building

```
python3 tools/questdata/build_questdata.py --fetch               # sparse clone of ATT into /tmp/phoenix_questdata
python3 tools/questdata/build_questdata.py --att <ATT checkout>  # or use an existing checkout
python3 tools/questdata/build_questdata.py --slice midnight      # one slice only
```

The generator downloads the three DB2 tables from wago.tools for the pinned build (cached), runs the extractor per
slice and flavour, and writes `Phoenix_UI_Data/Quests_<Slice>.lua` plus `Manifest.lua` (ATT commit, game builds,
counts). Rules applied: quests removed at or before the pinned build (ATT timelines) are dropped, as are
unobtainable ones (`u` 1 and 2); a quest without its own coordinates takes its giver NPC's; World Quests,
treasures, rares, achievements, battle pets, flight paths and zone drops are skipped (the game shows world
quests itself, the rest are not quests you pick up from an NPC).

Record format (one string per uiMap, records split by `;`):
`questID,npcID,x,y,minLevel,side,flags,classes/,races/,prerequisites/,needed,turnInMap,turnInX,turnInY`
with x/y in 0.1 % of the map, side 1 Alliance / 2 Horde, flags 1 daily, 2 weekly, 4 breadcrumb, 8 repeatable.
Each slice file calls `D:Slice(key, flavor, expansion)` first and returns early on the other client, so one file
list (and one generated `_Forever.toc`) serves both games.

## First data slice (shipped in S14)

| Slice | Client | Quests | Maps | With turn-in | Dropped (removed / no position) | NPC names | Size |
|---|---|---|---|---|---|---|---|
| Midnight (Quel'Thalas) | retail | 952 | 35 | 837 | 24 / 167 | 556 | ~100 KB |
| The War Within (Khaz Algar) | retail | 1384 | 33 | 1128 | 83 / 282 | 707 | ~140 KB |
| Azeroth (Eastern Kingdoms, Kalimdor) | WoW Forever | 3090 | 53 | 0 | 3 / 228 | 1195 | ~285 KB |

## Accuracy check

- **Spot checks** (also asserted by the smoke test): quest 86737 is given by Lor'themar Theron (235787) at
  45.4, 70.4 in Silvermoon (2393) and turned in on map 2395 at 46.7, 45.7 — where the follow-up quests start;
  Forever quest 783 (*A Threat Within*) is given by NPC 823 at 48.1, 42.9 in Elwynn Forest (1429), Alliance only.
  The DB2 coordinate conversion was verified on quest 11 (Elwynn turn-in 24.2, 74.5, Deputy Rainer).
- **Chain test:** for chained quests, the next quest's giver should stand where the previous one is handed in.
  83 % (Midnight) and 73 % (The War Within) of chained pairs are within 2 % of the map; the median gap is 0.1 %.
  The rest are mostly hand-ins to a different NPC or phase.
- At run time the game always wins: titles come from `C_QuestLog.GetTitleForQuestID` when the client knows the
  quest, a quest the game already offers as a quest line is shown once (from `C_QuestLine`), and completed or
  logged quests drop off at once.

## Known limits

- **Forever has no turn-in spots:** wago's Forever (wowf) tables are nearly empty, so the *Turn-in spots* row is
  retail-only. Forever still has givers, prerequisites and filters from ATT's Forever database.
- **NPC names are English** (the source DB's comments). Quest titles are localized by the game when it knows them.
- **Positions are the giver's,** not every spawn point: the client tables have no creature spawns, and ATT stores
  one coordinate per quest or NPC.
- Phased or event-only givers can show where the database puts them while the NPC is elsewhere.

## Remaining slices (documented, not shipped)

1. Dragon Isles (`02 - Outdoor Zones/14`), then Shadowlands, Battle for Azeroth, Legion, Draenor, Pandaria,
   Northrend, Outland and the old continents for retail (folders 01–13), one file each.
2. Dungeon and raid quests (`01 - Dungeons Raids`) for both clients.
3. Flight masters and points of interest from `TaxiNodes` / `AreaPOI` (DB2) for the arrow's route hints.
4. The opt-in contribution collector (the toggle ships now, UI only; nothing is recorded) — plan stage S17,
   once a backend is approved.

Each slice is one more entry in `SLICES` in the generator and one line in `Phoenix_UI_Data.toc`; the module
reads whatever slices the manifest lists and adds an expansion filter row per slice.
