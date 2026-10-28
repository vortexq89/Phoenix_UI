local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit-frame elements (plan 5.1, 15.3, mockup 01): health, power, absorbs and
-- heal prediction, four text zones, portrait (2D / 3D / class icon, square or
-- round, either side), border and background from the look, threat glow,
-- indicators, and the cast bar through PUI.CastBar (plan 1.O: one cast bar
-- element; auras live in Auras.lua on PUI.Auras). Builders create the
-- unprotected children of a secure unit button once; Update* functions are
-- the per-channel painters the trackers call. Values that may be secret go
-- only to widget methods (SetValue, SetText, SetFormattedText, SetTimerDuration,
-- SetAlphaFromBoolean, SetStatusBarColor); Lua never compares them (G1).
local _, ns = ...
local Bars, Theme, Media, Secret, Tags, Styles = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret, ns.Tags, ns.Styles
local OWNER = "UnitFrames"

local E = {}
ns.Elements = E

local ZONES = { "left", "center", "right", "power" }
E.ZONES = ZONES
local GLOW = "Interface\\AddOns\\Phoenix_UI_Media\\Media\\Textures\\NineSlice\\Shadow_Soft"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local OUTLINES = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE", shadow = "" }
E.NO_CAST = { player = true } -- the player cast bar is Resource Bars' (plan 1.O)

local function fontString(parent, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject("number"))
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  return fs
end

local function overlayBar(o, parent)
  local bar = Bars:Create(parent, OWNER, "BACKGROUND")
  bar.bg:SetAlpha(0)
  bar:SetFrameLevel(o.health:GetFrameLevel() + 1)
  return bar
end

-- Anchors a prediction segment to the end (after = true) or the inside edge of
-- the health fill, mirrored when the bar fills right to left.
local function anchorSegment(o, bar, after, reverse)
  local near, far = "LEFT", "RIGHT"
  if reverse then near, far = "RIGHT", "LEFT" end
  bar:ClearAllPoints()
  bar:SetPoint("TOP", o.health, "TOP")
  bar:SetPoint("BOTTOM", o.health, "BOTTOM")
  if after then
    bar:SetPoint(near, o.fill, far)
    bar:SetReverseFill(reverse == true)
  else
    bar:SetPoint(far, o.fill, far)
    bar:SetReverseFill(not reverse)
  end
end

-- Four edge textures: a crisp pixel border of any thickness (G23 whole pixels).
local function buildBorder(parent)
  local edges = {}
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0, 0, 0, 1)
    edges[side] = t
  end
  return edges
end

local function layoutBorder(edges, frame, px)
  local t, b, l, r = edges.top, edges.bottom, edges.left, edges.right
  for _, e in pairs(edges) do e:ClearAllPoints(); e:SetShown(px > 0) end
  if px <= 0 then return end
  t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); t:SetHeight(px)
  b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0); b:SetHeight(px)
  l:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0); l:SetWidth(px)
  r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0); r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0); r:SetWidth(px)
end
E.LayoutBorder = layoutBorder

local function paintEdges(edges, r, g, b, a)
  for _, e in pairs(edges) do e:SetColorTexture(r, g, b, a or 1) end
end

-- Builds every child once. o = { unit, group, button }.
function E.Build(o)
  local b = o.button
  -- body: every visual lives here so range fading never touches the secure button.
  local body = PUI:CreateFrame("Frame", nil, b, nil, OWNER)
  body:SetAllPoints(b)
  o.body = body
  o.bg = body:CreateTexture(nil, "BACKGROUND", nil, -8)
  o.bg:SetAllPoints(body)
  o.glow = Theme:Slice(body, GLOW, 12, "BACKGROUND")
  o.glow:ClearAllPoints()
  o.glow:SetPoint("TOPLEFT", body, "TOPLEFT", -6, 6)
  o.glow:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 6, -6)
  o.glow:Hide()
  o.health = Bars:Create(body, OWNER)
  o.health:SetClipsChildren(true) -- absorb / prediction segments are clipped at the bar end
  o.power = Bars:Create(body, OWNER)
  o.edge = o.health:CreateTexture(nil, "OVERLAY")
  o.edge:SetHeight(1)
  o.edge:SetPoint("BOTTOMLEFT", o.health, "BOTTOMLEFT")
  o.edge:SetPoint("BOTTOMRIGHT", o.health, "BOTTOMRIGHT")
  Theme:Paint(o.edge, "accent", 0.9)
  o.edge:Hide()

  local borderFrame = PUI:CreateFrame("Frame", nil, body, nil, OWNER)
  borderFrame:SetAllPoints(body)
  borderFrame:SetFrameLevel(o.health:GetFrameLevel() + 4)
  o.borderFrame = borderFrame
  o.border = buildBorder(borderFrame)

  -- Prediction segments start where the health fill ends and are clipped by the bar.
  o.fill = o.health:GetStatusBarTexture()
  o.incoming = overlayBar(o, o.health)
  Bars.Color(o.incoming, 0.3, 0.9, 0.4, 0.5)
  o.absorb = overlayBar(o, o.health)
  Bars.Color(o.absorb, 0.85, 0.9, 1, 0.55)
  o.healAbsorb = overlayBar(o, o.health)
  Bars.TokenColor(o.healAbsorb, "danger", 0.45)

  local textLayer = PUI:CreateFrame("Frame", nil, body, nil, OWNER)
  textLayer:SetAllPoints(body)
  textLayer:SetFrameLevel(o.health:GetFrameLevel() + 5)
  o.textLayer = textLayer
  o.texts = {
    left = fontString(textLayer, "LEFT"),
    center = fontString(textLayer, "CENTER"),
    right = fontString(textLayer, "RIGHT"),
    power = fontString(textLayer, "CENTER"),
  }
  o.texts.left:SetPoint("LEFT", o.health, "LEFT", 4, 0)
  o.texts.center:SetPoint("CENTER", o.health, "CENTER")
  o.texts.right:SetPoint("RIGHT", o.health, "RIGHT", -4, 0)
  o.texts.power:SetPoint("CENTER", o.power, "CENTER")

  E.BuildPortrait(o)
  E.BuildIndicators(o, textLayer)
  o.auraHolders = {}
end

function E.BuildPortrait(o)
  local p = PUI:CreateFrame("Frame", nil, o.body, nil, OWNER)
  p.bg = p:CreateTexture(nil, "BACKGROUND")
  p.bg:SetAllPoints()
  p.bg:SetColorTexture(0, 0, 0, 0.6)
  p.tex = p:CreateTexture(nil, "ARTWORK")
  p.tex:SetPoint("TOPLEFT", 1, -1)
  p.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  p.model = PUI:CreateFrame("PlayerModel", nil, p, nil, OWNER)
  p.model:SetPoint("TOPLEFT", 1, -1)
  p.model:SetPoint("BOTTOMRIGHT", -1, 1)
  p.border = buildBorder(p)
  p:Hide()
  o.portrait = p
end

local function icon(parent, size, point, x, y)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size, size)
  t:SetPoint(point, parent, point, x, y)
  t:Hide()
  return t
end

function E.BuildIndicators(o, layer)
  local ind = {}
  ind.raidMarker = icon(layer, 16, "TOP", 0, 8)
  ind.raidMarker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  ind.leader = icon(layer, 12, "TOPLEFT", 2, 7)
  ind.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  ind.combat = icon(layer, 14, "BOTTOMRIGHT", 4, -4)
  ind.combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
  ind.combat:SetTexCoord(0.5, 1, 0, 0.49)
  ind.resting = icon(layer, 14, "TOPRIGHT", 4, 7)
  ind.resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
  ind.resting:SetTexCoord(0, 0.5, 0, 0.42)
  ind.classification = icon(layer, 14, "TOPRIGHT", -14, 7)
  ind.classification:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  ind.pvp = icon(layer, 16, "BOTTOMLEFT", -4, -4)
  o.ind = ind
end

-- Effective look of a group (look + per-attribute settings + group portrait).
function E.Look(o)
  local s = ns.settings
  local edge
  if s.edge == "on" then edge = true elseif s.edge == "off" then edge = false end
  local look = Styles.Resolve(s.style, { border = s.border, borderColor = s.borderColor, background = s.background,
    power = s.powerStyle, shape = s.portraitShape, edge = edge })
  local p = o.cfg.portrait
  if p ~= "look" then look.portrait = p end
  return look
end

local function applyFont(fs, s)
  local base = Media:FontObject("number")
  local path = s.font ~= "global" and Media:Font(s.font) or (base.GetFont and base:GetFont())
  if path and fs.SetFont then fs:SetFont(path, s.fontSize, OUTLINES[s.fontOutline] or "") end
  if s.fontOutline == "shadow" then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
  else fs:SetShadowOffset(0, 0) end
end

-- Geometry from the unit's settings (c = resolved config).
function E.Layout(o, c)
  local s = ns.settings
  local look = E.Look(o)
  o.look = look
  local px = look.borderPx
  local power = c.powerHeight
  local inner = c.height - 2 * px
  local style = look.power
  local attached = power > 0 and style == "attached"
  o.health:ClearAllPoints()
  o.health:SetPoint("TOPLEFT", o.button, "TOPLEFT", px, -px)
  o.health:SetPoint("TOPRIGHT", o.button, "TOPRIGHT", -px, -px)
  o.health:SetHeight(math.max(1, attached and (inner - power - look.gap) or inner))
  o.power:ClearAllPoints()
  if style == "inset" then
    o.power:SetPoint("BOTTOMLEFT", o.health, "BOTTOMLEFT", 4, 3)
    o.power:SetPoint("BOTTOMRIGHT", o.health, "BOTTOMRIGHT", -4, 3)
    o.power:SetFrameLevel(o.health:GetFrameLevel() + 2)
  elseif style == "floating" then
    o.power:SetPoint("TOP", o.button, "BOTTOM", 0, -2)
    o.power:SetWidth(math.floor(c.width * 0.8 + 0.5))
  else
    o.power:SetPoint("TOPLEFT", o.health, "BOTTOMLEFT", 0, -look.gap)
    o.power:SetPoint("TOPRIGHT", o.health, "BOTTOMRIGHT", 0, -look.gap)
  end
  o.power:SetHeight(math.max(1, power))
  o.power:SetShown(power > 0)
  o.texts.power:SetShown(power > 0)
  Bars:SetFill(o.health, c.reverse, c.vertical)
  Bars:SetFill(o.power, c.reverse, false)
  local tex = c.texture ~= "global" and (Media:Path("statusbar", c.texture) or Media:Texture(c.texture)) or Bars:TexturePath()
  o.health:SetStatusBarTexture(tex)
  o.power:SetStatusBarTexture(tex)
  o.fill = o.health:GetStatusBarTexture()
  anchorSegment(o, o.incoming, true, c.reverse)
  anchorSegment(o, o.absorb, true, c.reverse)
  anchorSegment(o, o.healAbsorb, false, c.reverse)
  local w = c.width - 2 * px
  o.incoming:SetWidth(w)
  o.absorb:SetWidth(w)
  o.healAbsorb:SetWidth(w)
  o.fill:SetAlpha(s.fillAlpha)
  -- chrome
  layoutBorder(o.border, o.button, px)
  E.PaintBorder(o)
  o.glow:SetShown(look.border == "glow")
  local r, g, b = Theme:Color("surface.0")
  o.bg:SetColorTexture(r, g, b, look.bgAlpha)
  o.health.bg:SetAlpha(look.background == "clear" and 0 or 1)
  o.edge:SetShown(look.edge == true)
  -- portrait
  local p = o.portrait
  local size = c.height
  p:ClearAllPoints()
  p:SetSize(size, size)
  if c.portraitSide == "right" then p:SetPoint("TOPLEFT", o.button, "TOPRIGHT", 3, 0)
  else p:SetPoint("TOPRIGHT", o.button, "TOPLEFT", -3, 0) end
  p.tex:SetMask(look.shape == "circle" and ROUND_MASK or "")
  layoutBorder(p.border, p, look.shape == "circle" and 0 or math.max(1, px))
  for _, fs in pairs(o.texts) do applyFont(fs, s) end
  E.LayoutCast(o, c)
end

function E.PaintBorder(o)
  local look = o.look
  if not look then return end
  local mode = look.borderColor
  if mode == "accent" then paintEdges(o.border, Theme:Color("accent"))
  elseif mode == "gold" then paintEdges(o.border, Styles.GOLD.r, Styles.GOLD.g, Styles.GOLD.b, 1)
  elseif mode == "class" then
    local _, token = UnitClass(o.unit)
    local color = token ~= nil and C_ClassColor.GetClassColor(token)
    if color then paintEdges(o.border, color:GetRGB()) else paintEdges(o.border, 0, 0, 0, 1) end
  else paintEdges(o.border, 0, 0, 0, 1) end
  paintEdges(o.portrait.border, 0, 0, 0, 1)
end

-- Channels ------------------------------------------------------------------
function E.UpdateHealthColor(o)
  local s = ns.settings
  local mode, unit, bar = s.colorMode, o.unit, o.health
  if mode == "look" then mode = (o.look and o.look.colorMode) or "class" end
  if s.darkMode then
    bar:SetStatusBarColor(0.16, 0.16, 0.18, 1)
    local _, token = UnitClass(unit)
    local color = token ~= nil and C_ClassColor.GetClassColor(token)
    if color then bar.bg:SetVertexColor(color:GetRGB()) end
    return
  end
  local tapped = UnitIsTapDenied(unit)
  if not Secret.IsSecret(tapped) and tapped then bar:SetStatusBarColor(0.5, 0.5, 0.5, 1) return end
  if mode == "class" then
    local isPlayer = UnitIsPlayer(unit)
    if (Secret.IsSecret(isPlayer) or isPlayer) and Bars.ClassColor(bar, unit) then return end
    Bars.Color(bar, UnitSelectionColor(unit))
  elseif mode == "reaction" then
    Bars.Color(bar, UnitSelectionColor(unit))
  elseif mode == "gradient" then
    local color = UnitHealthPercent(unit, true, Bars:HealthCurve())
    bar:SetStatusBarColor(color:GetRGB())
  elseif mode == "custom" then
    local c = s.healthColor
    bar:SetStatusBarColor(c.r, c.g, c.b, 1)
  else
    Bars.TokenColor(bar, "accent")
  end
end

local function gradientNow(o)
  local mode = ns.settings.colorMode
  return mode == "gradient" or (mode == "look" and o.look ~= nil and o.look.colorMode == "gradient")
end

function E.UpdateHealth(o)
  local unit = o.unit
  Bars:SetValues(o.health, UnitHealthMax(unit), UnitHealth(unit), ns.settings.smooth)
  if gradientNow(o) and not ns.settings.darkMode then E.UpdateHealthColor(o) end
  E.UpdateTexts(o, "health")
end

function E.UpdatePower(o)
  if o.cfg.powerHeight <= 0 then return end
  local unit = o.unit
  Bars:SetValues(o.power, UnitPowerMax(unit), UnitPower(unit), ns.settings.smooth)
  E.UpdateTexts(o, "power")
end

function E.UpdatePowerType(o)
  Bars.PowerColor(o.power, o.unit)
  E.UpdatePower(o)
end

-- Absorbs and incoming heals through one heal-prediction calculator per unit.
function E.UpdatePrediction(o)
  local s = ns.settings
  o.absorb:SetShown(s.absorbs)
  o.healAbsorb:SetShown(s.absorbs)
  o.incoming:SetShown(s.healPrediction)
  local calc = o.calc
  if not calc then return end
  local unit = o.unit
  UnitGetDetailedHealPrediction(unit, "player", calc)
  local maxHealth = UnitHealthMax(unit)
  if s.absorbs then
    Bars:SetValues(o.absorb, maxHealth, (calc:GetDamageAbsorbs()))
    Bars:SetValues(o.healAbsorb, maxHealth, (calc:GetHealAbsorbs()))
  end
  if s.healPrediction then
    Bars:SetValues(o.incoming, maxHealth, (calc:GetIncomingHeals()))
  end
end

function E.UpdateTexts(o, channel)
  local c = o.cfg
  for i = 1, #ZONES do
    local zone = ZONES[i]
    local tag = c.texts[zone]
    if channel == nil or Tags.events[tag] == channel then Tags.Render(o.texts[zone], tag, o.unit) end
  end
end

function E.UpdatePortrait(o)
  local p = o.portrait
  local mode = (o.look and o.look.portrait) or "off"
  if mode == "off" then p:Hide() return end
  p:Show()
  if mode == "3d" then
    p.tex:Hide()
    p.model:Show()
    p.model:SetUnit(o.unit)
    p.model:SetPortraitZoom(1)
    return
  end
  p.model:Hide()
  p.tex:Show()
  if mode == "class" then
    local _, token = UnitClass(o.unit)
    local coords = token ~= nil and not Secret.IsSecret(token) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
    if coords then
      p.tex:SetTexture(CLASS_ICONS)
      p.tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      return
    end
  end
  p.tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
  SetPortraitTexture(p.tex, o.unit)
end

-- Cast bar (PUI.CastBar, plan 1.O). Created on first use, disabled when off.
function E.CastStyle(o, c)
  local s = ns.settings
  local height = c.castHeight
  local width = c.castWidth > 0 and c.castWidth or (c.width - (c.castIcon and (height + 2) or 0))
  return { width = width, height = height, icon = c.castIcon, iconSide = "LEFT", spellName = c.castName,
    timer = c.castTimer, shield = c.castShield, kick = c.castKick, fadeOut = s.castFade,
    texture = c.texture ~= "global" and c.texture or nil, colors = s.castColors }
end

function E.LayoutCast(o, c)
  if not c.castbar or E.NO_CAST[o.group] then
    if o.castbar then o.castbar:Disable() end
    return
  end
  local style = E.CastStyle(o, c)
  if not o.castbar then
    o.castbar = PUI.CastBar:Create(OWNER, o.body, o.unit, style)
  else
    o.castbar:ApplyStyle(style)
  end
  local f = o.castbar.frame
  f:ClearAllPoints()
  local offset = c.castIcon and (c.castHeight + 2) or 0
  if c.castPosition == "above" then
    f:SetPoint("BOTTOMLEFT", o.button, "TOPLEFT", offset, 3)
  else
    f:SetPoint("TOPLEFT", o.button, "BOTTOMLEFT", offset, -3)
  end
  if o.live then o.castbar:Enable() else o.castbar:Disable() end
end

-- Extra space under the frame taken by the cast bar (boss stacking, auras below).
function E.CastSpace(group, c)
  if not c.castbar or E.NO_CAST[group] or c.castPosition == "above" then return 0 end
  return c.castHeight + 3
end

function E.UpdateCast(o)
  local cb = o.castbar
  if cb and cb.enabled then cb:Refresh() end
end

-- Threat glow: the situation number may be secret; then the glow stays off.
function E.UpdateThreat(o)
  local glow = o.threat
  if not glow then
    glow = o.borderFrame:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", o.button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", o.button, "BOTTOMRIGHT", 3, -3)
    glow:SetTexture(GLOW)
    glow:Hide()
    o.threat = glow
  end
  if not ns.settings.threat then glow:Hide() return end
  local status
  if o.unit == "player" then status = UnitThreatSituation("player") else status = UnitThreatSituation("player", o.unit) end
  if status == nil or Secret.IsSecret(status) or status < 1 then glow:Hide() return end
  glow:SetVertexColor(GetThreatStatusColor(status))
  glow:Show()
end

local function flag(tex, on, value)
  if not on or Secret.IsSecret(value) then tex:Hide() return end
  tex:SetShown(value and true or false)
end

function E.UpdateIndicators(o)
  local unit, ind, s = o.unit, o.ind, ns.settings.indicators
  local idx
  if s.raidMarker then idx = GetRaidTargetIndex(unit) end
  if type(idx) == "nil" then
    ind.raidMarker:Hide()
  else
    ind.raidMarker:SetSpriteSheetCell(idx, 4, 4)
    ind.raidMarker:Show()
  end
  flag(ind.leader, s.leader, UnitIsGroupLeader(unit))
  flag(ind.combat, s.combat, UnitAffectingCombat(unit))
  flag(ind.resting, s.resting and unit == "player", unit == "player" and IsResting())
  local c = UnitClassification(unit)
  local special = c
  if not Secret.IsSecret(c) then special = c == "elite" or c == "rareelite" or c == "worldboss" or c == "rare" end
  flag(ind.classification, s.classification, special)
  local pvp = UnitIsPVP(unit)
  if s.pvp and not Secret.IsSecret(pvp) and pvp then
    local faction = UnitFactionGroup(unit)
    if Secret.IsSecret(faction) or (faction ~= "Horde" and faction ~= "Alliance") then
      ind.pvp:Hide()
    else
      ind.pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
      ind.pvp:Show()
    end
  else
    ind.pvp:Hide()
  end
end

function E.UpdateAll(o)
  E.UpdateHealthColor(o)
  E.UpdateHealth(o)
  Bars.PowerColor(o.power, o.unit)
  E.UpdatePower(o)
  E.UpdatePrediction(o)
  E.UpdateTexts(o)
  E.UpdatePortrait(o)
  E.UpdateCast(o)
  E.UpdateThreat(o)
  E.UpdateIndicators(o)
  if o.look and o.look.borderColor == "class" then E.PaintBorder(o) end
end

-- Test frames (plan 13.2 "/pui test boss"): fixed sample values painted
-- through the same bars and font strings, so the test view is the real paint.
E.SAMPLES = {
  player = { name = "Abdulrahman", hp = 0.78, pp = 0.6, level = 80 },
  target = { name = "Void Reaver", hp = 0.43, pp = 0.9, level = 82, hostile = true },
  focus = { name = "Healer Bot", hp = 0.91, pp = 0.75, level = 80 },
  pet = { name = "Shadowfiend", hp = 1, pp = 0.5, level = 80 },
  targettarget = { name = "Abdulrahman", hp = 0.78, pp = 0, level = 80 },
  focustarget = { name = "Void Reaver", hp = 0.43, pp = 0, level = 82, hostile = true },
  boss = { name = "Xal'atath", hp = 0.61, pp = 0.4, level = 83, hostile = true },
}

function E.PaintSample(o, index)
  local d = E.SAMPLES[o.group] or E.SAMPLES.target
  local hp = d.hp
  if index and index > 1 then hp = math.max(0.12, hp - 0.18 * (index - 1)) end
  o.health:SetMinMaxValues(0, 1)
  o.health:SetValue(hp)
  o.power:SetMinMaxValues(0, 1)
  o.power:SetValue(d.pp)
  if d.hostile then o.health:SetStatusBarColor(0.85, 0.2, 0.2, 1)
  else
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    o.health:SetStatusBarColor(c and c.r or 0.4, c and c.g or 0.7, c and c.b or 0.9, 1)
  end
  o.power:SetStatusBarColor(0.2, 0.45, 0.95, 1)
  local name = d.name .. ((index and index > 1) and (" " .. index) or "")
  for zone, fs in pairs(o.texts) do
    local tag = o.cfg.texts[zone]
    if tag == "none" then fs:SetText("")
    elseif tag:find("^name") or tag == "level:name" then fs:SetText(name)
    elseif tag:find("^power") then fs:SetFormattedText("%d%%", d.pp * 100)
    elseif tag:find("^health") or tag:find("^status") or tag == "absorb" then fs:SetFormattedText("%d%%", hp * 100)
    else fs:SetText(tostring(d.level)) end
  end
end
