# Phoenix UI roadmap (restored design, from 28 Oct 2026)

The original Phoenix design (`restore/v1-ui`) is the base again. This roadmap brings the valuable parts of the v2
work and of the addon research **into that design**, one item at a time. It replaces the 2.0.0 roadmap, which is
kept as [plan_v2/ROADMAP_2.0.0.md](plan_v2/ROADMAP_2.0.0.md).

Sources: [research/addons/README.md](research/addons/README.md) (86 addon folders studied),
[v2-reference/](v2-reference/README.md) (v2 plan, deferred list, review, in-game checks, release notes) and
[research/RECOVERY_REPORT.md](research/RECOVERY_REPORT.md).

## Rules for every item

1. **One owner.** Each feature goes into the existing module named in the table: its code in
   `Modules/<Module>/`, its settings on that module's page (`Phoenix_UI_Options/Options/<Module>.lua`), its sample
   in that page's preview. No new addon folder, no second page for the same thing, no duplicate setting.
2. **Original code only.** The research describes ideas; nothing is copied from another addon (most are All
   Rights Reserved or GPL; EllesmereUI and WindTools forbid reuse).
3. **Game art for game things.** Spell, ability, aura, cooldown and item icons are always the game's own icons.
   Phoenix glyphs are only for Phoenix's own chrome (window buttons, headers, status markers).
4. **Live and safe.** Settings apply live with no `/reload`; protected changes wait for the end of combat
   (`ns.Combat:Run`); secret values are passed to widgets, never compared; no `OnUpdate` for polling.
5. **Fits.** The options layout check and the default-position check in `tools/smoke/harness.lua` must stay at
   zero problems; previews fit their card.
6. **Done means:** luac, `tools/check_api.py`, `tools/check_ids.py`, `tools/check_locales.py` and the offline load
   test pass for retail and Forever, CI is green, **and an in-game screenshot of the feature with zero errors in
   the Bugs window** (`/pui bugs count` = 0 Phoenix reports) is attached to its pull request. One item per pull
   request.

## Status 31 Oct 2026 (parity pass, t169 / t191-t197)

Done (see CHANGES.md 2.0.0-beta2 for dates and commits): Cooldown Manager, aura reminders and aura bars, Mythic+ timer art, minimap bin bar, auto combat logging, movement alert, Quickdraw hold mode, data texts v9.1 art, art kits v7.1 / v8.1 / v9.1, code-review and QA fixes, GUI for every slash feature, macros Pick up, upgrade calculator, What's new full changelog, loot council, loadouts, party mode, gamepad, combat text user areas, combat text MSBT styles on built-in animations, an icon on every combat text line.

In progress: combat text MSBT parity (Blizzard text ledger, notifications, triggers, substitutions, MSBT import, combat fonts: Phoenix Font Bold plus Bebas Neue, Oswald, Russo One, Black Ops One, Grenze Black).

Still missing (docs/research/FEATURE_COVERAGE.md): full macro editor, MoveAny-level any-frame move / scale / hide, RareScanner killed and loot marks, LittleWigs-style dungeon warnings, WindTools and NaowhForever ideas, then the EllesmereUI 'equal' rows. Localization polish last.
## Order of work

Phase 0 (now): the user's in-game pass of the restored build. Fix what it finds before anything below.

| # | Item | Module (existing) | Source | Acceptance criteria (plus rule 6) |
|---|---|---|---|---|
| 1 | Keystone sharing in the common `LibKS` format (level, map, rating; request "R"), so `/keys` sees BigWigs, DBM and EllesmereUI users | MythicPlus (`Keystones.lua` already speaks part of it) | research #1 | A party member running only BigWigs shows in the keystone list with level and dungeon; no duplicate when they also run Phoenix |
| 2 | Auto item bars: flasks, food, potions, healthstones, runes, oils, trinkets, quest items, own list; filled from bags | ActionBars (`Extras.lua` item bar grows into up to 3 item bars) | v2 #66 | Each bar fills from real bags with game item icons; size, layout, fade and show rules on the Action Bars page with a live preview; nothing in Forever that Forever lacks |
| 3 | Battle res button and shared charge counter for classes that have one | ActionBars (item bar slot) + MythicPlus timer (charges) | v2 #66 | Druid/DK/warlock/paladin see the button with charges and recharge time; others never see it |
| 4 | Compact loot roll bars | Skins (loot roll is a Blizzard window) | v2 #69 | Need/Greed/Transmog/Pass work in a group; item icon and quality from the game; `/pui loottest` sample |
| 5 | Party cooldown and interrupt tracker on party frames (cast events, own cooldown table; fill in from LibOpenRaid when another addon loaded it) | GroupFrames | v2 #68, research #2 | Icons are the spells' game icons; shows interrupts and major defensives of a 5-player group; off by default; honest "hidden in instance" behaviour |
| 6 | "Casts on me" targeted spell bars | CastBars | research #5 | A mob casting at the player shows a bar with the spell's icon and time; secret-safe; off by default |
| 7 | Tank active-mitigation bars (Ironfur, Ignore Pain, Shield Block …) next to stagger | UnitFrames (`Resources.lua`) | research #7 | Correct uptime/charges for each tank spec; spell icons from the game |
| 8 | Talent conditions on Cooldown Manager / custom bar entries | Tracker | research #6 | An entry tied to a talent hides when the talent is not taken, live on respec |
| 9 | Move Blizzard windows (Shift-drag saves, Ctrl-drag for the session) | Movers (`M.WINDOWS` already scales them) | research #8 | Character, Spellbook, Collections etc. remember their place; never a protected frame in combat |
| 10 | "What's new" popup once per version | General (Home page already has the hook) | research #9 | Shows once after an update, closable, links to the changelog; never in combat |
| 11 | Mythic+ teleport flyout and hearthstones | MythicPlus | v2 #70 | Only teleports the character knows, game spell icons, secure buttons built out of combat |
| 12 | Paragon progress on the reputation data text | DataTexts | v2 #70 | Paragon factions show progress and reward-ready |
| 13 | Rare and treasure alerts with a waypoint (vignettes) | Quests (`Collector.lua` already reads vignettes; `Arrow.lua` is the waypoint) | v2 #71, research RareScanner | Alert once per rare, click sets the arrow; no alert spam in cities |
| 14 | Masque support for action bars, item bars and tracker icons | ActionBars, Tracker | v2 #67 | Does nothing without Masque; with Masque every button skins and Phoenix's border yields |
| 15 | Already Known tint at merchants, AH and collections | Quality | research #9 | Known recipes, mounts, pets, toys tinted; game icons untouched |
| 16 | Mail alt list | Automation | research #9 | Alts of the account listed beside Send Mail; click fills the recipient |
| 17 | Arabic text shaping (letters joined, right to left) for the Arabic locale | Locales + Core (one shaper) | v2 Core/Shaper | Arabic strings render joined and in order on every page; no effect on other locales |
| 18 | Per-dungeon trash data (dangerous casts, priority mobs) and boss timer data | NamePlates, Encounters | research #3, #4 | Needs the user's in-game runs first; data files load on demand per instance |
| 19 | Uploader and signed "fixed errors" list (v2 FIXED_SYNC) | Bugs | v2-reference/FIXED_SYNC.md | Only after the bug flow above is proven in daily use |
| 20 | Small wins: spell queue slider (exists in Quality, verify), focus key (exists in UnitFrames `quickFocus`, verify), AFK screen (exists, verify), mute list (exists in General) | various | v2 #70, #71 | Each verified in game; nothing rebuilt that already exists |

## Not doing

- A second UI framework, Studio, Sentinel, or any v2 window: the restored design keeps one options window, one
  movers mode and one Bugs viewer.
- Combat-log based features (closed in Midnight), WeakAuras-style custom aura engines (aura data is secret in combat).
- Bundling other addons' code (the old `main` / `legacy-baseline` did; never again).
