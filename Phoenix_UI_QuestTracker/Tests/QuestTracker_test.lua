local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Quest Tracker.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local QT = ns.QT

local function enable(t, ...)
  local keys = { "module.QuestTracker", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain(); wipe(H.quests); wipe(H.questLog) end)
  Schema:Set("module.QuestTracker", true)
end
local function seed()
  H.quests[1] = { id = 10, title = "Bravo", level = 80, dist = 400, objectives = { { text = "0/5 Bones", finished = false } } }
  H.quests[2] = { id = 11, title = "Alpha", level = 78, dist = 100, done = true }
  H.quests[3] = { id = 12, title = "Charlie", level = 80, dist = 900, world = true }
  H.questLog[1] = { isHeader = true, title = "Dornogal" }
  H.questLog[2] = { questID = 10 }
  H.questLog[3] = { questID = 11 }
  H.questLog[4] = { isHeader = true, title = "Isle of Dorn" }
  H.questLog[5] = { questID = 12 }
end

Tests:Add("QuestTracker", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.QuestTracker").default, false, "module defaults off")
  for key, def in pairs(QT.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.QuestTracker") then t:eq(QT.frame, nil, "no tracker frame while off") end
end)

Tests:Add("QuestTracker", "sorting, sections, filter and collapse", function(t)
  if not H then return end
  seed()
  enable(t, "qt.sort", "qt.filter", "qt.collapsed")
  local secs = QT.Sections(QT.Collect())
  t:same({ secs[1].name, secs[2].name }, { "Dornogal", "Isle of Dorn" }, "zone sections")
  t:same({ secs[1].quests[1].title, secs[1].quests[2].title }, { "Alpha", "Bravo" }, "titles sorted in a section")
  Schema:Set("qt.sort", "distance")
  t:ok(Ticker:IsRegistered("qt.distance"), "distance sort refreshes on the ticker")
  t:eq(QT.Sections(QT.Collect())[1].quests[1].id, 11, "nearest first")
  Schema:Set("qt.sort", "type")
  t:eq(Ticker:IsRegistered("qt.distance"), false, "ticker gone for other sorts")
  t:eq(QT.Sections(QT.Collect())[1].name, "Quests", "type sections")
  Schema:Set("qt.filter", "ready")
  t:eq(#QT.Collect(), 1, "ready filter")
  Schema:Set("qt.filter", "all")
  Schema:Set("qt.sort", "zone")
  local rows = QT.count
  Schema:Set("qt.collapsed", { Dornogal = true })
  t:ok(QT.count < rows, "collapsed section hides its quests")
end)

Tests:Add("QuestTracker", "Blizzard tracker adds no modules and comes back; auto quest respects settings", function(t)
  if not H then return end
  enable(t, "qt.autoQuest")
  CQ.Drain()
  t:eq(H.trackerModules, false, "SetCanAddModules(false) while Phoenix's tracker runs")
  t:eq(ObjectiveTrackerFrame:IsShown(), true, "Blizzard's frame is not hidden or disabled (G39)")
  wipe(H.calls)
  H.fire("QUEST_DETAIL")
  t:eq(#H.calls, 0, "no auto accept while off")
  Schema:Set("qt.autoQuest", true)
  H.fire("QUEST_DETAIL")
  t:eq(H.calls[1][1], "AcceptQuest", "auto accept")
  Schema:Set("module.QuestTracker", false)
  CQ.Drain()
  t:eq(H.trackerModules, true, "Blizzard tracker back")
  t:eq(QT.frame:IsShown(), false, "Phoenix tracker hidden")
end)

-- Step 8c ------------------------------------------------------------------------
Tests:Add("QuestTracker", "/way parsing, waypoint and super tracking (owner)", function(t)
  if not H then return end
  seed()
  enable(t, "qt.clickAction")
  t:cleanup(function() H.waypoint = nil; H.superTracked = {}; QT.waypoint = nil end)
  local m, x, y, name = QT.ParseWay("#2339 45.2, 61.8 Bank", 1)
  t:same({ m, x, y, name }, { 2339, 45.2, 61.8, "Bank" }, "map, coordinates and name")
  t:eq(QT.ParseWay("120 5", 1), nil, "coordinates over 100 refused")
  t:eq(select(1, QT.ParseWay("50 50", 2339)), 2339, "current map by default")
  QT.Way("50 40 Anvil")
  t:ok(H.waypoint and H.waypoint.position.x == 0.5 and H.waypoint.position.y == 0.4, "user waypoint placed")
  t:eq(H.superTracked.waypoint, true, "waypoint super tracked")
  t:ok(QT.text[QT.rows[1]]:GetText():find("Waypoint", 1, true), "waypoint line at the top")
  QT.OnClick(QT.rows[1], "LeftButton")
  t:eq(H.waypoint, nil, "clicking the line clears it")
  -- quest click super tracks
  local questRow
  for _, r in ipairs(QT.rows) do if QT.rowData[r] and QT.rowData[r].quest == 10 then questRow = r; break end end
  QT.OnClick(questRow, "LeftButton")
  t:eq(H.superTracked.quest, 10, "left-click super tracks the quest")
  t:ok(QT.text[questRow]:GetText():find("^> "), "super tracked quest is marked")
end)

Tests:Add("QuestTracker", "conflict notices: Kaliel's Tracker (module), TomTom and Questie (soft)", function(t)
  if not H then return end
  enable(t, "core.coexist.questtracker", "core.coexist.qt.waypoints", "core.coexist.qt.questie")
  H.addonLoaded["!KalielsTracker"] = true
  t:cleanup(function() QT.ClearWaypoint(); H.addonLoaded["!KalielsTracker"] = nil; H.addonLoaded.TomTom = nil; H.addonLoaded.Questie = nil; PUI.Kernel:Evaluate("QuestTracker") end)
  PUI.Kernel:Evaluate("QuestTracker")
  t:eq(QT.active, false, "dormant until the user picks")
  PUI.Coexist:Pick("questtracker", "phoenix")
  t:eq(QT.active, true, "Phoenix keeps the tracker")
  H.addonLoaded.TomTom = true
  local before = #H.disabled
  QT.Way("10 10")
  t:eq(H.waypoint, nil, "TomTom keeps /way until the user picks")
  PUI.Coexist:Pick("qt.waypoints", "phoenix")
  t:eq(#H.disabled, before, "a soft pick never turns the other addon off")
  QT.Way("10 10")
  t:ok(H.waypoint ~= nil, "Phoenix /way after the pick")
  H.waypoint = nil
  H.addonLoaded.Questie = true
  QT.Refresh()
  t:eq(QT.frame:IsShown(), false, "Questie's tracker kept: Phoenix tracker stays quiet")
  PUI.Coexist:Pick("qt.questie", "phoenix")
  QT.Refresh()
  t:eq(QT.frame:IsShown(), true, "shown again after the pick")
end)

Tests:Add("QuestTracker", "looks, progress colours, finished quests, sounds and announcements", function(t)
  if not H then return end
  seed()
  enable(t, "qt.completed", "qt.showLevel", "qt.announce", "announce.enabled", "announce.where", "qt.width")
  local r1, g1 = QT.ProgressColor("1/5")
  local r2, g2 = QT.ProgressColor("5/5")
  t:ok(r1 > r2 and g2 >= g1, "red to green as the count fills")
  Schema:Set("qt.showLevel", true)
  local found
  for _, r in ipairs(QT.rows) do if r:IsShown() and QT.text[r]:GetText():find("[80] Bravo", 1, true) then found = true end end
  t:ok(found, "quest level before the title")
  Schema:Set("qt.width", 300)
  t:eq(QT.frame:GetWidth(), 300, "width applies live")
  local n = QT.count
  Schema:Set("qt.completed", "hide")
  t:ok(QT.count < n, "finished quests hidden")
  -- announce progress through the router
  Schema:Set("announce.enabled", true)
  local where = Schema:Get("announce.where"); where.quest.world = true
  Schema:Set("announce.where", where)
  Schema:Set("qt.announce", true)
  QT.CheckCompletions()
  H.quests[1].objectives[1].text = "1/5 Bones"
  local log = #PUI.Announce.log
  QT.CheckCompletions()
  t:ok(#PUI.Announce.log > log, "objective progress announced (Only me by default)")
end)

Tests:Add("QuestTracker", "Ascent M+ block docks at the top; quests fold during the key", function(t)
  if not H or PUI.IS_FOREVER then return end
  seed()
  enable(t, "module.Ascent", "ascent.placement", "qt.collapseInKeys")
  t:cleanup(function() H.mplus = nil; H.fire("WORLD_STATE_TIMER_STOP") end)
  Schema:Set("module.Ascent", true)
  H.mplus = { mapID = 501, level = 12, limit = 1800, elapsed = 600, deaths = 0, lost = 0, forces = { 40, 100, "40%" } }
  H.fire("CHALLENGE_MODE_START")
  local D = PUI.Ascent.Display
  t:eq(D.docked, true, "block docked in the tracker")
  t:ok(QT.BlockHeight() > 0, "tracker leaves room for the block")
  local y = QT.rows[1].point[5]
  t:ok(-y >= QT.BlockHeight(), "first line starts under the block")
  QT.Refresh()
  t:ok(QT.text[QT.rows[1]]:GetText():find("^%+ "), "sections folded during the key")
  Schema:Set("ascent.placement", "standalone")
  t:eq(D.docked, false, "own window when chosen")
  t:eq(QT.BlockHeight(), 0, "tracker uses the full height again")
end)

Tests:Add("QuestTracker", "live preview follows the tracker settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = { Schema:Get("qt.completed"), Schema:Get("qt.mplusBlock") }
  t:cleanup(function() Schema:Set("qt.completed", saved[1]); Schema:Set("qt.mplusBlock", saved[2]) end)
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  Schema:Set("qt.completed", "glow")
  P.QuestTracker(card)
  local n = P.State(card).qtLines
  Schema:Set("qt.completed", "hide")
  Schema:Set("qt.mplusBlock", false)
  P.QuestTracker(card)
  t:eq(P.State(card).qtLines, n - 2, "finished quest and M+ line follow the settings")
end)
