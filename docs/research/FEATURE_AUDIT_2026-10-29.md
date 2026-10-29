# Phoenix UI feature audit (2026-10-29)

Read-only review of every Phoenix UI system on `restore/v1-ui` at 8eed84c (2026-10-29 18:32 Kuwait time, UTC+3).
References: EllesmereUI v9.6.1 (main reference; `docs/research/ellesmereui.md`, `ELLESMERE_GAP_AUDIT.md`), ElvUI,
and the addons listed in `docs/research/FEATURE_COVERAGE.md`. The references were studied for features and UX
only. No code or assets from them are used.

## How to read this
- **Built**: the code exists in this branch (path cited).
- **Harness**: the offline smoke harness (`tools/smoke/harness.lua`, 231 named `try(...)` tests) covers it.
  "Mentions" is the number of harness lines that name the module. It shows breadth of coverage, not proof the feature works.
- **In game**: **no feature in this audit has been checked in a structured way in the live game.** The only in-game
  evidence is the 2026-10-28 options-window self-test screenshots (`VISUAL_DEFECTS.md`, 20 defects: 12 fixed,
  2 to verify, 6 open). That run looked only at the options window. It did not cover combat, raids, nameplates in
  the world, or arenas.
- **Score**: 1-10 for feature depth and polish compared with the best reference, judged from the code and options.
  The scores are a code review, not a play test.
- Options are counted as `key =` rows in `Phoenix_UI_Options/Options/<Module>.lua`. Every module has a live
  preview (`Phoenix_UI_Options/Previews/`).

## Per-system table
| System | Path | Files/lines | Options | Harness mentions | Reference | Score |
|---|---|---|---|---|---|---|
| Unit frames (+arena, resources, imbues) | Modules/UnitFrames | 8 / 4258 | 249 | 24 | EllesmereUI UF + Resource Bars, ElvUI UF | 8 |
| Nameplates | Modules/NamePlates | 4 / 1511 | 147 | 26 | EllesmereUI Nameplates, Plater | 8 |
| Action bars (+ring, uprank) | Modules/ActionBars | 6 / 1667 | 111 | 23 | EllesmereUI AB + Quickdraw, ElvUI AB | 8 |
| Cast bars | Modules/CastBars | 7 / 1804 | 90 | 12 | ElvUI, Quartz-style | 8 |
| Chat | Modules/Chat | 5 / 1176 | 56 | 11 | EllesmereUI Chat, ElvUI Chat | 8 |
| Tooltip | Modules/Tooltip | 2 / 757 | 51 | 10 | ElvUI Tooltip, idTip | 8 |
| Minimap (+reveal, zone levels) | Modules/Minimap | 4 / 1993 | 40 | 11 | EllesmereUI Minimap + Forever Essentials | 8 |
| Skins (own windows) | Modules/Skins | 49 / 6921 | 68 | 60 | EllesmereUI Blizzard Skin, ElvUI Skins | 8 |
| Group frames | Modules/GroupFrames | 4 / 1141 | 150 | 3 | EllesmereUI Raid Frames, ElvUI, Grid2 | 7 |
| Auras | Modules/Auras | 3 / 750 | 61 | 3 | ElvUI Auras | 7 |
| Tracker (CDM, reminders, glows) | Modules/Tracker | 4 / 1602 | 89 | 15 | EllesmereUI CDM + Aura Reminders | 7 |
| Bags | Modules/Bags | 5 / 1605 | 41 | 15 | EllesmereUI Bags, ElvUI Bags | 7 |
| Data texts / data bars | Modules/DataTexts | 3 / 948 | 65 | 8 | EllesmereUI Data Bars, ElvUI DT | 7 |
| Mythic+ (timer, keys) | Modules/MythicPlus | 3 / 964 | 29 | 10 | EllesmereUI Mythic Timer | 7 |
| Group finder | Modules/GroupFinder | 7 / 1517 | 62 | 10 | EllesmereUI Group Finder, PGF | 7 |
| Quests (tracker, arrow, pins) | Modules/Quests | 8 / 1682 | 50 | 10 | EllesmereUI Quest Tracker, TomTom | 7 |
| Movers / layout mode | Modules/Movers | 3 / 933 | 22 | 14 | EllesmereUI unlock, ElvUI movers | 7 |
| Bugs (capture + viewer) | Modules/Bugs, Core/Errors.lua | 2 / 650 | 21 | 6 | BugSack | 7 |
| Encounters (timeline, warnings, BigWigs) | Modules/Encounters | 4 / 902 | 56 | 8 | BigWigs / DBM | 6 |
| Automation (macros, undercut, rares) | Modules/Automation | 9 / 948 | 41 | 10 | EllesmereUI QoL | 6 |
| Cooldown text | Modules/CooldownText | 1 / 226 | 17 | 4 | OmniCC | 6 |
| Item level / stats | Modules/ItemLevel | 3 / 504 | 19 | 9 | SimpleItemLevel | 6 |
| Quality / professions | Modules/Quality | 3 / 777 | 45 | 8 | - | 6 |
| Sim export | Modules/Sim | 2 / 786 | 19 | 8 | SimulationCraft addon | 6 |
| General | Modules/General | 1 / 130 | 41 | 14 | ElvUI General | 6 |
| Damage meter | Modules/DamageMeter | 2 / 315 | 22 | 6 | EllesmereUI Damage Meters, Details! | 5 |
| Combat text | Modules/CombatText | 2 / 221 | 22 | 4 | MSBT / xCT | 5 |
| PvP | Modules/PvP | 1 / 170 | 16 | 7 | - | 5 |
| Spell history | Modules/SpellHistory | 1 / 168 | 13 | 4 | - | 5 |
| AFK screen | Modules/AFK | 1 / 163 | 11 | 5 | ElvUI AFK | 5 |
| Core, options, profiles, installer | Core/, Phoenix_UI_Options/ | 25 / 4629 (Core) | - | most tests | EllesmereUI options | 8 |

**Overall: 6.7 / 10** (unweighted mean of the 31 rows). The feature breadth is close to EllesmereUI and ahead of it
in several places. The biggest drop comes from the "in game" column: nothing in this audit has been verified in game.

## Per system: features, depth, gaps, risks, next steps

### Unit frames - 8
- **Features:** player/target/focus/pet/ToT/boss/arena units; portrait (shape, ring, zoom, art), absorb, cast,
  class power, resources (`Modules/UnitFrames/Resources.lua`), totems, imbues (`Imbues.lua`), range and out-of-combat
  fade, mirrored layouts, nicknames, quick focus. Arena: the game's own DR trays and the trinket re-parented into Phoenix
  frames (`Arena.lua:7-23`). 12.x sends these values as secrets, so this is the secret-safe route.
- **Depth vs reference:** 249 options, more than EllesmereUI UF. Resource thresholds/hash lines were listed as missing
  in `ellesmereui.md`; they are now partly covered by Resources.lua (threshold depth not checked).
- **Gaps:** no conditional (in combat / in group) per-unit overrides (unverified, likely absent).
- **Risks:** largest module (4258 lines). Arena re-parenting of Blizzard trays is untested in rated arenas.
- **Next:** in-game check of arena DR/trinket in a skirmish; boss frames in an encounter.

### Nameplates - 8
- **Features:** per-context styles (enemy/friendly/name-only), threat by role, execute range, focus/target highlight,
  quest icons, cast bar, auras, health tags (`Phoenix_UI_Options/Options/NamePlates.lua`).
- **Depth:** 147 options, close to Plater's core without scripting.
- **Gaps:** no per-NPC colour/scripting list (Plater-style), unverified.
- **Risks:** nameplates in the world have never been looked at in game (VISUAL_DEFECTS.md says so).
- **Next:** dungeon run with threat colours as tank and as DPS.

### Action bars - 8
- **Features:** bars with rows, wrap, growth, visibility macro, paging, range tint, cooldown desaturation, quality
  border, micro/bags bars, vehicle/extra buttons, quick ring (`Ring.lua`, the Quickdraw-style radial), uprank (`Uprank.lua`, Forever).
- **Gaps:** no built-in quick keybind mode (`ELLESMERE_GAP_AUDIT.md`; rg finds none).
- **Risks:** secure-frame changes in combat, guarded with `combat = true` rows.
- **Next:** add a keybind mode, then check paging for every class in game.

### Cast bars - 8
- 7 files, 90 options. Preview zero-width bug fixed (VISUAL_DEFECTS #1). Next: interrupt-ready colouring check in game.

### Chat - 8
- URLs, copy, keyword alerts and sound, whisper tabs, history, fade, short channels, role/raid icons, item levels in
  links, armory link, chat bar with pull timer (`Modules/Chat/Bar.lua:204`). On par with ElvUI.
- **Risks:** chat message filters running on secret strings in instances. Next: an instance chat check.

### Tooltip - 8
- Item/spell IDs (`Options/Tooltip.lua:93`), M+ rating, keystone, inspect item level, target-of, targeted-by, BiS list, sim line,
  vendor price, mount, collected. Ahead of ElvUI on content. Risk: inspect throttling in raids.

### Minimap - 8
- Shapes (live fix this session), addon button bin, coords, zone levels, zone text, mail/difficulty/crafting order
  icons, world map coords/scale. Forever map reveal (`Reveal.lua`, 141 lines, plus `RevealData.lua`, 1251 lines /
  52 KB generated by `tools/mapreveal/build.py`; harness test "map reveal").
- Risk: reveal tiles are only harness-checked. Next: walk 3 unexplored zones on Forever.

### Skins - 8
- 49 files, 60 harness mentions. Own replacement windows (character, friends, guild, journal, loot, mail with alts,
  merchant, professions, quest log, vault, collections, calendar, achievements) and skins for the rest.
- Ahead of EllesmereUI on own windows. Risk: highest Blizzard-UI taint surface. VISUAL_DEFECTS #20 (Alts, Shift-drag) is still "verify".

### Group frames - 7
- Party/raid/tank/pet headers, sort (group/role/class/name), role order, dispel highlight (mine only), group
  buffs/debuffs, defensives, private auras with countdown, absorbs/heal-absorbs, ready/role/leader/marker/phase/threat
  icons, range fade, vertical bars, power by role. 150 options.
- **Gaps:** **no own click-casting.** `Headers.lua` only registers frames in `ClickCastFrames` for Clique.
  No party cooldown / interrupt tracker.
- **Risks:** only 3 harness mentions for a combat-critical module. Never seen in a raid.
- **Next:** more harness tests (sorting, private auras, dispel), then a raid check.

### Auras - 7
- Headers with sort, growth, wrap, time colouring, cancel, private auras, enchants. 3 harness mentions (thin).

### Tracker (Cooldown Manager) - 7
- Re-anchors and restyles Blizzard's CDM viewers (`Tracker/Viewers.lua`): glows, ready time, range tint, keybinds,
  trinkets. Reminders (`Reminders.lua`) cover the "Aura/Buff reminders" gap in `ellesmereui.md`.
- Gap: not a full CDM replacement like EllesmereUI's. Risk: depends on Blizzard's viewer layout between patches.

### Bags - 7
- Categories, sort, junk dim/sell, upgrade arrows, sim arrow, reagents, bank skin, currencies, processing (`Process.lua`).
- Gap: 41 options for 1605 lines, so the bag views are shallower than ElvUI/Baganator in settings (no custom category rules, unverified).

### Data texts / bars - 7
- Two panels, ~25 segments (gold, durability, guild, friends, spec, keystone, latency, FPS, mail, coords, clock,
  currencies, events), XP/rep/honor/quest-XP bars (`Bar.lua`). New event tracker (`Events.lua`, harness test). 

### Mythic+ - 7
- Timer with splits, bosses, forces, deaths log, chests, best time, pull count (`Timer.lua`); party keys via
  LibKeystone (`Keystones.lua`); auto insert; keys window. Comparable to EllesmereUI Mythic Timer. Never run in a key.

### Group finder - 7
- Expression filter (`Expression.lua`, `Filter.lua`, a PGF-style feature), role-check helper, teleports (`Teleport.lua`). Risk: LFG API secret
  values in 12.x. Next: real queue test.

### Quests - 7
- Restyled tracker, waypoint arrow (`Arrow.lua`) and `/way`, NPC pins, townsfolk, auto accept/turn in, progress announce
  (`Progress.lua`), rewards mark, ETA, rares.

### Movers - 7
- Grid, snap to frames, arrow nudge, unlock key, cog popup with anchor + X/Y (VISUAL_DEFECTS stage 2). Refuses to open
  with Edit Mode. Gap: popup edits position only, not the frame's other settings.

### Bugs - 7
- Own capture with privacy scrubbing (`Core/Errors.lua`) plus viewer (`Bugs/Viewer.lua`). On par with BugSack.

### Encounters - 6
- Own timeline bars (`Bars.lua`) on the game's encounter timeline, warnings, break/pull countdown
  (`Encounters.lua:171-177`, `C_PartyInfo.DoCountdown`), BigWigs bridge. Not a boss-mod replacement.
  The LittleWigs dungeon packs gap is listed in FEATURE_COVERAGE.md.

### Automation - 6
- Smart macros, auction undercut (protected-safe cancel), rare alert, plus QoL helpers. Fewer QoL options than EllesmereUI QoL.

### Damage meter - 5
- **Skins Blizzard's built-in meter**, with an optional Details! look (`DamageMeter.lua` header), plus a threat meter (`Threat.lua`).
  **Not** the own multi-window meter that FEATURE_COVERAGE.md implies. EllesmereUI ships its own meters.

### Combat text 5, Cooldown text 6, PvP 5, Spell history 5, AFK 5, Item level 6, Quality 6, Sim 6, General 6
- Small, focused modules (130-786 lines) that each do one job. PvP: safe queue, queue sound, surrender, shadowsight,
  tab binder. Sim: SimC export string (`Sim/Export.lua`). Combat text: scroll and font only (22 options), well below MSBT/xCT.

### Core, options, profiles, installer - 8
- Options are on demand with rail groups, tabs, live previews (drag on 30, resize on 20 - `Config/PreviewDrag.lua`),
  multi-edit with MIXED tag, per-row reset, global search (`Config/Search.lua`), presets, profiles + spec profiles
  (`Core/DB.lua:181`), share strings v2 (`Core/Profiles.lua`), first-run installer (`Config/Installer.lua`).
  Static checks: API, flavours, IDs, locales.
- `ELLESMERE_GAP_AUDIT.md` still lists "click preview to setting" and "first-install wizard" as missing. Both are now
  built (VISUAL_DEFECTS #5, Installer.lua), so that doc is stale.
- Gaps: no Ctrl+K command palette; no community preset gallery; no conditional overrides.

## Top 10 gaps (priority order)
1. **No in-game verification at all.** Run a structured in-game pass: options, then world, dungeon, raid, arena.
2. **No own click-casting** (only Clique support), `Modules/GroupFrames/Headers.lua`.
3. **No party cooldown / interrupt tracker** (nothing found by rg).
4. **Damage meter is a skin of Blizzard's**, not own windows.
5. **No raid marker / world marker bar.**
6. **Thin harness on combat modules:** GroupFrames 3, Auras 3, CooldownText 4, CombatText 4 mentions.
7. **No quick keybind mode.**
8. **Combat text is shallow** (22 options) compared with MSBT/xCT.
9. **No conditional overrides** (per context/role beyond spec profiles; unverified) and no community preset gallery.
10. **Stale docs:** FEATURE_COVERAGE.md cites 33 of its 44 paths in a layout this branch doesn't have, overstates the meter,
    click-cast, party CD, markers and palette, and claims 495 tests (actual 231). ELLESMERE_GAP_AUDIT.md lists two built features as missing.

## Coverage-doc corrections (FEATURE_COVERAGE.md)
- Paths missing in this branch include `Phoenix_UI_HUD/*`, `Phoenix_UI_Arena/DR.lua`, `Phoenix_UI_RaidFrames/ClickCast.lua`,
  `PartyCD.lua`, `Phoenix_UI_Sentinel/*`, `Phoenix_UI_Pulse/Pulse.lua`, `Phoenix_UI_Flow/Quiet.lua`, `Core/Kernel.lua`,
  `Core/Movers.lua`, `Core/SpecProfiles.lua`, `Core/Overrides.lua`, `Core/Search.lua`, `Core/FocusKey.lua`, `Core/Waypoint.lua`,
  `Phoenix_UI_Options/Studio.lua`, `.tools/harness`. Where a feature does exist, it lives elsewhere (e.g. DR in
  `Modules/UnitFrames/Arena.lua`, search in `Phoenix_UI_Options/Config/Search.lua`, movers in `Modules/Movers/`).
- Status should read missing for own click-cast, party CD, marker bar, command palette, and partial for the damage meter.

## What Phoenix does better than the references
- **Secret-value discipline:** 24 modules have secret guards. Values pass to widgets and are never compared; arena DR/trinkets use
  the game's own trays instead of reading secret payloads (`Arena.lua`). Static checks enforce it (`tools/check_api`).
- **One addon, two clients:** Retail (120105) and Forever (16001) tocs from one tree. Forever extras: map reveal from
  DB2 data, zone levels, uprank.
- **Data from DB2, pinned** (`tools/check_ids.py`, generated RevealData) instead of hand lists.
- **Own windows** in Skins (character, mail with alts, vault, journal and more), more than EllesmereUI's skin pass.
- **Options UX:** every module has a live preview you can drag and resize, multi-edit with MIXED, search that jumps to
  the row, and every setting applies live with no /reload.
- **Built-in tools the references leave to other addons:** bug capture with privacy scrubbing, SimC export, sim arrows in bags,
  M+ timer, LFG expression filter, waypoint arrow.
- **Original code only**, so no licence conflicts (EllesmereUI is all-rights-reserved; LibGetFrame is GPL-2.0).

## Unverified in this audit
Resource threshold depth; Bags custom category rules; Plater-style per-NPC lists; conditional overrides; anything at
runtime in game.
