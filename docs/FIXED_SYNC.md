# Fixed-in sync: Companion to addon (design, deferred batch D)

## Goal
When an error is marked fixed on the dashboard, every tester's Sentinel should know which version fixed it, so the viewer shows it as "Fixed in 1.4.2" and flags it as "Back after fix" if it happens again on that version or later.

## Limits of the game client
- An addon cannot read files, sockets or the clipboard. The only data an addon can read from outside is its SavedVariables (read once, when the game loads the addon) and text the player pastes.
- The client writes SavedVariables at logout and /reload. It overwrites any outside edit made while the game is running.

## Part 1: built now (no new infrastructure)
1. The developer exports the fixed issues from the dashboard as JSON. That is the existing issue list (`hash`, `status`, `fixedIn`); the existing read API returns it.
2. `sentinel-companion fixed-string issues.json` (`companion/sentinel_companion/fixedin.py`) keeps the rows whose status is `fixed` and that have a valid hash and version. It drops duplicates, caps the list at 500 rows and prints a `!PUI_SEN` string. That is the same encoding as report exports (JSON, deflate, base64).
3. The tester runs `/pui sentinel fixed` in game, pastes the string and clicks Import (`Phoenix_UI_Sentinel/FixedSync.lua`). The addon checks the payload kind and every row's hash and version against the same rules. Valid rows are marked Fixed through `Store:SetState`; nothing else changes. The open viewer repaints at once.

## Part 2: automatic sync (needs infrastructure, not built)
- **Server:** a per-install read scope that returns only `hash -> fixedIn` for the hashes that install reported. It must not expose other installs' data. Today the read token is admin-only and must never ship to players.
- **Companion:**
  - Pull that list after each upload.
  - Write it into `PhoenixUISentinelDB.fixedSync`, but only while Wow.exe is not running. The client would overwrite the change otherwise, and this is the same rule the installer follows.
  - Work like the installer: write to a staged copy, then swap it in, keeping a recovery copy.
- **Addon:** at load, apply `fixedSync` through the same `FixedSync.Apply` validation, then clear it.
- **Open questions:**
  - Signing the list, so a hand-edited SavedVariables file cannot mark errors fixed. A low-risk option is an HMAC with the install's upload key.
  - Whether "fixed" from the dashboard should override a tester's own "ignored" state. The proposal is no: local states win.

## Tests
- Companion: `FixedInTests`, which covers filtering, duplicates, bad hashes and versions, and the 500-row cap.
- Addon: the Sentinel test "fixed-in list from the Companion marks errors fixed, refuses bad input".
