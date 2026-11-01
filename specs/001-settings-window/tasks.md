# Tasks: Settings window and controls in the EllesmereUI look

**Input**: Design documents from `specs/001-settings-window/`
**Prerequisites**: plan.md, spec.md
**Tests**: each task adds or updates a smoke-harness check (constitution gate).

## Format: `[ID] [P?] [Story] Description`
Each task is one commit with: a CHANGES.md entry, a regenerated Core/Changelog.lua, plan doc updates, luacheck,
check_locales, the harness, then prepush, push and install.

## Phase 1: Setup
- [x] T000 Spec Kit initialised (`.specify/`, `.grok/skills/`), constitution written, spec / plan / tasks for 001

## Phase 2: Foundational
- [x] T001 [US1] `W.EUI` look table in UI/Widgets/Core.lua (all FR-001..FR-007 values in one place) plus the
  harness check that it exists and matches the spec numbers

## Phase 3: User Story 1 - Controls (P1) 🎯 MVP
- [x] T002 [US1] Toggle: 40 × 20, square knob, pad 2, off #444/0.65 with knob 0.5, on accent/0.75 with knob 1, slide
  0.075 s via ns.Anim, no picture art (UI/Widgets/Toggle.lua) plus a harness check
- [x] T003 [P] [US1] Checkbox widget `W:Checkbox` (18 px box, border 0.05/0.15, solid accent square) in UI/Widgets/Toggle.lua; rows adopt it in T013
- [x] T004 [P] [US1] Slider: track white 0.16, fill accent 0.75, input box 0.030/0.023/0.018 at 0.25, border 0.02
  (UI/Widgets/Slider.lua)
- [x] T005 [P] [US1] Dropdown: box and menu colours, hover / selection alphas, max height 200, 4 px scroll bar
  (UI/Widgets/Dropdown.lua)
- [x] T006 [P] [US1] Button: flat background 0.6/0.65, border 0.3/0.45, text 0.55/0.70 (UI/Widgets/Button.lua)
- [x] T007 [P] [US1] Colour swatch 1 px border and Segmented / Tabs flat style (ColorSwatch.lua, Controls.lua)

## Phase 4: User Story 2 - Window layout (P2)
- [x] T008 [US2] Window proportions: base 1300 × 946 (fit to screen), sidebar 295, header 138, tab bar 40, footer 82,
  padding 45 (Window.lua)
- [x] T009 [US2] Sidebar groups Core / QoL / UI Reskin / Phoenix per map §7, nav row states (Groups.lua, Window.lua)
- [ ] T010 [US2] Module pages as header tabs, last tab remembered (Window.lua, Renderer.lua)
- [ ] T011 [US2] Footer: profile, Layout, Test frames, window-scale slider; remove every "reload to apply" text and
  its locale keys (Window.lua, Locales/*)
- [ ] T012 [US2] Section headers (white 0.41 caps) and rows 50 high, two-up 350 + 42 + 350, three-up 180 / 50,
  shading 0.1 / 0.2 (Section.lua, Renderer.lua)

## Phase 5: User Story 3 - Cog and sync (P3)
- [ ] T013 [US3] Cog popup available to every row type; advanced rows move into it (Renderer.lua, Controls.lua)
- [ ] T014 [US3] Sync-to-all icon for settings shared by several frames (Renderer.lua)

## Phase N: Polish
- [ ] T015 Search re-index check (same count), harness live-apply and OnUpdate audits, screenshots compared with
  EllesmereUI (SC-001..SC-004)
- [ ] T016 Retire the unused art-kit paths in the widgets (after one release)

## Dependencies & Execution Order
T001 blocks everything. T002–T007 run in parallel after T001. T008 blocks T009–T012. T012 blocks T013–T014.
Polish comes last.
