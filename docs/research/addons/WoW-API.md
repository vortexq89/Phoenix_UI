# WoW-API (reference repository, not an addon)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** I:\ only (`WoW-API-main`).

**Licence:** No licence file found at the top level (unverified). Reference material only.

A reference checkout: Blizzard API documentation (generated), FrameXML source, GlobalStrings for Era and Forever, common libraries (Ace3, LibDBIcon, HereBeDragons, LibQTip ...) and a generator. It is not loaded by the game.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `WoW-API` | not installed | (see toc) | - | 1340 / 320,226 |

- **Title / notes (toc):** WoW-API - no notes line
- **Author (toc):** not stated in the toc
- **Slash commands:** `/perfreport`, `/texelvis`, `/tvis`
- **Embedded libraries:** Libraries (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 567x, `C_Timer` calls 74x.
- **Secure surface:** `SetAttribute` 301x, `SecureHandlers` 16x, `SecureHandler_Other_Execute` 12x, `SecureHandler_Self_Execute` 10x, `RegisterStateDriver` 3x, `SecureFrameTemplate` 3x
- **Hooks:** `hooksecurefunc` 14x, `HookScript` 31x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE`, `VARIABLES_LOADED`, `CVAR_UPDATE`, `BN_WHISPER`, `ADDON_LOADED`, `GUILD_ROSTER_UPDATE`, `UNIT_AURA`, `DISPLAY_SIZE_CHANGED`, `UNIT_PET`, `PLAYER_GUILD_UPDATE`, `GET_ITEM_INFO_RECEIVED`, `PLAYER_TARGET_CHANGED`, `UNIT_NAME_UPDATE`, `QUEST_LOG_UPDATE`, `UNIT_HEALTH`, `UNIT_LEVEL`, `TRIAL_STATUS_UPDATE`, `GUILD_EVENT`, `COMMUNITY_EVENT`, `UNIT_PORTRAIT_UPDATE`, `SPELL_DAMAGE`
- **C_ namespaces used:** `C_Item`, `C_Club`, `C_AuctionHouse`, `C_Garrison`, `C_Calendar`, `C_VoiceChat`, `C_Commentator`, `C_PetBattles`, `C_LFGList`, `C_ClubFinder`, `C_TradeSkillUI`, `C_AddOns`, `C_PvP`, `C_Spell`, `C_GuildInfo`

## Features

### API and FrameXML reference

- **What it does:** Look up function signatures, events and Blizzard UI code.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `Blizzard_APIDocumentationGenerated`, `FrameXML`, `GlobalStrings/<flavour>/GlobalStrings_<locale>.lua`.
- **Benefit to players:** Accurate development without guessing.

**Compared with Phoenix_UI** - status: **same purpose; ours is automated**. Phoenix keeps its own generated catalogue (`Data/ApiCatalog.json`, `Data/ApiManifest.lua`) rebuilt weekly by the `api-watch` workflow from live, PTR and Forever sources.

Ideas to adopt (original code only): Use its Forever GlobalStrings to check that our Forever locale strings use the client's own wording where possible.

## Verdict

Reference only. No gaps.
