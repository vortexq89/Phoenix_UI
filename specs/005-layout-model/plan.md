# Implementation Plan: One layout model

**Spec**: spec.md | **Constitution**: v1.1.0 (II, IV, VI)

## Technical context
- Movers: `Modules/Movers/Movers.lua` (M.BLIZZARD, M.WINDOWS, Register, the Edit Mode guard), `Toolbar.lua`, `Popup.lua`.
- Skins window drag: `Phoenix_UI_Skins/Move.lua` and the Skins options rows `moveWindows` / reset (Options/Skins.lua).
- Local move rows: Options/SpellHistory.lua (DT_MOVE → Edit Mode), Options/DataTexts.lua, Encounters timer-bar move
  toggles, CombatText "Move the areas", Tracker (CDM) "Move frames".
- Migration: Core/Migrations.lua step "skins-windows-to-layout".

## Steps
1. Movers API `M:Focus(key)` opens Layout with a frame selected (used by every Move row).
2. Skins/Move.lua registers its windows through Movers; the migration copies saved positions; the Skins rows go.
3. Rewire the local Move rows to `M:Focus`.
4. Grow M.WINDOWS and M.BLIZZARD (data); add hide per entry.
5. Layout screen: frame list with search and groups; rename to "Layout".

## Constitution check
One feature in one place (removes two duplicates); live; migration for moved data; C_Timer only. Passes.
