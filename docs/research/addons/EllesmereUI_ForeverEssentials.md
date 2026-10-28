# EllesmereUI Forever Essentials

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

WoW Forever (Classic) tools: active form icon, classic spellbook and talents windows, fishing helpers, flight timer, gathering skill in tooltips, junk window, loot feed, macro manager, map fade/reveal/travel pins, pet summon, quest reward value, simplified stats, threat meter, auto uprank, zone levels.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIForeverEssentials` | 9.6.8 | 9.6.1 | 16001 | 25 / 10,597 |

- **Title / notes (toc):** EllesmereUI Forever Essentials - Essential tools for WoW Forever.
- **Author (toc):** Ellesmere
- **Slash commands:** `/euimacros`, `/euitm`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 4x, `C_Timer` calls 14x.
- **Secure surface:** `SetAttribute` 16x, `SecureHandlerClickTemplate` 3x, `SecureActionButtonTemplate` 2x, `SecureFrameTemplate` 2x, `SecureHandlerShowHideTemplate` 1x
- **Hooks:** `HookScript` 13x, `hooksecurefunc` 11x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `PLAYER_REGEN_DISABLED`, `UNIT_SPELLCAST_CHANNEL_STOP`, `UNIT_THREAT_LIST_UPDATE`, `UNIT_THREAT_SITUATION_UPDATE`, `PLAYER_FOCUS_CHANGED`, `PLAYER_REGEN_ENABLED`, `MODIFIER_STATE_CHANGED`, `SPELL_UPDATE_COOLDOWN`, `GET_ITEM_INFO_RECEIVED`, `UNIT_SPELLCAST_STOP`, `UNIT_FLAGS`, `GROUP_ROSTER_UPDATE`, `PLAYER_TARGET_CHANGED`, `UNIT_PET`, `UNIT_TARGET`, `PLAYER_ENTERING_WORLD`, `UPDATE_BINDINGS`, `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `PLAYER_SOFT_INTERACT_CHANGED`, `PLAYER_CONTROL_GAINED`
- **C_ namespaces used:** `C_Map`, `C_Traits`, `C_Timer`, `C_Spell`, `C_SpellBook`, `C_Item`, `C_Container`, `C_PetJournal`, `C_Reputation`, `C_AddOns`, `C_ClassTalents`, `C_TaxiMap`, `C_SkillInfo`, `C_SpecializationInfo`, `C_CVar`

## Features

### Map tools

- **What it does:** Reveal unexplored areas, travel pins by zoom, zone level ranges on continent maps, fade map while moving.
- **Design (UX, settings, defaults):** Each its own setting.
- **How it is coded:** Static map data tables (overlay tiles, travel points) and the `mapFade` CVar.
- **Benefit to players:** Classic navigation.

**Compared with Phoenix_UI** - status: **missing**. Phoenix Forever: none of these (rg: none).

Ideas to adopt (original code only): P2 (Forever): zone levels and map reveal are the most used. Data must be ours (from client map art IDs, which are game data).

### Auto uprank

- **What it does:** When a new rank is learned, replace lower ranks on bars.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Uprank.lua` swaps action slots out of combat and reports in chat.
- **Benefit to players:** Classic quality of life.

**Compared with Phoenix_UI** - status: **missing**. Phoenix Skins/Forever has "Spell ranks (Forever)" setting (PR #58); auto uprank: unverified. rg found only the rank-line *display* setting (`foreverRanks` in `Phoenix_UI_Skins/Forever.lua`), no auto uprank.

Ideas to adopt (original code only): P2 (Forever) if missing.

### Gathering skill, quest reward value, simplified stats, flight timer, fishing, pet summon, threat meter, loot feed, junk window

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** One file each.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **partial**. Phoenix Forever: flight timer, fishing helper, pet happiness; others missing.

Ideas to adopt (original code only): P3 (Forever): quest reward value marker, gathering skill in tooltip.

## Verdict

Forever gaps are real but Forever-only; P2 for zone levels, map reveal, uprank.
