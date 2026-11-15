# RareScanner

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only (not on I:\), 12.1.5.3.

**Licence:** All Rights Reserved (toc X-License). Study only.

Detects rares, treasures and events via vignettes, alerts with a clickable button, plays sounds, and keeps a huge database of rare NPCs, containers, loot, achievements, map pins, respawn timers and routes.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `RareScanner` | 12.1.5.3 | not on I:\\ | 120105 | 93 / 79,452 |

- **Title / notes (toc):** RareScanner - Minimap scanner. Warns you visually with a button and a miniature and plays a sound everytime a rare NPC, treasure/chest or event shows up in your minimap
- **Author (toc):** maqjav, Maciza-Tyrande
- **X-License (toc):** All Rights Reserved
- **SavedVariables:** `RareScannerDB`
- **Slash commands:** `/qtip`
- **Embedded libraries:** Libs (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 80x, `C_Timer` calls 33x.
- **Secure surface:** `SetAttribute` 3x, `SecureActionButtonTemplate` 1x
- **Hooks:** `HookScript` 13x, `hooksecurefunc` 24x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `MODIFIER_STATE_CHANGED`, `TIME_PLAYED_MSG`, `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `UNIT_DIED`, `GROUP_ROSTER_UPDATE`, `PLAYER_LOGOUT`, `ADDON_LOADED`, `ALARM_MESSAGE`, `CLICK_TARGET`, `VIGNETTE_MINIMAP_UPDATED`, `VIGNETTES_UPDATED`, `NAME_PLATE_UNIT_ADDED`, `UPDATE_MOUSEOVER_UNIT`, `PLAYER_REGEN_ENABLED`, `PLAYER_TARGET_CHANGED`, `PLAYER_SOFT_INTERACT_CHANGED`, `LOOT_OPENED`, `CHAT_MSG_MONSTER_YELL`
- **C_ namespaces used:** `C_Map`, `C_QuestLog`, `C_Timer`, `C_VignetteInfo`, `C_Item`, `C_CVar`, `C_Minimap`, `C_DateAndTime`, `C_ChatInfo`, `C_TaskQuest`, `C_CreatureInfo`, `C_AreaPoiInfo`, `C_Spell`, `C_KeyBindings`, `C_UnitAuras`

## Features

### Vignette alerts with target button

- **What it does:** When a rare/treasure vignette appears: sound, flash, a button showing the model that targets the NPC with a macro.
- **Design (UX, settings, defaults):** Sounds per type, volume, channel; filters by NPC, container, event, zone; max-seen-time filters; auto waypoints (Blizzard, TomTom, WaypointUI).
- **How it is coded:** `VIGNETTE_MINIMAP_UPDATED`-style handling via `C_VignetteInfo.GetVignetteInfo`; `RSButtonHandler.lua` builds a secure macro button (`/target name`) prepared out of combat; `RSRecentlySeenTracker`, `RSRespawnTracker`.
- **Benefit to players:** Never miss a rare.

**Compared with Phoenix_UI** - status: **partial**. Phoenix `Phoenix_UI_HUD/Vignettes.lua` (`vignette.rare`, `treasure`, `event`, `sound`, `flash`, `chat`, `ignore`, `instances`) shipped in PR #71.

Ideas to adopt (original code only): P2: add an optional **secure target button** (macro `/tar`, built out of combat, hidden in combat) and auto waypoint via our `Core/Waypoint.lua`. Keep the database out (RareScanner's data is theirs).

### World map database and loot

- **What it does:** Pins for every known rare and treasure with loot, achievements, collected state.
- **Design (UX, settings, defaults):** Explorer panel, filters by loot quality/category, overlays, routes.
- **How it is coded:** Large static data (not copied), HereBeDragons for coordinates, map provider mixins.
- **Benefit to players:** Collectors plan farming.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix: none.

Ideas to adopt (original code only): Not planned; recommend RareScanner alongside Phoenix.

## Verdict

Phoenix covers the alert; P2 for a secure target button + waypoint. Database out of scope.
