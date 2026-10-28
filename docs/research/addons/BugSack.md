# BugSack and !BugGrabber (error capture)

> Research note for Phoenix_UI. Source read-only from the user's PC; studied on the box on 2026-10-28. Descriptions are in our own words; no code from this addon is reproduced. Everything below was verified by reading the source unless marked **(unverified)**. Nothing here was run in game.

## Overview

**Locations:** both the game AddOns folder and I:\ (game: BugSack v12.1.9 / BugGrabber v12.1.1; I:\: BugSack v12.1.8 / BugGrabber v12.1.1)

**Licence:** All Rights Reserved (toc X-License). BugSack adds "free to fork and modify on GitHub, ask about anything else". Study only.

A two-part pair by Funkeh: **!BugGrabber** loads first (the `!` sorts it to the front) and replaces the Lua error handler so it can catch every error and blocked-action event from the very first file loaded; **BugSack** is the viewer (a sack window, a broker/minimap icon, sound and chat alerts).

### Facts from the files

| Folder | Game folder version | I:\ version | Interface | Own Lua files / lines |
|---|---|---|---|---|
| `BugSack` | v12.1.9 | v12.1.8 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 6 / 1,812 |
| `!BugGrabber` | v12.1.1 | v12.1.1 | 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107 | 1 / 579 |

- **Title / notes (toc):** BugSack - Toss those bugs inna sack.
- **Author (toc):** Funkeh
- **X-License (toc):** All Rights Reserved: You are free to fork and modify on GitHub, please ask us about anything else.
- **SavedVariables:** `BugSackDB`, `BugSackLDBIconDB`
- **Slash commands:** `/bugsack`
- **Optional deps:** Ace3, LibSharedMedia-3.0, LibDBIcon-1.0, !BugGrabber
- **Embedded libraries:** AceComm-3.0, AceSerializer-3.0, CallbackHandler-1.0, LibDBIcon-1.0, LibDataBroker-1.1, LibSharedMedia-3.0, LibStub (see [Shared libraries](_SharedLibraries.md))
- **Update model (static count over the own code, libraries excluded):** `OnUpdate` mentioned 0x, `C_Timer` calls 1x.
- **Secure surface:** no secure templates, state drivers or SetAttribute calls found.
- **Hooks:** `hooksecurefunc` 1x
- **Event-style names referenced in files that register events (top, may include a few plain constants):** `LOADING_SCREEN_DISABLED`, `PLAYER_LOGIN`, `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, `LUA_WARNING`
- **C_ namespaces used:** `C_Timer`, `C_StringUtil`, `C_AddOns`

## Features

### Early error capture

- **What it does:** Catches Lua errors, `ADDON_ACTION_BLOCKED`/`ADDON_ACTION_FORBIDDEN` and `LUA_WARNING` from load onward, even before other addons exist.
- **Design (UX, settings, defaults):** No UI of its own; it just stores. A hard cap (`MAX_BUGGRABBER_ERRORS` = 500 stored errors) protects the saved file.
- **How it is coded:** Keeps a private copy of `seterrorhandler`, installs its own handler and blocks later replacements. Each error becomes a record {message, stack, locals, session, time, counter}. Duplicate messages are found in the current session list and only bump `counter`. Stack text is cleaned and checked with `issecretvalue` (Midnight can return secret stacks). Pseudo: `on error(msg): rec = find(session, msg) or new(msg, stack, locals); rec.counter++; fire("BugGrabber_BugGrabbed", rec)`.
- **Benefit to players:** No error is lost, even on login. Duplicate counting keeps the sack small during a loop error.

**Compared with Phoenix_UI** - status: **better**. Phoenix has Sentinel (`Phoenix_UI_Sentinel/Capture.lua`, `Taint.lua`, `Ring.lua`, `Store.lua`) and a BugGrabber bridge in `Core/SentinelHook.lua`; the toc lists BugGrabber as an optional dependency. Sentinel also records taint, secret-value and API-drift events, which BugGrabber does not. `Store.lua` caps other addons' errors at 100 (`MAX_OTHERS`).

Ideas to adopt (original code only): Keep the bridge; make sure our handler never fights BugGrabber for `seterrorhandler` (read-only consumer when BugGrabber is present). Adopt the idea of a hard size cap per session plus duplicate counters if `Store.lua` does not already cap by count (unverified).

### Bug viewer (BugSack)

- **What it does:** A window that pages through captured errors with session filters (current, previous, all), copy box and send-to-friend.
- **Design (UX, settings, defaults):** Options: sound on error (LibSharedMedia sound, "Fatality" by default), chat-frame print (off by default), auto-popup (off by default, and never in combat). Minimap/broker icon shows the count.
- **How it is coded:** Listens to the BugGrabber callback; `sack.lua` builds one reusable frame; `config.lua` builds checkbox rows. Sharing uses AceComm + AceSerializer to whisper an error to another player.
- **Benefit to players:** Players can report bugs with a full stack without enabling Blizzard's script errors.

**Compared with Phoenix_UI** - status: **better**. Phoenix has `Phoenix_UI_Sentinel/Viewer.lua`, `Toast.lua`, `Share.lua`, `Export.lua` and `Core/BugDisplay.lua`, plus the companion Uploader. Sentinel goes further (uploads, fixed-errors list, privacy scrub in `Privacy.lua`). Note: rg found no `InCombatLockdown` check in `Phoenix_UI_Sentinel/Toast.lua`; confirm toasts never pop a window in combat **(unverified)**.

Ideas to adopt (original code only): Copy the "never auto-open in combat" rule (verify Sentinel `Toast.lua` respects `InCombatLockdown`).

## Verdict

Phoenix's Sentinel already exceeds the pair. Keep BugGrabber compatibility as a first-class path because many players run it. No gaps of note.
