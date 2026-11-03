# Tasks: One layout model

## Phase 1: Setup
- [x] T000 Spec, plan and tasks for 005

## Phase 2: Foundational
- [x] T001 `Movers:Focus(key)` + harness (opens unlock mode with the frame selected)

## Phase 3: User Story 1 (P1)
- [x] T002 [US1] Window dragging moved to the Layout page (Blizzard windows section) as Skins-owned rows (module = "Skins"), so no saved data moved and no migration is needed; the drag code itself still lives in Skins/Move.lua (merging the code is a later step)
- [x] T003 [US1] Skins has no move rows; SKINS_MOVE removed from the 10 locales

## Phase 4: User Story 2 (P1)
- [x] T004 [US2] Spell History, the XP bar and the M+ timer "Move" rows open Layout on their frame (the M+ sample run shows in Layout too); Combat Text, CDM, bars, auras, cast bars, unit and group frames already opened Layout. The Damage Meter, Minimap and Chat rows stay on Edit Mode: those are Blizzard Edit Mode frames + harness

## Phase 5: User Story 3 (P2)
- [x] T005 [US3] Eight more windows (Inspect, Trade, Loot, Trainer, Flight map, Guild bank, Dressing room, AddOns list) in 10 locales; the rest of MoveAny's list follows
- [ ] T006 [US3] Extra HUD elements and per-entry hide

## Phase 6: User Story 4 (P2)
- [ ] T007 [US4] Frame list with search and groups beside the toolbar
- [ ] T008 [US4] "Layout" name in 10 locales; Edit Mode button; per-layout profiles
