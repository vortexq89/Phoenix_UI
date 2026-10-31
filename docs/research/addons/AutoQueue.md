# AutoQueue + AutoSignLFG

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (1.5.4 in both)

**Licence:** No licence file: treat as All Rights Reserved, study only.

Small helper by Azaleth that answers Dungeon Finder role checks automatically and speeds up Premade Group sign-ups, with a role bar to pick the roles.

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `AutoQueue` | 1.5.4 | 1.5.4 | 120105, 120107 | 13 / 1,472 |

- **Title / notes (toc):** AutoQueue + AutoSignLFG - Auto-accept role checks
- **Author (toc):** Azaleth
- **SavedVariables:** `AutoAcceptQueueCharDB`
- **Slash commands:** `/aq`, `/autoqueue`
- **Optional deps:** LibStub, LibDataBroker-1.1, LibDBIcon-1.0
- **Embedded libraries:** CallbackHandler-1.0, LibDataBroker-1.1, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 6x.
- **Secure surface:** `SetAttribute` 2x, `SecureActionButtonTemplate` 1x
- **Hooks:** `hooksecurefunc` 3x, `HookScript` 5x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `ADDON_LOADED`, `PLAYER_ENTERING_WORLD`, `PLAYER_LOGIN`, `LFG_ROLE_CHECK_SHOW`, `LFG_LIST_SEARCH_RESULTS_RECEIVED`, `LFG_LIST_APPLICATION_STATUS_UPDATED`
- **C_ namespaces used:** `C_Timer`, `C_AddOns`, `C_LFGList`

## Features

### Auto role check

- **What it does:** Confirms the LFD role check with your roles as soon as it appears.
- **Design (UX, settings, defaults):** Per-character toggle (`AutoAcceptQueueCharDB.active`); role override for tank/healer/dps or "use current spec".
- **How it is coded:** On `LFG_ROLE_CHECK_SHOW`, if active and not in combat, it sets roles with `SetLFGRoles` and confirms. Role from spec unless overridden.
- **Benefit to players:** Saves a click every queue; no failed role checks while tabbed out.

**Compared with Phoenix_UI** - status: **same**. Phoenix `Phoenix_UI_GroupFinder/QueueHelper.lua` handles role checks, sign-up and the Enter-to-sign-up button (`gf.*` keys).

### Auto sign-up for premades

- **What it does:** Fills the application dialog with your roles and signs up in one click.
- **Design (UX, settings, defaults):** Role bar (`AutoQueueRoleBar.lua`) with class-legal roles only; LDB/minimap icon.
- **How it is coded:** Hooks `LFGListApplicationDialog` and listens to `LFG_LIST_SEARCH_RESULTS_RECEIVED` / `LFG_LIST_APPLICATION_STATUS_UPDATED`.
- **Benefit to players:** Faster group finding.

**Compared with Phoenix_UI** - status: **same**. Covered by QueueHelper (sign-up, Enter button). PremadeGroupsFilter also covers this.

Ideas to adopt (original code only): A visible role bar that only offers the roles your class can play is a nice touch; check our sign-up dialog greys out impossible roles.

## Verdict

Covered by Phoenix GroupFinder. No gaps.
