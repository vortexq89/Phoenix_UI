# BigWigs, LittleWigs, BigWigs_Classic, BigWigs_Voice

Studied: the installed copies in the user's AddOns (BigWigs core/plugins/options, 14 raid packs incl. The Voidspire,
March on Quel'Danas, Midnight Lairs/World; LittleWigs + 10 packs incl. `Midnight/` dungeons and Delves) and the
BigWigsMods GitHub org (BigWigs pushed 2026-10-21, LittleWigs 2026-10-18).

## Licence
No licence file in BigWigs, LittleWigs, BigWigs_Classic or BigWigs_Voice (GitHub reports none) = **all rights
reserved**. GitHub's ToS lets people fork on GitHub; it does not grant reuse in another addon. Phoenix: **clean-room
only**; the BigWigs sound/voice packs and icons may not be bundled.

## How it is built (what we learned)
- **Loader + load-on-demand packs.** A tiny `BigWigs` loader knows zone → pack (`Loader.lua` maps instance IDs to
  addons) and loads the zone pack only on zone-in. Options are a separate LoD addon. Per-flavour `Init_*.lua`
  (`Init_Camelot.lua` sets `isForever`) and one multi-interface TOC (`11508 … 120105, 16001`).
- **Boss module = small declarative file.** `BigWigs:NewBoss(name, journalInstanceID, journalEncounterID)`,
  `RegisterEnableMob(npcID)`, `SetEncounterID(dungeonEncounterID)`, `SetRespawnTime`, `GetOptions()` returning
  spell IDs (each becomes a row with bar / message / sound / emphasise / countdown flags), `SetRenames` (short
  labels such as "Soak", "Adds"), `SetPrivateAuraSounds`.
- **Midnight boss mods are timeline fingerprinting.** `mod:UseCustomTimers(true)`; the module listens to
  `ENCOUNTER_TIMELINE_EVENT_ADDED/STATE_CHANGED/REMOVED` and identifies each Blizzard timeline event by its
  **rounded duration** and per-phase counters (e.g. Averzian: 160 s = Void Fall, 32 s = Umbral Collapse), because
  `spellID`, `spellName` and `iconFileID` are secret during encounters while `id`, `source`, `duration`,
  `maxQueueDuration` are `NeverSecret` (EncounterTimelineDocumentation.lua, 12.1.5). These tables are hand-made
  each tier from logs by the BigWigs team.
- **Timeline plugin** offers three modes: BigWigs bars ("enhanced"), Blizzard timeline as bars, Blizzard timeline
  as-is; it exposes Blizzard CVars (`encounterTimelineEnabled`, `…HideLongCountdowns`, `…HideQueuedCountdowns`,
  `…HideForOtherRoles`, `…IconographyEnabled`, `…IconographyHiddenMask` bitfield) and a **Test** button that calls
  `C_EncounterTimeline.AddEditModeEvents()` in a loop. It mutes Blizzard's Critical/Medium/Minor warning frames.
- **Plugins** (flavour-gated in code comments): Bars, BarStyles (public `RegisterBarStyle` API), Messages,
  Sounds, Colors, Countdown (voices), Flash, InfoBox, Pull/Break (retail uses `C_PartyInfo.DoCountdown`),
  BattleRes, BossBlock (talking head/emote suppression), Statistics (kills/wipes/best time), Victory, Wipe,
  Auras (Retail & Forever), Timeline (Retail only). Proximity, Raid Icons, Nameplates, AutoReply are **Classic
  only** now — the Midnight rules removed them on retail.
- **UX:** every plugin has *Test* and *Anchors*; per-ability rows with compact flag toggles; profile sharing
  strings; a statistics view per boss and difficulty.

## Game facts it relies on, and where Phoenix gets them
| Fact | BigWigs source | Phoenix source |
|---|---|---|
| Instance / encounter / boss IDs, names, order | hand-entered | DB2 `JournalInstance`, `JournalEncounter` (DungeonEncounterID, OrderIndex, UiMapID), `JournalEncounterCreature` |
| Ability list per boss, spell IDs, descriptions, role icons | hand-entered | DB2 `JournalEncounterSection` (28 459 rows: Title, BodyText, SpellID, IconFlags, Type, parent/child tree) |
| Timer durations per ability | logs, hand-maintained | **not in client data**; only observable at runtime (timeline `duration`, never secret). Phoenix does not maintain per-boss timer tables (see plan) |
| Private aura spell IDs | hand-entered | `JournalEncounterSection.SpellID` is a candidate list; confirmation requires logs — not maintained by Phoenix |
| Zone → pack | hand-entered | DB2 `JournalInstance.MapID` + `MapChallengeMode` |

## How Phoenix does it better (without duplicating BigWigs)
1. **Encounters module = the best skin and control panel for Blizzard's own system**: Phoenix-styled timeline bars and
   warnings (theme fonts/textures, role colours, icon masks), every Blizzard CVar on one page with live preview and a
   Test button, Edit Mode placement — zero per-boss upkeep, works for every boss on day one.
2. **Boss journal card** generated from DB2 (abilities tree with role icons, spell tooltips) in the pinned preview
   style — BigWigs has no journal view.
3. **Bridge, not rival:** when BigWigs/LittleWigs is loaded, Phoenix registers a bar style through
   `BigWigsAPI:RegisterBarStyle` so their bars wear the Phoenix look; Phoenix's own bars stand down to avoid two
   timers for one event.
4. Pull/break timers (`C_PartyInfo.DoCountdown`, `C_EncounterTimeline.AddScriptEvent` for break) and the Phoenix
   countdown voice already in Tracker move here once — one owner.
5. Statistics (kills, wipes, best time per difficulty) from `ENCOUNTER_START/END` (allowed events).
