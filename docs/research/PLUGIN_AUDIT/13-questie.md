# 13 · Questie and plugins

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\Questie-master` (924 Lua files without the DB) and QuestieTrace. Licence: GPL-3 with "all rights reserved" notes, so behaviour only, and its **database is not copied**. Scope: Forever (Classic) levelling; retail has its own quest system.

| Feature | Phoenix Quests (52 rows) | Status |
|---|---|---|
| Available quests on the map and minimap | Available quest lines, Quest givers from data, Pins on the minimap | have (from Phoenix's own data) |
| Objectives on the map (mobs, objects) | — | **partial** (turn-ins only) |
| Turn-in spots | yes | have |
| Waypoint arrow, distance, ETA | yes | have |
| Tracker | Objective tracker restyle | have |
| Quest tooltips (on mobs and items) | Quest tooltips | have |
| Hide low-level, filter by level | Hide low-level quests | have |
| Townsfolk (vendors, trainers, flight) | Townsfolk pins | have |
| Journey log / quest history | — | missing |
| Auto-accept / turn-in | yes | have |
| Announce progress | yes | have |
| Recorded NPC positions | yes (Phoenix's own crowd data) | have (unique) |
| Data coverage | Midnight, TWW, Azeroth | partial (no Outland/Northrend …) |

Plan (spec 014): objective areas (polygons from Phoenix's own recorded data), a journey log, and coverage expansion by the recording pipeline.
