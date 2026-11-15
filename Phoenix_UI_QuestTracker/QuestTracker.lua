local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Quest Tracker (plan 5.8, mockup 07). Blizzard's quest log stays the data
-- source (C_QuestLog; quest data is not secret in 12.1); Phoenix draws its own
-- restyled tracker. Blizzard's objective tracker is switched off only through
-- ObjectiveTrackerManager:SetCanAddModules(false) (restored on disable, G39;
-- never DisableAddOn), and Kaliel's Tracker goes through the conflict notice.
-- Owners (1.O): the tracker owns /way and super tracking (Flow links here) and
-- hosts Ascent's M+ block at its top while a key runs; the M+ timer itself is
-- Ascent's. Rows are pooled and grown on demand; one Ticker job only for the
-- distance sort. Every look and behaviour is a setting. Off by default.
local _, ns = ...
local Schema, Layout, CQ, Ticker, Secret = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker, PUI.Secret
local Theme, Media = PUI.Theme, PUI.Media
local OWNER = "QuestTracker"

local QT = { active = false, rows = {}, complete = {}, progress = {} }
ns.QT = QT
PUI.QuestTracker = QT
local s = {
  sort = "zone", filter = "all", autoTrackZone = false, autoQuest = false, sound = true, hideBlizzard = true, collapsed = {},
  width = 240, fontSize = 12, rowSpacing = 2, showLevel = false, completed = "glow", progressColors = true, bgAlpha = 0,
  collapseInCombat = false, collapseInKeys = true, mplusBlock = true, clickAction = "supertrack", objectiveSound = false,
  announce = false, skipTrivial = false, skipRepeatable = false, pauseKey = "SHIFT", waypointLine = true, opacity = 1,
}
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
      local keep = s.filter == "all" or (s.filter == "ready") == q.done
      if keep and q.done and s.completed == "hide" then keep = false end
      if keep then list[#list + 1] = q end
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

-- Objective progress colour (red -> yellow -> green) from "3/5"-style text.
function QT.ProgressColor(text, finished)
  if finished then return Theme:Color("success") end
  local have, need = tostring(text or ""):match("(%d+)%s*/%s*(%d+)")
  have, need = tonumber(have), tonumber(need)
  if not (s.progressColors and have and need and need > 0) then return 0.82, 0.82, 0.82 end
  local p = math.min(1, have / need)
  if p < 0.5 then return 1, 0.35 + p * 0.9, 0.3 end
  return 1 - (p - 0.5) * 1.2, 0.8, 0.3
end

-- Frame -----------------------------------------------------------------------
local function frame()
  local f = QT.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_QuestTracker", UIParent, nil, OWNER)
  f:SetSize(s.width, 16)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints()
  f.waypoint = f:CreateFontString(nil, "OVERLAY")
  f.waypoint:SetFontObject(Media:FontObject("small"))
  f.waypoint:SetJustifyH("LEFT")
  QT.frame = f
  Layout:Place(f, "qt.tracker")
  return f
end

local function row(i)
  local r = QT.rows[i]
  if r then return r end
  local f = frame()
  r = PUI:CreateFrame("Button", nil, f, nil, OWNER)
  r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local t = r:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(Media:FontObject("body"))
  t:SetPoint("LEFT", 2, 0)
  t:SetPoint("RIGHT", -2, 0)
  t:SetJustifyH("LEFT")
  t:SetWordWrap(false)
  QT.text = QT.text or setmetatable({}, { __mode = "k" })
  QT.text[r] = t
  r:SetScript("OnClick", function(self, button) QT.OnClick(self, button) end)
  QT.rows[i] = r
  return r
end

QT.rowData = setmetatable({}, { __mode = "k" })
-- Click: left = super track (or open details, setting), right = details,
-- Ctrl = Wowhead link in the shared copy box, Alt = stop tracking.
function QT.OnClick(r, button)
  local d = QT.rowData[r]
  if not d then return end
  if d.section then
    s.collapsed[d.section] = not s.collapsed[d.section] or nil
    Schema:Set("qt.collapsed", s.collapsed)
    QT.Refresh()
  elseif d.quest then
    if IsControlKeyDown() then return QT.ShowLink(d.quest) end
    if IsAltKeyDown() then C_QuestLog.RemoveQuestWatch(d.quest); return QT.Refresh() end
    if button == "RightButton" or s.clickAction == "details" then
      if not InCombatLockdown() then QuestMapFrame_OpenToQuestDetails(d.quest) end
    else
      QT.SuperTrack(d.quest)
    end
  elseif d.waypoint then
    QT.ClearWaypoint()
  end
end

function QT.Link(id) return "https://www.wowhead.com/quest=" .. id end
function QT.ShowLink(id) PUI.Dialogs:Copy("Wowhead link", QT.Link(id), "Ctrl+C to copy") end

-- Super tracking and waypoints (1.O owner) ------------------------------------
function QT.SuperTrack(questID)
  C_SuperTrack.SetSuperTrackedQuestID(questID)
  QT.Refresh()
end

-- Parses "/way [#mapID] x y [name]" (commas allowed). Returns mapID, x, y, name.
function QT.ParseWay(text, defaultMap)
  text = (text or ""):gsub(",", " ")
  local mapID
  local m, rest = text:match("^%s*#(%d+)%s+(.*)$")
  if m then mapID, text = tonumber(m), rest end
  local x, y, name = text:match("^%s*([%d%.]+)%s+([%d%.]+)%s*(.-)%s*$")
  x, y = tonumber(x), tonumber(y)
  if not (x and y) or x < 0 or x > 100 or y < 0 or y > 100 then return nil end
  return mapID or defaultMap, x, y, name ~= "" and name or nil
end

function QT.SetWaypoint(mapID, x, y, name)
  if not mapID or not C_Map.CanSetUserWaypointOnMap(mapID) then return false, "a waypoint cannot be placed on this map" end
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
  C_SuperTrack.SetSuperTrackedUserWaypoint(true)
  QT.waypoint = { mapID = mapID, x = x, y = y, name = name }
  QT.Refresh()
  return true
end

function QT.ClearWaypoint()
  C_Map.ClearUserWaypoint()
  QT.waypoint = nil
  QT.Refresh()
end

function QT.Way(msg)
  local out = PUI.Slash.Print
  if PUI.Coexist:Yields("qt.waypoints") then return out("TomTom handles /way (change this on the Quest Tracker page)") end
  if (msg or ""):match("^%s*clear%s*$") then QT.ClearWaypoint(); return out("waypoint cleared") end
  local mapID, x, y, name = QT.ParseWay(msg, C_Map.GetBestMapForUnit("player"))
  if not mapID then return out("/way [#mapID] x y [name]  |  /way clear") end
  local ok, why = QT.SetWaypoint(mapID, x, y, name)
  out(ok and string.format("waypoint: %.1f, %.1f%s", x, y, name and (" " .. name) or "") or ("no waypoint: " .. why))
end

-- Drawing ---------------------------------------------------------------------
local function setRow(i, y, text, r, g, b, data, size)
  local rw = row(i)
  local fs = QT.text[rw]
  local path = PUI.Look.FontFor("quests")
  if path and fs.SetFont then fs:SetFont(path, size, PUI.Look.Flags()) end
  fs:SetText(text)
  fs:SetTextColor(r, g, b)
  rw:ClearAllPoints()
  rw:SetPoint("TOPLEFT", QT.frame, "TOPLEFT", 0, -y)
  rw:SetSize(s.width, size + s.rowSpacing)
  QT.rowData[rw] = data
  rw:Show()
  return y + size + s.rowSpacing
end

-- Height used by Ascent's M+ block docked at the top (0 when not docked).
function QT.BlockHeight()
  local AS = PUI.Ascent
  local D = AS and AS.active and AS.run and s.mplusBlock and AS.Display
  if not (D and D.docked) then return 0 end
  return D.Height() + 6
end

function QT.Hidden()
  if PUI.Coexist:Yields("qt.questie") then return true end
  return false
end

function QT.Refresh()
  if not QT.active then return end
  local f = frame()
  if QT.Hidden() then f:Hide(); return end
  f:SetWidth(s.width)
  f:SetAlpha(s.opacity)
  f.bg:SetColorTexture(0, 0, 0, s.bgAlpha)
  local n, y = 0, QT.BlockHeight()
  local inKey = y > 0
  local size = s.fontSize
  local ar, ag, ab = Theme:Color("accent")
  -- waypoint line
  if s.waypointLine and QT.waypoint then
    n = n + 1
    local w = QT.waypoint
    y = setRow(n, y, string.format("> Waypoint %.1f, %.1f%s  |cff9a9a9a(click to clear)|r", w.x, w.y, w.name and (" " .. w.name) or ""), ar, ag, ab, { waypoint = true }, size - 1)
  end
  local collapseAll = (s.collapseInCombat and InCombatLockdown()) or (s.collapseInKeys and inKey)
  local superID = C_SuperTrack.GetSuperTrackedQuestID()
  for _, sec in ipairs(QT.Sections(QT.Collect())) do
    local collapsed = s.collapsed[sec.name] or collapseAll
    n = n + 1
    y = setRow(n, y, (collapsed and "+ " or "- ") .. sec.name:upper() .. "  " .. #sec.quests, ar, ag, ab, { section = sec.name }, size - 2)
    if not collapsed then
      for _, q in ipairs(sec.quests) do
        n = n + 1
        local r, g, b = 1, 0.82, 0
        if q.done then r, g, b = Theme:Color("success") end
        local title = (s.showLevel and ("[" .. q.level .. "] ") or "") .. q.title
        if q.id == superID then title = "> " .. title end
        if q.done and s.completed == "fade" then r, g, b = r * 0.6, g * 0.6, b * 0.6 end
        y = setRow(n, y, title .. (q.done and "  |cff5ad16a(turn in)|r" or ""), r, g, b, { quest = q.id }, size)
        if not q.done then
          for _, o in ipairs(q.objectives) do
            if o.text and not o.finished then
              n = n + 1
              local orr, og, ob = QT.ProgressColor(o.text, o.finished)
              y = setRow(n, y, "   " .. o.text, orr, og, ob, { quest = q.id }, size - 1)
            end
          end
        end
      end
    end
  end
  for i = n + 1, #QT.rows do QT.rows[i]:Hide(); QT.rowData[QT.rows[i]] = nil end
  f:SetHeight(math.max(16, y))
  f:Show()
  QT.count = n
end

-- Sounds and announcements on progress -----------------------------------------
function QT.CheckCompletions()
  for i = 1, C_QuestLog.GetNumQuestWatches() do
    local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
    if id then
      local done = C_QuestLog.IsComplete(id) and true or false
      if done and QT.complete[id] == false then
        if s.sound then PUI.Media:Alert(SOUNDKIT.IG_QUEST_LIST_COMPLETE) end
        if s.announce then PUI.Announce:Send("quest", (C_QuestLog.GetTitleForQuestID(id) or "Quest") .. " complete") end
      end
      QT.complete[id] = done
      -- objective progress
      for k, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
        local pkey = id .. ":" .. k
        local old = QT.progress[pkey]
        if old ~= nil and o.text and old ~= o.text and not done then
          if s.objectiveSound then PUI.Media:Alert(SOUNDKIT.IG_QUEST_LIST_SELECT or SOUNDKIT.IG_QUEST_LIST_COMPLETE) end
          if s.announce then PUI.Announce:Send("quest", o.text) end
        end
        QT.progress[pkey] = o.text
      end
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

-- Auto accept / turn-in with rules; hold the pause key to read the quest.
local PAUSE = { SHIFT = IsShiftKeyDown, CTRL = IsControlKeyDown, ALT = IsAltKeyDown }
function QT.Paused() local fn = PAUSE[s.pauseKey] or IsShiftKeyDown; return fn() end
function QT.Allowed(questID)
  if not s.autoQuest or QT.Paused() then return false end
  if questID and s.skipTrivial and C_QuestLog.IsQuestTrivial(questID) then return false end
  if questID and s.skipRepeatable and C_QuestLog.IsRepeatableQuest(questID) then return false end
  return true
end
function QT.OnQuestDetail(_, _, questID) if QT.Allowed(questID) then AcceptQuest() end end
function QT.OnQuestProgress() if QT.Allowed() and IsQuestCompletable() then CompleteQuest() end end
function QT.OnQuestComplete()
  if not QT.Allowed() then return end
  local n = GetNumQuestChoices()
  if n == 0 then GetQuestReward() elseif n == 1 then GetQuestReward(1) end
end

-- Blizzard tracker: no new modules while Phoenix's tracker is chosen (G39).
function QT.BlizzardTracker(allow)
  local mgr = rawget(_G, "ObjectiveTrackerManager")
  if not mgr then return end
  CQ.Defer("qt.blizzard", function()
    mgr:SetCanAddModules(allow)
    QT.blizzardOff = not allow
  end)
end

local function onEnable(mod)
  QT.active = true
  local refresh = function() QT.CheckCompletions(); QT.Refresh() end
  mod:RegisterEvent("QUEST_WATCH_LIST_CHANGED", refresh)
  mod:RegisterEvent("QUEST_LOG_UPDATE", refresh)
  mod:RegisterEvent("SUPER_TRACKING_CHANGED", function() QT.Refresh() end)
  mod:RegisterEvent("USER_WAYPOINT_UPDATED", function() if not C_Map.HasUserWaypoint() then QT.waypoint = nil end; QT.Refresh() end)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() QT.TrackZone(); QT.Refresh() end)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", function() if s.collapseInCombat then QT.Refresh() end end)
  mod:RegisterEvent("QUEST_DETAIL", QT.OnQuestDetail)
  mod:RegisterEvent("QUEST_PROGRESS", QT.OnQuestProgress)
  mod:RegisterEvent("QUEST_COMPLETE", QT.OnQuestComplete)
  if s.hideBlizzard then QT.BlizzardTracker(false) end
  QT.Sync()
  QT.Refresh()
  if PUI.Ascent and PUI.Ascent.active then PUI.Ascent.Draw() end
end

local function onDisable()
  QT.active = false
  if QT.frame then QT.frame:Hide() end
  if QT.blizzardOff then QT.BlizzardTracker(true) end
  Ticker:Unregister("qt.distance")
  if PUI.Ascent and PUI.Ascent.active then PUI.Ascent.Draw() end
end

PUI.Kernel:On("ASCENT_RUN", function() if QT.active then QT.Refresh() end end)

function QT.Sync()
  if QT.active and s.sort == "distance" then
    if not Ticker:IsRegistered("qt.distance") then Ticker:Register("qt.distance", 2, QT.Refresh, OWNER) end
  elseif Ticker:IsRegistered("qt.distance") then
    Ticker:Unregister("qt.distance")
  end
end

Layout:RegisterElement("qt.tracker", { label = "Quest tracker", owner = OWNER, size = { 240, 200 }, default = { point = "TOPRIGHT", x = -19, y = -360 } })

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
-- Simple
key("sort", { type = "select", default = "zone", choices = { "zone", "level", "distance", "type" }, label = "Sort quests by",
  tooltip = "Groups and orders tracked quests by zone, level, distance or quest type.", mode = "simple" })
key("filter", { type = "select", default = "all", choices = { "all", "progress", "ready" }, label = "Show",
  tooltip = "All tracked quests, only those in progress, or only those ready to turn in.", mode = "simple" })
key("completed", { type = "select", default = "glow", choices = { "glow", "fade", "hide" },
  choiceLabels = { glow = "Green with (turn in)", fade = "Faded", hide = "Hidden" }, label = "Finished quests",
  tooltip = "How quests ready to turn in look.", mode = "simple" })
key("mplusBlock", { type = "toggle", default = true, label = "Mythic+ block on top",
  tooltip = "While a key runs, Ascent's Mythic+ block sits at the top of the tracker (Ascent owns the timer).", mode = "simple",
  searchTags = { "mythic", "timer", "keystone" } }, function() if PUI.Ascent and PUI.Ascent.active then PUI.Ascent.Draw() end end)
key("collapseInKeys", { type = "toggle", default = true, label = "Collapse quests during M+",
  tooltip = "Folds every quest section while a key runs so the Mythic+ block has room.", mode = "simple" })
key("hideBlizzard", { type = "toggle", default = true, label = "Replace Blizzard's tracker",
  tooltip = "Blizzard's objective tracker adds no quests while this tracker is on (it comes back when you turn this off). Blizzard's addon is never disabled.", mode = "simple" },
  function(v) if QT.active and (v or QT.blizzardOff) then QT.BlizzardTracker(not v) end end)
key("clickAction", { type = "select", default = "supertrack", choices = { "supertrack", "details" },
  choiceLabels = { supertrack = "Super track (arrow on the map)", details = "Open quest details" }, label = "Left-click a quest",
  tooltip = "What a left click on a quest does. Right-click opens details, Ctrl-click copies a Wowhead link, Alt-click stops tracking.", mode = "simple" })
key("autoQuest", { type = "toggle", default = false, label = "Auto accept and turn in",
  tooltip = "Accepts and turns in quests with at most one reward choice. Hold the pause key to read the quest.", mode = "simple" })
-- Advanced
key("width", { type = "range", default = 240, min = 180, max = 400, step = 4, label = "Width", tooltip = "Tracker width.", mode = "advanced" })
key("fontSize", { type = "range", default = 12, min = 9, max = 18, step = 1, label = "Text size", tooltip = "Quest title size; objectives and headers are a little smaller.", mode = "advanced" })
key("rowSpacing", { type = "range", default = 2, min = 0, max = 8, step = 1, label = "Line spacing", tooltip = "Space between lines.", mode = "advanced" })
key("opacity", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = "Opacity", tooltip = "Opacity of the whole tracker.", mode = "advanced" })
key("bgAlpha", { type = "range", default = 0, min = 0, max = 0.9, step = 0.05, label = "Background", tooltip = "A dark background behind the tracker.", mode = "advanced" })
key("showLevel", { type = "toggle", default = false, label = "Quest level", tooltip = "Writes the quest level before the title.", mode = "advanced" })
key("progressColors", { type = "toggle", default = true, label = "Progress colours", tooltip = "Objectives go from red to green as their count fills.", mode = "advanced" })
key("collapseInCombat", { type = "toggle", default = false, label = "Collapse in combat", tooltip = "Folds every section while you are in combat.", mode = "advanced" })
key("waypointLine", { type = "toggle", default = true, label = "Waypoint line", tooltip = "Shows your /way waypoint at the top; click it to clear.", mode = "advanced" })
key("collapsed", { type = "layout", default = {}, mode = "advanced", label = "Collapsed sections", tooltip = "Sections you collapsed." })
key("autoTrackZone", { type = "toggle", default = false, label = "Track zone quests", tooltip = "Tracks quests for the zone you enter.", mode = "advanced" })
key("pauseKey", { type = "select", default = "SHIFT", choices = { "SHIFT", "CTRL", "ALT" }, label = "Pause key",
  tooltip = "Hold this key to read a quest instead of auto accepting or turning it in.", mode = "advanced" })
key("skipTrivial", { type = "toggle", default = false, label = "Skip low-level quests", tooltip = "Auto accept leaves grey (trivial) quests alone.", mode = "advanced" })
key("skipRepeatable", { type = "toggle", default = false, label = "Skip repeatable quests", tooltip = "Auto accept leaves repeatable quests alone.", mode = "advanced" })
key("sound", { type = "toggle", default = true, label = "Quest complete sound", tooltip = "Plays a sound when a tracked quest is ready.", mode = "advanced" })
key("objectiveSound", { type = "toggle", default = false, label = "Objective progress sound", tooltip = "Plays a short sound when an objective count goes up.", mode = "advanced" })
key("announce", { type = "toggle", default = false, label = "Announce progress",
  tooltip = "Sends objective progress and completions through Phoenix announcements (the Quest topic there decides where).", mode = "advanced" })

local ckey, cdef = PUI.Coexist:Define("questtracker", { module = OWNER, job = "Quest tracker", addons = { "!KalielsTracker", "KalielsTracker" } })
cdef.owner = OWNER
schema[ckey] = cdef
local qkey, qdef = PUI.Coexist:Define("qt.questie", { module = OWNER, job = "Questie's quest tracker", soft = true, addons = { "Questie" } })
qdef.owner = OWNER
schema[qkey] = qdef
local wkey, wdef = PUI.Coexist:Define("qt.waypoints", { module = OWNER, job = "Waypoints (/way)", soft = true, addons = { "TomTom" } })
wdef.owner = OWNER
schema[wkey] = wdef

-- /way (owner) is registered after login so TomTom, when loaded, keeps its own;
-- /pui way always works.
PUI.Slash:Register("way", QT.Way, "set a waypoint: [#mapID] x y [name] | clear")
PUI.Kernel:On("LOGIN", function()
  if C_AddOns.IsAddOnLoaded("TomTom") then return end
  SLASH_PHOENIXUIWAY1 = "/way"
  SlashCmdList.PHOENIXUIWAY = function(msg) QT.Way(msg) end
end)

QT.module = PUI:RegisterModule(OWNER, {
  label = "Quest Tracker", tooltip = "Restyled quest tracker with sorting, filters, super tracking, /way, the Mythic+ block on top and quest automation.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return PUI.Coexist:Allows("questtracker") end,
})
for k, def in pairs(schema) do if k:sub(1, 3) == "qt." then def.apply(Schema:Get(k)) end end
