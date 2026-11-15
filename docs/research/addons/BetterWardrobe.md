# BetterWardrobe (+ SourceData)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only (not on I:\), 6.12.3.

**Licence:** All Rights Reserved; "not licensed for distribution, modification, or commercial use without explicit written permission". Study only.

Extends the transmog collection and wardrobe: saved outfit sets beyond Blizzard's limit, extra sets data, situations (auto outfit per situation), randomiser, sorting and filters, dressing room tools.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `BetterWardrobe` | 6.12.3 | not on I:\\ | 120100 | 61 / 46,706 |
| `BetterWardrobe_SourceData` | 6.12.3 | not on I:\\ | 120100 | 4 / 113,395 |

- **Title / notes (toc):** BetterWardrobe (6.12.3) - no notes line
- **Author (toc):** SLOKnightfall
- **SavedVariables:** `BTT`, `BetterWardrobe_CharacterData`, `BetterWardrobe_ListData`, `BetterWardrobe_Mogitdata`, `BetterWardrobe_Options`, `BetterWardrobe_SavedSetData`, `BetterWardrobe_SubstituteItemData`, `BetterWardrobe_Updates`
- **Required deps:** Blizzard_Collections, Blizzard_Transmog
- **Optional deps:** MogMount,MogIt, CanIMogIt, Rarity, TransmogOutfits, ExtendedSets, ElvUI, PetTracker, PetTrackerJournal, Luckys_Wardrobe
- **Embedded libraries:** AceAddon-3.0, AceConfig-3.0, AceConsole-3.0, AceDB-3.0, AceDBOptions-3.0, AceEvent-3.0, AceGUI-3.0, AceHook-3.0, AceLocale-3.0, AceSerializer-3.0, CallbackHandler-1.0, LibAppropriateitems-1.0, LibArmorToken-1.0, LibStub, TaintLess (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 19x, `C_Timer` calls 35x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 26x, `hooksecurefunc` 17x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH`, `UNIT_FORM_CHANGED`, `TRANSMOG_COLLECTION_ITEM_UPDATE`, `DISPLAY_SIZE_CHANGED`, `UI_SCALE_CHANGED`, `VIEWED_TRANSMOG_OUTFIT_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS`, `TRANSMOG_SEARCH_UPDATED`, `TRANSMOG_COLLECTION_UPDATED`, `TRANSMOGRIFY_UPDATE`, `TRANSMOG_PENDING_CHANGES`, `SPELLS_CHANGED`, `TRANSMOG_OUTFITS_CHANGED`, `TRANSMOG_COLLECTION_CAMERA_UPDATE`, `TRANSMOG_SETS_UPDATE_FAVORITE`, `SPELL_UPDATE_COOLDOWN`, `INSPECT_READY`, `BW_NAME_TRANSMOG_OUTFIT`, `BW_CONFIRM_DELETE_TRANSMOG_OUTFIT`, `TRANSMOG_OUTFIT_CHECKING_APPEARANCES`, `BW_TRANSMOG_CUSTOM_SET_NAME`
- **C_ namespaces used:** `C_TransmogCollection`, `C_TransmogSets`, `C_TransmogOutfitInfo`, `C_AddOns`, `C_Item`, `C_Timer`, `C_Transmog`, `C_CreatureInfo`, `C_PlayerInfo`, `C_ArtifactUI`, `C_Spell`, `C_CurrencyInfo`, `C_Container`, `C_ModelInfo`, `C_PlayerInteractionManager`

## Features

### Saved outfits and situations

- **What it does:** Unlimited saved outfits; apply outfits automatically by situation (e.g. in a city, in an instance).
- **Design (UX, settings, defaults):** Tabs added to the collections journal; import/export.
- **How it is coded:** `C_TransmogCollection`, `C_TransmogSets`, `C_TransmogOutfitInfo.SetPendingTransmog`, with TaintLess to reduce taint on the journal.
- **Benefit to players:** Fashion players save time.

**Compared with Phoenix_UI** - status: **missing (by scope)**. Phoenix: collections/transmog skins and tooltip lines (`tt.lines.transmog`, `skins.transmog`). No outfit logic.

Ideas to adopt (original code only): Not planned.

### Collection list and filters

- **What it does:** Better sorting, colour filter, sources, hidden items.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Modules/SortingFunctions.lua`, `ColorFilter.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **missing**. missing (by scope)

## Verdict

Out of scope; test skin coexistence (P3).
