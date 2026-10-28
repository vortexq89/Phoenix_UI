# MoveAny (move, scale and hide Blizzard frames)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (game 1.13.24, I:\ 1.13.22)

**Licence:** All Rights Reserved (Copyright (c) 2026 D4KiR). Study only.

Lets the player move, scale, fade and hide almost any Blizzard HUD element, with per-element widgets in its own edit mode. Uses D4Lib.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `MoveAny` | 1.13.24 | 1.13.22 | 120105 | 29 / 16,247 |

- **Title / notes (toc):** MoveAny by D4KiR - MoveAny is an add-on that lets you unlock and move user interface elements
- **Author (toc):** D4KiR
- **SavedVariables:** `MATAB`, `MATABPC`
- **Embedded libraries:** D4Lib, buffutils.lua, durationtext.lua, math.lua, profiler.lua (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 12x, `C_Timer` calls 11x.
- **Secure surface:** `SetAttribute` 9x, `SecureActionButtonTemplate` 2x, `SecureHandlerStateTemplate` 1x, `RegisterStateDriver` 1x
- **Hooks:** `HookScript` 28x, `hooksecurefunc` 222x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `UNIT_AURA`, `PLAYER_REGEN_ENABLED`, `GAMETOOLTIP_ONCURSOR`, `LID_RIGHTCLICKFOROPTIONS`, `PLAYER_REGEN_DISABLED`, `UPDATE_BONUS_ACTIONBAR`, `LID_LOCKEDWINDOWS`, `ADDON_LOADED`, `LID_ANCHOR`, `LID_SPACING`, `LID_WIDTH`, `LID_CASTINGBAR`, `LID_ISENABLEDINEDITMODE`, `LID_LANGUAGE`, `LID_IMPORT`, `LID_RENAME`, `LID_QUESTTRACKER`, `UNIT_EXITED_VEHICLE`, `PET_BATTLE_CLOSE`, `PET_BATTLE_OPENING_DONE`, `LID_SLASHMOVE`
- **C_ namespaces used:** `C_Widget`, `C_Timer`, `C_Texture`, `C_ChatInfo`, `C_PetJournal`, `C_PetBattles`, `C_EditMode`, `C_Container`

## Features

### Move/scale any HUD element

- **What it does:** Drag handles for ~40 element groups (`ele/*.lua`: action bars, arena frames, bag bar, buffs, debuffs, micro menu, minimap, pet/stance bars, party frames...).
- **Design (UX, settings, defaults):** Toggle per element, scale slider, alpha (`alpha.lua`), hide panel. Works beside Edit Mode.
- **How it is coded:** Heavy use of `hooksecurefunc` (260x) to re-apply position after Blizzard moves a frame, `SetUserPlaced` (50x) and `SetMovable` (43x), `SetScale` (97x). Only 1 state driver.
- **Benefit to players:** Customise the stock UI without replacing it.

**Compared with Phoenix_UI** - status: **better (taint-safer, more elements)**. Phoenix `Core/Movers.lua`: ~130 Blizzard HUD elements appear as movers in Studio when "Blizzard elements" is on (off at first install). Phoenix never reparents or replaces a method, and re-asserts with a secure-safe path.

Ideas to adopt (original code only): Check that frames which Blizzard re-anchors in combat are queued through `Core/CombatQueue.lua`, which MoveAny handles by hooks.

### Move Blizzard windows (moveframes.lua)

- **What it does:** Drag any panel (character, spellbook, etc.).
- **Design (UX, settings, defaults):** Optional; remembers positions.
- **How it is coded:** `SetMovable` + `RegisterForDrag` on panels, saving offsets.
- **Benefit to players:** Windows where you want them.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: no general "drag any Blizzard window" feature was found (rg `SetMovable(true)` only hits our own frames). EllesmereUI QoL "Shifter" and WindTools "MoveFrames" also have it.

Ideas to adopt (original code only): Add a Skins option "Move Blizzard windows": Shift+drag to move permanently, Ctrl+drag for this session only (idea seen in EllesmereUI Shifter). Hook-only, no SetPoint in combat on protected panels. **P2**

## Verdict

Phoenix covers HUD movers better. Missing: moving Blizzard windows (P2).
