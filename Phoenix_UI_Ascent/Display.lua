local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ascent display: the M+ block (docked at the top of the Phoenix quest tracker
-- or standalone) and the battle res + Bloodlust widget. Text widgets get the
-- game's values as they come; colours and pace come from plain values only.
local _, ns = ...
local AS, Theme, Media, Layout, Secret, Schema = ns.AS, PUI.Theme, PUI.Media, PUI.Layout, PUI.Secret, PUI.Schema
local OWNER = AS.OWNER
local Display = { deathLines = {} }
ns.Display = Display
AS.Display = Display
local s = AS.settings
local PAD = 8

-- Text-safe value without touching a secret (no comparison, no "or").
function Display.Str(v) if Secret.IsSecret(v) or type(v) == "string" then return v end return "" end

local function text(f, role)
  local t = f:CreateFontString(nil, "OVERLAY")
  t:SetFontObject(Media:FontObject(role))
  t:SetJustifyH("LEFT")
  return t
end

local function bar(f, h)
  local b = PUI:CreateFrame("StatusBar", nil, f, nil, OWNER)
  b:SetHeight(h)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0, 0, 0, 0.5)
  return b
end

local function build()
  local f = Display.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_Ascent", UIParent, nil, OWNER)
  f:SetSize(s.width, 200)
  f.bg = Theme:Backdrop(f, "surface.1")
  f.edge = Theme:Outline(f, "accent", 0.5)
  f.title = text(f, "body")
  f.affixes = text(f, "small")
  f.timer = text(f, "header")
  f.marks = text(f, "small")
  f.timeBar = bar(f, 6)
  f.tick3 = f.timeBar:CreateTexture(nil, "OVERLAY")
  f.tick2 = f.timeBar:CreateTexture(nil, "OVERLAY")
  for _, t in ipairs({ f.tick3, f.tick2 }) do t:SetSize(2, 10); t:SetColorTexture(1, 1, 1, 0.9) end
  f.forcesLabel = text(f, "small")
  f.forces = bar(f, 10)
  f.forcesText = f.forces:CreateFontString(nil, "OVERLAY")
  f.forcesText:SetFontObject(Media:FontObject("small"))
  f.forcesText:SetPoint("CENTER")
  f.pace = text(f, "small")
  f.splits = text(f, "small")
  f.status = text(f, "small")
  f.kicks = text(f, "small")
  f.note = text(f, "small")
  f.deathBtn = PUI:CreateFrame("Button", nil, f, nil, OWNER) -- the death chips row: click opens the recap
  f.chips = {}
  f.deathBtn:SetScript("OnClick", function() Display.OpenLastRecap() end)
  Display.frame = f
  AS.frame = f
  Display.Place()
  return f
end

-- Docked at the top of the quest tracker (when it runs and the user wants it
-- there) or placed by Studio as its own window.
function Display.Host()
  local QT = PUI.QuestTracker
  if s.placement == "tracker" and QT and QT.active and QT.frame then return QT.frame end
end

function Display.Place()
  local f = Display.frame
  if not f then return end
  local host = Display.Host()
  f:ClearAllPoints()
  if host then
    f:SetParent(host)
    f:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    Display.docked = true
  else
    f:SetParent(UIParent)
    Layout:Place(f, "ascent.timer")
    Display.docked = false
  end
end

-- Height of the block when docked (the tracker pushes its quests below it).
function Display.Height()
  local f = Display.frame
  if not (f and f:IsShown()) then return 0 end
  return (f:GetHeight() or 0) * (f:GetScale() or 1)
end

local function line(f, t, y, h)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
  t:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
  return y + (h or 14)
end

function Display.ForcesText(c, pct)
  local q, t = AS.Plain(c.quantity), AS.Plain(c.totalQuantity)
  if s.forcesFormat == "count" and q and t then return string.format("%d/%d", q, t) end
  if pct and s.forcesFormat == "percent" then return string.format("%.1f%%", pct) end
  if pct and q and t then return string.format("%.1f%% (%d/%d)", pct, q, t) end
  return c.quantityString -- the game's own text, possibly secret
end

function Display.PaceText(pace, elapsed, limit)
  if not pace then return "Pace: shown when forces are readable" end
  local parts = {}
  local best = AS.Upgrades(elapsed, limit)
  for _, tier in ipairs({ 3, 2, 1 }) do
    if s.paceTiers == "all" or tier == math.max(1, best) then
      local d = pace[tier]
      local col = d >= 0 and "|cff5ad16a" or "|cffff6a5a"
      parts[#parts + 1] = string.format("+%d %s%+.1f%%|r", tier, col, d)
    end
  end
  return "Pace " .. table.concat(parts, "  ")
end

function Display.Draw()
  local run = AS.run
  if not run then Display.Hide() return end
  local f = build()
  Display.Place()
  f:SetScale(s.scale)
  f:SetWidth(s.width)
  f.bg:SetAlpha(s.bgAlpha)
  local elapsed = AS.Elapsed() or 0
  local limit = run.limit or 0
  local y = 6
  f.title:SetText(string.format("%s  |cffe8a33d+%d|r", run.name or "", run.level or 0))
  y = line(f, f.title, y, 16)
  f.affixes:SetText(table.concat(run.affixes, ", "))
  y = line(f, f.affixes, y)
  local up = limit > 0 and AS.Upgrades(elapsed, limit) or 1
  local tr, tg, tb = 1, 1, 1
  if up == 0 then tr, tg, tb = 1, 0.35, 0.3 elseif up == 1 then tr, tg, tb = 1, 0.82, 0.3 end
  f.timer:SetTextColor(tr, tg, tb)
  f.timer:SetText(AS.Clock(elapsed, s.timerFormat) .. " / " .. AS.Clock(limit))
  y = line(f, f.timer, y + 2, 20)
  local t = AS.Thresholds(limit)
  f.marks:SetText(string.format("+3 %s   +2 %s", up >= 3 and AS.Clock(t[1] - elapsed) or "-", up >= 2 and AS.Clock(t[2] - elapsed) or "-"))
  y = line(f, f.marks, y)
  -- timer bar with +3 / +2 marks
  local w = s.width - PAD * 2
  f.timeBar:ClearAllPoints()
  f.timeBar:SetPoint("TOPLEFT", PAD, -y)
  f.timeBar:SetWidth(w)
  f.timeBar:SetStatusBarTexture(PUI.Bars:TexturePath())
  f.timeBar:SetStatusBarColor(tr * 0.9, tg * 0.7, tb * 0.3, 1)
  f.timeBar:SetMinMaxValues(0, math.max(1, limit))
  f.timeBar:SetValue(math.min(elapsed, limit))
  for i, tick in ipairs({ f.tick3, f.tick2 }) do
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", f.timeBar, "LEFT", w * (i == 1 and AS.PLUS3 or AS.PLUS2), 0)
    tick:SetShown(s.marks)
  end
  y = y + 12
  AS.CheckThresholds(elapsed)
  -- enemy forces + pace
  local c = AS.Forces()
  if c then
    local pct = AS.ForcesPercent(c)
    f.forcesLabel:SetText("Enemy forces")
    y = line(f, f.forcesLabel, y)
    f.forces:ClearAllPoints()
    f.forces:SetPoint("TOPLEFT", PAD, -y)
    f.forces:SetWidth(w)
    f.forces:SetStatusBarTexture(PUI.Bars:TexturePath())
    local ar, ag, ab = Theme:Color("accent")
    f.forces:SetStatusBarColor(ar, ag, ab, 1)
    f.forces:SetMinMaxValues(0, c.totalQuantity)
    f.forces:SetValue(c.quantity)
    f.forcesText:SetText(Display.ForcesText(c, pct))
    f.forces:Show()
    f.forcesLabel:Show()
    y = y + 14
    if s.pace then
      f.pace:SetText(Display.PaceText(AS.Pace(elapsed, limit, pct), elapsed, limit))
      y = line(f, f.pace, y)
      f.pace:Show()
    else
      f.pace:Hide()
    end
  else
    f.forces:Hide(); f.forcesLabel:Hide(); f.pace:Hide()
  end
  -- splits vs best
  if s.splits and #run.splits > 0 then
    local best = AS.CompareRun(run.mapID, run.level)
    local lines = {}
    for i, sp in ipairs(run.splits) do
      local pb = best and best.splits and best.splits[i]
      local diff = pb and (sp.at - pb.at)
      local col = diff and (diff <= 0 and "|cff5ad16a" or "|cffff6a5a") or ""
      lines[#lines + 1] = string.format("|cff5ad16a+|r %s %s%s", sp.name or "Boss", AS.Clock(sp.at), diff and string.format("  %s%+ds|r", col, math.floor(diff)) or "")
    end
    f.splits:SetText(table.concat(lines, "\n"))
    y = line(f, f.splits, y, 14 * #lines)
    f.splits:Show()
  else
    f.splits:SetText(""); f.splits:Hide()
  end
  -- deaths, battle res, Bloodlust
  local deaths, lost = C_ChallengeMode.GetDeathCount()
  local parts = { string.format("Deaths %s (-%s)", Secret.ToText(deaths), Secret.IsSecret(lost) and "?" or AS.Clock(lost)) }
  if s.brLust and s.brLustPlacement == "block" then parts[#parts + 1] = Display.BrLustText() end
  f.status:SetText(table.concat(parts, "   "))
  y = line(f, f.status, y)
  -- kicks and the death log: one small text per entry so names and counts go
  -- to the formatter as they come (they can be secret during the key)
  y = Display.Chips(f, "kicks", s.kicks and PUI.Embers and PUI.Embers.Interrupts("Overall") or {}, 5, "Kicks", y, w,
    function(fs, r) fs:SetFormattedText("%s %s", Display.Str(r.name), PUI.Format.Number(r.count)) end)
  local deaths = (s.deathLog > 0 and PUI.Embers) and PUI.Embers.Deaths("Overall") or {}
  local recent = {}
  for i = math.max(1, #deaths - s.deathLog + 1), #deaths do recent[#recent + 1] = deaths[i] end
  Display.lastDeath = deaths[#deaths]
  y = Display.Chips(f, "deaths", recent, s.deathLog, "Deaths", y, w, function(fs, r) fs:SetText(Display.Str(r.name)) end)
  f.deathBtn:ClearAllPoints()
  f.deathBtn:SetPoint("TOPLEFT", PAD, -(y - 14))
  f.deathBtn:SetSize(w, 14)
  f.deathBtn:SetShown(#recent > 0)
  local notes = Schema:Get("ascent.notes")
  local note = s.notes and notes[tostring(run.mapID)] or nil
  f.note:SetText(note or "")
  if note then y = line(f, f.note, y) end
  f:SetHeight(y + 6)
  f:Show()
  Display.DrawBrLust()
  if Display.docked and PUI.QuestTracker then PUI.QuestTracker.Refresh() end
end

-- A labelled row of up to `max` small texts (pooled per row id).
function Display.Chips(f, id, list, max, label, y, w, paint)
  local row = f.chips[id]
  if not row then
    row = { label = text(f, "small"), items = {} }
    f.chips[id] = row
  end
  local n = math.min(#list, max)
  row.label:SetShown(n > 0)
  for i = n + 1, #row.items do row.items[i]:Hide() end
  if n == 0 then return y end
  row.label:ClearAllPoints()
  row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
  row.label:SetText("|cff9a9a9a" .. label .. "|r")
  local x0 = PAD + 44
  local cw = (w - 44) / math.max(1, n)
  for i = 1, n do
    local fs = row.items[i]
    if not fs then fs = text(f, "small"); fs:SetWordWrap(false); row.items[i] = fs end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + (i - 1) * cw, -y)
    fs:SetWidth(cw - 4)
    local r, g, b = 1, 1, 1
    if PUI.Embers then r, g, b = PUI.Embers.ClassColor(list[i].class) end
    fs:SetTextColor(r, g, b)
    paint(fs, list[i])
    fs:Show()
  end
  return y + 14
end

function Display.OpenLastRecap()
  local d = Display.lastDeath
  if d and PUI.Embers and PUI.Embers.Recap then PUI.Embers.Recap.Open(d.recap, d.name, d.class) end
end

function Display.BrLustText()
  local br = AS.BattleRes()
  local lust, left = AS.Lust()
  local brText = br and string.format("BR %s", Secret.ToText(br.charges)) or "BR -"
  local lustText = lust == "ready" and "|cff5ad16aLust ready|r" or lust == "sated" and string.format("|cffff6a5aSated %s|r", left and AS.Clock(left) or "") or "Lust ?"
  return brText .. "   " .. lustText
end

-- Standalone widget (setting), also useful in raid boss fights.
function Display.DrawBrLust()
  local show = AS.active and s.brLust and s.brLustPlacement == "standalone" and (AS.run ~= nil or (PUI.CombatTimer and PUI.CombatTimer:Kind() == "encounter"))
  local w = Display.brFrame
  if not show then if w then w:Hide() end return end
  if not w then
    w = PUI:CreateFrame("Frame", "PhoenixUI_AscentBrLust", UIParent, nil, OWNER)
    w:SetSize(150, 24)
    Theme:Backdrop(w, "surface.1")
    Theme:Outline(w, "accent", 0.5)
    w.text = text(w, "small")
    w.text:SetPoint("LEFT", 6, 0)
    Layout:Place(w, "ascent.brlust")
    Display.brFrame = w
  end
  w.text:SetText(Display.BrLustText())
  w:Show()
end

function Display.Hide()
  if Display.frame then Display.frame:Hide() end
  if Display.brFrame then Display.brFrame:Hide() end
  if PUI.QuestTracker and PUI.QuestTracker.active then PUI.QuestTracker.Refresh() end
end
