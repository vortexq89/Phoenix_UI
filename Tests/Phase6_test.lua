local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Phase 6 core pieces: public API v2, data packs, locales.
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema

Tests:Add("API", "v2 registries: plugins, data blocks, vault rules, nicknames", function(t)
  t:eq(PUI.API_VERSION, 2, "API version 2")
  local Reg = PUI.APIRegistry
  t:cleanup(function()
    Reg.plugins.myplug = nil; Reg.dataBlocks.fps = nil; Reg.vaultRules.mats = nil; Reg.nicknames.nick = nil
    for i = #Reg.pluginOrder, 1, -1 do if Reg.pluginOrder[i] == "myplug" then table.remove(Reg.pluginOrder, i) end end
    Schema:UnregisterOwner("plugin:myplug")
  end)
  t:eq(select(2, PUI.API.RegisterPlugin("x", { label = "Profiles" })), "reserved label", "reserved label refused")
  t:eq(select(2, PUI.API.RegisterPlugin("myplug", { label = "My Plug", schema = { ["other.key"] = {} } })), "keys must start with plugin.myplug.", "foreign keys refused")
  local applied
  t:ok(PUI.API.RegisterPlugin("myplug", { label = "My Plug", schema = { ["plugin.myplug.size"] = { type = "range", default = 2, min = 1, max = 4, step = 1,
    label = "Size", tooltip = "Size.", apply = function(v) applied = v end } } }), "plugin registered")
  Schema:Set("plugin.myplug.size", 3)
  t:eq(applied, 3, "plugin setting applies live")
  t:ok(PUI.API.RegisterDataBlock("fps", { text = function() return "60" end }), "data block")
  t:ok(PUI.API.RegisterVaultRule("mats", { match = function() return true end }), "vault rule")
  t:ok(PUI.API.RegisterNicknameProvider("nick", function(n) if n == "Tester" then return "Boss" end end), "nickname provider")
  t:eq(PUI.API.Nickname("Tester"), "Boss", "nickname resolved")
  local prev, done = geterrorhandler(), false
  seterrorhandler(function() end)
  securecallfunction(function() PUI.API.RegisterDataBlock("bad id!", { text = function() end }); done = true end)
  seterrorhandler(prev)
  local ok = done
  t:eq(ok, false, "bad id rejected")
end)

Tests:Add("Packs", "packs are stamped; staleness against the client build", function(t)
  local P = PUI.Packs
  t:cleanup(function() P.list.testpack = nil end)
  P:Register("testpack", { packVersion = "2020-01-01", gameBuild = "11.0.0", data = {} })
  t:eq(P:IsStale("testpack"), not PUI.IS_FOREVER, "older major.minor is stale on retail")
  P:Register("testpack", { packVersion = "2026-10-26", gameBuild = "99.9.9", data = {} })
  t:eq(P:IsStale("testpack"), false, "current pack not stale")
end)

Tests:Add("Locale", "English is free; other languages load the locale child and fall back", function(t)
  if not H then return end
  local before = Schema:Get("core.locale")
  t:cleanup(function() Schema:Set("core.locale", before) end)
  Schema:Set("core.locale", "enUS")
  t:eq(PUI.L["Language"], "Language", "English passthrough")
  Schema:Set("core.locale", "deDE")
  t:ok(C_AddOns.IsAddOnLoaded("Phoenix_UI_Locales"), "locale child loaded for German")
  PUI.Locale:Add("deDE", { ["Language"] = "Sprache" })
  t:eq(PUI.L["Language"], "Sprache", "translated")
  t:eq(PUI.L["Untranslated thing"], "Untranslated thing", "fallback to English")
  t:ok(PUI.Locale.missing["Untranslated thing"], "missing key remembered")
  local keys = PUI.Locale:Harvest()
  t:ok(#keys > 100, "harvest finds the schema strings")
end)

Tests:Add("Entry", "game menu, compartment and minimap entry points", function(t)
  local E, Schema = PUI.Entry, PUI.Schema
  t:ok(type(_G.PhoenixUI_OnAddonCompartmentClick) == "function", "compartment function")
  t:ok(E.mini ~= nil, "minimap button built (default on)")
  Schema:Set("general.minimapAngle", { angle = 90 })
  t:eq(Schema:Get("general.minimapAngle").angle, 90, "angle stored")
  Schema:Set("general.minimapButton", false)
  t:eq(E.mini:IsShown(), false, "hidden live")
  Schema:Set("general.minimapButton", true)
  t:eq(E.mini:IsShown(), true, "shown live")
  t:eq(PUI.Ticker:IsRegistered("entry.minimapDrag"), false, "no ticker unless dragging")
end)
