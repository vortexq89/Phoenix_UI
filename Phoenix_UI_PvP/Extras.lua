local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PvP, deferred batch C:
--  * conquest overlay: a read-only Phoenix panel inside Blizzard's conquest
--    frame (hooked with HookScript only) with your title progress.
--  * automatic Legend / Strategist achievement IDs: while the setting holds 0,
--    the game's achievement list is searched once per season for the title's
--    newest achievement (out of combat, when the card opens).
--  * rated history window: every stored rated result (date, bracket, change, rating).
--  * drag-to-reorder scoreboard headers: drop a header on another to move it.
--  * per-round Solo Shuffle results, recorded only when the game shows the
--    round count plainly.
local _, ns = ...
local Schema, Secret = PUI.Schema, PUI.Secret
local PV, R, C, M, W = ns.PvP, ns.Rated, ns.Columns, ns.Match, ns.Card
local OWNER = "PvP"
local s = PV.settings
local X = { found = {} }
PV.Extras = X

-- Automatic title achievement IDs ------------------------------------------------------------------
X.TITLE_WORDS = { legend = "Legend", strategist = "Strategist", gladiator = "Gladiator" }
-- FindTitleAchievement(word) -> highest achievement ID whose name starts with "<word>:" (plain names only)
function X.FindTitleAchievement(word)
  local list, numIn, info = rawget(_G, "GetCategoryList"), rawget(_G, "GetCategoryNumAchievements"), rawget(_G, "GetAchievementInfo")
  if not (list and numIn and info) then return nil end
  local best
  local prefix = word:lower() .. ":"
  for _, cat in ipairs(list() or {}) do
    for i = 1, (numIn(cat) or 0) do
      local id, name = info(cat, i)
      if type(id) == "number" and type(name) == "string" and name:lower():sub(1, #prefix) == prefix and (not best or id > best) then best = id end
    end
  end
  return best
end
function X.AutoIDs()
  if InCombatLockdown() or not s.autoTitleIDs then return 0 end
  local season, n = PV.Season(), 0
  for id, word in pairs(X.TITLE_WORDS) do
    if id ~= "gladiator" and (s["ach_" .. id] or 0) == 0 then
      local key = season .. ":" .. id
      -- a finished search is cached for the season (false = none); no search without the API
      if X.found[key] == nil and rawget(_G, "GetCategoryList") then X.found[key] = X.FindTitleAchievement(word) or false end
      if X.found[key] then n = n + 1 end
    end
  end
  return n
end
local progress = R.Progress
function R.Progress(id, db, season, st)
  local found = (st["ach_" .. id] or 0) == 0 and st.autoTitleIDs and X.found[season .. ":" .. id]
  if found then
    local copy = setmetatable({ ["ach_" .. id] = found }, { __index = st })
    return progress(id, db, season, copy)
  end
  return progress(id, db, season, st)
end

-- Conquest overlay -----------------------------------------------------------------------------------
function X.OverlayLines()
  local out, db, season = {}, PV.DB(), PV.Season()
  for _, t in ipairs(R.TITLES) do
    if s["title_" .. t.id] then
      local have, need = R.Progress(t.id, db, season, s)
      out[#out + 1] = string.format("%s  %d / %d", t.label, math.min(have, need), need)
    end
  end
  local cq, cqMax = R.Conquest()
  if cq then out[#out + 1] = cqMax and cqMax > 0 and string.format("Conquest %d / %d", cq, cqMax) or ("Conquest " .. cq) end
  return out
end
function X.PaintOverlay()
  local host = rawget(_G, "ConquestFrame")
  local want = PV.active and s.conquestOverlay and host and host:IsShown()
  if not want then if X.overlay then X.overlay:Hide() end return false end
  local f = X.overlay
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIConquestOverlay", host, nil, OWNER)
    f:SetSize(220, 70)
    f:EnableMouse(false)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.8)
    f.text = f:CreateFontString(nil, "OVERLAY"); f.text:SetFontObject(PUI.Media:FontObject("small")); f.text:SetPoint("TOPLEFT", 8, -6); f.text:SetJustifyH("LEFT")
    X.overlay = f
  end
  f:ClearAllPoints()
  f:SetPoint(s.overlayCorner, host, s.overlayCorner, s.overlayCorner:find("LEFT") and 8 or -8, s.overlayCorner:find("TOP") and -8 or 8)
  local lines = X.OverlayLines()
  f.text:SetText("|cffe8a33dPhoenix|r\n" .. table.concat(lines, "\n"))
  f:SetHeight(24 + #lines * 14)
  f:Show()
  return true
end
function X.HookConquest()
  local host = rawget(_G, "ConquestFrame")
  if X.hooked or not host then return false end
  X.hooked = true
  host:HookScript("OnShow", function() X.AutoIDs(); X.PaintOverlay() end)
  host:HookScript("OnHide", function() if X.overlay then X.overlay:Hide() end end)
  return true
end

-- Rated history window ----------------------------------------------------------------------------------
function X.HistoryLines(db, n)
  local out = {}
  for i, e in ipairs((db or PV.DB()).history or {}) do
    if i > n then break end
    local when = e.at and date("%d %b %H:%M", e.at) or "?"
    out[#out + 1] = string.format("%s   %-12s %+4d   %d", when, e.bracketLabel or e.bracket or "", e.change or 0, e.rating or 0)
  end
  return out
end
function X.ShowHistory()
  local f = X.history
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUIPvPHistory", UIParent, nil, OWNER)
    f:SetSize(340, 80)
    f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.95)
    f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2); f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
    f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetFontObject(PUI.Media:FontObject("normal")); f.title:SetPoint("TOPLEFT", 10, -8); f.title:SetText("Rated history")
    f.close = CreateFrame("Button", nil, f); f.close:SetSize(16, 16); f.close:SetPoint("TOPRIGHT", -4, -4)
    f.close.text = f.close:CreateFontString(nil, "OVERLAY"); f.close.text:SetFontObject(PUI.Media:FontObject("small")); f.close.text:SetAllPoints(); f.close.text:SetText("x")
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.body = f:CreateFontString(nil, "OVERLAY"); f.body:SetFontObject(PUI.Media:FontObject("small")); f.body:SetPoint("TOPLEFT", 10, -30); f.body:SetJustifyH("LEFT")
    X.history = f
    PUI.Layout:Place(f, "pvp.history")
  end
  local lines = X.HistoryLines(PV.DB(), s.historyRows)
  f.body:SetText(#lines > 0 and table.concat(lines, "\n") or "No rated matches stored yet.")
  f:SetHeight(44 + math.max(1, #lines) * 14)
  f:Show()
  return #lines
end

-- Drag-to-reorder headers ---------------------------------------------------------------------------------
function X.Reorder(list, from, to)
  local out = {}
  for i, v in ipairs(list) do out[i] = v end
  if not (out[from] and out[to]) or from == to then return out end
  local v = table.remove(out, from)
  table.insert(out, to, v)
  return out
end
function X.DropTarget(heads, n)
  for i = 1, n do if heads[i] and heads[i]:IsShown() and heads[i]:IsMouseOver() then return i end end
end
local paintScore = W.PaintScore
function W.PaintScore(st)
  paintScore(st)
  local f = W.score
  if not (f and f:IsShown()) then return end
  local n = #C:Pick(st.columns)
  for i = 1, n do
    local h = f.heads[i]
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() X.dragFrom = i end)
    h:SetScript("OnDragStop", function()
      local to = X.DropTarget(f.heads, n)
      local from = X.dragFrom
      X.dragFrom = nil
      if s.dragHeaders and from and to and from ~= to then
        local ids = {}
        for _, col in ipairs(C:Pick(st.columns)) do ids[#ids + 1] = col.id end
        Schema:Set("pvp.columns", X.Reorder(ids, from, to))
      end
    end)
  end
end

-- Per-round Solo Shuffle results ---------------------------------------------------------------------------
M.results = {}
local onState = M.OnState
function M.OnState(st)
  local before = M.round
  onState(st)
  local E = Enum.PvPMatchState or {}
  local state = C_PvP.GetActiveMatchState and C_PvP.GetActiveMatchState()
  if s.shuffleRounds and (state == E.PostRound or state == E.Complete) and M.round > 0 and M.results[M.round] == nil then
    local won = M.RoundRecord()
    if won ~= nil then
      local prev = M.prevWon or 0
      M.results[M.round] = won > prev and "W" or "L"
      M.prevWon = won
    end
  end
  return before
end
local reset = M.ResetRounds
function M.ResetRounds() reset(); M.results = {}; M.prevWon = nil end
local roundText = M.RoundText
function M.RoundText()
  local t = roundText()
  if not (t and s.shuffleRounds) then return t end
  local parts = {}
  for i = 1, M.round do parts[#parts + 1] = M.results[i] or "?" end
  return #parts > 0 and (t .. "  [" .. table.concat(parts, " ") .. "]") or t
end

PUI.Kernel:On("MODULE_ENABLED", function(name)
  if name ~= OWNER or not PV.module then return end
  X.HookConquest()
  PV.module:RegisterEvent("ADDON_LOADED", function(_, _, addon) if addon == "Blizzard_PVPUI" then X.HookConquest() end end)
end)
PUI.Slash:Register("pvphistory", function() X.ShowHistory() end, "rated match history window (PvP)")

PUI.Layout:RegisterElement("pvp.history", { label = "Rated history", owner = OWNER, size = { 340, 300 }, default = { point = "CENTER", x = -200, y = 80 } })
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    if name == "autoTitleIDs" then X.AutoIDs() end
    X.PaintOverlay()
    if PV.active then PV.Repaint() end
    if X.history and X.history:IsShown() then X.ShowHistory() end
  end
  PV.schema["pvp." .. name] = def
  Schema:Register("pvp." .. name, def)
  s[name] = Schema:Get("pvp." .. name)
end
key("conquestOverlay", { type = "toggle", default = true, mode = "simple", label = "Progress on the conquest frame", tooltip = "A small read-only Phoenix panel inside Blizzard's conquest frame with your title progress and conquest." })
key("overlayCorner", { type = "select", default = "BOTTOMRIGHT", choices = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
  choiceLabels = { TOPLEFT = "Top left", TOPRIGHT = "Top right", BOTTOMLEFT = "Bottom left", BOTTOMRIGHT = "Bottom right" }, label = "Panel corner", tooltip = "Which corner of the conquest frame the panel sits in." })
key("autoTitleIDs", { type = "toggle", default = true, label = "Find Legend and Strategist achievements", tooltip = "While an achievement ID setting is 0, Phoenix looks up the season's title achievement in the game's list (once per season) and reads its progress." })
key("historyRows", { type = "range", default = 20, min = 5, max = 50, step = 1, label = "History rows", tooltip = "How many rated results the history window lists (/pui pvphistory)." })
key("dragHeaders", { type = "toggle", default = true, label = "Drag scoreboard headers", tooltip = "Drag a scoreboard header onto another to change the column order." })
key("shuffleRounds", { type = "toggle", default = true, label = "Solo Shuffle round results", tooltip = "Writes W or L for each round once the game shows the round count plainly (it is hidden during play)." })
