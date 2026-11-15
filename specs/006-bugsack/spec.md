# Feature Specification: Bugs: BugSack parity

**Feature Branch**: `006-bugsack` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: BugGrabber + BugSack | **Audit**: [02-bugsack.md](../../docs/research/PLUGIN_AUDIT/02-bugsack.md)

## User Scenarios & Testing

### User Story 1 - Auto popup on error (P1)
As a player, I get Auto popup on error in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 2 - Throttle or filter of addon mistakes (P1)
As a player, I get Throttle or filter of addon mistakes in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 3 - Mute in combat (P1)
As a player, I get Mute in combat in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 4 - Font size of the viewer (P1)
As a player, I get Font size of the viewer in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 5 - Alt-click wipe (P2)
As a player, I get Alt-click wipe in Phoenix in full, in the Phoenix style, in one place.

**Today**: Clear all reports button (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 6 - Send bugs to a player in game (P1)
As a player, I get Send bugs to a player in game in Phoenix in full, in the Phoenix style, in one place.

**Today**: — (missing).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### User Story 7 - Save as .txt (P2)
As a player, I get Save as .txt in Phoenix in full, in the Phoenix style, in one place.

**Today**: only through the VQ8S app (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Owner additions (t228 queue)

In-game send of a bug report, a .txt export, and one-click upload (to the Phoenix site), on top of BugSack parity.

### Already in Phoenix (keep, verify against the checklist)

- Capture Lua errors and warnings: Catch errors from, Lua warnings
- Blocked or forbidden actions: Blocked actions
- Store and limit reports: Reports kept
- Sessions: viewer sessions
- Viewer with search and copy: search plus copy
- Chat notice, sound, flash: chat, sound, flash
- Minimap icon: Minimap indicator
- One-click upload: Upload reports to VQ8S.com

### From the audit (fixes, conflicts, where Phoenix must be better)

- With BugSack loaded, two viewers and two minimap icons show. Detect BugSack and offer "Phoenix is your bug viewer: hide BugSack's icon", or fold under it.
- "Blizzard error window" is a toggle for the game's own window. Keep it, worded as "also show".
1. Auto popup (out of combat only) with a throttle (the same error at most once per N s) and "mute in combat".
2. Send in game: pick a group member or friend, send through `C_ChatInfo.SendAddonMessage` in chunks, and the receiver accepts in a popup. Phoenix to Phoenix only.
3. Export .txt: the viewer gets "Copy all as text" (a pre-selected edit box) and the app writes `PhoenixBugs_<date>.txt`. Nothing writes to disk from Lua (not possible).
4. A viewer layout with a list on the left and the stack on the right, local variables folded, and one-click "Copy for a report" that adds the version, build and addon list.

## Requirements

- **FR-001**: Phoenix MUST provide Auto popup on error (missing today).
- **FR-002**: Phoenix MUST provide Throttle or filter of addon mistakes (missing today).
- **FR-003**: Phoenix MUST provide Mute in combat (missing today).
- **FR-004**: Phoenix MUST provide Font size of the viewer (missing today).
- **FR-005**: Phoenix MUST provide Alt-click wipe (partial today).
- **FR-006**: Phoenix MUST provide Send bugs to a player in game (missing today).
- **FR-007**: Phoenix MUST provide Save as .txt (partial today).
- **FR-008**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
