# Feature Specification: Friends

**Feature Branch**: `040-eui-friends` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: EllesmereUI Friends | **Audit**: [01-ellesmereui.md](../../docs/research/PLUGIN_AUDIT/01-ellesmereui.md) | **Parent spec**: 019-ellesmereui

## User Scenarios & Testing

### User Story 1 - Friends (P2)
As a player, I get Friends in Phoenix in full, in the Phoenix style, in one place.

**Today**: Skins › Phoenix friends window (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)


## Requirements

- **FR-001**: Phoenix MUST provide Friends (partial today).
- **FR-002**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
