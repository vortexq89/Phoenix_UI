# Feature Specification: Settings window and controls in the EllesmereUI look

**Feature Branch**: `restore/v1-ui` (no feature branch; the git extension is not installed)
**Created**: 2026-11-01
**Status**: Draft
**Input**: Rebuild map (docs/research/ELLESMERE_REBUILD_MAP.md) §8 step 1: "Shell & widgets: the EllesmereUI
window, sidebar groups, header and tab bar, footer, DualRow / triple rows, section headers, cog popups, segmented
control, sync-to-all, global search. Window-scale slider. No reload-to-apply text."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Controls look and feel like EllesmereUI (Priority: P1)
A player opens Phoenix settings and sees toggles, checkboxes, sliders, dropdowns, buttons and colour swatches that
look and move exactly like EllesmereUI's: flat shapes, faint white borders, the accent colour on "on" states.

**Why this priority**: every page uses these controls, so this is the most visible change and the base for all
later steps.

**Independent Test**: open any module page and compare the controls with EllesmereUI's at the same scale. Change
each control and see the setting apply at once.

**Acceptance Scenarios**:
1. **Given** a toggle is off, **When** the player clicks it, **Then** the knob slides right in under 0.1 s, the
   track fades from grey to the accent and the setting applies live.
2. **Given** any page, **When** it is shown, **Then** no control uses picture art, rounded pills or ember borders.
3. **Given** the accent is changed, **When** the page is open, **Then** every "on" control repaints in the new
   accent without a reload.

### User Story 2 - Window layout like EllesmereUI (Priority: P2)
The window has the EllesmereUI proportions: sidebar groups (Core, QoL, UI Reskin, Phoenix) with child rows; a
header with title, description and a tab bar for the module's pages; content in sections of two-up rows with
alternating row shading; and a footer with profile, Layout and window scale.

**Independent Test**: open the window and check the proportions (sidebar 295, header 138, tabs 40, footer 82,
content padding 45, base size 1300 × 946 scaled to fit) and the sidebar order against the map §7.

**Acceptance Scenarios**:
1. **Given** a module with several pages, **When** it is selected, **Then** its pages appear as tabs under the
   header and the last tab used is remembered.
2. **Given** a small screen, **When** the window opens, **Then** it scales down to fit and never covers more than
   the current screen limit. The footer scale slider changes it live.
3. **Given** any setting is changed, **Then** the footer never says "reload to apply".

### User Story 3 - Advanced options behind a cog, sync to all (Priority: P3)
Rows show the simple settings. Advanced sub-settings open from a small cog popup on the row, and settings shared by
several frames have a "sync to all" icon.

**Independent Test**: a row with a cog opens its popup next to the row. The popup's controls apply live. Sync copies
the value to every frame in the group.

### Edge Cases
- Combat: the window opens and controls work. Settings that touch protected frames queue until combat ends, as now.
- Forever client: the same window and controls; the accent defaults to #DCA77F.
- Locale fallback fonts (Cyrillic and CJK) still render in every control.
- Search still finds every setting after the layout change.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: Toggle 40 × 20. Square knob with a 2 px pad. Off track #444 at 0.65 and knob white at 0.5; on track
  accent at 0.75 and knob white at 1. The knob slides in 0.075 s with a C_Timer-driven step (no OnUpdate).
- **FR-002**: Checkbox box 0.112/0.105/0.098, border white 0.05 (0.15 when checked), with an accent check.
- **FR-003**: Slider track white 0.16, fill accent 0.75; a value input box 0.030/0.023/0.018 at 0.25 with a white
  0.02 border.
- **FR-004**: Dropdown background 0.103/0.095/0.088 at 0.9 (0.98 when hovered), border white 0.20 (0.30), value
  text white 0.50 (0.60); menu items highlight 0.08 on hover and 0.04 when selected; menu max height 200 with a
  4 px scroll bar.
- **FR-005**: Button background 0.089/0.080/0.072 at 0.6 (0.65), border white 0.3 (0.45), text white 0.55 (0.70).
- **FR-006**: Section header text white at 0.41, capitals. Rows are 50 high, two-up at 350 + 42 + 350 (or three-up
  at 180 / 50), with alternating black 0.1 / 0.2 shading.
- **FR-007**: Window: sidebar 295, header 138, tab bar 40, footer 82, content padding 45, base 1300 × 946. The
  sidebar groups follow the map §7. Nav text alpha: selected 1, enabled 0.6, disabled 0.11, hover 0.86.
- **FR-008**: The footer has the profile picker, Layout, Test frames and window scale. There is no "reload to apply"
  text anywhere.
- **FR-009**: A cog popup and a sync-to-all icon are available to every row type.
- **FR-010**: Every colour comes from the one theme's tokens, and the accent repaints live.
- **FR-011**: All new text strings are in all 10 locales.

### Key Entities
- **Control**: a widget bound to one setting path (get, set, live apply, refresh).
- **Row**: one, two or three controls in a shaded band; it may have a cog popup and a sync icon.
- **Page / Tab**: a module page shown as a header tab; holds sections of rows.

## Success Criteria *(mandatory)*
- **SC-001**: Side-by-side screenshots of a Phoenix page and an EllesmereUI page show the same control sizes,
  colours and spacing (within 1 px at scale 1).
- **SC-002**: 100 % of settings still apply live, and the harness live-apply checks pass.
- **SC-003**: No OnUpdate script is added; the harness OnUpdate audit passes.
- **SC-004**: Search returns the same number of settings as before the change.

## Assumptions
- Phoenix keeps its own fonts (Phoenix Font) in place of Expressway; sizes follow EllesmereUI.
- The flat black window background and the small logo stay (no theme background picture).
- The existing Renderer option types (toggle, range, select, color, …) are kept, and only their widgets and row
  layout change, so module option files do not need rewriting in this step.
