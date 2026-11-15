# Mik's Scrolling Battle Text (MSBT)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (game 12.042, I:\ 12.040)

**Licence:** No licence file for MSBT itself (treat as All Rights Reserved). Its `Combat/` folder states it is adapted from Forever Combat Text 0.6.8 (MIT) and ships that licence.

Classic scrolling combat text with scroll areas, triggers and profiles. This build has a large new combat layer for the closed combat log: it works out which hits are yours from public events.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `MikScrollingBattleText` | 12.042 | 12.040 | 120105, 120100, 11504, 40400, 110002 | 64 / 22,858 |

- **Title / notes (toc):** Mik's Scrolling Battle Text - Scrolls battle information around the character model.
- **Author (toc):** Mikord
- **SavedVariables:** `MSBTCombatEngine_SavedVars`, `MSBTProfiles_SavedVars`, `MSBTProfiles_SavedVarsPerChar`, `MSBT_SavedMedia`
- **Optional deps:** LibSharedMedia-3.0
- **Embedded libraries:** CallbackHandler-1.0.lua, LICENSE-LibDeflate.txt, LICENSE-LibSerialize.txt, LibDeflate.lua, LibSerialize.lua, LibSharedMedia-3.0.lua, LibStub.lua (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 9x, `C_Timer` calls 20x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 7x, `HookScript` 1x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `COMBAT_LOG_MESSAGE`, `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`, `LOOT_ITEM_CREATED_SELF`, `UNIT_COMBAT`, `UNIT_SPELLCAST_SUCCEEDED`, `COMBAT_TEXT_UPDATE`, `CURRENCY_GAINED`, `UNIT_AURA`, `LOOT_ITEM_CREATED_SELF_MULTIPLE`, `LOOT_ITEM_PUSHED_SELF_MULTIPLE`, `LOOT_ITEM_PUSHED_SELF`, `LOOT_ITEM_SELF_MULTIPLE`, `LOOT_ITEM_SELF`, `YOU_LOOT_MONEY`, `LOOT_MONEY_SPLIT`, `CURRENCY_GAINED_MULTIPLE`, `CURRENCY_GAINED_MULTIPLE_BONUS`, `VARIABLES_LOADED`, `SPELL_AURA_START`
- **C_ namespaces used:** `C_Spell`, `C_Timer`, `C_UnitAuras`, `C_CombatText`, `C_CombatLog`, `C_Item`, `C_Container`, `C_AddOns`, `C_ChallengeMode`, `C_EventUtils`, `C_Secrets`, `C_TooltipInfo`, `C_CurrencyInfo`, `C_LossOfControl`

## Features

### Scroll areas and animation styles

- **What it does:** Incoming, outgoing, notification and custom areas with straight, parabola, angled and static styles.
- **Design (UX, settings, defaults):** Options addon `MSBTOptions` (load on demand). Fonts via LibSharedMedia.
- **How it is coded:** `Display/AnimationEngine.lua` and `AnimationStyles.lua` move pooled font strings in Lua per frame (an OnUpdate driver).
- **Benefit to players:** Readable, moveable combat feedback.

**Compared with Phoenix_UI** - status: **better (performance)**. Phoenix `Phoenix_UI_Spark` (`spark.area`, four scroll areas, live preview). Spark moves lines with C-side AnimationGroups so no Lua runs per frame.

### Hit attribution without the combat log ("worked out")

- **What it does:** Decides which damage numbers on a unit are yours.
- **Design (UX, settings, defaults):** Labelled "worked out" on its settings page so users know it is inferred.
- **How it is coded:** `Combat/Mine.lua` matches each `UNIT_COMBAT` report (amount, school, flags; no source) to your own `UNIT_SPELLCAST_SUCCEEDED` (player and pet) and `PLAYER_SWING` events by time and school: next DoT tick on its rhythm, first hit after a cast of that school, first tick 1/1.5/2/3 s after cast, physical hit right after a swing, pet hit while the pet is attacking (max 1/s), otherwise someone else's. It learns per spell (school, instant vs tick, tick interval) and only trusts a learned school after confirmation (three agreeing casts or a matching log line), because a teammate's Frostbolt once taught it a wrong school.
- **Benefit to players:** Outgoing numbers keep working after the combat log closed.

**Compared with Phoenix_UI** - status: **same idea; MSBT's rules are more mature**. Phoenix Spark has `spark.attributionWindow` and `spark.outgoingMode`: outgoing attribution exists (Feed.lua uses `UNIT_SPELLCAST_SUCCEEDED`).

Ideas to adopt (original code only): Adopt the **trust-before-learn** principle: never store a learned fact from one sample; require N agreeing samples and allow taking a guess back. Also adopt the user-facing "worked out" label for inferred data.

### Triggers and notifications

- **What it does:** Low health/mana, procs, cooldown ready, loot, money, currency, reputation, XP, honour.
- **Design (UX, settings, defaults):** Trigger editor with conditions; per-event colours and sounds.
- **How it is coded:** `MSBTTriggers.lua`, `Components/*Notifications.lua`, `ItemCooldownTracker.lua`.
- **Benefit to players:** One place for all feedback text.

**Compared with Phoenix_UI** - status: **same**. Phoenix Spark: `spark.triggers`, `spark.items`, `spark.lootQuality`, `spark.itemThreshold`, money/rep/XP text.

### Profiles and transfer

- **What it does:** Profiles with import/export strings.
- **Design (UX, settings, defaults):** `Configuration/ProfileTransfer.lua` with LibSerialize + LibDeflate.
- **How it is coded:** Serialize -> compress -> encode for chat-safe strings.
- **Benefit to players:** Share setups.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Core/Profiles.lua`, share strings in several modules.

## Verdict

Phoenix Spark is architecturally ahead (no per-frame Lua). Take MSBT's attribution safeguards as design lessons. No P1 gaps.
