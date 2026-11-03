# EllesmereUI Group Finder

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Group finder search tweaks and an applications bar. The code says it is **held back from this release**: nothing runs.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIGroupFinder` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 3 / 4,376 |

- **Title / notes (toc):** EllesmereUI Group Finder - Premade Group search filters, listing, and application tools.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIGroupFinderDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 5x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 19x, `hooksecurefunc` 13x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `FULLSCREEN_DIALOG`, `LFG_LIST_APPLICATION_STATUS_UPDATED`, `PLAYER_LOGOUT`, `GLOBAL_MOUSE_DOWN`, `TANK_REMAINING`, `HEALER_REMAINING`, `DAMAGER_REMAINING`, `LFG_LIST_SEARCH_FAILED`, `CHALLENGE_MODE_MAPS_UPDATE`
- **C_ namespaces used:** `C_LFGList`, `C_Timer`, `C_MythicPlus`, `C_ChallengeMode`, `C_AddOns`, `C_ClassColor`

## Features

### Search tweaks and applications bar

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** Disabled in this version.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **better**. Phoenix GroupFinder is complete.

## Verdict

Not active; no comparison needed.
