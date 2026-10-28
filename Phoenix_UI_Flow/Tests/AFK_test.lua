local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the AFK screen (AFK.lua).
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local AFK = PUI.AFKScreen

Tests:Add("AFKScreen", "settings have labels, tooltips and live apply; clock text", function(t)
  for k in pairs(AFK.schema) do
    local d = Schema:Def(k)
    t:ok(d and type(d.apply) == "function" and d.label and d.tooltip, k)
  end
  t:eq(AFK.Clock(125), "2:05", "away timer")
end)

Tests:Add("AFKScreen", "shows when AFK, turns on one Ticker entry, leaves on movement and never in combat", function(t)
  if not H then return end
  local saved = Schema:Get("module.AFKScreen")
  t:cleanup(function() H.afk = nil; H.inCombat = false; AFK.Hide(); Schema:Set("module.AFKScreen", saved) end)
  Schema:Set("module.AFKScreen", true)
  H.afk = true
  H.fire("PLAYER_FLAGS_CHANGED", "player")
  t:eq(AFK.shown, true, "shown while AFK")
  t:ok(PUI.Ticker:IsRegistered("afk.screen"), "one Ticker entry")
  t:ok(AFK.frame.title:GetText() ~= nil, "name shown")
  Schema:Set("afk.dim", 0.5)
  H.fire("PLAYER_STARTED_MOVING")
  t:eq(AFK.shown, false, "movement removes it")
  t:eq(PUI.Ticker:IsRegistered("afk.screen"), false, "Ticker entry gone")
  H.inCombat = true
  AFK.Show()
  t:eq(AFK.shown, false, "never in combat")
end)
