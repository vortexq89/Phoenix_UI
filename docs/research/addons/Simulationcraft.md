# Simulationcraft (SimC export)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (game 12.1.5-03, I:\ 12.1.5-02)

**Licence:** Public domain (Unlicense text in LICENSE). We may reuse ideas and even code, but we keep our own implementation for consistency.

Builds the SimC profile string (character, talents, gear with bonus IDs, bags, catalyst/upgrade currencies, weekly rewards) and shows it in a copy box.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `Simulationcraft` | 12.1.5-03 | 12.1.5-02 | 120100, 120105, 16001 | 6 / 2,758 |

- **Title / notes (toc):** Simulationcraft - Constructs SimC export strings
- **Author (toc):** Theck, navv_, seriallos
- **SavedVariables:** `SimulationCraftDB`
- **Embedded libraries:** AceAddon-3.0, AceConsole-3.0, AceDB-3.0, AceEvent-3.0, CallbackHandler-1.0, LibDBIcon-1.0, LibDataBroker-1.1, LibRealmInfo, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 2x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 2x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `SPELL_CONFIRMATION_PROMPT`, `BONUS_ROLL_RESULT`
- **C_ namespaces used:** `C_SpecializationInfo`, `C_PetInfo`, `C_Item`, `C_ItemUpgrade`, `C_Container`, `C_MythicPlus`, `C_UnitAuras`, `C_SkillInfo`, `C_CurrencyInfo`, `C_SeasonInfo`, `C_AddOns`, `C_PlayerInteractionManager`, `C_Timer`, `C_SpellBook`, `C_DateAndTime`

## Features

### Profile string export

- **What it does:** `/simc` opens a window with a full SimC profile to paste into Raidbots.
- **Design (UX, settings, defaults):** Options: `nobags`, merge, links; a Forever path exports legacy talents, pet and stats.
- **How it is coded:** Ace3 addon. Reads gear with `C_Item`/item links and bonus IDs, talents via `C_Traits` (plus extra trait systems such as "omnium" talents by systemID), catalyst/upgrade currencies via `C_CurrencyInfo` and `C_ItemUpgrade`, bags via `C_Container`, Great Vault via weekly reward APIs. Text is assembled line by line and shown in an edit box.
- **Benefit to players:** The standard way to sim gear; required for Raidbots.

**Compared with Phoenix_UI** - status: **same (unverified parity)**. Phoenix `Phoenix_UI_Wisdom/SimC.lua` (`wisdom.simc`, `wisdom.simcBags`).

Ideas to adopt (original code only): Diff our output against SimC's on the same character in game: trait systems beyond class talents (systemID list), catalyst currencies and upgrade achievements are easy to miss. Since SimC is public domain, its field list can be used as a checklist.

## Verdict

Phoenix has it; verify field parity in game. Low priority.
