# EllesmereUI Damage Meters

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Damage meter windows on Blizzard's `C_DamageMeter` data (up to 5), with breakdown tooltip, combat timer, Forever threat type and spell history. ~9k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIDamageMeters` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 12 / 9,394 |

- **Title / notes (toc):** EllesmereUI Damage Meters - Lightweight damage meters with simple but powerful customization.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIDamageMetersDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 16x, `C_Timer` calls 26x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 18x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_DISABLED`, `PLAYER_SPECIALIZATION_CHANGED`, `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_LOGIN`, `UPDATE_BINDINGS`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `GROUP_ROSTER_UPDATE`, `ADDON_RESTRICTION_STATE_CHANGED`, `UNIT_FLAGS`, `ENCOUNTER_START`, `ENCOUNTER_END`, `ZONE_CHANGED_NEW_AREA`, `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `DAMAGE_METER_RESET`, `DAMAGE_METER_COMBAT_SESSION_UPDATED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED`, `UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_FAILED`
- **C_ namespaces used:** `C_DamageMeter`, `C_Timer`, `C_Spell`, `C_DeathRecap`, `C_PartyInfo`, `C_Item`, `C_RestrictedActions`, `C_PvP`, `C_Texture`, `C_AddOns`

## Features

### Meter windows on C_DamageMeter

- **What it does:** Up to five windows; zero Blizzard frame hooks; all settings live.
- **Design (UX, settings, defaults):** Stock looks (Blizzard, Classic, Forever); context menu per window.
- **How it is coded:** Shared refresh ticker; `C_DamageMeter` sessions; breakdown tooltip with hover poll.
- **Benefit to players:** Meters that work in Midnight.

**Compared with Phoenix_UI** - status: **same**. Phoenix Embers (up to four windows `embers.w1..w4`, breakdown, death recap, best-pull compare, report).

### Threat meter type (Forever)

- **What it does:** Threat as a meter type.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUIDamageMeters_ForeverThreat.lua` + Forever Essentials data.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **partial**. Phoenix `embers.threatWarn`, threat in UF; Forever threat meter not found.

Ideas to adopt (original code only): P3 (Forever).

## Verdict

Parity.
