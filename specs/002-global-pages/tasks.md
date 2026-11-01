# Tasks: Global pages

**Input**: specs/002-global-pages/ (spec.md, plan.md)
**Tests**: each task adds or updates a smoke-harness check (constitution gate).

## Format: `[ID] [P?] [Story] Description`
Each task is one commit with a CHANGES.md entry, a regenerated Core/Changelog.lua and tasks ticks; luacheck,
check_locales and the harness pass; then prepush, push and install.

## Phase 1: Setup
- [x] T000 Spec, plan and tasks for 002

## Phase 2: Foundational
- [x] T001 Row owner: `module = "<key>"` on a schema row makes the renderer read, write, reset and count it on
  that module (Renderer.lua) plus a harness check

## Phase 3: User Story 1 - Global pages (P1)
- [x] T002 [US1] Colors page: accent, class, power and dispel colours moved from General (Appearance.lua,
  General.lua, Locales)
- [x] T003 [US1] Fonts and Textures pages lead with the global font section and the global bar texture, moved from
  General (Appearance.lua, General.lua)
- [x] T004 [US1] Glows page mirroring every module glow row (Appearance.lua, Locales)

## Phase 4: User Story 2 and 3 - General and order (P2, P3)
- [x] T005 [US2] General › Looks takes the Presets page rows; the presets page is retired (Presets.lua,
  General.lua, Groups.lua)
- [x] T006 [US3] Phoenix group order General, Colors, Fonts, Textures, Glows, Sounds, Profiles, Layout, Plugins,
  Bugs, Diagnostics, About (Groups.lua)

## Phase N: Polish
- [x] T007 Settings count and search unchanged across the move (SC-002) in the harness

## Dependencies
T001 blocks T002–T004. T005 and T006 follow T002–T004.
