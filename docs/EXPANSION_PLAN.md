# Phoenix UI expansion plan (2026-10-22)

Scope: what Phoenix learns from BigWigs/LittleWigs, SimulationCraft, Questie, Premade Groups Filter, WindTools,
EllesmereUI and NaowhForever; where each feature lands in the 13-group sidebar; feasibility under Midnight 12.1.5
rules; the data pipeline; multi-flavour cost. Per-source notes: `docs/research/`. Principle: **learn, extract game
facts from Blizzard client data, build Phoenix's own implementation. No code or assets copied** except where a
licence clearly allows it in an MIT repo (only simc-addon, Unlicense).

## 1. Answers first
- **Are our icon IDs correct?** Yes, with one fix. All 80 hard-coded game references were checked against build
  12.1.5.70448 (62 interface file paths, 18 atlases incl. every `GetClassAtlas` target, 2 spell IDs, 7 SOUNDKIT
  constants, 3 enum fallbacks). One was wrong: the Bugs game-icon fallback `INV_Misc_Bug_01` does not exist →
  `INV_Misc_Bugsprayer` (609616). New `tools/check_ids.py` + `tools/ids/refresh.py` keep them pinned (commit
  086a53d on `rework`). Phoenix's own glyph atlases load the same way as bars (32-bit TGA, power of two, RLE is
  supported by the client), so the "no icons in game" report is still unexplained; `/pui diag` will tell.
- **SimC in one click:** feasible with the Phoenix app. 2 reloads; results visible in the app seconds after
  reload #1 and in game after reload #2. Running a sim inside WoW or sending to Raidbots automatically is
  impossible (no network/processes in addons; Raidbots has no submission API).
- **Questie for Phoenix:** retail Midnight needs no Questie clone (Blizzard draws objectives and quest givers);
  Phoenix adds a better tracker, quest-line browser, rares list, smart turn-in and waypoints from runtime APIs.
  NPC spawn coordinates are not in client data; Phoenix will not ship them (only community sources exist).
- **BigWigs-style boss mods in Midnight:** spell IDs/names/icons on Blizzard's encounter timeline are secret
  during encounters; boss mods now fingerprint timers by duration with per-boss tables hand-made every tier.
  Phoenix will not maintain those. It will own the best skin/control panel for Blizzard's timeline and warnings,
  a DB2-generated boss journal, pull/break timers, and a bar-style bridge to BigWigs.
- **Multi-flavour:** WoW Forever (16001, launches 4 Nov 2026) shares Mainline APIs and secrets → cheap (stage S5,
  M). Classic Era / TBC Anniversary / Mists Classic are a different API family → L–XL; not recommended now.

## 2. Licences
| Source | Licence | Phoenix may |
|---|---|---|
| BigWigs, LittleWigs, BigWigs_Classic, BigWigs_Voice, Questie/WoW-API | none (all rights reserved) | learn; clean-room; call public runtime APIs |
| Questie, QuestieDB, QuestieTrace | "consider all rights reserved", GPLv3 consent in progress | learn; clean-room; optional runtime provider if user installs QuestieDB |
| premade-groups-filter | GPL-2.0-or-later | clean-room (or relicense Phoenix to GPL) |
| simc engine | GPL-3.0 | run as separate program; download at runtime (no redistribution duties) |
| simc-addon | Unlicense | reuse export logic (we re-implement with credit) |
| EllesmereUI | custom, all rights reserved | learn only |
| LibGetFrame | GPL-2.0 | do not embed |
| ElvUI_WindTools / EllesmereUI_WindTools | restricted (GPLv3 only in ElvUI/NDui) | learn only |
| NaowhForever | all rights reserved | learn only |
| Blizzard client data (DB2 via wago.tools) | game data | extract facts into generated tables (as every addon does) |

## 3. What we learned and how Phoenix does it better (per source)
| Source | Learned | Phoenix does better by |
|---|---|---|
| BigWigs/LittleWigs | LoD zone packs; declarative boss files; Midnight = duration fingerprinting of the Blizzard timeline; Test + Anchors on every plugin; statistics | owning the Blizzard timeline/warnings look and settings with live preview, a DB2 boss journal, and a BigWigs bar-style bridge instead of a competing mod |
| SimulationCraft | profile text format; simc CLI + json2; no Raidbots API | visual item picking in game, local sim with no copy/paste, results back on tooltips and bag arrows |
| Questie | quest/NPC/object data model, CBOR-in-TOC storage, corrections layer, per-flavour TOCs | runtime-API quest tools on retail where Questie doesn't exist; DB2-generated tables per flavour; no unlicensed data |
| Premade Groups Filter | expression keywords, list enhancements, one-click sign-up | own taint-free results browser, filter builder + safe grammar (no loadstring), presets per key level |
| WindTools | broad QoL catalogue, dense dual-row options | the fitting ideas placed into existing Phoenix modules, secret-safe |
| EllesmereUI | per-client file variants, Quickdraw radial menu, resource bars, reminders | same polish with enforced zero-taint rules and pinned data checks |
| NaowhForever | modules off by default, onboarding picker, BiS/stat weights, journal with loot | module picker on first install; personal stat weights from simc |

## 4. Master feature table
Priority P0 (next) → P3 (later). Effort S ≤ 1 day, M ≤ 1 week, L > 1 week. "Extends" names the existing module.
| # | Feature | Source of idea | Sidebar group | New / extends | Pri | Effort | Feasibility (12.1.5) |
|---|---|---|---|---|---|---|---|
| 1 | Encounter timeline & warnings skin + all Blizzard CVars + Test button | BigWigs Timeline | Combat | new **Encounters** | P0 | M | yes: `C_EncounterTimeline`, CVars; secret spell names go to display sinks only |
| 2 | Pull / break timers, countdown voice | BigWigs Pull/Break/Countdown | Combat | Encounters (moves voice from Tracker) | P0 | S | yes: `C_PartyInfo.DoCountdown` (hardware event), `AddScriptEvent` |
| 3 | Boss journal card (abilities tree, role icons) | BigWigs options rows | Group & Mythic+ | Encounters | P1 | M | yes: DB2 JournalEncounterSection |
| 4 | Encounter statistics (kills, wipes, best) | BigWigs Statistics | Group & Mythic+ | Encounters | P2 | S | yes: ENCOUNTER_START/END |
| 5 | BigWigs/LittleWigs bar-style bridge | BigWigs BarStyles API | Combat | Encounters | P1 | S | yes: public `RegisterBarStyle`, pcall'd |
| 6 | Per-boss custom timers | BigWigs modules | — | not planned | — | XL/tier | possible only with hand-made duration tables each tier → rejected |
| 7 | Sim: gear/bag picker + profile export | simc-addon | Tooltips & Items | new **Sim** | P0 | M | yes, out of combat |
| 8 | Phoenix app runs simc, shows results, writes Results.lua | simc | Tools | uploader → **Phoenix app** | P0 | L | yes, 2 reloads |
| 9 | Sim results on tooltips + bag upgrade arrow | — | Tooltips & Items | Bags, Tooltip | P1 | S | yes |
| 10 | Personal stat weights | simc scaling | Tooltips & Items | Sim | P2 | S | yes (longer sim) |
| 11 | Quest tracker restyle (distance sort, progress bars, auto-collapse in instances) | WindTools, EUI QuestTracker | Maps, Minimap & Data | new **Quests** | P1 | M | yes; cosmetic hooks only |
| 12 | Zone quest-line browser with chain progress | Questie journey | Maps, Minimap & Data | Quests | P1 | M | yes: `C_QuestLine.*` + DB2 QuestLine |
| 13 | Rares & treasures list + map pins | WindTools EventTracker | Maps, Minimap & Data | Quests | P2 | M | yes: `C_VignetteInfo` |
| 14 | Smart auto accept / turn-in (reward by upgrade or price) | WindTools TurnIn, Questie | Quality of Life | Automation | P1 | S | yes; never in combat |
| 15 | Waypoint arrow + chat coordinate parsing | WindTools SuperTracker | Maps, Minimap & Data | Quests | P2 | S | yes: `C_Map.SetUserWaypoint`, `C_SuperTrack` |
| 16 | NPC spawn pins | Questie | — | optional provider | P3 | M | only via user-installed QuestieDB API; we ship no spawns |
| 17 | Group Finder browser + filter builder | PGF | Group & Mythic+ | new **Group Finder** | P1 | L | yes if own frame; Search needs a click; sign-up via Blizzard dialog |
| 18 | Leader rating, spec icons, missing roles in list | PGF | Group & Mythic+ | Group Finder | P1 | S | yes (own rows) |
| 19 | Raid markers bar + Quick Focus | WindTools | Group & Mythic+ | new **Raid Tools** | P2 | S | yes: secure buttons set up out of combat |
| 20 | Extra item bar (quest items, potions) | WindTools | Action Bars & Cooldowns | ActionBars | P2 | M | yes: secure action buttons, out-of-combat rebuild |
| 21 | Chat bar + Smart Tab | WindTools | Chat & Social | Chat | P2 | S | yes |
| 22 | Instance difficulty badge | WindTools | Maps, Minimap & Data | Minimap | P3 | S | yes |
| 23 | Already Known, merchant pages, inspect panel | WindTools | Tooltips & Items | Tooltip / ItemLevel | P2 | M | yes |
| 24 | CVar editor + sound mute list | WindTools | Tools / QoL | new page / Quality | P3 | S | yes (CVar allowlist) |
| 25 | Buff / consumable reminders (out of combat) | EUI, Naowh | Combat | Tracker | P2 | M | yes out of combat; in-combat aura data may be secret |
| 26 | Resource bars | EUI | Unit Frames | UnitFrames | P2 | M | yes via StatusBar secret sinks |
| 27 | Quickdraw radial menu | EUI | Action Bars & Cooldowns | new | P3 | M | yes, secure handlers |
| 28 | Module picker on first install | Naowh | Home | Presets | P1 | S | yes |
| 29 | WoW Forever support | BigWigs/EUI/Naowh | all | flavour layer | P1 | M | yes (stage S5) |

No duplicates: countdown voice moves from Tracker into Encounters (one owner); quest automation lives in
Automation, not Quests; upgrade arrows stay in Bags and only gain the sim delta; tooltip lines stay in Tooltip.

## 5. What the new pages look like
- **Encounters (Combat):** pinned preview = a live timeline strip with three sample bars in Phoenix textures and
  a warning banner; tabs *Timeline · Warnings · Timers · Sounds · Journal*; Test button runs
  `AddEditModeEvents()` so changes show on the real bars.
- **Sim (Tooltips & Items):** left a paperdoll, right the bag grid with checkboxes per item and slot filter;
  footer: mode segmented control, *Prepare sim* → *Reload to send*; results card: DPS per set with deltas and the
  sim time, history of the last 10 sims.
- **Quests (Maps):** tabs *Tracker · Zone story · Rares · Waypoints*; zone story shows chains as rows with step
  progress and a *track next step* button.
- **Group Finder (Group & Mythic+):** our own results list with leader rating, spec icons and missing roles;
  filter chips row (role needs, rating, key level, age) with a live "12 of 48 groups" count, advanced box.

## 6. Data pipeline
- **Sources:** wago.tools DB2 CSV per product/build (`wow`, `wowf`, later `wow_classic` …); Blizzard UI source
  (Gethe/wow-ui-source) for constants; Ketho BlizzardInterfaceResources for enums. Never Wowhead scraping or
  unlicensed community data.
- **Scripts:** `tools/data/fetch.py --product wow --build latest` (cached CSVs, outside the repo) →
  `tools/data/gen_<topic>.py` → `Data/<flavor>/<Topic>.lua` (generated, header with build and table hashes).
  Topics: `Journal` (instances, encounters, sections, creatures), `QuestLines`, `QuestPOI` (compressed polygons
  per uiMap), `Vignettes`, `ChallengeMaps`, `GroupFinder` activities. `tools/ids/refresh.py` (done) is the pattern.
- **Size budget:** ≤ 1.5 MB Lua per flavour loaded on demand (`Phoenix_UI_Data_<Flavor>` LoD addon), ≤ 150 KB
  always loaded. QuestPOI is the biggest (≈ 7 MB raw CSV → numbers quantised to 1/1000 map units and only for
  quests without runtime POIs; measure in S3, drop if over budget because retail draws them already).
- **Every patch:** `refresh` job compares the new build's tables, regenerates, runs `check_ids.py` and a
  `check_data.py` (row counts, referential integrity, no orphan IDs), and lists diffs in the PR. Runtime lookups
  stay preferred; generated data is only for what APIs don't expose before you meet it (journal for unvisited
  instances, quest chains not yet available).
- **Honest gaps:** spawns, quest givers on Classic, quest text, timer durations, BiS lists, drop rates.

## 7. Stages
| Stage | Content | Effort |
|---|---|---|
| S0 (done) | Icon/ID audit, `check_ids.py`, research notes, this plan | — |
| S1 | Encounters module (#1, #2, #5), countdown move, module picker (#28) | M |
| S2 | Sim in game (#7) + Phoenix app sim runner (#8), tooltips (#9); measure sim times | L |
| S3 | Data pipeline + journal card (#3, #4) + Quests (#11, #12, #14) | L |
| S4 | Group Finder (#17, #18), Raid Tools (#19), WindTools QoL set (#20–24) | L |
| S5 | WoW Forever flavour: `## Interface: 120105, 16001`, `ns.flavor`, gate retail-only modules, `wowf` data build, test on Forever client | M |
| S6 (optional) | Classic flavours: separate TOCs, API shims (no `C_EncounterTimeline`, no secrets, older C_ APIs), per-flavour data, own test matrix; realistically XL and an ongoing tax on every feature | XL |

## 8. Risks
- Blizzard keeps tightening secrets (Forever beta added `FrameStrata` secrets): every feature behind `ns.Secret`
  and static checks; features degrade to "hidden", never error.
- Taint in LFG/quest tracker: own frames only; no writes to Blizzard tables.
- The Phoenix app grows from an uploader into a sim runner: needs signed builds and a clear "what it runs" page;
  antivirus false positives for an unsigned exe.
- simc download is 115 MB; first sim needs consent and disk space.
- Data size and patch churn: generated data must stay optional and regenerated each patch.
- Forever launch (4 Nov) may change APIs; test on the live client before claiming support.
- Licence: switching Phoenix to GPL would allow PGF/Questie code reuse but blocks some future options; the plan
  assumes Phoenix stays MIT.

## 9. Decisions needed from the user
1. Order of stages (proposed S1 → S2 → S3 → S4 → S5).
2. Phoenix app: OK to download simc (115 MB) on first use with consent?
3. Forever support before or after Group Finder (launch is 4 Nov)?
4. Classic flavours (S6): skip for now?
5. Keep Phoenix MIT (clean-room everything) — recommended.
