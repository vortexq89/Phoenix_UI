# EllesmereUI Data Bars

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Configurable info bars built from blocks: audio, bags, clock, crests, currency, gold, Great Vault, item level, location, micro menu, profession, spacer, spec, stats (fps/ms/durability/combat), supplies (Forever), travel, XP/rep.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIDataBars` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 19 / 11,583 |

- **Title / notes (toc):** EllesmereUI DataBars - Information bar for EllesmereUI - clock, gold, reputation and more
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIDataBarsDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 6x, `C_Timer` calls 10x.
- **Secure surface:** `SetAttribute` 49x, `SecureActionButtonTemplate` 8x, `SecureHandlerStateTemplate` 7x, `RegisterStateDriver` 6x
- **Hooks:** `HookScript` 5x, `hooksecurefunc` 2x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED`, `PORTRAITS_UPDATED`, `UNIT_PORTRAIT_UPDATE`, `PLAYER_GUILD_UPDATE`, `TOKEN_MARKET_PRICE_UPDATED`, `SHIFT_LEFT_CLICK`, `GUILD_ROSTER_UPDATE`, `BN_FRIEND_ACCOUNT_ONLINE`, `BN_FRIEND_ACCOUNT_OFFLINE`, `FRIENDLIST_UPDATE`, `PET_BATTLE_OVER`, `PET_BATTLE_CLOSE`, `ON_COOLDOWN`, `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_TARGET_CHANGED`, `GROUP_ROSTER_UPDATE`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `PLAYER_CAN_GLIDE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `UPDATE_SHAPESHIFT_FORM`
- **C_ namespaces used:** `C_CurrencyInfo`, `C_ClassTalents`, `C_Item`, `C_Container`, `C_Timer`, `C_Map`, `C_PvP`, `C_SpecializationInfo`, `C_MajorFactions`, `C_Traits`, `C_MythicPlus`, `C_WowTokenPublic`, `C_FriendList`, `C_DelvesUI`, `C_GossipInfo`

## Features

### Block bars

- **What it does:** Users build bars from blocks; each block has its own tooltip/click.
- **Design (UX, settings, defaults):** Per-slot background tint; secure blocks (micro menu, profession, hearth) prebuilt out of combat.
- **How it is coded:** One factory file per block in `Blocks/`, shared scaffolding.
- **Benefit to players:** Information at a glance.

**Compared with Phoenix_UI** - status: **same (unverified: block count)**. Phoenix `Phoenix_UI_HUD/DataBars.lua` (`db.*`), HUD extras.

Ideas to adopt (original code only): Compare block list: Crests, Great Vault, Travel (hearth + M+ teleports), Supplies. Add any missing ones (P3).

## Verdict

Parity likely; verify block list.
