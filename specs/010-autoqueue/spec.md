# Feature Specification: Group finder: AutoQueue parity

**Feature Branch**: `010-autoqueue` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: AutoQueue | **Audit**: [06-autoqueue.md](../../docs/research/PLUGIN_AUDIT/06-autoqueue.md)

## User Scenarios & Testing

### User Story 1 - Accept role check automatically (P2)
As a player, I get Accept role check automatically in Phoenix in full, in the Phoenix style, in one place.

**Today**: "Accept role checks with a key" (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Role from the active spec (P1)
As a player, I get Role from the active spec in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Role override (tank, healer, dps) (P1)
As a player, I get Role override (tank, healer, dps) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Role bar (small buttons) (P1)
As a player, I get Role bar (small buttons) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Keybind to queue or sign up (P2)
As a player, I get Keybind to queue or sign up in Phoenix in full, in the Phoenix style, in one place.

**Today**: Enter signs up (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)


## Requirements

- **FR-001**: Phoenix MUST provide Accept role check automatically (partial today).
- **FR-002**: Phoenix MUST provide Role from the active spec (missing today).
- **FR-003**: Phoenix MUST provide Role override (tank, healer, dps) (missing today).
- **FR-004**: Phoenix MUST provide Role bar (small buttons) (missing today).
- **FR-005**: Phoenix MUST provide Keybind to queue or sign up (partial today).
- **FR-006**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
