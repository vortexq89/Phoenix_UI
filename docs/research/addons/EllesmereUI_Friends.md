# EllesmereUI Friends

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** Both locations (game folder 9.6.8, I:\ 9.6.1).

**Licence:** EllesmereUI custom licence: all rights reserved. **Standing project rule: never reproduce EllesmereUI code.** Study only; every idea below must be rebuilt from scratch.

Friends list restyle using Blizzard's ScrollBox through hooks only (no custom data provider, no groups).

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `EllesmereUIFriends` | 9.6.8 | 9.6.1 | 120000, 120001, 120005, 120007, 120100, 120105, 16001 | 1 / 3,246 |

- **Title / notes (toc):** EllesmereUI Friends - A modern friends list with built-in organization tools.
- **Author (toc):** Ellesmere
- **SavedVariables:** `EllesmereUIFriendsDB`
- **Required deps:** EllesmereUI
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 7x, `C_Timer` calls 16x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `HookScript` 31x, `hooksecurefunc` 13x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `PLAYER_FLAGS_CHANGED`, `PLAYER_LOGIN`, `FRIENDLIST_UPDATE`, `BN_FRIEND_LIST_SIZE_CHANGED`, `BN_FRIEND_INFO_CHANGED`, `BN_FRIEND_INVITE_ADDED`, `BN_FRIEND_INVITE_REMOVED`, `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`
- **C_ namespaces used:** `C_Timer`, `C_ChallengeMode`, `C_FriendList`, `C_ChatInfo`, `C_SocialUI`, `C_BattleNet`, `C_PartyInfo`, `C_Texture`

## Features

### Friends list restyle

- **What it does:** Class colours, status, zone.
- **Design (UX, settings, defaults):** -
- **How it is coded:** Weak-keyed side table for frame state.
- **Benefit to players:** -

**Compared with Phoenix_UI** - status: **better**. Phoenix `Phoenix_UI_Friends` (search across friends/guild/recent, sort, app-only filter, notes, invite accept).

## Verdict

Phoenix is ahead.
