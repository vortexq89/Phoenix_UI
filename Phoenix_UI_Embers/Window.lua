local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers meter windows. Live rows take the API values as they come (secret or
-- not): bar values and AbbreviateNumbers text are handed to widgets, names go
-- to SetText; Phoenix never compares or adds them. Saved segments are plain.
-- Rows are created once per window up to the 25-row cap, never in combat.
local _, ns = ...
local EM, Theme, Media, Layout = ns.EM, PUI.Theme, PUI.Media, PUI.Layout
local Window = {}
ns.Window = Window
local MAX_ROWS, ROW_H = 25, 18
local SOURCES = { "Current", "Overall", "Saved" }

local LOOK = {
  bars = { height = 18, bar = true, alpha = 0.9 },
  compact = { height = 14, bar = true, alpha = 0.7 },
  minimal = { height = 14, bar = false, alpha = 0 },
}

local function row(w, i)
  local r = PUI:CreateFrame("StatusBar", nil, w.frame, nil, EM.OWNER)
  r:SetStatusBarTexture(Media:Texture("flat"))
  r.nameText = r:CreateFontString(nil, "OVERLAY")
  r.nameText:SetFontObject(Media:FontObject("small"))
  r.nameText:SetPoint("LEFT", 4, 0)
  r.amountText = r:CreateFontString(nil, "OVERLAY")
  r.amountText:SetFontObject(Media:FontObject("small"))
  r.amountText:SetPoint("RIGHT", -4, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ROW_H, ROW_H)
  r.icon:SetPoint("RIGHT", r, "LEFT", -2, 0)
  r:Hide()
  return r
end

function Window.Create(index)
  local w = { index = index, meter = index == 1 and EM.settings.meter or EM.METERS[index], source = "Current", rows = {} }
  local f = PUI:CreateFrame("Frame", "PhoenixUI_Embers" .. index, UIParent, nil, EM.OWNER)
  f:SetSize(240, 180)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.5)
  w.frame = f
  local title = PUI:CreateFrame("Button", nil, f, nil, EM.OWNER)
  title:SetPoint("TOPLEFT")
  title:SetPoint("TOPRIGHT")
  title:SetHeight(18)
  title.text = title:CreateFontString(nil, "OVERLAY")
  title.text:SetFontObject(Media:FontObject("header"))
  title.text:SetPoint("LEFT", 6, 0)
  title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  title:SetScript("OnClick", function(_, button) Window.Cycle(w, button == "RightButton" and "source" or "meter") end)
  w.title = title
  for i = 1, MAX_ROWS do w.rows[i] = row(w, i) end
  Layout:Place(f, "embers.window" .. index)
  return w
end

function Window.Cycle(w, what)
  if what == "source" then
    local i = 1
    for k, v in ipairs(SOURCES) do if v == w.source then i = k end end
    w.source = SOURCES[i % #SOURCES + 1]
  else
    local i = 1
    for k, v in ipairs(EM.METERS) do if v == w.meter then i = k end end
    w.meter = EM.METERS[i % #EM.METERS + 1]
  end
  Window.Update(w)
end

-- Rows to draw: { name, class, value(bar), text, max } from live or saved data.
function Window.Data(w)
  if w.source == "Saved" then
    local seg = EM.Store()[1]
    if not seg then return {}, 1, "no saved segment" end
    local out = {}
    for _, r in ipairs(seg.rows) do out[#out + 1] = { name = r.name, class = r.class, value = r.amount, text = EM.FormatNumber(r.amount), spec = r.spec } end
    return out, seg.rows[1] and seg.rows[1].amount or 1, seg.name
  end
  local ok = EM.Available()
  if not ok then return {}, 1, "meter unavailable" end
  local session = EM.Live(w.meter, w.source)
  if not session then return {}, 1, w.meter end
  local out = {}
  for _, src in ipairs(session.combatSources or {}) do
    out[#out + 1] = { name = src.name, class = src.classFilename, value = src.totalAmount, text = AbbreviateNumbers(src.totalAmount), spec = src.specIconID }
  end
  return out, session.maxAmount, w.meter .. " - " .. w.source
end

function Window.Update(w)
  if not w.frame:IsShown() and EM.active then return end
  local look = LOOK[EM.settings.look] or LOOK.bars
  local data, max, label = Window.Data(w)
  w.title.text:SetText(label)
  local shown = math.min(EM.settings.rows, MAX_ROWS)
  w.frame:SetHeight(20 + shown * (look.height + 1))
  for i, r in ipairs(w.rows) do
    local d = i <= shown and data[i]
    if d then
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", w.frame, "TOPLEFT", ROW_H + 4, -20 - (i - 1) * (look.height + 1))
      r:SetPoint("RIGHT", w.frame, "RIGHT", -2, 0)
      r:SetHeight(look.height)
      r:SetMinMaxValues(0, max)
      r:SetValue(d.value)
      local cr, cg, cb = EM.ClassColor(d.class)
      r:SetStatusBarColor(cr, cg, cb, look.alpha)
      r.nameText:SetText(d.name)
      r.amountText:SetText(d.text)
      r.icon:SetTexture(d.spec)
      r:Show()
    else
      r:Hide()
    end
  end
end
