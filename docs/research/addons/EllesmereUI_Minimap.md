# EllesmereUI Minimap

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Minimap skin with an addon-button flyout, custom indicators (Great Vault, M+ portal), friends and calendar tooltips with lockouts.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIMinimap` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 10 / 6,867 |

- **Title / notes (toc):** EllesmereUI Minimap - A new age minimap with clean styling and square layout options.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIMinimapDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 8x, `C_Timer` calls 19x.
- **Secure surface:** `SetAttribute` 6x, `RegisterStateDriver` 3x, `SecureActionButtonTemplate` 2x, `SecureHandlerStateTemplate` 1x, `SecureTemplate` 1x
- **Hooks:** `hooksecurefunc` 21x, `HookScript` 26x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED_INDOORS`, `ADDON_LOADED`, `GLOBAL_MOUSE_DOWN`, `PLAYER_LOGIN`, `CVAR_UPDATE`, `ZONE_CHANGED`, `PLAYER_REGEN_ENABLED`, `PLAYER_DIFFICULTY_CHANGED`, `GROUP_ROSTER_UPDATE`, `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`, `DIEL_CYCLE_CHANGED`
- **C_ namespaces used:** `C_Timer`, `C_Texture`, `C_DateAndTime`, `C_FriendList`, `C_PartyInfo`, `C_AddOns`, `C_ChallengeMode`, `C_WeeklyRewards`, `C_Map`, `C_PvP`, `C_CraftingOrders`, `C_BattleNet`, `C_CreatureInfo`, `C_UIWidgetManager`, `C_GameRules`

## Features

### Button flyout and indicators

- **What it does:** Collects addon buttons into a flyout grid; Great Vault button with tooltip; M+ portal button.
- **Design (UX, settings, defaults):** Blacklists, grow direction.
- **How it is coded:** `EUI_Minimap_Buttons.lua`, `Flyout.lua`, `Indicators.lua`.
- **Benefit to players:** Tidy minimap.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_HUD/ButtonBin.lua` (`mm.bin.*`), `mm.extra.indicators`, `mm.extra.friends`.

### Calendar tooltip with lockouts

- **What it does:** Hover the calendar to see saved lockouts.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_Minimap_Tooltips.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **unverified**. Phoenix `rf.lockouts`? lockouts appear in ActionBars/Skins (unverified for minimap).

Ideas to adopt (original code only): P3: lockout list on clock/calendar hover.

## Verdict

Parity.
