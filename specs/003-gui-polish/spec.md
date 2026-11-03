# Feature Specification: GUI polish (screenshot review)

**Feature Branch**: `restore/v1-ui` | **Created**: 2026-11-01 | **Status**: Draft
**Input**: the owner's 20 screenshots (t227); issues are listed in docs/research/PLUGIN_AUDIT/15-gui-screenshots.md.

## User Scenarios & Testing
### User Story 1 - Nothing is cut, covered or blank (P1)
Every page reads fully at 100 % window scale: no truncated headers, subtitles or URLs; no rows under the footer;
no blank dropdowns, squares or previews; tooltips never cover the row text.
**Independent test**: the harness walks every page and checks text widths against their regions, the scroll height
against body − FOOTER_H, and that each select has a value present in its list.

### User Story 2 - No reload anywhere (P1)
The RELOAD badges on Buffs, Cast Bars and Group Frames are gone; the owner swap applies live or through a "Switch now"
confirm.

### User Story 3 - The Movers screen is readable (P2)
Overlay boxes are clamped in size, labels never overlap, and the toolbar has two rows.

## Requirements
- FR-001 Header descriptions wrap to 2 lines (H/P4).
- FR-002 A closed group's page list wraps to two lines instead of being cut; the module dots stay (they are the on/off switches, as in EllesmereUI) but "off" reads clearly (S1, S2).
- FR-003 Home fits the body or scrolls; the glow is clipped to its card; "This week" shows data or hides (H1–H3).
- FR-004 Page scroll content ends above the footer (P6).
- FR-005 Selects fall back to the first valid entry (V1, C1 sound).
- FR-006 Row tooltips anchor to the right of the row (P5).
- FR-007 The options window scale defaults to 100 % and is independent of the UI scale (W1).
- FR-008 Movers overlays clamp to 400×200, with labels inside and a collision offset; the toolbar has 2 rows (M1–M3).
- FR-009 Encounters detects load-on-demand BigWigs (E1).
- FR-010 No RELOAD badges (P3).
- Also fixed here: About links (A1), the QoL "Combat" preview word (Q1), the AFK preview model (F1).
- Out of scope: live UF/GF previews and the crowded data bar (spec 004), the layout model (005), Sim gear grid (007), crit defaults (010).

## Success Criteria
- SC-001 All 22 issues in 15-gui-screenshots.md are fixed or moved to a named spec.
- SC-002 Harness checks for FR-001, 004, 005 and 010 pass on retail and Forever.
