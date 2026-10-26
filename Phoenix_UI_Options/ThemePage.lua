local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Theme & Media page (mockup 04): accent swatches, the font list drawn in
-- each font's own face, font size, a grid of every status bar texture as a
-- live sample, the sound list with play buttons, and the remaining theme
-- settings as normal rows. Clicking anything commits through the schema.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Widgets = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Widgets
local Media = PUI.Media
local TP = {}
Options.ThemePage = TP
Options.views = Options.views or {}

local COL_W, PAD = 340, 20
local MORE = { "theme.panelAlpha", "media.numberFont", "bars.backgroundAlpha", "media.shareLSM" }

local function pickRow(parent, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(COL_W - 36, h)
  b.sel = Theme:Slice(b, A.control, 20, "BACKGROUND")
  b.sel:SetVertexColor(1, 1, 1, 0)
  b.check = Kit.Icon(b, A.check, 14, "OVERLAY")
  b.check:SetPoint("RIGHT", -10, 0)
  Theme:Paint(b.check, "accent", 1, "vertex")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  return b
end

local function mark(b, on)
  b.check:SetShown(on)
  b.sel:SetVertexColor(1, 1, 1, on and 1 or 0)
end

local function column(v, x, title, h)
  local c = Kit.Card(v.child)
  c:SetPoint("TOPLEFT", x, 0)
  c:SetSize(COL_W, h)
  c.head = Kit.Section(c, title)
  c.head:SetPoint("TOPLEFT", 18, -16)
  return c
end

local function buildAccent(v, c)
  v.swatches = {}
  for i, name in ipairs(Theme.ACCENTS) do
    local s = CreateFrame("Button", nil, c)
    s:SetSize(30, 30)
    s:SetPoint("TOPLEFT", 18 + (i - 1) * 38, -44)
    s.tex = Kit.Icon(s, A.knob, 30)
    s.tex:SetPoint("CENTER")
    s.tex:SetVertexColor(Theme:ResolveAccent(name))
    s.ring = Kit.Icon(s, A.thumbRing, 38, "OVERLAY")
    s.ring:SetPoint("CENTER")
    s.name = name
    s:SetScript("OnClick", function() Model.Commit("theme.accent", name) end)
    v.swatches[i] = s
  end
end

local function buildFonts(v, c, y)
  local cap = Kit.Section(c, "Interface font")
  cap:SetPoint("TOPLEFT", 18, y)
  y = y - 26
  v.fonts = {}
  for _, name in ipairs(Media:List("font")) do
    local b = pickRow(c, 30)
    b:SetPoint("TOPLEFT", 18, y)
    b.text = b:CreateFontString(nil, "ARTWORK")
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetFont(Media:Path("font", name) or Media:Font(name), 15, "")
    b.text:SetText(name)
    Theme:Paint(b.text, "text.primary", 1, "text")
    b:SetScript("OnClick", function() Model.Commit("media.uiFont", name) end)
    b.name = name
    v.fonts[#v.fonts + 1] = b
    y = y - 32
  end
  y = y - 10
  local sz = Kit.Section(c, "Font size")
  sz:SetPoint("TOPLEFT", 18, y)
  v.size = Kit.Slider(c, Schema:Def("media.fontScale"), COL_W - 36, function(val) Model.Commit("media.fontScale", val) end)
  v.size:SetPoint("TOPLEFT", 18, y - 26)
  return y - 70
end

local function buildBars(v, c)
  v.bars = {}
  local y = -44
  for _, name in ipairs(Media:List("statusbar")) do
    local b = pickRow(c, 34)
    b:SetPoint("TOPLEFT", 18, y)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetPoint("LEFT", 8, 0)
    b.bar:SetSize(150, 18)
    b.bar:SetTexture(Media:Path("statusbar", name))
    b.label = Kit.Text(b, "small", "text.secondary")
    b.label:SetPoint("LEFT", b.bar, "RIGHT", 10, 0)
    b.label:SetText(name)
    b:SetScript("OnClick", function() Model.Commit("bars.texture", name) end)
    b.name = name
    v.bars[#v.bars + 1] = b
    y = y - 36
  end
  return y
end

local function buildSounds(v, c)
  v.sounds = {}
  local y = -44
  for _, name in ipairs(Media:List("sound")) do
    local b = pickRow(c, 30)
    b:SetPoint("TOPLEFT", 18, y)
    b.label = Kit.Text(b, "text", "text.secondary")
    b.label:SetPoint("LEFT", 36, 0)
    b.label:SetText(name)
    b.play = Kit.Button(b, ">", 24, function() Media:PlaySound(name) end, "ghost")
    b.play:SetPoint("LEFT", 4, 0)
    b.play:SetHeight(24)
    b:SetScript("OnClick", function() Model.Commit("media.alertSound", name); Media:PlaySound(name) end)
    b.name = name
    v.sounds[#v.sounds + 1] = b
    y = y - 32
  end
  return y
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  local icon = Kit.Icon(v, A.Icon("theme"), 44)
  icon:SetPoint("TOPLEFT", 30, -30)
  local title = Kit.Text(v, "display", "text.primary")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, 2)
  title:SetText("Theme & Media")
  local desc = Kit.Text(v, "text", "muted")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  desc:SetText(Media:Count("font") .. " fonts, " .. Media:Count("statusbar") .. " bar textures, " .. Media:Count("sound") .. " sounds. Click to apply, live.")
  local scroll = CreateFrame("ScrollFrame", nil, v)
  scroll:SetPoint("TOPLEFT", 30, -100)
  scroll:SetPoint("BOTTOMRIGHT", -30, 20)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, self:GetScrollChild():GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 60)))
  end)
  v.child = CreateFrame("Frame", nil, scroll)
  v.child:SetSize(3 * COL_W + 2 * PAD, 10)
  scroll:SetScrollChild(v.child)

  local c1 = column(v, 0, "Accent", 10)
  buildAccent(v, c1)
  local h1 = -buildFonts(v, c1, -96)
  c1:SetHeight(h1)
  local c2 = column(v, COL_W + PAD, "Bar texture", 10)
  local h2 = -buildBars(v, c2) + 10
  c2:SetHeight(h2)
  local c3 = column(v, 2 * (COL_W + PAD), "Alert sound", 10)
  local y = buildSounds(v, c3) - 10
  v.more = {}
  local more = Kit.Section(c3, "More")
  more:SetPoint("TOPLEFT", 18, y)
  y = y - 24
  for _, key in ipairs(MORE) do
    if Schema:Def(key) then
      local row = Widgets.Row(c3, key)
      v.more[key] = row
      row:SetPoint("TOPLEFT", 6, y)
      row:SetPoint("RIGHT", c3, "RIGHT", -6, 0)
      y = y - Widgets.ROW_H
    end
  end
  c3:SetHeight(-y + 12)
  v.c3 = c3
  v.child:SetHeight(math.max(h1, h2, -y + 12) + 20)
  function v:OnSetting() TP:Refresh(self) end
  Options.views.theme = v
  return v
end

function TP:Refresh(v)
  local accent = Schema:Get("theme.accent")
  for _, s in ipairs(v.swatches) do
    s.ring:SetShown(s.name == accent)
    s.tex:SetVertexColor(Theme:ResolveAccent(s.name))
  end
  local font, tex, snd = Schema:Get("media.uiFont"), Schema:Get("bars.texture"), Schema:Get("media.alertSound")
  for _, b in ipairs(v.fonts) do mark(b, b.name == font) end
  for _, b in ipairs(v.bars) do
    mark(b, b.name == tex)
    b.bar:SetVertexColor(Theme:Color("accent"))
  end
  for _, b in ipairs(v.sounds) do mark(b, b.name == snd) end
  v.size:SetValue_(Schema:Get("media.fontScale"))
  for _, key in ipairs(MORE) do
    local row = v.more[key]
    if row then row:Refresh(); row:Show() end
  end
end

function TP:Show(host)
  local v = Options.views.theme or build(host)
  v:Show()
  self:Refresh(v)
end
