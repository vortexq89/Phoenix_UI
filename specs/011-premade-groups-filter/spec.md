# Feature Specification: Group finder: Premade Groups Filter parity

**Feature Branch**: `011-premade-groups-filter` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: Premade Groups Filter | **Audit**: [07-premade-groups-filter.md](../../docs/research/PLUGIN_AUDIT/07-premade-groups-filter.md)

## User Scenarios & Testing

### User Story 1 - Per-category panels (Dungeon, Raid, Arena, RBG, Delve) (P2)
As a player, I get Per-category panels (Dungeon, Raid, Arena, RBG, Delve) in Phoenix in full, in the Phoenix style, in one place.

**Today**: one filter panel (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Persist sign-up note (P1)
As a player, I get Persist sign-up note in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Compact list entries (P1)
As a player, I get Compact list entries in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Region or realm (PremadeRegions) (P1)
As a player, I get Region or realm (PremadeRegions) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Dungeon picker (per-dungeon checkboxes) (P1)
As a player, I get Dungeon picker (per-dungeon checkboxes) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Difficulty, role slots, members, item level, rating, age: yes
- Expression filter: Filter expression
- One-click sign up, Enter signs up: yes
- Role and spec indicators on the list: Specialization icons, class strip
- Lockout hint: Raid lockout hint
- Application status (declined dimming): Dim groups that declined you
- Leader score and best key: yes

## Requirements

- **FR-001**: Phoenix MUST provide Per-category panels (Dungeon, Raid, Arena, RBG, Delve) (partial today).
- **FR-002**: Phoenix MUST provide Persist sign-up note (missing today).
- **FR-003**: Phoenix MUST provide Compact list entries (missing today).
- **FR-004**: Phoenix MUST provide Region or realm (PremadeRegions) (missing today).
- **FR-005**: Phoenix MUST provide Dungeon picker (per-dungeon checkboxes) (missing today).
- **FR-006**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
