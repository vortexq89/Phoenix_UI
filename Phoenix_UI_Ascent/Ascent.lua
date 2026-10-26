local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent (PUI_V2 6.2): Mythic+ timer on the game's world timer, so it resumes
-- correctly after a reload. +2/+3 thresholds from the map's time limit,
-- enemy forces as a bar fed the criteria values as they come (secret-safe),
-- deaths and time lost, boss splits against personal bests, affixes, route
-- notes per dungeon, a per-character leaderboard and a run summary. Retail
-- only (the module never enables on Forever). Off by default.
local _, ns = ...
local Schema, Secret, Ticker, Theme, Media, Layout = PUI.Schema, PUI.Secret, PUI.Ticker, PUI.Theme, PUI.Media, PUI.Layout
local OWNER = "Ascent"

local AS = { active = false, run = nil }
ns.AS = AS
PUI.Ascent = AS
local s = { sounds = true, tts = false, hideBlizzard = false, splits = true, notes = true, scale = 1 }
AS.settings = s

AS.PLUS3, AS.PLUS2 = 0.6, 0.8

function AS.Clock(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The challenge-mode world timer, if one is running.
function AS.TimerID()
  for _, id in ipairs({ GetWorldElapsedTimers() }) do
    local _, _, kind = GetWorldElapsedTime(id)
    if kind == Enum.WorldElapsedTimerTypes.ChallengeMode then return id end
  end
end

function AS.Elapsed()
  local id = AS.TimerID()
  if not id then return nil end
  local _, elapsed = GetWorldElapsedTime(id)
  return elapsed
end

-- Thresholds for a time limit: { +3, +2, +1 } in seconds.
function AS.Thresholds(limit) return { limit * AS.PLUS3, limit * AS.PLUS2, limit } end

-- Upgrade level the run would get at `elapsed` (3, 2, 1, or 0 = over time).
function AS.Upgrades(elapsed, limit)
  local t = AS.Thresholds(limit)
  if elapsed <= t[1] then return 3 elseif elapsed <= t[2] then return 2 elseif elapsed <= t[3] then return 1 end
  return 0
end

-- Enemy forces: the weighted criteria. Values pass straight to the bar.
function AS.Forces()
  for i = 1, 32 do
    local c = C_ScenarioInfo.GetCriteriaInfo(i)
    if not c then return nil end
    if c.isWeightedProgress then return c end
  end
end

-- Records (per character) -----------------------------------------------------
local function records() return Schema:Get("ascent.records") end
AS.Records = records

function AS.RecordKey(mapID, level) return tostring(mapID) .. ":" .. tostring(level) end

function AS.Best(mapID, level)
  local r = records()[PUI.DB:CharKey()]
  return r and r[AS.RecordKey(mapID, level)]
end

-- Store a finished run when it beats the character's best on that map/level.
function AS.SaveRun(run)
  local all = records()
  local me = PUI.DB:CharKey()
  all[me] = all[me] or {}
  local key = AS.RecordKey(run.mapID, run.level)
  local old = all[me][key]
  local better = not old or (run.onTime and not old.onTime) or (run.onTime == old.onTime and run.time < old.time)
  if better then
    all[me][key] = { time = run.time, onTime = run.onTime, deaths = run.deaths, splits = run.splits, at = time() }
    Schema:Set("ascent.records", all)
  end
  return better
end

-- Leaderboard: this character's best per dungeon (highest timed level first).
function AS.Leaderboard()
  local out = {}
  local mine = records()[PUI.DB:CharKey()] or {}
  for key, rec in pairs(mine) do
    local mapID, level = key:match("^(%d+):(%d+)$")
    out[#out + 1] = { mapID = tonumber(mapID), level = tonumber(level), time = rec.time, onTime = rec.onTime }
  end
  table.sort(out, function(a, b)
    if a.onTime ~= b.onTime then return a.onTime end
    if a.level ~= b.level then return a.level > b.level end
    return a.time < b.time
  end)
  return out
end

-- Run lifecycle ------------------------------------------------------------------
function AS.Start()
  local mapID = C_ChallengeMode.GetActiveChallengeMapID()
  if not mapID then AS.run = nil; return nil end
  local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
  local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
  local names = {}
  for _, id in ipairs(affixes or {}) do names[#names + 1] = (C_ChallengeMode.GetAffixInfo(id)) end
  AS.run = { mapID = mapID, name = name, limit = limit, level = level, affixes = names, splits = {}, warned = {} }
  return AS.run
end

function AS.OnBoss(_, _, encounterID, encounterName, _, _, success)
  local run = AS.run
  if not run or success ~= 1 then return end
  local elapsed = AS.Elapsed()
  if not elapsed then return end
  run.splits[#run.splits + 1] = { name = encounterName, at = elapsed }
  AS.Draw()
end

function AS.OnComplete()
  local run = AS.run
  if not run then return end
  local info = C_ChallengeMode.GetChallengeCompletionInfo()
  if not info or info.practiceRun then AS.run = nil; return end
  run.time = (info.time or 0) / 1000
  run.onTime = info.onTime
  run.deaths = (C_ChallengeMode.GetDeathCount())
  local pb = AS.SaveRun(run)
  local delta = (info.newOverallDungeonScore or 0) - (info.oldOverallDungeonScore or 0)
  PUI.Slash.Print(string.format("%s +%d: %s, %s, %d deaths, score %+d%s", run.name or "?", run.level or 0, AS.Clock(run.time),
    run.onTime and ("+" .. (info.keystoneUpgradeLevels or 1)) or "over time", run.deaths or 0, delta, pb and " - personal best!" or ""))
  AS.run = nil
end

local function alert(text)
  if s.sounds then PlaySound(SOUNDKIT.RAID_WARNING) end
  if s.tts then C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard), text, 0, 100, false) end
end
AS.Alert = alert

-- Display ----------------------------------------------------------------------
local f
local function build()
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_Ascent", UIParent, nil, OWNER)
  f:SetSize(240, 150)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.5)
  local function text(role, y)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFontObject(Media:FontObject(role))
    t:SetPoint("TOPLEFT", 8, y)
    t:SetJustifyH("LEFT")
    return t
  end
  f.title = text("header", -6)
  f.timer = text("header", -24)
  f.marks = text("small", -44)
  f.forces = PUI:CreateFrame("StatusBar", nil, f, nil, OWNER)
  f.forces:SetPoint("TOPLEFT", 8, -60)
  f.forces:SetSize(224, 12)
  f.forces:SetStatusBarTexture(Media:Texture("flat"))
  f.forcesText = f.forces:CreateFontString(nil, "OVERLAY")
  f.forcesText:SetFontObject(Media:FontObject("small"))
  f.forcesText:SetPoint("CENTER")
  f.deaths = text("small", -78)
  f.splits = text("small", -94)
  f.note = text("small", -128)
  Layout:Place(f, "ascent.timer")
  AS.frame = f
  return f
end

function AS.Draw()
  local run = AS.run
  if not run then if f then f:Hide() end return end
  build()
  f:SetScale(s.scale)
  local elapsed = AS.Elapsed() or 0
  local limit = run.limit or 0
  f.title:SetText(string.format("%s +%d  %s", run.name or "", run.level or 0, table.concat(run.affixes, ", ")))
  local up = AS.Upgrades(elapsed, limit)
  f.timer:SetText(AS.Clock(elapsed) .. " / " .. AS.Clock(limit))
  local t = AS.Thresholds(limit)
  f.marks:SetText(string.format("+3 %s   +2 %s", AS.Clock(t[1] - elapsed), AS.Clock(t[2] - elapsed)))
  -- crossing a threshold: one alert each
  if up < 3 and not run.warned[3] and limit > 0 then run.warned[3] = true; if up == 2 then alert("Plus three lost") end end
  if up < 2 and not run.warned[2] and limit > 0 then run.warned[2] = true; if up == 1 then alert("Plus two lost") end end
  local c = AS.Forces()
  if c then
    f.forces:SetMinMaxValues(0, c.totalQuantity)
    f.forces:SetValue(c.quantity)
    f.forcesText:SetText(c.quantityString)
    f.forces:Show()
  else
    f.forces:Hide()
  end
  local deaths, lost = C_ChallengeMode.GetDeathCount()
  f.deaths:SetText(string.format("Deaths %s (-%s)", Secret.ToText(deaths), Secret.IsSecret(lost) and "?" or AS.Clock(lost)))
  if s.splits then
    local best = AS.Best(run.mapID, run.level)
    local lines = {}
    for i, sp in ipairs(run.splits) do
      local pb = best and best.splits and best.splits[i]
      lines[#lines + 1] = string.format("%s %s%s", sp.name or "Boss", AS.Clock(sp.at), pb and string.format(" (%+ds)", math.floor(sp.at - pb.at)) or "")
    end
    f.splits:SetText(table.concat(lines, "\n"))
  else
    f.splits:SetText("")
  end
  local notes = Schema:Get("ascent.notes")
  f.note:SetText(s.notes and notes[tostring(run.mapID)] or "")
  f:Show()
end

-- Blizzard's scenario tracker: faded (not moved or hidden) while a run is shown.
local function blizzTracker(hide)
  local t = rawget(_G, "ObjectiveTrackerFrame")
  if not t then return end
  if hide then
    if AS.trackerAlpha == nil then AS.trackerAlpha = t:GetAlpha() end
    t:SetAlpha(0)
  elseif AS.trackerAlpha ~= nil then
    t:SetAlpha(AS.trackerAlpha)
    AS.trackerAlpha = nil
  end
end
AS.BlizzTracker = blizzTracker

local function refresh()
  if not AS.active then return end
  if C_ChallengeMode.IsChallengeModeActive() then
    if not AS.run then AS.Start() end
    blizzTracker(s.hideBlizzard and AS.run ~= nil)
    Ticker:Register("ascent.timer", 0.25, AS.Draw, OWNER)
    AS.Draw()
  else
    Ticker:Unregister("ascent.timer")
    blizzTracker(false)
    if f then f:Hide() end
  end
end
AS.Refresh = refresh

local function onEnable(mod)
  AS.active = true
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", refresh)
  mod:RegisterEvent("CHALLENGE_MODE_START", function() AS.run = nil; refresh() end)
  mod:RegisterEvent("CHALLENGE_MODE_RESET", function() AS.run = nil; refresh() end)
  mod:RegisterEvent("WORLD_STATE_TIMER_START", refresh)
  mod:RegisterEvent("WORLD_STATE_TIMER_STOP", refresh)
  mod:RegisterEvent("ENCOUNTER_END", AS.OnBoss)
  mod:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() AS.OnComplete(); refresh() end)
  refresh()
end

local function onDisable()
  AS.active = false
  Ticker:Unregister("ascent.timer")
  blizzTracker(false)
  if f then f:Hide() end
end

Layout:RegisterElement("ascent.timer", { label = "Mythic+ timer", owner = OWNER, size = { 240, 150 }, default = { point = "TOPRIGHT", x = -19, y = -207 } })

local schema = {}
AS.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = function(value) s[name] = value; if AS.active then refresh() end end
  schema["ascent." .. name] = def
end
key("sounds", { type = "toggle", default = true, label = "Threshold sounds", tooltip = "Plays a warning when the +3 or +2 time runs out.", mode = "simple" })
key("tts", { type = "toggle", default = false, label = "Spoken warnings", tooltip = "Reads threshold warnings aloud with the game's text to speech.", mode = "advanced" })
key("hideBlizzard", { type = "toggle", default = false, label = "Hide Blizzard tracker in keys", tooltip = "Fades the Blizzard objective tracker while a key runs.", mode = "simple" })
key("splits", { type = "toggle", default = true, label = "Boss splits", tooltip = "Boss kill times and the difference to your best run.", mode = "advanced" })
key("notes", { type = "toggle", default = true, label = "Route notes", tooltip = "Shows your note for the dungeon under the timer (/pui ascent note <text>).", mode = "advanced" })
key("scale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Timer scale", tooltip = "Size of the timer window.", mode = "advanced" })
schema["ascent.records"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Best runs", tooltip = "Best run per dungeon and level for each character.", apply = function() end }
schema["ascent.notes"] = { type = "layout", default = {}, owner = OWNER, mode = "advanced", label = "Route notes", tooltip = "Your notes per dungeon.", apply = function() end }

PUI.Slash:Register("ascent", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  local out = PUI.Slash.Print
  if word == "note" then
    local mapID = (AS.run and AS.run.mapID) or C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if not mapID then return out("start or own a key to attach a note") end
    local notes = Schema:Get("ascent.notes")
    notes[tostring(mapID)] = arg ~= "" and arg or nil
    Schema:Set("ascent.notes", notes)
    out("note saved")
  elseif word == "best" then
    for _, r in ipairs(AS.Leaderboard()) do
      out(string.format("%s +%d  %s%s", (C_ChallengeMode.GetMapUIInfo(r.mapID)) or r.mapID, r.level, AS.Clock(r.time), r.onTime and "" or " (over)"))
    end
  else
    out("/pui ascent note <text> | best")
  end
end, "Mythic+ timer: route note, personal bests")

AS.module = PUI:RegisterModule(OWNER, {
  label = "Ascent", tooltip = "Mythic+ timer with thresholds, forces, deaths, boss splits and personal bests.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return not PUI.IS_FOREVER end,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
