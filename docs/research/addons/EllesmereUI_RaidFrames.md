# EllesmereUI Raid Frames

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Party and raid frames with buff/debuff managers, click casting, pet frames, party targets, portraits, boss frames, previews. ~44k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIRaidFrames` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 36 / 43,680 |

- **Title / notes (toc):** EllesmereUI Raid & Party Frames - Incredibly light performance, modern raid and party frames with endless flexibility.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIRaidFramesDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 19x, `C_Timer` calls 37x.
- **Secure surface:** `SetAttribute` 187x, `SecureUnitButtonTemplate` 11x, `SecureGroupHeaderTemplate` 7x, `SecureActionButtonTemplate` 5x, `RegisterStateDriver` 5x, `SecureHandlerExecute` 3x
- **Hooks:** `HookScript` 34x, `hooksecurefunc` 11x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `PLAYER_TARGET_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `SPELLS_CHANGED`, `UNIT_IN_RANGE_UPDATE`, `UNIT_MAXHEALTH`, `UNIT_HEALTH`, `UNIT_HEAL_PREDICTION`, `UNIT_CONNECTION`, `UNIT_FLAGS`, `UNIT_NAME_UPDATE`, `UNIT_POWER_UPDATE`, `UNIT_DISPLAYPOWER`, `UNIT_MAX_HEALTH_MODIFIERS_CHANGED`, `PLAYER_LOGIN`, `UNIT_ENTERED_VEHICLE`, `UNIT_EXITED_VEHICLE`, `FULLSCREEN_DIALOG`, `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`, `UNIT_LEVEL`
- **C_ namespaces used:** `C_Spell`, `C_Timer`, `C_SpellBook`, `C_CurveUtil`, `C_SpecializationInfo`, `C_Item`, `C_StringUtil`, `C_CreatureInfo`, `C_Container`, `C_AddOns`, `C_Texture`, `C_IncomingSummon`, `C_UnitAuras`, `C_ClassColor`

## Features

### Buff and debuff managers

- **What it does:** Per-slot aura placement with filters (own HoTs, dispellable, boss debuffs), private auras.
- **Design (UX, settings, defaults):** Large options with live previews (party/raid/roles/sizes).
- **How it is coded:** `EUI_RaidFrames_BuffManager*.lua`, `DebuffManager.lua`, aura containers on the 12.1 engine.
- **Benefit to players:** Healers see what matters.

**Compared with Phoenix_UI** - status: **same**. Phoenix `rf.buffs`, `rf.debuffs`, `rf.corners`, `rf.privateAuras`, `rf.dispel*`, Indicators.lua.

### Click casting

- **What it does:** Built-in click-cast bindings per button/modifier.
- **Design (UX, settings, defaults):** Binding UI.
- **How it is coded:** `EUI_RaidFrames_ClickCast.lua` (~5k lines) with secure attributes.
- **Benefit to players:** No Clique needed.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_RaidFrames/ClickCast.lua` (`cc.bindings`, `cc.hovercast`).

### Pet frames, party targets, portraits

- **What it does:** Pet frames for group, target-of-party frames, portraits on party frames.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `PetFrames.lua`, `PartyTargets.lua`, `Portrait.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `rf.pets`, `rf.partyTargets` (Extra.lua).

### Forever missing buffs

- **What it does:** On WoW Forever, shows missing class buffs per member.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_RaidFrames_ForeverMissingBuffs.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix Reminders (`rm.raid`, `rm.class`).

## Verdict

Parity.
