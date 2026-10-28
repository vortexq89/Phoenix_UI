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

## Part 2: automatic sync (built, branch feat/fixed-sync)
- **Server (vq8-website, worker/phoenix/fixed.mjs):** `GET /phoenix/api/fixed` is public and returns `{ alg: "ed25519", keyId, payload, sig }`. The payload lists only `hash -> fixedIn` for issues marked fixed with a version (no report text, installs or addresses), at most 500 rows, newest first. It is signed with the Worker secret `PHOENIX_FIXED_SIGNING_KEY` (Ed25519, PKCS#8), cacheable for 5 minutes, limited to 60 requests per 10 minutes per address, and answers 503 rather than serve an unsigned list.
- **Uploader (companion/uploader/fixedsync.go, 1.2.0):** every 30 minutes, and only while no WoW client process is running, it fetches the list, checks the signature against the embedded public key, and writes `PhoenixUISentinelFixed = {...}` into every account's `Phoenix_UI_Sentinel.lua`: staged file, then swap, with the previous file kept as `Phoenix_UI_Sentinel.lua.phoenix-bak`. An unchanged list is not rewritten.
- **Addon (Phoenix_UI_Sentinel/FixedSync.lua):** `PhoenixUISentinelFixed` is a declared SavedVariable. At load Sentinel checks its checksum (Adler-32 over `hash=version;` rows, the same as the Uploader), applies it through `F.Apply` (marks Fixed in that version, so the viewer shows "Fixed in X" and "Back after fix" if it returns), keeps local Ignored states, then clears the variable.
- **Decisions:** the signature is verified in the Uploader (Lua has no fast Ed25519); the addon trusts only Uploader-written data with a matching checksum. Local Ignored wins over the dashboard's Fixed.

## Tests
- Companion: `FixedInTests`, which covers filtering, duplicates, bad hashes and versions, and the 500-row cap.
- Addon: the Sentinel tests "fixed-in list from the Companion marks errors fixed, refuses bad input" and "fixed-in sync: Uploader-written list applied once at load".
- Uploader: `go test ./...` (signature, tampering, wrong key, checksum parity with Lua, staged write and recovery copy).
- Server: `node --test worker/phoenix/fixed.test.mjs` in vq8-website.
