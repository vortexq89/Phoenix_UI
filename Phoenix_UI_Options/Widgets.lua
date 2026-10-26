local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Widgets: one row per schema key (label, control, changed dot, inline help,
-- right-click reset). Rows read the value from the schema on Refresh and
-- write through Model.Commit, so every change is live.
local Options, Theme, Media = PUI.Options, PUI.Theme, PUI.Media
local Model, Schema = Options.Model, PUI.Schema
local Widgets = {}
Options.Widgets = Widgets

local ROW_H = 34
Widgets.ROW_H = ROW_H
local FLAT = PUI.Media:Texture("flat")

local function font(fs, role)
  fs:SetFontObject(Media:FontObject(role or "body"))
  return fs
end
Widgets.Font = font

local function showHelp(row)
  local def = Schema:Def(row.key)
  if not def then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(PUI.L[def.label], 1, 1, 1)
  GameTooltip:AddLine(PUI.L[def.tooltip], 0.63, 0.63, 0.66, true)
  GameTooltip:AddLine("Right-click to reset to default (" .. Model.Format(def, def.default) .. ").", 0.63, 0.63, 0.66, true)
  GameTooltip:Show()
end

local function hideHelp() GameTooltip:Hide() end

-- A small flat button in Phoenix chrome.
function Widgets.Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 90, 22)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  Theme:Paint(bg, "surface.2")
  Theme:Outline(b, "line")
  b.label = font(b:CreateFontString(nil, "OVERLAY"), "small")
  b.label:SetPoint("CENTER")
  b.label:SetText(text)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function() Theme:Paint(bg, "accent.soft") end)
  b:SetScript("OnLeave", function() Theme:Paint(bg, "surface.2") end)
  function b:SetLabel(t) self.label:SetText(t) end
  return b
end

-- Controls -------------------------------------------------------------------
local build = {}

function build.toggle(row)
  local c = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  c:SetPoint("RIGHT", -12, 0)
  c:SetScript("OnClick", function(self) Model.Commit(row.key, self:GetChecked() and true or false) end)
  row.control = c
  function row:Show_(value) c:SetChecked(value) end
end

function build.range(row, def)
  local s = CreateFrame("Slider", nil, row)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(180, 12)
  s:SetPoint("RIGHT", -60, 0)
  s:SetMinMaxValues(def.min or 0, def.max or 1)
  s:SetValueStep(def.step or 1)
  s:SetObeyStepsToValues(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(2)
  Theme:Paint(track, "line")
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(FLAT)
  thumb:SetSize(8, 14)
  Theme:Paint(thumb, "accent", 1, "vertex")
  s:SetThumbTexture(thumb)
  local text = font(row:CreateFontString(nil, "OVERLAY"), "number")
  text:SetPoint("RIGHT", -12, 0)
  text:SetJustifyH("RIGHT")
  s:SetScript("OnValueChanged", function(_, value, userInput)
    if userInput then Model.Commit(row.key, value) end
  end)
  s:SetScript("OnMouseWheel", function(_, delta)
    Model.Commit(row.key, Schema:Get(row.key) + delta * (def.step or 1))
  end)
  s:EnableMouseWheel(true)
  row.control = s
  function row:Show_(value)
    s:SetValue(value)
    text:SetText(Model.Format(def, value))
  end
end

-- Select: click opens a one-level popup list; the wheel cycles.
function build.select(row, def)
  local b = Widgets.Button(row, "", 180, function(self) Widgets.OpenChoices(self, row.key) end)
  b:SetPoint("RIGHT", -12, 0)
  b:EnableMouseWheel(true)
  b:SetScript("OnMouseWheel", function(_, delta)
    Model.Commit(row.key, Model.Cycle(def, Schema:Get(row.key), delta > 0 and -1 or 1))
  end)
  row.control = b
  function row:Show_(value) b:SetLabel(Model.Format(def, value)) end
end

function build.text(row)
  local e = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  e:SetSize(180, 20)
  e:SetPoint("RIGHT", -12, 0)
  e:SetAutoFocus(false)
  e:SetScript("OnEnterPressed", function(self)
    Model.Commit(row.key, self:GetText() or "")
    self:ClearFocus()
  end)
  e:SetScript("OnEscapePressed", function(self)
    self:SetText(Schema:Get(row.key))
    self:ClearFocus()
  end)
  row.control = e
  function row:Show_(value) if not e:HasFocus() then e:SetText(value) end end
end

-- Select popup (one level only, PUI_V2 18.2) ------------------------------------
-- Long lists wrap into columns. Media pickers preview their entry: fonts render
-- in their own face, bar textures show a strip, sounds play on hover.
local POPUP_ROWS = 20
local previewFonts = {}

function Widgets.Preview(b, def, value)
  local kind = def.preview
  if b.strip then b.strip:Hide() end
  b.label:SetFontObject(Media:FontObject("small"))
  b.previewSound = nil
  if kind == "font" then
    local path = Media:Font(value)
    local obj = previewFonts[path]
    if not obj then
      obj = CreateFont("PhoenixUIPreviewFont" .. (#Media.fontOrder + 1) .. "_" .. tostring(value):gsub("%W", ""))
      obj:SetFont(path, 12, "")
      previewFonts[path] = obj
    end
    b.label:SetFontObject(obj)
  elseif kind == "statusbar" then
    if not b.strip then
      b.strip = b:CreateTexture(nil, "ARTWORK")
      b.strip:SetPoint("TOPLEFT", 2, -2)
      b.strip:SetPoint("BOTTOMRIGHT", -2, 2)
      b.strip:SetVertexColor(0.35, 0.55, 0.85, 0.85)
    end
    b.strip:SetTexture(Media:Path("statusbar", value) or Media:Texture(value))
    b.strip:Show()
  elseif kind == "sound" then
    b.previewSound = value
  end
end

local popup
function Widgets.OpenChoices(anchor, key)
  local def = Schema:Def(key)
  if not popup then
    popup = CreateFrame("Frame", "PhoenixUIOptionsChoices", UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    Theme:Backdrop(popup, "surface.1")
    Theme:Outline(popup, "line")
    popup.buttons = {}
    popup:EnableMouse(true)
    tinsert(UISpecialFrames, "PhoenixUIOptionsChoices")
  end
  local choices = Model.Choices(def)
  for i = 1, math.max(#choices, #popup.buttons) do
    local b = popup.buttons[i]
    if i <= #choices then
      if not b then
        b = Widgets.Button(popup, "", 176, nil)
        local col, rowi = math.floor((i - 1) / POPUP_ROWS), (i - 1) % POPUP_ROWS
        b:SetPoint("TOPLEFT", 2 + col * 178, -2 - rowi * 22)
        b:HookScript("OnEnter", function(self) if self.previewSound then Media:PlaySound(self.previewSound) end end)
        popup.buttons[i] = b
      end
      local value = choices[i]
      b:SetLabel(Model.Format(def, value) .. (value == Schema:Get(key) and "  *" or ""))
      Widgets.Preview(b, def, value)
      b:SetScript("OnClick", function() popup:Hide(); Model.Commit(key, value) end)
      b:Show()
    elseif b then
      b:Hide()
    end
  end
  local cols = math.max(1, math.ceil(#choices / POPUP_ROWS))
  popup:SetSize(cols * 178 + 2, math.min(#choices, POPUP_ROWS) * 22 + 4)
  popup:ClearAllPoints()
  popup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
  popup:SetClampedToScreen(true)
  popup:Show()
  Widgets.popup = popup
end

-- Rows ---------------------------------------------------------------------------
function Widgets.Row(parent, key)
  local def = Schema:Def(key)
  local row = CreateFrame("Frame", nil, parent)
  row.key = key
  row:SetHeight(ROW_H)
  row:EnableMouse(true)
  local hover = row:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints()
  Theme:Paint(hover, "surface.2")
  hover:Hide()
  row.dot = row:CreateTexture(nil, "ARTWORK")
  row.dot:SetSize(6, 6)
  row.dot:SetPoint("LEFT", 6, 0)
  Theme:Paint(row.dot, "accent")
  row.label = font(row:CreateFontString(nil, "OVERLAY"), "body")
  row.label:SetPoint("LEFT", 18, 6)
  row.label:SetText(PUI.L[def.label])
  row.sub = font(row:CreateFontString(nil, "OVERLAY"), "small")
  row.sub:SetPoint("LEFT", 18, -8)
  row.sub:SetPoint("RIGHT", -260, 0)
  row.sub:SetJustifyH("LEFT")
  row.sub:SetWordWrap(false)
  row.sub:SetText(PUI.L[def.tooltip])
  Theme:Paint(row.sub, "text.secondary", 1, "text")
  row:SetScript("OnEnter", function(self) hover:Show(); showHelp(self) end)
  row:SetScript("OnLeave", function() hover:Hide(); hideHelp() end)
  row:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then Schema:Reset(self.key) end
  end)
  build[def.type](row, def)
  function row:Refresh()
    self:Show_(Schema:Get(self.key))
    if Model.IsChanged(self.key) then self.dot:Show() else self.dot:Hide() end
  end
  row:Refresh()
  return row
end
