# EllesmereUI Quality of Life

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Many small features: upgrade calculator, centre alerts, auto combat logging, battle res, Bloodlust/Sated tracker, cursor ring, `/keys`, movement cooldown alert, raid tools band, self combat text, Shifter (move Blizzard panels), teleport prompt, `/way`.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIQoL` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 15 / 19,678 |

- **Title / notes (toc):** EllesmereUI Quality of Life - Lightweight quality of life tools and enhancements.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIQoLDB`
- **Slash commands:** `/eec`, `/ekeys`, `/euic`, `/euiraid`, `/euiway`, `/key`, `/keys`, `/upgcalc`, `/way`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 56x, `C_Timer` calls 65x.
- **Secure surface:** `SetAttribute` 152x, `SecureActionButtonTemplate` 8x, `SecureHandlerExecute` 7x, `SecureHandlerClickTemplate` 4x, `RegisterStateDriver` 4x, `SecureHandlerWrapScript` 3x
- **Hooks:** `HookScript` 32x, `hooksecurefunc` 30x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `ADDON_LOADED`, `PLAYER_REGEN_DISABLED`, `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_SPECIALIZATION_CHANGED`, `UNIT_SPELLCAST_STOP`, `UNIT_AURA`, `MERCHANT_CLOSED`, `UNIT_SPELLCAST_CHANNEL_STOP`, `MPLUS_AND_RAID`, `UNIT_ENTERED_VEHICLE`, `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`, `BAG_UPDATE_DELAYED`, `BAG_UPDATE`, `CINEMATIC_STOP`, `UPDATE_MOUSEOVER_UNIT`, `GROUP_ROSTER_UPDATE`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_FAILED`, `UNIT_SPELLCAST_INTERRUPTED`
- **C_ namespaces used:** `C_Timer`, `C_Spell`, `C_Item`, `C_Container`, `C_Map`, `C_ChallengeMode`, `C_MountJournal`, `C_PetJournal`, `C_UnitAuras`, `C_CurrencyInfo`, `C_ItemUpgrade`, `C_AddOns`, `C_ToyBoxInfo`, `C_PartyInfo`, `C_GossipInfo`

## Features

### Upgrade calculator

- **What it does:** Plans gear upgrades: crests and gold needed per slot.
- **Design (UX, settings, defaults):** Frame `EUIUpgCalcFrame`, `/euic`.
- **How it is coded:** `EUI_UpgradeCalc.lua` (data tables + logic + UI).
- **Benefit to players:** Plan the week's crests.

**Compared with Phoenix_UI** - status: **partial**. Phoenix tooltip lines `tt.lines.upgrade`, `tt.lines.crestCalc`, `tt.crestCost`; no planner window.

Ideas to adopt (original code only): P3: planner window listing every equipped item's next upgrade and total crests.

### Movement cooldown alert

- **What it does:** Shows your spec's mobility spell cooldown, plus two more trackers.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUIQoL_MovementAlert.lua` (~2.6k lines).
- **Benefit to players:** Know when you can dash.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found.

Ideas to adopt (original code only): P3: can be a CDM preset ("Mobility" row) rather than a new feature.

### Keystones via LibKeystone

- **What it does:** `/keys` shows party keystones received through LibKeystone, which BigWigs and DBM users also send.
- **Design (UX, settings, defaults):** -
- **How it is coded:** LibKeystone prefix `LibKS`, message "level,mapID,rating", "R" to request.
- **Benefit to players:** Works with players who do not use the same UI.

**Compared with Phoenix_UI** - status: **worse**. Phoenix `/keys` uses its own prefix `PUIKEYS` (`Phoenix_UI_Ascent/Keystones.lua`), so it only sees other Phoenix users.

Ideas to adopt (original code only): **P1:** also speak the LibKeystone wire format (send and receive `LibKS`) in our own code, so `/keys` shows BigWigs/DBM/EllesmereUI users' keys. Protocol interop only; no library code copied.

### Shifter (move Blizzard panels)

- **What it does:** Shift+drag to move a Blizzard panel permanently, Ctrl+drag for a temporary move.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUIQoL_Shifter.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **missing**. Phoenix: missing (see MoveAny).

Ideas to adopt (original code only): P2 (same item as MoveAny).

### Teleport prompt

- **What it does:** On joining an LFG group for a dungeon you have the teleport for, a popup offers the teleport.
- **Design (UX, settings, defaults):** Small square popup.
- **How it is coded:** `EllesmereUIQoL_TeleportPrompt.lua` (secure spell button).
- **Benefit to players:** Faster M+ start.

**Compared with Phoenix_UI** - status: **partial**. Phoenix has M+ teleports on item bar 5 (PR #70); no prompt.

Ideas to adopt (original code only): P3: prompt on `LFG_LIST_JOINED_GROUP` with a secure button.

### Bloodlust/Sated tracker, battle res icon

- **What it does:** Icon with Sated timer; brez pool icon (polls `GetSpellCharges(20484)`).
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `ascent.brLust`, item bar battle res (PR #66).

### Cursor ring, alerts, auto logging, self combat text, waypoint

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `cursor.*`, Spark, `flow.combatLog`, `Core/Waypoint.lua` (`way.*`).

## Verdict

**P1: LibKeystone interop.** P2: Shifter. Others P3.
