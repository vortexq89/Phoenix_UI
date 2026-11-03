# EllesmereUI Cooldown Manager

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Restyles and re-anchors Blizzard's Cooldown Viewer (CDM) frames into custom bars, adds tracking bars, bar glows and per-spell conditions. ~39k lines. Core principle in its own words: Blizzard manages all cooldown/buff state; the addon only restyles and repositions.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUICooldownManager` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 45 / 39,452 |

- **Title / notes (toc):** EllesmereUI Cooldown Manager - A CDM replacement focused on performance, customizations and alerts.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUICooldownManagerDB`
- **Slash commands:** `/cd`, `/cdmeffects`, `/ecdm`, `/ecme`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 39x, `C_Timer` calls 56x.
- **Secure surface:** `SecureHandlerStateTemplate` 1x, `SetAttribute` 1x, `RegisterStateDriver` 1x
- **Hooks:** `hooksecurefunc` 59x, `HookScript` 12x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `UNIT_AURA`, `PLAYER_REGEN_ENABLED`, `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_USABLE`, `UNIT_SPELLCAST_SUCCEEDED`, `PLAYER_TARGET_CHANGED`, `UPDATE_BONUS_ACTIONBAR`, `UPDATE_SHAPESHIFT_FORM`, `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`, `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_REGEN_DISABLED`, `PLAYER_FOCUS_CHANGED`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, `UPDATE_STEALTH`, `SPELL_RANGE_CHECK_UPDATE`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_LOGIN`
- **C_ namespaces used:** `C_Spell`, `C_SpellBook`, `C_Timer`, `C_CooldownViewer`, `C_Item`, `C_UnitAuras`, `C_SpecializationInfo`, `C_StringUtil`, `C_NamePlate`, `C_TooltipInfo`, `C_CurveUtil`, `C_AssistedCombat`, `C_EditMode`, `C_Secrets`, `C_Container`

## Features

### Re-anchor Blizzard CDM into custom bars

- **What it does:** Essential/utility/buff icons placed in user-defined bars with shapes, borders, fonts and keybind text.
- **Design (UX, settings, defaults):** Spell picker with drag to reorder; per-spec bars; ghost bars; "always show" placeholders.
- **How it is coded:** Mixin hooks on Blizzard viewers (`EllesmereUICdmHooks.lua` "v5 mixin hook architecture"), `CollectAndReanchor` pool and sorting, spell route map (which bar a cooldown belongs to), Edit Mode lock so Blizzard does not move them back.
- **Benefit to players:** Cooldowns where the player looks, using Blizzard's secret-safe data.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_CooldownManager` (rows, presets, share string, `cdm.essential/utility/buffIcon/buffBar/custom`).

### Tracking bars (buff bars)

- **What it does:** Bars for tracked buffs with tick marks, thresholds, charge hash lines, spark, pandemic glow, stacks, decimal duration (12.1 engine-driven).
- **Design (UX, settings, defaults):** Style presets, groups per spec, sounds on gain/loss.
- **How it is coded:** `EUI_CDM_BuffBar*.lua`; durations mirror Blizzard's duration font string (secret-safe) and a 12.1 engine path for decimals.
- **Benefit to players:** Readable buff uptime.

**Compared with Phoenix_UI** - status: **same (unverified: tick marks/thresholds)**. Phoenix `cdm.buffBar`, pandemic glow (CooldownManager/Extras.lua), `uf.auraBars.*`.

Ideas to adopt (original code only): Add per-bar tick marks (e.g. pandemic 30% line) if missing. P3.

### Per-spell talent and stance conditions

- **What it does:** Show an icon only while talent X is taken / Y not taken, or hide it in a given stance page.
- **Design (UX, settings, defaults):** Rows in the spell options.
- **How it is coded:** `EllesmereUICdmTalentConditions.lua`, `EllesmereUICdmStanceBar.lua`.
- **Benefit to players:** One layout works for every build.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: no talent conditions (rg: none).

Ideas to adopt (original code only): **P2:** "Show only with talent" condition per CDM icon/bar entry (check with `C_Traits` node rank on `TRAIT_CONFIG_UPDATED`).

### Bar glows from auras

- **What it does:** Glow an action bar or CDM button when a chosen buff is active (or missing).
- **Design (UX, settings, defaults):** Glow When + extra conditions.
- **How it is coded:** `EllesmereUICdmBarGlows.lua`, `...BarGlowConditions.lua`.
- **Benefit to players:** Never miss a proc-driven button.

**Compared with Phoenix_UI** - status: **missing**. Phoenix `ab.procGlow` uses Blizzard overlay glows; no user aura-to-button glow rules.

Ideas to adopt (original code only): P3: "Glow this button while aura X" rule (secret-safe: use aura instance presence only).

### Focus kick, rotation helper icon, key-press mirror, trinkets, potions

- **What it does:** Focus interrupt bar; Blizzard Assisted Combat suggestion icon; mirror key presses on icons; trinket and dynamic potion icons.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_CDM_FocusKick.lua`, `EllesmereUICdmRotationIcon.lua` (display only, nothing registered when off), `HookPressMirror.lua`, `HookTrinkets.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `cdm.focusKick`, `cdm.assist`, `ab.assist`; trinkets on item bars.

### Sync generic entries across specs

- **What it does:** Trinket slots and items shared across chosen specs of the profile.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUICdmRPTSync.lua`.
- **Benefit to players:** Less setup per spec.

**Compared with Phoenix_UI** - status: **unverified**. Phoenix: unverified.

## Verdict

Parity on the core. P2: talent conditions per CDM entry.
