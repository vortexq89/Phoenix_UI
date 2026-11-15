# Feature Specification: Spell History: TrufiGCD parity

**Feature Branch**: `013-trufigcd` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: TrufiGCD | **Audit**: [09-trufigcd.md](../../docs/research/PLUGIN_AUDIT/09-trufigcd.md)

## User Scenarios & Testing

### User Story 1 - Party, arena and target units (one queue per unit) (P1)
As a player, I get Party, arena and target units (one queue per unit) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Spell blocklist (P1)
As a player, I get Spell blocklist in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Tooltip on hover (P1)
As a player, I get Tooltip on hover in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Moved in Layout (P2)
As a player, I get Moved in Layout in Phoenix in full, in the Phoenix style, in one place.

**Today**: own "Move" row (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Player cast icon queue: yes
- Icon size, count, direction, spacing: yes
- Fade time, only in combat: yes
- Interrupted or failed mark: yes
- Masque: — (Phoenix style)

## Requirements

- **FR-001**: Phoenix MUST provide Party, arena and target units (one queue per unit) (missing today).
- **FR-002**: Phoenix MUST provide Spell blocklist (missing today).
- **FR-003**: Phoenix MUST provide Tooltip on hover (missing today).
- **FR-004**: Phoenix MUST provide Moved in Layout (partial today).
- **FR-005**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
