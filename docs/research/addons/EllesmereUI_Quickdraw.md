# EllesmereUI Quickdraw (hold-key action palette)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Hold a key, a palette (fan/arc or grid) of slots appears around the cursor, point at one, release to use it. Slots can be spells, items, mounts, toys, outfits, markers, professions.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIQuickdraw` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 13 / 10,315 |

- **Title / notes (toc):** EllesmereUI Quickdraw - Hold a keybind to open a menu of actions; point or scroll to choose, release to fire.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIQuickdrawDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 15x, `C_Timer` calls 1x.
- **Secure surface:** `SetAttribute` 177x, `SecureHandlerSetFrameRef` 19x, `SecureHandlerWrapScript` 13x, `SecureTemplate` 7x, `SecureHandlerEnterLeaveTemplate` 4x, `SecureHandlers` 3x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `UPDATE_BINDINGS`, `PLAYER_ENTERING_WORLD`, `PLAYER_SPECIALIZATION_CHANGED`, `SPELLS_CHANGED`, `UPDATE_MACROS`, `TRANSMOG_OUTFITS_CHANGED`, `RAID_TARGET_UPDATE`, `UNIT_SPELLCAST_SUCCEEDED`, `MOUNT_JOURNAL_USABILITY_CHANGED`, `MINIMAP_UPDATE_ZOOM`, `PLAYER_REGEN_DISABLED`, `BINDING_NAME_`
- **C_ namespaces used:** `C_Spell`, `C_Item`, `C_MountJournal`, `C_SpellBook`, `C_SpecializationInfo`, `C_PetJournal`, `C_TransmogOutfitInfo`, `C_Foo`, `C_ToyBox`, `C_Timer`

## Features

### Hold-to-open secure palette

- **What it does:** Like a ring menu: press, aim, release.
- **Design (UX, settings, defaults):** Nested groups, cycling markers, dynamic professions/outfits, Escape cancels.
- **How it is coded:** Fully secure: arm/claim/press/release snippets in a secure header, override bindings, geometry for claim boxes and arcs, a pointer needle; insecure fallback for non-protected actions.
- **Benefit to players:** Many actions on one key; great for mounts, toys, utility.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: none (Oracle is a typed palette, not a hold-key ring).

Ideas to adopt (original code only): P3: a secure "ring" in ActionBars. Complex secure code; plan carefully. OPie is the reference most players know.

## Verdict

P3 only; big effort.
