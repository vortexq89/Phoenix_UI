# Feature Specification: EllesmereUI: every module, better (umbrella)

**Feature Branch**: `019-ellesmereui` (work lands on `restore/v1-ui`)
**Created**: 2026-11-03 | **Status**: Draft | **Owner request**: t229 (one spec per plugin and feature)
**Source**: EllesmereUI (all modules) | **Audit**: [01-ellesmereui.md](../../docs/research/PLUGIN_AUDIT/01-ellesmereui.md)

## User Scenarios & Testing

### User Story 1 - Options window (rail, header tabs, footer) (P2)
As a player, I get Options window (rail, header tabs, footer) in Phoenix in full, in the Phoenix style, in one place.

**Today**: have (have).

**Acceptance**: 1) Given the module is on, when I open its page, then the option(s) are there with a live preview. 2) When I change them, the frame changes at once. 3) It works on retail and Forever, in combat where allowed.

This umbrella spec only tracks the per-module specs listed in specs/INDEX.md; each module is built from its own spec.

### Already in Phoenix (keep, verify against the checklist)

- Options window (rail, header tabs, footer): have
- UnitFrames: partial
- RaidFrames: partial
- Nameplates: have
- ActionBars (+XP/rep bars): have
- CooldownManager: have
- ResourceBars: partial
- AuraBuffReminders: have
- Bags: have
- Chat: have
- DamageMeters: have
- DataBars: partial
- Friends: partial
- GroupFinder: have
- Minimap: have
- MythicTimer: have
- QoL: partial
- QuestTracker: have
- BlizzardSkin: partial
- Quickdraw (macro/keybind helper): **missing**
- ForeverEssentials: partial
- WindTools (326 files): partial

### From the audit (fixes, conflicts, where Phoenix must be better)

1. **Live previews** on every frame page (EUI shows real frames; ours are empty or grey placeholders).
2. **No RELOAD badges.** Constitution IV says "every setting live", but the Buffs, Cast Bars and Group Frames "drawn by" rows still carry them. Make them live or move them to an explicit swap action.
3. **Search plus the cog for advanced rows** (FoldAdvanced) on every page; EUI has no search across pages.
4. **One layout model** (INDEX §2); EUI also mixes its unlock mode with Edit Mode.
5. **Onboarding:** first-run module picker, What's new (built) and a Home that fits at 100 % scale.

## Requirements

- **FR-001**: Every item of the feature checklist ([checklist.md](checklist.md)) MUST be met.

## Success Criteria

- **SC-001**: every parity row of the audit reads **have** or better.
- **SC-002**: the checklist is fully ticked, with evidence (harness test or screenshot) per line.
- **SC-003**: no duplicate feature or second place in the GUI; the harness, luacheck, check_locales and CI pass.
