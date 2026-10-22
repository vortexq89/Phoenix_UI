# Phoenix Uploader

The Phoenix app. It does two jobs for the Phoenix UI addon, which cannot reach the internet or start programs:

1. sends the error reports that the **Bugs** module saves in game to vq8s.com, so they can be triaged in the
   Phoenix admin (`/phoenix/admin`);
2. runs **SimulationCraft** for the addon's **Sim** page (1.2.0+) and writes the results back for the game.

One self-contained Windows exe, no installer, no runtime.

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
No character, realm or account names: the account folder name is only used in the local log. The addon strips
identity before it stores a report, and the uploader repeats that on what it sends (GUIDs, BattleTags, Windows user
and account folders, every realm and character folder name of the account, text-like string locals).

**Opt-out**: when `PhoenixUIBugsDB.share` is `false` (*Send error reports to the author* switched off in the addon)
the account is skipped and the log says so. Reports caught while it is off are marked as handled and never sent.
A missing `share` (addon builds before 2.0.0-beta1's switch) counts as on. `"disabled": true` in `config.json`
still stops all uploads from this PC.

## Sims (1.2.0)

The addon's Sim page (Tooltips & Items) writes a request into `PhoenixUISimDB` in the same SavedVariables file:
your SimC profile as the addon exports it, the bag items you ticked, the mode (gear, compare, best set, stat
weights) and the fight. After a `/reload` the app sees it within 5 seconds and:

- **checks every line** (`sim.go`): only character, talent and item options SimC profiles contain are allowed, with
  bounded values; anything that could write files, read files or change the run (`html=`, `output=`,
  `json2=`, `save=`, `threads=`, includes, ...) is refused, and the item and set counts are capped;
- **plans the sim** (`simplan.go`): one baseline plus one SimC profileset per compared item (rings and trinkets
  in both slots, one-handers next to a two-hander handled), every combination for "best set" (capped at 400),
  `calculate_scale_factors` for weights;
- **runs simc** at below-normal priority with no window, all cores but two (`simThreads` in config.json), with a
  15 minute limit;
- **writes `Interface\AddOns\Phoenix_UI\Sim\Results.lua`** (the last 10 results per character, data only).
  The addon imports it on the next login or reload, keeps it in its saved data and shows DPS per set, the
  deltas, the sim time, stat weights, a tooltip line and the bag upgrade arrows. Updating the addon replaces that
  file with an empty one, so let the game import a finished sim (one reload) before you update.

Measured on a 28 thread PC (SimC 1210-01, Midnight 12.1.5 profile): a gear sim takes 0.5 s on Patchwerk and
2.9 s on a dungeon slice; comparing six items 2.4 s and 17.9 s; stat weights 2.4 s on Patchwerk.

### Getting SimulationCraft: only with your consent, verified

SimulationCraft (GPL-3.0) is **not bundled**. The first time a sim is requested the app asks, in a Windows dialog
with "No" as the default, whether it may download the pinned build (size, version, source and folder are shown).
Nothing is downloaded before you press Yes; No is remembered (the addon shows "declined") until you choose
**Download SimulationCraft...** in the tray menu. A new pinned version asks again. `--allow-simc-download` is the
same Yes for unattended use.

The download comes from `downloads.simulationcraft.org`, the SimulationCraft team's own nightly server. That
server only works over plain HTTP and the team publishes no checksums or signatures, and `simc.exe` is not signed.
So the trust anchor is GitHub: SimulationCraft's official build workflow (`simulationcraft/simc-publish`,
"Nightly") uploads every build as an Actions artifact and GitHub records the artifact's SHA-256 digest.
`tools/simc/pin.py` downloads that artifact, checks GitHub's digest, hashes the `.7z` inside it and the `simc.exe`
inside that, and writes them into `simc.json` together with the artifact ID and digest. The app (`simc.go`):

- reads the newest `simc.json` from this repository over HTTPS (falling back to the copy built into the exe),
- downloads to a temporary file, refuses it unless **size and SHA-256 match the pin**, unpacks only `simc.exe`
  and the license, checks the exe's **size and SHA-256** too, and only then moves it into place;
- follows redirects only to the SimulationCraft hosts, never runs anything it did not verify, and re-checks the
  exe's hash before every run.

It is stored in `%LOCALAPPDATA%\Phoenix UI Uploader\simc\<version>\` (with its license as `COPYING.txt`). **Remove
SimulationCraft** in the tray (or `--remove-simc`) deletes it and forgets the answer. `--simc <path>` (or `simcPath`)
uses your own simc.exe instead; then no download happens and the pin does not apply.

Limits worth knowing: a pin goes stale when the SimC team re-uploads a nightly with the same version (the hash no
longer matches, so the app refuses it and the Sim page shows the error until the pin is refreshed with
`tools/simc/pin.py`); `tools/simc/pin.py --check` confirms the pinned artifact is unchanged.

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
  --no-sim              ignore sim requests (config: "simDisabled": true)
  --allow-simc-download agree to download the verified SimulationCraft build without the dialog
  --simc <path>         use your own simc.exe (no download)
  --remove-simc         delete the downloaded SimulationCraft and forget the download answer
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
`dist/SHA256SUMS` lists the hashes. Attach `PhoenixUploader.exe` to each GitHub release under that exact name.
The website links to the tagged asset, `releases/download/<tag>/PhoenixUploader.exe` (GitHub's `releases/latest`
skips pre-releases), so bump `PHOENIX_UPLOADER_TAG` in the site's `components/phoenix/data.ts` with each release.

## Test

`go test ./...` covers the sim side too: the embedded pin and its refusals, profile checking, compare and best
set plans, reading SimC's JSON (real, trimmed reports in `testdata/`), the results writer, reading requests, a
download from a fake server into a temporary data folder (good file, wrong hash, wrong size, bad paths) and a full
run with a fake simc. Two fixtures are shared with the addon's smoke test so both sides agree on the file format:
`testdata/sim_request.lua` is written by the addon's real export code (`PHOENIX_UPDATE_FIXTURES=1 lua5.1
tools/smoke/harness.lua .`) and `testdata/sim_results.lua` by the Go writer (`UPDATE_FIXTURES=1 go test ./...`).

It also covers the parser (escapes, long strings, comments, refusals, depth limit), reading the sample
file in `testdata/`, the sent-state rules, batching, the endpoint policy, folder detection, and a full cycle
against a fake server (send, re-run sends nothing, a grown count is re-sent, a refused key surfaces).

## Third-party code

The exe links these Go modules (licenses in each module): `fyne.io/systray` (Apache-2.0), `golang.org/x/sys`
and `golang.org/x/text` (BSD-3-Clause), `github.com/bodgit/sevenzip`, `bodgit/plumbing`, `bodgit/windows`
(BSD-3-Clause, reading SimulationCraft's .7z), `github.com/ulikunitz/xz`, `github.com/pierrec/lz4/v4`,
`github.com/klauspost/compress` (BSD-3-Clause), `github.com/andybalholm/brotli`, `github.com/stangelandcl/ppmd`
(MIT), `github.com/spf13/afero`, `go4.org` (Apache-2.0) and `github.com/hashicorp/golang-lru/v2` (MPL-2.0,
unmodified; source at https://github.com/hashicorp/golang-lru). SimulationCraft itself is downloaded separately
(see above) and is GPL-3.0; its license is kept next to it as `COPYING.txt`.
