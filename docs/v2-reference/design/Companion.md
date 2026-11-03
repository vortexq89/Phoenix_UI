# Sentinel Companion v1 (PUI_V2 16.4)

The Companion is Python 3.9+ and uses the stdlib only.

## Layout
- **Source:** `companion/sentinel_companion/`. Tests are in `companion/tests/`.
- **Build:** `python3 companion/build.py`. Add `--exe` to also build a PyInstaller one-file exe.

## Flow
1. **Watch:** poll the mtime of `WTF/Account/*/SavedVariables/Phoenix_UI_Sentinel.lua`. The client writes this file at reload and at logout.
2. **Parse:** read the file with `luasv.py`.
3. **Build:** produce the same contract v2 payload as `Export.lua`, with the same stable report ids. Nothing is built unless `optIn` is set in game.
4. **Attach the taint log:** for taint incidents, append the matching `Logs/taint.log` lines to `locals`.
5. **Redact:**
   - Strip user paths, emails, battletags and key/token/password values.
   - Remove the account folder name from every text field.
6. **Dedupe:** `state.json` maps report id to count. A report is re-sent only when its count grew.
7. **Upload:** `POST /phoenix/api/ingest` with `X-Phoenix-Key`, in batches of 100.
8. **Report back:** print the incident ids so the tester can quote them.

## Config
`%APPDATA%/PhoenixSentinel/config.json` holds `wowPath`, `endpoint`, `ingestKey` and `interval`. The key can also come from `PHOENIX_INGEST_KEY`. The key is never printed: `status` shows only `set` or `missing`.

## Commands
| Command | What it does |
|---|---|
| `watch` (default) | Watch the SavedVariables file and upload on change |
| `once` | Run one check and upload |
| `status` | Show the config and how many reports were already sent |
| `decode <!PUI_SEN>` | Decode an export string pasted from Discord or GitHub |
| `send-export <!PUI_SEN>` | Upload an export string |
| `--dry-run` | Build everything but send nothing |
