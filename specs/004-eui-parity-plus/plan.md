# Implementation Plan: EllesmereUI parity and beyond

**Spec**: spec.md | **Constitution**: v1.1.0 (I, II, IV, VI)

## Technical context
- Previews: `Phoenix_UI_Options/Previews/*` move from drawn samples to a `Previews/Host.lua` that asks a module
  for `M:BuildPreview(parent, sample)`. UnitFrames and GroupFrames go first (they are empty today), then NamePlates,
  CastBars, Auras and Tracker (CDM).
- Buff reminders: a new file in `Phoenix_UI_Auras/Reminders.lua`, with data tables of buff, flask, food and rune spell IDs
  (from the game's own data and checked with tools/check_ids.py), one secure item button per missing item, and
  settings on the Auras page (a "Reminders" tab).
- Naming: Locales only (labels for "Tracker" → "Cooldown Manager").
- Social page: a new Options page that owns the existing Skins friends-window row and DataTexts friends rows through
  `module = "<key>"` (the specs/002 row owner), so no keys move.
- Data bar: `Phoenix_UI_DataTexts/Bar.lua` gets width-based packing and a Layout registration (`Movers:Register`).
- Quickdraw: a new tab on Automation; `C_Macro` / `CreateMacro` / `SetBinding` out of combat only.

## Constitution check
Original code; every setting live; C_Timer only; Phoenix Font; one feature in one place (Social replaces two places).
Passes.

## Order
US1 (UF, GF previews), then US2, US4, US3, US5. Each task is one commit with harness checks.
