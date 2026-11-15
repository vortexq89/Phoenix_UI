# Addon research: every installed and stored addon compared with Phoenix_UI

Studied on 2026-10-28 from the user's PC (read-only): the game folder `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns` (96 non-Phoenix, non-Blizzard folders: 81 copied and studied, plus 15 `RaiderIO_DB_*` data-only folders that were listed but not copied) and the `I:\` drive (74 folders, all top level, none zipped). Phoenix_UI* and Blizzard_* folders were skipped. 43 research files cover 86 addon folders, plus one shared-libraries file.

Method: Lua, TOC and XML files were copied to the box and read there. Each file lists facts taken from the TOC and a static scan (events, C_ namespaces, secure templates, OnUpdate/C_Timer counts), then each feature with design, code approach (described in our own words, no code reproduced), benefit, and a comparison with Phoenix_UI backed by `rg` over the Phoenix source and `Data/SchemaIndex.lua`. Nothing was run in game; anything not confirmed in the source is marked **(unverified)**.

Licences: most studied addons are All Rights Reserved or GPL; EllesmereUI and WindTools are explicitly closed to reuse. Only ideas are taken; all Phoenix code stays original (standing rule).

## Index

| Research file | Game folder | I:\ drive | Folders covered | Summary |
|---|---|---|---|---|
| [Auctionator](Auctionator.md) | yes (341) | yes (341) | 1 | Auction House tool for modern and legacy AH: shopping lists, price database from full scans, selling with undercut, cancelling, crafting cost info, and tooltips with... |
| [AutoQueue + AutoSignLFG](AutoQueue.md) | yes (1.5.4) | yes (1.5.4) | 1 | Small helper by Azaleth that answers Dungeon Finder role checks automatically and speeds up Premade Group sign-ups, with a role bar to pick the roles. |
| [BetterWardrobe (+ SourceData)](BetterWardrobe.md) | yes (6.12.3) | no | 2 | Extends the transmog collection and wardrobe: saved outfit sets beyond Blizzard's limit, extra sets data, situations (auto outfit per situation), randomiser, sorting and... |
| [BigWigs Bossmods (core, plugins, options and all content packs)](BigWigs.md) | yes (v427.8) | yes (v427.7) | 23 | The most used boss mod |
| [BugSack and !BugGrabber (error capture)](BugSack.md) | yes (v12.1.9) | yes (v12.1.8) | 2 | A two-part pair by Funkeh: !BugGrabber loads first (the ! sorts it to the front) and replaces the Lua error handler so it can catch every error and blocked-action event... |
| [EllesmereUI core (+ Options, + Locales) - family index](EllesmereUI.md) | yes (9.6.8) | yes (9.6.1) | 3 | The EllesmereUI suite is a core addon plus 20 child addons, one per area |
| [EllesmereUI Action Bars](EllesmereUI_ActionBars.md) | yes (9.6.8) | yes (9.6.1) | 1 | Own secure action bar frames and buttons (not Blizzard's), to avoid tainting Blizzard's protected buttons |
| [EllesmereUI Aura/Buff Reminders](EllesmereUI_AuraBuffReminders.md) | yes (9.6.8) | yes (9.6.1) | 1 | Clickable reminders for raid buffs, auras and consumables, plus talent reminders, beacon reminders and a ready-check mana warning |
| [EllesmereUI Bags](EllesmereUI_Bags.md) | yes (9.6.8) | yes (9.6.1) | 1 | All-in-one bags and bank with grid, list and compact views, categories, pin/assign modes, junk marker and quick actions |
| [EllesmereUI Blizzard Skin](EllesmereUI_BlizzardSkin.md) | yes (9.6.8) | yes (9.6.1) | 1 | Themed Blizzard windows on a shared window engine (14k-line pack file), with a reworked character sheet, inspect sheet, Great Vault, group finder, chat bubbles,... |
| [EllesmereUI Chat](EllesmereUI_Chat.md) | yes (9.6.8) | yes (9.6.1) | 1 | Chat skin with a sidebar of icons (portal flyout etc.), fade rules, session history, link copying and tabs |
| [EllesmereUI Cooldown Manager](EllesmereUI_CooldownManager.md) | yes (9.6.8) | yes (9.6.1) | 1 | Restyles and re-anchors Blizzard's Cooldown Viewer (CDM) frames into custom bars, adds tracking bars, bar glows and per-spell conditions |
| [EllesmereUI Damage Meters](EllesmereUI_DamageMeters.md) | yes (9.6.8) | yes (9.6.1) | 1 | Damage meter windows on Blizzard's C_DamageMeter data (up to 5), with breakdown tooltip, combat timer, Forever threat type and spell history |
| [EllesmereUI Data Bars](EllesmereUI_DataBars.md) | yes (9.6.8) | yes (9.6.1) | 1 | Configurable info bars built from blocks: audio, bags, clock, crests, currency, gold, Great Vault, item level, location, micro menu, profession, spacer, spec, stats... |
| [EllesmereUI Forever Essentials](EllesmereUI_ForeverEssentials.md) | yes (9.6.8) | yes (9.6.1) | 1 | WoW Forever (Classic) tools: active form icon, classic spellbook and talents windows, fishing helpers, flight timer, gathering skill in tooltips, junk window, loot feed,... |
| [EllesmereUI Friends](EllesmereUI_Friends.md) | yes (9.6.8) | yes (9.6.1) | 1 | Friends list restyle using Blizzard's ScrollBox through hooks only (no custom data provider, no groups). |
| [EllesmereUI Group Finder](EllesmereUI_GroupFinder.md) | yes (9.6.8) | yes (9.6.1) | 1 | Group finder search tweaks and an applications bar |
| [EllesmereUI Minimap](EllesmereUI_Minimap.md) | yes (9.6.8) | yes (9.6.1) | 1 | Minimap skin with an addon-button flyout, custom indicators (Great Vault, M+ portal), friends and calendar tooltips with lockouts. |
| [EllesmereUI Mythic Timer (Mythic+ tools)](EllesmereUI_MythicTimer.md) | yes (9.6.8) | yes (9.6.1) | 1 | Mythic+ tools: kick tracker (bars and nameplate icons), run summary with per-character history (/ov), target/focus cast bars and targeted spell bars. |
| [EllesmereUI Nameplates](EllesmereUI_Nameplates.md) | yes (9.6.8) | yes (9.6.1) | 1 | Enemy and friendly nameplates with engine-driven aura groups, cast bar with kick tick, threat, quest mobs, overlays and a cast overlay |
| [EllesmereUI Quality of Life](EllesmereUI_QoL.md) | yes (9.6.8) | yes (9.6.1) | 1 | Many small features: upgrade calculator, centre alerts, auto combat logging, battle res, Bloodlust/Sated tracker, cursor ring, /keys, movement cooldown alert, raid tools... |
| [EllesmereUI Quest Tracker](EllesmereUI_QuestTracker.md) | yes (9.6.8) | yes (9.6.1) | 1 | Skins Blizzard's Objective Tracker through hooks only and adds auto accept/turn-in, a quest-item hotkey and Forever sorting/filtering. |
| [EllesmereUI Quickdraw (hold-key action palette)](EllesmereUI_Quickdraw.md) | yes (9.6.8) | yes (9.6.1) | 1 | Hold a key, a palette (fan/arc or grid) of slots appears around the cursor, point at one, release to use it |
| [EllesmereUI Raid Frames](EllesmereUI_RaidFrames.md) | yes (9.6.8) | yes (9.6.1) | 1 | Party and raid frames with buff/debuff managers, click casting, pet frames, party targets, portraits, boss frames, previews |
| [EllesmereUI Resource Bars](EllesmereUI_ResourceBars.md) | yes (9.6.8) | yes (9.6.1) | 1 | Personal health, power, class resource, cast, GCD and totem bars with per-spec thresholds and several class-specific engine drivers |
| [EllesmereUI Unit Frames](EllesmereUI_UnitFrames.md) | yes (9.6.8) | yes (9.6.1) | 1 | Player, target, focus, pet, ToT, focus target and boss frames plus player aura bars |
| [EllesmereUI_WindTools (WindTools port for EllesmereUI)](EllesmereUI_WindTools.md) | yes (0.2.8) | yes (0.2.8) | 1 | A "migration shell" of WindTools (the ElvUI plugin) for EllesmereUI |
| [idTip (IDs in tooltips)](idTip.md) | yes (12.1.4) | yes (12.1.4) | 1 | One 640-line file that appends IDs (spell, item, NPC, quest, currency, achievement, talent, mount, pet and more) to tooltips |
| [LittleWigs (dungeon boss mods for BigWigs)](LittleWigs.md) | yes (v12.1.22) | yes (v12.1.21) | 12 | BigWigs content packs for dungeons, delves and scenarios |
| [Mik's Scrolling Battle Text (MSBT)](MikScrollingBattleText.md) | yes (12.042) | yes (12.040) | 1 | Classic scrolling combat text with scroll areas, triggers and profiles |
| [MountsJournal (+ MountsJournalUI, + EllesmereUI skin)](MountsJournal.md) | yes (v12.1.14) | no | 3 | Smart mount summoning with rules (zone, flyable, swimming, conditions, snippets), weighted random lists, pets with mounts, a richer mount journal with filters, tags and... |
| [MoveAny (move, scale and hide Blizzard frames)](MoveAny.md) | yes (1.13.24) | yes (1.13.22) | 1 | Lets the player move, scale, fade and hide almost any Blizzard HUD element, with per-element widgets in its own edit mode |
| [Mythic Dungeon Tools (MDT, + MDT_UI)](MythicDungeonTools.md) | yes (6.3.24) | no | 2 | The standard Mythic+ route planner: a map per dungeon with every enemy pack, enemy forces, pulls you draw, notes and live sharing |
| [Premade Groups Filter (+ EllesmereUI skin plugin)](PremadeGroupsFilter.md) | yes (7.6.5) | yes (7.6.5) | 2 | Filters the Premade Groups list with panels (dungeon, raid, arena, RBG, delve, roles) or a free-form expression, and adds many list improvements. |
| [Questie (+ QuestieDB, + QuestieTrace)](Questie.md) | no | yes ((see toc)) | 3 | Quest helper for Classic flavours and WoW Forever: quest givers, objectives and turn-ins on the map and minimap from a full quest/NPC/object/item database, a tracker,... |
| [Raider.IO (+ regional database addons)](RaiderIO.md) | yes (12.1.0 (v202610260600)) | no | 1 | Shows Mythic+ score, best runs, raid progress and recruitment info in tooltips, the group finder and profiles |
| [RareScanner](RareScanner.md) | yes (12.1.5.3) | no | 1 | Detects rares, treasures and events via vignettes, alerts with a clickable button, plays sounds, and keeps a huge database of rare NPCs, containers, loot, achievements,... |
| [sArena Reloaded (arena frames)](sArena_Reloaded.md) | yes (v2.7.0) | yes (v2.6.7) | 1 | Arena enemy frames with trinket, racial, DR, dispel, interrupt, cast bar, auras, absorbs, pets and several layouts, rebuilt for Midnight's secret values. |
| [Simulationcraft (SimC export)](Simulationcraft.md) | yes (12.1.5-03) | yes (12.1.5-02) | 1 | Builds the SimC profile string (character, talents, gear with bonus IDs, bags, catalyst/upgrade currencies, weekly rewards) and shows it in a copy box. |
| [SpecBisTooltip](SpecBisTooltip.md) | yes (1.0.14) | no | 1 | Shows "Best in Slot for <spec>" on item tooltips from a large bundled data table (data.lua, ~70k lines) with sources, plus a Forever (Classic) pool. |
| [TrufiGCD (recent ability icons)](TrufiGCD.md) | no | yes ((no version line)) | 1 | Shows a moving queue of recently cast ability icons for you (Midnight/Forever) and for party, arena, target and focus on Classic flavours. |
| [Tust_EUI (TustEUI companion plugin for EllesmereUI)](Tust_EUI.md) | yes (1.1.20) | no | 1 | Companion plugin that adds pages to EllesmereUI: a chat replacement, a multi-bar Data Bars engine, enhanced XP bar, LFG enhancements, nameplate rules, tooltip additions... |
| [WoW-API (reference repository, not an addon)](WoW-API.md) | no | yes ((see toc)) | 1 | A reference checkout: Blizzard API documentation (generated), FrameXML source, GlobalStrings for Era and Forever, common libraries (Ace3, LibDBIcon, HereBeDragons,... |
| [Shared libraries](_SharedLibraries.md) | yes | yes | - | Ace3, LibSharedMedia, LibStub, LibDBIcon, LibKeystone, LibOpenRaid and ~40 more, with Phoenix's position on each |

### Only in one location

- **Game folder only:** BetterWardrobe (+SourceData), MountsJournal (+UI, +EllesmereUI skin), MythicDungeonTools (+UI), PremadeGroupsFilter_EllesmereUI, RaiderIO (+15 DB folders), RareScanner, SpecBisTooltip, Tust_EUI.
- **I:\ only:** Questie, QuestieDB, QuestieTrace (source checkouts), TrufiGCD, WoW-API (reference repository, not an addon).
- **Both, different versions:** BigWigs core v427.8 (game) / v427.7 (I:\); BugSack v12.1.9 / v12.1.8; EllesmereUI family 9.6.8 / 9.6.1; LittleWigs v12.1.22 / v12.1.21; MSBT 12.042 / 12.040; MoveAny 1.13.24 / 1.13.22; sArena v2.7.0 / v2.6.7; Simulationcraft 12.1.5-03 / 12.1.5-02. Others identical.

## Top 10 findings

1. P1 - `/keys` only sees other Phoenix users (`PUIKEYS`); BigWigs, DBM and EllesmereUI all share keys through LibKeystone (`LibKS`, "level,mapID,rating", "R" request). Speak that format in our own code.
2. P2 - Party cooldown tracking can be filled in from LibOpenRaid (`LRS`) when another addon already loaded it, covering casts Midnight hides inside instances.
3. P2 - Mythic+ trash knowledge is the biggest content gap (LittleWigs); finish the per-dungeon NPC data packs after in-game testing.
4. P2 - Boss timers: Phoenix Pulse already uses the encounter timeline like BigWigs; the missing part is data (spell renames, sounds, severity) and a per-spell override grid.
5. P2 - "Casts on me" targeted spell bars (EllesmereUI Mythic Timer) are missing.
6. P2 - Talent conditions on Cooldown Manager entries are missing.
7. P2 - Tank active-mitigation bars (Ironfur, Ignore Pain) are missing; only stagger exists.
8. P2 - Moving Blizzard windows (MoveAny / Shifter) is missing; HUD movers already exist in Studio.
9. P2 - Onboarding: no in-game "What's new" popup; plus small wins: Already Known tint and mail alt list.
10. Info - WindTools for EllesmereUI only loads 5 of its ~90 modules; Phoenix matches all 5. Phoenix is equal or better on error capture (Sentinel vs BugSack), IDs (vs idTip), group finder expressions (safe parser vs PGF loadstring), scrolling text performance (vs MSBT), HUD movers (vs MoveAny) and cast history (vs TrufiGCD).

## Combined gap table

| Feature | Seen in | Phoenix status | Priority |
|---|---|---|---|
| Keystone sharing compatible with BigWigs/DBM/EllesmereUI (LibKeystone wire format `LibKS`) | EllesmereUI QoL, BigWigs, WindTools | worse: own `PUIKEYS` prefix only (`Phoenix_UI_Ascent/Keystones.lua`) | P1 |
| Party cooldowns from LibOpenRaid when another addon loaded it | WindTools (LibOpenRaid), Details users | partial: casts only (`Phoenix_UI_RaidFrames/PartyCD.lua`) | P2 |
| Per-dungeon trash data packs (dangerous casts, priority mobs) | LittleWigs | partial: `Phoenix_UI_Nameplates/DataPacks.lua` framework, data pending | P2 |
| Data-only boss pack (spell renames, sounds, severity) + per-spell override grid | BigWigs | partial: Pulse timeline bars, `pulse.bossRules` | P2 |
| Targeted spell bars ("casts on me") | EllesmereUI Mythic Timer | missing | P2 |
| Talent conditions on Cooldown Manager entries | EllesmereUI CDM | missing | P2 |
| Tank active-mitigation bars (Ironfur, Ignore Pain) | EllesmereUI Resource Bars | partial: Brewmaster stagger only | P2 |
| Move Blizzard windows (Shift-drag permanent, Ctrl-drag session) | MoveAny, EllesmereUI QoL Shifter, WindTools MoveFrames | missing (HUD movers exist in Studio) | P2 |
| "What's new" popup after updates | EllesmereUI core | missing | P2 |
| Already Known tint at merchant / AH / collections | WindTools (disconnected module) | missing | P2 |
| Mail alt list beside Send Mail | EllesmereUI Blizzard Skin | missing (alts known in Vault) | P2 |
| Secure "target rare" button + auto waypoint on vignette | RareScanner | partial: alerts only (`Phoenix_UI_HUD/Vignettes.lua`) | P2 |
| Forever: zone levels, map reveal, auto uprank | EllesmereUI Forever Essentials | missing | P2 (Forever) |
| Hold-key secure ring palette | EllesmereUI Quickdraw | missing | P3 |
| Macro factory (smart macros written out of combat) | EllesmereUI core | missing | P3 |
| Spell cost preview on the power bar | EllesmereUI core | missing | P3 |
| Quest XP overlay on the XP bar | EllesmereUI Action Bars | missing | P3 |
| Aura-to-button glow rules | EllesmereUI CDM | missing | P3 |
| Bag "process" mode (disenchant/prospect/mill) | EllesmereUI Bags | missing | P3 |
| Upgrade planner window | EllesmereUI QoL | partial: tooltip lines only | P3 |
| Teleport prompt on joining an LFG group | EllesmereUI QoL | partial: teleports on item bar 5 | P3 |
| Movement cooldown alert | EllesmereUI QoL | missing (could be a CDM preset) | P3 |
| Mute sound list, Smart Tab whisper cycling, extended merchant pages, event tracker, context-menu links | WindTools (disconnected), Raider.IO | missing | P3 |
| Skyriding vigor skin, stat-DR tooltip, merchant bulk buy | EllesmereUI Blizzard Skin | missing | P3 |
| Nameplate cast "lift" above stacked plates | EllesmereUI Nameplates | missing | P3 |
| Ebon Might bar (Augmentation) | EllesmereUI Resource Bars | missing | P3 |
| Smart mount summon rules | MountsJournal | missing (Oracle summons by name) | P3 |
| Read MDT API for forces / current pull | MythicDungeonTools | missing | P3 |
| User-supplied BiS list import into Wisdom | SpecBisTooltip | different approach (stat weights) | P3 |
| Skins for PGF dialog; coexistence tests with Auctionator, BetterWardrobe | PGF, Auctionator, BetterWardrobe | untested | P3 |
| Never auto-open a Sentinel window in combat | BugSack | unverified in `Toast.lua` | P3 check |

## Design and code lessons

- **Restyle, never own Blizzard state.** EllesmereUI CDM states it plainly: Blizzard computes cooldowns/buffs; the addon only restyles and re-anchors. Same for skins via weak-keyed side tables. Phoenix already follows this; keep it as a written rule in reviews.
- **Pass secrets to widgets; colour by curves.** sArena, EllesmereUI resource bars and BugGrabber all check `issecretvalue` or feed secret values straight into status bars, and use `C_CurveUtil` colour curves instead of comparing numbers.
- **Trust before learn.** MSBT only keeps an inferred fact (a spell's school) after several agreeing samples and can take a guess back. Any Phoenix inference (party cooldowns, hit attribution) should do the same and label it "worked out" in the UI.
- **Speak common protocols.** LibKeystone (`LibKS`) and LibOpenRaid (`LRS`) are how players without the same UI share data. Interop beats a private prefix.
- **Build protected frames before combat; queue what appears in combat.** Tust_EUI prebuilds its raid shelf; WindTools Quick Focus keeps a weak-keyed pending queue for frames first seen in combat. Phoenix `Core/CombatQueue.lua` is the place for this.
- **Pure models with an impure edge.** MDT keeps layout maths and sidebar state pure (no WoW API) so they are unit-tested with stubs. Phoenix tests already do this; extend it to new features.
- **One timer driver.** TrufiGCD and MSBT run a per-frame OnUpdate; Phoenix's Ticker registry and C-side AnimationGroups (Spark) are lighter. Keep the "no OnUpdate outside the Ticker" rule.
- **Load on demand.** BigWigs loads core, plugins and content per zone; options are load-on-demand in BigWigs, MSBT and EllesmereUI. Phoenix Options is separate; consider making large data packs (NPC packs, boss packs) load-on-demand per instance.
- **Hard caps on saved data.** BugGrabber caps at 500 stored errors with duplicate counters; Phoenix Sentinel caps other addons' errors at 100. Apply the same to any history (chat, runs, gold).
- **Safety nets for CVars.** BigWigs BossBlock re-enables CVars at load in case a disconnect left them off mid-fight. Phoenix's CVar ledger should restore after abnormal exits too.
- **Onboarding polish.** EllesmereUI's first-install module picker, patch-notes popup and video guides make a large suite approachable.
- **Label held-back features.** EllesmereUI Group Finder and most WindTools modules ship but do not run; disabled code in releases confuses users and reviewers. Phoenix should not ship dormant modules.

## Areas where Phoenix is already equal or ahead

Error capture (Sentinel), tooltip IDs, group finder expressions and queue helper, cast history, scrolling text, HUD movers, arena frames with DR from game data, damage meter on `C_DamageMeter`, cooldown manager restyling, reminders, bags with rules, chat, friends, raid frames with click casting, data bars, minimap button bin, quest tracker, SimC export, auto item bars, focus key, raid markers. See each file's comparison sections for the exact Phoenix files and settings.

## Notes on files we did not act on

Questie, QuestieTrace and Auctionator (at least) ship `AGENTS.md`/`CLAUDE.md` files. They were not read as instructions and nothing in them was acted on.
