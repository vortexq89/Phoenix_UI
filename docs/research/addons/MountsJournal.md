# MountsJournal (+ MountsJournalUI, + EllesmereUI skin)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only (not on I:\); MountsJournal and UI v12.1.14, skin v1.2.1.

**Licence:** MountsJournal: Apache 2.0 (ideas and code reusable with notice). The skin: GPL-3.0 derivative of MountsJournal_ElvUI_Skin. We write our own code.

Smart mount summoning with rules (zone, flyable, swimming, conditions, snippets), weighted random lists, pets with mounts, a richer mount journal with filters, tags and a 3D preview.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `MountsJournal` | v12.1.14 | not on I:\\ | 120105, 120107 | 29 / 12,195 |
| `MountsJournalUI` | v12.1.14 | not on I:\\ | 120105, 120107 | 55 / 18,590 |
| `MountsJournal_EllesmereUI_Skin` | v1.2.1 | not on I:\\ | 120105, 120100, 120007 | 2 / 5,625 |

- **Title / notes (toc):** MountsJournal - Improved Mounts Journal.
- **Author (toc):** sfmict
- **SavedVariables:** `MountsJournalChar`, `MountsJournalDB`
- **Slash commands:** `/dm`, `/dmount`, `/mne`, `/mount`, `/mountNoError`
- **Optional deps:** LibStub, LibThingsLoad, ChatThrottleLib, OPie
- **Embedded libraries:** ChatThrottleLib, LibStub, LibThingsLoad (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 48x, `C_Timer` calls 18x.
- **Secure surface:** `SetAttribute` 33x, `SecureBarButtonTemplate` 2x, `SecureActionButtonTemplate` 2x, `SecureHandlerShowHideTemplate` 2x, `SecureHandlerWrapScript` 1x, `SecureHandlerClickTemplate` 1x
- **Hooks:** `hooksecurefunc` 41x, `HookScript` 141x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `ADDON_INIT`, `PLAYER_STARTED_MOVING`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_AURA`, `MOUNT_JOURNAL_USABILITY_CHANGED`, `CALENDAR_UPDATE_EVENT_LIST`, `RESTRICTION_CHANGED`, `COMPANION_UPDATE`, `ITEM_UNLOCKED`, `ADDON_LOADED`, `PLAYER_REGEN_DISABLED`, `MOUNTED_UPDATE`, `CHAT_MSG_CHANNEL`, `CHAT_MSG_WHISPER`, `PLAYER_LOGIN`, `PLAYER_LOGOUT`, `UPDATE_INVENTORY_DURABILITY`, `ADDON_RESTRICTION_STATE_CHANGED`, `NEW_WMO_CHUNK`, `ZONE_CHANGED`
- **C_ namespaces used:** `C_PetJournal`, `C_Spell`, `C_MountJournal`, `C_Calendar`, `C_Item`, `C_Secrets`, `C_AddOns`, `C_Map`, `C_Timer`, `C_SpecializationInfo`, `C_UnitAuras`, `C_EncodingUtil`, `C_ChatInfo`, `C_BattleNet`, `C_Container`, `C_TransmogOutfitInfo`, `C_ClassColor`, `C_Minimap`, `C_TradeSkillUI`, `C_SpellBook`, `C_EquipmentSet`, `C_FriendList`

## Features

### Rule-based summon

- **What it does:** One keybind/macro chooses the right mount: flying, ground, swimming, per zone, with conditions and Lua snippets.
- **Design (UX, settings, defaults):** Rule editor UI with conditions (class, zone, map group, flyable, advanced flyable...), weighted chance, per profile.
- **How it is coded:** `components/Conditions.lua` evaluates rule tables; `Actions.lua` offers random-mount actions; `C_MountJournal.SummonByID`, `IsFlyableArea`, `IsAdvancedFlyableArea`; snippets run in a sandbox env (`SnippetEnv.lua`).
- **Benefit to players:** Never pick the wrong mount.

**Compared with Phoenix_UI** - status: **missing**. Phoenix Oracle can summon mounts by name (`Phoenix_UI_Oracle/Oracle.lua`). No rule-based summon.

Ideas to adopt (original code only): P3: a small "smart mount" item in the Oracle palette (flyable -> favourite flyer, water -> swimmer, else ground) with an option list. Original code.

### Journal UI upgrades

- **What it does:** Filters (sources, families, factions, expansions, rarity), tags, custom order, inspect target mount.
- **Design (UX, settings, defaults):** -
- **How it is coded:** LibSFDropDown menus, ScrollBox sorting.
- **Benefit to players:** Collectors manage hundreds of mounts.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix: collections skin only.

## Verdict

P3 smart mount only.
