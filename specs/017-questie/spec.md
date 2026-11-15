# Feature Specification: Quests: Questie parity

**Feature Branch**: `017-questie` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: Questie | **Audit**: [13-questie.md](../../docs/research/PLUGIN_AUDIT/13-questie.md)

## User Scenarios & Testing

### User Story 1 - Objectives on the map (mobs, objects) (P2)
As a player, I get Objectives on the map (mobs, objects) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Journey log / quest history (P1)
As a player, I get Journey log / quest history in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Data coverage (P2)
As a player, I get Data coverage in Phoenix in full, in the Phoenix style, in one place.

**Today**: Midnight, TWW, Azeroth (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Available quests on the map and minimap: Available quest lines, Quest givers from data, Pins on the minimap
- Turn-in spots: yes
- Waypoint arrow, distance, ETA: yes
- Tracker: Objective tracker restyle
- Quest tooltips (on mobs and items): Quest tooltips
- Hide low-level, filter by level: Hide low-level quests
- Townsfolk (vendors, trainers, flight): Townsfolk pins
- Auto-accept / turn-in: yes
- Announce progress: yes
- Recorded NPC positions: yes (Phoenix's own crowd data)

## Requirements

- **FR-001**: Phoenix MUST provide Objectives on the map (mobs, objects) (partial today).
- **FR-002**: Phoenix MUST provide Journey log / quest history (missing today).
- **FR-003**: Phoenix MUST provide Data coverage (partial today).
- **FR-004**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
