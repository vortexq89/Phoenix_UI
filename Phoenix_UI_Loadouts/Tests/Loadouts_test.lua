local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Loadouts.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local LO = ns.LO

local function enable(t, ...)
  local saved = { Schema:Get("module.Loadouts"), Schema:Get("loadouts.rules"), Schema:Get("loadouts.auto") }
  t:cleanup(function()
    Schema:Set("loadouts.auto", saved[3]); Schema:Set("loadouts.rules", saved[2]); Schema:Set("module.Loadouts", saved[1])
    H.instanceInfo = nil; H.specIndex = 1; H.config = 100; H.inCombat = false
    H.sets[1][2] = false; H.sets[2][2] = true
  end)
  Schema:Set("module.Loadouts", true)
end

Tests:Add("Loadouts", "off by default; content kinds", function(t)
  t:eq(Schema:Def("module.Loadouts").default, false, "module defaults off")
  t:eq(Schema:Def("loadouts.auto").default, false, "automatic switch off by default")
  for key, def in pairs(LO.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not H then return end
  H.instanceInfo = { "X", "party", 8 }
  t:eq(LO.Content(), "mythicplus", "keystone difficulty")
  H.instanceInfo = { "X", "party", 2 }
  t:eq(LO.Content(), "dungeon", "dungeon")
  H.instanceInfo = { "X", "raid", 16 }
  t:eq(LO.Content(), "raid", "raid")
  H.instanceInfo = nil
end)

Tests:Add("Loadouts", "save, detect difference, apply step by step out of combat", function(t)
  if not H then return end
  enable(t)
  Schema:Set("loadouts.rules", {})
  H.instanceInfo = { "X", "raid", 16 }
  H.specIndex, H.config = 2, 200
  H.sets[1][2], H.sets[2][2] = true, false
  LO.SaveRule("raid")
  H.specIndex, H.config = 1, 100
  H.sets[1][2], H.sets[2][2] = false, true
  local diff = LO.Check("raid")
  t:ok(diff and diff.spec == 2 and diff.config == 200 and diff.set == 1, "all three differ")
  wipe(H.calls)
  H.inCombat = true
  LO.Apply()
  t:eq(#H.calls, 0, "nothing in combat")
  H.inCombat = false
  CQ.Drain()
  t:eq(H.calls[1][1], "SetSpecialization", "spec first")
  H.fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  local names = {}
  for _, c in ipairs(H.calls) do names[#names + 1] = c[1] end
  t:eq(table.concat(names, ","), "SetSpecialization,LoadConfig,UseEquipmentSet", "then talents and gear")
  t:eq(LO.Check("raid"), nil, "now matches")
end)
