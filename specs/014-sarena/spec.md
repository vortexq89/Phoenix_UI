# Feature Specification: Arena: sArena Reloaded parity

**Feature Branch**: `014-sarena` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: sArena Reloaded | **Audit**: [10-sarena-reloaded.md](../../docs/research/PLUGIN_AUDIT/10-sarena-reloaded.md)

## User Scenarios & Testing

### User Story 1 - Racials (P1)
As a player, I get Racials in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Dispel cooldowns (P1)
As a player, I get Dispel cooldowns in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Interrupt cooldowns (P1)
As a player, I get Interrupt cooldowns in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Pet frames (P1)
As a player, I get Pet frames in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Dampening (P1)
As a player, I get Dampening in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 6 - Test mode (P2)
As a player, I get Test mode in Phoenix in full, in the Phoenix style, in one place.

**Today**: preview (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 7 - Layout presets (9) (P2)
As a player, I get Layout presets (9) in Phoenix in full, in the Phoenix style, in one place.

**Today**: one layout (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Arena frames (Phoenix-styled): UnitFrames › Arena layout
- DR tray: takes the game's tray and follows its CVar
- Trinkets: from the game frames
- Spec icon: yes
- Cast bar: yes
- Range fade: —
- Import/export: profiles

## Requirements

- **FR-001**: Phoenix MUST provide Racials (missing today).
- **FR-002**: Phoenix MUST provide Dispel cooldowns (missing today).
- **FR-003**: Phoenix MUST provide Interrupt cooldowns (missing today).
- **FR-004**: Phoenix MUST provide Pet frames (missing today).
- **FR-005**: Phoenix MUST provide Dampening (missing today).
- **FR-006**: Phoenix MUST provide Test mode (partial today).
- **FR-007**: Phoenix MUST provide Layout presets (9) (partial today).
- **FR-008**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
