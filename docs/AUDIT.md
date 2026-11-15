# Phoenix_UI — Legacy Audit (pre-rework baseline `a2c69a9`)

> Target: **World of Warcraft Retail 12.1.5 "Midnight"**, `## Interface: 120105`, live build **12.1.5.70448**
> (wago.tools `wow` branch, detected 2026-10-16; Gethe `wow-ui-source` live commit `b9be937` "12.1.5 (70448)").
> PTR (`wowt`) is 12.1.7 (70424) at the time of writing and is **not** the target.
>
> Sources used for every API claim in this document: Blizzard FrameXML 12.1.5.70448 (`/workspace/ref/wow-ui-source`),
> `Blizzard_APIDocumentationGenerated` (dumped to `api_dump.tsv`, 8 347 rows incl. secret flags),
> Ketho BlizzardInterfaceResources (`live`), warcraft.wiki.gg *Patch 12.0.0 / 12.0.5 / 12.1.0 / 12.1.5 API changes*,
> *Secret values* and *Patch 12.0.0/Planned API changes* pages. Nothing is from memory.
> The mechanical findings are reproducible: see `tools/audit/` and [`docs/audit/API_FINDINGS.md`](audit/API_FINDINGS.md).

---

## 0. TL;DR

| Metric | Value |
|---|---|
| Lua/XML files | ~605 (≈159 k loaded Lua/XML lines + 11.6 k dead) |
| Media | 77 fonts (24 MB — one font, `AvantGarde.TTF`, is 13 MB), 131 textures (4.7 MB) |
| Embedded third-party *addons* | 5 (MoveAny, MikScrollingBattleText + MSBTOptions, BuffOverlay, PremadeGroupsFilter, OmniCC/OmniCD/TrufiGCD-style CooldownTracker) |
| Option frameworks in parallel | 5 (Phoenix_Config, AceConfig/AceGUI ×2 copies, MSBTOptions, PGF settings, MoveAny settings) |
| Unknown / removed globals referenced | **612 names, 1 747 references** (luacheck vs. generated 12.1.5 std) |
|  → removed/renamed API calls needing replacement | 96 names / 313 refs |
|  → combat-log (CLEU) usage — **forbidden in 12.x** | 20 live registrations in 7 files (+3 dead) |
|  → calls to functions defined nowhere (runtime errors) | 21 names / 233 refs (`FlushSavedVariables`/`FlushSettingsDB` alone: 174) |
|  → undefined locals / scoping bugs | 15 names / 61 refs |
|  → removed Blizzard frame names (old skin targets) | 428 names / 1 011 refs |
| Non-existent `C_` namespace fields called | 15 fields / 34 refs |
| Writes to Blizzard/shared globals (taint/collision) | 126 sites |
| Accidental global leaks (W111) | 124 addon-created globals (`btn`, `tab`, `msg`, `data`, `class`, …) |
| Dead (never-loaded) Lua/XML files | 70 files / ≈11.6 k lines |
| Case-mismatched XML includes (Windows-only loading) | 52 |
| TOC | `## Interface: 100205, 30401, 11501` → **does not load at all on 12.x** (addons < 120000 are hard-blocked) |

**Bottom line:** the current addon cannot load on Midnight, and even with the TOC bumped it would hit hundreds of
nil-call errors, register a now-forbidden event in 7 modules and taint Blizzard frames from ~126 sites. Roughly 60 %
of the code by line count is third-party addons copied in wholesale. A rewrite on a new core is the only path to
"zero errors / zero duplication / zero taint". The art assets, the feature *list*, and some small modules are worth carrying over.

---

## 1. TOC problems

`Phoenix_UI.toc` (baseline):

| Line | Problem | Fix |
|---|---|---|
| `## Interface: 100205, 30401, 11501` | Dragonflight 10.2.5 + Wrath + Classic. Midnight rejects any addon whose interface < 120000 (no "load out of date" override any more). | `## Interface: 120105` (retail only) |
| `## Version: 11.0.58` | Hard-coded | `## Version: @project-version@` or semantic `2.0.0` |
| `## Author: Vajalol` | Credits (`Data/_Users.lua`) name *VortexQ8* — inconsistent | see Open Questions |
| `## AddonCompartmentFunc: Phoenix_Options` | Global function that calls removed `InterfaceOptionsFrame_OpenToCategory` → error on click | `## AddonCompartmentFunc` pointing at a namespaced function, or `AddonCompartmentFrame:RegisterAddon{}` from Lua |
| missing | `## Category`, `## IconTexture`, `## Title-*` localisations, `## Notes`, `## X-License` | add |
| `Libs/Load.xml` → … → `Modules/Load.xml` | `Modules/Load.xml` contains bare `##` text lines (invalid XML text nodes); 52 include paths differ in case from the file on disk (`_Actionbar.lua` vs `_actionbar.lua`, `CheckBox` vs `Checkbox`, `_CvarsBrowser` …) — only works on case-insensitive file systems | one generated, case-exact load order |
| SavedVariables `Phoenix_UIDB`, PerCharacter `Phoenix_UIPerCharDB` | fine, but the code also *reads* `Phoenix_UIDB` directly in 6 places and keeps mock fallback DBs | single DB owner (see ARCHITECTURE §5) |

Nested third-party TOCs (`PremadeGroupsFilter_Cata.toc`, `buffoverlay/Libs/*/…toc`, `MoveAny`) are ignored by the client
but shipped — delete.

---

## 2. Module / feature inventory with verdicts

Verdict legend: **KEEP** (port mostly as is onto the new core), **REWRITE** (feature stays, code is new),
**MERGE** (feature folds into another module), **REMOVE** (feature dropped or replaced by Blizzard-native UI).

Sizes = loaded Lua/XML lines (dead lines in parentheses).

### 2.1 Core & infrastructure

| Path | Size | What it does | Problems | Verdict |
|---|---:|---|---|---|
| `Core/Init.lua` | 3 206 | Creates global AceAddon `Phoenix_UI` (AceEvent/Comm/Serializer/Console/Hook/Timer), ~1 000-line defaults table, AceDB + "mock" DBs, ~10 save/repair/backup functions, module bootstrapping with "critical module recovery", Skin/Color helpers, macro creation, force-disables LortiUI/UberUI/SUI | `EmergencyBackup` defined twice (2743, 3114); `Skin`/`Color` defined twice (1089/1594, 1147/1616) and again in `Core/Theme.lua` & `Skins/_SkinFix.lua`; calls undefined `FlushSavedVariables`; `_G.Phoenix_Options` uses removed `InterfaceOptionsFrame_OpenToCategory`; disables other addons (`DisableAddOn`) — hostile and needs C_AddOns | **REWRITE** (new core) |
| `Core/VersionDetect.lua`, `Core/Utilities.lua` | 404 | Classic/retail branching, misc helpers | Classic constants (`WOW_PROJECT_*_CLASSIC`) no longer relevant | **REMOVE** (retail-only) / helpers → core util |
| `Core/Core.lua`, `Core/Defaults.lua`, `Core/Theme.lua` | (1 291) | Earlier core, defaults, theme | Never loaded; duplicates live code | **REMOVE** (Theme ideas → new theme) |
| `Config/_Gui.lua` + `Config/Layouts/*` + `Config/Components/*` | 12 692 (1 193) | ~26 option pages, install wizard, CVar browser, NPC colour editor, profile import | Built on custom `Libs/Phoenix_Config` (8.8 k lines); 174 calls to undefined `FlushSavedVariables`/`FlushSettingsDB`; `C_Console` (does not exist); duplicate `OpenConfig` (Init + _Gui); every module also has its *own* options (MSBT, PGF, BuffOverlay, MoveAny, CooldownTracker) | **REWRITE** (one standalone config window, §ARCH 9) |
| `Libs/Phoenix_Config` | ~8 800 | In-house widget library | Uses removed `GetSpellInfo`/`GetItemInfo`; dead examples/widgets | **REWRITE** as `UI/Widgets` on the theme |
| `Data/*` | 99 (8) | Colours, fonts (LSM), party profile, textures, 5 themes, credits | `_Profiles.lua` dead | **MERGE** → `Theme` + `Media` registry; credits → About page |
| `Media/*` | 124 + assets | LSM registration, fonts, textures | 77 font files incl. 54 Roboto weights and a 13 MB `AvantGarde.TTF`; many unused | **KEEP (curated)** — ship ~12 fonts (§ARCH 11.2) |

### 2.2 Feature modules

| Module | Size | Features | Midnight / code problems | Verdict |
|---|---:|---|---|---|
| **ActionBars** | 908 | Hotkey/macro text, range colouring, press flash, mouseover fade, bar/micro/bag toggles | Mutates `StanceBar`, `OverrideActionBar`; `ActionButton_ShowGrid/HideGrid` removed; range via `IsSpellInRange` global (removed); Edit Mode owns layout now | **REWRITE** — cosmetic layer over Blizzard bars (hooks on `ActionBarActionButtonMixin`), visibility via Edit Mode + secure state drivers only |
| **Bags** | (17) | empty stub | not loaded | **REMOVE** |
| **Buffs** | 454 | Player buff/debuff size, padding, count | Writes `DebuffFrame`; `.bk` stray file; overlaps Edit Mode buff frame settings + BuffOverlay + MoveAny buff bar | **MERGE** → new `Auras` module |
| **BuffOverlay** (`buffoverlay`) | 8 304 + 15 981 lib | Third-party addon: priority buff icons on raid frames | Ships a *second complete Ace3* + LibDBIcon/LibDialog/LibCustomGlow; reads aura fields (secret in combat/instances) and compares them; missing `CompactAuraTemplate`; own AceConfig options | **REMOVE** embedded copy → **MERGE** feature into `Auras`/`GroupFrames` using `CustomAuraContainer`/`C_UnitAuras.GetUnitAuras` + secret-safe display |
| **CastBars** | 400 | Player/target/focus bar style, timer, icon, latency, target name | Writes `PlayerCastingBarFrame` fields; `CastingBarFrame` (removed) | **REWRITE** — skin `CastingBarMixin`, timer via `UnitCastingDuration` + `SetTimerDuration`; latency player-only |
| **Chat** | 3 722 (52) | Style, URL copy, class colours, copy window, emoji, class/role icons, history+search, categorisation/collapse, social/friend list, "performance" | 12× `ChatFrame_AddMessageEventFilter`, 6× `ChatEdit_*`, 20× `NUM_CHAT_WINDOWS` (all removed); duplicate `OnInitialize`/`OnEnable` in `Chat.lua`; `ProcessChatMessage` in two files; message text is **secret during encounter/M+/PvP lockdown** → string ops on it error; `collectgarbage("collect")` in `_Performance.lua:429`; 3 stray `.bak/.new` | **REWRITE** — secret-aware filters (`issecretvalue` early-out), `ChatFrameUtil.*`, drop "performance"/compression hacks |
| **CooldownTracker** | 8 402 (2 189) | CooldownText (OmniCC-like), SpellTracker (TrufiGCD-like), PartyCD (OmniCD-like), RaidTimeline (dead), Styling | Two cores (`Core.lua` dead + `_Core.lua`), two RaidTimelines; CLEU in PartyCD & SpellTracker; addon comms + `SendChatMessage` in PartyCD; cooldown values are **secret** in combat/M+/PvP/encounters; `GetSpellInfo` ×7 | CooldownText → **REWRITE** (style Blizzard countdown numbers / Duration objects); SpellTracker → **REWRITE** player-only on `UNIT_SPELLCAST_SUCCEEDED` (secrecy-checked); PartyCD & RaidTimeline → **REMOVE** (cannot survive) |
| **Detail-Skin** | 1 291 | Skins the third-party *Details!* meter, imports a profile | `download_textures.ps1` stray; depends on Details internals | **REWRITE** as skin for Blizzard's built-in damage meter (`Blizzard_DamageMeter`); optional Details profile is an open question |
| **General** | 3 961 (50) | Auto repair/sell/delete/stack-buy/decline duel/release/accept res/invite, skip cinematics, AFK cam, item-level (character/inspect/bags), FPS/MS/speed stats, fonts, talking head, error filter, Edit Mode helpers, slash commands, "ModuleIntegration" | `GetItemInfo`, `GetMerchantItemInfo`, `GetDetailedItemLevelInfo`, `C_Item.GetInventoryItemDurability` (does not exist), `C_DeathInfo.GetCombatResurrectionCharges` (does not exist); `EnumerateFrames` in AFK cam; 3 dead files | Split: `Automation` **REWRITE**, `AFK` **KEEP→port**, `ItemLevel` **MERGE** (with Tooltip/Bag ilvl), `DataTexts` **REWRITE** (merges MoveAny FPS), Fonts → **MERGE** Theme, Editmode/Commands → **MERGE** Core, `ModuleIntegration` **REMOVE** |
| **Maps** | 1 547 | Minimap shape/size/opacity, coords, clock, date, garrison/expansion button, tracking, button collection; world-map coords | 1 158-line `_Minimap.lua` with duplicate `StyleMinimap`/`ProcessMinimapButton`; ~15 removed frames (`MiniMapTracking`, `MinimapBorderTop`, `GarrisonLandingPageMinimapButton`…); `GetTrackingTexture` removed | **REWRITE** (`Minimap` module; `C_Minimap`, `ExpansionLandingPageMinimapButton`, addon-compartment aware) |
| **MSBT / MSBTOptions / MikScrollingBattleText** | 555 + 15 970 + 11 806 | Full copy of MikScrollingBattleText + its options UI | Entirely **COMBAT_LOG_EVENT_UNFILTERED** driven (`MSBTParser.lua:851/949`, `MSBTTriggers.lua` ×6, `MSBTCooldowns.lua` ×2) — registering it errors in 12.x; bundles LibStub/CallbackHandler-7/LSM copies; 3 option frameworks of its own | **REMOVE** → replace with small `CombatText` module that themes/configures Blizzard floating combat text (`floatingCombatText*_v2` CVars, `C_CombatText`) |
| **Misc** | 447 | Dampening display, hide bits, interrupt announce, loss-of-control, safe queue, surrender, tab-binder | `_Interrupt.lua` = CLEU + `SendChatMessage` (both blocked/forbidden); globals `surrender` etc. | Interrupt → **REMOVE**; rest → **MERGE** into `PvP` module (Safe Queue, Tab binder out of combat, surrender, dampening) & `Automation` |
| **MoveAny** | 12 583 + 6 422 lib | Third-party addon: move/scale/hide ~all Blizzard frames, profile sharing | 133 `hooksecurefunc`, writes `BagsBar`, `DebuffFrame`, `StanceBar`, `ObjectiveTrackerFrame`, `C_Timer`, `C_Timer.After`, `GetClassColor`, **`string.startswith`** (now a native 12.1.5 function — `libs/db.lua:671` overwrites it); AceComm profile sharing (blocked in instances); `Bindings.xml` dead; `MainMenuMicroButton` template missing | **REMOVE** — layout belongs to Edit Mode; our own frames register with **LibEditMode**; a small out-of-combat "window mover" for non-Edit-Mode panels |
| **Mythic+** | 4 842 | Timer (+2/+3 chest), objectives %, death counter & penalty, prideful/shrouded, keystone info, affix text, auto-gossip | `C_Scenario.GetCriteriaInfo/GetNumCriteria/GetNumStages`, `C_ChallengeMode.GetCompletionTime/IsCompletionTimerActive` — none exist; `DeathTracker.lua:234` CLEU + `SendChatMessage`; npcID parsing from GUIDs (secret in instances); seasonal affixes obsolete | Timer/Objectives/Keystone → **REWRITE** on `C_ScenarioInfo` + `C_ChallengeMode` (`GetDeathCount`, `GetChallengeCompletionInfo`); DeathTracker who-died → **REMOVE** (count kept); AutoGossip → **KEEP→port** (verify outside lockdown) |
| **NamePlates** | 627 | Style/texture/size, arena numbers, totem icons, health text, server name, NPC colours by npcID, focus highlight, cast time | NPC colouring parses `UnitGUID` (`_Core.lua:161`) — GUID/identity secret in instances (Blizzard explicitly targets this); `_TotemIcons.lua:10/182` CLEU; `UnitName("player") ~= UnitName(unit)` (secret comparison); health text arithmetic on `UnitHealth/UnitHealthMax` (secret) | **REWRITE** cosmetics (texture, font, health text via `UnitHealthPercent` + `AbbreviateNumbers`, cast bar skin); NPC colours & totem icons → **REMOVE**; arena numbers → verify (12.1.5 `UnitFrameUtil` arena spec) |
| **PremadeGroupsFilter** | 8 017 (632) | Third-party addon (GPL-2, B. Saumweber): advanced LFG filter expressions | Writes `LFGListFrame.SearchPanel.results`, `LFGListApplicationDialog_Show`, `LFGList_ReportAdvertisement` (taint of the LFG UI = "action blocked" on sign-up); Cata files dead | **REMOVE** from the bundle (actively maintained standalone; duplicating it is the opposite of "zero duplication") — see Open Questions |
| **RaidFrames** | 477 (152) | Size, layout, textures, always-on-top | `CompactRaidFrameManager_SetSetting`, `CompactRaidFrameContainer_SetGroupMode` removed; Edit Mode owns size/layout | **REWRITE** as `GroupFrames` skin (textures/fonts/colours, secret-safe health via StatusBar) |
| **Skins** | 1 789 (2 275) | Darkens/re-colours ~55 Blizzard windows | 1 011 references to removed frame names (mostly `Skins/Blizzard/*`, dead `old.lua` 1 995 lines, MoveAny settings); `_arena`, `_dungeon` dead; addon skins for Bartender/ClassicUI dead | **REWRITE** — one theme-driven skin engine that targets mixins/parentKeys, lazy per Blizzard addon (`EventUtil.ContinueOnAddOnLoaded`) |
| **SpellNotifications** | 345 | Big "Interrupted!/Dispelled!" text | CLEU (`SpellNotifications.lua:33/45`) | **REMOVE** (cannot survive) |
| **Tooltip** | 1 284 | Style, anchor, health on top, ToT, role, targeted-by, item level, aura source | `C_PlayerInfo.GetUnitByGUID`, `C_PlayerInfo.GetPlayerItemLevel`, `C_PaperDollInfo.GetUnitItemLevel/GetAverageItemLevel` — none exist; `UnitName/UnitIsUnit/UnitGUID` comparisons on secret values; writes `GameTooltip` fields (×7), `UnitFrame_UpdateTooltip`; duplicate `GetItemLevel` | **REWRITE** on `TooltipDataProcessor.AddTooltipPostCall`; secret-aware |
| **idTip** | 763 | Spell/item/NPC/quest IDs in tooltips | Overlaps Tooltip; `C_TradeSkillUI.GetRecipeReagentItemLink`, `C_PetBattles.GetPetInfoBySpeciesID` don't exist; NPC IDs secret in instances | **MERGE** → Tooltip "IDs" section |
| **UIscaling** | (353) | Pixel-perfect scale | not loaded; also `Config/Layouts/_UIScaling.lua` calls undefined `module.applyScale` | **MERGE** → Core (`UIParent` scale helper, out of combat) |
| **UnitFrames** | 680 | Class-colour health, class portraits, combat icon, hide bits, boss frame colours, player/target text | Global `class` leak (`_Color.lua:14`); 40+ removed frame names (`TargetFrameTextureFrame`, `PlayerFrameTexture` …); `PetHitIndicator.SetText` overwrite | **REWRITE** as skin on `PlayerFrame`/`TargetFrame` mixins + `UnitFrameUtil` |
| **WeakAurasIntegration** | (471) | WeakAuras theming | Not loaded; WeakAuras does not support Midnight | **REMOVE** |

### 2.3 Feature-level verdict summary

* **KEEP / port:** AFK cam, auto-gossip, talking-head control, error filter, safe queue, tab-binder, surrender, keystone info, world-map coordinates, credits/About, media assets (curated).
* **REWRITE (new code, same feature):** core, config GUI, theme & skins, action-bar cosmetics, unit frames, group frames, cast bars, nameplate cosmetics, tooltip (+IDs, +ilvl), chat, minimap, M+ timer/objectives, automation, data texts, cooldown text, player spell history, damage-meter skin, combat-text configuration.
* **MERGE:** Buffs + BuffOverlay → `Auras`; idTip → `Tooltip`; UIscaling + General/Editmode + Commands + Fonts → `Core`/`Theme`; Misc PvP bits → `PvP`; three item-level implementations → `ItemLevel`.
* **REMOVE:** MoveAny, MSBT (+Options), PremadeGroupsFilter, WeakAurasIntegration, Bags stub, PartyCD, RaidTimeline (×2), SpellNotifications, interrupt announce, M+ death *names*, NPC-ID nameplate colours, totem icons, "ModuleIntegration", chat "performance" hacks, all dead files, all duplicate libraries.

---

## 3. Libraries

| Library | Local | Current upstream | Needed after rework? |
|---|---|---|---|
| LibStub | 2 (+4 nested copies) | 2 | **Yes** (one copy) |
| CallbackHandler-1.0 | 8 (MSBT bundles **7**) | 8 | Yes (LSM/LibEditMode dependency) |
| AceAddon-3.0 | 13 | 13 | **No** — own module system |
| AceEvent-3.0 | 4 | 4 | No — own event bus |
| AceDB-3.0 | **30** | 39 | **Optional** — own DB layer with profiles (§ARCH 5); if kept, update to 39 |
| AceDBOptions-3.0 | **15** | 17 | No |
| AceConfig/ConfigDialog/Registry | **86 / 21** (BuffOverlay copy 87) | 93 / 22 | No — own GUI |
| AceGUI-3.0 | 41 (+ full 2nd copy in buffoverlay) | 41 | No |
| AceComm/AceSerializer | 14 / 5 | 14 / 5 | No — `C_EncodingUtil` (CBOR/JSON/Base64/Compress) for profile strings; addon comms are blocked in instanced content |
| AceConsole/AceHook/AceTimer | 7 / 9 / 17 | current | No — `RegisterNewSlashCommand`, `hooksecurefunc`, `C_Timer` |
| AceBucket/AceLocale/AceTab, `Libs/Ace3.lua` | — | — | dead files; AceTab overwrites `ChatEdit_CustomTabPressed` | **remove** |
| LibSharedMedia-3.0 | **8020003** (MSBT bundles another) | 12000005 | **Yes** (update) — interop with other addons' media |
| LibEditMode | **8** | 18 (tag 9) | **Yes** (update) — our frames in Edit Mode |
| LibEditModeOverride | 10 | — | No — we do not rewrite Blizzard layouts programmatically |
| LibDeflate | 3 | 3 | No — `C_EncodingUtil.CompressString` |
| LibDBIcon / LibDataBroker | 55 | current | Optional (minimap button); prefer Addon Compartment |
| LibDropDown | 8 | — | No — Blizzard `MenuUtil` / `DropdownButton` |
| LibCustomGlow / LibDialog (buffoverlay) | 20 / 8 | — | No — `ActionButtonSpellAlertManager`/own glow; `StaticPopup` |
| LibNPCInfo | — | — | No — NPC identity is secret in instances |

---

## 4. Deprecated / removed API usage

Full per-symbol list with **every file:line** and the replacement is generated into
[`docs/audit/API_FINDINGS.md`](audit/API_FINDINGS.md). Highlights (live files only):

| Removed API (12.x) | Refs | Replacement in 12.1.5 |
|---|---:|---|
| `GetSpellInfo` | 21 | `C_Spell.GetSpellInfo` (table) |
| `NUM_CHAT_WINDOWS` | 20 | `Constants.ChatFrameConstants.MaxChatWindows` |
| `GetItemInfo` | 15 | `C_Item.GetItemInfo` |
| `GetSpecialization` / `GetSpecializationInfo` | 15 / 7 | `C_SpecializationInfo.*` |
| `CombatLogGetCurrentEventInfo` + `COMBAT_LOG_EVENT_UNFILTERED` | 13 + 20 | **none for addons** — feature redesign (§6) |
| `ChatFrame_AddMessageEventFilter` | 12 | `ChatFrameUtil.AddMessageEventFilter` |
| `SendChatMessage` | 8 | `C_ChatInfo.SendChatMessage` (blocked during lockdown) |
| `ChatEdit_*` (6 names) | 14 | `ChatFrameUtil.*` / `ChatFrameEditBoxMixin` |
| `IsAddOnLoaded`/`LoadAddOn`/`GetAddOnMetadata`/`GetAddOnInfo`/`DisableAddOn` | 17 | `C_AddOns.*` |
| `InterfaceOptions_AddCategory` / `…OpenToCategory` / `InterfaceOptionsFrame` | 13 | `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory` / `Settings.OpenToCategory(id)` |
| `UnitAura` / `UnitBuff` / `UnitDebuff` | 12 | `C_UnitAuras.GetAuraDataByIndex` / `GetUnitAuras` |
| `GetMouseFocus` | 5 | `GetMouseFoci()` |
| `GetItemQualityColor`, `LE_ITEM_QUALITY_*`, `LE_ITEM_CLASS_*` | 12 | `C_Item.GetItemQualityColor`, `Enum.ItemQuality`, `Enum.ItemClass` |
| `GetSpellCooldown/Texture/Charges/Link/Description/CastCount`, `IsSpellInRange` | 15 | `C_Spell.*` |
| `EasyMenu` | 1 | `MenuUtil.CreateContextMenu` |
| `GuildRoster`, `RegisterAddonMessagePrefix`, `GetZonePVPInfo`, `GetMerchantItemInfo`, `GetDetailedItemLevelInfo` | 7 | `C_GuildInfo.GuildRoster`, `C_ChatInfo.RegisterAddonMessagePrefix`, `C_PvP.GetZonePVPInfo`, `C_MerchantFrame.GetItemInfo`, `C_Item.GetDetailedItemLevelInfo` |
| `C_Console.*` | 2 | never existed → `ConsoleGetAllCommands()` |
| `getglobal`, `MouseIsOver`, `SetDesaturation`, `AnimateTexCoords` | 19 | `_G[]`, `region:IsMouseOver()`, `tex:SetDesaturated()`, FlipBook |

Non-existent `C_` fields (would error on call): `C_Scenario.GetCriteriaInfo/GetNumStages/GetNumCriteria`,
`C_PlayerInfo.GetUnitByGUID/GetPlayerItemLevel`, `C_PaperDollInfo.GetUnitItemLevel/GetAverageItemLevel`,
`C_Item.GetInventoryItemDurability/GetInventoryItemQuality`, `C_DeathInfo.GetCombatResurrectionCharges`,
`C_GossipInfo.GetNumOptions`, `C_TradeSkillUI.GetRecipeReagentItemLink`, `C_ChallengeMode.GetCompletionTime/IsCompletionTimerActive`,
`C_PetBattles.GetPetInfoBySpeciesID` — replacements in the appendix. Several look AI-invented.

Removed/renamed **CVars** set by the addon: `floatingCombatTextCombatHealing`/`…CombatDamage` (now `*_v2`),
`consolidateBuffs`, `compactPartyFrameHeight/Width`, `multiBarRightVerticalLayout`, `alwaysShowActionBars`,
`nameplateMotion` (12.1.5 restored `nameplateMotionSpeed`), `NamePlateVerticalScale/HorizontalScale`,
`nameplateShowFriendlyTotems` (→ `nameplateShowFriendlyPlayerTotems`), `useCompactPartyFrames`.

Missing **templates**: `CompactAuraTemplate` (`buffoverlay/BuffOverlay.lua:1638`), `MainMenuMicroButton` (`MoveAny/ele/micromenu.lua:111`).
Removed **widget methods**: `SetMinResize/SetMaxResize` (→ `SetResizeBounds`, guarded only in AceGUI) and ~60 calls to methods defined nowhere.

12.1.5-specific collisions: 12.1.5 adds native `string.startswith`, `table.contains`, `math.clamp` … — `MoveAny/libs/db.lua:671`
**overwrites `string.startswith` globally** (affects every addon and Blizzard code).

---

## 5. Duplicates

**Duplicate definitions (same name, same addon):**

* `Core/Init.lua`: `EmergencyBackup` (2743, 3114), `Skin` (1147, 1616), `Color` (1089, 1594); `SaveDB` also in dead `Core/Core.lua`; `OpenConfig` in `Init.lua` and `Config/_Gui.lua`.
* `Skin`/`Color` again in `Core/Theme.lua` (dead) and `Modules/Skins/_SkinFix.lua`.
* `Modules/Chat/Chat.lua`: `OnInitialize` and `OnEnable` each defined twice; `ProcessChatMessage` in `Chat.lua` and `_Core.lua`.
* `Modules/CooldownTracker`: two cores (`Core.lua` dead, `_Core.lua`), two `RaidTimeline` (root + `modules/`), two configs (`_Config.lua`, `config.lua`), `OpenConfigPanel` twice in `_Core.lua`.
* `Modules/Maps/_Minimap.lua`: `StyleMinimap`, `ProcessMinimapButton` twice.
* `Modules/General/_Itemlevel.lua`: `GetItemEnchantAsText`, `GetSocketTextures` twice; `Modules/Tooltip/_Core.lua`: `GetItemLevel` twice.
* `Modules/MoveAny`: `Update*ScaleAlpha` ×3; D4Lib re-implements core helpers (`GetWoWBuild`, `MClamp`, `InitSlash`, grid).

**Duplicate features:**

| Feature | Implementations |
|---|---|
| Aura display | `Buffs`, `buffoverlay`, MoveAny buff/debuff bars, Edit Mode buff frame |
| Frame movement | MoveAny, LibEditMode, LibEditModeOverride, `General/_Editmode`, Blizzard Edit Mode |
| Scrolling combat text | MSBT, Blizzard FCT, `SpellNotifications` |
| Options UIs | Phoenix_Config, AceConfig/AceGUI (×2 copies), MSBTOptions, PGF, BuffOverlay, MoveAny, CooldownTracker `_Config` + `config` |
| Dropdowns | LibDropDown, UIDropDownMenu, MenuUtil |
| Item level | `General/_Itemlevel`, `General/_BagIlvl`, `Tooltip/_Core` |
| IDs in tooltip | `idTip`, `Tooltip` |
| FPS/latency | `General/_Stats`, MoveAny `fps.lua` |
| Minimap buttons | `Maps/_Minimap`, MoveAny minimap, LibDBIcon (×2) |
| UI scale | `UIscaling` (dead), `Config/Layouts/_UIScaling` |
| Skin helpers | `Init.lua`, `Theme.lua`, `_SkinFix.lua`, `Skins/Blizzard/old.lua` |
| Libraries | Ace3 ×2, LibStub ×6, CallbackHandler ×2 versions, LSM ×2, LibDBIcon ×2 |

---

## 6. Features that cannot survive Midnight

Midnight's "addon disarmament" (secret values, forbidden CLEU, chat/comm lockdown) makes these impossible *as designed*:

| Feature | Why | Replacement |
|---|---|---|
| MSBT (whole addon) | Requires `COMBAT_LOG_EVENT_UNFILTERED`; registering it errors; combat-log chat lines are KStrings | Themed Blizzard FCT v2 (`CombatText` module) |
| PartyCD (OmniCD-like) | CLEU + addon comms (blocked in M+/raid/PvP) + others' cooldowns are secret | Blizzard Cooldown Manager (self) — none for party |
| RaidTimeline | CLEU + encounter secrets | Blizzard `C_EncounterTimeline` UI (Boss Timeline) |
| SpellNotifications | CLEU | — |
| Interrupt announce (`Misc/_Interrupt`) | CLEU + `SendChatMessage` blocked during lockdown | — |
| M+ death tracker (who died / by what) | CLEU; names secret in instances | death *count* via `C_ChallengeMode.GetDeathCount()` |
| Nameplate NPC colours by npcID | GUID/creature ID secret in instances; Blizzard explicitly designed against "mechanic awareness" plates | — (threat/reaction colours via Blizzard only) |
| Nameplate totem icons | CLEU | Blizzard totem nameplates (`nameplateShowFriendlyPlayerTotems`) |
| BuffOverlay priority logic | Aura spell IDs/durations secret in combat/instances (except whitelist) → cannot compare/sort | `CustomAuraContainer` / `GetUnitAuras(sortRule)` display-only |
| MoveAny profile sharing via comms | Addon comms blocked during lockdown | Export/Import strings (`C_EncodingUtil`) |
| Chat processing during lockdown | Messages arrive as secret strings | Pass-through untouched while `issecretvalue(msg)` |
| "Targeted by" tooltip lines, `UnitIsUnit` comparisons | `UnitIsUnit` restricted (non-secret only for target/focus/mouseover/soft tokens) | Only outside restrictions, guarded by `C_Secrets.ShouldUnitComparisonBeSecret` |
| WeakAuras / Details integration | WeakAuras abandoned Midnight; Details now rides `C_DamageMeter` | Skin Blizzard damage meter |

---

## 7. Global leaks

124 accidental globals (luacheck W111) excluding tests, e.g. `btn`, `tab`, `val`, `msg`, `data`, `grid`, `once`,
`backdrop`, `surrender`, `animationGroup`, `fontPath`, `barTexturePath`, `titleText`, `currentUpdateRate`, `class`
(`UnitFrames/_Color.lua:14`), dozens of `MA*` (MoveAny) and `SLASH_*` names, and many `Phoenix_UI*` helpers.
Undefined-local bugs (read as globals → nil): `L` (26 refs), `self`, `tooltip`, `kinds`, `flags`, `spellID`,
`instanceType`, `t1`–`t3`, `cmID`, `EL`, `CH`, `mouseEle`, `showLeft`. Full list in the appendix.

## 8. Taint risks

* **126 writes to Blizzard globals/fields** (appendix §"Writes to Blizzard"): `ColorPickerFrame` fields (×9, use `ColorPickerFrame:SetupColorPickerAndShow`), `GameTooltip` fields (×7), `StanceBar` (×6), `PowerBarColor.MANA` (×6), `PlayerCastingBarFrame` (×5), `StaticPopupDialogs` (fine if namespaced keys), `LFGListFrame.SearchPanel.results/totalResults`, `LFGListApplicationDialog_Show`, `QuickJoinToastButton.Show`, `PetHitIndicator.SetText`, `OverrideActionBar`, `SetItemRef`, `UnitFrame_UpdateTooltip`, `MovieFrame_PlayMovie`, `MerchantItemButton_OnModifiedClick`, `CloseSpecialWindows`, `ChatEdit_CustomTabPressed`, `CHAT_FRAME_*` fade constants, `C_Timer`/`C_Timer.After` (D4Lib), `GetClassColor`, `string.startswith`.
* Replacing functions/fields on secure frames taints every Blizzard code path that reads them (classic "Action blocked" / "Interface action failed because of an AddOn"). In 12.x tainted code also turns secret values into errors.
* `SetParent`/`SetPoint`/`Hide` on protected frames (action bars, unit frames, raid frames) from non-secure code paths, sometimes without `InCombatLockdown()` checks (121 checks exist but are inconsistent).
* `EnumerateFrames` iteration (AFK cam) touches forbidden frames.
* Disabling other addons at load (`LortiUI`, `UberUI`, `SUI`).

## 9. Performance issues

* 35 `OnUpdate` scripts in 22 files (+58 in libs/third-party), 17 repeating tickers; several run always (stats, mouseover fade, cooldown text).
* Forced `collectgarbage("collect")` (`Chat/_Performance.lua:429`, `MSBTProfiles.lua:3884`) → frame hitches.
* Chat history "compression" and virtual scrolling re-implemented in Lua on every message.
* ~2× library load (second Ace3), 24 MB of fonts loaded via LSM (all registered → all hit memory when listed).
* `UnitGUID`/`UnitName` string parsing in nameplate update paths.

## 10. Dead files (not reachable from the TOC)

70 Lua/XML files (≈11.6 k lines). Notable: `Core/Core.lua`, `Core/Defaults.lua`, `Core/Theme.lua`,
`Config/Layouts/General.lua`, `_PremadeGroupsFilter.lua`, `_RaidFrames.lua`, `Data/_Profiles.lua`, `Libs/Ace3.lua`,
`AceBucket`, `AceLocale`, `AceTab`, LibStub tests, LibDeflate examples, `Phoenix_Config/examples`, `widgets/Group.lua`,
`Modules/Bags`, `Chat/EmojiDebug.lua`, `_RoleIcons.lua`, CooldownTracker `Core.lua`/`FramePool.lua`/`RaidTimeline.lua`/`config.lua`/`modules/RaidTimeline.lua`,
`General/_Core.lua`, `_Errorhide.lua`, `_Resurrection.lua`, `MoveAny/Bindings.xml`, PGF `*_Cata`, `RaidFrames/_Show.lua`,
`Skins/Addons/*`, `Skins/Blizzard/_arena.lua`, `_dungeon.lua`, `old.lua` (1 995), `Skins/_SkinFix.lua`, `UIscaling/UIscale.lua`,
`WeakAurasIntegration/*`, `buffoverlay/Display.lua`, nested buffoverlay lib copies.
Stray non-code files: `Buffs/_Buffs.lua.bk`, `Chat/_Core.lua.bak`, `Chat/_Social.lua.new`, `Chat/_Url.lua.bak`,
`Detail-Skin/download_textures.ps1`, `.vscode/settings.json`, nested READMEs/CHANGELOGs/TOCs.

## 11. Biggest risks for the rework

1. **Secret values everywhere in combat UI.** Any arithmetic/comparison/boolean test on health, power (non-player), auras, cooldowns, casts, names, GUIDs in restricted states throws. Every module must be written display-only through `StatusBar`, `Duration`, `Curve`, `*FromBoolean` APIs. Mitigation: `.cursor/rules/midnight-secrets.mdc`, test CVars (`secret*RestrictionsForced`) in the test checklist.
2. **Taint of Edit Mode / action bars / unit frames** by cosmetic hooks. Mitigation: hooks only via `hooksecurefunc`, never write fields on Blizzard tables, defer all protected work to `PLAYER_REGEN_ENABLED`.
3. **Scope.** ~160 k lines collapse to an estimated 25–35 k; a phased build order (ARCHITECTURE §13) keeps it shippable.
4. **SavedVariables migration** from a 1 000-key ad-hoc schema (ARCHITECTURE §5.4).
5. **API drift** (12.1.7 on PTR). Mitigation: the generated luacheck std is regenerated per patch (`tools/audit`).

## 12. Reproducing this audit

```
python3 tools/audit/mainline_files.py   # resolve mainline FrameXML files from TOCs
python3 tools/audit/gen_globals.py      # build .luacheck/wow_std_12.1.5.lua + json
luacheck --config tools/audit/audit.luacheckrc --formatter plain . > luacheck_all.txt
python3 tools/audit/summarize.py && python3 tools/audit/gen_api_appendix.py
```
(Requires `wow-ui-source` + BlizzardInterfaceResources checkouts; paths at the top of each script.)
