local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Free party placement (deferred batch B).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Layout = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Layout
local RF = ns.RF
local M = RF.Members

Tests:Add("RaidFramesX", "party members placed one by one in Studio, header hidden, all live", function(t)
  if not H then return end
  local keys = { "module.RaidFrames", "rf.party.free", "rf.showPlayer" }
  local saved = {}
  for i, k in ipairs(keys) do saved[i] = Schema:Get(k) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.RaidFrames", true); CQ.Drain()
  t:eq(Schema:Def("rf.party.free").default, false, "off at first install")
  Schema:Set("rf.party.free", true); CQ.Drain()
  t:eq(#M.buttons, 5, "you and four party frames")
  local b2 = M.buttons[2]
  t:eq(b2:GetAttribute("unit"), "party1", "fixed unit")
  t:eq(b2:GetAttribute("*type1"), "target", "click targets")
  t:eq(Layout:Frame("rf.party.member2"), b2, "each one is a Studio element")
  t:eq(H.stateDrivers[b2].visibility, "[group:raid] hide; [@party1,exists] show; hide", "shown while that member exists")
  t:eq(H.stateDrivers[RF.headers.party].visibility, "hide", "party row hidden")
  t:ok(RF.byButton[b2] ~= nil, "same Phoenix elements as the row")
  Schema:Set("rf.showPlayer", false); CQ.Drain()
  t:eq(H.stateDrivers[M.buttons[1]].visibility, "hide", "show-player setting respected")
  Schema:Set("rf.party.free", false); CQ.Drain()
  t:eq(H.stateDrivers[b2].visibility, nil, "off: members released")
  t:ok(H.stateDrivers[RF.headers.party].visibility ~= "hide", "party row back")
end)
