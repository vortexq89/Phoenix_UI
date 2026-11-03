# Shared libraries found in the studied addons

> Libraries are grouped here instead of getting their own files. Embedded copies were skipped when counting each addon's own code. Licences of individual libraries were **not** verified file by file; treat them as their authors' terms. Phoenix bundles none of these (it only looks them up at runtime when another addon loaded them).

| Library | What it does | Embedded by | Phoenix_UI position |
|---|---|---|---|
| LibStub | Version-safe library registry: the shared loader every embedded library uses. | Auctionator, AutoQueue, BetterWardrobe, BigWigs, BugSack, EllesmereUI, MountsJournal, MDT, RaiderIO, RareScanner, Simulationcraft, sArena, Questie, TrufiGCD, MSBT | Phoenix looks libraries up through LibStub when present (`Core/Media.lua`, `Core/Masque.lua`, CastHistory/HUD extras) and never requires it. |
| CallbackHandler-1.0 | Event/callback dispatch used by Ace3 and most libraries. | Most Ace3 users, EllesmereUI, RaiderIO, MDT | Phoenix uses its own kernel events (`Core/Kernel.lua`). |
| Ace3 (AceAddon, AceEvent, AceDB, AceConfig/Dialog/Registry, AceGUI, AceConsole, AceComm, AceSerializer, AceTimer, AceHook, AceLocale, AceBucket) | Addon framework: lifecycle, events, profiles, options GUI, comms, serialisation, timers. | BetterWardrobe, BigWigs_Options (AceConfig/GUI only), RareScanner, Simulationcraft, sArena, MDT (AceDB/AceComm), BugSack (AceComm/AceSerializer), Questie | Phoenix has its own schema-driven DB, options and profiles; EllesmereUI also replaced Ace with a "Lite" layer for speed. No change needed. |
| LibSharedMedia-3.0 (+ AceGUI-3.0-SharedMediaWidgets) | Shared registry of fonts, bar textures, borders, sounds. | BigWigs, BugSack, EllesmereUI, MDT, RareScanner, sArena, MSBT, Questie | Phoenix registers and reads LSM media (`Core/Media.lua`), so users see our fonts in other addons and theirs in ours. Keep. |
| LibDataBroker-1.1 / LibDBIcon-1.0 | Data feeds ("brokers") and minimap icons. | AutoQueue, BigWigs, BugSack, EllesmereUI, MDT, RaiderIO, Simulationcraft, RareScanner, Questie | Phoenix collects minimap buttons in the button bin (`Phoenix_UI_HUD/ButtonBin.lua`); a Phoenix broker feed for third-party data bars is **unverified**. |
| LibDeflate / LibSerialize | Compression and serialisation for share strings and addon messages. | EllesmereUI, sArena, MSBT, Questie, MDT (route strings) | Phoenix share strings use their own encoder (unverified which); fine. |
| LibKeystone | Shares party/guild keystones over the addon prefix `LibKS` ("level,mapID,rating", "R" to request). | BigWigs, EllesmereUI, EllesmereUI_WindTools | **Not supported by Phoenix** (we use `PUIKEYS`). P1: speak the same wire format in our own code. |
| LibOpenRaid | Details!' group data sharing (cooldowns, keystones, gear) over prefix `LRS`. | EllesmereUI_WindTools | Phoenix PartyCD watches casts only. P2: if LibOpenRaid is already loaded by another addon, read its cooldown data through LibStub to fill gaps where Midnight hides party casts (no bundling; licence of the library unverified). |
| LibSpecialization | Shares specs/roles in group. | BigWigs, EllesmereUI | Phoenix reads inspect/role APIs. P3 optional read. |
| LibCustomGlow-1.0 | Pixel/autocast/button glow effects. | BigWigs_Plugins, sArena | Phoenix has original glows (`glows.*`). |
| LibCandyBar-3.0 | Timer bars. | BigWigs_Plugins | Phoenix `Core/Bars.lua`. |
| LibSink-2.0 | Route messages to chat/frames/SCT. | BigWigs_Plugins | n/a |
| LibRangeCheck-3.0 | Range estimates to units. | EllesmereUI_WindTools | Phoenix range fade uses Blizzard APIs (`range.*`). |
| HereBeDragons(-2.0) | Map coordinates and distances. | RareScanner, Questie | Phoenix `Core/Waypoint.lua` uses `C_Map` directly. |
| LibQTip-1.0 | Multi-column tooltips. | RareScanner, EllesmereUI_WindTools | Phoenix tooltips are own frames. |
| LibDualSpec-1.0 | Profile per spec for AceDB. | BigWigs | Phoenix `Core/SpecProfiles.lua`. |
| LibDropDownExtension-1.0, LibSFDropDown, LibUIDropDownMenu, ElioteDropDownMenu | Drop-down menu helpers / taint-safe menus. | RaiderIO, MountsJournalUI, Questie, WindTools | Phoenix uses Blizzard `MenuUtil`. |
| LibDurability, LibLatency | Share durability/latency in raid. | BigWigs | n/a |
| LibCombatLogging-1.0 | Coordinated combat logging. | RaiderIO | Phoenix `flow.combatLog`. |
| LibClassTalentsImportExport-1.0 | Talent string import/export. | RaiderIO | Phoenix Loadouts uses `C_ClassTalents`. |
| LibAHTab, LibBattlePetTooltipLine, LibCBOR | Auction House tab helper, pet tooltip line, CBOR encoding. | Auctionator | n/a |
| LibAppropriateItems, LibArmorToken, TaintLess | Transmog helpers; TaintLess patches known Blizzard taint paths. | BetterWardrobe | Phoenix avoids taint by design (Sentinel `Taint.lua` monitors). |
| LibThingsLoad | Async item/spell data loading. | MountsJournal | Phoenix `Core/Items.lua`. |
| LibAsync / ThreadLib | Spread long work over frames. | MDT / Questie | Phoenix `Core/Budget.lua` and the Ticker. |
| D4Lib | D4KiR's shared helper library. | MoveAny, SpecBisTooltip | n/a |
| LibItemEnchant, LibObjectiveProgressWT | Enchant names; NPC objective progress (forces %). | EllesmereUI_WindTools | Phoenix forces data in Ascent / tooltips. |
| LibRealmInfo, LibTime-1.0, LibAboutPanel-2.0, LibDialog-1.0, LibPopupStack-1.0, LibTextDump-1.0, LibDDI-1.0, ChatThrottleLib, Krowi_WorldMapButtons | Realm data, time helpers, about panel, dialogs, popups, text dump, data-driven icons, chat throttling, world-map buttons. | Simulationcraft, RareScanner, Questie(Trace), BigWigs_Options, MountsJournal | Phoenix: own equivalents where needed; ChatThrottleLib-style throttling exists in Phoenix comms (unverified). |

## Verdict

Two libraries matter for Phoenix as **protocols**, not code: LibKeystone (keystone sharing, P1) and LibOpenRaid (party cooldowns, P2). Everything else Phoenix already does with its own core.
