local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Quest Tracker (PUI_V2 5.10): a Phoenix tracker built from C_QuestLog, not a
-- reskin. Watched quests are grouped into sections by the chosen sort (zone,
-- level, distance, type), filtered (all / in progress / ready), and each
-- section remembers whether it is collapsed. Blizzard's objective tracker is
-- hidden out of combat while this is on and shown again when it is turned
-- off. Optional: zone auto-track, auto accept / turn-in (hold Shift to read),
-- completion sound, Ctrl-click for a Wowhead link. Off by default.
local _, ns = ...
local Schema, Layout, Slash, CQ, Ticker = PUI.Schema, PUI.Layout, PUI.Slash, PUI.CombatQueue, PUI.Ticker
local Theme, Media = PUI.Theme, PUI.Media
local OWNER = "QuestTracker"
local ROW_H, WIDTH = 16, 240

local QT = { active = false, rows = {}, complete = {}, hooked = false }
ns.QT = QT
PUI.QuestTracker = QT
local s = { sort = "zone", filter = "all", autoTrackZone = false, autoQuest = false, sound = true, hideBlizzard = true, collapsed = {} }
QT.settings = s

-- Data ------------------------------------------------------------------------
-- Zone (header) for every quest in the log, built from the header rows.
function QT.Headers()
  local map, header = {}, nil
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info then
      if info.isHeader then header = info.title elseif info.questID then map[info.questID] = header end
    end
  end
  return map
end

function QT.TypeOf(id)
  if C_QuestLog.IsWorldQuest(id) then return "World quests" end
  local tag = C_QuestLog.GetQuestTagInfo(id)
  if tag and tag.tagName then return tag.tagName end
  return "Quests"
end

function QT.Collect()
  local headers = QT.Headers()
  local list = {}
  for i = 1, C_QuestLog.GetNumQuestWatches() do
    local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
    if id then
      local done = C_QuestLog.IsComplete(id) or C_QuestLog.ReadyForTurnIn(id)
      local q = { id = id, title = C_QuestLog.GetTitleForQuestID(id) or ("Quest " .. id), done = done and true or false,
        objectives = C_QuestLog.GetQuestObjectives(id) or {}, level = C_QuestLog.GetQuestDifficultyLevel(id) or 0,
        zone = headers[id] or "Other" }
      local d = C_QuestLog.GetDistanceSqToQuest(id)
      q.dist = type(d) == "number" and d or math.huge
      if s.filter == "all" or (s.filter == "ready") == q.done then list[#list + 1] = q end
    end
  end
  return list
end

-- Groups quests into ordered sections for the current sort.
function QT.Sections(list)
  local keyOf, cmp
  if s.sort == "level" then
    keyOf = function(q) return "Level " .. q.level end
    cmp = function(a, b) return a.level < b.level end
  elseif s.sort == "distance" then
    keyOf = function() return "Nearest" end
    cmp = function(a, b) return a.dist < b.dist end
  elseif s.sort == "type" then
    keyOf = function(q) return QT.TypeOf(q.id) end
    cmp = function(a, b) return a.title < b.title end
  else
    keyOf = function(q) return q.zone end
    cmp = function(a, b) return a.title < b.title end
  end
  table.sort(list, function(a, b) if cmp(a, b) then return true elseif cmp(b, a) then return false end return a.id < b.id end)
  local sections, byName = {}, {}
  for _, q in ipairs(list) do
    local name = keyOf(q)
    local sec = byName[name]
    if not sec then sec = { name = name, quests = {} }; byName[name] = sec; sections[#sections + 1] = sec end
    sec.quests[#sec.quests + 1] = q
  end
  if s.sort == "level" then table.sort(sections, function(a, b) return a.quests[1].level < b.quests[1].level end) end
  return sections
end

-- Frame -----------------------------------------------------------------------
local function frame()
  local f = QT.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_QuestTracker", UIParent, nil, OWNER)
  f:SetSize(WIDTH, ROW_H)
  QT.frame = f
  Layout:Place(f, "qt.tracker")
  return f
end

local function row(i)
  local r = QT.rows[i]
  if r then return r end
  local f = frame()
  r = PUI:CreateFrame("Button", nil, f, nil, OWNER)
  r:SetSize(WIDTH, ROW_H)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  r:RegisterForClicks("LeftButtonUp")
  local t = r:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(Media:FontObject("body"))
  t:SetPoint("LEFT", 2, 0)
  t:SetPoint("RIGHT", -2, 0)
  t:SetJustifyH("LEFT")
  t:SetWordWrap(false)
  QT.text = QT.text or setmetatable({}, { __mode = "k" })
  QT.text[r] = t
  r:SetScript("OnClick", function(self) QT.OnClick(self) end)
  QT.rows[i] = r
  return r
end

QT.rowData = setmetatable({}, { __mode = "k" })
function QT.OnClick(r)
  local d = QT.rowData[r]
  if not d then return end
  if d.section then
    s.collapsed[d.section] = not s.collapsed[d.section] or nil
    Schema:Set("qt.collapsed", s.collapsed)
    QT.Refresh()
  elseif d.quest then
    if IsControlKeyDown() then QT.ShowLink(d.quest) return end
    if not InCombatLockdown() then QuestMapFrame_OpenToQuestDetails(d.quest) end
  end
end

function QT.Link(id) return "https://www.wowhead.com/quest=" .. id end
function QT.ShowLink(id)
  local box = QT.linkBox
  if not box then
    box = PUI:CreateFrame("EditBox", nil, UIParent, nil, OWNER)
    box:SetSize(320, 24)
    box:SetPoint("CENTER")
    box:SetAutoFocus(true)
    box:SetFontObject(Media:FontObject("body"))
    Theme:Backdrop(box, "surface.1")
    box:SetScript("OnEscapePressed", function(self) self:Hide() end)
    box:SetScript("OnEnterPressed", function(self) self:Hide() end)
    QT.linkBox = box
  end
  box:SetText(QT.Link(id))
  box:Show()
  box:HighlightText()
end

local function setRow(i, text, r, g, b, data)
  local rw = row(i)
  QT.text[rw]:SetText(text)
  QT.text[rw]:SetTextColor(r, g, b)
  QT.rowData[rw] = data
  rw:Show()
end

function QT.Refresh()
  if not QT.active then return end
  local n = 0
  for _, sec in ipairs(QT.Sections(QT.Collect())) do
    local collapsed = s.collapsed[sec.name]
    n = n + 1
    local ar, ag, ab = Theme:Color("accent")
    setRow(n, (collapsed and "+ " or "- ") .. sec.name .. " (" .. #sec.quests .. ")", ar, ag, ab, { section = sec.name })
    if not collapsed then
      for _, q in ipairs(sec.quests) do
        n = n + 1
        local r, g, b = 1, 0.82, 0
        if q.done then r, g, b = Theme:Color("success") end
        setRow(n, q.title, r, g, b, { quest = q.id })
        if not q.done then
          for _, o in ipairs(q.objectives) do
            if o.text and not o.finished then
              n = n + 1
              setRow(n, "   " .. o.text, 0.8, 0.8, 0.8, { quest = q.id })
            end
          end
        end
      end
    end
  end
  for i = n + 1, #QT.rows do QT.rows[i]:Hide(); QT.rowData[QT.rows[i]] = nil end
  frame():SetHeight(math.max(ROW_H, n * ROW_H))
  frame():Show()
  QT.count = n
end

-- Completion sound: a watched quest that just became ready.
function QT.CheckCompletions()
  for i = 1, C_QuestLog.GetNumQuestWatches() do
    local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
    if id then
      local done = C_QuestLog.IsComplete(id) and true or false
      if done and QT.complete[id] == false and s.sound then PUI.Media:Alert(SOUNDKIT.IG_QUEST_LIST_COMPLETE) end
      QT.complete[id] = done
    end
  end
end

-- Zone auto-track: watch quests filed under the current zone's header.
function QT.TrackZone()
  if not s.autoTrackZone then return end
  local zone = GetZoneText()
  for id, header in pairs(QT.Headers()) do
    if header == zone then C_QuestLog.AddQuestWatch(id) end
  end
end

-- Auto accept / turn-in, hold Shift to read the quest instead.
function QT.OnQuestDetail() if s.autoQuest and not IsShiftKeyDown() then AcceptQuest() end end
function QT.OnQuestProgress() if s.autoQuest and not IsShiftKeyDown() and IsQuestCompletable() then CompleteQuest() end end
function QT.OnQuestComplete()
  if not s.autoQuest or IsShiftKeyDown() then return end
  local n = GetNumQuestChoices()
  if n == 0 then GetQuestReward() elseif n == 1 then GetQuestReward(1) end
end

-- Blizzard tracker visibility (out of combat only).
function QT.BlizzardTracker(show)
  local ot = rawget(_G, "ObjectiveTrackerFrame")
  if not ot then return end
  CQ.Defer("qt.blizzard", function()
    if show then ot:SetAlpha(1); ot:Show() else ot:Hide() end
  end)
end
function QT.OnBlizzardShow()
  if QT.active and s.hideBlizzard then QT.BlizzardTracker(false) end
end

local function onEnable(mod)
  QT.active = true
  local refresh = function() QT.CheckCompletions(); QT.Refresh() end
  mod:RegisterEvent("QUEST_WATCH_LIST_CHANGED", refresh)
  mod:RegisterEvent("QUEST_LOG_UPDATE", refresh)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() QT.TrackZone(); QT.Refresh() end)
  mod:RegisterEvent("QUEST_DETAIL", QT.OnQuestDetail)
  mod:RegisterEvent("QUEST_PROGRESS", QT.OnQuestProgress)
  mod:RegisterEvent("QUEST_COMPLETE", QT.OnQuestComplete)
  local ot = rawget(_G, "ObjectiveTrackerFrame")
  if ot and not QT.hooked then QT.hooked = true; hooksecurefunc(ot, "Show", QT.OnBlizzardShow) end
  if s.hideBlizzard then QT.BlizzardTracker(false) end
  QT.Sync()
  QT.Refresh()
end

local function onDisable()
  QT.active = false
  if QT.frame then QT.frame:Hide() end
  if QT.linkBox then QT.linkBox:Hide() end
  QT.BlizzardTracker(true)
end

function QT.Sync()
  if QT.active and s.sort == "distance" then
    if not Ticker:IsRegistered("qt.distance") then Ticker:Register("qt.distance", 2, QT.Refresh, OWNER) end
  elseif Ticker:IsRegistered("qt.distance") then
    Ticker:Unregister("qt.distance")
  end
end

Layout:RegisterElement("qt.tracker", { label = "Quest tracker", owner = OWNER, size = { WIDTH, 200 }, default = { point = "RIGHT", x = -40, y = 120 } })

local schema = {}
QT.schema = schema
local function key(name, def, after)
  def.owner = OWNER
  def.apply = function(value)
    s[name] = value
    if after then after(value) end
    QT.Sync()
    QT.Refresh()
  end
  schema["qt." .. name] = def
end
key("sort", { type = "select", default = "zone", choices = { "zone", "level", "distance", "type" }, label = "Sort quests by",
  tooltip = "Groups and orders tracked quests by zone, level, distance or quest type.", mode = "simple" })
key("filter", { type = "select", default = "all", choices = { "all", "progress", "ready" }, label = "Show",
  tooltip = "All tracked quests, only those in progress, or only those ready to turn in.", mode = "simple" })
key("collapsed", { type = "layout", default = {}, mode = "advanced", label = "Collapsed sections", tooltip = "Sections you collapsed." })
key("autoTrackZone", { type = "toggle", default = false, label = "Track zone quests",
  tooltip = "Tracks quests for the zone you enter.", mode = "advanced" })
key("autoQuest", { type = "toggle", default = false, label = "Auto accept and turn in",
  tooltip = "Accepts and turns in quests with at most one reward choice. Hold Shift to read the quest.", mode = "advanced" })
key("sound", { type = "toggle", default = true, label = "Completion sound", tooltip = "Plays a sound when a tracked quest is ready.", mode = "advanced" })
key("hideBlizzard", { type = "toggle", default = true, label = "Hide Blizzard tracker",
  tooltip = "Hides the default objective tracker while this tracker is on.", mode = "advanced" },
  function(v) if QT.active then QT.BlizzardTracker(not v) end end)

QT.module = PUI:RegisterModule(OWNER, {
  label = "Quest Tracker", tooltip = "Phoenix quest tracker with sorting, filters, collapsible sections and quest automation.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
