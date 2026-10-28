# Premade Groups Filter (+ EllesmereUI skin plugin)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ for PGF (7.6.5 in both); the `PremadeGroupsFilter_EllesmereUI` skin (1.1.0) is in the game folder only.

**Licence:** PGF: GNU GPL v2. The EllesmereUI skin plugin: MIT (Stephen Cavaliere). GPL code must not be copied into Phoenix (our licence differs); ideas are fine.

Filters the Premade Groups list with panels (dungeon, raid, arena, RBG, delve, roles) or a free-form expression, and adds many list improvements.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `PremadeGroupsFilter` | 7.6.5 | 7.6.5 | 120105 | 53 / 9,209 |
| `PremadeGroupsFilter_EllesmereUI` | 1.1.0 | not on I:\\ | 120100 | 1 / 450 |

- **Title / notes (toc):** Premade Groups Filter - Allows filtering of premade groups using an UI or advanced filter expressions.
- **Author (toc):** Bernhard Saumweber
- **SavedVariables:** `PremadeGroupsFilterSettings`, `PremadeGroupsFilterState`
- **Optional deps:** PremadeRegions, RaiderIO
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 17x, `C_Timer` calls 0x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 17x, `HookScript` 11x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `PLAYER_LOGIN`, `LFG_LIST_APPLICATION_STATUS_UPDATED`, `AREA_POIS_UPDATED`, `ADDON_RESTRICTION_STATE_CHANGED`, `CHALLENGE_MODE_MAPS_UPDATE`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `GROUP_ROSTER_UPDATE`, `TANK_REMAINING`, `HEALER_REMAINING`, `DAMAGER_REMAINING`, `PGF_CONFIRM_RESET`, `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED`
- **C_ namespaces used:** `C_LFGList`, `C_ChallengeMode`, `C_MythicPlus`, `C_RestrictedActions`, `C_XMLUtil`, `C_AreaPoiInfo`, `C_EventUtils`, `C_AddOns`, `C_PvP`, `C_Item`, `C_UI`, `C_Texture`

## Features

### Expression filter

- **What it does:** Type e.g. `mprating >= 2500 and tanks == 0` to filter groups.
- **Design (UX, settings, defaults):** Advanced mode with help text; also simple panels per category; filters stored per category.
- **How it is coded:** `Modules/Expression.lua` compiles the text with `loadstring("return "..exp)`, sets a sandbox environment built from the search result with `setfenv`, and runs it with `pcall`. Pseudo: `env = vars(result); ok, pass = pcall(setfenv(compile(exp), env))`.
- **Benefit to players:** Very precise group search.

**Compared with Phoenix_UI** - status: **better (safer, friendlier errors)**. Phoenix `Phoenix_UI_GroupFinder/Expr.lua`: an original parser (or/and/not/compare/sum/term grammar), no `loadstring`, reports unknown names with a suggestion. Plus `gf.*` filters, why-hidden count (`Gaps.lua`).

### List improvements

- **What it does:** Group age, role indicators with specs, rating info, remaining slots, lockout info, compact list entries, one-click sign-up, sign-up on Enter, persistent sign-up note, member info in tooltip, application status.
- **Design (UX, settings, defaults):** Each a module under `Modules/`; all optional.
- **How it is coded:** Hooks LFGList list entries and the application dialog; uses `C_LFGList.GetSearchResultInfo/PlayerInfo/MemberCounts/EncounterInfo`; reads Raider.IO through `Plugins/RaiderIO.lua` if present.
- **Benefit to players:** Faster, better-informed sign-ups.

**Compared with Phoenix_UI** - status: **same**. Phoenix `gf.age`, `gf.roleIcons`, `gf.leaderCrown`, `gf.compact`, `gf.ownLockout`, `gf.bossesDown`, `gf.rioScore`, `gf.cancelOldest`, `gf.declined`, QueueHelper sign-up/Enter.

### Skin plugin (EllesmereUI)

- **What it does:** Re-styles PGF dialog to match EllesmereUI.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Small (450 lines), hooks PGF frames.
- **Benefit to players:** Visual consistency.

**Compared with Phoenix_UI** - status: **missing (minor)**. Phoenix GroupFinder is its own UI; a PGF skin could live in `Phoenix_UI_Skins/Packs.lua` if users keep PGF.

Ideas to adopt (original code only): P3: skin PGF's dialog when PGF is loaded.

## Verdict

Phoenix GroupFinder reaches parity with a safer design. P3 skin for PGF only.
