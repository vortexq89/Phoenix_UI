# EllesmereUI Action Bars

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Own secure action bar frames and buttons (not Blizzard's), to avoid tainting Blizzard's protected buttons. 28 files, ~22k lines. Slash `/eab`, `/kb`.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIActionBars` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 28 / 22,409 |

- **Title / notes (toc):** EllesmereUI Action Bars - Modern action bars built for performance and clarity.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIActionBarsDB`
- **Slash commands:** `/eab`, `/kb`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 20x, `C_Timer` calls 38x.
- **Secure surface:** `SetAttribute` 106x, `RegisterStateDriver` 15x, `SecureActionButtonTemplate` 8x, `SecureHandlerStateTemplate` 6x, `SecureHandlerAttributeTemplate` 6x, `SecureTemplate` 2x
- **Hooks:** `HookScript` 71x, `hooksecurefunc` 63x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `ACTIONBAR_SLOT_CHANGED`, `ACTIONBAR_UPDATE_COOLDOWN`, `PLAYER_REGEN_ENABLED`, `PLAYER_LOGIN`, `PLAYER_REGEN_DISABLED`, `ACTIONBAR_PAGE_CHANGED`, `ACTIONBAR_UPDATE_USABLE`, `UPDATE_SHAPESHIFT_FORM`, `ADDON_LOADED`, `SPELL_UPDATE_CHARGES`, `SPELL_UPDATE_ICON`, `PLAYER_TARGET_CHANGED`, `UPDATE_VEHICLE_ACTIONBAR`, `UPDATE_OVERRIDE_ACTIONBAR`, `UPDATE_BONUS_ACTIONBAR`, `SPELL_UPDATE_COOLDOWN`, `UNIT_ENTERED_VEHICLE`, `CVAR_UPDATE`, `SPELLS_CHANGED`, `INPUT_DEVICE_INTERFACE_TRANSITION`, `UPDATE_BINDINGS`
- **C_ namespaces used:** `C_ActionBar`, `C_Timer`, `C_Spell`, `C_Reputation`, `C_Housing`, `C_Texture`, `C_EventUtils`, `C_AssistedCombat`, `C_CurveUtil`, `C_MajorFactions`, `C_CooldownViewer`, `C_SpellBook`, `C_SpellActivationOverlay`, `C_AddOns`, `C_EditMode`

## Features

### Own secure bars and buttons

- **What it does:** Bars 1-8+, stance, pet, vehicle exit, extra bars, micro menu and bag bar holders.
- **Design (UX, settings, defaults):** Per-bar layout, shapes, borders, fonts; first-install capture of Blizzard's layout so the bars start where the user had them.
- **How it is coded:** `SecureActionButtonTemplate` + `SecureHandlerStateTemplate`; `RegisterStateDriver` for paging and visibility; a secure controller for show-grid, drag and click snippets; Blizzard bars disposed early into a hidden frame while the file loads (`EUI_ActionBars_Disposal.lua`).
- **Benefit to players:** Taint-free bars that look modern.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_ActionBars` (ab.bar1..bar10, stance, pet, vehicle, extra, items, `ab.editModeCapture`).

Ideas to adopt (original code only): `ab.editModeCapture` exists: check it captures Blizzard positions on first install like theirs.

### Paging and visibility conditions

- **What it does:** Per-bar paging conditions including class states, page arrows on bar 1; visibility drivers (combat, mouseover, vehicle, gamepad...).
- **Design (UX, settings, defaults):** Condition builder UI.
- **How it is coded:** `EUI_ActionBars_Paging.lua`, `VisibilityDrivers.lua` build macro-condition strings for state drivers; lazy bar build when a bar first becomes visible.
- **Benefit to players:** Bars only when needed.

**Compared with Phoenix_UI** - status: **same**. Phoenix where-to-show rules per bar (combat, vehicle, pet battle, mounted, skyriding, content, group, spec), fade, `ab.mouseoverLinked`.

### Keybinds, quick keybind, range, glows, pushed state

- **What it does:** Override bindings per bar with key-down casting; Quick Keybind Mode support; out-of-range tint per slot; proc glows and assisted-combat highlight; pushed flash.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Keybinds.lua` uses override bindings; `Range.lua` per-slot checks; `Glows.lua` glue to the shared glow engines.
- **Benefit to players:** Responsive and readable bars.

**Compared with Phoenix_UI** - status: **same**. Phoenix `KeybindMode.lua`, `ab.rangeMode`, `ab.procGlow`, `ab.assist`, `ab.lossOfControl`, `ab.keyAbbrev`.

### XP / reputation / house favour bars with Quest XP overlay

- **What it does:** XP bar art styles, dividers, "smart ticks" and an overlay showing XP from completed quests in your log.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_ActionBars_XPBar.lua` sums quest reward XP for completed quests and draws it as a second fill.
- **Benefit to players:** See whether turning in quests levels you.

**Compared with Phoenix_UI** - status: **missing**. Phoenix data bars (`db.bar1..4`, `db.progress`), paragon progress (PR #70). No quest-XP overlay (rg: none).

Ideas to adopt (original code only): **P3:** pending quest XP overlay on the XP bar (sum `GetQuestLogRewardXP` for completed quests; event-driven on `QUEST_LOG_UPDATE`).

### Gamepad and housing

- **What it does:** Hide bars while using a gamepad; housing editor keybinds.
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix has gamepad handling in `Phoenix_UI_ActionBars/Extras.lua`.

## Verdict

Parity. One small P3 (quest XP overlay).
