# EllesmereUI Quest Tracker

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Skins Blizzard's Objective Tracker through hooks only and adds auto accept/turn-in, a quest-item hotkey and Forever sorting/filtering.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIQuestTracker` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 6 / 3,930 |

- **Title / notes (toc):** EllesmereUI Quest Tracker - A clean, updated reskin of Blizzard's Quest Tracker.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIQuestTrackerDB`
- **Slash commands:** `/eqt`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 1x, `C_Timer` calls 19x.
- **Secure surface:** `SetAttribute` 2x, `SecureActionButtonTemplate` 1x
- **Hooks:** `HookScript` 12x, `hooksecurefunc` 12x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `SUPER_TRACKING_CHANGED`, `QUEST_REMOVED`, `ENCOUNTER_END`, `QUEST_WATCH_LIST_CHANGED`, `QUEST_WATCH_UPDATE`, `INPUT_DEVICE_INTERFACE_TRANSITION`, `ZONE_CHANGED_NEW_AREA`, `ADDON_LOADED`, `PLAYER_LOGIN`, `ZONE_CHANGED`, `QUEST_DETAIL`, `QUEST_COMPLETE`, `GOSSIP_SHOW`, `EUI_QUESTITEM`, `UPDATE_BINDINGS`, `PLAYER_REGEN_ENABLED`, `SCENARIO_UPDATE`, `SCENARIO_CRITERIA_UPDATE`, `TRACKED_ACHIEVEMENT_LIST_CHANGED`
- **C_ namespaces used:** `C_QuestLog`, `C_Timer`, `C_GossipInfo`, `C_SuperTrack`, `C_ChatInfo`, `C_EventUtils`, `C_CampaignInfo`, `C_ChallengeMode`, `C_AddOns`, `C_InstanceEncounter`, `C_PlayerInfo`, `C_UnitAuras`

## Features

### Skin via hooks only

- **What it does:** Restyle headers, blocks, bars; never `SetScript` on tracker frames.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Strict rules listed in `Visibility.lua`; SplashFrame taint-free OnHide clone.
- **Benefit to players:** No taint from the tracker.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_QuestTracker` (`qt.*`: sort, filter, autoTrackZone, autoQuest, itemButtons, mplusBlock).

### Quest item hotkey

- **What it does:** One binding uses the closest quest item.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Secure button bound via override binding.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **unverified**. Phoenix `qt.itemButtons`; hotkey unverified.

Ideas to adopt (original code only): P3.

## Verdict

Parity.
