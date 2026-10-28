# idTip (IDs in tooltips)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (12.1.4 in both)

**Licence:** No licence file or X-License line: treat as All Rights Reserved, study only.

One 640-line file that appends IDs (spell, item, NPC, quest, currency, achievement, talent, mount, pet and more) to tooltips. Every API namespace is feature-gated so a missing namespace only disables one kind.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `idTip` | 12.1.4 | 12.1.4 | 11509, 16001, 20506, 38002, 50504, 120001, 120105, 120107 | 1 / 640 |

- **Title / notes (toc):** idTip - Adds various IDs to tooltips
- **Author (toc):** silverwind
- **SavedVariables:** `idTipConfig`
- **Slash commands:** `/idtip`
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 0x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 2x, `HookScript` 1x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`
- **C_ namespaces used:** `C_PetBattles`, `C_Item`, `C_UnitAuras`, `C_PetJournal`, `C_CurrencyInfo`, `C_QuestLog`, `C_Spell`

## Features

### IDs on every tooltip kind

- **What it does:** Adds a labelled "SpellID / ItemID / NPC ID ..." line to tooltips.
- **Design (UX, settings, defaults):** Settings page through `Settings.RegisterAddOnCategory`, one checkbox per kind (`idTipConfig`), `/idtip` opens it.
- **How it is coded:** Registers one post-call for all tooltip data types with `TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, ...)`, then switches on the data type; adds hooks for hyperlinks, talents, achievement criteria and map pins where the processor does not fire. Dedupes so a line is added once (`addUnique`), and extends an existing line when the tooltip is reused. Skips work in pet battles.
- **Benefit to players:** Players, theorycrafters and addon authors get IDs without a dev tool.

**Compared with Phoenix_UI** - status: **better**. Phoenix `Phoenix_UI_HUD/TooltipIDs.lua` with 30+ keys (`tt.ids.*`: spell, item, npc, quest, currency, achievement, criteria, talent, traitNode/Entry/Definition, mount, species, visual, source, vignette, areaPoi, macro, gate, colour options, `tt.ids.copyKey`).

Ideas to adopt (original code only): Nothing to adopt; we already cover more kinds and add copy-to-clipboard.

## Verdict

Fully covered by Phoenix (`tt.ids.*`). Recommend users disable idTip to avoid double lines; consider detecting idTip in `Core/Coexist.lua` and offering to hide our duplicate kinds.
