# Feature Specification: EllesmereUI parity and beyond

**Feature Branch**: `restore/v1-ui` | **Created**: 2026-11-03 | **Status**: Draft
**Input**: docs/research/PLUGIN_AUDIT/01-ellesmereui.md and 15-gui-screenshots.md (P1, D1); constitution VI.

## User Scenarios & Testing
### User Story 1 - Every frame page shows the real thing (P1)
Unit Frames, Group Frames, Nameplates, Cast Bars, Buffs and the Cooldown Manager pages show a live preview built
from the same code as the real frames. Changing a setting changes the preview at once, with no reload.
**Independent test**: the harness opens each page, changes one size, one texture and one colour, and checks that
the preview frame changed.

### User Story 2 - Buff reminders (P1)
A reminder shows when you are missing your class buff, flask/phial, food, augment rune or weapon oil in an
instance (or always, by choice), with an icon you can click to use the item if you have it (out of combat).
**Independent test**: with a sample aura list missing the flask, the reminder lists the flask; with it present,
it hides.

### User Story 3 - Clear names and one home for each feature (P2)
The Cooldown Manager is named so everywhere (the folder stays, for saved data). Friends gets its own "Social" page
(the friends window, friends online, invite rules) instead of sitting under Skins. Resource bars get their own
section on the Unit Frames page with a jump link from Home.

### User Story 4 - A data bar that fits (P2)
The data bar starts above the action bars, never on top of chat. Too many texts flow into a second panel instead of
overlapping, and it shows in Layout.

### User Story 5 - Quickdraw (P3)
A macro and keybind helper: list your macros with their icons, make one from a spell or item by drag, and bind a key
with a click (out of combat).

## Requirements
- FR-001 A shared preview host renders a module's real frame factory with sample units (Retail and Forever).
- FR-002 Previews follow live setting changes through PUI_SETTING_CHANGED; no OnUpdate.
- FR-003 Buff reminders read auras with secret-safe calls only; secret values are passed to widgets, never compared.
- FR-004 Renaming labels moves no saved keys; any moved setting gets a Core/Migrations.lua step.
- FR-005 The data bar layout is computed from the text widths; overflow goes to panel 2.
- FR-006 Every new key is in all 10 locales.
- Out of scope: frame moving (spec 005), Sim (007).

## Success Criteria
- SC-001 No empty preview on any frame page (screenshot P1).
- SC-002 Each EllesmereUI module row in 01-ellesmereui.md reads "have".
- SC-003 Harness checks for US1, US2 and US4 pass on Retail and Forever.
