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

-- Step 8c ------------------------------------------------------------------------
Tests:Add("Ascent", "pace line against each upgrade tier", function(t)
  local p = AS.Pace(900, 1800, 60)
  t:ok(math.abs(p[1] - 10) < 0.01, "+10% ahead of in-time pace")
  t:ok(p[3] < p[2] and p[2] < p[1], "+3 needs more than +2 than in time")
  t:eq(AS.Pace(nil, 1800, 50), nil, "no forces: no pace")
end)

Tests:Add("Ascent", "keystones: alts list, group share, !keys reply and auto-slot (owner)", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t)
  local saved = { Schema:Get("ascent.keys"), Schema:Get("ascent.autoSlot"), Schema:Get("ascent.keysReply") }
  t:cleanup(function()
    H.ownedKey, H.ownedKeyLevel, H.group, H.slotted = nil, nil, nil, nil; H.items = {}; H.addonMsgs = {}
    Schema:Set("ascent.keys", saved[1]); Schema:Set("ascent.autoSlot", saved[2]); Schema:Set("ascent.keysReply", saved[3])
  end)
  local K = AS.Keys
  Schema:Set("ascent.keys", { ["Alt - Realm"] = { mapID = 502, level = 9, class = "PRIEST" } })
  H.group = { "MAGE" }
  H.ownedKey, H.ownedKeyLevel = 501, 14
  t:eq(K.Scan(), true, "new key noticed")
  t:eq(H.addonMsgs[#H.addonMsgs][2], "K:501:14", "shared with the group on the hidden channel")
  K.OnAddonMessage(nil, nil, K.PREFIX, "K:503:11", nil, "Friend-Realm")
  K.OnAddonMessage(nil, nil, "OTHER", "K:1:1", nil, "Spam")
  local list = K.List()
  t:same({ list[1].kind, list[2].kind, list[3].kind, #list }, { "me", "alt", "group", 3 }, "you, then alts, then group")
  t:eq(list[3].who, "Friend", "realm trimmed")
  H.secretMode = true
  K.OnAddonMessage(nil, nil, K.PREFIX, H.secret("K:1:1"), nil, "X")
  H.secretMode = false
  t:eq(#K.List(), 3, "secret messages ignored")
  Schema:Set("ascent.keysReply", true)
  local spy = {}
  local send = PUI.Announce.Send
  PUI.Announce.Send = function(_, topic, msg) spy[#spy + 1] = { topic, msg } end
  t:cleanup(function() PUI.Announce.Send = send end)
  K.OnPartyChat(nil, nil, "!keys")
  K.OnPartyChat(nil, nil, "keys please")
  t:eq(#spy, 1, "only !keys answered")
  t:eq(spy[1][1], "keystone", "through the Keystones announce topic")
  Schema:Set("ascent.autoSlot", true)
  t:same({ K.Slot() }, { false, "no keystone in your bags" }, "explains why nothing was slotted")
  H.items["0:2"] = { itemID = 180653 }
  t:eq(K.Slot(), true, "found in the bags")
  PUI.CombatQueue.Drain()
  t:eq(H.slotted, true, "keystone slotted")
  t:same({ K.Slot() }, { false, "already slotted" }, "never twice")
end)

Tests:Add("Ascent", "battle res and Bloodlust widget; forces owner yields to MDT when asked", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t, "core.coexist.ascent.forcestips")
  local saved = Schema:Get("core.coexist.ascent.forcestips")
  t:cleanup(function() H.charges = nil; H.auras = {}; H.forces = {}; H.addonLoaded.MythicDungeonTools = nil; Schema:Set("core.coexist.ascent.forcestips", saved) end)
  H.charges = { 2, 5 }
  t:eq(AS.BattleRes().charges, 2, "pooled charges")
  t:eq(AS.Lust(), "ready", "no sated debuff")
  H.auras[57723] = { expirationTime = GetTime() + 300 }
  local state, left = AS.Lust()
  t:eq(state, "sated", "sated found")
  t:ok(left > 290, "time left")
  H.secretMode = true
  t:eq(AS.Lust(), "unknown", "hidden aura is not guessed")
  t:ok(AS.Display.BrLustText():find("BR", 1, true), "widget text from secret charges")
  H.secretMode = false
  H.mplus = { mapID = 501, level = 12, limit = 1800, elapsed = 0, deaths = 0, lost = 0, forces = { 0, 100, "0%" } }
  H.forces = { nameplate1 = { 4, 100, "4" } }
  t:eq(AS.UnitForces("nameplate1"), "4", "forces for tooltips and plates")
  H.addonLoaded.MythicDungeonTools = true
  t:eq(PUI.Coexist:Allows("ascent"), true, "MDT never turns Ascent off")
  PUI.Coexist:Pick("ascent.forcestips", "other")
  t:eq(AS.UnitForces("nameplate1"), nil, "MDT keeps the tooltip count when picked")
end)

Tests:Add("Ascent", "end-of-run summary card from Embers totals, auto-closes on the Ticker", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t)
  local saved = { Schema:Get("ascent.summary"), Schema:Get("ascent.summaryHide") }
  t:cleanup(function() Schema:Set("ascent.summary", saved[1]); Schema:Set("ascent.summaryHide", saved[2]); AS.Summary.Hide() end)
  H.meter.current = { max = 9000, total = 9000, duration = 30, rows = { { name = "Tester", class = "MAGE", amount = 9000, aps = 300, me = true } } }
  Schema:Set("ascent.summary", "popup")
  Schema:Set("ascent.summaryHide", 3)
  local run = { name = "Priory", level = 12, onTime = true, upgrades = 2, time = 1500, limit = 1800, deaths = 1 }
  t:eq(AS.Summary.Show(run), true, "card shown")
  t:ok(AS.Summary.data.header:find("timed +2", 1, true), "result in the header")
  t:ok(#AS.Summary.data.rows >= 1, "one row per player")
  for _ = 1, 4 do H.step(1) end
  t:eq(AS.Summary.frame:IsShown(), false, "closes by itself")
  t:eq(Ticker:IsRegistered("ascent.summary"), false, "and stops its job")
  Schema:Set("ascent.summary", "off")
  t:eq(AS.Summary.Show(run), false, "off means off")
end)

Tests:Add("Ascent", "live preview follows timer and widget settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = Schema:Get("ascent.pace")
  t:cleanup(function() Schema:Set("ascent.pace", saved) end)
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  Schema:Set("ascent.pace", true)
  P.Ascent(card)
  local n = P.State(card).ascentLines
  Schema:Set("ascent.pace", false)
  P.Ascent(card)
  t:eq(P.State(card).ascentLines, n - 1, "pace line follows the setting")
end)

Tests:Add("Ascent", "current pull forces, score projection and the vault planner", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t)
  local X = AS.Extras
  t:cleanup(function()
    for _, u in ipairs({ "nameplate1", "nameplate2", "nameplate3" }) do H.units[u] = nil; H.hostile[u] = nil; H.combatUnits[u] = nil; H.forces[u] = nil end
    H.mapBest = {}; H.runHistory = {}; H.vaultActs = nil
  end)
  H.mplus = { mapID = 501, level = 12, limit = 1800, elapsed = 600, deaths = 0, lost = 0, forces = { 40, 200, "20%" } }
  H.fire("CHALLENGE_MODE_START")
  for i, v in ipairs({ 6, 4, 9 }) do
    local u = "nameplate" .. i
    H.units[u], H.hostile[u], H.forces[u] = true, true, { v, 200, "" }
    H.combatUnits[u] = i < 3
  end
  local p = X.PullForces()
  t:eq(p.add, 5, "two engaged enemies: 10 of 200")
  t:eq(p.after, 25, "20% now, 25% after the pull")
  t:eq(X.PullText(p), "pull +5.0% -> 25.0%", "pull text")
  H.mapBest[501] = 300
  AS.Draw()
  t:ok(X.label:find("pull +5.0%", 1, true) and X.label:find("score: timed", 1, true), "forces line shows pull and projection")
  H.secretMode = true
  t:eq(X.PullForces(), nil, "secret values hide the pull preview")
  H.secretMode = false
  t:eq(X.Score(2, 1), 155, "+2 timed")
  t:eq(X.Score(12, 1), 365, "+12 timed: level and four breakpoints")
  t:eq(X.Score(12, 0.6), 380, "40% under adds the full time bonus")
  t:eq(X.Score(12, 1.5), 0, "far over time gives nothing")
  local proj = X.Projection(501, 12)
  t:same({ proj.timed, proj.best, proj.gain }, { 365, 300, 65 }, "projection against your best")
  Schema:Set("ascent.scoreProjection", false)
  Tests.Keep(t, "ascent.scoreProjection")
  AS.Draw()
  t:eq(X.label:find("score", 1, true), nil, "projection off live")
  H.vaultActs = { { index = 1, threshold = 1 }, { index = 2, threshold = 4 }, { index = 3, threshold = 8 } }
  H.runHistory = { { level = 10 }, { level = 12 }, { level = 8 }, { level = 11 } }
  local plan = X.VaultPlan()
  t:eq(plan[1].text, "Slot 1: unlocked at +12", "first slot from the best run")
  t:eq(plan[2].text, "Slot 2: unlocked at +8", "fourth best run")
  t:eq(plan[3].text, "Slot 3: 4 more runs (4 of 8)", "runs still needed")
end)
