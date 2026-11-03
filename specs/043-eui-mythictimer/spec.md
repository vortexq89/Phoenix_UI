# Feature Specification: MythicTimer

**Feature Branch**: `043-eui-mythictimer` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: EllesmereUI MythicTimer | **Audit**: [01-ellesmereui.md](../../docs/research/PLUGIN_AUDIT/01-ellesmereui.md) | **Parent spec**: 019-ellesmereui

## User Scenarios & Testing

### User Story 1 - MythicTimer (P2)
As a player, I get MythicTimer in Phoenix in full, in the Phoenix style, in one place.

**Today**: MythicPlus (36) (have).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- MythicTimer: MythicPlus (36)

## Requirements

- **FR-001**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
