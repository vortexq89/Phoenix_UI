# Feature Specification: Combat Text: MikScrollingBattleText parity

**Feature Branch**: `012-msbt` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: MikScrollingBattleText | **Audit**: [08-mikscrollingbattletext.md](../../docs/research/PLUGIN_AUDIT/08-mikscrollingbattletext.md)

## User Scenarios & Testing

### User Story 1 - Crits (size, area, sound) (P2)
As a player, I get Crits (size, area, sound) in Phoenix in full, in the Phoenix style, in one place.

**Today**: yes, but **greyed out, 0 %, blank sound** in the screenshot (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Cooldown notifications (spell ready) (P1)
As a player, I get Cooldown notifications (spell ready) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Loot and money, honour, reputation notices (P2)
As a player, I get Loot and money, honour, reputation notices in Phoenix in full, in the Phoenix style, in one place.

**Today**: partial (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Per-event colour, font and sound (P2)
As a player, I get Per-event colour, font and sound in Phoenix in full, in the Phoenix style, in one place.

**Today**: area colour plus one sound (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - MSBT fonts (P2)
As a player, I get MSBT fonts in Phoenix in full, in the Phoenix style, in one place.

**Today**: Combat font list (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Scroll areas (add, remove, name, position, size): yes
- Animations and direction, alignment, time on screen: yes
- Incoming, outgoing, notifications, power gains: yes
- Merge rapid hits, throttle: yes
- Triggers (custom) and import from MSBT: yes
- Spell icon, skill name: yes

## Requirements

- **FR-001**: Phoenix MUST provide Crits (size, area, sound) (partial today).
- **FR-002**: Phoenix MUST provide Cooldown notifications (spell ready) (missing today).
- **FR-003**: Phoenix MUST provide Loot and money, honour, reputation notices (partial today).
- **FR-004**: Phoenix MUST provide Per-event colour, font and sound (partial today).
- **FR-005**: Phoenix MUST provide MSBT fonts (partial today).
- **FR-006**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
