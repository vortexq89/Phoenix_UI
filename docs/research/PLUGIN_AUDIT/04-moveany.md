# 04 · MoveAny (move every panel, not bars or unit frames)

Audited 2026-11-01 (t226/t227) against `restore/v1-ui` @ fc053f54. The reference copies are read-only (I:\, D:\). Phoenix copies behaviour only; it never copies code (constitution I, V).

Status key: **have** = matching or better; **partial** = exists but weaker or split; **missing**.

Source: `I:\MoveAny` (102 window frames in moveframes.lua, 119 element switches). Licence: check LIBRARIES.md; behaviour only.

## Parity
| Feature | MoveAny | Phoenix | Status |
|---|---|---|---|
| Move Blizzard windows (Character, PVE, ...) | 102 frames | Skins › Move windows (drag) + Movers › Blizzard windows (scale, 17 in `M.WINDOWS`) | partial (**split across 2 modules**) |
| Scale and alpha per window | yes | Window scale / This window's scale | have |
| HUD elements (zone text, errors, alerts, top widgets, boss banner, toasts, ready check) | yes | `M.BLIZZARD` (8) | partial (MoveAny has more, e.g. the vehicle seat indicator, durability, ticket status, the loss-of-control frame and the archaeology bar) |
| Any frame by name or by pick | yes | Any frame / Pick a frame | have |
| Grid, snap, nudge, coordinates | grid | grid, snap to grid and frames, arrows, coordinates | have (better) |
| Edit Mode frames | moves them (conflicts) | guard refuses them and points to Edit Mode | have (by design) |

## Conflict: three movers in one UI
1. **Blizzard Edit Mode**: action bars, unit frames, buffs, cast bar, minimap, chat, objective tracker and the other Edit Mode systems.
2. **Phoenix Layout/Movers**: Phoenix-owned frames (CDM bars, data bar, combat-text areas, spell history, Phoenix frames).
3. **Skins › Move windows** drags Blizzard windows, while **Movers › Blizzard windows** scales the *same* windows.

## The one model (proposal; decided in spec 003)
- **Edit Mode owns its systems.** Where Phoenix replaces one (UF, action bars), the Phoenix frame registers in **Phoenix Layout**, and the Edit Mode copy is hidden, so a frame never appears in both.
- **Phoenix Layout** (one unlock mode: Movers renamed to "Layout") owns every Phoenix frame **and** every non-Edit-Mode Blizzard HUD element or window. Window dragging moves from Skins into Layout › Windows (one list: move, scale, reset).
- Opening one closes the other (already true). The Layout toolbar has a button "Edit Mode frames →".
- Every module's "Move" row (SpellHistory › Move, CDM › Move frames, CombatText › Move the areas) opens Layout focused on that frame. There are no local mover modes.

## Screenshot issues (Movers screen)
- Huge combat-text boxes, overlapping labels (Boss banner and others) and a cramped toolbar. Fix with min/max box sizes, labels inside the box with ellipsis, a collision offset and a 2-row toolbar (15 › M1–M3).

## Improvements (spec 005)
Widen `M.WINDOWS` to the full MoveAny window list (data only, presence-checked); add the missing HUD elements; per-frame "hide"; profiles per layout; a search box in the Layout frame list.
