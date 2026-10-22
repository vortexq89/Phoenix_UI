# Game data from Blizzard client files (wago.tools DB2)

Products on wago.tools (2026-10-22): `wow` 12.1.5.70448 (retail), `wowf` 1.60.1.70532 (Forever), `wow_classic`
5.5.4.70531 (Mists Classic), `wow_anniversary` 2.5.6.70006 (TBC Anniversary), `wow_classic_era` 1.15.9.70003,
`wowt` 12.1.7.70424 (PTR). CSV: `https://wago.tools/db2/<Table>/csv?build=<version>`.

## Tables checked on 12.1.5.70448
| Table | Rows | Use |
|---|---|---|
| ManifestInterfaceData | 142 885 | interface file paths → fileDataID (icon audit) |
| UiTextureAtlasElement / Member | 19 680 / 17 513 | atlas names and sizes (icon audit) |
| SpellName | 416 246 | spell names |
| QuestV2 | 66 552 | quest IDs (no titles: server-side) |
| QuestObjective | 10 771 | objectives for 4 433 quests |
| QuestPOIBlob / QuestPOIPoint | 72 740 / 172 728 | objective areas for 21 809 quests |
| QuestLine / QuestLineXQuest | 1 694 / 21 150 | quest chains |
| Creature | 23 166 | NPC names/titles/classification (no spawns) |
| Vignette | 7 247 | rares/treasures |
| AreaPOI, TaxiNodes, UiMap, UiMapAssignment, UiMapLink | 3 946 / 1 485 / 1 967 / 22 780 / 62 | map facts and coordinate transforms |
| JournalInstance / JournalEncounter / JournalEncounterSection / JournalEncounterCreature | 231 / 1 215 / 28 459 / 1 960 | dungeon and boss journal |
| MapChallengeMode | 87 | Mythic+ maps |

## Not in client data
NPC spawn coordinates, quest giver/turn-in NPCs (retail), quest titles/text, boss timer durations, BiS lists,
drop rates. Only community data has them (QuestieDB: ARR/GPLv3-pending; Wowhead: terms forbid scraping), or
runtime APIs in game. Phoenix never ships scraped or unlicensed community data.
