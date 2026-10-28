# BigWigs Bossmods (core, plugins, options and all content packs)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\. Game folder core v427.8, I:\ core v427.7; expansion packs v12.1.x in both.

**Licence:** All Rights Reserved: "You are free to fork and modify on GitHub, please ask us about anything else" (toc X-License). Study only.

The most used boss mod. A tiny always-loaded **loader** (`BigWigs`) watches zones and loads `BigWigs_Core`, `BigWigs_Plugins` and the right content pack on demand. Each boss is a module written against a prototype API (`BigWigs:NewBoss`). In Midnight the combat log is closed, so the current modules are driven by Blizzard's **encounter timeline** and **encounter warnings** with BigWigs adding names, sounds and colours on top.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `BigWigs` | v427.8 | v427.7 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 70 / 35,251 |
| `BigWigs_Core` | v427.8 | v427.7 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 5 / 11,941 |
| `BigWigs_Plugins` | v427.8 | v427.7 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 22 / 18,785 |
| `BigWigs_Options` | v427.8 | v427.7 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 3 / 4,735 |
| `BigWigs_TheVoidspire` | v427.8 | v427.7 | 120100, 120105, 120107 | 7 / 3,940 |
| `BigWigs_TheDreamrift` | v427.8 | v427.7 | 120100, 120105, 120107 | 2 / 717 |
| `BigWigs_MarchOnQuelDanas` | v427.8 | v427.7 | 120100, 120105, 120107 | 3 / 1,464 |
| `BigWigs_TheVenomousAbyss` | v427.8 | v427.7 | 120100, 120105, 120107 | 9 / 5,959 |
| `BigWigs_TheUnbindingOfKithix` | v427.8 | v427.7 | 120100, 120105, 120107 | 2 / 765 |
| `BigWigs_Sporefall` | v427.8 | v427.7 | 120100, 120105, 120107 | 2 / 323 |
| `BigWigs_MidnightLairs` | v427.8 | v427.7 | 120100, 120105, 120107 | 2 / 317 |
| `BigWigs_MidnightWorld` | v427.8 | v427.7 | 120100, 120105, 120107 | 4 / 336 |
| `BigWigs_TheWarWithin` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 43 / 18,364 |
| `BigWigs_Dragonflight` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 45 / 18,956 |
| `BigWigs_Shadowlands` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 50 / 23,333 |
| `BigWigs_BattleForAzeroth` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 63 / 20,520 |
| `BigWigs_Legion` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 74 / 27,006 |
| `BigWigs_WarlordsOfDraenor` | v12.1.0 | v12.1.0 | 120100, 120105, 120007 | 48 / 16,544 |
| `BigWigs_MistsOfPandaria` | v12.1.0 | v12.1.0 | 50504, 50503, 120100, 120105, 120007 | 60 / 22,565 |
| `BigWigs_Cataclysm` | v12.1.0 | v12.1.0 | 40402, 50504, 50503, 120100, 120105, 120007 | 42 / 11,982 |
| `BigWigs_WrathOfTheLichKing` | v12.1.0 | v12.1.0 | 30405, 38002, 40402, 50504, 50503, 120100, 120105, 120007 | 67 / 18,142 |
| `BigWigs_BurningCrusade` | v12.1.11 | v12.1.11 | 40402 | 77 / 14,889 |
| `BigWigs_Classic` | v12.1.2 | v12.1.2 | 40402 | 151 / 26,755 |

- **Title / notes (toc):** BigWigs - Modular, lightweight, non-intrusive approach to boss encounter warnings.
- **Author (toc):** Funkeh, Nebula, Justwait, Delk
- **X-License (toc):** All Rights Reserved: You are free to fork and modify on GitHub, please ask us about anything else.
- **SavedVariables:** `BigWigs3DB`, `BigWigsIconDB`, `BigWigsStatsDB`
- **Slash commands:** `/bigwigs`, `/bw`, `/bwv`
- **Optional deps:** Ace3, LibCandyBar-3.0, LibSharedMedia-3.0, LibSink-2.0, LibDBIcon-1.0, LibDDI-1.0, LibSpecialization, LibDualSpec-1.0, LibCustomGlow-1.0, LibKeystone, LibLatency, LibDurability
- **Embedded libraries:** CallbackHandler-1.0, LibDataBroker-1.1, LibDualSpec-1.0, LibDurability, LibKeystone, LibLatency, LibSharedMedia-3.0, LibSpecialization, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 15x, `C_Timer` calls 7x.
- **Secure surface:** `SetAttribute` 9x
- **Hooks:** `HookScript` 5x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD`, `CHALLENGE_MODE_START`, `UNIT_TARGET`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED`, `CHALLENGE_MODE_COMPLETED`, `NAME_PLATE_UNIT_ADDED`, `INSTANCE_CHAT`, `GROUP_LEFT`, `ENCOUNTER_START`, `UNIT_CONNECTION`, `NAME_PLATE_UNIT_REMOVED`, `PLAYER_TARGET_CHANGED`, `GROUP_FORMED`, `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`, `ENCOUNTER_END`, `START_PLAYER_COUNTDOWN`, `CANCEL_PLAYER_COUNTDOWN`
- **C_ namespaces used:** `C_PartyInfo`, `C_AddOns`, `C_ChallengeMode`, `C_MythicPlus`, `C_CVar`, `C_Container`, `C_Spell`, `C_ChatInfo`, `C_BattleNet`, `C_ClassColor`, `C_Timer`, `C_Map`, `C_ScenarioInfo`, `C_PlayerInfo`, `C_CreatureInfo`, `C_EncounterJournal`, `C_UIWidgetManager`, `C_GossipInfo`, `C_PlayerChoice`, `C_Item`, `C_NamePlate`, `C_UnitAuras`

### Architecture

Loader (`Loader.lua`) holds zone-to-addon maps and version checks (`GuildVersion.lua`), plus always-on tools (`Tools/`: AutoInvite, AutoRole, CombatTimer, Keystones, LFGTimer). Core (`Core.lua`, `BossPrototype.lua` ~5k lines, `PluginPrototype.lua`) defines the module API: `Bar/CDBar/StopBar`, `Message`, `PlaySound`, `Nameplate`, `Log` (combat-log listeners on older content), `RegisterEngageMob`, `ScheduleTimer`. Plugins are each a module (Bars, Messages, Sound, Countdown, Pull, Break, BattleRes, BossBlock, Nameplates, InfoBox, AltPower, Proximity, AutoReply, Statistics, Victory, Wipe, Colors, Flash, RaidIcon, Timeline). Options are load-on-demand (AceConfig).

## Features

### Midnight timers from the encounter timeline

- **What it does:** Shows boss timer bars for current content even though addons can no longer read the combat log.
- **Design (UX, settings, defaults):** Plugin `Timeline.lua`, setting `timersMode`: "enhanced" (default, BigWigs bars fed by the timeline plus module renames and sounds), "blizzbars" (Blizzard's basic data shown as bars), "blizztimeline" (only Blizzard's timeline, no bars), "dev". A warning is shown if you leave "enhanced".
- **How it is coded:** Listens to `ENCOUNTER_TIMELINE_EVENT_ADDED/STATE_CHANGED/REMOVED`, reads `C_EncounterTimeline.GetEventList/GetEventInfo/GetEventState/GetEventTimeRemaining`, and uses `AddEditModeEvents` for test bars. Values are checked with `issecretvalue` before use. Boss modules for Midnight raids (e.g. `BigWigs_TheVoidspire`) mostly map timeline events to friendly names (`GetRename`) and sounds, and react to `ENCOUNTER_WARNING` for "on you" messages. Pseudo: `on TIMELINE_EVENT_ADDED(info): if module.rename[info.spell] then bar(name, info.duration) end`.
- **Benefit to players:** Clear named timers and sounds in Midnight raids, consistent with older content.

**Compared with Phoenix_UI** - status: **same core idea; BigWigs is ahead on per-boss knowledge**. Phoenix `Phoenix_UI_Pulse/Pulse.lua` draws bars from `C_EncounterTimeline` (sorted event list, engine duration objects, highlight events) and soft-yields when BigWigs/DBM are loaded (Coexist "pulse.timeline"). `pulse.bossRules`, `pulse.bigwigsStyle`, `pulse.auraSounds`, `pulse.nextHud` exist.

Ideas to adopt (original code only): Per-boss **rename and sound packs** are BigWigs' real value. We could ship an original, data-only "boss pack" format (spellID -> short name, sound, colour, severity) in `Pulse` and let the community fill it, instead of code per boss. Do not copy BigWigs' rename tables.

### Messages, sounds, countdown voice

- **What it does:** Big centre messages, emphasised messages, sounds per option and a spoken 5-4-3-2-1 countdown.
- **Design (UX, settings, defaults):** Per-ability option bitflags (`Constants.lua`: bar, message, sound, icon, flash, nameplate, emphasize...). Voice packs selectable; invalid voice is reset.
- **How it is coded:** Messages plugin anchors just below the boss emote frame and grows down. Countdown plugin owns its own frames and voice table. Sounds go through LibSharedMedia.
- **Benefit to players:** Players learn mechanics by sound; per-ability toggles reduce noise.

**Compared with Phoenix_UI** - status: **partial**. Phoenix Pulse has `pulse.countdownSound`, `pulse.colorCountdown`, severity colours; Spark/Toast for text. No per-ability option grid.

Ideas to adopt (original code only): Add a per-ability override grid in the Pulse options (show bar / sound / message / hide) keyed by spellID, generated from what the timeline reported in the last pulls (learned list).

### Pull, break and battle-res tools

- **What it does:** `/pull`, `/break`, battle-res counter, combat timer, LFG ready timer, auto invite by keyword, auto role.
- **Design (UX, settings, defaults):** Plugins with their own frames; LFG timer exposes a callback so skins can style it.
- **How it is coded:** Pull/Break send addon messages so every BigWigs/DBM user sees the same countdown; BattleRes reads the shared charge pool.
- **Benefit to players:** Raid leaders get standard tools.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_RaidTools` (`rt.pullSeconds`, `rt.breakMinutes`, `rt.mplusCountdown`, `/pui cd`), battle res on item bar and in Ascent (`ascent.brLust`), `Skins/QueueTimer.lua`.

### BossBlock (noise control)

- **What it does:** During encounters hides talking heads, emotes, movies, zone text, objective tracker, garrison toasts, and can mute music/ambience; redirects toasts.
- **Design (UX, settings, defaults):** Defaults: talking heads blocked in Mythic dungeons, raids, timewalking, scenarios and delves but not normal/heroic dungeons; movies blocked (remembering watched ones); spell error text blocked.
- **How it is coded:** Toggles CVars and hides frames at engage, and re-enables CVars on load "just in case" a disconnect left them off.
- **Benefit to players:** Less clutter in hard content.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_Flow/Quiet.lua` (`flow.quiet.instances`, `flow.quiet.where`), `flow.hideBanners`, `flow.hideErrors`; CVar ledger restores old values.

Ideas to adopt (original code only): Copy the "restore CVars at load if a fight ended abnormally" safety net; our ledger should already restore (verify a disconnect mid-fight case).

### Nameplate icons and InfoBox/AltPower

- **What it does:** Timers on enemy nameplates, info box with player lists, alternate power list.
- **Design (UX, settings, defaults):** Per module.
- **How it is coded:** Nameplates plugin attaches text/icon frames to plates with rounding for timers.
- **Benefit to players:** Mechanics that target mobs are visible where you look.

**Compared with Phoenix_UI** - status: **missing (low value without a module API)**. Phoenix Nameplates has cast/aura lanes and M+ indicators; no boss-module nameplate timers.

### Statistics

- **What it does:** Counts kills, wipes, best time per boss and difficulty.
- **Design (UX, settings, defaults):** Shown in options per boss.
- **How it is coded:** Saved per boss id on `ENCOUNTER_END`.
- **Benefit to players:** Progress tracking.

**Compared with Phoenix_UI** - status: **same**. Phoenix `rt.stats.*` (encounter stats with wipe trend, `rt.stats.yieldToBossMods`).

## Verdict

Phoenix Pulse already follows the Midnight-safe model (timeline first, yield to BigWigs). The gap is content knowledge (renames, sounds per spell), which is data, not code. Priority P2: a data-only boss pack format plus per-spell override grid.
