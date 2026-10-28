# EllesmereUI core (+ Options, + Locales) - family index

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

The EllesmereUI suite is a core addon plus 20 child addons, one per area. This file covers the core, the options addon (~157k lines of option pages) and the locales addon. Each child module has its own file here (EllesmereUI_<Module>.md). Version 9.6.8 in the game folder, 9.6.1 on I:\. Interface lines cover retail 12.0.x-12.1.x and 16001 (WoW Forever).

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUI` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 73 / 81,763 |
| `EllesmereUIOptions` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 97 / 156,713 |
| `EllesmereUILocales` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 12 / 74,599 |

- **Title / notes (toc):** EllesmereUI - Shared framework for the EllesmereUI addon suite
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIDB`
- **Slash commands:** `/ee`, `/ellesmere`, `/ellesmereui`, `/epm`, `/eui`, `/euidev`, `/euigfintro`, `/euiktintro`, `/euioverridesintro`, `/euiresethint`, `/euiresetscale`, `/euistyleintro`
- **Embedded libraries:** CallbackHandler-1.0, LibDataBroker-1.1, LibDeflate, LibKeystone, LibSharedMedia-3.0, LibSpecialization, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 393x, `C_Timer` calls 290x.
- **Secure surface:** `SetAttribute` 37x, `SecureActionButtonTemplate` 4x, `SecureTemplate` 2x, `SecureHandlerStateTemplate` 1x, `RegisterStateDriver` 1x
- **Hooks:** `hooksecurefunc` 50x, `HookScript` 306x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_LOGIN`, `ADDON_LOADED`, `PLAYER_ENTERING_WORLD`, `FULLSCREEN_DIALOG`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `UNIT_SPELLCAST_START`, `UNIT_PET`, `GROUP_ROSTER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `GLOBAL_MOUSE_DOWN`, `PLAYER_LOGOUT`, `IN_OUT`, `UPDATE_MACROS`, `UI_SCALE_CHANGED`, `SCREEN_LEFT`, `CVAR_UPDATE`, `BAG_UPDATE_DELAYED`, `MODIFIER_STATE_CHANGED`, `SCREEN_RIGHT`, `SCREEN_TOP`, `UNIT_SPELLCAST_STOP`
- **C_ namespaces used:** `C_Timer`, `C_AddOns`, `C_Spell`, `C_Item`, `C_SpecializationInfo`, `C_SpellBook`, `C_Texture`, `C_CVar`, `C_EditMode`, `C_ChallengeMode`, `C_UnitAuras`, `C_Housing`, `C_CurveUtil`, `C_PvP`, `C_StringUtil`, `C_ToyBox`, `C_CurrencyInfo`, `C_Container`, `C_Traits`, `C_CooldownViewer`, `C_ClassTalents`, `C_ClassColor`

## Features

### Lite framework instead of Ace3

- **What it does:** Replaces AceAddon/AceEvent/AceDB with a small built-in layer that still reads AceDB-format saved variables.
- **Design (UX, settings, defaults):** Invisible to users.
- **How it is coded:** `EllesmereUI_Lite.lua`: direct frame event handlers (no CallbackHandler), AceDB-compatible profiles so no migration. A client gate (`EllesmereUI_ClientGate.lua`) stamps "Forever" before any other file runs, and content gates on it rather than on `WOW_PROJECT_ID`.
- **Benefit to players:** Less memory/CPU, one dependency fewer.

**Compared with Phoenix_UI** - status: **same**. Phoenix has its own kernel (`Core/Kernel.lua`, `Core/DB.lua`, `Core/Schema.lua`) and client gate (`Core/ClientGate.lua`).

### Unlock Mode (movers with anchors and snapping)

- **What it does:** Grid overlay, draggable movers for every element from every child addon, snap guides, anchor one element to another, size-match, position memory, return to options.
- **Design (UX, settings, defaults):** Animated transition; elements register through a shared API so all children use one table.
- **How it is coded:** `EUI_UnlockMode*.lua` (~15k lines). Anchor DB `{child -> {target, side}}`, link pruning and re-keying, `OnSizeChanged` hooks to keep anchored chains, combat-parked positioning (moves are queued until combat ends).
- **Benefit to players:** Precise layouts without addons fighting.

**Compared with Phoenix_UI** - status: **same**. Phoenix Studio layout editor (`Phoenix_UI_Options/Studio.lua`, `Core/Layout.lua`, `Core/Movers.lua`, `studio.*` 29 keys). Verified: attached movers with connector lines (`StudioExtras.lua`) and "Match width" (`StudioPanels.lua`).

Ideas to adopt (original code only): Check Studio supports anchoring one mover to another with automatic follow on resize, and size-matching (width of A = width of B). If not: **P2**.

### Spec overrides and conditional overrides

- **What it does:** Any setting can have a different value per spec group, or per condition (content type, group size...), with "editing as" mode.
- **Design (UX, settings, defaults):** Spec Assign popup, list page, layers; a resolution ladder decides which conditional group is active; a keybind toggles.
- **How it is coded:** `EllesmereUI_SpecOverrides*.lua` (harvest on leave, apply on enter), `EllesmereUI_Conditions.lua` (condition definitions, active-group resolver).
- **Benefit to players:** One profile adapts to tank/heal/dps and to raid vs M+.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Core/SpecProfiles.lua` (profile per spec) and `Core/Overrides.lua` + `Phoenix_UI_Options/OverridesUI.lua`. Verified: `Core/Overrides.lua` resolves condition > specialization > profile > default, with "editing as" sessions and provenance.

Ideas to adopt (original code only): Make sure overrides can be keyed by content type as well as spec (raid / M+ / PvP / open world), with a visible "editing as" banner. **P2** if missing.

### Macro Factory

- **What it does:** Creates and maintains helper macros (e.g. resident item macros) from a UI card.
- **Design (UX, settings, defaults):** Inside the QoL options page.
- **How it is coded:** `EUI_MacroFactory.lua` writes macros with the macro API out of combat and keeps item macros up to date.
- **Benefit to players:** No manual macro writing for common needs.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: no macro creation (rg `CreateMacro`: none). Oracle can run macros.

Ideas to adopt (original code only): P3: "Smart macros" card (healthstone/potion, focus interrupt, mouseover) written out of combat with a preview. Original.

### Global options search

- **What it does:** Fuzzy search across every option of every child addon.
- **Design (UX, settings, defaults):** Search box in the options window.
- **How it is coded:** Option rows register search entries if the search file exists (optional module).
- **Benefit to players:** Find any setting fast.

**Compared with Phoenix_UI** - status: **better**. Phoenix `Core/Search.lua` and Oracle command palette (Ctrl+K).

### First-install module picker, migrations, patch notes, video guides, uninstall

- **What it does:** Choose which modules stay enabled on first install; one-time migrations; patch-notes popup; links to video guides; uninstall.
- **Design (UX, settings, defaults):** Three-column checklist popup at login; migrations registered with id/scope/description.
- **How it is coded:** `EllesmereUI_FirstInstall.lua`, `EllesmereUI_Migration.lua` (one-time runner per account/character/profile/spec), `EllesmereUI_PatchNotesPopup.lua`, `EllesmereUI_VideoGuides.lua`, `EllesmereUI_Uninstall.lua`.
- **Benefit to players:** Smooth onboarding and upgrades.

**Compared with Phoenix_UI** - status: **partial**. Phoenix Setup wizard, presets, tour and uninstall (`Phoenix_UI_Setup/Wizard.lua`). No in-game "what's new" popup found (rg: none).

Ideas to adopt (original code only): **P2: "What's new" popup** after an update, generated from CHANGELOG.md at build time, dismissable, with links to the changed settings (Oracle can jump to them).

### Shared engines

- **What it does:** Glows, aura kit, kick data, number format, pixel-perfect sizing, rounded corners, style cards, colours, fonts, visibility rules, spell cost prediction, warrior charges, mana regen spark (Forever).
- **Design (UX, settings, defaults):** -
- **How it is coded:** Each in its own core file; child addons call them.
- **Benefit to players:** Consistency across modules.

**Compared with Phoenix_UI** - status: **partial**. Phoenix `Core/Look.lua`, `Theme.lua`, `Media.lua`, `Visibility.lua`, `Prediction.lua`, `Auras.lua`, `Ticker.lua`. No spell cost prediction (rg `GetSpellPowerCost`: none) and no Forever 5-second-rule spark.

Ideas to adopt (original code only): P3: spell cost preview on the power bar (shade the cost of the spell being cast). P3 (Forever): five-second-rule mana spark.

### Party mode and profile sync

- **What it does:** Party mode layout toggle; sync settings between characters.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EllesmereUI_PartyMode.lua`, `EllesmereUI_ProfileSync.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same (unverified: party mode)**. Phoenix profiles are account-wide with per-character choice (`Core/Profiles.lua`).

## Verdict

EllesmereUI is the closest competitor and the source of most ideas in this research. Its core strengths are the anchor/size-match unlock mode, overrides by spec *and* condition, and onboarding polish (module picker, patch notes). Phoenix matches most of it; the clear gaps are a "What's new" popup (P2), macro factory (P3) and spell-cost preview (P3).
