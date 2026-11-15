# Feature Specification: Rares: RareScanner parity

**Feature Branch**: `018-rarescanner` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: RareScanner | **Audit**: [14-rarescanner.md](../../docs/research/PLUGIN_AUDIT/14-rarescanner.md)

## User Scenarios & Testing

### User Story 1 - Alert button with model and a secure target click (P1)
As a player, I get Alert button with model and a secure target click in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Map pins for rares, events and treasures (P2)
As a player, I get Map pins for rares, events and treasures in Phoenix in full, in the Phoenix style, in one place.

**Today**: Quests › Rare pins (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Killed / looted state per character (P1)
As a player, I get Killed / looted state per character in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Loot preview (mounts, pets, toys) on the alert (P1)
As a player, I get Loot preview (mounts, pets, toys) on the alert in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Filters (per zone, per rare, collected loot only) (P1)
As a player, I get Filters (per zone, per rare, collected loot only) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 6 - Waypoint on alert (P2)
As a player, I get Waypoint on alert in Phoenix in full, in the Phoenix style, in one place.

**Today**: waypoint arrow exists (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 7 - Navigation between rares on the alert (P1)
As a player, I get Navigation between rares on the alert in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Rare alert on vignette (sound, flash): Automation › Rare alert

## Requirements

- **FR-001**: Phoenix MUST provide Alert button with model and a secure target click (missing today).
- **FR-002**: Phoenix MUST provide Map pins for rares, events and treasures (partial today).
- **FR-003**: Phoenix MUST provide Killed / looted state per character (missing today).
- **FR-004**: Phoenix MUST provide Loot preview (mounts, pets, toys) on the alert (missing today).
- **FR-005**: Phoenix MUST provide Filters (per zone, per rare, collected loot only) (missing today).
- **FR-006**: Phoenix MUST provide Waypoint on alert (partial today).
- **FR-007**: Phoenix MUST provide Navigation between rares on the alert (missing today).
- **FR-008**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
