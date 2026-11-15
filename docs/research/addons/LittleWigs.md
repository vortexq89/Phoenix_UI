# LittleWigs (dungeon boss mods for BigWigs)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (game v12.1.22, I:\ v12.1.21).

**Licence:** All Rights Reserved with the same "free to fork on GitHub" note as BigWigs. Study only.

BigWigs content packs for dungeons, delves and scenarios. Same module API as BigWigs. The packs are huge (around 180k lines of boss modules) and older expansions still use combat-log listeners (`self:Log`).

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `LittleWigs` | v12.1.22 | v12.1.21 | 11508, 11509, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120107, 120100, 120105 | 75 / 12,118 |
| `LittleWigs_TheWarWithin` | present, no version line | (no version line) | 120100, 120105, 120107 | 113 / 32,294 |
| `LittleWigs_Dragonflight` | present, no version line | (no version line) | 120100, 120105, 120107 | 60 / 17,009 |
| `LittleWigs_Shadowlands` | present, no version line | (no version line) | 120100, 120105, 120107 | 60 / 16,935 |
| `LittleWigs_BattleForAzeroth` | present, no version line | (no version line) | 120100, 120105, 120107 | 84 / 25,105 |
| `LittleWigs_Legion` | present, no version line | (no version line) | 120100, 120105, 120107 | 96 / 21,052 |
| `LittleWigs_WarlordsOfDraenor` | present, no version line | (no version line) | 120100, 120105, 120107 | 50 / 7,596 |
| `LittleWigs_MistsOfPandaria` | present, no version line | (no version line) | 50503, 50504, 120107, 120100, 120105 | 49 / 5,722 |
| `LittleWigs_Cataclysm` | present, no version line | (no version line) | 40402, 50503, 50504, 120107, 120100, 120105 | 79 / 9,473 |
| `LittleWigs_WrathOfTheLichKing` | present, no version line | (no version line) | 30405, 38002, 40402, 50503, 50504, 120107, 120100, 120105 | 83 / 6,675 |
| `LittleWigs_BurningCrusade` | present, no version line | (no version line) | 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120107, 120100, 120105 | 76 / 7,049 |
| `LittleWigs_Classic` | present, no version line | (no version line) | 11508, 11509, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120107, 120100, 120105 | 81 / 6,896 |

- **Title / notes (toc):** LittleWigs - Boss warnings for 5-man dungeons & scenarios.
- **Author (toc):** Funkeh, Delk
- **X-License (toc):** All Rights Reserved: You are free to fork and modify on GitHub, please ask us about anything else.
- **Required deps:** BigWigs
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 0x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ENCOUNTER_TIMELINE_EVENT_ADDED`, `ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED`, `ENCOUNTER_TIMELINE_EVENT_REMOVED`, `ME_ONLY_EMPHASIZE`, `UNIT_SPELLCAST_START`, `TANK_HEALER`, `GOSSIP_SHOW`, `ENCOUNTER_WARNING`, `PLAYER_CHOICE_UPDATE`, `CASTBAR_COUNTDOWN`, `UNIT_SPELLCAST`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_SUCCEEDED`, `CHAT_MSG_MONSTER_EMOTE`, `SPELL_CAST_START`, `SPELL_CAST_SUCCESS`, `SPELL_AURA_APPLIED`, `SPELL_INTERRUPT`, `SPELL_AURA_REMOVED`, `SPELL_PERIODIC_DAMAGE`, `SPELL_PERIODIC_MISSED`, `SPELL_AURA_APPLIED_DOSE`
- **C_ namespaces used:** `C_EncounterTimeline`, `C_ScenarioInfo`, `C_MerchantFrame`, `C_GossipInfo`

## Features

### Dungeon boss modules

- **What it does:** Timers, messages, sounds and nameplate icons for dungeon bosses and notable trash.
- **Design (UX, settings, defaults):** Each module lists its option keys; trash modules register mobs by NPC id (`RegisterEngageMob`).
- **How it is coded:** Most-called API across the packs: `Log` (1153x), `CDBar` (1132x), `PlaySound` (1055x), `Message` (880x), `Nameplate` (620x). Midnight dungeons follow the timeline approach of BigWigs.
- **Benefit to players:** Mythic+ players get warnings for trash casts, which Blizzard's timeline does not cover.

**Compared with Phoenix_UI** - status: **partial**. Phoenix Pulse covers boss timelines; trash coverage is through Nameplates (`np.cast`, `np.interrupt`, `np.npc` colours) and the planned per-dungeon NPC data packs (`Phoenix_UI_Nameplates/DataPacks.lua`).

Ideas to adopt (original code only): Ship the per-dungeon NPC packs (dangerous casts, priority mobs) as data: highest value for M+ players. Keep them original (ours from in-game testing or public spell data).

## Verdict

Gap is data for trash in Midnight dungeons. P2: finish `DataPacks.lua` content after the user's testing.
