# Feature coverage: every installed addon vs Phoenix UI

Built 2026-10-28 from the per-addon studies in `docs/research/addons/` (game AddOns folder: 96 non-Phoenix folders; `I:\`: 74 folders, read-only), with every "missing"/"partial" re-checked against the current Phoenix source with `rg` (statuses refreshed 2026-10-29, and again 2026-10-31 after the EllesmereUI parity pass: t193 / t194). Ideas only; all Phoenix code is original.

Rule (user, t125u, widened t193 / t194): every studied addon counts, not only EllesmereUI; the most complete version of a feature is the reference (MoveAny for moving and scaling any frame). Original code, live, GUI only, retail and Forever.

Installed only in one place: game folder only - BetterWardrobe, MountsJournal, MythicDungeonTools, RaiderIO (+DBs), RareScanner, SpecBisTooltip, Tust_EUI; `I:\` only - Questie (+DB, Trace), TrufiGCD, WoW-API (reference, not an addon). Libraries: see `addons/_SharedLibraries.md`.

> **Corrected 2026-10-29 (feature audit, `FEATURE_AUDIT_2026-10-29.md`).** This file was first written against an older multi-addon layout (`Phoenix_UI_HUD`, `Phoenix_UI_Sentinel`, `Core/Kernel.lua` ...) that is not on `restore/v1-ui`. Rows whose paths or status were wrong now point at this branch. Setting keys written like `vault.*`, `tt.*`, `mm.*`, `gf.*` are names from that layout; the real keys are in `Phoenix_UI_Options/Options/<Module>.lua`. Status changes: click casting, kick tracker, raid markers -> missing; damage meter windows, conditional overrides, BossBlock, gold ledger, HUD movers, Tust extras, cursor/QoL -> partial.

## Summary

| Class | Features |
|---|---|
| Phoenix has | 122 |
| partial | 9 |
| missing | 2 |
| out of scope | 10 |

## Prioritized build list

| # | Feature | Reference | Status |
|---|---|---|---|
| 1 | Move Blizzard windows (Shift+drag saves, Ctrl+drag this session, reset) | EllesmereUI QoL Shifter (MoveAny ideas folded in, t194) | built |
| 2 | Pending quest XP overlay on the XP bar | EllesmereUI ActionBars XP bar | built |
| 3 | Mail: alt list next to the recipient box | EllesmereUI BlizzardSkin mail | built |
| 4 | "What's new" popup after an update | EllesmereUI core | built |
| 5 | CDM entry: show only with talent | EllesmereUI CooldownManager | built (?ID / !ID in a custom bar list) |
| 6 | Casts-on-me bars (secret-safe target check) | EllesmereUI MythicTimer | built (Cast Bars > Target > Casts on me) |
| 7 | Rare alert secure target button + waypoint | RareScanner (no EUI version) | built (Automation > Rare alert) |
| 8 | Copy armory link in unit menus | Raider.IO (no EUI version) | built (Chat > Armory link in menus) |
| 9 | Merchant bulk buy | EllesmereUI BlizzardSkin | built (Alt+click at a vendor) |
| 10 | Already Known tint (built: Automation > Already known at merchants), upgrade planner (built: Item Level > Upgrade planner), aura glows (built: Cooldown Manager > Aura glows), quickdraw ring (built: Action Bars > Quick ring), macro factory (built: Automation > Smart macros), quest item hotkey (built: Action Bars > Quest item key), movement CD row (built: Cooldown Manager > Movement row) | EllesmereUI (WindTools / QoL / CDM / Quickdraw) | later (P3) |
| 11 | Selling/cancelling in AH, wardrobe collection list, PGF skin, BiS import, BigWigs per-ability grid | Auctionator / BetterWardrobe / PGF / SpecBisTooltip / BigWigs | built: Automation > Auction undercut (selling price, plus a cancel helper: one check or cancel per click of yours), Skins > Transmog set list, Skins > Premade Groups Filter, Tooltip > BiS list, Encounters > Ability rules (hide / emph / sound by spell ID, as rules rather than a grid) |

## Combat text review (t195, 2026-10-31)

What exists (this branch): `Modules/CombatText/CombatText.lua` (79 lines, module `CombatText`, profile keys `damageFont`, `scroll.*`) and `Modules/CombatText/Scroll.lua` (403 lines), settings `Phoenix_UI_Options/Options/CombatText.lua` (161 lines) in two tabs: Blizzard floating text (CVars, Options/CombatText.lua:59-80) and Phoenix scroll areas (from :82).

Font: the scroll text uses **Phoenix Font Bold** with a thick outline and shadow (`font = Style.Text(20, { font = "PhoenixFontBold", outline = "THICK", shadow = true })`, CombatText.lua:20), editable with the normal font picker. `damageFont` (CombatText.lua:16, default "" = game font) sets Blizzard's own floating damage font via DAMAGE_TEXT_FONT at load (needs a relog; CombatText.lua:73). Grenze Black (`Core/FontData.lua:207`) and the other Media/Fonts faces are only choices in the picker; nothing in combat text uses them by default, and there is no separate MSBT-style font file. Step 5 (2026-10-31): Combat text > Combat font quick pick: Phoenix Font Bold (default), Bebas Neue, Oswald, Russo One, Black Ops One, Grenze Black (all OFL, Media/Fonts/FONTS.md).

Overlaps found:
- Blizzard floating combat text and Phoenix scroll read the same source (COMBAT_TEXT_UPDATE). With both "Your own combat text" (`enableFloatingCombatText`) and the scroll on, incoming numbers show twice. Merge: when the scroll is on, offer to turn Blizzard's self text off (one switch, both tabs). Resolved 2026-10-31 (combat text step 4): `scroll.hideBlizzard` (on by default) makes the game's CombatText frame invisible while the scroll is on; it keeps feeding the scroll and returns when either is off (`M:ApplyBlizzardText`, Scroll.lua).
- "Combat state" CVar (`floatingCombatTextCombatState_v2`) vs Quality > Combat alert banner (`Modules/Quality/Quality.lua:19`, `combatAlert`): two "entering / leaving combat" messages. Merge: one control that names both. Resolved 2026-10-31 (t198): each switch's description names the other (the CVar is account-wide and the banner is profile data, so they stay two switches).
- Notify area (buff / debuff / fade / reactive) vs Cooldown Manager proc glows and Reminders: different jobs (scrolling note vs icon), no merge, but the notify defaults should stay off for procs the CDM already glows.
- Honor / reputation text vs Quality > Loot feed (items, money, currencies) and the DataTexts rep bar: no real duplicate.
- Damage meter (totals) and Encounters (timeline bars): no overlap.
- Rule note (resolved 2026-10-31, combat text step 2): Scroll.lua no longer has an OnUpdate; every line flies on its own AnimationGroup (Translation + smoothed bend + Scale pop + Alpha fade, OnFinished returns it to the pool; `fly`/`flight`/`release` in Scroll.lua). Only the settings preview (Previews/Combat.lua:295) keeps an OnUpdate while it is visible.

## Duplicate checks before building (t195)

- MoveAny vs existing: Layout mode `Modules/Movers/Movers.lua` (Phoenix frames + about 130 Blizzard HUD elements, scale / alpha per mover, line 13), one scale for Blizzard panel windows (`windowScale`, Movers.lua:21 and M.WINDOWS :42), Skins > Move Blizzard windows (`Phoenix_UI_Skins/Move.lua`, drag only), and the game's Edit Mode (`Libs/LibEditMode`). Build MoveAny-level work inside Movers (pick any frame, hide, per-window scale), not as a new module; fold Move.lua's per-window position into the same store.
- RareScanner vs existing: Automation > Rare alert (`Phoenix_UI_Automation/RareAlert.lua:63`, toast, secure target button, waypoint) and the opt-in vignette recorder in `Phoenix_UI_Quests/Collector.lua` (positions only, never shown). New rare features (killed today, loot marks) belong in RareAlert.lua.

## Every feature

| Addon | Feature | Class | Note |
|---|---|---|---|
| Auctionator | Shopping lists and search | out of scope | Not planned. Make sure our AH skin coexists with Auctionator's tabs (P3 test). |
| Auctionator | Selling and cancelling | Phoenix has | Automation > Auction undercut (price just under the lowest offer, cancel helper one click at a time). |
| Auctionator | Price tooltips | out of scope | Phoenix shows vendor price and upgrade info in tooltips (`Modules/Tooltip/Tooltip.lua`, Tooltip > vendorPrice) but no auction price. |
| AutoQueue | Auto role check | Phoenix has | Phoenix `Phoenix_UI_GroupFinder/QueueHelper.lua` handles role checks, sign-up and the Enter-to-sign-up button (`gf.*` keys). |
| AutoQueue | Auto sign-up for premades | Phoenix has | Covered by QueueHelper (sign-up, Enter button). PremadeGroupsFilter also covers this. |
| BetterWardrobe | Saved outfits and situations | out of scope | Not planned. |
| BetterWardrobe | Collection list and filters | Phoenix has | Skins > Transmog set list (pieces owned, closest first, search). |
| BigWigs | Midnight timers from the encounter timeline | Phoenix has | `Modules/Encounters/Bars.lua` and `Encounters.lua` draw bars from the game's encounter timeline; BigWigs bridge in `Modules/Encounters/BigWigs.lua`. |
| BigWigs | Messages, sounds, countdown voice | Phoenix has | Encounters > Ability rules (spellID=hide / emph / sound / count) on the Phoenix timeline bars. Review 28 (2026-10-31): emphasised bars in their own bigger stack, drain / fill, spark, voice count-in per ability or for every emphasised bar, banner lines, screen-edge flash on critical warnings. |
| BigWigs | Pull, break and battle-res tools | Phoenix has | Phoenix `Phoenix_UI_RaidTools` (`rt.pullSeconds`, `rt.breakMinutes`, `rt.mplusCountdown`, `/pui cd`), battle res on item bar and in Ascent (`ascent.brLust`), `Skins/Queue |
| BigWigs | BossBlock (noise control) | have | Banner hiding in `Modules/Quality/Quality.lua` (hideZoneText, hideBossBanner, hideTalkingHead). Built 2026-10-31 (t198): boss emotes (`hideBossEmotes`, RaidWarningFrame's emote events only) and a quiet scope for all four (`hideWhere`: everywhere / dungeons and raids / raids, `M.QuietHere`). Completed 2026-10-31 (review 32): `hideWhere = "listed"` with `quietList` (Add this instance / Remove, `M:QuietListAdd`, `M:QuietListRemove`), and boss fight sound muting (`muteMusic`, `muteAmbience`, `muteSfx`, `muteErrorSpeech`, ENCOUNTER_START / END) with a CVar ledger (`global.soundLedger`, restored at the end of the fight or at the next login). Movies: Automation > Skip cinematics; objective tracker: Quests > Auto-collapse; error text: Filter errors. |
| BigWigs | Nameplate icons and InfoBox/AltPower | out of scope | Phoenix Nameplates has cast/aura lanes and M+ indicators; no boss-module nameplate timers. |
| BigWigs | Statistics | Phoenix has | Phoenix `rt.stats.*` (encounter stats with wipe trend, `rt.stats.yieldToBossMods`). |
| BugSack | Early error capture | Phoenix has | `Core/Errors.lua` captures errors early with privacy scrubbing. |
| BugSack | Bug viewer (BugSack) | Phoenix has | `Modules/Bugs/Viewer.lua` (viewer) and `Modules/Bugs/Bugs.lua`. |
| EllesmereUI | Lite framework instead of Ace3 | Phoenix has | Own module system and saved data: `Core/Modules.lua`, `Core/DB.lua`, `Core/Flavor.lua`. |
| EllesmereUI | Unlock Mode (movers with anchors and snapping) | Phoenix has | `Modules/Movers/Movers.lua`: layout mode with grid, snap to frames, arrow nudge and a cog popup (anchor, X/Y). |
| EllesmereUI | Spec overrides and conditional overrides | partial | Spec profiles in `Core/DB.lua:181` (`specProfiles`). Conditional overrides: not found on this branch. |
| EllesmereUI | Macro Factory | Phoenix has | Automation > Smart macros; 2026-10-31 Pick up buttons and Open macro window. Full in-addon macro editor built 2026-10-31 (next row). |
| EllesmereUI | Global options search | Phoenix has | `Phoenix_UI_Options/Config/Search.lua` (search every page, jump to and flash the row). No Ctrl+K command palette. |
| EllesmereUI | First-install module picker, migrations, patch notes, video guides, uninstall | partial | What's new popup plus (2026-10-31) About > Full changelog and a show-after-updates switch. Module picker at first install: setup wizard only; video guides, uninstall: not planned. |
| EllesmereUI | Shared engines | Phoenix has | Spell cost preview: `Modules/UnitFrames/Update.lua` `Live:SpellCost` (cost of the spell being cast, secret-safe). Five-second-rule spark (Forever): not built. |
| EllesmereUI | Party mode and profile sync | Phoenix has | Built 2026-10-31: Automation > Party mode (edge lights, boss / key / level-up celebrations, manual session never ended by a trigger). Profiles are account-wide with per-character choice. |
| EllesmereUI_ActionBars | Own secure bars and buttons | Phoenix has | Phoenix `Phoenix_UI_ActionBars` (ab.bar1..bar10, stance, pet, vehicle, extra, items, `ab.editModeCapture`). |
| EllesmereUI_ActionBars | Paging and visibility conditions | Phoenix has | Phoenix where-to-show rules per bar (combat, vehicle, pet battle, mounted, skyriding, content, group, spec), fade, `ab.mouseoverLinked`. |
| EllesmereUI_ActionBars | Keybinds, quick keybind, range, glows, pushed state | Phoenix has | Phoenix `KeybindMode.lua`, `ab.rangeMode`, `ab.procGlow`, `ab.assist`, `ab.lossOfControl`, `ab.keyAbbrev`. |
| EllesmereUI_ActionBars | XP / reputation / house favour bars with Quest XP overlay | Phoenix has | Pending quest XP overlay on the XP bar. |
| EllesmereUI_ActionBars | Gamepad and housing | Phoenix has | Built 2026-10-31: Automation > Gamepad (controller switch, camera turn / tilt speed, no console). |
| EllesmereUI_AuraBuffReminders | Clickable secure reminder icons | Phoenix has | Review 30 (2026-10-31): `Phoenix_UI_Tracker/Reminders.lua` icons are SecureActionButtons (cast the buff, use the best bag flask / food / rune, oil with /use 16, summon pet, Create Healthstone; right-click hide until next zone), `reminders.classBuff` (poisons, shields, Beacon on the tank), `reminders.glow`, `reminders.labels`, sound, ready-check mana. The old `rm.*` keys were the pre-v2 layout. |
| EllesmereUI_AuraBuffReminders | Talent reminders per zone | Phoenix has | Phoenix `rm.talentZone`, `rm.talentZones`; Loadouts module. |
| EllesmereUI_AuraBuffReminders | Ready-check mana warning; Beacon M+ reminders | Phoenix has | Tracker/Reminders.lua ready-check low mana; review 30: Holy paladin Beacon reminder (no Beacon of yours on a group member; click casts it on the tank). |
| EllesmereUI_Bags | Three views and categories | Phoenix has | Phoenix Vault (`vault.view`, `vault.rules`, `vault.sections`, `vault.listColumns`, `vault.compactSize`, custom rules). |
| EllesmereUI_Bags | Quick actions | Phoenix has | Built 2026-10-29: `Modules/Bags/Process.lua` (Process chip / bag-window button; secure spell-on-item cells; retail). |
| EllesmereUI_Bags | Junk marker, sell junk, reagent window, gold ledger | Phoenix has | Junk dim and sell, reagents, bank skin in `Modules/Bags/`. Gold ledger built 2026-10-31 (t198): every character's gold and the warband bank (existing), plus session earned / spent and today's net change in the gold tooltip (`goldLedger`, `M.GoldSession`, `M.GoldToday`) and Forget character (`M:ForgetGold`), `Phoenix_UI_DataTexts/DataTexts.lua`. |
| EllesmereUI_BlizzardSkin | Window engine and packs | Phoenix has | Phoenix `Phoenix_UI_Skins` (`skins.*`, 119 keys; applied and removed live). |
| EllesmereUI_BlizzardSkin | Character sheet rework | Phoenix has | Built 2026-10-29: `Modules/ItemLevel/StatDR.lua` (Item Level > Diminishing returns in stat tooltips): DR cost and the next 100 rating, from the game's own rating functions. |
| EllesmereUI_BlizzardSkin | Skyriding vigor skin | Phoenix has | ActionBars skyriding/vigor handling |
| EllesmereUI_BlizzardSkin | Mail alt list, merchant bulk buy | Phoenix has | Skins > Mail alts; Automation > Bulk buy (Alt+click at a vendor). |
| EllesmereUI_BlizzardSkin | Tooltip skin, anchor and visibility | Phoenix has | `Modules/Tooltip/Tooltip.lua` (anchor, cursor offsets, hide in combat, skin). |
| EllesmereUI_BlizzardSkin | Public skin API | Phoenix has | Phoenix `Core/API.lua` + `Skins.lua` registration. |
| EllesmereUI_Chat | Sidebar and fade | Phoenix has | Phoenix `chat.channelBar`, `chat.idleFade`, `chat.fadeAlpha`. |
| EllesmereUI_Chat | Session history, URL copy, copy chat | Phoenix has | Phoenix `chat.history`, `chat.persistHistory`, `chat.urls`, `chat.lineCopy`. |
| EllesmereUI_CooldownManager | Re-anchor Blizzard CDM into custom bars | Phoenix has | Phoenix `Phoenix_UI_CooldownManager` (rows, presets, share string, `cdm.essential/utility/buffIcon/buffBar/custom`). |
| EllesmereUI_CooldownManager | Tracking bars (buff bars) | Phoenix has | Phoenix `cdm.buffBar`, pandemic glow (CooldownManager/Extras.lua), `uf.auraBars.*`. |
| EllesmereUI_CooldownManager | Per-spell talent and stance conditions | Phoenix has | ?ID / !ID entries in a custom bar list (show only with / without a talent). Stance: not built. |
| EllesmereUI_CooldownManager | Bar glows from auras | Phoenix has | Cooldown Manager > Aura glows (presence only). |
| EllesmereUI_CooldownManager | Focus kick, rotation helper icon, key-press mirror, trinkets, potions | Phoenix has | Phoenix `cdm.focusKick`, `cdm.assist`, `ab.assist`; trinkets on item bars. |
| EllesmereUI_CooldownManager | Sync generic entries across specs | Phoenix has | Custom bar lists (`cdm.custom1..3`) are profile-wide, so items and trinket entries already apply to every spec (unknown spells are skipped). |
| EllesmereUI_DamageMeters | Meter windows on C_DamageMeter | Phoenix has | Phoenix damage meter windows (up to three, Layout-mode movers, every mode and segment; CHANGES.md 2.0.0-beta1). |
| EllesmereUI_DamageMeters | Threat meter type (Forever) | Phoenix has | Built 2026-10-29: `Modules/DamageMeter/Threat.lua` (Damage Meter > Threat meter), event-driven, movable. |
| EllesmereUI_DataBars | Block bars | Phoenix has | `Modules/DataTexts/Bar.lua` (XP, reputation, honor, quest-XP bars). |
| EllesmereUI_ForeverEssentials | Map tools | Phoenix has | Zone levels (Minimap > Zone levels, both clients) and map reveal (Minimap > Reveal unexplored areas, Forever; overlays generated from the client's WorldMapOverlay DB2 by tools/mapreveal/build.py). |
| EllesmereUI_ForeverEssentials | Auto uprank | Phoenix has | Built 2026-10-29: `Modules/ActionBars/Uprank.lua` (Action Bars > Extra > Auto uprank), out of combat, cursor-safe. |
| EllesmereUI_ForeverEssentials | Gathering skill, quest reward value, simplified stats, flight timer, fishing, pet summon, threat meter, loot feed, junk window | Phoenix has | Built 2026-10-29: quest reward value marker (Quests > Mark the most valuable reward), gathering skill in tooltip (Tooltip), threat meter (above), flight timer (Quality of Life > Travel, both clients, learned times), pet summon (Automation > Companion pet, both clients), loot feed (Quality of Life > Loot feed, both clients), simplified stats (Phoenix Character window on Forever), fishing helper and junk window (Automation, both clients). |
| EllesmereUI_Friends | Friends list restyle | Phoenix has | Phoenix `Phoenix_UI_Friends` (search across friends/guild/recent, sort, app-only filter, notes, invite accept). |
| EllesmereUI_GroupFinder | Search tweaks and applications bar | Phoenix has | Phoenix GroupFinder is complete. |
| EllesmereUI_Minimap | Button flyout and indicators | Phoenix has | `Phoenix_UI_Minimap/Minimap.lua` (button bin, mail, difficulty, crafting order icons). Review 29: Great Vault button, difficulty as text, FPS / latency line, right-click tracking, middle-click calendar, fade rules, mouse-over zone / coords (`Extras.lua`). M+ portals: Action Bars item bar 5 and Group Finder teleport prompt. |
| EllesmereUI_Minimap | Calendar tooltip with lockouts | Phoenix has | Review 29 (2026-10-31): the clock tooltip and the Minimap info line list Great Vault progress and saved lockouts (`Phoenix_UI_Minimap/Extras.lua`, `ns.Weekly:Lockouts`). |
| EllesmereUI_MythicTimer | Kick tracker | Phoenix has | Built 2026-10-29: interrupt tracker, `Modules/MythicPlus/Kicks.lua` (Mythic+ > Interrupt tracker). |
| EllesmereUI_MythicTimer | Targeted spell bars | Phoenix has | Cast Bars > Target > Casts on me. |
| EllesmereUI_MythicTimer | Run summary and history | Phoenix has | Phoenix `ascent.summary`, `ascent.records`. |
| EllesmereUI_Nameplates | Engine aura containers on plates | Phoenix has | Phoenix `np.auras`, aura lanes. |
| EllesmereUI_Nameplates | Cast bar with kick tick and cast overlay | Phoenix has | Phoenix `np.cast`, `np.interrupt.*`, "kicked by" name on interrupt (`Phoenix_UI_Nameplates/Extras.lua` `OnInterrupted`). |
| EllesmereUI_Nameplates | Debuff colours, threat gap, near-aggro, low-health overlays | Phoenix has | Phoenix `np.colors`, threat colours, execute indicator. |
| EllesmereUI_Nameplates | Friendly plates in delves, faction badge, class power on target plate | Phoenix has | Phoenix `np.friendly`, `np.resource`. |
| EllesmereUI_QoL | Upgrade calculator | Phoenix has | Item Level > Upgrade planner; 2026-10-31 calculator: crests per track and total, average item level gain, cost and step sliders, live on gear change. |
| EllesmereUI_QoL | Movement cooldown alert | Phoenix has | Cooldown Manager > Movement row (`Modules/Tracker/Custom.lua` M.MOBILITY). |
| EllesmereUI_QoL | Keystones via LibKeystone | Phoenix has | Modules/MythicPlus/Keystones.lua speaks LibKS (R / level,mapID,rating) |
| EllesmereUI_QoL | Shifter (move Blizzard panels) | Phoenix has | Skins > Move Blizzard windows (Shift+drag saves, Ctrl+drag this session, reset). |
| EllesmereUI_QoL | Teleport prompt | Phoenix has | Built 2026-10-29: `Modules/GroupFinder/Teleport.lua` (Group Finder > Teleport prompt); teleport found from your flyouts by the dungeon's name, no data shipped. |
| EllesmereUI_QoL | Bloodlust/Sated tracker, battle res icon | Phoenix has | Phoenix `ascent.brLust`, item bar battle res (PR #66). |
| EllesmereUI_QoL | Cursor ring, alerts, auto logging, self combat text, waypoint | Phoenix has | Cursor ring (Quality); waypoint arrow with a GUI box (Quests); built 2026-10-31: Automation > Auto combat logging (M+ / raid / dungeon, only stops logs it started) and Cooldown Manager > Movement alert. |
| EllesmereUI_QuestTracker | Skin via hooks only | Phoenix has | Phoenix `Phoenix_UI_QuestTracker` (`qt.*`: sort, filter, autoTrackZone, autoQuest, itemButtons, mplusBlock). |
| EllesmereUI_QuestTracker | Quest item hotkey | Phoenix has | Action Bars > Quest item key. |
| EllesmereUI_Quickdraw | Hold-to-open secure palette | Phoenix has | Action Bars > Quick ring; 2026-10-31: hold-and-release mode, open at cursor, v9 ring art. |
| EllesmereUI_RaidFrames | Buff and debuff managers | Phoenix has | Phoenix `rf.buffs`, `rf.debuffs`, `rf.corners`, `rf.privateAuras`, `rf.dispel*`, Indicators.lua. |
| EllesmereUI_RaidFrames | Click casting | Phoenix has | Built 2026-10-29: `Modules/GroupFrames/ClickCast.lua` (Group Frames > Click casting); stands aside for Clique. Blizzard's own Click Casting also works on Phoenix frames. |
| EllesmereUI_RaidFrames | Pet frames, party targets, portraits | Phoenix has | Phoenix `rf.pets`, `rf.partyTargets` (Extra.lua). |
| EllesmereUI_RaidFrames | Forever missing buffs | Phoenix has | Phoenix Reminders (`rm.raid`, `rm.class`). |
| EllesmereUI_ResourceBars | Thresholds and colour bands per spec | Phoenix has | Review 31 (2026-10-31): `Phoenix_UI_UnitFrames/Resources.lua` power threshold colour (a `C_CurveUtil` step alpha curve read by `UnitPowerPercent`, works on secret power), power ticks, spark, gradient, absorbs, visibility rules. The old `Phoenix_UI_ResourceBars` / `rb.*` pointer was stale. |
| EllesmereUI_ResourceBars | Tank active mitigation bars | Phoenix has | Resources.lua: Ironfur / Ignore Pain bars |
| EllesmereUI_ResourceBars | Spec-specific engine drivers | Phoenix has | Resources.lua: Ebon Might |
| EllesmereUI_ResourceBars | GCD bar, cast bar with latency and channel ticks, totem bar | Phoenix has | GCD bar and latency / channel ticks in `Phoenix_UI_CastBars` (Extras.lua, CastBars.lua), totem bar in `Phoenix_UI_UnitFrames/Resources.lua`. |
| EllesmereUI_ResourceBars | Forever: swing timer, druid mana in forms, call totem bar | Phoenix has | Swing timer (Cast Bars), druid mana while shapeshifted (resource block), totem bar (Unit Frames). |
| EllesmereUI_UnitFrames | Frames with stock styles | Phoenix has | Phoenix `Phoenix_UI_UnitFrames` (358 `uf.*` keys, styles, tags, text slots, Blizzard or Phoenix per frame). |
| EllesmereUI_UnitFrames | Player aura bars | Phoenix has | Phoenix `uf.auraBars.*` (+ `dedupeCDM`). |
| EllesmereUI_UnitFrames | Forever weapon imbues | Phoenix has | Built 2026-10-29: `Modules/UnitFrames/Imbues.lua` (Unit Frames > Resources > Weapon imbues), both flavours. |
| EllesmereUI_WindTools | Extra Item Bar (loaded) | Phoenix has | Phoenix auto item bars (PR #66, `ab.ibar1..ibar5`, `ab.ibars`, `Data/ItemBarData.lua`, battle res button, M+ teleports on bar 5). |
| EllesmereUI_WindTools | Quick Focus (loaded) | Phoenix has | Unit Frames > quickFocus (`Modules/UnitFrames/UnitFrames.lua`). |
| EllesmereUI_WindTools | Raid Markers bar (loaded) | Phoenix has | This row was wrong: Quality of Life already had a basic bar. Built 2026-10-29 as one bar in Group Frames > Markers (`Modules/GroupFrames/Markers.lua`, world markers, ready check, pull); the Quality bar was merged into it (schema 7 migration). |
| EllesmereUI_WindTools | Chat Bar (loaded) | Phoenix has | Phoenix `chat.channelBar`, `chat.channelBarSide`. |
| EllesmereUI_WindTools | Friendly Nameplate Outline (loaded) | Phoenix has | Nameplates > Friendly > name text outline (`np.styles.friendly.name.outline`, OUTLINE by default). |
| EllesmereUI_WindTools | Disconnected modules (present on disk, not loaded) | Phoenix has | Already Known tint: built (Automation). Mute list: built (General). Smart tab: declined (writing the chat edit box's chat type taints it and breaks secure slash commands typed in chat). Extended merchant pages: declined (re-anchors Blizzard merchant slots). Event tracker: built (Data Texts > Events: the game's event POIs on your continent with time left, today's holidays). |
| LittleWigs | Dungeon boss modules | missing | Ship the per-dungeon NPC packs (dangerous casts, priority mobs) as data: highest value for M+ players. Keep them original (ours from in-game testing or public spell data) |
| MikScrollingBattleText | Scroll areas and animation styles | Phoenix has | Corrected t195 (no `Phoenix_UI_Spark` on this branch): `Modules/CombatText/Scroll.lua` draws 7 fixed areas (incoming, heals, target, outheal, power, notify, crits; defaults `Modules/CombatText/CombatText.lua:22`), 4 animations (`M.Path`, Scroll.lua:70: straight, parabola, angled, static), direction, align, duration, scale, icon side and size per area (keys `scroll.areas.<area>.*`, Options/CombatText.lua:97-118). Step 2 (2026-10-31): all six MSBT styles (straight, parabola, angled, horizontal, pow, static) on built-in AnimationGroups. |
| MikScrollingBattleText | Hit attribution without the combat log ("worked out") | partial | Corrected t195: incoming text comes from COMBAT_TEXT_UPDATE + `C_CombatText.GetCurrentEventInfo` (Scroll.lua:278), target damage/heals from UNIT_COMBAT "target" (Scroll.lua:298, from everyone, 12.x gives no source), cast icons from your UNIT_SPELLCAST_SUCCEEDED (Scroll.lua:256). No per-spell outgoing attribution. |
| MikScrollingBattleText | Triggers and notifications | partial | Corrected t195: per-event switch, colour, size, area and sound for 30 event types (`scroll.events.*`, CombatText.lua:39-68; Options/CombatText.lua:38-43), crit handling (`scroll.crit` sticky / pop, `critScale`, `critArea`, `critSound`), merge + window, throttle, combat-only. Substitutions built 2026-10-31 (step 4b: `scroll.subs`, `M.Substitute`). User triggers built 2026-10-31 (step 4b: aura gained / faded, reactive spell by name -> message, colour, area, sound; `scroll.triggers`, Triggers tab). Missing vs MSBT: trigger conditions beyond aura and reactive names (health, power and cooldown are secret in 12.x), loot notifications in the scroll (Quality > Loot feed covers loot). Money and XP notifications built 2026-10-31 (step 4b; money off by default to avoid doubling Loot feed). |
| MikScrollingBattleText | Profiles and transfer | Phoenix has | MSBT import built 2026-10-31 (step 4b: `M:ImportMSBT`, Triggers tab button: areas, events, colours, substitutions). `Core/Profiles.lua` (combat text settings are profile data; Blizzard floating-text CVars are account CVars, Options/CombatText.lua:59-80). |
| MountsJournal | Rule-based summon | Phoenix has | Built 2026-10-29: PUI Mount rules (flyer / ground / swimmer names; [swimming] / [flyable] in the macro). |
| MountsJournal | Journal UI upgrades | out of scope | Phoenix: collections skin only. |
| MoveAny | Move/scale any HUD element | Phoenix has | Layout mode moves and scales about 130 Blizzard HUD elements and every Phoenix frame (scale and alpha per mover). Built 2026-10-31: any named frame by click or name (Movers > Any frame; `M:AddAnyFrame`, `M:PickFrame`); per-frame hide (cog popup > Hide this frame, `M:SetHidden`, alpha 0 held against the game's SetAlpha; not offered on frames that animate their own alpha or on Phoenix frames, which have their own switches); a scale per Blizzard window over the shared one (`windowScales`, `M:SetWindowScale`). |
| MoveAny | Move Blizzard windows (moveframes.lua) | Phoenix has | Skins > Move Blizzard windows (Shift+drag saves, Ctrl+drag this session). No longer skipped as a duplicate (t194): scaling those windows is tracked in the row above. |
| MythicDungeonTools | Route planning on a map | out of scope | Do not build a planner (huge, MDT is the standard). Instead read MDT's public API if present (`MythicDungeonToolsAPI:GetEnemyForces(npcId)` documented in `Modules/API.lua |
| MythicDungeonTools | Share and live sessions | Phoenix has | Phoenix share strings exist for settings and layouts; no route sharing. |
| MythicDungeonTools | Architecture lessons | Phoenix has | Phoenix already tests pure logic in `Tests/` with the offline harness. |
| PremadeGroupsFilter | Expression filter | Phoenix has | Phoenix `Phoenix_UI_GroupFinder/Expr.lua`: an original parser (or/and/not/compare/sum/term grammar), no `loadstring`, reports unknown names with a suggestion. Plus `gf.*` |
| PremadeGroupsFilter | List improvements | Phoenix has | Phoenix `gf.age`, `gf.roleIcons`, `gf.leaderCrown`, `gf.compact`, `gf.ownLockout`, `gf.bossesDown`, `gf.rioScore`, `gf.cancelOldest`, `gf.declined`, QueueHelper sign-up/E |
| PremadeGroupsFilter | Skin plugin (EllesmereUI) | Phoenix has | Skins > Premade Groups Filter. |
| Questie | Map and minimap pins from a quest database | out of scope | Not planned (data licence). For Forever players recommend Questie; make sure our QuestTracker yields (`qt.hideBlizzard` vs Questie tracker). |
| Questie | Tracker, tooltips, announce | Phoenix has | Built 2026-10-29: `Modules/Quests/Progress.lua` (objective / complete sounds, optional party announce); quest tooltips: Quests > Tooltip. |
| Questie | Session recorder (QuestieTrace) | out of scope | No session recorder on this branch; `Core/Errors.lua` scrubs private data from errors. |
| Questie | Unit tests in Lua | Phoenix has | Offline harness `tools/smoke/harness.lua` (235 named tests at 2026-10-29), run for both clients by `tools/check_flavors.py`. |
| RaiderIO | Score and progress in tooltips | out of scope | Keep the "use Raider.IO when installed" integration; never ship their data. |
| RaiderIO | Copy URL / search | Phoenix has | Chat > Armory link in menus. |
| RaiderIO | Combat logging helper | Phoenix has | Phoenix `flow.combatLog`, `flow.combatLogWhere`. |
| RareScanner | Vignette alerts with target button | Phoenix has | Automation > Rare alert (secure target button, waypoint). |
| RareScanner | World map database and loot | out of scope | Not planned; recommend RareScanner alongside Phoenix. |
| Simulationcraft | Profile string export | Phoenix has | Phoenix `Phoenix_UI_Wisdom/SimC.lua` (`wisdom.simc`, `wisdom.simcBags`). |
| SpecBisTooltip | BiS line on tooltips | Phoenix has | Tooltip > BiS list (paste item IDs or a PUI-BIS: string). |
| TrufiGCD | Ability queue | Phoenix has | Phoenix `Phoenix_UI_CastHistory` (`ch.*`: unit, direction, speed, blockSpells/blockItems, showCancelled, showInterrupted, empowerHeld, masque, where). Phoenix also covers |
| Tust_EUI | Chat replacement | Phoenix has | Phoenix `Phoenix_UI_Chat` (skin, history, whisper windows, channel bar, emoji, keyword alerts). |
| Tust_EUI | Data Bars multi-bar engine | Phoenix has | Phoenix DataBars (`db.*`), `rt.*`, friends in minimap (`mm.extra.friends`). |
| Tust_EUI | Enhanced XP bar, LFG region/rating, nameplate rules, tooltips, bag upgrade markers, stat priorities, minimap group info | partial | Quest-XP on the XP bar (`Modules/DataTexts/Bar.lua`), upgrade arrows in bags (`Modules/Bags`). Minor-enemy plates built 2026-10-31 (Nameplates > Minor enemies, `M.IsMinor`, smaller and dimmer). LFG region/rating badges not found. |
| EllesmereUI | Full in-addon macro editor (account / character, icon picker, conditionals helper) | Phoenix has | Built 2026-10-31: `Phoenix_UI_Automation/MacroEditor.lua` (M:ShowMacroEditor, MacroList, SaveMacro, InsertSnippet); Automation > Macro editor. |
| EllesmereUI | Loot council | Phoenix has | Built 2026-10-31: Automation > Loot council (session drops, Want shares your equipped item level, auto-open, raid only). |
| EllesmereUI | Loadout manager | Phoenix has | Built 2026-10-31: Automation > Loadouts (talents + equipment set per content per spec, offer or auto apply). |
| EllesmereUI_CooldownManager | Cooldown Manager parity pass | Phoenix has | 2026-10-30: Cooldown Manager rows, aura reminders (custom, group buffs, banner style), aura bars (`Tracker/AuraBars.lua`). |
| EllesmereUI_MythicTimer | Timer art and clock alignment | Phoenix has | 2026-10-30: v9 timer art (bar, skull, chest marks, forces, affixes), clock alignment. |
| EllesmereUI_Minimap | Button bin as flyout or bar | Phoenix has | 2026-10-30: Minimap > bin mode flyout / bar. |
| EllesmereUI_DataBars | Time, gold and bugs data texts with v9.1 art | Phoenix has | 2026-10-30: ember caps and dividers, 12/24h and local/server options, live bug count. |
| MikScrollingBattleText | Custom scroll areas, every area in Layout mode | Phoenix has | Built 2026-10-31 (e3473f7): user areas (add, name, rename, remove, route events; `scroll.custom`, `M:AddArea` in `Modules/CombatText/Scroll.lua`); every area is always a Layout-mode mover with snapping, on or off. |
| MikScrollingBattleText | Per-event sound and icon rules | Phoenix has | t195: sound per event exists (`scroll.events.<e>.sound`); icons only from your own casts (`scroll.castIcons`). Gap: icon per event, sticky per event. Step 3 (2026-10-31): every line has an icon (spell icon, your last cast, else a Phoenix glyph per event in the line colour, `scroll.glyphIcons`). Built 2026-10-31 (t198): per event Always sticky (`events.<e>.sticky`), Show the icon (`events.<e>.icon`) and Message with %a (`events.<e>.msg`, `M.Template`), Font per event (`events.<e>.font`, the six combat faces); MSBT import takes alwaysSticky and %a messages. |
| BigWigs | Per-boss knowledge (LittleWigs-style warnings) | partial | Timeline bars and ability rules; no per-boss authored warnings. |
| RareScanner | Rare already-killed / loot status on the alert | partial | Built 2026-10-31: killed today and seen today on the toast, per character, cleared at the daily reset (`M.NoteRare`, `M.RareStatus`, RareAlert.lua). Gap: loot-collected marks need per-rare loot data. |
| WindTools | Smart Tab, Event Tracker, CVar editor, merchant extra pages | partial | CVar editor built 2026-10-31 (Automation > CVar editor, `Phoenix_UI_Automation/CVarEditor.lua`). Ideas list (docs/research/windtools.md); Smart Tab was declined for taint, re-check. |
| WindTools | Combat alert banner and sound, announcements set, sound mute list by ID, world map scale | Phoenix has | Re-checked 2026-10-31: combat alert (Quality `combatAlert`), sound mute by file ID (General `GEN_MUTE`, General.lua:89), world map scale (Minimap `worldMapScale`); announcements built 2026-10-31 (Automation > Announcements: new key, instance reset, thanks; Announce.lua). |
| NaowhForever | Training planner, profession recipes incl. unlearned, gear swap bar, paladin blessings | missing | Forever-first ideas (docs/research/naowhforever.md); data from the wowf DB2 build. |
| NaowhForever | Forever dungeon journal, group inspect window, threat meter window | partial | Encounters data, meter item level and plate threat exist; add the windows. |
| idTip | IDs on every tooltip kind | Phoenix has | Tooltip > ids and idKinds (`Phoenix_UI_Options/Options/Tooltip.lua:93`, `Modules/Tooltip/Tooltip.lua`). |
| sArena_Reloaded | Arena frames with layouts | Phoenix has | Arena units in `Modules/UnitFrames/Arena.lua` (trinket, spec, racial, DR) and PvP extras in `Modules/PvP/PvP.lua` (shadowsight, safe queue). |
| sArena_Reloaded | DR tracking in Midnight | Phoenix has | `Modules/UnitFrames/Arena.lua` turns on the game's enemy DR tracking (`spellDiminishPVPEnemiesEnabled`) and re-parents its DR trays into Phoenix arena frames. |
| sArena_Reloaded | Trinkets, racials, dispels, interrupts | Phoenix has | Phoenix `arena.racial`, `arena.dispelTracker`, trinket in `State.lua`. |
| sArena_Reloaded | Midnight absorbs and auras | Phoenix has | Phoenix `arena.auraOrder`, `arena.auraGlow`, `arena.classAura`. |
