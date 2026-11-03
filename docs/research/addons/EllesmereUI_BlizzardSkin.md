# EllesmereUI Blizzard Skin

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Themed Blizzard windows on a shared window engine (14k-line pack file), with a reworked character sheet, inspect sheet, Great Vault, group finder, chat bubbles, skyriding vigor, tooltips and a public skin API. ~38k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIBlizzardSkin` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 24 / 38,021 |

- **Title / notes (toc):** EllesmereUI Blizzard Skins+ - Clean and beautiful visual refreshes for Blizzard UI elements.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIBlizzardSkinDB`, `EllesmereUIDragonRidingDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 44x, `C_Timer` calls 60x.
- **Secure surface:** `SetAttribute` 6x, `SecureHandlerSetFrameRef` 3x, `SecureHandlerBaseTemplate` 2x, `SecureHandlerExecute` 1x, `SecureHandler` 1x
- **Hooks:** `hooksecurefunc` 210x, `HookScript` 182x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_LOGIN`, `ADDON_LOADED`, `GET_ITEM_INFO_RECEIVED`, `PLAYER_ENTERING_WORLD`, `PLAYER_EQUIPMENT_CHANGED`, `UNIT_INVENTORY_CHANGED`, `PLAYER_REGEN_DISABLED`, `PLAYER_LOGOUT`, `BAG_UPDATE_DELAYED`, `SOCKET_INFO_UPDATE`, `SPELL_UPDATE_COOLDOWN`, `MERCHANT_CLOSED`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, `PLAYER_SPECIALIZATION_CHANGED`, `SPELL_UPDATE_CHARGES`, `PLAYER_IS_GLIDING_CHANGED`, `INSPECT_READY`, `PLAYER_REGEN_ENABLED`, `ITEM_MOD_HASTE_RATING_SHORT`, `QUEST_LOG_UPDATE`, `UPDATE_UI_WIDGET`
- **C_ namespaces used:** `C_Item`, `C_Timer`, `C_Container`, `C_Texture`, `C_PaperDollInfo`, `C_PlayerInfo`, `C_CurrencyInfo`, `C_ChallengeMode`, `C_Spell`, `C_NamePlate`, `C_CVar`, `C_AddOns`, `C_MerchantFrame`, `C_MountJournal`, `C_EquipmentSet`

## Features

### Window engine and packs

- **What it does:** Style-aware shells (atlas or flat), panels, buttons, tabs for dozens of Blizzard windows.
- **Design (UX, settings, defaults):** One switch per window.
- **How it is coded:** External weak-keyed tables hold frame state so Blizzard frames are never written to (taint safety).
- **Benefit to players:** Unified look.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_Skins` (`skins.*`, 119 keys; applied and removed live).

Ideas to adopt (original code only): Their weak-keyed side table pattern matches ours; keep it.

### Character sheet rework

- **What it does:** Item level, enchants, upgrade track, sockets row, stat diminishing-returns tooltip.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `CharacterSheet.lua` (~5k lines), `SocketPanel.lua`, `DiminishingReturns.lua` (secondary/tertiary stat DR shown in tooltips).
- **Benefit to players:** Gear check at a glance.

**Compared with Phoenix_UI** - status: **partial**. Phoenix `Phoenix_UI_Skins/Gear.lua`, `skins.character`, `skins.inspect`. Stat DR tooltip: not found.

Ideas to adopt (original code only): P3: show stat diminishing returns in the character stat tooltips.

### Skyriding vigor skin

- **What it does:** Restyled vigor bar.
- **Design (UX, settings, defaults):** Textures list.
- **How it is coded:** `DragonRiding.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found (rg `vigor`: none).

Ideas to adopt (original code only): P3: vigor/skyriding bar skin.

### Mail alt list, merchant bulk buy

- **What it does:** Alt list beside Send Mail (same-faction characters); shift-click a vendor item to buy a quantity.
- **Design (UX, settings, defaults):** Opt-in.
- **How it is coded:** `MailAlts.lua`, `MerchantBulkBuy.lua`.
- **Benefit to players:** Convenience.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found.

Ideas to adopt (original code only): **P2:** mail alt list (we already store alts in Vault). P3: bulk buy dialog.

### Tooltip skin, anchor and visibility

- **What it does:** Tooltip style, cursor anchor, fixed position with mover, show modes with peek modifier, unit health strip.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_BlizzardSkin_Tooltip*.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_HUD/Tooltip.lua` (`tt.anchor`, `tt.combat`, `tt.offsetX`...).

### Public skin API

- **What it does:** Third-party addons register a skin callback.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUI.RegisterSkin(addon, fn)`.
- **Benefit to players:** Ecosystem.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Core/API.lua` + `Skins.lua` registration.

## Verdict

P2: mail alt list. Several P3 polish items.
