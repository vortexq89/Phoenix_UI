# Sentinel (Phase 1) - design page

Scope: `Core/SentinelHook.lua` (always loaded) + `Phoenix_UI_Sentinel/` (LoadOnDemand child, `PhoenixUISentinelDB`).
Spec references: PUI_V2 v7.4 Section 16 (16.3 in particular), 17.3 contract v2, Appendix A.
Out of scope for this page: Companion app, vq8s.com ingest/D1/admin pages, agent loop (later Phase 1 steps).

## Split
- **Hook (parent addon):** chains `seterrorhandler` at file load (keeps the previous handler - Blizzard's, BugSack's - and calls it after capture). If another grabber keeps the handler slot, uses BugGrabber's public `BugGrabber_BugGrabbed` callback. Only errors whose stack points into `AddOns/Phoenix_UI*` are recorded. Buffers up to 50 records until the child loads. Keeps the event ring (50, or 200 in tester mode). Owns the Sentinel settings.
- **Child:** loaded at `DB_READY` (before `PLAYER_LOGIN`) so safe mode and the drift check run before any module enables.

## Capture pipeline
error -> `BuildRecord` (every value through `PUI.Secret`: secrets become `<secret>`) -> owner module from stack path -> `Capture:Report(kind, module, fields)` -> dedupe hash = djb2(module | normalised stack | message without numbers) -> incident `{hash, kind, module, message, stack, locals, count, firstSeen, lastSeen, session, addonVersion, interface, build, locale, track, severity, context, extra}`.

Kinds: `error`, `secret` (Midnight signatures, plus last API family from the ring), `taint` (ADDON_ACTION_BLOCKED/FORBIDDEN for Phoenix addons), `integrity` (settings repaired to defaults with before/after; unknown keys kept), `drift` (API in `Data/ApiManifest.lua` missing; owner put in safe mode), `perf` (3 consecutive samples over budget), plus `heartbeat` and `test` records. Max 100 incidents (oldest dropped).

Context: class token, level, spec (retail), zone/instance type/difficulty, key level (retail), combat flag, group size, profile name + hash, the module's settings, loaded addons + versions (max 120), Phoenix CPU from `C_AddOnProfiler`, FPS, latency. Character name only with `sentinel.shareCharacterName`. Never chat text, other players' names, friends or addon messages.

## Behaviours
| Behaviour | Rule |
|---|---|
| Safe mode | with `sentinel.safeMode` on: a module with more than `sentinel.safeModeThreshold` errors last session is disabled at load; notice at login with "Re-enable"; Core/Sentinel are never disabled |
| Toast | first occurrence of a new incident only, when `sentinel.toast` is on; "Send report" (opted in) or "Details"; hides after 10 s |
| Export | `!PUI_SEN` + Base64(Deflate(contract v2 JSON)) via `C_EncodingUtil`; requires `sentinel.optIn` |
| Send now | requires opt-in; reloads the UI so SavedVariables reach disk for the Companion |
| Taint log | `sentinel.taintLogSession` sets CVar `taintLog=1`, restores the previous value at logout and resets the switch |
| Perf sampler | Ticker key `sentinel.perf`, 5 s (1 s tester mode), only while `sentinel.perfSampler` is on |
| Heartbeat | one record per session at logout (last 20 kept) |

## Panel (`/pui sentinel`)
Default geometry 620x470, centred, movable, closes with Esc. Surface #0E0E10 at 97%, 1 px line #2A2A2F, ember accent on the toast bar.
Rows: title; status line (incidents, occurrences, sharing, last report, capture mode); "what is collected" text; scrolling read-only box (incident list or export string); toggles row (Sharing, Taint log, Sampler, Safe mode - each label shows on/off); actions row (Incidents, Export string, Send now, Clear).
States: normal; disabled actions are explained in the box (e.g. export without opt-in); combat: panel stays usable (no protected calls).
Simple vs Advanced: Simple keys = `sentinel.optIn`, `sentinel.safeMode`, `sentinel.toast`; Advanced adds `shareCharacterName`, `testerMode`, `perfSampler`, `taintLogSession`, `safeModeThreshold`.

Subcommands: `/pui sentinel export|send|clear|induce|enable <module>`.

## Settings
| Key | Default | Mode |
|---|---|---|
| `sentinel.optIn` | off | simple |
| `sentinel.shareCharacterName` | off | advanced |
| `sentinel.testerMode` | off | advanced |
| `sentinel.safeMode` | off | simple |
| `sentinel.perfSampler` | off | advanced |
| `sentinel.taintLogSession` | off | advanced |
| `sentinel.safeModeThreshold` | 5 (1-50) | advanced |
| `sentinel.toast` | on (cosmetic) | simple |

## Mockup
Not yet produced (Canva/Figma export to `docs/design/img/` is pending the maintainer's design pass); the layout table above is the spec for Phase 1.

## Error reporter, diagnostics and profiler (step 9c)

- `Store.lua`: Phoenix incidents + other addons' errors (`db.others`, this PC only), sessions, sources, plain search, fingerprints, resolved states (`db.resolved`, persist).
- `Alerts.lua`: popup (Toast) + badge on; sound, chat line, auto-open off; per-signature throttle; BugSack picker `core.coexist.sentinel.display`.
- `Share.lua`: addon prefix `PUISEN`, whisper. Offer -> accept prompt -> chunks (220 bytes, 4 per second on one Ticker entry) -> checksum check.
- `Privacy.lua`: whole-word own name -> `[player]`, GUID kind only; applied to exports, shares and the outbox.
- `Upload.lua`: Preview text, status line, `db.outbox` written at logout and before Send now; the Companion uploads it as-is.
- `Reporter.lua`: the viewer window with Errors, Diagnostics and Profiler tabs.
- Safe mode is retired (hidden, inert); errors are never hidden.
- Core: `Core/Diag.lua` (`PUI.Diag`, `/pui diag`), `Core/Profiler.lua` (`PUI.Profiler`, `/pui profile`, zero cost while off).
