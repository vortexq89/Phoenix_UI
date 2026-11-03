# Feature Specification: Layout: MoveAny parity

**Feature Branch**: `008-moveany` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: MoveAny | **Audit**: [04-moveany.md](../../docs/research/PLUGIN_AUDIT/04-moveany.md)

## User Scenarios & Testing

### User Story 1 - Move Blizzard windows (Character, PVE, ...) (P2)
As a player, I get Move Blizzard windows (Character, PVE, ...) in Phoenix in full, in the Phoenix style, in one place.

**Today**: Skins › Move windows (drag) + Movers › Blizzard windows (scale, 17 in `M.WINDOWS`) (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - HUD elements (zone text, errors, alerts, top widgets, boss banner, toasts, ready check) (P2)
As a player, I get HUD elements (zone text, errors, alerts, top widgets, boss banner, toasts, ready check) in Phoenix in full, in the Phoenix style, in one place.

**Today**: `M.BLIZZARD` (8) (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

Builds on specs/005 (one layout model).

### Already in Phoenix (keep, verify against the checklist)

- Scale and alpha per window: Window scale / This window's scale
- Any frame by name or by pick: Any frame / Pick a frame
- Grid, snap, nudge, coordinates: grid, snap to grid and frames, arrows, coordinates
- Edit Mode frames: guard refuses them and points to Edit Mode

### From the audit (fixes, conflicts, where Phoenix must be better)

1. **Blizzard Edit Mode**: action bars, unit frames, buffs, cast bar, minimap, chat, objective tracker and the other Edit Mode systems.
2. **Phoenix Layout/Movers**: Phoenix-owned frames (CDM bars, data bar, combat-text areas, spell history, Phoenix frames).
3. **Skins › Move windows** drags Blizzard windows, while **Movers › Blizzard windows** scales the *same* windows.
- **Edit Mode owns its systems.** Where Phoenix replaces one (UF, action bars), the Phoenix frame registers in **Phoenix Layout**, and the Edit Mode copy is hidden, so a frame never appears in both.
- **Phoenix Layout** (one unlock mode: Movers renamed to "Layout") owns every Phoenix frame **and** every non-Edit-Mode Blizzard HUD element or window. Window dragging moves from Skins into Layout › Windows (one list: move, scale, reset).
- Opening one closes the other (already true). The Layout toolbar has a button "Edit Mode frames →".
- Every module's "Move" row (SpellHistory › Move, CDM › Move frames, CombatText › Move the areas) opens Layout focused on that frame. There are no local mover modes.

## Requirements

- **FR-001**: Phoenix MUST provide Move Blizzard windows (Character, PVE, ...) (partial today).
- **FR-002**: Phoenix MUST provide HUD elements (zone text, errors, alerts, top widgets, boss banner, toasts, ready check) (partial today).
- **FR-003**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
