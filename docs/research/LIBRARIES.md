# Bundled libraries audit (t220/t221, 1 Nov 2026)

Read-only scan of: (1) `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns`, (2) `..\_forever_\Interface\AddOns`, (3) `I:\` (EllesmereUI first, then the other addons). Phoenix_UI folders excluded. Nothing was edited or deleted.

**Licence column = what the local files say** (LICENSE file or source header). "not found locally" means no licence text was in that copy; the "Upstream" column is the commonly published licence and must be confirmed from the official repo before bundling. Verdict rule: permissive / public domain / LGPL with notice = YES; all-rights-reserved = NO; no evidence = UNKNOWN.

> Note: several local headers read `licens by VortexQ8e` / `Copyright (c) 2020 VortexQ8` (e.g. EllesmereUI LibSharedMedia, MSBT LibSerialize, WindTools LibRangeCheck). These look like a find-and-replace on the local copies, not the original authors. Phoenix must bundle **pristine upstream copies** with the original notices.

## Summary by library

| Library | Copies found | Versions seen | Upstream licence | Verdict | Phoenix already has? |
|---|---|---|---|---|---|
| LibStub | 23 | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | Public Domain | YES (Public Domain, header) | yes (Libs/LibStub) |
| CallbackHandler-1.0 | 18 | local MAJOR, MINOR = "CallbackHandler-1.0", 6; local MAJOR, MINOR = "CallbackHandler-1.0", 7 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | yes |
| LibDataBroker-1.1 | 13 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | MIT/public (upstream, verify) | UNKNOWN - verify upstream before bundling | no (data texts are own) |
| LibDBIcon-1.0 | 11 | local DBICON10_MINOR = 55; local DBICON10_MINOR = 56 | All Rights Reserved upstream (Funkeh) - verify | UNKNOWN - verify upstream before bundling | own UI/MinimapButton.lua + minimap button bin |
| LibSharedMedia-3.0 | 10 | Revision: $Revision$; Revision: $Revision: 181 $ | LGPL-2.1 | YES (keep notice) | yes |
| AceDB-3.0 | 8 | - | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | own Core/Profiles.lua + PhoenixUIDB |
| AceConsole-3.0 | 6 | local MAJOR,MINOR = "AceConsole-3.0", 7 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceDBOptions-3.0 | 6 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 15; local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 17 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceGUI-3.0 | 6 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | own GUI (Phoenix_UI_Options) |
| LibDeflate | 6 | ## Version: afc3b78; local _MINOR = 3 | zlib | YES (keep notice) | own encoding in Core/Profiles.lua |
| LibKeystone | 6 | local LKS = LibStub:NewLibrary("LibKeystone", 10); local LKS = LibStub:NewLibrary("LibKeystone", 11) | unknown | UNKNOWN - verify upstream before bundling | - |
| AceAddon-3.0 | 4 | local MAJOR, MINOR = "AceAddon-3.0", 13 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceComm-3.0 | 4 | local MAJOR, MINOR = "AceComm-3.0", 14 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceConfig-3.0 | 4 | local MAJOR, MINOR = "AceConfig-3.0", 3 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | own GUI |
| AceEvent-3.0 | 4 | local MAJOR, MINOR = "AceEvent-3.0", 4 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| LibSpecialization | 4 | local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 28); local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 29) | unknown | UNKNOWN - verify upstream before bundling | - |
| AceGUI-3.0-SharedMediaWidgets | 3 | local AGSMW = LibStub:NewLibrary("AceGUISharedMediaWidgets-1.0", DataV | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceSerializer-3.0 | 3 | local MAJOR,MINOR = "AceSerializer-3.0", 5 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| D4Lib | 3 | - | unknown | UNKNOWN - verify upstream before bundling | - |
| LibSerialize | 3 | - | MIT | UNKNOWN - verify upstream before bundling | own encoding in Core/Profiles.lua |
| AceConfigDialog-3.0 | 2 | local MAJOR, MINOR = "AceConfigDialog-3.0", 93 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | own GUI |
| AceConfigRegistry-3.0 | 2 | local MAJOR, MINOR = "AceConfigRegistry-3.0", 22 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| LibCandyBar-3.0 | 2 | local lib = LibStub:NewLibrary("LibCandyBar-3.0", 110) | unknown (verify) | UNKNOWN - verify upstream before bundling | own Encounters bars |
| LibCBOR | 2 | LibCBOR = LibStub:NewLibrary("LibCBOR-1.0", 4) | MIT | UNKNOWN - verify upstream before bundling | - |
| LibCustomGlow-1.0 | 2 | local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSIO | BSD-2 upstream (verify) | UNKNOWN - verify upstream before bundling | own glows |
| LibDDI-1.0 | 2 | - | unknown | UNKNOWN - verify upstream before bundling | - |
| LibDualSpec-1.0 | 2 | local MAJOR, MINOR = "LibDualSpec-1.0", 35 | BSD-style (Adirelle header) | UNKNOWN - verify upstream before bundling | - |
| LibDurability | 2 | local LD = LibStub:NewLibrary("LibDurability", 5) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibItemEnchant | 2 | local MAJOR, MINOR = "LibItemEnchant-WT", 1 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibLatency | 2 | local LL = LibStub:NewLibrary("LibLatency", 5) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibObjectiveProgressWT | 2 | local MAJOR, MINOR = "LibObjectiveProgress-WT", 1 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibOpenRaid | 2 | - | unknown | UNKNOWN - verify upstream before bundling | - |
| LibRangeCheck-3.0 | 2 | - | MIT (header) | YES (keep notice) | - |
| LibRealmInfo | 2 | local MAJOR, MINOR = "LibRealmInfo", 13 | zlib upstream (Phanx, verify) | YES (keep notice) | - |
| LibSink-2.0 | 2 | local SINK20_MINOR = 120001 | unknown | UNKNOWN - verify upstream before bundling | - |
| AceBucket-3.0 | 1 | local MAJOR, MINOR = "AceBucket-3.0", 4 | BSD-3 (Ace3) | YES (keep notice) | - |
| AceHook-3.0 | 1 | local ACEHOOK_MAJOR, ACEHOOK_MINOR = "AceHook-3.0", 9 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceLocale-3.0 | 1 | local MAJOR,MINOR = "AceLocale-3.0", 6 | BSD-3 (Ace3) | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) | - |
| AceTimer-3.0 | 1 | local MAJOR, MINOR = "AceTimer-3.0", 17 | BSD-3 (Ace3) | YES (keep notice) | - |
| ChatThrottleLib | 1 | - | Public Domain upstream (verify) | YES (keep notice) | - |
| HereBeDragons | 1 | local MAJOR, MINOR = "HereBeDragonsQuestie-2.0", 34 | BSD (TOC X-License) | YES (keep notice) | - |
| Krowi_WorldMapButtons | 1 | local lib, oldminor = LibStub:NewLibrary('Krowi_WorldMapButtons-1.4',  | All Rights Reserved | NO | - |
| LibAHTab | 1 | local lib = LibStub:NewLibrary("LibAHTab-1-0", 5) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibAppropriateitems-1.0 | 1 | local lib, oldMinor = LibStub:NewLibrary("LibAppropriateItems-1.0", 1) | unknown | YES (keep notice) | - |
| LibArmorToken-1.0 | 1 | local lib, oldMinor = LibStub:NewLibrary("LibArmorToken-1.0", 2) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibAsync | 1 | local _MINOR = 5 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibBattlePetTooltipLine | 1 | local lib = LibStub:NewLibrary("LibBattlePetTooltipLine-1-0", 1) | MIT | YES (keep notice) | - |
| LibClassTalentsImportExport-1.0 | 1 | local MAJOR, MINOR = "LibClassTalentsImportExport-1.0", 1 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibCombatLogging-1.0 | 1 | local MAJOR, MINOR = "LibCombatLogging-1.0", 1 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibDropDownExtension-1.0 | 1 | local MAJOR, MINOR = "LibDropDownExtension-1.0", 3 | unknown | UNKNOWN - verify upstream before bundling | - |
| LibQTip | 1 | - | BSD-3 upstream (verify) | UNKNOWN - verify upstream before bundling | - |
| LibSFDropDown | 1 | local lib, oldminor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibThingsLoad | 1 | local lib, oldminor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | unknown | UNKNOWN - verify upstream before bundling | - |
| LibUIDropDownMenu | 1 | local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | unknown | UNKNOWN - verify upstream before bundling | - |

## Recommendations (no integration yet; needs a plan)

1. **AceDB-3.0 (+CallbackHandler, LibStub already bundled)** - BSD-3. Candidate fix for audit item 23 (settings/positions reset after /reload) only if the root cause is the DB layer. Phoenix already has its own DB + profiles (Core/Profiles.lua, PhoenixUIDB, per-spec/per-place profiles), so adopting AceDB would *duplicate* it. Recommendation: first fix item 23 in the existing module; adopt AceDB only as a replacement of the storage layer with a migration, never alongside it.
2. **LibSharedMedia-3.0** - LGPL-2.1, already bundled. Keep; register all Phoenix fonts/textures/sounds into it so other addons can use them and Phoenix pickers show other addons' media.
3. **LibDataBroker-1.1** - YES (verify notice). Add so Phoenix data texts can *show* other addons' LDB feeds and publish Phoenix's own. Extends Phoenix_UI_DataTexts; no new module.
4. **LibDBIcon-1.0** - upstream is "All Rights Reserved" by its author with redistribution as an embedded lib customary; licence not found locally -> UNKNOWN. Phoenix already has its own minimap button and a button bin that *reads* LibDBIcon buttons, so no need to bundle it.
5. **LibDeflate (zlib) / LibSerialize (MIT)** - YES. Only worth it if profile export strings must be compatible with other addons (e.g. WeakAuras-style). Otherwise Phoenix's own encoding stays (no duplicate).
6. **LibCustomGlow-1.0** (BSD-2 upstream, verify) - optional; Phoenix has own glows. Skip unless it replaces them.
7. **LibCandyBar-3.0 / LibSink / LibKeystone / LibSpecialization / LibOpenRaid** - licence unknown locally; Phoenix already has its own boss bars, combat text output, M+ and spec data. Do not bundle.
8. **Krowi_WorldMapButtons** - All Rights Reserved (Questie copy) -> NO.
9. **EllesmereUI itself** - only bundles LibStub, CallbackHandler, LibDataBroker, LibSharedMedia, LibDeflate, LibKeystone, LibSpecialization. Its own Lua (UI code) has no open licence found -> copy the *look*, not the code.

## Every copy found (source folder, path, version, local licence evidence, verdict)

| Scanned root | Path | Library | Version line | Local licence evidence | Verdict |
|---|---|---|---|---|---|
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibDeflate | ## Version: afc3b78 | LICENSE.txt:zlib License (C) 2018-2021 Haoqian He | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 11) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 12000005 | License: LGPL v2.1 | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibSpecialization | local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 30) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_WindTools\Libraries` | LibItemEnchant | local MAJOR, MINOR = "LibItemEnchant-WT", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_WindTools\Libraries` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 10) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_WindTools\Libraries` | LibObjectiveProgressWT | local MAJOR, MINOR = "LibObjectiveProgress-WT", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_WindTools\Libraries` | LibOpenRaid | - | LICENSE:                  GNU LESSER GENERAL PUBLIC LICENSE                        Version 2.1, February 1999 | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\EllesmereUI_WindTools\Libraries` | LibRangeCheck-3.0 | - | License: MIT | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Auctionator\Libs` | LibCBOR | LibCBOR = LibStub:NewLibrary("LibCBOR-1.0", 4) | LICENSE:Copyright (c) 2014-2015 Kim Alvefur and 2024 plusmouse Permission is hereby granted, free of charge, t | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Auctionator\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\AutoQueue\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\AutoQueue\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 56 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\AutoQueue\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\AutoQueue\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceAddon-3.0 | local MAJOR, MINOR = "AceAddon-3.0", 13 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceConfig-3.0 | local MAJOR, MINOR = "AceConfig-3.0", 3 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 17 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceEvent-3.0 | local MAJOR, MINOR = "AceEvent-3.0", 4 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceHook-3.0 | local ACEHOOK_MAJOR, ACEHOOK_MINOR = "AceHook-3.0", 9 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceLocale-3.0 | local MAJOR,MINOR = "AceLocale-3.0", 6 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | AceSerializer-3.0 | local MAJOR,MINOR = "AceSerializer-3.0", 5 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | LibAppropriateitems-1.0 | local lib, oldMinor = LibStub:NewLibrary("LibAppropriateItems-1.0", 1) | ## X-License: BSD | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | LibArmorToken-1.0 | local lib, oldMinor = LibStub:NewLibrary("LibArmorToken-1.0", 2) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BetterWardrobe\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibDualSpec-1.0 | local MAJOR, MINOR = "LibDualSpec-1.0", 35 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibDurability | local LD = LibStub:NewLibrary("LibDurability", 5) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 11) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibLatency | local LL = LibStub:NewLibrary("LibLatency", 5) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 12000005 | License: LGPL v2.1 | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibSpecialization | local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 29) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Options\Libs` | AceConfigDialog-3.0 | local MAJOR, MINOR = "AceConfigDialog-3.0", 93 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Options\Libs` | AceConfigRegistry-3.0 | local MAJOR, MINOR = "AceConfigRegistry-3.0", 22 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Options\Libs` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 17 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Options\Libs` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Options\Libs` | LibDDI-1.0 | - | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Plugins\Libs` | LibCandyBar-3.0 | local lib = LibStub:NewLibrary("LibCandyBar-3.0", 110) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Plugins\Libs` | LibCustomGlow-1.0 | local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSIO | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BigWigs_Plugins\Libs` | LibSink-2.0 | local SINK20_MINOR = 120001 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | AceComm-3.0 | local MAJOR, MINOR = "AceComm-3.0", 14 | -- LICENSE: ChatThrottleLib is released into the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | AceSerializer-3.0 | local MAJOR,MINOR = "AceSerializer-3.0", 5 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 12000005 | License: LGPL v2.1 | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\BugSack\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MikScrollingBattleText\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MikScrollingBattleText\Libs` | LibDeflate | - | DEFLATE/zlib format. | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MikScrollingBattleText\Libs` | LibSerialize | - | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MikScrollingBattleText\Libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 8020003 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MikScrollingBattleText\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | not found locally | YES (Public Domain, header) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MountsJournalUI\libs` | LibSFDropDown | local lib, oldminor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | LICENSE:                    GNU GENERAL PUBLIC LICENSE                        Version 3, 29 June 2007 | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MountsJournal\libs` | ChatThrottleLib | - | -- LICENSE: ChatThrottleLib is released into the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MountsJournal\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MountsJournal\libs` | LibThingsLoad | local lib, oldminor = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | LICENSE:                    GNU GENERAL PUBLIC LICENSE                        Version 3, 29 June 2007 | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MoveAny\libs` | D4Lib | - | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | AceComm-3.0 | local MAJOR, MINOR = "AceComm-3.0", 14 | -- LICENSE: ChatThrottleLib is released into the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | LibAsync | local _MINOR = 5 | LICENSE:                    GNU GENERAL PUBLIC LICENSE                        Version 2, June 1991 | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 12000005 | License: LGPL v2.1 | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\MythicDungeonTools\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibClassTalentsImportExport-1.0 | local MAJOR, MINOR = "LibClassTalentsImportExport-1.0", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibCombatLogging-1.0 | local MAJOR, MINOR = "LibCombatLogging-1.0", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 55 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibDropDownExtension-1.0 | local MAJOR, MINOR = "LibDropDownExtension-1.0", 3 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\RaiderIO\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | AceAddon-3.0 | local MAJOR, MINOR = "AceAddon-3.0", 13 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | AceEvent-3.0 | local MAJOR, MINOR = "AceEvent-3.0", 4 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 6 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | LibRealmInfo | local MAJOR, MINOR = "LibRealmInfo", 13 | LICENSE.txt:Copyright (C) 2014-2019 Phanx <addons@phanx.net> This software is provided 'as-is', without any ex | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Simulationcraft\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\SpecBisTooltip\libs` | D4Lib | - | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\Tust_EUI\Libs` | LibSerialize | - | not found locally | UNKNOWN - verify upstream before bundling |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceConfig-3.0 | local MAJOR, MINOR = "AceConfig-3.0", 3 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 15 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | AceGUI-3.0-SharedMediaWidgets | local AGSMW = LibStub:NewLibrary("AceGUISharedMediaWidgets-1.0", DataV | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| D:\ retail/forever AddOns | `D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns\sArena_Reloaded\Ace3` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| I:\ | `I:\EllesmereUI\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\EllesmereUI\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI\Libs` | LibDeflate | local _MINOR = 3 | local _COPYRIGHT = "LibDeflate " .. _VERSION .. | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI\Libs` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 11) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI\Libs` | LibSharedMedia-3.0 | Revision: $Revision: 181 $ | licens by VortexQ8e: LGPL v2.1 | YES (keep notice) |
| I:\ | `I:\EllesmereUI\Libs` | LibSpecialization | local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 28) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| I:\ | `I:\EllesmereUI_WindTools\Libraries` | LibItemEnchant | local MAJOR, MINOR = "LibItemEnchant-WT", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI_WindTools\Libraries` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 10) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI_WindTools\Libraries` | LibObjectiveProgressWT | local MAJOR, MINOR = "LibObjectiveProgress-WT", 1 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI_WindTools\Libraries` | LibOpenRaid | - | local spamLimit = {} | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI_WindTools\Libraries` | LibRangeCheck-3.0 | - | Author(s): mitch0, WoWUIDev Community | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\EllesmereUI_WindTools\Modules\Skins\Libraries` | LibQTip | - | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Auctionator\Libs` | LibCBOR | LibCBOR = LibStub:NewLibrary("LibCBOR-1.0", 4) | LICENSE:Copyright (c) 2014-2015 Kim Alvefur and 2024 plusmouse Permission is hereby granted, free of charge, t | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Auctionator\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| I:\ | `I:\Auctionator\Libs_ModernAH` | LibAHTab | local lib = LibStub:NewLibrary("LibAHTab-1-0", 5) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Auctionator\Libs_ModernAH` | LibBattlePetTooltipLine | local lib = LibStub:NewLibrary("LibBattlePetTooltipLine-1-0", 1) | LICENSE:MIT License Copyright (c) 2024 plusmouse | YES (keep notice) |
| I:\ | `I:\AutoQueue\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\AutoQueue\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 56 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\AutoQueue\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\AutoQueue\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| I:\ | `I:\BigWigs\Libs` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs\Libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibDualSpec-1.0 | local MAJOR, MINOR = "LibDualSpec-1.0", 35 | Copyright (C) 2009-2024 Adirelle | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibDurability | local LD = LibStub:NewLibrary("LibDurability", 5) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibKeystone | local LKS = LibStub:NewLibrary("LibKeystone", 11) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibLatency | local LL = LibStub:NewLibrary("LibLatency", 5) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibSharedMedia-3.0 | Revision: $Revision: 184 $ | License: LGPL v2.1 | YES (keep notice) |
| I:\ | `I:\BigWigs\Libs` | LibSpecialization | local LS, oldminor = LibStub:NewLibrary("LibSpecialization", 29) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| I:\ | `I:\BigWigs_Options\Libs` | AceConfigDialog-3.0 | local MAJOR, MINOR = "AceConfigDialog-3.0", 93 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs_Options\Libs` | AceConfigRegistry-3.0 | local MAJOR, MINOR = "AceConfigRegistry-3.0", 22 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs_Options\Libs` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 17 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs_Options\Libs` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BigWigs_Options\Libs` | LibDDI-1.0 | - | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs_Plugins\Libs` | LibCandyBar-3.0 | local lib = LibStub:NewLibrary("LibCandyBar-3.0", 110) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs_Plugins\Libs` | LibCustomGlow-1.0 | local lib, oldversion = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSIO | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BigWigs_Plugins\Libs` | LibSink-2.0 | local SINK20_MINOR = 120001 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BugSack\Libs` | AceComm-3.0 | local MAJOR, MINOR = "AceComm-3.0", 14 | --- **AceComm-3.0** allows you to send messages of unlimited length over the addon comm channels. | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BugSack\Libs` | AceSerializer-3.0 | local MAJOR,MINOR = "AceSerializer-3.0", 5 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BugSack\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\BugSack\Libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BugSack\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\BugSack\Libs` | LibSharedMedia-3.0 | Revision: $Revision: 181 $ | License: LGPL v2.1 | YES (keep notice) |
| I:\ | `I:\BugSack\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain | YES (keep notice) |
| I:\ | `I:\MikScrollingBattleText\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\MikScrollingBattleText\Libs` | LibDeflate | - | @copyright LibDeflate <2018-2021> Haoqian He | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\MikScrollingBattleText\Libs` | LibSerialize | - | Copyright (c) 2020 VortexQ8 | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\MikScrollingBattleText\Libs` | LibSharedMedia-3.0 | local MAJOR, MINOR = "LibSharedMedia-3.0", 8020003 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\MikScrollingBattleText\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | not found locally | YES (Public Domain, header) |
| I:\ | `I:\MoveAny\libs` | D4Lib | - | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceAddon-3.0 | local MAJOR, MINOR = "AceAddon-3.0", 13 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceBucket-3.0 | local MAJOR, MINOR = "AceBucket-3.0", 4 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceComm-3.0 | local MAJOR, MINOR = "AceComm-3.0", 14 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceConfig-3.0 | local MAJOR, MINOR = "AceConfig-3.0", 3 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceDB-3.0 | - | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 17 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceEvent-3.0 | local MAJOR, MINOR = "AceEvent-3.0", 4 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceGUI-3.0-SharedMediaWidgets | local AGSMW = LibStub:NewLibrary("AceGUISharedMediaWidgets-1.0", DataV | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | AceTimer-3.0 | local MAJOR, MINOR = "AceTimer-3.0", 17 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | HereBeDragons | local MAJOR, MINOR = "HereBeDragonsQuestie-2.0", 34 | TOC ## X-License: BSD | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | Krowi_WorldMapButtons | local lib, oldminor = LibStub:NewLibrary('Krowi_WorldMapButtons-1.4',  | LICENSE:Copyright (c) 2020 Krowi All Rights Reserved unless otherwise explicitly stated. | NO |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 56 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibDeflate | - | @copyright LibDeflate <2018-2020> Haoqian He | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibSharedMedia-3.0 | Revision: $Revision$ | License: LGPL v2.1 | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | LICENSE.txt:Copyright (c) 2007, Ace3 Development Team  All rights reserved. | YES (keep notice) |
| I:\ | `I:\Questie-master\Questie-master\Libs` | LibUIDropDownMenu | local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\QuestieTrace-master\QuestieTrace-master\Libs` | LibDeflate | - | @copyright LibDeflate <2018-2020> Haoqian He | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\QuestieTrace-master\QuestieTrace-master\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | TOC ## X-License: Public Domain | YES (keep notice) |
| I:\ | `I:\Simulationcraft\libs` | AceAddon-3.0 | local MAJOR, MINOR = "AceAddon-3.0", 13 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\Simulationcraft\libs` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\Simulationcraft\libs` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\Simulationcraft\libs` | AceEvent-3.0 | local MAJOR, MINOR = "AceEvent-3.0", 4 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\Simulationcraft\libs` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 6 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\Simulationcraft\libs` | LibDBIcon-1.0 | local DBICON10_MINOR = 57 | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Simulationcraft\libs` | LibDataBroker-1.1 | local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4) | not found locally | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Simulationcraft\libs` | LibRealmInfo | local MAJOR, MINOR = "LibRealmInfo", 13 | Copyright 2014-2019 Phanx <addons@phanx.net> | UNKNOWN - verify upstream before bundling |
| I:\ | `I:\Simulationcraft\libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
| I:\ | `I:\TrufiGCD\Libs` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | TOC ## X-License: Public Domain  | YES (keep notice) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceConfig-3.0 | local MAJOR, MINOR = "AceConfig-3.0", 3 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceConsole-3.0 | local MAJOR,MINOR = "AceConsole-3.0", 7 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceDB-3.0 | - | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceDBOptions-3.0 | local ACEDBO_MAJOR, ACEDBO_MINOR = "AceDBOptions-3.0", 15 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceGUI-3.0 | local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | AceGUI-3.0-SharedMediaWidgets | local AGSMW = LibStub:NewLibrary("AceGUISharedMediaWidgets-1.0", DataV | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | CallbackHandler-1.0 | local MAJOR, MINOR = "CallbackHandler-1.0", 8 | not found locally | YES (Ace3 BSD-3; LICENSE.txt in Questie copy) |
| I:\ | `I:\sArena_Reloaded\Ace3` | LibStub | local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2 | -- LibStub is hereby placed in the Public Domain Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel | YES (keep notice) |
