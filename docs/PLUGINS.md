# Phoenix UI plugin API (version 1)

A plugin is a normal WoW addon with `## Dependencies: Phoenix_UI` that calls
`PhoenixUI.Plugins:Register(name, spec)` once at load. Phoenix gives it a
handle with only what a plugin needs; nothing else in `PhoenixUI` is public.
A working example lives in `examples/Phoenix_UI_PluginExample` (it is outside
the Phoenix_UI* install set, so it is never installed by default; copy the
folder to `Interface\AddOns` to try it).

## Register

```lua
local h = PhoenixUI.Plugins:Register("MyPlugin", {
  api = 1,                       -- plugin API version you were written for
  label = "My plugin",           -- shown on /pui -> Modules
  tooltip = "What it does.",
  enabledByDefault = false,
  schema = {                     -- keys must start with "plugin.MyPlugin."
    ["plugin.MyPlugin.size"] = { type = "range", min = 1, max = 10, step = 1, default = 4,
      label = "Size", tooltip = "...", mode = "simple", apply = function(v) end },
  },
  onEnable = function(h) end,    -- module turned on (login or live)
  onDisable = function(h) end,   -- module turned off; your Ticker jobs are already gone
})
```

Registration errors at load when the name is not letters/digits/_ (starting
with a letter), when `api` is newer than `PhoenixUI.Plugins.API`, when the
name is taken, or when a key is outside the plugin's prefix.

## Handle

| Call | What it does |
| --- | --- |
| `h:Key(suffix)` | `"plugin.<name>.<suffix>"` |
| `h:Get(key)` / `h:Set(key, v)` | read any setting / write your own settings only (applies live) |
| `h:Color(token)` | theme colour (`accent`, `surface.0-2`, `text`, `muted`, `line`, ...) |
| `h:Backdrop(frame, token)` | Phoenix backdrop on your frame |
| `h:Font(role)` | Phoenix font object (`small`, `body`, `large`, ...) |
| `h:Frame(type, name, parent)` | a frame owned by your plugin (CPU and errors attributed to it) |
| `h:Every(job, seconds, fn)` / `h:Stop(job)` | periodic work as a Ticker job `plugin.<name>.<job>` |
| `h:On(event, fn)` / `h:Off(event)` | game events on your module (registered only while enabled) |
| `h:Print(msg)` | chat line tagged with your plugin name |

## Rules (the same guardrails Phoenix follows)

- No `OnUpdate`: use `h:Every`. Phoenix's Ticker audit flags stray OnUpdate scripts.
- Every setting applies live: give each key an `apply` (a no-op one is added if missing).
- Secret values: pass them to widgets, never compare or do arithmetic on them.
- No `pcall` around your code: errors go to Sentinel under your addon's name, so
  players can report them to you.
- Taint: do not write into Blizzard tables or call protected functions in combat.

## Versioning

`PhoenixUI.Plugins.API` is 1. New handle calls are added without a version
bump; anything that changes or removes a call bumps the version, and a plugin
asking for a newer version than the installed Phoenix is refused with a clear
message at load.
