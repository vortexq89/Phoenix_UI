local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers meter windows. Live rows take the API values as they come (secret or
-- not): bar values and AbbreviateNumbers text are handed to widgets, names go
-- to SetText; Phoenix never compares or adds them. Saved segments are plain.
-- Rows are created once per window up to the 25-row cap, never in combat.
local _, ns = ...
local EM, Theme, Media, Layout, Secret = ns.EM, PUI.Theme, PUI.Media, PUI.Layout, PUI.Secret
local Window = {}
ns.Window = Window
EM.Window = Window
local MAX_ROWS, TITLE_H = 25, 20

-- Each look is a set of starting values; every part is also its own setting.
Window.LOOKS = {
  phoenix = { bar = true, alphaScale = 1, bgScale = 1, heightScale = 1, edge = true },
  glass = { bar = true, alphaScale = 0.55, bgScale = 0.5, heightScale = 1, edge = true },
  blizzard = { bar = true, alphaScale = 0.85, bgScale = 1, heightScale = 1, edge = false },
  compact = { bar = true, alphaScale = 0.8, bgScale = 1, heightScale = 0.8, edge = true },
  minimal = { bar = false, alphaScale = 0, bgScale = 0.4, heightScale = 0.8, edge = false },
}

local function font(fs, size)
  fs:SetFontObject(Media:FontObject("small"))
  local path = PUI.Look.FontFor("meter")
  if path and fs.SetFont then fs:SetFont(path, size, PUI.Look.Flags()) end
end

local function row(w, i)
  local r = PUI:CreateFrame("StatusBar", nil, w.frame, nil, EM.OWNER)
  r.index = i
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.ghost = PUI:CreateFrame("StatusBar", nil, r, nil, EM.OWNER) -- your best pull on this boss
  r.ghost:SetAllPoints()
  r.ghost:Hide()
  r.nameText = r:CreateFontString(nil, "OVERLAY")
  r.nameText:SetPoint("LEFT", 4, 0)
  r.nameText:SetJustifyH("LEFT")
  r.amountText = r:CreateFontString(nil, "OVERLAY")
  r.amountText:SetPoint("RIGHT", -4, 0)
  r.amountText:SetJustifyH("RIGHT")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("RIGHT", r, "LEFT", -2, 0)
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self) Window.OnEnter(w, self) end)
  r:SetScript("OnLeave", function() if ns.Recap then ns.Recap.HideBreakdown() end end)
  r:SetScript("OnMouseUp", function(self, button) Window.OnClick(w, self, button) end)
  r:Hide()
  return r
end

function Window.Create(index)
  local s = EM.settings
  local w = { index = index, meter = s.meters[index] or "DamageDone", source = s.sessions[index] or "Current", rows = {}, data = {} }
  local f = PUI:CreateFrame("Frame", "PhoenixUI_Embers" .. index, UIParent, nil, EM.OWNER)
  f:SetSize(s.width, 180)
  w.bg = Theme:Backdrop(f, "surface.1")
  w.outline = Theme:Outline(f, "accent", 0.5)
  w.frame = f
  local title = PUI:CreateFrame("Button", nil, f, nil, EM.OWNER)
  title:SetPoint("TOPLEFT")
  title:SetPoint("TOPRIGHT")
  title:SetHeight(TITLE_H)
  title.bg = title:CreateTexture(nil, "BACKGROUND")
  title.bg:SetAllPoints()
  title.text = title:CreateFontString(nil, "OVERLAY")
  title.text:SetFontObject(Media:FontObject("header"))
  title.text:SetPoint("LEFT", 6, 0)
  title.right = title:CreateFontString(nil, "OVERLAY")
  title.right:SetFontObject(Media:FontObject("small"))
  title.right:SetPoint("RIGHT", -6, 0)
  title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  title:SetScript("OnClick", function(_, button) Window.Cycle(w, button == "RightButton" and "source" or "meter") end)
  w.title = title
  for i = 1, MAX_ROWS do w.rows[i] = row(w, i) end
  Layout:Place(f, "embers.window" .. index)
  return w
end

function Window.Cycle(w, what)
  local list, cur = what == "source" and EM.SESSIONS or EM.METERS, what == "source" and w.source or w.meter
  local i = 1
  for k, v in ipairs(list) do if v == cur then i = k end end
  local nextValue = list[i % #list + 1]
  PUI.Schema:Set("embers.w" .. w.index .. (what == "source" and ".session" or ".meter"), nextValue)
end

-- Rows to draw from live, threat or saved data. Each row:
-- { name, class, value (bar), text, spec, me, rank, guid, recap, pct }.
function Window.Data(w)
  local s = EM.settings
  local label = EM.METER_LABELS[w.meter] or w.meter
  if EM.IsThreat(w.meter) then
    local out = {}
    for i, t in ipairs(EM.Threat()) do
      out[i] = { name = t.name, class = t.class, value = t.value, fmt = "%.0f%%", me = t.me, rank = i }
    end
    return out, 100, label
  end
  if w.source == "Saved" then
    local seg = EM.Store()[1]
    if not seg then return {}, 1, label .. " - no saved segment" end
    local out = {}
    for i, r in ipairs(seg.rows) do
      local text = EM.FormatNumber(r.amount)
      if s.showPerSecond and r.aps and r.aps > 0 then text = text .. " (" .. EM.FormatNumber(r.aps) .. ")" end
      out[i] = { name = r.name, class = r.class, value = r.amount, text = text, spec = r.spec, me = r.me, rank = i,
        pct = (seg.total or 0) > 0 and r.amount / seg.total * 100 or nil }
    end
    local extra = seg.vsBest and string.format("  %+.1f%% vs best", seg.vsBest) or ""
    return out, seg.rows[1] and seg.rows[1].amount or 1, seg.name .. extra, seg
  end
  local ok = EM.Available()
  if not ok then return {}, 1, "Meter unavailable" end
  local session = EM.Live(w.meter, w.source)
  if not session then return {}, 1, label .. " - " .. w.source end
  local total = EM.Plain(session.totalAmount)
  local out = {}
  for i, src in ipairs(session.combatSources or {}) do
    local v = src.totalAmount
    local pv = EM.Plain(v)
    out[i] = { name = src.name, class = src.classFilename, value = v, text = EM.FormatNumber(v), spec = src.specIconID, me = src.isLocalPlayer,
      rank = i, guid = src.sourceGUID, recap = src.deathRecapID, pct = (pv and total and total > 0) and pv / total * 100 or nil }
  end
  return out, session.maxAmount, label .. " - " .. w.source
end

-- Pinned own row: when you are below the last shown row, your row takes the
-- last place and keeps its real rank number.
function Window.Visible(data, shown, pin)
  local list = {}
  for i = 1, math.min(shown, #data) do list[i] = data[i] end
  if not pin or #data <= shown then return list end
  for i = 1, shown do if data[i].me then return list end end
  for i = shown + 1, #data do
    if data[i].me then list[shown] = data[i]; return list end
  end
  return list
end

local function titleRight(w)
  local s, parts = EM.settings, {}
  if s.compareBest and not EM.IsThreat(w.meter) then
    local enc = PUI.CombatTimer and PUI.CombatTimer:Encounter()
    local best = enc and EM.BestPull(enc.id, enc.difficulty, w.meter)
    if best then parts[#parts + 1] = "best " .. EM.FormatNumber(best.aps) .. "/s" end
    w.best = best
  else
    w.best = nil
  end
  if s.headerTimer and PUI.CombatTimer then parts[#parts + 1] = PUI.CombatTimer:Text() end
  return table.concat(parts, "  ")
end

function Window.Update(w)
  if not w.frame:IsShown() and EM.active then return end
  local s = EM.settings
  local look = Window.LOOKS[s.look] or Window.LOOKS.phoenix
  local data, max, label, seg = Window.Data(w)
  w.data, w.seg = data, seg
  local rh = math.max(8, math.floor(s.rowHeight * look.heightScale + 0.5))
  local top = s.header and TITLE_H or 0
  w.title:SetShown(s.header)
  w.title.text:SetText(label)
  w.title.right:SetText(titleRight(w))
  local ar, ag, ab = Theme:Color("accent")
  w.title.bg:SetColorTexture(ar * 0.25, ag * 0.25, ab * 0.25, s.bgAlpha)
  w.bg:SetAlpha(s.bgAlpha * look.bgScale)
  for _, edge in ipairs(w.outline) do edge:SetShown(s.border and look.edge) end
  local shown = math.min(s.rows, MAX_ROWS)
  local visible = Window.Visible(data, shown, s.pinSelf)
  local iconW = s.showIcon == "spec" and rh or 0
  w.frame:SetSize(s.width + iconW, top + shown * (rh + s.spacing) + 2)
  local tex = PUI.Bars and PUI.Bars:TexturePath() or Media:Texture("flat")
  for i, r in ipairs(w.rows) do
    local d = visible[i]
    if d then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", w.frame, "TOPLEFT", iconW + 2, -top - 1 - (i - 1) * (rh + s.spacing))
      r:SetPoint("RIGHT", w.frame, "RIGHT", -2, 0)
      r:SetHeight(rh)
      r:SetStatusBarTexture(tex)
      r:SetMinMaxValues(0, max)
      r:SetValue(d.value)
      local cr, cg, cb = ar, ag, ab
      if s.classColors then cr, cg, cb = EM.ClassColor(d.class) end
      r:SetStatusBarColor(cr, cg, cb, look.bar and s.barAlpha * look.alphaScale or 0)
      r.bg:SetColorTexture(cr * 0.15, cg * 0.15, cb * 0.15, look.bar and 0.35 * s.bgAlpha or 0)
      font(r.nameText, s.fontSize)
      font(r.amountText, s.fontSize)
      if s.showRank then r.nameText:SetFormattedText("%d. %s", d.rank or i, d.name) else r.nameText:SetText(d.name) end
      if d.fmt then
        r.amountText:SetFormattedText(d.fmt, d.value)
      elseif s.showPercent and d.pct then
        r.amountText:SetText(d.text .. string.format("  %.0f%%", d.pct))
      else
        r.amountText:SetText(d.text)
      end
      r.icon:SetSize(rh, rh)
      r.icon:SetShown(s.showIcon == "spec" and d.spec ~= nil)
      if s.showIcon == "spec" then r.icon:SetTexture(d.spec) end
      -- best-pull marker on your own live row (plain best value, live max as is)
      if d.me and w.best and s.bestGhost and w.source ~= "Saved" then
        r.ghost:SetStatusBarTexture(tex)
        r.ghost:SetMinMaxValues(0, max)
        r.ghost:SetValue(w.best.amount)
        r.ghost:SetStatusBarColor(1, 1, 1, 0.18)
        r.ghost:Show()
      else
        r.ghost:Hide()
      end
      r.data = d
      r:Show()
    else
      r.data = nil
      r:Hide()
    end
  end
end

-- Hover: spell breakdown beside the window (side with more room).
function Window.OnEnter(w, r)
  if not (EM.settings.breakdownOnHover and r.data and ns.Recap) then return end
  if w.meter == "Deaths" or EM.IsThreat(w.meter) then return end
  ns.Recap.ShowBreakdown(w, r.data)
end

-- Click: a Deaths row opens that death's recap.
function Window.OnClick(w, r, button)
  if button ~= "LeftButton" or not r.data then return end
  if w.meter == "Deaths" and type(r.data.recap) == "number" and ns.Recap then ns.Recap.Open(r.data.recap, r.data.name, r.data.class) end
end
