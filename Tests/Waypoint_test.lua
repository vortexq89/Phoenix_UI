local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the waypoint arrow, /way and the spell queue window.
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema

Tests:Add("Waypoint", "arrow follows the user waypoint, counts yards on one Ticker entry and clears on arrival", function(t)
  if not H then return end
  local W = PUI.Waypoint
  t:cleanup(function() H.waypoint = nil; H.mapPos = nil; W.Sync() end)
  H.mapPos = { map = 2339, x = 0.5, y = 0.5, w = 1000, h = 1000, facing = 0 }
  H.waypoint = { uiMapID = 2339, position = { GetXY = function() return 0.5, 0.4 end } }
  H.fire("USER_WAYPOINT_UPDATED")
  t:ok(PUI.Ticker:IsRegistered("way.arrow"), "one Ticker entry while a waypoint exists")
  t:eq(W.frame.dist:GetText(), "100 yd", "distance in yards")
  local _, bearing = W.Vector(W.point)
  t:eq(math.floor(bearing * 100 + 0.5), 0, "point due north")
  H.mapPos.x = H.secret(0.5)
  W.Update()
  t:eq(W.frame.dist:GetText(), "?", "secret position never used for maths")
  H.mapPos.x = 0.5
  H.mapPos.y = 0.405
  W.Update()
  t:eq(H.waypoint, nil, "arrived: waypoint cleared")
  t:eq(PUI.Ticker:IsRegistered("way.arrow"), false, "Ticker entry gone")
end)

Tests:Add("Waypoint", "spell queue window goes through the CVar ledger and restores", function(t)
  if not H then return end
  local saved = Schema:Get("core.spellQueue")
  t:cleanup(function() Schema:Set("core.spellQueue", saved); PUI.CombatQueue.Drain() end)
  local had = H.cvars.SpellQueueWindow
  H.cvars.SpellQueueWindow = H.cvars.SpellQueueWindow or "400"
  t:cleanup(function() H.cvars.SpellQueueWindow = had end)
  local before = C_CVar.GetCVar("SpellQueueWindow")
  Schema:Set("core.spellQueue", 120); PUI.CombatQueue.Drain()
  t:eq(C_CVar.GetCVar("SpellQueueWindow"), "120", "set")
  Schema:Set("core.spellQueue", 0); PUI.CombatQueue.Drain()
  t:eq(C_CVar.GetCVar("SpellQueueWindow"), before, "restored")
end)
