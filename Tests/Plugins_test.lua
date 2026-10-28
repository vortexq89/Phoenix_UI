local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the public plugin API (Core/Plugins.lua).
local Tests, Plugins, Schema = PUI.Tests, PUI.Plugins, PUI.Schema

Tests:Add("Plugins", "register checks name, API version and key prefix", function(t)
  t:throws(function() Plugins:Register("1bad", {}) end, "bad name")
  t:throws(function() Plugins:Register("PUITestFuture", { api = Plugins.API + 1 }) end, "newer API refused")
  t:throws(function() Plugins:Register("PUITestKeys", { schema = { ["core.x"] = { type = "toggle", default = true } } }) end, "key outside prefix")
end)

Tests:Add("Plugins", "a plugin gets a module, live settings and owned Ticker jobs", function(t)
  local enabled, seen = 0, nil
  local h = Plugins:Get("PUITestPlug") or Plugins:Register("PUITestPlug", {
    api = 1, label = "Test plugin",
    schema = { ["plugin.PUITestPlug.size"] = { type = "range", min = 1, max = 9, step = 1, default = 3, label = "Size", tooltip = "Size.",
      apply = function(v) seen = v end } },
    onEnable = function() enabled = enabled + 1 end,
  })
  t:cleanup(function() Schema:Set("module.Plugin:PUITestPlug", false); PUI.Ticker:UnregisterOwner("Plugin:PUITestPlug") end)
  t:eq(h.module.name, "Plugin:PUITestPlug", "prefixed module")
  Schema:Set("plugin.PUITestPlug.size", 5)
  t:eq(seen, 5, "applies live")
  t:eq(h:Get("plugin.PUITestPlug.size"), 5, "reads current value")
  t:throws(function() h:Set("core.locale", "enUS") end, "cannot set other keys")
  h:Every("tick", 1, function() end)
  t:ok(PUI.Ticker:IsRegistered("plugin.PUITestPlug.tick"), "ticker job under the plugin prefix")
  t:eq(PUI.Ticker.entries["plugin.PUITestPlug.tick"].owner, "Plugin:PUITestPlug", "owned by the plugin")
  t:ok(h:Color("accent") ~= nil, "theme tokens")
  t:throws(function() Plugins:Register("PUITestPlug", {}) end, "no duplicate")
end)
