# EllesmereUI Bags

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

All-in-one bags and bank with grid, list and compact views, categories, pin/assign modes, junk marker and quick actions. ~17k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIBags` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 16 / 16,977 |

- **Title / notes (toc):** EllesmereUI Bags - A beautiful visual refresh of Blizzard Bags with intuitive organization.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIBagsDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 36x, `C_Timer` calls 23x.
- **Secure surface:** `SetAttribute` 6x, `SecureActionButtonTemplate` 2x
- **Hooks:** `HookScript` 48x, `hooksecurefunc` 16x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `BAG_UPDATE`, `PLAYER_REGEN_DISABLED`, `FULLSCREEN_DIALOG`, `PLAYER_REGEN_ENABLED`, `ITEM_LOCK_CHANGED`, `BAG_UPDATE_DELAYED`, `CURSOR_CHANGED`, `EQUIPMENT_SETS_CHANGED`, `BANKFRAME_CLOSED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `INVTYPE_RANGED`, `MODIFIER_STATE_CHANGED`, `INVENTORY_SEARCH_UPDATE`, `CURRENCY_DISPLAY_UPDATE`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`, `GOSSIP_CLOSED`, `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`, `INVTYPE_CHEST`, `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`
- **C_ namespaces used:** `C_Container`, `C_Item`, `C_Bank`, `C_Timer`, `C_CurrencyInfo`, `C_PlayerInteractionManager`, `C_EquipmentSet`, `C_ChallengeMode`, `C_TooltipInfo`, `C_Spell`, `C_NewItems`, `C_Cursor`, `C_SpellBook`

## Features

### Three views and categories

- **What it does:** Grid, list (one row per item, column headers) and compact (blocks per category).
- **Design (UX, settings, defaults):** Categories from `Enum.ItemClass` IDs (locale-safe); rename, reorder, group; auto-size grows while open.
- **How it is coded:** Secure item-slot factory, pooled slot data with saved order.
- **Benefit to players:** Find items fast.

**Compared with Phoenix_UI** - status: **same**. Phoenix Vault (`vault.view`, `vault.rules`, `vault.sections`, `vault.listColumns`, `vault.compactSize`, custom rules).

### Quick actions

- **What it does:** A header toggle dims every item except those a known spell works on (disenchant, prospect, mill, lockpick), then click to use.
- **Design (UX, settings, defaults):** Off by default.
- **How it is coded:** `EllesmereUIBags_QuickActions.lua`.
- **Benefit to players:** Fast profession processing.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found.

Ideas to adopt (original code only): **P3:** "Process" mode in Vault (secure spell-on-item buttons prepared out of combat).

### Junk marker, sell junk, reagent window, gold ledger

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_Bags_Select.lua`, `Footer.lua`, shared gold ledger in core.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `vault.junkList`, `vault.autoSell`, `vault.goldHistory`, Bank.lua.

## Verdict

Parity; P3 quick actions.
