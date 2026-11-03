# Feature Specification: One layout model

**Feature Branch**: `restore/v1-ui` | **Created**: 2026-11-03 | **Status**: Draft
**Input**: docs/research/PLUGIN_AUDIT/04-moveany.md and 00-INDEX.md §2; constitution VI.

## The model
1. **Blizzard Edit Mode** owns the frames it manages (action bars, Blizzard unit frames, buffs, cast bar, minimap,
   chat, objective tracker, and the other Edit Mode systems). Phoenix never moves them. When Phoenix replaces one,
   the Blizzard copy is hidden and only the Phoenix frame is in Layout.
2. **Phoenix Layout** (today's Movers, renamed) is the only Phoenix unlock mode. It moves, scales, fades, hides and
   resets every Phoenix frame and every Blizzard window or HUD element that Edit Mode does not manage.
3. Every "Move" button anywhere opens Layout with that frame selected. The two modes are exclusive (already true), and
   each has a button for the other.

## User Scenarios & Testing
### User Story 1 - One place to move Blizzard windows (P1)
Dragging and scaling the Character, Group Finder, Bank and other windows is in Layout › Windows, as one list
(move, scale, reset, per window). Skins no longer has its own "Move windows" switch; its saved positions are kept.
**Independent test**: a profile with Skins window positions migrates into Layout's store, and the window opens there.

### User Story 2 - Every "Move" row opens Layout (P1)
Spell History, Data texts, Encounters (timer bars, emphasised bars), Combat Text areas and the Cooldown Manager have
no local mover modes. Their "Move" rows open Layout focused on their frame.

### User Story 3 - The full MoveAny window and element list (P2)
Layout knows every Blizzard window MoveAny moves (about 100, checked present at runtime) and the HUD elements Edit Mode
does not manage (vehicle seat, durability, ticket status, loss of control, archaeology bar, …), each with hide.

### User Story 4 - A Layout screen that reads well (P2)
A searchable frame list beside the toolbar, groups (Phoenix frames, Blizzard windows, HUD elements), per-layout
profiles, and a clear "Edit Mode frames →" button.

## Requirements
- FR-001 `Modules/Movers` is the single store of positions for non-Edit-Mode frames; Phoenix_UI_Skins/Move.lua becomes a
  client of it (no second drag code).
- FR-002 A migration moves `Skins.windows` positions into the Movers store and tolerates any old shape (constitution II).
- FR-003 The Edit Mode guard stays: frames managed by Edit Mode are refused with a pointer to Edit Mode.
- FR-004 The window list is data (`M.WINDOWS` grows); each entry is presence-checked and load-on-demand windows are
  hooked when they load.
- FR-005 No OnUpdate: drag uses StartMoving/StopMovingOrSizing; nudges use C_Timer.
- FR-006 The user-visible name becomes "Layout" in all 10 locales (the module key "Movers" stays, for saved data).
- Out of scope: Edit Mode systems themselves; Phoenix unit frame and action bar positions (they stay in Layout
  already).

## Success Criteria
- SC-001 One mover per frame: no frame can be moved from two places (harness walks all registrations).
- SC-002 Skins has no move rows; existing window positions survive the update.
- SC-003 Every "Move" row in the options opens Layout with that frame selected.
