# TrufiGCD (recent ability icons)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** I:\ only (not installed in the game folder). toc Interface 120100 (retail), plus Vanilla/TBC/Cata/Mists/Camelot tocs.

**Licence:** MIT (Copyright (c) 2025 Mstislav Zhivodkov). Ideas and code may be reused with attribution; we still write our own.

Shows a moving queue of recently cast ability icons for you (Midnight/Forever) and for party, arena, target and focus on Classic flavours.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `TrufiGCD` | not installed | (no version line) | 120100 | 18 / 3,072 |

- **Title / notes (toc):** TrufiGCD - Player spell history on Midnight and Forever; also party, arena, target and focus history on Classic.
- **Author (toc):** not stated in the toc
- **SavedVariables:** `TrufiGCDChSave`, `TrufiGCDGlSave`
- **Slash commands:** `/tgcd`
- **Optional deps:** ButtonFacade, Masque
- **Embedded libraries:** LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 1x, `C_Timer` calls 1x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `PLAYER_ENTERING_BATTLEGROUND`, `PLAYER_ENTERING_WORLD`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_CHANNEL_STOP`, `UNIT_SPELLCAST_EMPOWER_START`, `UNIT_SPELLCAST_EMPOWER_STOP`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`
- **C_ namespaces used:** `C_Item`, `C_Spell`, `C_Container`, `C_Timer`, `C_SettingsUtil`

## Features

### Ability queue

- **What it does:** Icons slide in when you cast, move along a strip and fade.
- **Design (UX, settings, defaults):** Per-unit layout (direction, size, count, position), location filter (world/dungeon/raid/arena/bg), blocklist window, profiles copyable between characters, Masque.
- **How it is coded:** One `OnUpdate` frame drives all queues (`TrufiGCD.lua`), each `IconQueue` moves its icons by elapsed time and fades them by a hiding delay. Casts come from `UNIT_SPELLCAST_START/SUCCEEDED/CHANNEL_*/EMPOWER_*`; cancelled casts get a cross. `LocationCheck` turns the addon off by zone type.
- **Benefit to players:** Shows what you (or enemies, on Classic) just pressed; good for streams and reviewing play.

**Compared with Phoenix_UI** - status: **better**. Phoenix `Phoenix_UI_CastHistory` (`ch.*`: unit, direction, speed, blockSpells/blockItems, showCancelled, showInterrupted, empowerHeld, masque, where). Phoenix also covers party and arena units on retail where the API allows. Verified: `Phoenix_UI_CastHistory/Strip.lua` drives movement through the Ticker (8 references), no OnUpdate.

Ideas to adopt (original code only): Our rule says no `OnUpdate` outside the Ticker: CastHistory already uses the Ticker (verify). Adopt "location filter" naming and the per-character profile copy.

## Verdict

Covered and exceeded by Phoenix Cast History.
