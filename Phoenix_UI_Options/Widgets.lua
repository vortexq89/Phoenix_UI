local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Widgets: one settings row per schema key (label + description left, the
-- control right, changed dot, tooltip, right-click reset) built from the Kit,
-- and the dropdown menu whose rows preview fonts, bar textures and sounds.
-- Rows read the schema on Refresh and write through Model.Commit (live).
local Options, Theme, Media = PUI.Options, PUI.Theme, PUI.Media
local Model, Schema, Kit, A = Options.Model, PUI.Schema, Options.Kit, Options.Assets
local Widgets = {}
Options.Widgets = Widgets

local ROW_H = 50
Widgets.ROW_H = ROW_H
local LEGACY = { header = "title", body = "body", small = "small", number = "mono" }

function Widgets.Font(fs, role)
  fs:SetFontObject(Kit.FontObject(LEGACY[role] or role or "body"))
  return fs
end

function Widgets.Button(parent, text, width, onClick)
  local b = Kit.Button(parent, text, width, onClick, "secondary")
  b:SetHeight(26)
  return b
end

local function showHelp(row)
  local def = Schema:Def(row.key)
  if not def then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(PUI.L[def.label], 0.93, 0.91, 0.89)
  GameTooltip:AddLine(PUI.L[def.tooltip], 0.73, 0.71, 0.69, true)
  GameTooltip:AddLine("Applies live. Right-click to reset (" .. Model.Format(def, def.default) .. ").", 1, 0.66, 0.30, true)
  GameTooltip:Show()
end

-- Choices with a label override (def.choiceLabels) or prettified values.
local function choiceLabel(def, value)
  if def.choiceLabels and def.choiceLabels[value] then return def.choiceLabels[value] end
  local s = tostring(value)
  return (s:gsub("^%l", string.upper))
end
Widgets.ChoiceLabel = choiceLabel

-- Controls ------------------------------------------------------------------
-- build[type](row, def) creates row.control and row:Show_(value). Controls.lua
-- adds color, keybind, anchor, list and grid; plugins use the same table.
local build = {}
Widgets.build = build

function build.toggle(row)
  local c = Kit.Toggle(row, function(v) Model.Commit(row.key, v) end)
  c:SetPoint("RIGHT", -14, 0)
  row.control = c
  function row:Show_(value) c:SetValue_(value) end
end

function build.range(row, def)
  local s = Kit.Slider(row, def, 300, function(v) Model.Commit(row.key, v) end)
  s:SetPoint("RIGHT", -14, 0)
  row.control = s
  function row:Show_(value) s:SetValue_(value) end
end

-- Dropdown button: shows the current value (in its own font / with a bar sample).
local function dropdown(row, def)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(220, 30)
  local bg = Theme:Slice(b, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  b.text = Kit.Text(b, "label", "text.primary")
  b.text:SetPoint("LEFT", 12, 0)
  b.text:SetPoint("RIGHT", -28, 0)
  b.text:SetWordWrap(false)
  local chev = Kit.Icon(b, A.chevron, 12)
  chev:SetPoint("RIGHT", -10, 0)
  Theme:Paint(chev, "muted", 1, "vertex")
  b.sample = b:CreateTexture(nil, "ARTWORK")
  b.sample:SetPoint("LEFT", 12, 0)
  b.sample:SetSize(90, 10)
  b.sample:Hide()
  b:SetScript("OnClick", function(self) Widgets.OpenChoices(self, row.key) end)
  b:EnableMouseWheel(true)
  b:SetScript("OnMouseWheel", function(_, delta)
    Model.Commit(row.key, Model.Cycle(def, Schema:Get(row.key), delta > 0 and -1 or 1))
  end)
  return b
end

function build.select(row, def)
  local choices = def.choices
  if type(choices) == "table" and #choices <= 5 and not def.preview then
    local labels = {}
    for i = 1, #choices do labels[i] = choiceLabel(def, choices[i]) end
    local seg = Kit.Segmented(row, choices, labels, function(v) Model.Commit(row.key, v) end)
    seg:SetPoint("RIGHT", -14, 0)
    row.control = seg
    function row:Show_(value) seg:SetValue_(value) end
    return
  end
  local b = dropdown(row, def)
  b:SetPoint("RIGHT", -14, 0)
  row.control = b
  function row:Show_(value)
    b.text:SetText(choiceLabel(def, value))
    Widgets.Preview(b, def, value)
  end
end

function build.text(row)
  local e = CreateFrame("EditBox", nil, row)
  e:SetSize(300, 30)
  e:SetPoint("RIGHT", -14, 0)
  e:SetAutoFocus(false)
  e:SetFontObject(Kit.FontObject("mono"))
  e:SetTextInsets(10, 10, 0, 0)
  local bg = Theme:Slice(e, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  e:SetScript("OnEnterPressed", function(self) Model.Commit(row.key, self:GetText() or ""); self:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(self) self:SetText(Schema:Get(row.key)); self:ClearFocus() end)
  row.control = e
  function row:Show_(value) if not e:HasFocus() then e:SetText(value) end end
end

-- Media previews ---------------------------------------------------------------
local previewFonts = {}
local function fontObjectFor(path)
  local o = previewFonts[path]
  if not o then
    o = CreateFont("PhoenixUIPreviewFont" .. (#previewFonts + 1) .. tostring(#path))
    o:SetFont(path, 13, "")
    previewFonts[path] = o
    previewFonts[#previewFonts + 1] = o
  end
  return o
end
Widgets.FontObjectFor = fontObjectFor

-- b: a dropdown button or menu row with .text and optional .sample.
function Widgets.Preview(b, def, value)
  local kind = def.preview
  if b.sample then b.sample:Hide() end
  b.text:SetFontObject(Kit.FontObject("label"))
  b.previewSound = nil
  if kind == "font" then
    b.text:SetFontObject(fontObjectFor(Media:Font(value)))
  elseif kind == "statusbar" and b.sample then
    b.sample:SetTexture(Media:Path("statusbar", value) or Media:Texture(value))
    Theme:Paint(b.sample, "accent", 1, "vertex")
    b.sample:Show()
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", b.sample, "RIGHT", 10, 0)
    b.text:SetPoint("RIGHT", -28, 0)
  elseif kind == "sound" then
    b.previewSound = value
  end
end

-- Dropdown menu ----------------------------------------------------------------
local MENU_ROWS, MENU_W, MENU_H = 14, 260, 30
local menu

local function menuRow(i)
  local r = menu.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, menu.content)
  r:SetSize(MENU_W - 12, MENU_H)
  r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * MENU_H)
  r.text = Kit.Text(r, "label", "text.primary")
  r.text:SetPoint("LEFT", 10, 0)
  r.text:SetPoint("RIGHT", -24, 0)
  r.text:SetWordWrap(false)
  r.sample = r:CreateTexture(nil, "ARTWORK")
  r.sample:SetSize(90, 12)
  r.sample:SetPoint("LEFT", 10, 0)
  r.check = Kit.Icon(r, A.check, 14)
  r.check:SetPoint("RIGHT", -8, 0)
  Theme:Paint(r.check, "accent", 1, "vertex")
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  r:SetScript("OnEnter", function(self) if self.previewSound then Media:PlaySound(self.previewSound) end end)
  menu.rows[i] = r
  return r
end

local function ensureMenu()
  if not menu then
    menu = CreateFrame("Frame", "PhoenixUIOptionsChoices", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    local bg = Theme:Slice(menu, A.card, 28)
    bg:SetVertexColor(0.09, 0.10, 0.13, 0.98)
    Theme:Slice(menu, A.shadowTight, 20, "BACKGROUND", -7):SetVertexColor(0, 0, 0, 0.8)
    local scroll = CreateFrame("ScrollFrame", nil, menu)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(MENU_W, 10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, content:GetHeight() - self:GetHeight())
      self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * MENU_H * 2)))
    end)
    menu.scroll, menu.content, menu.rows = scroll, content, {}
    tinsert(UISpecialFrames, "PhoenixUIOptionsChoices")
  end
  return menu
end

-- Generic pick list: values, a label(value) function, the checked value and
-- onPick(value). def (optional) adds font / texture / sound samples.
function Widgets.OpenMenu(anchor, choices, label, current, onPick, def)
  ensureMenu()
  for i = 1, math.max(#choices, #menu.rows) do
    local r = menuRow(i)
    local value = choices[i]
    if value ~= nil then
      r.text:SetText(label(value))
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", 10, 0)
      r.text:SetPoint("RIGHT", -24, 0)
      if def then Widgets.Preview(r, def, value) else r.text:SetFontObject(Kit.FontObject("label")); r.sample:Hide(); r.previewSound = nil end
      r.check:SetShown(value == current)
      r:SetScript("OnClick", function() menu:Hide(); onPick(value) end)
      r:Show()
    else
      r:Hide()
    end
  end
  menu.content:SetHeight(#choices * MENU_H + 12)
  menu:SetSize(MENU_W, math.min(#choices, MENU_ROWS) * MENU_H + 12)
  menu.scroll:SetVerticalScroll(0)
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
  menu:SetClampedToScreen(true)
  menu:Show()
  Widgets.popup = menu
  return menu
end

function Widgets.OpenChoices(anchor, key)
  local def = Schema:Def(key)
  return Widgets.OpenMenu(anchor, Model.Choices(def), function(v) return choiceLabel(def, v) end, Schema:Get(key),
    function(v) Model.Commit(key, v) end, def)
end

-- Rows -------------------------------------------------------------------------
function Widgets.Row(parent, key)
  local def = Schema:Def(key)
  local row = CreateFrame("Frame", nil, parent)
  row.key = key
  row:SetHeight(ROW_H)
  row:EnableMouse(true)
  local hover = row:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.025)
  hover:Hide()
  local line = Kit.Divider(row)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  row.dot = row:CreateTexture(nil, "ARTWORK")
  row.dot:SetSize(5, 5)
  row.dot:SetPoint("LEFT", 2, 7)
  Theme:Paint(row.dot, "accent")
  row.label = Kit.Text(row, "body", "text.primary")
  row.label:SetPoint("LEFT", 14, 8)
  row.label:SetText(PUI.L[def.label])
  row.sub = Kit.Text(row, "small", "muted")
  row.sub:SetPoint("LEFT", 14, -9)
  row.sub:SetPoint("RIGHT", -330, 0)
  row.sub:SetWordWrap(false)
  row.sub:SetText(PUI.L[def.tooltip])
  row.hover = hover
  row:SetScript("OnEnter", function(self) hover:Show(); showHelp(self) end)
  row:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
  row:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then Schema:Reset(self.key) end
  end)
  build[def.type](row, def)
  if row.stacked then -- tall controls sit under the label, full width
    row.sub:SetPoint("RIGHT", -14, 0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", 14, -10)
    row.sub:ClearAllPoints()
    row.sub:SetPoint("TOPLEFT", 14, -28)
    row.sub:SetPoint("RIGHT", -14, 0)
    row.dot:ClearAllPoints()
    row.dot:SetPoint("TOPLEFT", 2, -15)
  end
  function row:Refresh()
    self:Show_(Schema:Get(self.key))
    if Model.IsChanged(self.key) then self.dot:Show() else self.dot:Hide() end
  end
  row:Refresh()
  return row
end
