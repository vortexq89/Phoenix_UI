# Mythic Dungeon Tools (MDT, + MDT_UI)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only (not on I:\), 6.3.24.

**Licence:** GNU GPL v2 (LICENSE). Not compatible with copying into Phoenix; ideas only.

The standard Mythic+ route planner: a map per dungeon with every enemy pack, enemy forces, pulls you draw, notes and live sharing. Data files per dungeon (`Midnight/*.lua`, 16 Midnight-season dungeons).

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `MythicDungeonTools` | 6.3.24 | not on I:\\ | 120107, 120105 | 72 / 60,508 |
| `MythicDungeonTools_UI` | 6.3.24 | not on I:\\ | 120107, 120105 | 35 / 4,902 |

- **Title / notes (toc):** Mythic Dungeon Tools (MDT) - Tool for planning and optimizing Mythic+ dungeon runs
- **Author (toc):** Nnoggie
- **SavedVariables:** `MythicDungeonToolsDB`
- **Slash commands:** `/dungeontools`, `/mdt`, `/mplus`, `/mythicdungeontools`
- **Optional deps:** !!AddonLocale, LibStub, Ace3
- **Embedded libraries:** AceComm-3.0, AceDB-3.0, CallbackHandler-1.0, LibAsync, LibDBIcon-1.0, LibDataBroker-1.1, LibSharedMedia-3.0, LibStub, load_core_libs.xml, load_libs.xml (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 52x, `C_Timer` calls 25x.
- **Secure surface:** `SetAttribute` 6x, `SecureActionButtonTemplate` 2x
- **Hooks:** `hooksecurefunc` 3x, `HookScript` 37x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`, `PLAYER_REGEN_ENABLED`, `READY_CHECK`, `RAID_TARGET_`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_DISABLED`, `UPDATE_INSTANCE_INFO`, `PLAYER_DIFFICULTY_CHANGED`, `GROUP_ROSTER_UPDATE`, `GLOBAL_MOUSE_DOWN`, `PLAYER_LOGIN`, `MDT_UI_DISABLED`, `CHAT_MSG_CHANNEL`, `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`, `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `GLOBAL_MOUSE_UP`, `SPELL_DATA_LOAD_RESULT`
- **C_ namespaces used:** `C_Timer`, `C_Spell`, `C_AddOns`, `C_ChatInfo`, `C_Map`, `C_EncodingUtil`, `C_Secrets`, `C_ChallengeMode`, `C_RestrictedActions`, `C_ScenarioInfo`, `C_Texture`

## Features

### Route planning on a map

- **What it does:** Click packs to add them to numbered pulls; running forces total per pull; draw lines and text with spell/raid-icon tags.
- **Design (UX, settings, defaults):** Pull rows sidebar, enemy hover card (Ctrl keeps it open), drawing toolbar, presets list, fullscreen mode.
- **How it is coded:** Per-dungeon data tables (enemies with npcId, count, spawn coords, clones). `PullLabelLayout.lua` is pure logic (no WoW API) tested with a stub; labels spiral out from each pull's centre like a word cloud. Sidebar uses a pure model + impure edge split (`SidebarModel.lua` / `Sidebar.lua`).
- **Benefit to players:** Groups agree on a route; players learn forces counts.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix Ascent shows forces (`ascent.forcesData`, `ascent.pullForces`), Nameplates shows M+ forces per mob, tooltips show forces (`tt.lines.forces`). No route planner.

Ideas to adopt (original code only): Do not build a planner (huge, MDT is the standard). Instead **read MDT's public API** if present (`MythicDungeonToolsAPI:GetEnemyForces(npcId)` documented in `Modules/API.lua`) for forces when our data is missing, and show "current pull" from the user's MDT route on the Ascent block. P3.

### Share and live sessions

- **What it does:** Export/import strings, send a route to the group, live session where everyone sees edits.
- **Design (UX, settings, defaults):** Route batch strings carry many routes; version check dialog.
- **How it is coded:** Addon messages (`SendAddonMessage` 45x) with compression/serialisation; `LiveSession.lua` checks for other live clients first.
- **Benefit to players:** Team coordination.

**Compared with Phoenix_UI** - status: **n/a**. Phoenix share strings exist for settings and layouts; no route sharing.

### Architecture lessons

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** Pure, testable modules for layout maths; a compact error handler that reports MDT errors internally; conflict check that prompts removal of an abandoned addon.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix already tests pure logic in `Tests/` with the offline harness.

Ideas to adopt (original code only): Adopt the "pure model + impure edge" naming in our own code reviews.

## Verdict

Out of scope to replicate. P3: optional MDT API read for forces and current pull.
