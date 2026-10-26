local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Dashboard (mockup 01): hero with the Phoenix glyph, welcome line, client
-- badges, Open Studio / Run setup again; module cards (3 columns, toggle +
-- Configure) with an All/On/Off filter; right column with quick toggles,
-- the profile card and the Sentinel card.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Nav = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Nav
local Dash = { filter = "all", cards = {} }
Options.Dashboard = Dash
Options.views = Options.views or {}

local RIGHT_W, CARD_W, CARD_H, GAP = 320, 248, 96, 14
local QUICK = { "general.gameMenuButton", "general.minimapButton", "media.shareLSM", "studio.snap", "studio.showGrid" }

local function slash(word)
  local c = PUI.Slash.commands[word]
  if c then c.fn("") end
end

-- Owners with a module.<Owner> toggle, in sidebar order.
function Dash.Modules()
  local out = {}
  for _, g in ipairs(Nav.GROUPS) do
    for _, owner in ipairs(g[2]) do
      local on = Nav.ModuleOn(owner)
      if on ~= nil then out[#out + 1] = { owner = owner, on = on } end
    end
  end
  return out
end

local function buildHero(v)
  local hero = CreateFrame("Frame", nil, v)
  hero:SetPoint("TOPLEFT", 30, -24)
  hero:SetPoint("TOPRIGHT", -30, -24)
  hero:SetHeight(196)
  local art = hero:CreateTexture(nil, "BACKGROUND")
  art:SetAllPoints()
  art:SetTexture(A.hero)
  local edge = Theme:Slice(hero, A.card, 28, "BORDER")
  edge:SetVertexColor(1, 1, 1, 0.35)
  local glyph = Kit.Icon(hero, A.glyph, 220, "ARTWORK")
  glyph:SetPoint("RIGHT", -40, 0)
  glyph:SetAlpha(0.9)
  hero.kicker = Kit.Text(hero, "caption", "accent")
  hero.kicker:SetPoint("TOPLEFT", 34, -34)
  hero.kicker:SetText("PHOENIX UI")
  hero.title = Kit.Text(hero, "hero", "text.primary")
  hero.title:SetPoint("TOPLEFT", hero.kicker, "BOTTOMLEFT", 0, -6)
  hero.sub = Kit.Text(hero, "body", "text.secondary")
  hero.sub:SetPoint("TOPLEFT", hero.title, "BOTTOMLEFT", 0, -6)
  hero.b1 = Kit.Badge(hero, PUI.IS_FOREVER and "Forever" or "Midnight", "accent")
  hero.b1:SetPoint("TOPLEFT", hero.sub, "BOTTOMLEFT", 0, -12)
  hero.b2 = Kit.Badge(hero, "Applies live", "ok")
  hero.b2:SetPoint("LEFT", hero.b1, "RIGHT", 8, 0)
  hero.b3 = Kit.Badge(hero, "", "neutral")
  hero.b3:SetPoint("LEFT", hero.b2, "RIGHT", 8, 0)
  local studio = Kit.Button(hero, "Open Studio", 150, function() PUI.OptionsHost:OpenStudio() end, "primary", A.Icon("studio"))
  studio:SetPoint("BOTTOMLEFT", 34, 26)
  local setup = Kit.Button(hero, "Run setup again", 160, function() slash("setup") end, "secondary")
  setup:SetPoint("LEFT", studio, "RIGHT", 10, 0)
  v.hero = hero
end

local function card(v, i)
  local c = Dash.cards[i]
  if c then return c end
  c = Kit.Card(v.grid)
  c:SetSize(CARD_W, CARD_H)
  c.icon = Kit.Icon(c, A.Icon("general"), 32)
  c.icon:SetPoint("TOPLEFT", 16, -16)
  c.title = Kit.Text(c, "label", "text.primary")
  c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -1)
  c.desc = Kit.Text(c, "small", "muted")
  c.desc:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
  c.desc:SetPoint("RIGHT", -16, 0)
  c.desc:SetJustifyH("LEFT")
  c.desc:SetMaxLines(2)
  c.toggle = Kit.Toggle(c, function(on) if c.key then Model.Commit(c.key, on) end end)
  c.toggle:SetPoint("BOTTOMLEFT", 16, 12)
  c.state = Kit.Text(c, "small", "muted")
  c.state:SetPoint("LEFT", c.toggle, "RIGHT", 8, 0)
  c.go = Kit.Button(c, "Configure  >", 100, function() if c.owner then Options:Open(c.owner) end end, "ghost")
  c.go:SetPoint("BOTTOMRIGHT", -8, 8)
  c.go:SetHeight(26)
  Dash.cards[i] = c
  return c
end

local function sideCard(v, title, h, anchor)
  local c = Kit.Card(v)
  c:SetWidth(RIGHT_W)
  c:SetHeight(h)
  if anchor then c:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP) else c:SetPoint("TOPRIGHT", v.hero, "BOTTOMRIGHT", 0, -20) end
  c.head = Kit.Section(c, title)
  c.head:SetPoint("TOPLEFT", 18, -16)
  return c
end

local function buildRight(v)
  local quick = sideCard(v, "Quick toggles", 44 + #QUICK * 36)
  quick.rows = {}
  local y = -42
  for _, key in ipairs(QUICK) do
    local def = Schema:Def(key)
    if def then
      local label = Kit.Text(quick, "text", "text.secondary")
      label:SetPoint("TOPLEFT", 18, y - 6)
      label:SetText(def.label)
      local t = Kit.Toggle(quick, function(on) Model.Commit(key, on) end)
      t:SetPoint("TOPRIGHT", -16, y)
      quick.rows[key] = t
      y = y - 36
    end
  end
  quick:SetHeight(-y + 10)
  v.quick = quick

  local prof = sideCard(v, "Profile", 124, quick)
  prof.name = Kit.Text(prof, "title", "text.primary")
  prof.name:SetPoint("TOPLEFT", 18, -42)
  prof.sub = Kit.Text(prof, "small", "muted")
  prof.sub:SetPoint("TOPLEFT", prof.name, "BOTTOMLEFT", 0, -3)
  local switch = Kit.Button(prof, "Switch", 90, function() Options:Open("profile") end, "secondary")
  switch:SetPoint("BOTTOMLEFT", 16, 14)
  local exp = Kit.Button(prof, "Export", 90, nil, "ghost")
  exp:SetPoint("LEFT", switch, "RIGHT", 8, 0)
  exp:Disable()
  exp:SetAlpha(0.45)
  exp.tooltip = "Profile import/export is not available yet."
  v.prof = prof

  local sen = sideCard(v, "Sentinel", 124, prof)
  sen.big = Kit.Text(sen, "display", "ok")
  sen.big:SetPoint("TOPLEFT", 18, -40)
  sen.sub = Kit.Text(sen, "small", "muted")
  sen.sub:SetPoint("LEFT", sen.big, "RIGHT", 10, -2)
  local open = Kit.Button(sen, "Open Sentinel", 130, function() slash("sentinel") end, "secondary", A.Icon("sentinel"))
  open:SetPoint("BOTTOMLEFT", 16, 14)
  v.sen = sen
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  buildHero(v)
  local head = Kit.Text(v, "title", "text.primary")
  head:SetPoint("TOPLEFT", v.hero, "BOTTOMLEFT", 0, -22)
  head:SetText("Modules")
  v.count = Kit.Text(v, "small", "muted")
  v.count:SetPoint("LEFT", head, "RIGHT", 10, -1)
  v.filter = Kit.Segmented(v, { "all", "on", "off" }, { "All", "On", "Off" }, function(f) Dash.filter = f; Dash:Fill(v) end)
  v.filter:SetPoint("TOPRIGHT", v.hero, "BOTTOMRIGHT", -(RIGHT_W + 24), -16)
  local scroll = CreateFrame("ScrollFrame", nil, v)
  scroll:SetPoint("TOPLEFT", v.hero, "BOTTOMLEFT", 0, -60)
  scroll:SetPoint("BOTTOMRIGHT", -(30 + RIGHT_W + 20), 20)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, self:GetScrollChild():GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 60)))
  end)
  v.grid = CreateFrame("Frame", nil, scroll)
  v.grid:SetSize(3 * CARD_W + 2 * GAP, 10)
  scroll:SetScrollChild(v.grid)
  buildRight(v)
  function v:OnSetting(key)
    if key:find("^module%.") or self.quick.rows[key] or key == "core.profile" then Dash:Refresh(self) end
  end
  Options.views.dashboard = v
  return v
end

function Dash:Fill(v)
  local mods, n, on = Dash.Modules(), 0, 0
  for _, m in ipairs(mods) do
    if m.on then on = on + 1 end
    if self.filter == "all" or (self.filter == "on") == m.on then
      n = n + 1
      local c = card(v, n)
      local icon, label, desc = Nav.Info(m.owner)
      c.owner, c.key = m.owner, "module." .. m.owner
      c.icon:SetTexture(A.Icon(icon, not m.on))
      c.title:SetText(label)
      c.desc:SetText(desc)
      c.toggle:SetValue_(m.on)
      c.state:SetText(m.on and "On" or "Off")
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", ((n - 1) % 3) * (CARD_W + GAP), -math.floor((n - 1) / 3) * (CARD_H + GAP))
      c:SetAlpha(m.on and 1 or 0.72)
      c:Show()
    end
  end
  for i = n + 1, #self.cards do self.cards[i]:Hide() end
  v.grid:SetHeight(math.ceil(n / 3) * (CARD_H + GAP))
  v.count:SetText(on .. " of " .. #mods .. " on")
  return on, #mods
end

function Dash:Refresh(v)
  local on, total = self:Fill(v)
  v.filter:SetValue_(self.filter)
  v.hero.title:SetText("Welcome back, " .. (UnitName("player") or "champion"))
  v.hero.sub:SetText(on .. " of " .. total .. " modules running. Every change applies live.")
  v.hero.b3:SetText(#Schema.keys .. " settings")
  for key, t in pairs(v.quick.rows) do t:SetValue_(Schema:Get(key) and true or false) end
  v.prof.name:SetText(PUI.DB:GetProfileName() or "Default")
  v.prof.sub:SetText(#PUI.DB:ProfileNames() .. " profile(s) on this account")
  local S = PUI.Sentinel
  local list = S and S.Viewer and S.Viewer:List(true)
  if list then
    v.sen.big:SetText(tostring(#list))
    Theme:Paint(v.sen.big, #list == 0 and "ok" or "err", 1, "text")
    v.sen.sub:SetText(#list == 1 and "error this session" or "errors this session")
  else
    v.sen.big:SetText("--")
    Theme:Paint(v.sen.big, "muted", 1, "text")
    v.sen.sub:SetText("Sentinel loads on its first report")
  end
end

function Dash:Show(host)
  local v = Options.views.dashboard or build(host)
  v:Show()
  self:Refresh(v)
end
