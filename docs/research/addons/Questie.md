# Questie (+ QuestieDB, + QuestieTrace)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** I:\ only (source checkouts `Questie-master`, `QuestieDB-master`, `QuestieTrace-master`); Questie toc 12.1.0. Not installed in the retail game folder (it is a Classic/Forever addon).

**Licence:** Questie and QuestieDB: LICENSING files say contributions after 21.10.2026 count as GPLv3; earlier code has mixed authorship. Treat as GPL (no copying). The big data tables were excluded from the copy (>1 MB each). QuestieTrace and Questie contain AGENTS.md/CLAUDE.md files, which we did not act on.

Quest helper for Classic flavours and WoW Forever: quest givers, objectives and turn-ins on the map and minimap from a full quest/NPC/object/item database, a tracker, tooltips and announcements. QuestieDB is the database package; QuestieTrace records play sessions (events + API results) for debugging.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `Questie` | not installed | (see toc) | 00000 | 847 / 221,728 |
| `QuestieDB` | not installed | (see toc) | 11508, 11509, 20506, 30405, 38000, 38001, 38002, 40402, 50503, 50504, 16001 | 357 / 1,895,850 |
| `QuestieTrace` | not installed | (see toc) | 16001 | 1349 / 338,388 |

- **Title / notes (toc):** Questie game client not supported - Questie only supports Classic official servers.
- **Author (toc):** not stated in the toc
- **Slash commands:** `/qprofiler`
- **Embedded libraries:** AceAddon-3.0, AceBucket-3.0, AceComm-3.0, AceConfig-3.0, AceConsole-3.0, AceDB-3.0, AceDBOptions-3.0, AceEvent-3.0, AceGUI-3.0, AceGUI-3.0-SharedMediaWidgets, AceTimer-3.0, Annotations, CallbackHandler-1.0, HereBeDragons, Krowi_WorldMapButtons, LICENSE.md, LibDBIcon-1.0, LibDataBroker-1.1, LibDeflate, LibSharedMedia-3.0 (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 655x, `C_Timer` calls 186x.
- **Secure surface:** `SetAttribute` 314x, `SecureHandlers` 16x, `SecureHandler_Other_Execute` 12x, `SecureHandler_Self_Execute` 10x, `SecureActionButtonTemplate` 4x, `RegisterStateDriver` 3x
- **Hooks:** `hooksecurefunc` 61x, `HookScript` 85x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `CHAT_MSG_PARTY`, `QUEST_LOG_UPDATE`, `CHAT_MSG_SYSTEM`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `CHAT_MSG_SKILL`, `DELETE_ITEM`, `CRITERIA_UPDATE`, `LOADING_SCREEN_ENABLED`, `PLAYER_TARGET_CHANGED`, `ADDON_LOADED`, `LOADING_SCREEN_DISABLED`, `QUEST_ACCEPTED`, `UNIT_QUEST_LOG_CHANGED`, `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`, `BAG_UPDATE_DELAYED`, `PLAYER_LOGIN`, `QUEST_REMOVED`, `PLAYER_LEAVING_WORLD`, `CHAT_MSG_WHISPER`, `CHAT_MSG_EMOTE`, `BN_SENDER_123`
- **C_ namespaces used:** `C_QuestLog`, `C_Garrison`, `C_Item`, `C_TradeSkillUI`, `C_Commentator`, `C_PvP`, `C_Timer`, `C_Calendar`, `C_AuctionHouse`, `C_Club`, `C_LFGList`, `C_TransmogCollection`, `C_TooltipInfo`, `C_PetJournal`, `C_VoiceChat`, `C_EncodingUtil`, `C_AddOns`, `C_Seasons`, `C_Map`, `C_PetBattles`, `C_ClubFinder`, `C_Spell`

## Features

### Map and minimap pins from a quest database

- **What it does:** Shows available quests, objective areas and turn-ins.
- **Design (UX, settings, defaults):** Per-type toggles, icon scale, fade by distance, hide low-level quests.
- **How it is coded:** Huge compiled tables per expansion (quest, NPC, object, item) plus localisation lookups; HereBeDragons for coordinates; a ThreadLib to spread work over frames; `QuestieCombatQueue.lua` defers work out of combat.
- **Benefit to players:** Levelling without alt-tabbing.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix QuestTracker (`qt.*`) works on the game's own quest log; `Phoenix_UI_Forever` is small (flight timer, pet happiness, swing). No quest database.

Ideas to adopt (original code only): Not planned (data licence). For Forever players recommend Questie; make sure our QuestTracker yields (`qt.hideBlizzard` vs Questie tracker).

### Tracker, tooltips, announce

- **What it does:** Its own tracker, objective progress in NPC tooltips, party announce of progress.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Modules/Tracker`, `Tooltips`, `QuestieAnnounce.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **partial**. Phoenix `qt.announce`, `qt.objectiveSound`, `qt.progressColors`.

### Session recorder (QuestieTrace)

- **What it does:** Records events and API returns to replay a session; strips names, realms and GUIDs before export.
- **Design (UX, settings, defaults):** Web trace analyzer and CLI decoder.
- **How it is coded:** -
- **Benefit to players:** Developer debugging.

**Compared with Phoenix_UI** - status: **same idea**. Phoenix Sentinel `Recorder.lua` and the privacy scrubber `Privacy.lua` are the analogue.

Ideas to adopt (original code only): Their privacy rule (strip names, realms, GUIDs before saving) matches ours; keep it.

### Unit tests in Lua

- **What it does:** Questie ships `*.test.lua` next to modules and a test setup.
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix offline harness (`.tools/harness`) with 495 tests.

## Verdict

Forever-only scope. Recommend Questie for Forever levelling; no P1/P2 gaps.
