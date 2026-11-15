local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PvP windows, all Phoenix's own frames (nothing on Blizzard's PvP frame is
-- rewritten): the rated card (docks beside the PvP window or stands alone),
-- the scoreboard and the leave countdown bar. Built on first use; text
-- comes from Lines(), which the settings preview also draws.
local _, ns = ...
local R, C, M = ns.Rated, ns.Columns, ns.Match
local Secret = PUI.Secret
local W = {}
ns.Card = W

local function font(fs, role) fs:SetFontObject(PUI.Media:FontObject(role or "small")) end
local function panel(name, w, h, element)
  local f = PUI:CreateFrame("Frame", name, UIParent, nil, "PvP")
  f:SetSize(w, h)
  f:SetFrameStrata("MEDIUM")
  PUI.Theme:Backdrop(f, "surface.0")
  local accent = f:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT"); accent:SetHeight(2)
  PUI.Theme:Paint(accent, "accent")
  f.title = f:CreateFontString(nil, "OVERLAY"); font(f.title, "header")
  f.title:SetPoint("TOPLEFT", 12, -10)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)
  if element then PUI.Layout:Place(f, element) end
  f:Hide()
  return f
end
local function button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onClick)
  return b
end

-- Lines(s, db, season) -> { {text, role}, ... } for the card and the preview.
function W.Lines(s, db, season, snap)
  snap = snap or R.Snapshot()
  local out = {}
  local function add(t, role) out[#out + 1] = { t, role or "small" } end
  if s.cardRatings then
    add("Ratings", "normal")
    for _, b in ipairs(R.BRACKETS) do
      local i = snap[b.id]
      if i and s["bracket_" .. b.id] then
        local wk = b.rounds and i.roundsWeek and string.format("rounds %d-%d", i.roundsWeekWon or 0, i.roundsWeek - (i.roundsWeekWon or 0))
          or string.format("%d-%d", i.weekWon or 0, (i.weekPlayed or 0) - (i.weekWon or 0))
        add(string.format("%-12s %4d   best %d   this week %s", b.label, i.rating or 0, i.best or 0, wk))
      end
    end
  end
  local last = db.history and db.history[1]
  if s.cardChange and last then
    add(string.format("Last match: %s %+d (now %d)", last.bracketLabel or "", last.change or 0, last.rating or 0), "normal")
  end
  if s.cardProgress then
    for _, t in ipairs(R.TITLES) do
      if s["title_" .. t.id] then
        local have, need, src = R.Progress(t.id, db, season, s)
        add(string.format("%s: %d / %d wins at %d+%s%s", t.label, math.min(have, need), need, s["rating_" .. t.id] or 2400,
          have >= need and "  - done" or "", src == "phoenix" and "  (counted by Phoenix)" or ""))
      end
    end
  end
  if s.cardWeekly then
    local won, lost = R.WeekRecord(snap)
    local cq, cqMax = R.Conquest()
    local open, slots = R.Vault()
    local parts = { string.format("This week %d-%d", won, lost) }
    if cq then parts[#parts + 1] = cqMax > 0 and string.format("Conquest %d / %d", cq, cqMax) or ("Conquest " .. cq) end
    if open then parts[#parts + 1] = string.format("Great Vault %d / %d", open, math.max(slots, 3)) end
    add(table.concat(parts, "   "))
  end
  local round = s.shuffleTracker and M.RoundText()
  if round then add("Solo Shuffle: " .. round, "normal") end
  if s.cardLinks then add("Arena frames, DR, trinkets, match card -> Arena.  Queue status -> Group Finder.", "small") end
  return out
end

function W.BuildCard()
  local f = panel("PhoenixUIPvPCard", 400, 220, "pvp.card")
  f.title:SetText("Rated PvP")
  f.lines = {}
  f.trainBG = button(f, "Training Grounds", 130, function() M.QueueTraining("bg") end)
  f.trainBG:SetPoint("BOTTOMLEFT", 12, 10)
  f.trainArena = button(f, "Training arena", 120, function() M.QueueTraining("arena") end)
  f.trainArena:SetPoint("LEFT", f.trainBG, "RIGHT", 6, 0)
  f.score = button(f, "Scoreboard", 100, function() W.ShowScore(ns.PvP.settings) end)
  f.score:SetPoint("LEFT", f.trainArena, "RIGHT", 6, 0)
  W.card = f
  return f
end
function W.PaintCard(s, db, season)
  local f = W.card
  if not (f and f:IsShown()) then return end
  local lines = W.Lines(s, db, season)
  local y = -34
  for i, l in ipairs(lines) do
    local fs = f.lines[i]
    if not fs then fs = f:CreateFontString(nil, "OVERLAY"); fs:SetJustifyH("LEFT"); f.lines[i] = fs end
    font(fs, l[2]); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 12, y); fs:SetPoint("RIGHT", -12, 0)
    fs:SetText(l[1]); fs:Show()
    y = y - (l[2] == "normal" and 18 or 15)
  end
  for i = #lines + 1, #f.lines do f.lines[i]:Hide() end
  local tg = M.TrainingStatus()
  f.trainBG:SetShown(s.training and tg.available)
  f.trainArena:SetShown(s.training and tg.available)
  f.trainBG:SetText(tg.bgWon and "Training BG (won)" or "Training Grounds")
  f:SetHeight(math.max(120, -y + 44))
  f:SetScale(s.cardScale)
end
function W.ToggleCard(s, db, season, show)
  local f = W.card or W.BuildCard()
  if show == nil then show = not f:IsShown() end
  f:SetShown(show)
  W.PaintCard(s, db, season)
end

-- Scoreboard --------------------------------------------------------------
function W.BuildScore()
  local f = panel("PhoenixUIPvPScore", 640, 360, "pvp.scoreboard")
  f.title:SetText("Scoreboard")
  f.note = f:CreateFontString(nil, "OVERLAY"); font(f.note, "small"); f.note:SetPoint("TOPRIGHT", -30, -14)
  f.heads, f.rows = {}, {}
  W.score = f
  return f
end
local function cell(parent, list, i)
  local fs = list[i]
  if not fs then fs = parent:CreateFontString(nil, "OVERLAY"); font(fs, "small"); fs:SetJustifyH("LEFT"); list[i] = fs end
  return fs
end
function W.PaintScore(s)
  local f = W.score
  if not (f and f:IsShown()) then return end
  local cols = C:Pick(s.columns)
  local ready = C.Ready()
  f.note:SetText(ready and "Click a header to sort" or "Scores are hidden by the game until the match ends")
  local x = 12
  for i, col in ipairs(cols) do
    local h = f.heads[i]
    if not h then
      h = CreateFrame("Button", nil, f); h:SetHeight(18)
      h.fs = h:CreateFontString(nil, "OVERLAY"); font(h.fs, "small"); h.fs:SetAllPoints(); h.fs:SetJustifyH("LEFT")
      f.heads[i] = h
    end
    h:SetWidth(col.width); h:ClearAllPoints(); h:SetPoint("TOPLEFT", x, -36)
    h.fs:SetText(col.label .. (s.sortBy == col.id and (s.sortDesc and " v" or " ^") or ""))
    PUI.Theme:Paint(h.fs, "accent", nil, "text")
    h:SetScript("OnClick", function()
      if PUI.Schema:Get("pvp.sortBy") == col.id then PUI.Schema:Set("pvp.sortDesc", not s.sortDesc) else PUI.Schema:Set("pvp.sortBy", col.id) end
    end)
    h:Show()
    x = x + col.width + 6
  end
  for i = #cols + 1, #f.heads do f.heads[i]:Hide() end
  f:SetWidth(math.max(360, x + 12))
  local rows = ready and C.Sort(C.Rows(), s.sortBy, s.sortDesc) or {}
  local guid = UnitGUID("player")
  local myFaction = rawget(_G, "GetBattlefieldArenaFaction") and GetBattlefieldArenaFaction()
  local n = 0
  for r, row in ipairs(rows) do
    if r > 40 then break end
    local line = f.rows[r] or { cells = {} }
    f.rows[r] = line
    if not line.bg then line.bg = f:CreateTexture(nil, "BACKGROUND", nil, 1); line.bg:SetHeight(16) end
    local mine = C.Mine(row, guid, myFaction)
    line.bg:ClearAllPoints(); line.bg:SetPoint("TOPLEFT", 8, -56 - (r - 1) * 17); line.bg:SetPoint("RIGHT", -8, 0)
    if mine == "me" and s.highlightMe then PUI.Theme:Paint(line.bg, "accent", 0.25); line.bg:Show()
    elseif mine == "team" and s.highlightTeam then PUI.Theme:Paint(line.bg, "surface.2", 0.6); line.bg:Show()
    else line.bg:Hide() end
    local cx = 12
    for i, col in ipairs(cols) do
      local fs = cell(f, line.cells, i)
      fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", cx, -56 - (r - 1) * 17); fs:SetWidth(col.width)
      local v = col.value(row)
      local txt = C.Format(v, col.format)
      if txt == nil then fs:SetFormattedText("%s", v) else fs:SetText(txt) end -- secret goes to the widget
      if col.id == "name" and s.classColors and row.classToken and not Secret.IsSecret(row.classToken) then
        local c = C_ClassColor.GetClassColor(row.classToken)
        if c then fs:SetTextColor(c.r, c.g, c.b) end
      else fs:SetTextColor(1, 1, 1) end
      fs:Show(); cx = cx + col.width + 6
    end
    for i = #cols + 1, #line.cells do line.cells[i]:Hide() end
    n = r
  end
  for r = n + 1, #f.rows do
    local line = f.rows[r]
    line.bg:Hide()
    for _, fs in ipairs(line.cells) do fs:Hide() end
  end
  f:SetHeight(math.max(120, 70 + n * 17))
  W.scoreRows = n
end
function W.ShowScore(s, show)
  local f = W.score or W.BuildScore()
  if show == nil then show = true end
  f:SetShown(show)
  W.PaintScore(s)
end

-- Leave countdown bar -----------------------------------------------------
function W.BuildLeave()
  local f = panel("PhoenixUIPvPLeave", 340, 64, "pvp.leave")
  f.title:SetText("Battleground over")
  f.text = f:CreateFontString(nil, "OVERLAY"); font(f.text, "normal"); f.text:SetPoint("TOPLEFT", 12, -30)
  f.now = button(f, "Leave now", 100, function() M.Leave() end); f.now:SetPoint("BOTTOMRIGHT", -112, 8)
  f.stay = button(f, "Stay", 90, function() M.Cancel() end); f.stay:SetPoint("BOTTOMRIGHT", -14, 8)
  W.leave = f
  return f
end
function W.PaintLeave()
  if not M.left then if W.leave then W.leave:Hide() end return end
  local f = W.leave or W.BuildLeave()
  f:Show()
  if M.left > 0 then f.text:SetText(string.format("Leaving in 0:%02d", M.left))
  else f.text:SetText("Leaving when you are out of combat") end
end
