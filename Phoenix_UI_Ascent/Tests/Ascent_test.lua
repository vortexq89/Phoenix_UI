local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Ascent.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, Ticker = PUI.Tests, PUI.Schema, PUI.Ticker
local AS = ns.AS

local function enable(t)
  local saved = { Schema:Get("module.Ascent"), Schema:Get("ascent.records"), Schema:Get("ascent.hideBlizzard") }
  t:cleanup(function()
    H.mplus = nil; H.completion = nil; H.secretMode = false
    Schema:Set("ascent.hideBlizzard", saved[3]); Schema:Set("ascent.records", saved[2]); Schema:Set("module.Ascent", saved[1])
  end)
  Schema:Set("module.Ascent", true)
end

Tests:Add("Ascent", "off by default; retail only; thresholds", function(t)
  t:eq(Schema:Def("module.Ascent").default, false, "module defaults off")
  for key, def in pairs(AS.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  t:eq(AS.Upgrades(1000, 1800), 3, "+3 under 60%")
  t:eq(AS.Upgrades(1300, 1800), 2, "+2 under 80%")
  t:eq(AS.Upgrades(1700, 1800), 1, "+1 in time")
  t:eq(AS.Upgrades(1900, 1800), 0, "over time")
  t:eq(AS.Clock(125), "2:05", "clock format")
  if PUI.IS_FOREVER and H then
    Schema:Set("module.Ascent", true)
    t:eq(AS.module.enabled, false, "never enables on Forever")
    Schema:Set("module.Ascent", false)
  end
end)

Tests:Add("Ascent", "run: timer resumes from world timer, forces secret-safe, splits, best run", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t)
  Schema:Set("ascent.records", {})
  Schema:Set("ascent.hideBlizzard", true)
  H.mplus = { mapID = 501, level = 12, limit = 1800, elapsed = 600, deaths = 2, lost = 10, forces = { 40, 100, "40%" } }
  H.fire("CHALLENGE_MODE_START")
  t:ok(Ticker:IsRegistered("ascent.timer"), "ticker while a key runs")
  t:eq(AS.frame.timer:GetText(), "10:00 / 30:00", "elapsed from the world timer")
  t:eq(ObjectiveTrackerFrame:GetAlpha(), 0, "Blizzard tracker faded")
  H.secretMode = true
  AS.Draw()
  t:ok(AS.frame.forces:IsShown(), "forces bar fed secret values")
  H.secretMode = false
  H.mplus.elapsed = 900
  H.fire("ENCOUNTER_END", 1, "Boss One", 8, 5, 1)
  t:eq(#AS.run.splits, 1, "boss split recorded")
  H.mplus.elapsed = 1500
  AS.Draw()
  t:ok(AS.run.warned[3], "+3 crossing warned once")
  H.completion = { time = 1500000, onTime = true, keystoneUpgradeLevels = 1, oldOverallDungeonScore = 2000, newOverallDungeonScore = 2050 }
  H.fire("CHALLENGE_MODE_COMPLETED")
  local best = AS.Best(501, 12)
  t:ok(best and best.time == 1500, "personal best stored")
  t:eq(AS.Leaderboard()[1].level, 12, "leaderboard lists it")
  H.mplus = nil
  H.fire("WORLD_STATE_TIMER_STOP")
  t:eq(Ticker:IsRegistered("ascent.timer"), false, "ticker gone after the key")
  t:eq(ObjectiveTrackerFrame:GetAlpha(), 1, "tracker restored")
end)
