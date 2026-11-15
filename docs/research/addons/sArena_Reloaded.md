# sArena Reloaded (arena frames)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game v2.7.0, I:\ v2.6.7).

**Licence:** Mixed: LICENSE says MIT for most files with designated All Rights Reserved files; in this copy almost every file header says "Copyright (c) 2026 Bodify. All rights reserved." Treat as study only.

Arena enemy frames with trinket, racial, DR, dispel, interrupt, cast bar, auras, absorbs, pets and several layouts, rebuilt for Midnight's secret values.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `sArena_Reloaded` | v2.7.0 | v2.6.7 | 120105, 120100 | 74 / 45,029 |

- **Title / notes (toc):** sArena Reloaded - Enhanced Arena Frames
- **Author (toc):** Stako, "reloaded" by Bodify
- **SavedVariables:** `sArena_ReloadedDB`
- **Optional deps:** sArena, sArena_Updated2_by_sammers
- **Embedded libraries:** Libs (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 48x, `C_Timer` calls 50x.
- **Secure surface:** `SetAttribute` 15x
- **Hooks:** `HookScript` 28x, `hooksecurefunc` 53x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ARENA_OPPONENT_UPDATE`, `PLAYER_LOGIN`, `ARENA_PREP_OPPONENT_SPECIALIZATIONS`, `UNIT_TARGET`, `GROUP_ROSTER_UPDATE`, `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_FLAGS`, `SPELL_CAST_SUCCESS`, `UNIT_NAME_UPDATE`, `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`, `ADDON_LOADED`, `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_PET`, `PLAYER_SPECIALIZATION_CHANGED`, `PVP_MATCH_ACTIVE`, `PVP_MATCH_STATE_CHANGED`, `COMBAT_LOG_EVENT_UNFILTERED`, `PLAYER_TARGET_CHANGED`
- **C_ namespaces used:** `C_Timer`, `C_Spell`, `C_AddOns`, `C_ClassColor`, `C_PvP`, `C_CVar`, `C_UnitAuras`, `C_DurationUtil`, `C_SpecializationInfo`, `C_SettingsUtil`, `C_PlayerInfo`, `C_TooltipInfo`, `C_Commentator`, `C_Texture`

## Features

### Arena frames with layouts

- **What it does:** Five frames with class icon cooldown, health/power, cast bar, spec icon, pets.
- **Design (UX, settings, defaults):** Layouts: BlizzRetail, BlizzCompact, BlizzRaid, Gladiuish, Pixelated; test mode; settings search; import/export (LibSerialize + LibDeflate).
- **How it is coded:** Ace3 options; layout files set positions/sizes; `SpecFinder.lua` from `ARENA_PREP_OPPONENT_SPECIALIZATIONS`; updates on `ARENA_OPPONENT_UPDATE`; casts from `UNIT_SPELLCAST_*` including empower.
- **Benefit to players:** Readable enemy state for PvP.

**Compared with Phoenix_UI** - status: **same or better (match card, Shadowsight)**. Phoenix `Phoenix_UI_Arena` (`arena.*`: 72 keys; preset, castBar, specIcon, pets, racial, trinket, dampening, shadowsight, matchTimer, card).

### DR tracking in Midnight

- **What it does:** DR icons per category on each enemy.
- **Design (UX, settings, defaults):** Per-category toggles, sizes, grow direction.
- **How it is coded:** Uses Midnight duration objects (`C_DurationUtil.CreateDuration`) and `C_Spell.IsSpellCrowdControl`; no combat-log DR maths for retail (unverified detail).
- **Benefit to players:** Know when CC will be immune.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_Arena/DR.lua` turns on the game's own enemy DR tracking (CVar `spellDiminishPVPEnemiesEnabled`, via the ledger) and draws that data (`arena.drTray`, `arena.drStage` ...).

### Trinkets, racials, dispels, interrupts

- **What it does:** Cooldown icons for PvP trinket (e.g. 283167 / 336139), racials, dispel and interrupt.
- **Design (UX, settings, defaults):** Per-module toggles.
- **How it is coded:** `Modules/Trinkets.lua`, `Racials.lua`, `Dispels.lua`, `Interrupt.lua` from spellcast events and arena APIs.
- **Benefit to players:** Track key enemy cooldowns.

**Compared with Phoenix_UI** - status: **same**. Phoenix `arena.racial`, `arena.dispelTracker`, trinket in `State.lua`.

### Midnight absorbs and auras

- **What it does:** Absorb shields and important auras on frames.
- **Design (UX, settings, defaults):** `Absorbs_Midnight.lua`, `Auras_Midnight.lua` separate from older-client files.
- **How it is coded:** Secret values are passed straight to widgets (no maths).
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `arena.auraOrder`, `arena.auraGlow`, `arena.classAura`.

Ideas to adopt (original code only): Mirror their split of "Midnight" vs "older client" files for clarity in our Forever/retail code.

## Verdict

Parity. Phoenix adds match card and Shadowsight. No gaps.
