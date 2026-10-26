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

Tests:Add("QuestTracker", "blizzard tracker hidden and restored; auto quest respects settings", function(t)
  if not H then return end
  enable(t, "qt.autoQuest")
  CQ.Drain()
  t:eq(ObjectiveTrackerFrame:IsShown(), false, "Blizzard tracker hidden")
  wipe(H.calls)
  H.fire("QUEST_DETAIL")
  t:eq(#H.calls, 0, "no auto accept while off")
  Schema:Set("qt.autoQuest", true)
  H.fire("QUEST_DETAIL")
  t:eq(H.calls[1][1], "AcceptQuest", "auto accept")
  Schema:Set("module.QuestTracker", false)
  CQ.Drain()
  t:eq(ObjectiveTrackerFrame:IsShown(), true, "Blizzard tracker back")
  t:eq(QT.frame:IsShown(), false, "Phoenix tracker hidden")
end)
