# Raider.IO (+ regional database addons)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game folder only (12.1.0, data v202610260600) with 15 `RaiderIO_DB_<region>_<M|R|F>` data addons (M+ / raid / recruitment for CN, EU, KR, TW, US). Not on I:\. The DB folders were not copied to the box (data only).

**Licence:** All Rights Reserved (LICENSE). Study only; the data is theirs and must not be bundled.

Shows Mythic+ score, best runs, raid progress and recruitment info in tooltips, the group finder and profiles. Data comes from load-on-demand database addons per region that the Raider.IO client updates.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `RaiderIO` | 12.1.0 (v202610260600) | not on I:\\ | 120100, 120105 | 13 / 27,174 |

- **Title / notes (toc):** Raider.IO Mythic Plus, Raiding, and Recruitment - Shows Raider.IO Mythic+ Score, Raid Progress, and Recruitment status in-game. Make sure to load one or more region DB.
- **Author (toc):** Vladinator (Vladinator-TarrenMill), Aspyr (Aspyrox-Skullcrusher) and Isak (Isak-Sargeras)
- **SavedVariables:** `RaiderIO_CachedRuns`, `RaiderIO_CompletedReplays`, `RaiderIO_Config`, `RaiderIO_LastCharacter`, `RaiderIO_MissingCharacters`, `RaiderIO_MissingServers`, `RaiderIO_RWF`
- **Embedded libraries:** CallbackHandler-1.0, LibClassTalentsImportExport-1.0, LibCombatLogging-1.0, LibDataBroker-1.1, LibDropDownExtension-1.0, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 25x, `C_Timer` calls 12x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 23x, `HookScript` 51x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `RAIDERIO_SETTINGS_SAVED`, `NONE_COLORLESS`, `RAIDERIO_CONFIG_READY`, `MODERN_SPLITS`, `PLAYER_ENTERING_WORLD`, `MODERN_COMPACT`, `RAIDERIO_SETTINGS_WIDGET_UPDATE`, `IN_OUT`, `NONE_YELLOW`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `COMBAT_LOG_EVENT_UNFILTERED`, `RAIDERIO_SETTINGS_CLOSED`, `RAIDERIO_PLAYER_LOGIN`, `PLAYER_SPECIALIZATION_CHANGED`, `ZONE_CHANGED_NEW_AREA`, `ADDON_LOADED`, `MODIFIER_STATE_CHANGED`, `CHAT_MSG_SYSTEM`, `CHALLENGE_MODE_COMPLETED`, `WORLD_STATE_TIMER_START`
- **C_ namespaces used:** `C_LFGList`, `C_ChallengeMode`, `C_Timer`, `C_AddOns`, `C_ClassTalents`, `C_Traits`, `C_SpecializationInfo`, `C_Item`, `C_CreatureInfo`, `C_BattleNet`, `C_FriendList`, `C_Texture`, `C_MythicPlus`, `C_PlayerInfo`, `C_LootHistory`

## Features

### Score and progress in tooltips

- **What it does:** Unit, LFG applicant, guild and friend tooltips show M+ score, best key per dungeon, raid progress.
- **Design (UX, settings, defaults):** Many profile options (`core.lua` is ~30k lines: Profile 581 refs, Keystone 244, Guild 197).
- **How it is coded:** Region DB addons are loaded on demand; lookups by realm+name; tooltips via `TooltipDataProcessor` and LFGList hooks.
- **Benefit to players:** Quick vetting of players.

**Compared with Phoenix_UI** - status: **partial by design (no offline database)**. Phoenix reads Raider.IO if present (`Phoenix_UI_GroupFinder/Extras.lua`, `Core/Season.lua`, `gf.rioScore`) and has its own season score colours (`season.scoreColors`) and Blizzard M+ rating in tooltips (`tt.mplus`, `tt.lines.bestRun`).

Ideas to adopt (original code only): Keep the "use Raider.IO when installed" integration; never ship their data.

### Copy URL / search

- **What it does:** Right-click menu "Copy Raider.IO URL", `/rio` search.
- **Design (UX, settings, defaults):** Uses LibDropDownExtension to add menu entries.
- **How it is coded:** Adds to unit context menus.
- **Benefit to players:** Easy profile lookup.

**Compared with Phoenix_UI** - status: **missing**. Phoenix: no context-menu additions found (rg `Menu.ModifyMenu`: none).

Ideas to adopt (original code only): P3: optional "Copy armory link" entry via `Menu.ModifyMenu` (original).

### Combat logging helper

- **What it does:** Auto-enables combat logging for uploads.
- **Design (UX, settings, defaults):** Option.
- **How it is coded:** LibCombatLogging.
- **Benefit to players:** Log uploads.

**Compared with Phoenix_UI** - status: **same**. Phoenix `flow.combatLog`, `flow.combatLogWhere`.

## Verdict

No action needed beyond the existing integration. P3: context-menu link.
