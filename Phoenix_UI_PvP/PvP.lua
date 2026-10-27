local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PvP (plan 5.21 "PvP UI" row, 15.7 sArena parity rows, mockup 18; owner per
-- plan 1.O of the rated card, rated history, title progress, the scoreboard
-- column registry, the BG leave countdown, Training Grounds and the Solo
-- Shuffle round tracker). Arena frames, the DR tray, trinkets, the match
-- timer and the post-match card are Arena's; queue status and pop countdown
-- are Group Finder's. Values are read only when the game shows them plainly
-- (scores are secret during a match).
local _, ns = ...
local Schema = PUI.Schema
local R, C, M, W = ns.Rated, ns.Columns, ns.Match, ns.Card
local OWNER = "PvP"
local PV = { active = false }
ns.PvP = PV
PUI.PvP = PV
PV.Rated, PV.Columns, PV.Match, PV.Card = R, C, M, W
local s = {}
PV.settings = s

function PV.DB()
  local db = rawget(_G, "PhoenixUIPvPDB")
  if type(db) ~= "table" then
    db = {}
    -- lint-allow: global own SavedVariablesPerCharacter
    PhoenixUIPvPDB = db
  end
  return db
end
function PV.Season()
  local v = C_PvP.GetUIDisplaySeason and C_PvP.GetUIDisplaySeason()
  if v == nil or PUI.Secret.IsSecret(v) then return 0 end
  return v
end
local function thresholds()
  return { gladiator = s.rating_gladiator, legend = s.rating_legend, strategist = s.rating_strategist }
end
local function bracketNow()
  if C_PvP.IsRatedSoloShuffle() then return "shuffle" end
  if C_PvP.IsRatedSoloRBG and C_PvP.IsRatedSoloRBG() then return "blitz" end
  if C_PvP.IsRatedBattleground() then return "rbg" end
  if C_PvP.IsRatedArena() then
    local size = GetNumGroupMembers()
    return size <= 2 and "2v2" or "3v3"
  end
  return nil
end
PV.BracketNow = bracketNow

function PV.Repaint()
  W.PaintCard(s, PV.DB(), PV.Season())
  W.PaintScore(s)
  W.PaintLeave()
end
M.onChange = function() PV.Repaint() end

-- Match flow ---------------------------------------------------------------
function PV.OnMatchActive()
  PV.before, PV.bracket = R.Snapshot(), bracketNow()
  M.ResetRounds()
end
-- After the match the game updates personal rated info; read it then.
function PV.Settle()
  local bracket = PV.bracket
  if not bracket then return nil end
  local after = R.Snapshot()
  local diff = R.Diff(PV.before, after, bracket)
  PV.before, PV.bracket = nil, nil
  if not diff then return nil end
  local db = PV.DB()
  R.Count(db, PV.Season(), diff, bracket, thresholds())
  R.Remember(db, { at = time(), bracket = bracket, bracketLabel = R.BY_ID[bracket].label, change = diff.change, rating = diff.rating, wins = diff.wins }, s.historySize)
  PUI.Kernel:Fire("PVP_RATED_RESULT", diff, bracket)
  if s.chatChange then PUI.Slash.Print(string.format("%s: %+d rating (now %d)", R.BY_ID[bracket].label, diff.change, diff.rating)) end
  PV.Repaint()
  return diff
end
function PV.OnMatchComplete()
  if C_PvP.IsBattleground() and not C_PvP.IsArena() then M.StartLeave(s) end
  if s.scoreAfter and not C_PvP.IsArena() then W.ShowScore(s, true) end
  local fn = rawget(_G, "RequestRatedInfo")
  if fn then fn() end
  C_Timer.After(2, function() if PV.active and PV.bracket then PV.Settle() end end)
end
function PV.OnZone()
  if not (C_PvP.IsBattleground() or C_PvP.IsArena()) then
    M.Cancel(); M.ResetRounds()
    if W.score and not s.scoreAfterZone then W.score:Hide() end
  end
  PV.Repaint()
end

local function onEnable(mod)
  PV.active = true
  mod:RegisterEvent("PVP_MATCH_ACTIVE", PV.OnMatchActive)
  mod:RegisterEvent("PVP_MATCH_COMPLETE", PV.OnMatchComplete)
  mod:RegisterEvent("PVP_RATED_STATS_UPDATE", function() if PV.bracket and not C_PvP.IsMatchActive() then PV.Settle() end PV.Repaint() end)
  mod:RegisterEvent("PVP_MATCH_STATE_CHANGED", function() M.OnState(s) end)
  mod:RegisterEvent("UPDATE_BATTLEFIELD_SCORE", function() W.PaintScore(s) end)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", PV.OnZone)
  mod:RegisterEvent("WEEKLY_REWARDS_UPDATE", PV.Repaint)
  mod:RegisterEvent("CURRENCY_DISPLAY_UPDATE", function() if W.card and W.card:IsShown() then PV.Repaint() end end)
  PV.HookPvPWindow()
end
local function onDisable()
  PV.active = false
  M.Cancel(); M.ResetRounds()
  for _, f in ipairs({ W.card, W.score, W.leave }) do if f then f:Hide() end end
end

-- Dock the card beside Blizzard's PvP window (hook only; nothing replaced).
function PV.HookPvPWindow()
  if PV.hooked then return end
  local frame = rawget(_G, "PVEFrame")
  if not frame then return end
  PV.hooked = true
  frame:HookScript("OnShow", function() if PV.active and s.cardWith == "pvp" then W.ToggleCard(s, PV.DB(), PV.Season(), true); PV.Dock() end end)
  frame:HookScript("OnHide", function() if s.cardWith == "pvp" and W.card then W.card:Hide() end end)
end
function PV.Dock()
  local frame = rawget(_G, "PVEFrame")
  if not (W.card and frame and s.cardWith == "pvp") then return end
  W.card:ClearAllPoints(); W.card:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
end

-- Settings -----------------------------------------------------------------
local schema = {}
PV.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; if PV.active then PV.Repaint() end end
  schema["pvp." .. name] = def
end
key("cardRatings", { type = "toggle", default = true, mode = "simple", label = "Ratings on the card", tooltip = "Each bracket's rating, season best and this week's record." })
for _, b in ipairs(R.BRACKETS) do
  key("bracket_" .. b.id, { type = "toggle", default = true, label = "Show " .. b.label, tooltip = "Lists " .. b.label .. " on the rated card." })
end
key("cardChange", { type = "toggle", default = true, mode = "simple", label = "Rating change after each match", tooltip = "Your last rated match and how much it moved your rating." })
key("chatChange", { type = "toggle", default = false, label = "Rating change in chat", tooltip = "Also prints the rating change in your chat window after each rated match." })
key("cardProgress", { type = "toggle", default = true, mode = "simple", label = "Gladiator / Legend / Strategist progress",
  tooltip = "Wins toward each title. Uses the game's own achievement count when the season has one; otherwise Phoenix counts wins taken at or above the title rating." })
for _, t in ipairs(R.TITLES) do
  key("title_" .. t.id, { type = "toggle", default = true, label = t.label .. " progress", tooltip = "Shows " .. t.label .. " progress on the card." })
  key("rating_" .. t.id, { type = "range", default = 2400, min = 1400, max = 3000, step = 50, label = t.label .. " rating", tooltip = "Rating at which wins count toward " .. t.label .. " (check the season's rules)." })
  key("need_" .. t.id, { type = "range", default = t.id == "legend" and 100 or (t.id == "strategist" and 25 or 50), min = 1, max = 300, step = 1,
    label = t.label .. " wins needed", tooltip = "Wins needed when Phoenix counts them itself." })
  key("ach_" .. t.id, { type = "range", default = 0, min = 0, max = 99999, step = 1, label = t.label .. " achievement ID",
    tooltip = "Optional: the season's achievement ID, so the count comes from the game. 0 = automatic (Gladiator) or Phoenix's count." })
end
key("cardWeekly", { type = "toggle", default = true, mode = "simple", label = "Weekly record, conquest and Great Vault", tooltip = "This week's wins and losses, conquest earned and the PvP row of the Great Vault on one line." })
key("cardLinks", { type = "toggle", default = true, label = "Links to Arena and Group Finder", tooltip = "A line naming where arena frames, DR and queue status live." })
key("cardWith", { type = "select", default = "pvp", choices = { "pvp", "manual" }, choiceLabels = { pvp = "With the PvP window", manual = "Only when I open it" },
  mode = "simple", label = "Show the rated card", tooltip = "Opens beside Blizzard's PvP window, or only with /pui pvp card." })
key("cardScale", { type = "range", default = 1, min = 0.6, max = 1.6, step = 0.05, label = "Card scale", tooltip = "Size of the rated card." })
key("historySize", { type = "range", default = 50, min = 5, max = 200, step = 5, label = "Rated matches kept", tooltip = "How many rated results are kept (Arena's card reads them too)." })
key("columns", { type = "list", default = C.DEFAULT, maxItems = 20, mode = "simple", label = "Scoreboard columns",
  tooltip = "Add, remove and reorder columns. Column IDs: name, spec, damage, healing, kb, deaths, hk, rating, ratingChange, mmrBefore, mmrAfter, honor, plus any column another addon adds." })
key("sortBy", { type = "select", default = "damage", choices = function() local o = {}; for _, d in ipairs(C:All()) do o[#o + 1] = d.id end; return o end,
  label = "Sort scoreboard by", tooltip = "Starting sort column (click a header to change it)." })
key("sortDesc", { type = "toggle", default = true, label = "Highest first", tooltip = "Sort from highest to lowest." })
key("highlightMe", { type = "toggle", default = true, label = "Highlight you", tooltip = "Your row is tinted with the accent colour." })
key("highlightTeam", { type = "toggle", default = true, label = "Highlight your team", tooltip = "Your team's rows get a light tint." })
key("classColors", { type = "toggle", default = true, label = "Class-coloured names", tooltip = "Player names in their class colour." })
key("scoreAfter", { type = "toggle", default = true, mode = "simple", label = "Open the scoreboard after a battleground", tooltip = "Opens Phoenix's scoreboard when a battleground ends." })
key("scoreAfterZone", { type = "toggle", default = false, label = "Keep it open after leaving", tooltip = "The scoreboard stays open after you leave the battleground." })
key("leave", { type = "toggle", default = true, mode = "simple", label = "Leave countdown after a battleground",
  tooltip = "When a battleground ends, a countdown leaves for you. Cancel it or leave at once. Arenas are never left for you." })
key("leaveSeconds", { type = "range", default = 15, min = 3, max = 60, step = 1, mode = "simple", label = "Leave after (s)", tooltip = "Seconds before leaving." })
key("leaveNotInCombat", { type = "toggle", default = true, label = "Never leave in combat", tooltip = "If you are fighting when the countdown ends, it waits until you are out of combat." })
key("leaveRatedOnly", { type = "select", default = "all", choices = { "all", "unrated" }, choiceLabels = { all = "Every battleground", unrated = "Unrated only" },
  label = "Leave countdown in", tooltip = "Which battlegrounds use the countdown." })
key("leaveSound", { type = "toggle", default = false, label = "Sound when the countdown starts", tooltip = "Plays a short sound." })
key("shuffleTracker", { type = "toggle", default = true, mode = "simple", label = "Solo Shuffle round tracker", tooltip = "Round N of 6 with a round clock, and your round record once the game shows it." })
key("training", { type = "toggle", default = true, label = "Training Grounds buttons", tooltip = "Queue buttons for Training Grounds on the rated card, with \"won today\"." })
PUI.Layout:RegisterElement("pvp.card", { label = "PvP rated card", owner = OWNER, size = { 400, 220 }, default = { point = "LEFT", x = 40, y = 60 } })
PUI.Layout:RegisterElement("pvp.scoreboard", { label = "PvP scoreboard", owner = OWNER, size = { 640, 360 }, default = { point = "CENTER", x = 0, y = 40 } })
PUI.Layout:RegisterElement("pvp.leave", { label = "Battleground leave countdown", owner = OWNER, size = { 340, 64 }, default = { point = "TOP", x = 0, y = -180 } })

-- Test: sample rated result and a leave countdown (/pui pvp test).
function PV.Test()
  local db = PV.DB()
  R.Remember(db, { at = time(), bracket = "3v3", bracketLabel = "3v3", change = 16, rating = 2184, wins = 1 }, s.historySize)
  W.ToggleCard(s, db, PV.Season(), true)
  M.StartLeave(s)
  return db.history[1]
end

PUI.Slash:Register("pvp", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "card" then W.ToggleCard(s, PV.DB(), PV.Season())
  elseif word == "score" then W.ShowScore(s, not (W.score and W.score:IsShown()))
  elseif word == "test" then PV.Test()
  elseif word == "stay" then M.Cancel()
  else PUI.Slash.Print("/pui pvp card | score | test | stay") end
end, "PvP: rated card, scoreboard, test, stay (cancel the leave countdown)")

PV.module = PUI:RegisterModule(OWNER, {
  label = "PvP", tooltip = "Rated card with rating change and title progress, a scoreboard with your own columns, the battleground leave countdown, Training Grounds and the Solo Shuffle round tracker. Arena frames are in Arena.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
