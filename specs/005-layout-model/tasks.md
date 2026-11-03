# Tasks: One layout model

## Phase 1: Setup
- [x] T000 Spec, plan and tasks for 005

## Phase 2: Foundational
- [x] T001 `Movers:Focus(key)` + harness (opens unlock mode with the frame selected)

## Phase 3: User Story 1 (P1)
- [x] T002 [US1] Window dragging moved to the Layout page (Blizzard windows section) as Skins-owned rows (module = "Skins"), so no saved data moved and no migration is needed; the drag code now lives in Layout (Modules/Movers/Windows.lua); Skins keeps the switch and saved spots and hooks Layout's window list too
- [x] T003 [US1] Skins has no move rows; SKINS_MOVE removed from the 10 locales

## Phase 4: User Story 2 (P1)
- [x] T004 [US2] Spell History, the XP bar and the M+ timer "Move" rows open Layout on their frame (the M+ sample run shows in Layout too); Combat Text, CDM, bars, auras, cast bars, unit and group frames already opened Layout. The Damage Meter, Minimap and Chat rows stay on Edit Mode: those are Blizzard Edit Mode frames + harness

## Phase 5: User Story 3 (P2)
- [x] T005 [US3] Eight more windows (Inspect, Trade, Loot, Trainer, Flight map, Guild bank, Dressing room, AddOns list) in 10 locales; twenty more of MoveAny's list (macros, clock, calendar, socketing, upgrade, keystone, archaeology, scrapper, expansion summary, professions book, crafting orders, stable, tabard, black market, transmogrify, renown, item interaction, chat settings, flight master, petition)
- [x] T006 [US3] Reviewed: MoveAny's extra HUD elements (durability, vehicle seat, loss of control, …) are Edit Mode systems on retail now, so the guard rightly sends them to Edit Mode; nothing to add

## Phase 6: User Story 4 (P2)
- [x] T007 [US4] Frame list with search and groups on the Layout page (Phoenix / Blizzard / added, type to filter, Move it opens Layout on it) + harness; Phoenix frames are Layout only (no Blizzard Edit Mode entry, spots kept) + harness
- [x] T008 [US4] The page and mode are named "Layout" in all 10 locales (the module key stays "Movers"); Edit Mode button already there. Layout profiles: spots per Edit Mode layout shown on the page, copy another layout's spots into the one in use
