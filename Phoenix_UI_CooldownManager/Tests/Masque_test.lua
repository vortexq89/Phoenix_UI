local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for PUI.Masque (optional Masque support).
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local M = PUI.Masque

local function fakeMasque(t)
  local groups = {}
  local lib = { Group = function(_, addon, name)
    local g = groups[name] or { addon = addon, buttons = {} }
    function g.AddButton(self, b, regions) self.buttons[b] = regions end
    function g.RemoveButton(self, b) self.buttons[b] = nil end
    groups[name] = g
    return g
  end }
  rawset(_G, "LibStub", { GetLibrary = function(_, n) if n == "Masque" then return lib end end })
  t:cleanup(function()
    for b, m in pairs(M.members) do m.group:RemoveButton(b); M.members[b] = nil; if rawget(b, "puiMasque") ~= nil then b.puiMasque = false end end
    wipe(M.groups)
    rawset(_G, "LibStub", nil)
  end)
  return groups
end

Tests:Add("Masque", "without Masque every call is a no-op", function(t)
  t:eq(M.Available(), false, "not loaded")
  local f = CreateFrame("Frame")
  t:eq(M.Add("ab", "Action bar 1", f), false, "nothing joined")
  t:eq(M.Skinned(f), false, "not skinned")
end)

Tests:Add("Masque", "action bars, special bars, auto item bars and CDM icons join their groups; toggles apply live", function(t)
  if not H then return end
  local groups = fakeMasque(t)
  local keys = { "module.ActionBars", "masque.ab", "masque.items" }
  local saved = {}
  for i, k in ipairs(keys) do saved[i] = Schema:Get(k) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.ActionBars", true); CQ.Drain()
  local AB = PUI.ActionBars
  AB.ApplyAll(); CQ.Drain()
  local g = groups["Action bar 1"]
  t:ok(g ~= nil, "Action bar 1 group")
  local b = AB.bars[1].buttons[1]
  t:ok(g and g.buttons[b] ~= nil, "button 1 in the group")
  t:ok(g and g.buttons[b] and g.buttons[b].Icon == b.icon, "icon region passed")
  t:eq(b.edges[1]:IsShown(), false, "Phoenix border hidden under Masque")
  t:ok(groups["Pet bar"] ~= nil, "special bar group")
  Schema:Set("masque.ab", false); CQ.Drain()
  t:eq(g.buttons[b], nil, "toggle off removes the button")
  t:eq(b.puiMasque, false, "back to Phoenix look")
  local f = CreateFrame("Frame")
  f.Icon = f:CreateTexture()
  PUI.CooldownManager.Skin(f, false)
  t:ok(groups["Cooldown Manager"] and groups["Cooldown Manager"].buttons[f] ~= nil, "CDM icon joins its group")
  t:eq(rawget(f, "puiMasque"), nil, "no field written on a viewer frame")
end)
