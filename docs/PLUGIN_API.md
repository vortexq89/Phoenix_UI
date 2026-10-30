# Phoenix UI public plugin API (v1.2)

Third-party addons extend Phoenix through the global, read-only table `PhoenixUI` (Core/API.lua).
Phoenix's internals (`ns`) are private and may change; this API is the stable contract.

## Versioning
- `PhoenixUI.API_MAJOR` / `API_MINOR` — major bumps break compatibility, minor bumps only add.
- `PhoenixUI:GetVersion()` → addonVersion, major, minor.
- `PhoenixUI:Supports(major, minor)` → true when major matches and minor ≤ current. Check it before registering.
- Pass `apiMajor = 1` in your definition to fail loudly on a mismatched Phoenix.

## Setup
TOC: `## Dependencies: Phoenix_UI`, `## Interface: 120105` (retail) plus a `_Forever.toc` at 16001 (or one TOC with
`## Interface: 120105, 16001`). Phoenix does not scan folders: your plugin appears because it calls `RegisterPlugin`. Use a
vendor-prefixed folder such as `MyAddon_Phoenix`; `Phoenix_UI_<Key>` folders are Phoenix's own load-on-demand plugins.

## Registration
`PhoenixUI:RegisterPlugin(key, def)` — key is `Vendor_Name` (`[%w_]+` with an underscore), unique, not starting with
`Phoenix` and not a Phoenix plugin or reserved key (Raid, Cooldowns, Reminders, Toast, Quickdraw, Macros, MythicPlus ...). `def`:
| field | meaning |
|---|---|
| label, desc, category, order, icon | plugin manager entry (category: system/interface/combat/social/utility) |
| defaults | saved settings; `enabled` controls the toggle |
| OnInitialize, OnEnable, OnDisable, Refresh | lifecycle; Refresh is called after every settings change (live, no /reload) |
| apiMajor | required major version |

Returns the module: `module.db`, `module:IsEnabled()`, `module:Refresh()`. Registering after login binds, initializes and enables immediately. `PhoenixUI:GetPlugin(key)` returns a registered plugin.
`Refresh` is only called while the plugin is enabled. `PhoenixUI:GetState(key)` → state ("enabled", "disabled", "errored" …),
reason; `Listen("PUI_MODULE_STATE", ...)` to observe changes. An error in `OnInitialize` leaves the plugin "errored".

## Settings, movers, theme
- `RegisterSettings(key, rows)` — same row schema as Phoenix pages (header, toggle, range, select, color, texture, input, button, description); `key` is a dotted path into `module.db`.
- `RegisterMover(key, frame, label[, store])` — Layout-mode mover; Phoenix saves the position unless you pass a store `{get,set,apply,reset}`. Returns false when the Movers plugin is off.
- `Color(token)`, `Font(role)`, `BarTexture()`, `CreateText(parent, role, token, justify)`, `StylePanel(frame, "base"|"raised"|"sunken")`, `OnTheme(frame, fn)` — Phoenix Font and theme, re-applied on theme change.

## Art kit (1.1 / 1.2, THEME_API.md §7)
Baked textures only; never an effect token. Swap anything with a token layer:
- `OverrideArt(owner, tokens[, priority])` → handle `:Set(path, v)`, `:Clear(path)`, `:Remove()`. Paths: `background.image`,
  `logo.*`, `panel.alpha.*` (0.5–1), `icon.status.*`, `atlas.ui[.<piece>]`, `atlas.icons[.<key>]`, and v8.1 sheets
  `atlas.<portraits|actions|bars|frames|panels|modules>[.<piece>]` = `{ file =, coords = { l, r, t, b }, inset | left/right/top/bottom }`,
  `texture.barFill`, `texture.castFill`. Highest priority wins (default 100; ties: newest).
- `ArtToken(path)`, `PaintArt(texture, piece)`, `PaintIcon(texture, key)`, `RegisterIcon(key, { file, coords })`,
  `SetModuleIcon(moduleKey, iconKey)`.
- `DressArt(frame, slot[, opts])` (1.2): a v8.1 module slot over a frame, e.g. `"Toast.frame"`, `"Cooldowns.icon"`,
  `"Reminders.banner"`, `"MythicPlus.bar"`, `"Quickdraw.ring"`, `"Macros.panel"`; `opts.backdrop = true` adds the #0E0B0A 92%
  backdrop. `ArtEnabled()` (1.2) is true while the phoenix-wings look is on. Class, spec and ability icons are never repainted.

## Events and combat
- `On(event, owner, fn)` returns false (and keeps nothing) for an event the client does not know, `Off(event, owner)`, `Listen(message, owner, fn)`.
- `AfterCombat(key, fn, ...)` — runs now or after combat lockdown ends (deduplicated by key).
- `IsSecret(v)` — secret values must be passed to widgets (SetValue/SetText), never compared or computed with.
- `OpenSettings(key)`.

## Rules for plugins
No OnUpdate polling (use C_Timer), every setting applies live, and do not reach into `ns`.

## Sample
`docs/samples/Phoenix_UI_Hello/` — a themed movable panel with a settings page.
