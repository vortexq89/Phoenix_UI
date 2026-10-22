# Phoenix_UI_Data

Load-on-demand data addon for Phoenix UI's **Quests** page. Phoenix loads it (`C_AddOns.LoadAddOn`) only when
a quest-pin option is on, so it costs nothing otherwise. It holds facts only — no code from other projects.

| File | What | Source |
|---|---|---|
| `Data.lua` | Tiny loader: picks the client (retail / WoW Forever), collects slices into `PhoenixUI_QuestData` | Phoenix (MIT) |
| `Manifest.lua` | Source commit, game builds and per-slice counts | generated |
| `Quests_Midnight.lua` | Midnight (Quel'Thalas) quests, retail | generated |
| `Quests_WarWithin.lua` | The War Within (Khaz Algar) quests, retail | generated |
| `Quests_Forever.lua` | WoW Forever zone quests (Eastern Kingdoms, Kalimdor) | generated |

Each record: quest ID, giver NPC ID, giver x/y (0.1 % of the map), minimum level, side, flags (daily, weekly,
breadcrumb, repeatable), class and race restrictions, prerequisite quests (and how many are needed) and the
turn-in map/x/y.

## Provenance and licences

* **Quest givers, coordinates, prerequisites, restrictions, English names** — extracted from the
  [AllTheThings](https://github.com/AllTheThings/AllTheThings) source database (`.contrib/.db`), MIT licence
  (see `LICENSE-ATT.txt`). Phoenix reads the database with its own clean-room reader
  (`tools/questdata/att_extract.lua`); no AllTheThings code is copied or shipped.
* **Turn-in areas (retail)** — Blizzard's own client tables `QuestPOIBlob` / `QuestPOIPoint` /
  `UiMapAssignment` (game data the client already ships; read as CSV from wago.tools), objective index -1.
* **Not used:** Wowhead (scraping forbidden by its terms), Questie, TrinityCore/CMaNGOS databases,
  HandyNotes/RareScanner data.

Regenerate: `python3 tools/questdata/build_questdata.py --fetch` (see `docs/QUEST_DATA.md`).
The code in this folder is MIT (`LICENSE`).
