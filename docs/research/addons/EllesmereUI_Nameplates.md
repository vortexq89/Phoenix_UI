# EllesmereUI Nameplates

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Enemy and friendly nameplates with engine-driven aura groups, cast bar with kick tick, threat, quest mobs, overlays and a cast overlay. ~18k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUINameplates` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 19 / 18,036 |

- **Title / notes (toc):** EllesmereUI Nameplates - Clean, lightweight nameplates with endless customization.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUINameplatesDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 23x, `C_Timer` calls 17x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 17x, `HookScript` 2x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_TARGET_CHANGED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `INCLUDE_NAME_PLATE_ONLY`, `PLAYER_REGEN_ENABLED`, `PLAYER_SPECIALIZATION_CHANGED`, `DISPLAY_SIZE_CHANGED`, `UNIT_NAME_UPDATE`, `UNIT_FACTION`, `RAID_TARGET_UPDATE`, `PLAYER_REGEN_DISABLED`, `ZONE_CHANGED_NEW_AREA`, `BREWMASTER_STAGGER`, `INSANITY_BAR`, `UNIT_AURA`, `UNIT_HEALTH`, `UPDATE_SHAPESHIFT_FORM`, `GLOBAL_MOUSE_UP`, `CROWD_CONTROL`, `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_USABLE`, `SOUL_FRAGMENTS_VENGEANCE`
- **C_ namespaces used:** `C_NamePlate`, `C_Timer`, `C_CurveUtil`, `C_Spell`, `C_NamePlateManager`, `C_ClassColor`, `C_SpecializationInfo`, `C_UnitAuras`, `C_TooltipInfo`, `C_Garrison`, `C_PartyInfo`, `C_QuestLog`, `C_CVar`, `C_PlayerInfo`, `C_Texture`

## Features

### Engine aura containers on plates

- **What it does:** Three groups per plate: your debuffs, enemy important buffs, crowd control.
- **Design (UX, settings, defaults):** -
- **How it is coded:** 12.1 aura containers rendered by the engine.
- **Benefit to players:** Secret-safe auras.

**Compared with Phoenix_UI** - status: **same**. Phoenix `np.auras`, aura lanes.

### Cast bar with kick tick and cast overlay

- **What it does:** Shows where your interrupt comes off cooldown on the cast; optional "lift" that reparents each plate's cast bar into a small container under UIParent so it draws above other plates.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_Nameplates_Cast.lua`, `EllesmereUINameplates_CastOverlay.lua`.
- **Benefit to players:** Interrupts land; casts are not hidden by stacked plates.

**Compared with Phoenix_UI** - status: **same; no cast lift**. Phoenix `np.cast`, `np.interrupt.*`, "kicked by" name on interrupt (`Phoenix_UI_Nameplates/Extras.lua` `OnInterrupted`).

Ideas to adopt (original code only): P3: cast lift option for dense pulls (check secure/taint implications: plates are not protected, but test).

### Debuff colours, threat gap, near-aggro, low-health overlays

- **What it does:** Tint plate by your debuff, show threat gap number, overlays.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `DebuffColors.lua` (credited technique), `Overlays.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `np.colors`, threat colours, execute indicator.

### Friendly plates in delves, faction badge, class power on target plate

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUINameplatesFriendly.lua`, `Faction.lua`, `ClassPower.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `np.friendly`, `np.resource`.

## Verdict

Parity.
