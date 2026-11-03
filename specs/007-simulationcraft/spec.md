# Feature Specification: Sim: SimulationCraft parity

**Feature Branch**: `007-simulationcraft` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: SimulationCraft | **Audit**: [03-simulationcraft.md](../../docs/research/PLUGIN_AUDIT/03-simulationcraft.md)

## User Scenarios & Testing

### User Story 1 - Auto-select all equipped gear and copy in one click (P2)
As a player, I get Auto-select all equipped gear and copy in one click in Phoenix in full, in the Phoenix style, in one place.

**Today**: Pick gear (manual list) (partial).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

### Already in Phoenix (keep, verify against the checklist)

- Export of the equipped profile string: Export.lua (simc format)
- Bag items in the export: Pick gear
- Bank and Great Vault: Include bank / Include Great Vault
- Copy box: yes
- Run a sim and show results: through the Phoenix app (Bridge)
- Fight style, targets, length: yes
- Results history: Last 10 sims
- Results in tooltips: Tooltip › Sim results

### From the audit (fixes, conflicts, where Phoenix must be better)

1. The default selection is every equipped item, and a "Copy string" button sits in the page header.
2. The gear list is a 2-column grid of 46 px slots with a scrollbar, without the "(scroll)" text.
3. A results card per spec and gear set, comparing DPS with the last run.

## Requirements

- **FR-001**: Phoenix MUST provide Auto-select all equipped gear and copy in one click (partial today).
- **FR-002**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
