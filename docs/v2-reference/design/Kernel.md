# Kernel (Phase 1) - design page

Scope: `Core/` of the parent addon `Phoenix_UI`. No visible UI in Phase 1 besides `/pui` chat output.
Spec references: PUI_V2 v7.4 Sections 3, 4, 5.1, 11, 20.2, Appendix A.

## Files and load order (`Phoenix_UI.toc`)
1. `Core/ClientGate.lua` - first file. Reads `GetBuildInfo()`; opens the gate for interface >= 120100 or Forever 16000-19999; sets `PUI.IS_FOREVER`, `PUI.IS_RETAIL`, `PUI.TOC`, `PUI.BUILD`. Closed gate: one chat line at login, every other file stops at its line-1 guard. Provides `CheckSerializable` (strings, finite numbers, booleans, string/number keys, no cycles, no secrets).
2. `Core/Secret.lua` - `IsSecret`, `ToText`, `Storable`, `SafeFormat`, `SafeAlpha`. Secrets become `<secret>`.
3. `Core/Kernel.lua` - namespaces (`PhoenixUI` is the only global table), signals, `PUI:Log`, `PUI:CreateFrame` (owner tag), module registry and lifecycle.
4. `Core/Schema.lua` - settings registry: `Register`, `Validate`, `Get`, `Set` (live: validate, store, `apply`, log), `ApplyAll`, `Snapshot`.
5. `Core/DB.lua` - `PhoenixUIDB`: `profiles`, `chars`, `migrations`. Defaults are read through, never copied; values equal to the default are stripped at logout. Migrations are idempotent, stamped on success, genesis-stamped on a fresh install. No timestamps/metadata keys.
6. `Core/Locale.lua`, `Core/CombatQueue.lua`, `Core/Ticker.lua`, `Core/Budget.lua`, `Core/API.lua`, `Core/Slash.lua`, `Core/SentinelHook.lua`.
7. `Data/ApiManifest.lua`, `Data/SchemaIndex.lua` (generated), `Tests/*`.

## Lifecycle (5.1)
| Moment | Work |
|---|---|
| main chunk | inert frames only (R-ZERO), schema registration |
| `ADDON_LOADED` (Phoenix_UI) | `DB:Init` (+ migrations) -> signal `DB_READY` (SentinelHook loads `Phoenix_UI_Sentinel`, which applies safe mode and runs drift/integrity) -> `Schema:ApplyAll` |
| `PLAYER_LOGIN` | signal `LOGIN`; every registered module evaluated in registration order |
| module registered after login | evaluated one frame later (`C_Timer.After(0)`) |
| `ZONE_CHANGED_NEW_AREA`, `GROUP_ROSTER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED` (retail) | registered only once a module has a `loadCondition`; re-evaluates all modules |
| `PLAYER_LOGOUT` | signal `LOGOUT`; `DB:Shutdown` strips defaults and checks serializability |

Module enabled = setting `module.<Name>` (default `enabledByDefault`) AND not in safe mode AND `loadCondition()` (if any). Each module gets one inert event frame; `mod:RegisterEvent` refuses while disabled; disabling unregisters events, handlers and the owner's tickers.

## States
| State | Meaning |
|---|---|
| registered | inert frame + schema keys only |
| enabled | `onEnable` ran; may own events/tickers |
| disabled | nothing registered |
| safe mode | forced disabled by Sentinel until released |
| combat | protected work only via `PUI.CombatQueue.Defer(key, fn)` |

## Combat queue and ticker
- `CombatQueue.Defer(key, fn)`: runs now out of combat; in combat keeps the newest fn per key and drains in first-queued order at `PLAYER_REGEN_ENABLED` (the only handler of that event in the addon; registered only while non-empty).
- `Ticker:Register(key, interval, fn, owner)`: interval > 0 = looping AnimationGroup; interval 0 = the single shared OnUpdate driver. `Ticker:Audit()` lists Phoenix frames with an unregistered OnUpdate.

## Settings (Simple / Advanced)
| Key | Default | Mode | Live apply |
|---|---|---|---|
| `core.profile` | `Default` (per character) | simple | switches profile and re-applies every key |
| `core.locale` | `auto` | simple | resolves locale, fires `LOCALE_CHANGED` |
| `core.debugRing` | off | advanced | prints ring events to chat |

Simple mode shows `core.profile` and `core.locale`; Advanced adds `core.debugRing`. The options renderer is a later phase; Phase 1 exposes the keys through `/pui list|get|set`.

## Mockup
No visual surface in Phase 1 (chat output only), so no image in `docs/design/img/`.
