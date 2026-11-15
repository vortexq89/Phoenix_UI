# EllesmereUI Unit Frames

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Player, target, focus, pet, ToT, focus target and boss frames plus player aura bars. ~33k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIUnitFrames` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 31 / 33,135 |

- **Title / notes (toc):** EllesmereUI Unit Frames - Simple unit frames with a modern visual style.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIUnitFramesDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 20x, `C_Timer` calls 34x.
- **Secure surface:** `SetAttribute` 14x, `SecureHandlerStateTemplate` 1x, `RegisterStateDriver` 1x, `SecureUnitButtonTemplate` 1x
- **Hooks:** `hooksecurefunc` 14x, `HookScript` 20x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_FACTION`, `UNIT_MAXPOWER`, `UNIT_PET`, `UNIT_HEALTH`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT`, `UNIT_ENTERED_VEHICLE`, `UNIT_EXITED_VEHICLE`, `UNIT_POWER_UPDATE`, `UNIT_MAXHEALTH`, `PORTRAITS_UPDATED`, `PLAYER_REGEN_ENABLED`, `UNIT_CLASSIFICATION_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `SOUL_FRAGMENTS_VENGEANCE`, `WHIRLWIND_STACKS`, `SWEEPING_STRIKES`, `UNIT_CONNECTION`, `UNIT_MAX_HEALTH_MODIFIERS_CHANGED`, `UNIT_DISPLAYPOWER`
- **C_ namespaces used:** `C_Timer`, `C_Spell`, `C_CurveUtil`, `C_SpecializationInfo`, `C_ClassColor`, `C_Texture`, `C_PaperDollInfo`, `C_PetInfo`, `C_Item`, `C_DurationUtil`, `C_UnitAuras`, `C_SpellBook`, `C_StringUtil`, `C_Garrison`, `C_PartyInfo`

## Features

### Frames with stock styles

- **What it does:** Blizzard-style, Classic-art and EllesmereUI styles; portraits (3D/class), threat, absorbs, class power, text tags.
- **Design (UX, settings, defaults):** Per-frame options pages and a preview.
- **How it is coded:** `EUI_UnitFrames_*` builders, engine, layout, text, portrait, castbar, absorb; Forever extras (form bar, weapon imbues).
- **Benefit to players:** Choice between stock look and modern.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_UnitFrames` (358 `uf.*` keys, styles, tags, text slots, Blizzard or Phoenix per frame).

### Player aura bars

- **What it does:** Buffs/debuffs as bars with filters, groups, custom bars, preview.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_PlayerAuraBars_*`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `uf.auraBars.*` (+ `dedupeCDM`).

### Forever weapon imbues

- **What it does:** Shows weapon enchant/imbue timers (poisons, shaman weapons) on WoW Forever.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_UnitFrames_ForeverImbues.lua`.
- **Benefit to players:** Classic players track poisons.

**Compared with Phoenix_UI** - status: **partial**. Phoenix: weapon enchant reminders exist (`rm.weaponOil`); an imbue timer on frames not found.

Ideas to adopt (original code only): P3 (Forever): imbue timer icon near the player frame.

## Verdict

Parity.
