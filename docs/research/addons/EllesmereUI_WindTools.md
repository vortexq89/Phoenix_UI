# EllesmereUI_WindTools (WindTools port for EllesmereUI)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (0.2.8 in both).

**Licence:** Restricted-source: GPLv3 only inside the ElvUI and NDui ecosystems; any copying or reuse outside them needs a separate written licence. Phoenix is outside: **study only**.

A "migration shell" of WindTools (the ElvUI plugin) for EllesmereUI. Its toc says most original modules are intentionally disconnected. The source of ~90 modules is shipped, but `Modules/Load_Modules.xml` only loads: **Extra Item Bar** (+ data), **Chat Bar**, **Raid Markers**, **Friendly Nameplate Outline** and **Quick Focus**. The rest (announcements, tooltips, auto turn-in, fast loot, smart tab, mute, already known, contacts, event tracker, world map, etc.) is present on disk but not loaded in this build.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUI_WindTools` | 0.2.8 | 0.2.8 | 120100, 120105 | 312 / 89,024 |

- **Title / notes (toc):** EllesmereUI WindTools - Migration shell for WindTools on EllesmereUI. Most original WindTools modules are intentionally disconnected.
- **Author (toc):** fang2hou, XanaHopper
- **SavedVariables:** `EllesmereUI_WindToolsDB`, `WindToolsGlobalDB`, `WindToolsPrivateDB`
- **Slash commands:** `/windquestturnin`, `/windturnin`, `/wti`
- **Required deps:** EllesmereUI
- **Optional deps:** SharedMedia, MythicDungeonTools, Myslot, Details, WeakAuras, BigWigs, WorldQuestTab, BtWQuests, Clique, Cell
- **Embedded libraries:** LibItemEnchant, LibKeystone, LibObjectiveProgressWT, LibOpenRaid, LibRangeCheck-3.0, Load_Libraries.xml, Skins (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 23x, `C_Timer` calls 12x.
- **Secure surface:** `SetAttribute` 79x, `SecureActionButtonTemplate` 17x, `RegisterStateDriver` 15x, `SecureHandlerStateTemplate` 4x
- **Hooks:** `hooksecurefunc` 310x, `HookScript` 70x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `BN_WHISPER`, `PLAYER_REGEN_DISABLED`, `ZONE_CHANGED_NEW_AREA`, `GROUP_ROSTER_UPDATE`, `RAID_WARNING`, `QUEST_LOG_UPDATE`, `PLAYER_GUILD_UPDATE`, `QUEST_TURNED_IN`, `INSTANCE_CHAT`, `TEXT_EMOTE`, `PLAYER_EQUIPMENT_CHANGED`, `QUEST_ACCEPTED`, `QUEST_WATCH_LIST_CHANGED`, `UNIT_INVENTORY_CHANGED`, `ZONE_CHANGED`, `LOOT_READY`, `TRADE_SHOW`, `CONFIRM_SUMMON`
- **C_ namespaces used:** `C_Item`, `C_QuestLog`, `C_AddOns`, `C_CVar`, `C_BattleNet`, `C_Timer`, `C_LFGList`, `C_Map`, `C_ChallengeMode`, `C_GossipInfo`, `C_MythicPlus`, `C_Container`, `C_Club`, `C_SpecializationInfo`, `C_Spell`

## Features

### Extra Item Bar (loaded)

- **What it does:** Auto-filled item bars: quest items, consumables (flasks, food, potions), equipment on-use, trinkets, custom lists.
- **Design (UX, settings, defaults):** Several bars, each with source list, buttons per row, size, mouseover, visibility state driver (fixed the old "[petbattle]hide;show" syntax to include spaces).
- **How it is coded:** Secure item buttons; equipment slot icons read synchronously to avoid black icons before item info is cached; positions converted to BOTTOMLEFT so the bar grows up-right when resized; data file maps item categories.
- **Benefit to players:** No dragging consumables onto bars.

**Compared with Phoenix_UI** - status: **same**. Phoenix auto item bars (PR #66, `ab.ibar1..ibar5`, `ab.ibars`, `Data/ItemBarData.lua`, battle res button, M+ teleports on bar 5).

### Quick Focus (loaded)

- **What it does:** Modifier+click any unit frame to set focus.
- **Design (UX, settings, defaults):** Modifier and mouse button choice.
- **How it is coded:** Sets a focus macro attribute on frames; frames first seen in combat wait in a weak-keyed queue until combat ends; only touches frames it tagged; guards against frames whose `GetName` returns a non-string (Blizzard damage meter bars).
- **Benefit to players:** Fast focus for interrupts.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Core/FocusKey.lua` (`focuskey.modifier`, `focuskey.button`, `focuskey.groupFrames`, PR #70).

Ideas to adopt (original code only): Copy the two safety ideas: weak-keyed pending queue for combat, and a type guard on `GetName()`.

### Raid Markers bar (loaded)

- **What it does:** Bar of raid target and world marker buttons, clear, ready check, countdown.
- **Design (UX, settings, defaults):** Orientation, size, modifier for world markers.
- **How it is coded:** Secure buttons with marker macros.
- **Benefit to players:** Raid leading.

**Compared with Phoenix_UI** - status: **same**. Phoenix `rt.markers`, `rt.worldMarkers`, `rt.readyButton`, `rt.pullButton`.

### Chat Bar (loaded)

- **What it does:** Buttons to switch chat channels, world channel, emotes, roll.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Clickable bar beside chat.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `chat.channelBar`, `chat.channelBarSide`.

### Friendly Nameplate Outline (loaded)

- **What it does:** Class-coloured outline on friendly nameplates.
- **Design (UX, settings, defaults):** -
- **How it is coded:** -
- **Benefit to players:** Spot allies in PvP.

**Compared with Phoenix_UI** - status: **unverified**. Phoenix `np.friendly` styles (outline unverified).

Ideas to adopt (original code only): P3.

### Disconnected modules (present on disk, not loaded)

- **What it does:** Announcement (interrupt/quest/keystone/reset instance), Combat alert, Already Known, Contacts, Delete Item, Extend Merchant Pages, Fast Loot, Inspect, Item Level, Trade, Event Tracker, Instance Difficulty, Minimap Buttons, Rectangle Minimap, Super Tracker, World Map, Mute, Pause To Slash, Skip Cutscene, Smart Tab, Context Menu, Emote, Achievement tracker/screenshot, Objective tracker, Turn-in, tooltips (group info, keystone, M+, progression, tier set)...
- **Design (UX, settings, defaults):** -
- **How it is coded:** Not loaded in 0.2.8, so not active for the user (verified from the load XML).
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **mixed**. Phoenix already has many of these: `flow.autoDelete`, `flow.quickLoot`, `flow.screenshot`, `qt.autoQuest`, `mm.shape`, `mm.text.difficulty`, `tt.mplus`, `tt.lines.setPieces`, `chat.emoji`, `Core/Announce.lua`. Not found in Phoenix: **Already Known** tint at merchants/AH, **Extend Merchant Pages**, **Mute** (MuteSoundFile list), **Smart Tab** (Tab cycles whisper targets), **Event Tracker**, **context-menu extras**, **guild news item level**.

Ideas to adopt (original code only): P2: Already Known tint (merchant, AH browse, collections); P3: mute list, smart tab, extended merchant pages, event tracker.

## Verdict

Only five modules are live and Phoenix matches all five. The disconnected WindTools source suggests the P2/P3 list above.
