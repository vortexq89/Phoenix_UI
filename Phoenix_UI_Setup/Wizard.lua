local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Setup wizard UI (mockups 05-11): welcome, five steps with a progress rail
-- (language, scale, role, layout, look) and a finish summary. Built from the
-- options design kit (Phoenix_UI_Options is loaded on open). Choices apply
-- through the schema on Finish, live, without a reload; the look step
-- previews accent and panel live. Never opens in combat.
local _, ns = ...
local SU, P = ns.SU, ns.P
local Schema, Theme, CQ = PUI.Schema, PUI.Theme, PUI.CombatQueue
local W, H, RAIL = 1200, 700, 280
local CARD_W, GAP = 252, 14
local Kit, A -- bound when the options child loads

SU.STEP_LABELS = { "Language", "Scale", "Role", "Layout", "Look" }
SU.LANGS = {
  { "enUS", "English", "English" }, { "deDE", "Deutsch", "German" }, { "frFR", "Fran\195\167ais", "French" },
  { "esES", "Espa\195\177ol", "Spanish" }, { "ptBR", "Portugu\195\170s", "Portuguese" },
  { "ruRU", "\208\160\209\131\209\129\209\129\208\186\208\184\208\185", "Russian" },
  { "koKR", "\237\149\156\234\181\173\236\150\180", "Korean" },
  { "zhCN", "\231\174\128\228\189\147\228\184\173\230\150\135", "Chinese (Simplified)" },
  { "zhTW", "\231\185\129\233\171\148\228\184\173\230\150\135", "Chinese (Traditional)" },
}
local NATIVE_FONT = { koKR = "Noto Sans KR", zhCN = "Noto Sans SC", zhTW = "Noto Sans SC" }
local ROLE_ICON = { healer = "raid", tank = "sentinel", dps = "resource" }
SU.SCALES = { { "compact", "Compact", 0.85 }, { "pixel", "Pixel perfect", 1 }, { "large", "Large", 1.2 } }

local function playerLine()
  local name = UnitName("player") or "champion"
  local _, className = UnitClass("player")
  local api, specName = C_SpecializationInfo, nil
  local spec = api and api.GetSpecialization and api.GetSpecialization()
  if spec and api.GetSpecializationInfo then
    local _, sn = api.GetSpecializationInfo(spec)
    specName = sn
  end
  return name, (specName and (specName .. " ") or "") .. (UnitClass("player") or className or "")
end

-- Selectable card: Kit card, accent outline + check badge when selected.
local function choiceCard(parent, w, h, onClick)
  local c = CreateFrame("Button", nil, parent)
  c:SetSize(w, h)
  c.bg = Theme:Slice(c, A.card, 28, "BACKGROUND")
  c.ring = Theme:Slice(c, A.borderSoft, 28, "BORDER")
  Theme:Paint(c.ring, "accent", 1, "vertex")
  c.tint = Theme:Slice(c, A.card, 28, "BACKGROUND", 1)
  Theme:Paint(c.tint, "accent", 0.08, "vertex")
  c.check = CreateFrame("Frame", nil, c)
  c.check:SetSize(18, 18)
  c.check:SetPoint("TOPRIGHT", -9, -9)
  local dot = Kit.Icon(c.check, A.knob, 18)
  dot:SetPoint("CENTER")
  Theme:Paint(dot, "accent", 1, "vertex")
  local tick = Kit.Icon(c.check, A.check, 12, "OVERLAY")
  tick:SetPoint("CENTER")
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", -3, 3)
  hl:SetColorTexture(1, 1, 1, 0.03)
  c:SetScript("OnClick", onClick)
  function c:Select(on)
    self.ring:SetShown(on)
    self.tint:SetShown(on)
    self.check:SetShown(on)
  end
  c:Select(false)
  return c
end

-- Frame ---------------------------------------------------------------------------------
local function buildRail(f)
  local rail = CreateFrame("Frame", nil, f)
  rail:SetPoint("TOPLEFT")
  rail:SetPoint("BOTTOMLEFT")
  rail:SetWidth(RAIL)
  local shade = rail:CreateTexture(nil, "BACKGROUND", nil, 1)
  shade:SetPoint("TOPLEFT", 3, -3)
  shade:SetPoint("BOTTOMRIGHT", 0, 3)
  shade:SetColorTexture(0, 0, 0, 0.18)
  local line = Kit.Divider(rail, true)
  line:SetPoint("TOPRIGHT")
  line:SetPoint("BOTTOMRIGHT")
  local logo = Kit.Icon(rail, A.logo, 38)
  logo:SetPoint("TOPLEFT", 26, -26)
  local t = Kit.Text(rail, "title", "text.primary")
  t:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -2)
  t:SetText("PHOENIX |cffff7a1aUI|r")
  local s = Kit.Text(rail, "small", "muted")
  s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2)
  s:SetText("First-time setup")
  rail.items = {}
  for i, label in ipairs(SU.STEP_LABELS) do
    local it = CreateFrame("Frame", nil, rail)
    it:SetSize(RAIL - 40, 26)
    it:SetPoint("TOPLEFT", 26, -100 - (i - 1) * 46)
    it.circle = Kit.Icon(it, A.knob, 24)
    it.circle:SetPoint("LEFT")
    it.ring = Kit.Icon(it, A.thumbRing, 30, "OVERLAY")
    it.ring:SetPoint("CENTER", it.circle)
    Theme:Paint(it.ring, "accent", 1, "vertex")
    it.num = Kit.Text(it, "small", "text.primary", "OVERLAY")
    it.num:SetPoint("CENTER", it.circle)
    it.num:SetText(tostring(i))
    it.tick = Kit.Icon(it, A.check, 12, "OVERLAY")
    it.tick:SetPoint("CENTER", it.circle)
    it.label = Kit.Text(it, "label", "muted")
    it.label:SetPoint("LEFT", it.circle, "RIGHT", 14, 0)
    it.label:SetText(label)
    if i < #SU.STEP_LABELS then
      it.link = it:CreateTexture(nil, "BACKGROUND")
      it.link:SetSize(1, 22)
      it.link:SetPoint("TOP", it.circle, "BOTTOM", 0, 0)
      it.link:SetColorTexture(1, 1, 1, 0.12)
    end
    rail.items[i] = it
  end
  rail.progress = Kit.Text(rail, "small", "muted")
  rail.progress:SetPoint("BOTTOMLEFT", 26, 40)
  local track = rail:CreateTexture(nil, "ARTWORK")
  track:SetPoint("BOTTOMLEFT", 26, 26)
  track:SetSize(RAIL - 52, 3)
  track:SetColorTexture(1, 1, 1, 0.1)
  rail.fill = rail:CreateTexture(nil, "OVERLAY")
  rail.fill:SetPoint("LEFT", track)
  rail.fill:SetHeight(3)
  Theme:Paint(rail.fill, "accent")
  rail.trackW = RAIL - 52
  f.rail = rail
end

local function buildFooter(f)
  local foot = CreateFrame("Frame", nil, f.stage)
  foot:SetPoint("BOTTOMLEFT", 0, 0)
  foot:SetPoint("BOTTOMRIGHT", 0, 0)
  foot:SetHeight(86)
  local line = Kit.Divider(foot)
  line:SetPoint("TOPLEFT", 0, -10)
  line:SetPoint("TOPRIGHT", 0, -10)
  f.skip = Kit.Button(foot, "Skip setup", 100, function() SU.Skip() end, "ghost")
  f.skip:SetPoint("LEFT", 0, -6)
  f.go = Kit.Button(foot, "Continue  >", 140, function() SU.Go(1) end, "primary")
  f.go:SetPoint("RIGHT", 0, -6)
  f.back = Kit.Button(foot, "Back", 80, function() SU.Go(-1) end, "secondary")
  f.back:SetPoint("RIGHT", f.go, "LEFT", -10, 0)
end

local function build()
  local f = SU.frame
  if f then return f end
  f = PUI:CreateFrame("Frame", "PhoenixUI_SetupWizard", UIParent, nil, "Setup")
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  Kit.Window(f)
  buildRail(f)
  -- stepped pages: content to the right of the rail
  local stage = CreateFrame("Frame", nil, f)
  stage:SetPoint("TOPLEFT", RAIL + 44, -40)
  stage:SetPoint("BOTTOMRIGHT", -44, 0)
  f.stage = stage
  f.title = Kit.Text(stage, "display", "text.primary")
  f.title:SetPoint("TOPLEFT")
  f.sub = Kit.Text(stage, "text", "muted")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
  f.sub:SetWidth(700)
  f.sub:SetJustifyH("LEFT")
  f.body = CreateFrame("Frame", nil, stage)
  f.body:SetPoint("TOPLEFT", 0, -96)
  f.body:SetPoint("BOTTOMRIGHT", 0, 96)
  buildFooter(f)
  f.pages = {}
  SU.frame = f
  return f
end

-- Pages ---------------------------------------------------------------------------------
local Pages = {}
SU.Pages = Pages

function Pages.welcome(f)
  local v = CreateFrame("Frame", nil, f)
  v:SetAllPoints()
  local glow = Kit.Icon(v, A.radial, 300, "BACKGROUND")
  glow:SetPoint("TOP", 0, 40)
  Theme:Paint(glow, "accent", 0.35, "vertex")
  local logo = Kit.Icon(v, A.logo, 136)
  logo:SetPoint("TOP", 0, -50)
  local t = Kit.Text(v, "display", "text.primary")
  t:SetFont(Kit.FontPath("Rajdhani Bold"), 46, "")
  t:SetPoint("TOP", logo, "BOTTOM", 0, -18)
  t:SetText("PHOENIX |cffff7a1aUI|r")
  local s = Kit.Text(v, "body", "text.secondary")
  s:SetPoint("TOP", t, "BOTTOM", 0, -12)
  s:SetText("Rise from the ashes of the default interface.")
  local feats = {
    { "unitframes", "Modern frames", "Unit, raid & nameplates in one style" },
    { "studio", "Studio mover", "Drag, snap and nudge every element" },
    { "sentinel", "Sentinel", "Catches errors before they ruin a pull" },
    { "theme", "Your style", "Accent, fonts, textures & sounds" },
  }
  for i, ft in ipairs(feats) do
    local c = Kit.Card(v)
    c:SetSize(250, 92)
    c:SetPoint("TOP", (i - 2.5) * 264, -330)
    local ic = Kit.Icon(c, A.Icon(ft[1]), 32)
    ic:SetPoint("TOPLEFT", 16, -16)
    local tt = Kit.Text(c, "label", "text.primary")
    tt:SetPoint("TOPLEFT", ic, "TOPRIGHT", 12, 0)
    tt:SetText(ft[2])
    local dd = Kit.Text(c, "small", "muted")
    dd:SetPoint("TOPLEFT", tt, "BOTTOMLEFT", 0, -4)
    dd:SetWidth(170)
    dd:SetJustifyH("LEFT")
    dd:SetText(ft[3])
  end
  local start = Kit.Button(v, "Start setup  >", 170, function() SU.Go(1) end, "primary")
  start:SetPoint("TOP", 92, -466)
  local imp = Kit.Button(v, "Import a profile", 160, nil, "secondary")
  imp:SetPoint("RIGHT", start, "LEFT", -12, 0)
  imp:Disable()
  imp:SetAlpha(0.45)
  v.hello = Kit.Text(v, "small", "muted")
  v.hello:SetPoint("TOP", 0, -520)
  function v:Refresh()
    local name, spec = playerLine()
    self.hello:SetText("Hello " .. name .. " - " .. spec .. "  |  You can rerun this any time from the Dashboard.")
  end
  return v
end

local function grid(body, items, cols, w, h, make)
  local cards = {}
  for i, item in ipairs(items) do
    local c = make(item, w, h)
    c:SetPoint("TOPLEFT", ((i - 1) % cols) * (w + GAP), -math.floor((i - 1) / cols) * (h + GAP))
    cards[i] = c
  end
  return cards
end

function Pages.language(f)
  local v = CreateFrame("Frame", nil, f.body)
  v:SetAllPoints()
  v.title, v.sub = "Choose your language", "Phoenix follows your game client by default. Fonts switch automatically to cover the script you pick."
  v.cards = grid(v, SU.LANGS, 3, 252, 64, function(l, w, h)
    local c = choiceCard(v, w, h, function() SU.choices.language = l[1]; v:Refresh() end)
    c.native = c:CreateFontString(nil, "ARTWORK")
    local face = NATIVE_FONT[l[1]]
    c.native:SetFont(face and PUI.Media:Path("font", face) or Kit.FontPath("Inter SemiBold"), 14, "")
    Theme:Paint(c.native, "text.primary", 1, "text")
    c.native:SetPoint("TOPLEFT", 14, -14)
    c.native:SetText(l[2])
    local sub = Kit.Text(c, "small", "muted")
    sub:SetPoint("TOPLEFT", c.native, "BOTTOMLEFT", 0, -5)
    sub:SetText(l[3] .. " - " .. l[1])
    c.code = l[1]
    return c
  end)
  v.match = Kit.Toggle(v, function(on)
    SU.choices.language = on and "auto" or PUI.Locale:Resolve("auto")
    v:Refresh()
  end)
  v.match:SetPoint("TOPLEFT", 0, -3 * (64 + GAP) - 6)
  v.matchText = Kit.Text(v, "text", "text.secondary")
  v.matchText:SetPoint("LEFT", v.match, "RIGHT", 10, 0)
  function v:Refresh()
    local choice = SU.choices.language
    local active = PUI.Locale:Resolve(choice)
    for _, c in ipairs(self.cards) do c:Select(c.code == active) end
    self.match:SetValue_(choice == "auto")
    self.matchText:SetText("Match my game client (" .. GetLocale() .. ")")
  end
  return v
end

local function miniHud(parent, factor)
  local box = CreateFrame("Frame", nil, parent)
  box:SetPoint("TOPLEFT", 8, -8)
  box:SetPoint("BOTTOMRIGHT", -8, 34)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(A.hero)
  bg:SetVertexColor(0.6, 0.55, 0.5, 1)
  local name = Kit.Text(box, "small", "ok")
  name:SetPoint("TOPLEFT", 8, -8)
  name:SetText(UnitName("player") or "Player")
  local hp = box:CreateTexture(nil, "ARTWORK")
  hp:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
  hp:SetSize(68 * factor, 6 * factor)
  Theme:Paint(hp, "ok")
  local pp = box:CreateTexture(nil, "ARTWORK")
  pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -2)
  pp:SetSize(56 * factor, 2.5 * factor)
  Theme:Paint(pp, "info")
  local size = 12 * factor
  for i = 1, 8 do
    local ic = Kit.Icon(box, A.abilities[i], size)
    ic:SetPoint("BOTTOM", (i - 4.5) * (size + 2), 8)
  end
end

function Pages.scale(f)
  local v = CreateFrame("Frame", nil, f.body)
  v:SetAllPoints()
  v.title = "Set your UI scale"
  v.cards = grid(v, SU.SCALES, 3, CARD_W, 168, function(sc, w, h)
    local c = choiceCard(v, w, h, function() SU.choices.scale = SU.ClampScale(SU.PixelScale() * sc[3]); v:Refresh() end)
    miniHud(c, sc[3])
    local name = Kit.Text(c, "label", "text.primary")
    name:SetPoint("BOTTOMLEFT", 10, 12)
    name:SetText(sc[2])
    local x = Kit.Text(c, "mono", "muted")
    x:SetPoint("BOTTOMRIGHT", -10, 12)
    x:SetText(string.format("%.2fx", sc[3]))
    c.factor = sc[3]
    return c
  end)
  local label = Kit.Text(v, "label", "text.secondary")
  label:SetPoint("TOPLEFT", 0, -168 - 34)
  label:SetText("Fine tune")
  v.slider = Kit.Slider(v, { min = 0.64, max = 1.15, step = 0.01 }, 2 * CARD_W, function(val)
    SU.choices.scale = SU.ClampScale(val)
    v:Refresh()
  end)
  v.slider:SetPoint("LEFT", label, "LEFT", 120, 0)
  function v:Refresh()
    local px = SU.PixelScale()
    local w, h = GetPhysicalScreenSize()
    self.sub = string.format("Detected %d x %d. We recommend |cffff7a1a%.2f|r for pixel-perfect 1px borders on your screen.", w or 0, h or 0, px)
    f.sub:SetText(self.sub)
    local cur = SU.choices.scale
    if type(cur) ~= "number" then cur = px end
    for _, c in ipairs(self.cards) do c:Select(math.abs(SU.ClampScale(px * c.factor) - cur) < 0.005) end
    self.slider:SetValue_(cur)
  end
  return v
end

function Pages.role(f)
  local v = CreateFrame("Frame", nil, f.body)
  v:SetAllPoints()
  v.title = "What do you play most?"
  v.cards = grid(v, P.WIZARD_ROLES, 3, CARD_W, 136, function(role, w, h)
    local c = choiceCard(v, w, h, function() SU.choices.role = role; v:Refresh() end)
    local ic = Kit.Icon(c, A.Icon(ROLE_ICON[role]), 44)
    ic:SetPoint("TOP", 0, -18)
    local n = Kit.Text(c, "title", "text.primary")
    n:SetPoint("TOP", ic, "BOTTOM", 0, -10)
    n:SetText(P.ROLE_LABELS[role])
    local d = Kit.Text(c, "small", "muted")
    d:SetPoint("TOP", n, "BOTTOM", 0, -6)
    d:SetWidth(w - 40)
    d:SetText(P.ROLE_TEXT[role])
    c.role = role
    return c
  end)
  function v:Refresh()
    local _, spec = playerLine()
    self.sub = "We detected |cff3ddc97" .. spec .. "|r. Your role shapes the starting layout and which modules are on."
    f.sub:SetText(self.sub)
    for _, c in ipairs(self.cards) do c:Select(c.role == SU.choices.role) end
  end
  return v
end

function Pages.layout(f)
  local v = CreateFrame("Frame", nil, f.body)
  v:SetAllPoints()
  v.title = "Pick a starting layout"
  v.sub = "Each preset is a full layout. Fine-tune anything afterwards in Studio - nothing is locked."
  v.cards = grid(v, P.LAYOUT_ORDER, 3, CARD_W, 210, function(id, w, h)
    local L = P.LAYOUTS[id]
    local c = choiceCard(v, w, h, function() SU.choices.layout = id; v:Refresh() end)
    local art = c:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", 8, -8)
    art:SetPoint("TOPRIGHT", -8, -8)
    art:SetHeight(128)
    art:SetTexture(A.presets[L.art])
    local n = Kit.Text(c, "label", "text.primary")
    n:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 2, -12)
    n:SetText(L.label)
    c.badge = Kit.Badge(c, L.badge, L.badge == "Recommended" and "accent" or "neutral")
    c.badge:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", -2, -9)
    local d = Kit.Text(c, "small", "muted")
    d:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -6)
    d:SetWidth(w - 24)
    d:SetJustifyH("LEFT")
    d:SetText(L.desc)
    c.id = id
    return c
  end)
  function v:Refresh()
    for _, c in ipairs(self.cards) do c:Select(c.id == SU.choices.layout) end
  end
  return v
end

function Pages.look(f)
  local v = CreateFrame("Frame", nil, f.body)
  v:SetAllPoints()
  v.title, v.sub = "Make it yours", "Accent colour lights up toggles, highlights and borders across the whole UI."
  local s1 = Kit.Section(v, "Accent")
  s1:SetPoint("TOPLEFT", 0, 0)
  v.swatches = {}
  for i, name in ipairs(Theme.DESIGN_ACCENTS) do
    local b = CreateFrame("Button", nil, v)
    b:SetSize(46, 46)
    b:SetPoint("TOPLEFT", (i - 1) * 64, -22)
    b.fill = Theme:Slice(b, A.control, 20, "ARTWORK")
    b.fill:SetVertexColor(Theme:ResolveAccent(name))
    b.ring = Theme:Slice(b, A.borderSoft, 28, "OVERLAY")
    b.ring:ClearAllPoints()
    b.ring:SetPoint("TOPLEFT", -4, 4)
    b.ring:SetPoint("BOTTOMRIGHT", 4, -4)
    b.label = Kit.Text(b, "small", "muted")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -6)
    b.label:SetText(Theme.ACCENT_LABELS[name])
    b.name = name
    b:SetScript("OnClick", function() SU.choices.accent = name; Schema:Set("theme.accent", name); v:Refresh() end)
    v.swatches[i] = b
  end
  local s2 = Kit.Section(v, "Panels")
  s2:SetPoint("TOPLEFT", 0, -100)
  v.panels = {}
  for i, id in ipairs(Theme.PANELS) do
    local c = choiceCard(v, CARD_W, 84, function() SU.choices.panel = id; Schema:Set("theme.panel", id); v:Refresh() end)
    c:SetPoint("TOPLEFT", (i - 1) * (CARD_W + GAP), -120)
    local sw = c:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", 8, -8)
    sw:SetPoint("TOPRIGHT", -8, -8)
    sw:SetHeight(46)
    sw:SetTexture(Theme.PANEL_PATHS[id])
    local bar = c:CreateTexture(nil, "OVERLAY")
    bar:SetPoint("TOPLEFT", sw, "TOPLEFT", 10, -8)
    bar:SetSize(70, 4)
    Theme:Paint(bar, "accent")
    local n = Kit.Text(c, "label", "text.primary")
    n:SetPoint("BOTTOMLEFT", 10, 10)
    n:SetText(Theme.PANEL_LABELS[id])
    c.id = id
    v.panels[i] = c
  end
  local s3 = Kit.Section(v, "Preview")
  s3:SetPoint("TOPLEFT", 0, -222)
  local uf = Kit.Card(v)
  uf:SetSize(180, 52)
  uf:SetPoint("TOPLEFT", 0, -242)
  local hp = uf:CreateTexture(nil, "ARTWORK")
  hp:SetPoint("TOPLEFT", 12, -14)
  hp:SetSize(150, 14)
  hp:SetTexture(PUI.Bars:TexturePath())
  Theme:Paint(hp, "ok", 1, "vertex")
  local pp = uf:CreateTexture(nil, "ARTWORK")
  pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -3)
  pp:SetSize(120, 4)
  Theme:Paint(pp, "info")
  local tg = Kit.Toggle(v, nil)
  tg:SetPoint("LEFT", uf, "RIGHT", 18, 0)
  tg:SetValue_(true)
  local bt = Kit.Button(v, "Button", 90, nil, "primary")
  bt:SetPoint("LEFT", tg, "RIGHT", 14, 0)
  local bd = Kit.Badge(v, "Badge", "accent")
  bd:SetPoint("LEFT", bt, "RIGHT", 12, 0)
  local sl = Kit.Slider(v, { min = 0, max = 1, step = 0.1 }, 160, nil)
  sl:SetPoint("LEFT", bd, "RIGHT", 16, 0)
  sl:SetValue_(0.6)
  function v:Refresh()
    local accent, panel = SU.choices.accent, SU.choices.panel
    for _, b in ipairs(self.swatches) do
      b.ring:SetShown(b.name == accent)
      Theme:Paint(b.label, b.name == accent and "text.primary" or "muted", 1, "text")
    end
    for _, c in ipairs(self.panels) do c:Select(c.id == panel) end
  end
  return v
end

function Pages.finish(f)
  local v = CreateFrame("Frame", nil, f)
  v:SetAllPoints()
  local glow = Kit.Icon(v, A.radial, 220, "BACKGROUND")
  glow:SetPoint("TOP", 0, 10)
  Theme:Paint(glow, "accent", 0.35, "vertex")
  local dot = Kit.Icon(v, A.knob, 92)
  dot:SetPoint("TOP", 0, -50)
  Theme:Paint(dot, "accent", 1, "vertex")
  local tick = Kit.Icon(v, A.check, 40, "OVERLAY")
  tick:SetPoint("CENTER", dot)
  tick:SetVertexColor(0.04, 0.04, 0.05, 1)
  v.head = Kit.Text(v, "display", "text.primary")
  v.head:SetFont(Kit.FontPath("Rajdhani Bold"), 36, "")
  v.head:SetPoint("TOP", dot, "BOTTOM", 0, -20)
  local s = Kit.Text(v, "body", "text.secondary")
  s:SetPoint("TOP", v.head, "BOTTOM", 0, -8)
  s:SetText("Phoenix UI is live. No reload needed.")
  local card = Kit.Card(v)
  card:SetSize(500, 5 * 40 + 16)
  card:SetPoint("TOP", s, "BOTTOM", 0, -22)
  v.rows = {}
  for i, label in ipairs({ "Language", "Scale", "Role", "Layout", "Accent" }) do
    local l = Kit.Text(card, "text", "muted")
    l:SetPoint("TOPLEFT", 22, -8 - (i - 1) * 40 - 12)
    l:SetText(label)
    local r = Kit.Text(card, "label", "text.primary")
    r:SetPoint("TOPRIGHT", -22, -8 - (i - 1) * 40 - 12)
    v.rows[i] = r
    if i > 1 then
      local d = Kit.Divider(card)
      d:SetPoint("TOPLEFT", 16, -8 - (i - 1) * 40)
      d:SetPoint("TOPRIGHT", -16, -8 - (i - 1) * 40)
    end
  end
  local enter = Kit.Button(v, "Enter the game", 160, function() f:Hide() end, "primary")
  enter:SetPoint("TOP", card, "BOTTOM", 86, -26)
  local studio = Kit.Button(v, "Fine-tune in Studio", 180, function() f:Hide(); PUI.OptionsHost:OpenStudio() end, "secondary", A.Icon("studio"))
  studio:SetPoint("RIGHT", enter, "LEFT", -12, 0)
  local foot = Kit.Text(v, "small", "muted")
  foot:SetPoint("TOP", card, "BOTTOM", 0, -80)
  foot:SetText("Open settings any time: Game Menu > Phoenix UI, the minimap phoenix, or /pui")
  function v:Refresh()
    local c = SU.choices
    self.head:SetText("You're ready, " .. (UnitName("player") or "champion"))
    local lang = PUI.Locale:Resolve(c.language or "auto")
    local scale = type(c.scale) == "number" and string.format("%.2f", c.scale) or "Unchanged"
    self.rows[1]:SetText(lang)
    self.rows[2]:SetText(scale)
    self.rows[3]:SetText(P.ROLE_LABELS[c.role] or "-")
    self.rows[4]:SetText(P.LAYOUTS[c.layout] and P.LAYOUTS[c.layout].label or "-")
    self.rows[5]:SetText((Theme.ACCENT_LABELS[c.accent] or "-") .. " - " .. (Theme.PANEL_LABELS[c.panel] or "-"))
  end
  return v
end

-- Flow ----------------------------------------------------------------------------------
-- SU.step: 0 welcome, 1..5 the steps, 6 finish.
local function page(f, id)
  local p = f.pages[id]
  if not p then
    p = Pages[id](f)
    f.pages[id] = p
  end
  return p
end

function SU.Render()
  local f = SU.frame
  if not f then return end
  for _, p in pairs(f.pages) do p:Hide() end
  local stepped = SU.step >= 1 and SU.step <= #SU.STEPS
  f.rail:SetShown(stepped)
  f.stage:SetShown(stepped)
  local id = stepped and SU.STEPS[SU.step] or (SU.step == 0 and "welcome" or "finish")
  local p = page(f, id)
  p:Show()
  p:Refresh()
  if not stepped then return end
  f.title:SetText(p.title)
  if p.sub then f.sub:SetText(p.sub) end
  for i, it in ipairs(f.rail.items) do
    local done, cur = i < SU.step, i == SU.step
    it.tick:SetShown(done)
    it.num:SetShown(not done)
    it.ring:SetShown(cur)
    if done then Theme:Paint(it.circle, "accent", 1, "vertex") else Theme:Paint(it.circle, "bg3", 1, "vertex") end
    Theme:Paint(it.label, (done or cur) and "text.primary" or "muted", 1, "text")
  end
  f.rail.progress:SetText("Step " .. SU.step .. " of " .. #SU.STEPS .. "  -  about 1 minute")
  f.rail.fill:SetWidth(f.rail.trackW * SU.step / #SU.STEPS)
  f.go:SetLabel(SU.step == #SU.STEPS and "Finish  >" or "Continue  >")
end

function SU.Go(dir)
  if dir > 0 and SU.step == #SU.STEPS then
    SU.ApplyChoices(SU.choices)
    SU.step = #SU.STEPS + 1
  elseif dir > 0 and SU.step > #SU.STEPS then
    if SU.frame then SU.frame:Hide() end
    return
  else
    SU.step = math.max(0, math.min(#SU.STEPS, SU.step + dir))
  end
  SU.Render()
end

function SU.Skip()
  SU.saveState({ wizardDone = true })
  if SU.frame then SU.frame:Hide() end
end

-- Wizard choices for a step, for /pui and the tests.
local OPTIONS = {
  language = function() return PUI.Locale.CHOICES end,
  scale = function() return { "keep", "pixel" } end,
  role = function() return P.WIZARD_ROLES end,
  layout = function() return P.LAYOUT_ORDER end,
  look = function() return Theme.DESIGN_ACCENTS end,
}
SU.OPTIONS = OPTIONS

function SU.Cycle(step, dir)
  local list = OPTIONS[step]()
  local field = step == "look" and "accent" or step
  local idx = 1
  for i, v in ipairs(list) do if v == SU.choices[field] then idx = i end end
  idx = (idx - 1 + (dir or 1)) % #list + 1
  SU.choices[field] = list[idx]
  SU.Render()
end

function SU.OpenWizard()
  CQ.Defer("setup.wizard", function()
    if not PUI.OptionsHost:Load() then return end
    Kit, A = PUI.Options.Kit, PUI.Options.Assets
    SU.step = 0
    SU.choices = SU.Defaults()
    build():Show()
    SU.Render()
  end)
end
