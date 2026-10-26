local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Nameplates. Tests that enable the module restore every
-- touched setting and the module toggle in cleanup.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local NP, P = ns.NP, ns.Plate

local function enable(t, ...)
  local keys = { "module.Nameplates", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.Nameplates", true)
end

Tests:Add("Nameplates", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.Nameplates").default, false, "module defaults off")
  if Schema:Get("module.Nameplates") then return end
  t:eq(NP.active, false, "inactive")
  t:eq(NP.module:RegisteredEventCount(), 0, "no module events")
  t:eq(next(NP.plates), nil, "no plates owned")
  t:eq(next(NP.cvarsSaved), nil, "no CVars touched")
end)

Tests:Add("Nameplates", "every setting has a schema entry with apply", function(t)
  local n = 0
  for key, def in pairs(NP.schema) do
    n = n + 1
    t:ok(Schema:Def(key) == def, key .. " registered")
    t:eq(type(def.apply), "function", key .. " apply")
  end
  t:ok(n >= 16, "keys registered (" .. n .. ")")
end)

Tests:Add("Nameplates", "plates are pooled over Blizzard's and released", function(t)
  if not H then return end
  enable(t)
  local plate = H.addPlate("nameplate1")
  t:cleanup(function() H.plates.nameplate1 = nil; H.units.nameplate1 = nil end)
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  local f = NP.plates.nameplate1
  t:ok(f and f:IsShown(), "Phoenix plate shown")
  t:eq(f:GetParent(), plate, "parented to the Blizzard plate")
  t:eq(plate.UnitFrame:GetAlpha(), 0, "Blizzard UnitFrame parked at alpha 0")
  t:ok(f.health:IsShown(), "enemy plate shows health")
  H.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  t:eq(NP.plates.nameplate1, nil, "released")
  t:eq(plate.UnitFrame:GetAlpha(), 1, "Blizzard UnitFrame restored")
  t:ok(P.pool[#P.pool] == f, "frame back in the pool")
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
  t:ok(NP.plates.nameplate1 == f, "pooled frame reused")
end)

Tests:Add("Nameplates", "settings apply live and events follow settings", function(t)
  if not H then return end
  enable(t, "np.width", "np.castbar", "np.friendlyNameOnly", "np.execute", "np.threat")
  H.addPlate("nameplate2")
  H.friendly.nameplate2 = true
  t:cleanup(function() H.plates.nameplate2 = nil; H.units.nameplate2 = nil; H.friendly.nameplate2 = nil end)
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
  local f = NP.plates.nameplate2
  t:eq(f.nameOnly, true, "friendly plate is name-only")
  Schema:Set("np.friendlyNameOnly", false)
  t:eq(f.nameOnly, false, "name-only off live")
  Schema:Set("np.width", 200)
  t:eq(f:GetWidth(), 200, "width applied live")
  Schema:Set("np.execute", 20)
  t:ok(f.execute:IsShown(), "execute marker shown")
  t:ok(NP.module.frame and true, "module frame")
  Schema:Set("np.castbar", false)
  local events = 0
  for ev in pairs(NP.WantedEvents()) do if ev:find("SPELLCAST") then events = events + 1 end end
  t:eq(events, 0, "no cast events without cast bars")
  Schema:Set("np.threat", false)
  t:eq(NP.WantedEvents().UNIT_THREAT_LIST_UPDATE, nil, "no threat events without threat colours")
end)

Tests:Add("Nameplates", "threat colours by role", function(t)
  t:eq(P.THREAT.tank[3], "success", "tank holding aggro is good")
  t:eq(P.THREAT.other[3], "danger", "dps holding aggro is bad")
  if not H then return end
  H.threat = 3
  t:cleanup(function() H.threat = 0 end)
  t:eq(P.ThreatToken("target", "TANK"), "success", "tank token")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  t:eq(P.ThreatToken("target", "TANK"), nil, "secret threat is never compared")
end)

Tests:Add("Nameplates", "secret values only reach widgets", function(t)
  if not H then return end
  enable(t, "np.healthText", "np.colorMode")
  H.addPlate("nameplate3")
  t:cleanup(function() H.plates.nameplate3 = nil; H.units.nameplate3 = nil end)
  H.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
  H.secretMode, H.casting = true, true
  t:cleanup(function() H.secretMode, H.casting = false, false end)
  Schema:Set("np.healthText", "percent")
  for _, mode in ipairs({ "reaction", "class" }) do
    Schema:Set("np.colorMode", mode)
    P.UpdateAll(NP.plates.nameplate3, NP.settings)
  end
  t:ok(NP.plates.nameplate3.cast:IsShown(), "cast bar from a duration object")
end)

Tests:Add("Nameplates", "CVars are written out of combat and restored on disable", function(t)
  if not H then return end
  local before = H.cvars.nameplateMotion
  t:cleanup(function() H.cvars.nameplateMotion = before end)
  H.cvars.nameplateMotion = "0"
  enable(t, "np.stacking")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  Schema:Set("np.stacking", "stacked")
  t:eq(H.cvars.nameplateMotion, "0", "unchanged in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(H.cvars.nameplateMotion, "1", "stacked after combat")
  Schema:Set("module.Nameplates", false)
  t:eq(H.cvars.nameplateMotion, "0", "original value restored")
end)
