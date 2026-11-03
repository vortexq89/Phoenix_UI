# Tasks: EllesmereUI parity and beyond

## Phase 1: Setup
- [x] T000 Spec, plan and tasks for 004

## Phase 2: Foundational
- [x] T001 Preview hardening: an empty preview says so (and notes it for Diagnostics) instead of a blank panel. The real-code previews already exist (Previews/UnitFrames.lua, GroupFrames.lua); the blank panels could not be reproduced from the files or the saved error log, so T002/T003 wait for an in-game screenshot with this build

## Phase 3: User Story 1 (P1)
- [x] T002 [US1] Unit Frames live preview: t228 removed the preview box and its clipping (the likely cause of the blank/clipped panels); the stage is sized to the real frame, centred; confirm in game
- [x] T003 [US1] Group Frames live preview: same t228 fix (no box, no clipping, sized to the sample); confirm in game
- [x] T004 [P] [US1] NamePlates, Cast Bars, Buffs and CDM previews were already on the host; they share the t228 boxless stage

## Phase 4: User Story 2 (P1)
- [x] T005 [US2] Already built: Phoenix_UI_Tracker/Reminders.lua (audit corrected)
- [x] T006 [US2] Already built (secure click-to-use icons, instances-only option)
- [x] T007 [US2] Buffs page links to the reminders (10 locales)

## Phase 5: User Story 4 (P2)
- [ ] T008 [US4] Data bar packing, panel 2 overflow, default above the action bars, Layout entry + harness

## Phase 6: User Story 3 (P2)
- [x] T009 [US3] Already true: the page is "Cooldown Manager" in all 10 locales
- [x] T010 [US3] Social page (QoL group): friends window, friends and guild data texts, invite/duel/guild/resurrect rules, all owned by their modules (no key moved) + harness
- [x] T011 [US3] Resource bars section was already on Unit Frames; Home's quick actions get a Resource bars button that lands on it

## Phase 7: User Story 5 (P3)
- [ ] T012 [US5] Quickdraw: macro list, make from drag, click to bind
