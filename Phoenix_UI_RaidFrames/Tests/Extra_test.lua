local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test: pets, party targets, extra role frames and Grid Mode.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local RF = ns.RF

Tests:Add("RaidFrames", "pets, party targets and extra frames build out of combat with state drivers", function(t)
  Tests.Keep(t, "module.RaidFrames", "rf.pets", "rf.partyTargets", "rf.extraRole", "rf.gridMode")
  t:cleanup(function() CQ.Drain() end)
  Schema:Set("module.RaidFrames", true)
  Schema:Set("rf.pets", true); Schema:Set("rf.partyTargets", true); Schema:Set("rf.extraRole", "tank")
  CQ.Drain()
  local X = RF.Extra
  t:eq(#X.sets.pets, 5, "five pet frames")
  t:eq(#X.sets.targets, 4, "four party target frames")
  t:eq(H.stateDrivers[X.sets.pets[2]].visibility, "[@partypet1,exists] show; hide", "pet shown while it exists")
  t:eq(X.sets.targets[1]:GetAttribute("unit"), "party1target", "party target unit")
  t:ok(PUI.Ticker:IsRegistered("rf.partyTargets"), "target poll only while on")
  t:eq(X.header:GetAttribute("groupFilter"), "TANK", "extra header filters tanks")
  Schema:Set("rf.extraRole", "healer"); CQ.Drain()
  t:eq(X.header:GetAttribute("groupFilter"), "HEALER", "live switch to healers")
  Schema:Set("rf.partyTargets", false); CQ.Drain()
  t:ok(not PUI.Ticker:IsRegistered("rf.partyTargets"), "poll removed when off")
  t:eq(H.stateDrivers[X.sets.targets[1]].visibility, nil, "driver removed")
  Schema:Set("rf.gridMode", true)
  t:eq(RF.Spacing({ spacing = 2, groupSpacing = 6 }), -1, "Grid Mode: shared outline")
  CQ.Drain()
  local h = RF.headers.raid
  t:ok(math.abs(h:GetAttribute("yOffset")) == 1 or math.abs(h:GetAttribute("xOffset")) == 1, "headers re-laid live")
  t:eq(h:GetAttribute("columnSpacing"), 0, "no gap between groups")
end)
