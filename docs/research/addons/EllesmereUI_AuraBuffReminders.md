# EllesmereUI Aura/Buff Reminders

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Clickable reminders for raid buffs, auras and consumables, plus talent reminders, beacon reminders and a ready-check mana warning. ~8k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIAuraBuffReminders` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 13 / 7,877 |

- **Title / notes (toc):** EllesmereUI AuraBuff Reminders - Simple raid buff, auras, consumables and talent reminders.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIAuraBuffRemindersDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 10x, `C_Timer` calls 17x.
- **Secure surface:** `SetAttribute` 30x, `SecureActionButtonTemplate` 4x
- **Hooks:** `HookScript` 7x, `hooksecurefunc` 1x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `ZONE_CHANGED_NEW_AREA`, `UNIT_AURA`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`, `SPELLS_CHANGED`, `ENCOUNTER_START`, `ENCOUNTER_END`, `PLAYER_DEAD`, `BAG_UPDATE_DELAYED`, `PLAYER_LOGIN`, `PLAYER_ALIVE`, `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`, `SPELL_ACTIVATION_OVERLAY_GLOW_HIDE`, `PLAYER_LEVEL_CHANGED`, `UNIT_PHASE`, `UNIT_ENTERED_VEHICLE`, `UNIT_EXITED_VEHICLE`
- **C_ namespaces used:** `C_UnitAuras`, `C_Timer`, `C_Item`, `C_Spell`, `C_ChallengeMode`, `C_Garrison`, `C_Traits`, `C_Map`, `C_PaperDollInfo`, `C_TradeSkillUI`, `C_SpellBook`, `C_Housing`, `C_Secrets`, `C_Container`, `C_CurveUtil`

## Features

### Clickable secure reminder icons

- **What it does:** Missing buff icon you click to cast/use it (flask, food, rune, oil, raid buff).
- **Design (UX, settings, defaults):** Sections: Raid Buffs, Auras, Consumables; middle-click dismiss; appear sounds; glow types.
- **How it is coded:** Secure, combat and cursor icon pools; provider cast button (`SecureActionButtonTemplate`) built out of combat; "Midnight non-secret-spell tracking" for auras that stay readable; pre-combat aura snapshot.
- **Benefit to players:** One click fixes the missing buff.

**Compared with Phoenix_UI** - status: **same**. Phoenix Reminders (`rm.click`, `rm.consumables`, `rm.raid`, `rm.class`, `rm.weaponOil`, `rm.readyCheck`, `rm.glow`, `rm.sound`).

### Talent reminders per zone

- **What it does:** Remind to swap talents when entering a zone or boss.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUIABR_TalentReminders.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `rm.talentZone`, `rm.talentZones`; Loadouts module.

### Ready-check mana warning; Beacon M+ reminders

- **What it does:** Warns healers low on mana at ready check; Holy Paladin beacon reminder during M+ bosses.
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **partial**. Phoenix `rm.readyCheck` (unverified mana). No beacon reminder.

Ideas to adopt (original code only): P3: low-mana line in ready-check summary.

## Verdict

Parity.
