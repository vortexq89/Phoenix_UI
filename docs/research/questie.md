# Questie, QuestieDB, QuestieTrace, Questie/WoW-API

Studied: GitHub READMEs, licences, TOC list and data layout (Questie pushed 2026-10-22; QuestieDB 2026-10-21).

## Licence
`LICENSE.md` (all four): historically unlicensed, so "**when in doubt consider Questie as all rights reserved**";
the team is collecting contributor consent for GPLv3 and accepts forks "under the GPLv3 terms, but we can not
promise all contributors are". The name and logo are excluded. Questie/WoW-API has no licence.
Phoenix (MIT): **clean-room**. Calling QuestieDB's *public runtime API* when the user installed QuestieDB
themselves is fine (we ship none of its code or data).

## Flavours
TOCs present: `Questie.toc`, `_Vanilla`, `_TBC`, `_Wrath`, `_Cata`, `_Mists`, `_Camelot` (= WoW Forever).
**No Mainline/retail TOC: Questie does not support retail Midnight.** QuestieTrace is "Not compatible with Retail".
QuestieDB covers Classic Era, TBC, Wrath, Cata, Mists and Forever.

## How it is built (what we learned)
- **Data:** quests, NPCs, items, objects with keys such as start/finish NPC, objectives (creature/item/object/
  area), required level/race/class, pre-quests (`preQuestSingle/Group`), exclusive groups, zone, and **NPC spawn
  coordinates per zone** (`NpcDB.spawns(30) → { [12] = { {36.43, 55.89}, … } }`) plus waypoint paths.
- **Storage trick:** QuestieDB "bakes" data into compressed CBOR blocks stored as **TOC metadata**, read at runtime
  with no Lua parse cost; per-flavour generated TOCs; nine base locales; a corrections layer per expansion
  (`src/corrections/<expansion>`) and a runtime corrections registrar for third parties.
- **Features:** start/turn-in/objective notes on world map and minimap, NPC path lines, tooltips on mobs/items
  ("Quest: 3/8"), its own tracker, journey log, available-quest filtering by level/class/race/profession/rep,
  auto accept/turn-in, Questie Public API for other addons. QuestieTrace records sessions for debugging.
- **Repo size:** Questie ~393 MB of git history, QuestieDB ~65 MB.

## Facts it needs vs. what Blizzard client data has (verified on wago.tools, 12.1.5.70448)
| Fact | In DB2? | Notes |
|---|---|---|
| Quest IDs | yes `QuestV2` (66 552) | ID only; **titles and text are server-side** (runtime `C_QuestLog.GetTitleForQuestID` / quest cache) |
| Objectives | partial `QuestObjective` (10 771 rows, 4 433 quests) | type/amount/objectID/description |
| Objective areas on the map | yes `QuestPOIBlob` (72 740) + `QuestPOIPoint` (172 728), 21 809 quests | the polygons Blizzard draws; world → map coords via `UiMapAssignment` |
| Quest lines / chains | yes `QuestLine` (1 694), `QuestLineXQuest` (21 150) | ordered chains with names |
| NPC names, titles, type | yes `Creature` (23 166) | |
| **NPC spawn coordinates** | **no** | server-side. Only community-collected data has them (QuestieDB, Wowhead). Wowhead's terms forbid scraping; QuestieDB is all-rights-reserved/GPLv3-pending. Phoenix cannot ship spawns |
| Quest giver/turn-in NPC | no (server) | retail: runtime map pins for available quests; Classic: community data only |
| Rares/treasures | yes `Vignette` (7 247) + runtime `C_VignetteInfo` | |
| Flight points, POIs, maps | yes `TaxiNodes`, `AreaPOI`, `UiMap`, `UiMapAssignment`, `UiMapLink` | |

## How Phoenix does it (better, and honest)
- **Retail Midnight:** Blizzard already draws objective areas, quest-giver pins and supertracking, so a Questie
  clone adds little. Phoenix *Quests* adds what is missing: a Phoenix-styled tracker with distance sort and
  progress bars, zone **quest-line browser** (`C_QuestLine.GetAvailableQuestLines`, `GetQuestLineQuests`) with
  chain progress, objective/area overlays from runtime POIs, rares/treasures list from vignettes, smart auto
  accept/turn-in (reward picked by upgrade value or vendor price), waypoint arrow via `C_Map.SetUserWaypoint` +
  `C_SuperTrack`, quest-item button. All runtime APIs, no shipped spawn data.
- **Forever / Classic:** generated tables from that flavour's DB2 (quest lines, objectives, POI blobs, creature
  names) + runtime APIs; NPC spawn pins only when the user has QuestieDB installed (optional provider through its
  public API). Shipping our own spawn database would require collecting it ourselves in game (an opt-in Phoenix
  recorder, like QuestieTrace) — possible later, large effort, and it must never send names or positions of players.
