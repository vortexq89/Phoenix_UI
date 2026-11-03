# Tust_EUI (TustEUI companion plugin for EllesmereUI)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Game AddOns folder only, 1.1.20.

**Licence:** No licence file: treat as All Rights Reserved, study only.

Companion plugin that adds pages to EllesmereUI: a chat replacement, a multi-bar Data Bars engine, enhanced XP bar, LFG enhancements, nameplate rules, tooltip additions and Blizzard UI tweaks. ~61k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `Tust_EUI` | 1.1.20 | not on I:\\ | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 31 / 60,903 |

- **Title / notes (toc):** TustEUI - A TustEUI companion plugin for EllesmereUI.
- **Author (toc):** Tust
- **SavedVariables:** `TustEUICharacterDB`, `TustEUIDB`, `TustEUIGoldDB`
- **Slash commands:** `/tust`, `/tusteui`, `/tustfps`
- **Required deps:** EllesmereUI
- **Optional deps:** NaowhUI_EUI, AlterEgo, NorthernSkyRaidTools, MyusKnowledgePointsTracker, EllesmereUIChat, EllesmereUIDataBars, EllesmereUINameplates, EllesmereUIFriends, EllesmereUIQoL, EllesmereUIBlizzardSkin, EllesmereUIMinimap, EllesmereUIRaidFrames
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 38x, `C_Timer` calls 102x.
- **Secure surface:** `SetAttribute` 89x, `SecureActionButtonTemplate` 15x, `SecureHandlerStateTemplate` 7x, `RegisterStateDriver` 7x, `SecureHandlerSetFrameRef` 2x, `SecureHandlerClickTemplate` 2x
- **Hooks:** `hooksecurefunc` 110x, `HookScript` 140x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`, `PLAYER_REGEN_DISABLED`, `ZONE_CHANGED_NEW_AREA`, `GROUP_ROSTER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `FULLSCREEN_DIALOG`, `COPPER_SUFFIX`, `PLAYER_TARGET_CHANGED`, `LOADING_SCREEN_DISABLED`, `PLAYER_GUILD_UPDATE`, `CVAR_UPDATE`, `UNIT_TARGET`, `BAG_UPDATE_DELAYED`, `PLAYER_DIFFICULTY_CHANGED`, `UPDATE_CHAT_WINDOWS`, `UPDATE_FLOATING_CHAT_WINDOWS`, `PLAYER_LOGOUT`, `GOLD_SUFFIX`, `SILVER_SUFFIX`, `UPDATE_FACTION`
- **C_ namespaces used:** `C_Timer`, `C_Item`, `C_LFGList`, `C_CurrencyInfo`, `C_Reputation`, `C_Container`, `C_AddOns`, `C_ClassTalents`, `C_Spell`, `C_Map`, `C_FriendList`, `C_GuildInfo`, `C_MajorFactions`, `C_PartyInfo`, `C_Texture`

## Features

### Chat replacement

- **What it does:** Own chat chrome around Blizzard's message surface: appearance, artwork, collapse, history (timestamps, persistent history, edit-box history), links, movement, notifications, sidebar.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Ownership boundary: only its own visual hosts are reparented; native widgets keep their hierarchy; reply reads the native edit-box parent before using secret whisper targets.
- **Benefit to players:** Modern chat without breaking Blizzard's secret whisper handling.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_Chat` (skin, history, whisper windows, channel bar, emoji, keyword alerts).

Ideas to adopt (original code only): Their rule "reparent only our hosts, never native widgets" is a good written guardrail; check our Chat follows it.

### Data Bars multi-bar engine

- **What it does:** User-created data bars with blocks, a secure Raid Tools shelf (prebuilt before combat), a social block with online friends/guild list, supplies (Forever).
- **Design (UX, settings, defaults):** -
- **How it is coded:** Engine file + per-instance block factories; protected frames all built before combat.
- **Benefit to players:** Flexible info bars.

**Compared with Phoenix_UI** - status: **same**. Phoenix DataBars (`db.*`), `rt.*`, friends in minimap (`mm.extra.friends`).

### Enhanced XP bar, LFG region/rating, nameplate rules, tooltips, bag upgrade markers, stat priorities, minimap group info

- **What it does:** -
- **Design (UX, settings, defaults):** -
- **How it is coded:** Read-only unit tooltip additions; LFG sorting is "safely gated"; stat priorities catalogue allocated only when enabled.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **mostly same**. Phoenix: `gf.regionBadge`, `gf.rioScore`, `np.rules`, `tt.lines.*`, `wisdom.bags` (upgrade star in bags). Stat priority display: Wisdom weights (not a "stat priority" text line).

Ideas to adopt (original code only): P3: show the active stat priority (from Wisdom weights) on the character sheet.

## Verdict

Parity. Useful guardrail wording about reparenting.
