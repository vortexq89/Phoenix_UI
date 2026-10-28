local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Plugin API (public, versioned). A third-party addon that depends on
-- Phoenix_UI registers one plugin and gets a narrow handle instead of the
-- whole PUI table:
--   local P = PhoenixUI.Plugins:Register("MyPlugin", { api = 1, label = "My plugin", tooltip = "...",
--     enabledByDefault = false, schema = { ["plugin.MyPlugin.size"] = { type = "range", ... } },
--     onEnable = function(handle) end, onDisable = function(handle) end })
-- Rules the API enforces (the same guardrails Phoenix follows):
--  * Names are prefixed: the module is "Plugin:<name>", settings keys must
--    start with "plugin.<name>.", Ticker keys are "plugin.<name>.<job>".
--  * No OnUpdate: periodic work goes through handle:Every(), a Ticker job
--    owned by the plugin and dropped when it is disabled.
--  * Settings apply live: every schema key needs an apply function or gets a
--    no-op one, and handle:Get(key) reads the current value.
--  * No pcall: a plugin that errors is reported by Sentinel like any addon;
--    the plugin is never wrapped or silenced.
-- docs/PLUGINS.md is the reference.
local Plugins = { API = 1, list = {}, order = {} }
PUI.Plugins = Plugins

local NAME = "^[%a][%w_]*$"

local Handle = {}
Handle.__index = Handle
function Handle:Key(suffix) return "plugin." .. self.name .. "." .. suffix end
function Handle:Get(key) return PUI.Schema:Get(key) end
function Handle:Set(key, value) assert(key:find(self.prefix, 1, true) == 1, "plugin can only set its own keys"); PUI.Schema:Set(key, value) end
function Handle:Color(token) return PUI.Theme:Color(token) end
function Handle:Backdrop(frame, token) return PUI.Theme:Backdrop(frame, token or "surface.1") end
function Handle:Font(role) return PUI.Media:FontObject(role or "body") end
function Handle:Frame(kind, name, parent) return PUI:CreateFrame(kind or "Frame", name, parent or UIParent, nil, self.module.name) end
function Handle:Every(job, seconds, fn)
  assert(type(job) == "string" and job:find(NAME), "job name: letters, digits, _")
  PUI.Ticker:Register(self:Key(job), seconds, fn, self.module.name)
end
function Handle:Stop(job) PUI.Ticker:Unregister(self:Key(job)) end
function Handle:On(event, fn) self.module:RegisterEvent(event, fn) end
function Handle:Off(event) self.module:UnregisterEvent(event) end
function Handle:Print(msg) PUI.Slash.Print("[" .. self.name .. "] " .. tostring(msg)) end

-- Register(name, spec) -> handle. Errors (at load) on a bad name, an API
-- version newer than this Phoenix, a duplicate, or a key outside the prefix.
function Plugins:Register(name, spec)
  assert(type(name) == "string" and name:find(NAME), "plugin name: letters, digits, _ (starts with a letter)")
  assert(type(spec) == "table", "plugin spec table required")
  local api = spec.api or 1
  assert(type(api) == "number" and api <= self.API, "plugin " .. name .. " needs Phoenix plugin API " .. tostring(api) .. " (this build has " .. self.API .. ")")
  assert(not self.list[name], "plugin " .. name .. " already registered")
  local h = setmetatable({ name = name, api = api, prefix = "plugin." .. name .. "." }, Handle)
  local schema = {}
  for key, def in pairs(spec.schema or {}) do
    assert(type(key) == "string" and key:find(h.prefix, 1, true) == 1, "plugin key " .. tostring(key) .. " must start with " .. h.prefix)
    def.mode = def.mode or "advanced"
    def.apply = def.apply or function() end
    schema[key] = def
  end
  h.module = PUI:RegisterModule("Plugin:" .. name, {
    label = spec.label or name,
    tooltip = spec.tooltip or ("Third-party plugin " .. name .. "."),
    enabledByDefault = spec.enabledByDefault == true,
    schema = schema,
    onEnable = function() h.enabled = true; if spec.onEnable then spec.onEnable(h) end end,
    onDisable = function()
      h.enabled = false
      PUI.Ticker:UnregisterOwner(h.module.name)
      if spec.onDisable then spec.onDisable(h) end
    end,
  })
  self.list[name] = h
  self.order[#self.order + 1] = name
  return h
end
function Plugins:Get(name) return self.list[name] end
