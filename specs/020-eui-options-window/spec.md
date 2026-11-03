# Feature Specification: Options window (rail, header tabs, footer)

**Feature Branch**: `020-eui-options-window` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: EllesmereUI Options window (rail, header tabs, footer) | **Audit**: [01-ellesmereui.md](../../docs/research/PLUGIN_AUDIT/01-ellesmereui.md) | **Parent spec**: 019-ellesmereui

## User Scenarios & Testing

### User Story 1 - Options window (rail, header tabs, footer) (P2)
As a player, I get Options window (rail, header tabs, footer) in Phoenix in full, in the Phoenix style, in one place.

**Today**: Phoenix_UI_Options (have).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Options window (rail, header tabs, footer): Phoenix_UI_Options

## Requirements

- **FR-001**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
