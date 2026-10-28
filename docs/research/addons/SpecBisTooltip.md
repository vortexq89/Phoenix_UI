# SpecBisTooltip

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only (not on I:\), 1.0.14.

**Licence:** All Rights Reserved (Copyright (c) 2026 D4KiR). Study only; the BiS data must not be copied.

Shows "Best in Slot for <spec>" on item tooltips from a large bundled data table (`data.lua`, ~70k lines) with sources, plus a Forever (Classic) pool.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `SpecBisTooltip` | 1.0.14 | not on I:\\ | 120105 | 29 / 55,177 |

- **Title / notes (toc):** SpecBisTooltip by D4KiR - Shows a list of the best specializations for specific dungeons/raids.
- **Author (toc):** D4KiR
- **SavedVariables:** `SBTTAB`, `SBTTABPC`
- **Embedded libraries:** D4Lib (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 0x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 2x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `LID_BISTRINKETX`, `LID_YOURSPEC`, `LID_BISPVESODX`, `LID_PREBISPVESODX`, `INVTYPE_TRINKET`, `LID_BISPVEPHASEX`, `LID_PREBISPVEPHASEX`, `LID_NOOTHERCLASSNEEDSTHIS`, `LID_NOOTHERSPECNEEDSTHIS`, `LID_SOURCE`, `INVTYPE_FINGER`, `INVTYPE_WEAPON`, `INVTYPE_2HWEAPON`, `INVTYPE_WEAPONMAINHAND`, `INVTYPE_WEAPONOFFHAND`, `INVTYPE_HOLDABLE`, `LID_OTHERCLASSES`, `LID_OTHERSPECS`, `LID_CATALYSTFROM`, `LID_OTHERCLASSESMAYALSO`, `PLAYER_LOGIN`, `INVTYPE_HEAD`
- **C_ namespaces used:** `C_Seasons`

## Features

### BiS line on tooltips

- **What it does:** Tooltip line naming the specs for which the item is BiS, with source (raid/dungeon/crafted).
- **Design (UX, settings, defaults):** Settings for which specs (own, all), colours.
- **How it is coded:** `TooltipDataProcessor` post-call looks up itemID in the per-build BiS pool; Forever uses a "CLASSIC" pool and maps druid specs.
- **Benefit to players:** Quick gearing guidance.

**Compared with Phoenix_UI** - status: **different approach**. Phoenix Wisdom scores items by stat weights and shows an upgrade star (`wisdom.tooltip`, `wisdom.star`, `wisdom.weights`). No BiS lists.

Ideas to adopt (original code only): P3: allow importing a user-supplied BiS list (item IDs per slot) into Wisdom from a share string, instead of shipping third-party data.

## Verdict

Phoenix Wisdom covers the need differently. P3 import of user BiS lists.
