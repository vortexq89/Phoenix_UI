# In-game checks still needed (PRs #31-#47)

The offline harness runs every test without drawing anything, so nothing in PRs #31-#47 has been verified in the client yet (PLAN §2: "Nothing below has been verified in game yet"). Each item needs a pass on 12.1.5 retail, and on Forever where noted, with zero Sentinel incidents in a session that uses the feature. This list is gathered from PLAN, DEFERRED, the step-status lines and the deferred batches A-D.

## Across all PRs
- [ ] Every screen against its mockup: options 01-04, wizard 05-11, Studio 12, menu and minimap 13, Sentinel 14, HUD 15. Check at 1080p and 1440p and at pixel scale. Fix spacing and fonts.
- [ ] Esc menu row: open it in and out of combat 20 times, then click Logout, Exit, Options and AddOns after using Phoenix's row. `/pui sentinel` should show no taint, and `/console taintLog 2` should stay clean.
- [ ] Every "applies live" setting really applies without /reload. Spot-check each module page with its preview open.
- [ ] Skins audit, plus the quality of each skin pack.

## Options & Core (PRs #31-#32)
- [ ] Profiles manager: create, copy, rename and delete (1.6).
- [ ] Spec auto-switch, in town and in combat (deferred) (1.7).
- [ ] Spec and condition overrides: party, raid, arena, BG, solo and keybind layers (1.8, 1.9).
- [ ] Ledger page and "Uninstall Phoenix" restore only Phoenix-owned values (1.22). Disabling Nameplates gives the CVars back.
- [ ] Copy dialog and chat links (1.26). Own confirm and keep-or-revert dialogs (1.27).
- [ ] PUI.Season: live season IDs, dungeons and affixes (1.28).
- [ ] Shared services: Mouse, Range, Glow and Format (1.29).
- [ ] Diagnostics `/pui diag` and the profiler `/pui profile` (1.31, 1.32).
- [ ] UF anchored to a CDM bar: resize the CDM and the UF follows; entering combat mid-drag is safe.

## Unit Frames (PR #33) and Raid Frames
- [ ] Secure buttons, click-cast registration and menus.
- [ ] Private-aura anchors on addon frames, each tier (`rf.privateAuras`). AnimatedHealthLoss on addon frames.
- [ ] PUI.Auras: auras correct in an M+ key and on a raid boss (restricted), with zero Lua errors and no per-frame Lua in the Ticker.
- [ ] Free party placement (batch B): secure buttons and state drivers.

## Nameplates (PR #35)
- [ ] Batch A extras: totem and pet plates, range fade, "interrupted by", NPC subtitles and quest text (C_TooltipInfo), hit-box insets (C_NamePlateManager), hover highlight, aura and pandemic glows, purge glow, pool pre-warm, rule conditions, Blizzard driver suppression, the slot layout editor.

## Action Bars, Cooldown Manager, Resource Bars (PR #36)
- [ ] Micro menu and bag bar, extra and zone ability movers, flyout reskin, pet autocast right-click, keybind mouse capture, per-button overrides, Classic looks and masks, cooldown threshold colours (secret-safe curve), hide in housing and gamepad, Edit Mode capture, reverse CDM dedupe.
- [ ] CDM: hidden spells, glow conditions, tracking-bar reskin, focus kick bar, rotation assist, audio cues, per-spell import, crafted-quality rank.
- [ ] Resources: coverage of every class resource, latency overlay and channel ticks, empower stages, GCD modes, spec helpers on hidden aura slots, threshold curves, bar shifting.

## Studio (PR #37) and HUD (PR #38)
- [ ] Studio: connectors, resize grips, grow buttons, thumbnails, the ElvUI importer, the Blizzard page, Blizzard fades re-evaluated.
- [ ] Tooltip: inspect item level and spec, transmog and upgrade-track lines, tier-set count, achievement, artifact, follower and pet-battle ID lines.
- [ ] Minimap: Phoenix tracking, calendar and mail buttons. Data Bars: LDB host, secure hearth and profession blocks, per-spec sets. The Skins queue-pop timer.

## Quest Tracker, Reminders, Embers, Ascent (PR #40)
- [ ] Quest-item secure buttons (out of combat only) and auto-share.
- [ ] Reminders: the paladin aura and the hunter Marksmanship no-pet spec. The season consumable and weapon-oil ID pack (still empty). Talents by zone. Sound and icon overrides.
- [ ] Embers: show/hide and reset hotkeys (Binding ledger), snapping, the threat warning on Forever and retail.
- [ ] Ascent: current-pull forces, the score projection constants (`AS.SCORE`), `/pui vaultplan`.

## Flow, Group Finder, Raid Tools (PR #41)
- [ ] Flow: leave-queue popups, open containers, Train All, tutorials and banners, `/gg`, queue protection, the Tab binder, screenshot on achievement.
- [ ] Group Finder: the Raider.IO `rio` and `riomain` words (RaiderIO.GetProfile), LibRealmInfo `samelang` and the `[DE]` badge, plugin sorts, the word list, the detached panel mover.
- [ ] Raid Tools: the notes window hides in combat and returns after it. Boss tooltip line (TooltipDataProcessor). Stats window.

## Pulse, Arena, Spark, Cast History (PR #42)
- [ ] Pulse: the next-three HUD on a real boss, per-boss rules, `C_EncounterTimeline.SetViewType` hide and restore, the BigWigs `RegisterBarStyle` bridge.
- [ ] Arena: pet frames (RegisterUnitWatch), the class-icon aura filters, the dispel tracker spell IDs, the range-fade spells per class, the click-binding list, text sizes, FrameSort `GetEnemyUnits`, the CVar `spellDiminishPVPOnlyTriggerableByMe`, healer-only variants.
- [ ] Spark: per-event sounds, aura gain and fade, substitutions, the trigger builder, MSBT import against a real `MSBTProfiles_SavedVars`.
- [ ] Cast History: the Masque group, Alt+click on the compartment entry, the Embers "Casts" button.

## PvP, Friends, Sentinel, Diagnostics (PR #43)
- [ ] PvP: `GetPersonalRatedInfo` bracket indexes 7 (Shuffle) and 9 (Blitz), LeaveBattlefield from the Ticker, Training Grounds queue calls, the conquest overlay on ConquestFrame, automatic Legend and Strategist IDs (category scan), the history window, header drag, Shuffle rounds once plain.
- [ ] Friends: the FriendsFrame_UpdateFriendButton hook, the recent allies data shape, the BNet note dialog, icon themes, frame border and tab line, add-friend suggestions on AddFriendNameEditBox.
- [ ] Sentinel: the capture path (`/pui sentinel induce`), in-game report sharing (offer, accept, chunks, checksum), the media-library error sounds (PlaySoundFile), the baseline warning, the event trace.

## Deferred batch D (PR #47)
- [ ] BugGrabber shim: with !BugGrabber alone, `PhoenixUIBugDisplay` is picked from the TOC field and BugGrabber stops its own chat line. With BugSack loaded, BugSack still wins.
- [ ] Developer recorder: rows while zoning, in combat and grouping. A recording left open by a client crash after a /reload comes back as "recovered".
- [ ] Self-measurement: the `C_AddOnProfiler` signature check passes on 12.1.5 and on Forever. `GetTopKAddOnsForMetric` returns `addOnName` / `metricValue` rows. `MeasureCall` returns `elapsedMilliseconds`.
- [ ] Diagnostics page, the CPU chip hover readout, the A/B window.
- [ ] Privacy allow-list with a character whose name matches an addon folder.
- [ ] Fixed-in paste import: a Companion `fixed-string` output decodes in game (C_EncodingUtil deflate and base64 match Python's raw deflate).
- [ ] Forever child (Forever client only): `TakeTaxiNode` post-hook slot indexes match `C_TaxiMap.GetAllTaxiNodes` `slotIndex`. `PLAYER_CONTROL_LOST` / `GAINED` with `UnitOnTaxi` around flights. `C_PetInfo.GetPetHappiness` returns 1-3 and a loyalty rate. `UNIT_PET` fires on summon and dismiss.
- [ ] Forever spellbook and talent skins (Forever client, Skins on): SpellButton1-12 get the Phoenix slot frame and fonts, the rank line is muted (toggle Spell ranks off: Blizzard colour back), skill-line and bottom tabs have Phoenix faces; the talent window shows rings on maxed, chosen and pickable talents and updates on a point spent; no blocked-action message.
- [ ] Forever fishing helper (Forever page, turn on): casting Fishing shows the bar with the time left, catches count up on each fishing loot, the louder-splash option raises sound effects during the cast and restores them after.

## Still blocked (no in-game check will fix these)
- Swing timer on retail only (no combat log; Forever has it), line-of-sight fade, Group Finder lockout filters and cancel-oldest, Pulse private-aura sounds, Friends app-only removal (taint).
