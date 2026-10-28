# EllesmereUI Mythic Timer (Mythic+ tools)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Mythic+ tools: kick tracker (bars and nameplate icons), run summary with per-character history (`/ov`), target/focus cast bars and **targeted spell bars**.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIMythicTimer` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 8 / 14,741 |

- **Title / notes (toc):** EllesmereUI Mythic+ Tools - A simple Mythic+ timer with full tracking customizations.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIMythicRunsDB`, `EllesmereUIMythicTimerDB`
- **Slash commands:** `/euikt`, `/euimplus`, `/ov`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 14x, `C_Timer` calls 17x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 3x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `GROUP_ROSTER_UPDATE`, `CHALLENGE_MODE_START`, `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, `RAID_TARGET_UPDATE`, `REMAINING_TOTAL`, `INSPECT_READY`, `UNIT_SPELLCAST_INTERRUPTED`, `UNIT_SPELLCAST_CHANNEL_STOP`, `UNIT_SPELLCAST_EMPOWER_STOP`, `PLAYER_REGEN_DISABLED`, `DAMAGE_METER_RESET`, `ADDON_RESTRICTION_STATE_CHANGED`, `PLAYER_TARGET_CHANGED`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_RESET`, `UNIT_SPELLCAST_INTERRUPTIBLE`, `UNIT_SPELLCAST_NOT_INTERRUPTIBLE`, `UNIT_SPELLCAST_SUCCEEDED`, `CHAT_MSG_ADDON`
- **C_ namespaces used:** `C_ChallengeMode`, `C_Spell`, `C_Timer`, `C_Item`, `C_CurveUtil`, `C_Traits`, `C_ClassColor`, `C_DamageMeter`, `C_DurationUtil`, `C_SpecializationInfo`, `C_ChatInfo`, `C_PaperDollInfo`, `C_ScenarioInfo`, `C_RestrictedActions`, `C_NamePlate`

## Features

### Kick tracker

- **What it does:** Who kicked what and when each member's interrupt is back; bars per member and an icon on the kicked enemy's plate.
- **Design (UX, settings, defaults):** Where-to-show filter shared by all tools.
- **How it is coded:** `KickEngine.lua` (data), `KickBars.lua`, `KickPlates.lua`.
- **Benefit to players:** Interrupt rotation without voice chat.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_RaidFrames/PartyCD.lua` (`pcd.cat.interrupt`), "kicked by" on nameplates, `ascent.kicks`.

### Targeted spell bars

- **What it does:** One movable group of cast bars, one per enemy currently casting **at you**.
- **Design (UX, settings, defaults):** Placeable via unlock mode.
- **How it is coded:** `EUI_MythicTimer_TargetedSpellBars.lua` replicates the nameplate cast display per casting plate.
- **Benefit to players:** React to casts on you in big pulls.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: not found (rg: none).

Ideas to adopt (original code only): **P2:** "Casts on me" list in Nameplates/Ascent: for each plate casting with target == player (use the engine's secret-safe target check), show a bar. Needs in-game check of what Midnight exposes.

### Run summary and history

- **What it does:** Overview per party member after a run, plus history of finished runs.
- **Design (UX, settings, defaults):** Nothing built until enabled.
- **How it is coded:** `RunSummary.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `ascent.summary`, `ascent.records`.

## Verdict

P2: targeted spell bars.
