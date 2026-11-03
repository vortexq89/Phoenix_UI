# EllesmereUI Chat

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Chat skin with a sidebar of icons (portal flyout etc.), fade rules, session history, link copying and tabs. ~11k lines.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIChat` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 14 / 10,891 |

- **Title / notes (toc):** EllesmereUI Chat - Modern chat enhancements with useful utilities.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIChatDB`, `EllesmereUIChatScrollDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 24x, `C_Timer` calls 37x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 50x, `hooksecurefunc` 18x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_ENTERING_WORLD`, `CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`, `CHAT_MSG_WHISPER_INFORM`, `CHAT_MSG_BN_WHISPER_INFORM`, `EDIT_MODE_LAYOUTS_UPDATED`, `PLAYER_REGEN_ENABLED`, `UPDATE_CHAT_COLOR`, `PLAYER_LOGOUT`, `PLAYER_LEAVING_WORLD`, `PLAYER_LOGIN`, `CHAT_MSG_SAY`, `CHAT_MSG_YELL`, `CHAT_MSG_GUILD`, `CHAT_MSG_OFFICER`, `CHAT_MSG_PARTY`, `CHAT_MSG_PARTY_LEADER`, `CHAT_MSG_RAID`, `CHAT_MSG_RAID_LEADER`, `CHAT_MSG_INSTANCE_CHAT`, `CHAT_MSG_INSTANCE_CHAT_LEADER`, `CHAT_MSG_CHANNEL`
- **C_ namespaces used:** `C_Timer`, `C_EditMode`, `C_ChatInfo`, `C_ChallengeMode`, `C_AddOns`, `C_Housing`, `C_BattleNet`, `C_Texture`, `C_VoiceChat`, `C_HouseEditor`, `C_FriendList`, `C_GuildInfo`

## Features

### Sidebar and fade

- **What it does:** Sidebar icons (chat menu, portals, social) on either side; idle fade with mouse passthrough at full hide.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `EUI_Chat_Sidebar*.lua`, `Visibility.lua`.
- **Benefit to players:** Clean screen.

**Compared with Phoenix_UI** - status: **same**. Phoenix `chat.channelBar`, `chat.idleFade`, `chat.fadeAlpha`.

### Session history, URL copy, copy chat

- **What it does:** History restored across reloads; URLs clickable with popup; copy any line.
- **Design (UX, settings, defaults):** -
- **How it is coded:** `SessionHistory.lua`, `Links.lua`.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **same**. Phoenix `chat.history`, `chat.persistHistory`, `chat.urls`, `chat.lineCopy`.

## Verdict

Parity.
