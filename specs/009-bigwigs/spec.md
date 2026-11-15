# Feature Specification: Encounters: BigWigs and LittleWigs parity

**Feature Branch**: `009-bigwigs` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: BigWigs + LittleWigs | **Audit**: [05-bigwigs-littlewigs.md](../../docs/research/PLUGIN_AUDIT/05-bigwigs-littlewigs.md)

## User Scenarios & Testing

### User Story 1 - Sound (P2)
As a player, I get Sound in Phoenix in full, in the Phoenix style, in one place.

**Today**: Warning sounds critical/medium/minor (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - BossBlock (hide talking head, movies, …) (P1)
As a player, I get BossBlock (hide talking head, movies, …) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - AutoReply (whisper "in combat with X") (P1)
As a player, I get AutoReply (whisper "in combat with X") in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Victory, Wipe sounds and messages (P1)
As a player, I get Victory, Wipe sounds and messages in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Statistics (kills, wipes, best time) (P1)
As a player, I get Statistics (kills, wipes, best time) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 6 - BattleRes counter (P1)
As a player, I get BattleRes counter in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 7 - InfoBox, AltPower (P1)
As a player, I get InfoBox, AltPower in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 8 - RaidIcon (auto-mark) (P1)
As a player, I get RaidIcon (auto-mark) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 9 - Nameplates (icons on nameplates) (P1)
As a player, I get Nameplates (icons on nameplates) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 10 - Auras (P1)
As a player, I get Auras in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 11 - Colors per bar type (P2)
As a player, I get Colors per bar type in Phoenix in full, in the Phoenix style, in one place.

**Today**: Bar colour, emphasis colour (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Bars, BarStyles: Phoenix bars (width, height, texture, colour, emphasis, spark, direction) + "Phoenix bar style for BigWigs"
- Timeline (Midnight): Boss timeline
- Messages: Phoenix banner, least important shown
- Countdown: Countdown voice (start at, pull, M+/arena/BG starts, emphasised abilities)
- Pull, Break: Pull timer, Break timer, share
- Flash: Flash on critical
- Proximity: —
- Per-boss options: Boss modules (expansion › instance › boss › ability › "On the bars")

## Requirements

- **FR-001**: Phoenix MUST provide Sound (partial today).
- **FR-002**: Phoenix MUST provide BossBlock (hide talking head, movies, …) (missing today).
- **FR-003**: Phoenix MUST provide AutoReply (whisper "in combat with X") (missing today).
- **FR-004**: Phoenix MUST provide Victory, Wipe sounds and messages (missing today).
- **FR-005**: Phoenix MUST provide Statistics (kills, wipes, best time) (missing today).
- **FR-006**: Phoenix MUST provide BattleRes counter (missing today).
- **FR-007**: Phoenix MUST provide InfoBox, AltPower (missing today).
- **FR-008**: Phoenix MUST provide RaidIcon (auto-mark) (missing today).
- **FR-009**: Phoenix MUST provide Nameplates (icons on nameplates) (missing today).
- **FR-010**: Phoenix MUST provide Auras (missing today).
- **FR-011**: Phoenix MUST provide Colors per bar type (partial today).
- **FR-012**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
