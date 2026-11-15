# Phoenix Uploader

**1.1.0**: also uploads Phoenix UI 2.x Sentinel reports (`Phoenix_UI_Sentinel.lua`, `PhoenixUISentinelDB.outbox`, contract v2) from `_retail_` and the WoW Forever client folder next to it, with each report's game (retail / forever), the session and the installed addon list (name, version, enabled, loaded) the game wrote. Nothing is sent while "Auto-upload via Companion" is off in game.

Sends the error reports that the Phoenix UI **Bugs** module saves in game to vq8s.com, so they can be triaged in the
Phoenix admin (`/phoenix/admin`). One self-contained Windows exe, no installer, no runtime.

Addons cannot reach the internet. Phoenix UI writes its reports to
`World of Warcraft\_retail_\WTF\Account\<account>\SavedVariables\Phoenix_UI.lua` (variable `PhoenixUIBugsDB`) when
the player logs out or types `/reload`. The uploader reads that file and POSTs reports it has not sent yet.

## What it does

- **Finds WoW on its own**: `PHOENIX_WOW_PATH`, then the Blizzard uninstall / install keys in the registry,
  `Battle.net.config` and the Battle.net agent's `product.db`, then the usual folders on drives C: to Z:.
  Extra folders can be added with `--wow` or `wowPaths` in config.json.
- **Reads the file safely**: a small parser for the SavedVariables subset of Lua (tables, strings, numbers,
  booleans, nil). Nothing is executed; anything else (function calls, expressions) is refused.
- **Sends only what is new**: `state.json` remembers each report id and the count it was sent with. A report is
  sent again only when its count grew (the same error happened more often). The server is idempotent too, so a
  lost state file only produces "already there" answers.
- **Background or once**: double-click starts it in the tray (status, Upload now, Open log, Open data folder,
  Phoenix UI page, Start with Windows, Quit) and it re-checks every 60 s, only re-reading files whose time stamp
  changed. `--once` scans, uploads and exits (exit code 0 ok, 1 error, 2 no WoW folder found).
- **Polite on errors**: 429 / 5xx / network errors back off and retry (honouring `Retry-After`); a refused key
  (403) is logged and the background mode waits 30 minutes before trying again (Upload now tries at once).
- **Logs** to `uploader.log` (rotated at 1 MB) in the data folder: `%LOCALAPPDATA%\Phoenix UI Uploader`.

What travels: the report fields of the shared contract (id, hash, kind, message, stack, locals, count, first/last
seen, session, addon version, interface, build, locale, source) plus the random 16-hex `installId` the addon made.
No character, realm or account names: the account folder name is only used in the local log.

## Command line

```
PhoenixUploader.exe                     tray / background (first run also adds itself to "start with Windows")
PhoenixUploader.exe --once              scan, upload, exit
PhoenixUploader.exe --once --dry-run    show what would be sent
  --wow <folder>        a World of Warcraft or _retail_ folder (repeatable)
  --endpoint <url>      override the ingest URL (https only; http allowed for localhost testing)
  --key <key>           override the ingest key
  --data-dir <folder>   where config.json, state.json and uploader.log live
  --no-tray             background without the tray icon
  --install-startup / --remove-startup
  --version
```

## The ingest key

The key is **not** in the source. It is the value of the site's `PHOENIX_INGEST_KEY` secret and reaches the exe
in one of two ways:

1. baked in at build time: `PHOENIX_INGEST_KEY=... ./build.sh` (sets `main.defaultIngestKey` with `-ldflags -X`), or
2. a `config.json` next to the exe or in the data folder (see `config.example.json`).

The key ships to every player, so it is a gate against random traffic, not a secret: the server also rate-limits
per IP and per install, validates every field and only lets an install write report ids that start with its own
installId.

## Build

```
./build.sh             # Linux/macOS/WSL: tests, dist/PhoenixUploader.exe (windows/amd64, GUI subsystem) + a Linux build
.\build.ps1            # the same on Windows
```

Go 1.22+. `CGO_ENABLED=0`, `-trimpath -s -w -H windowsgui`. The icon and version resource come from
`winres/` through go-winres (`go install github.com/tc-hib/go-winres@latest`) when it is installed.
`dist/SHA256SUMS` lists the hashes. Attach `PhoenixUploader.exe` to each GitHub release under that exact name:
the website links to `releases/latest/download/PhoenixUploader.exe`.

## Test

`go test ./...` covers the parser (escapes, long strings, comments, refusals, depth limit), reading the sample
file in `testdata/`, the sent-state rules, batching, the endpoint policy, folder detection, and a full cycle
against a fake server (send, re-run sends nothing, a grown count is re-sent, a refused key surfaces).
