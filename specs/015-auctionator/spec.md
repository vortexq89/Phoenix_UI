# Feature Specification: Auction house: Auctionator parity

**Feature Branch**: `015-auctionator` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: Auctionator | **Audit**: [11-auctionator.md](../../docs/research/PLUGIN_AUDIT/11-auctionator.md)

## User Scenarios & Testing

### User Story 1 - Undercut alert (P2)
As a player, I get Undercut alert in Phoenix in full, in the Phoenix style, in one place.

**Today**: Automation › Auction undercut (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Shopping lists (import/export) (P1)
As a player, I get Shopping lists (import/export) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - One-click selling (price memory, undercut %) (P1)
As a player, I get One-click selling (price memory, undercut %) in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Cancel undercut auctions (P1)
As a player, I get Cancel undercut auctions in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Posting history (P1)
As a player, I get Posting history in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 6 - Price database plus tooltip prices (P1)
As a player, I get Price database plus tooltip prices in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (vendor price only) (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 7 - Crafting cost / profit in Professions (P1)
As a player, I get Crafting cost / profit in Professions in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- AH skin: Skins › Auction house
- Open bags at the AH: Bags

## Requirements

- **FR-001**: Phoenix MUST provide Undercut alert (partial today).
- **FR-002**: Phoenix MUST provide Shopping lists (import/export) (missing today).
- **FR-003**: Phoenix MUST provide One-click selling (price memory, undercut %) (missing today).
- **FR-004**: Phoenix MUST provide Cancel undercut auctions (missing today).
- **FR-005**: Phoenix MUST provide Posting history (missing today).
- **FR-006**: Phoenix MUST provide Price database plus tooltip prices (missing today).
- **FR-007**: Phoenix MUST provide Crafting cost / profit in Professions (missing today).
- **FR-008**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
