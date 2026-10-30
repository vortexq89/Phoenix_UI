# Phoenix UI public plugin API (v1.0)

Third-party addons extend Phoenix through the global, read-only table `PhoenixUI` (Core/API.lua).
Phoenix's internals (`ns`) are private and may change; this API is the stable contract.

## Versioning
- `PhoenixUI.API_MAJOR` / `API_MINOR` — major bumps break compatibility, minor bumps only add.
- `PhoenixUI:GetVersion()` → addonVersion, major, minor.
- `PhoenixUI:Supports(major, minor)` → true when major matches and minor ≤ current. Check it before registering.
- Pass `apiMajor = 1` in your definition to fail loudly on a mismatched Phoenix.

## Setup
TOC: `## Dependencies: Phoenix_UI`. Name your folder `Phoenix_UI_<Name>` so the installer and plugin manager pick it up.

## Registration
`PhoenixUI:RegisterPlugin(key, def)` — key is `[%w_]+`, unique. `def`:
| field | meaning |
|---|---|
| label, desc, category, order, icon | plugin manager entry (category: system/interface/combat/social/utility) |
| defaults | saved settings; `enabled` controls the toggle |
| OnInitialize, OnEnable, OnDisable, Refresh | lifecycle; Refresh is called after every settings change (live, no /reload) |
| apiMajor | required major version |

Returns the module: `module.db`, `module:IsEnabled()`, `module:Refresh()`. Registering after login binds, initializes and enables immediately. `PhoenixUI:GetPlugin(key)` returns a registered plugin.

## Settings, movers, theme
- `RegisterSettings(key, rows)` — same row schema as Phoenix pages (header, toggle, range, select, color, texture, input, button, description); `key` is a dotted path into `module.db`.
- `RegisterMover(key, frame, label[, store])` — Layout-mode mover; Phoenix saves the position unless you pass a store `{get,set,apply,reset}`.
- `Color(token)`, `Font(role)`, `BarTexture()`, `CreateText(parent, role, token, justify)`, `StylePanel(frame, "base"|"raised"|"sunken")`, `OnTheme(frame, fn)` — Phoenix Font and theme, re-applied on theme change.

## Events and combat
- `On(event, owner, fn)`, `Off(event, owner)`, `Listen(message, owner, fn)`.
- `AfterCombat(key, fn, ...)` — runs now or after combat lockdown ends (deduplicated by key).
- `IsSecret(v)` — secret values must be passed to widgets (SetValue/SetText), never compared or computed with.
- `OpenSettings(key)`.

## Rules for plugins
No OnUpdate polling (use C_Timer), every setting applies live, and do not reach into `ns`.

## Sample
`docs/samples/Phoenix_UI_Hello/` — a themed movable panel with a settings page.
