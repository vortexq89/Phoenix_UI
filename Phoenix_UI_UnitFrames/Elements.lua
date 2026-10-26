local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit-frame elements (PUI_V2 5.3): health, power, absorb and heal prediction,
-- four text zones, cast bar, portrait and indicators. Builders create the
-- unprotected children of a secure unit button once; Update* functions are the
-- per-channel refreshers the trackers call. Values that may be secret go only
-- to widget methods (SetValue, SetText, SetFormattedText, SetTimerDuration,
-- SetAlphaFromBoolean, SetStatusBarColor).
local _, ns = ...
local Bars, Theme, Media, Secret, Tags = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret, ns.Tags
local OWNER = "UnitFrames"

local E = {}
ns.Elements = E

local ZONES = { "left", "center", "right", "power" }
E.ZONES = ZONES
local CAST_HEIGHT = 14

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

-- Builds every child once. o = { unit, group, button }.
function E.Build(o)
  local b = o.button
  o.bg = Theme:Backdrop(b, "surface.0")
  o.outline = Theme:Outline(b, "line")
  o.health = Bars:Create(b, OWNER)
  o.health:SetClipsChildren(true) -- absorb / prediction segments are clipped at the bar end
  o.power = Bars:Create(b, OWNER)

  -- Prediction segments start where the health fill ends and are clipped by the bar.
  local fill = o.health:GetStatusBarTexture()
  o.fill = fill
  o.incoming = overlayBar(o, o.health)
  Bars.Color(o.incoming, 0.3, 0.9, 0.4, 0.5)
  o.absorb = overlayBar(o, o.health)
  Bars.Color(o.absorb, 0.85, 0.9, 1, 0.55)
  o.healAbsorb = overlayBar(o, o.health)
  Bars.TokenColor(o.healAbsorb, "danger", 0.45)

  local textLayer = PUI:CreateFrame("Frame", nil, b, nil, OWNER)
  textLayer:SetAllPoints(b)
  textLayer:SetFrameLevel(o.health:GetFrameLevel() + 3)
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

  E.BuildCast(o)
  E.BuildPortrait(o)
  E.BuildIndicators(o, textLayer)
end

function E.BuildCast(o)
  local cast = Bars:Create(o.button, OWNER)
  cast:SetHeight(CAST_HEIGHT)
  cast:SetPoint("TOPLEFT", o.button, "BOTTOMLEFT", CAST_HEIGHT + 2, -3)
  cast:SetPoint("TOPRIGHT", o.button, "BOTTOMRIGHT", 0, -3)
  Bars.TokenColor(cast, "accent")
  cast.icon = cast:CreateTexture(nil, "ARTWORK")
  cast.icon:SetSize(CAST_HEIGHT, CAST_HEIGHT)
  cast.icon:SetPoint("RIGHT", cast, "LEFT", -2, 0)
  cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  cast.text = fontString(cast, "LEFT")
  cast.text:SetPoint("LEFT", cast, "LEFT", 3, 0)
  cast.text:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
  -- Uninterruptible shield: an overlay whose alpha follows a (possibly secret) boolean.
  cast.shield = PUI:CreateFrame("Frame", nil, cast, nil, OWNER)
  cast.shield:SetAllPoints(cast)
  local tint = cast.shield:CreateTexture(nil, "OVERLAY")
  tint:SetAllPoints()
  Theme:Paint(tint, "text.secondary", 0.45)
  cast.shield:SetAlpha(0)
  cast:Hide()
  o.cast = cast
end

function E.BuildPortrait(o)
  local p = PUI:CreateFrame("Frame", nil, o.button, nil, OWNER)
  p:SetPoint("TOPRIGHT", o.button, "TOPLEFT", -2, 0)
  p.tex = p:CreateTexture(nil, "ARTWORK")
  p.tex:SetAllPoints()
  p.tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
  p.model = PUI:CreateFrame("PlayerModel", nil, p, nil, OWNER)
  p.model:SetAllPoints()
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

-- Geometry from the unit's settings (c = resolved config).
function E.Layout(o, c)
  local power = c.powerHeight
  o.health:ClearAllPoints()
  o.health:SetPoint("TOPLEFT", o.button, "TOPLEFT", 1, -1)
  o.health:SetPoint("TOPRIGHT", o.button, "TOPRIGHT", -1, -1)
  o.health:SetHeight(math.max(1, c.height - 2 - (power > 0 and (power + 1) or 0)))
  o.power:ClearAllPoints()
  o.power:SetPoint("TOPLEFT", o.health, "BOTTOMLEFT", 0, -1)
  o.power:SetPoint("TOPRIGHT", o.health, "BOTTOMRIGHT", 0, -1)
  o.power:SetHeight(math.max(1, power))
  o.power:SetShown(power > 0)
  o.texts.power:SetShown(power > 0)
  Bars:SetFill(o.health, c.reverse, false)
  Bars:SetFill(o.power, c.reverse, false)
  anchorSegment(o, o.incoming, true, c.reverse)
  anchorSegment(o, o.absorb, true, c.reverse)
  anchorSegment(o, o.healAbsorb, false, c.reverse)
  local w = c.width - 2
  o.incoming:SetWidth(w)
  o.absorb:SetWidth(w)
  o.healAbsorb:SetWidth(w)
  o.portrait:SetSize(c.height, c.height)
  o.health:GetStatusBarTexture():SetAlpha(ns.settings.fillAlpha)
end

-- Channels ------------------------------------------------------------------
function E.UpdateHealthColor(o)
  local mode, unit, bar = ns.settings.colorMode, o.unit, o.health
  if mode == "class" then
    local isPlayer = UnitIsPlayer(unit)
    if (Secret.IsSecret(isPlayer) or isPlayer) and Bars.ClassColor(bar, unit) then return end
    Bars.Color(bar, UnitSelectionColor(unit))
  elseif mode == "reaction" then
    Bars.Color(bar, UnitSelectionColor(unit))
  elseif mode == "gradient" then
    local color = UnitHealthPercent(unit, true, Bars:HealthCurve())
    bar:SetStatusBarColor(color:GetRGB())
  else
    Bars.TokenColor(bar, "accent")
  end
end

function E.UpdateHealth(o)
  local unit = o.unit
  Bars:SetValues(o.health, UnitHealthMax(unit), UnitHealth(unit), ns.settings.smooth)
  if ns.settings.colorMode == "gradient" then E.UpdateHealthColor(o) end
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
  local calc = o.calc
  if not calc then return end
  local unit = o.unit
  UnitGetDetailedHealPrediction(unit, "player", calc)
  local maxHealth = UnitHealthMax(unit)
  local s = ns.settings
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
  local p, mode = o.portrait, o.cfg.portrait
  if mode == "off" then p:Hide() return end
  p:Show()
  if mode == "3d" then
    p.tex:Hide()
    p.model:Show()
    p.model:SetUnit(o.unit)
    p.model:SetPortraitZoom(1)
  else
    p.model:Hide()
    p.tex:Show()
    SetPortraitTexture(p.tex, o.unit)
  end
end

-- Cast bar: the engine animates the fill from a duration object.
function E.UpdateCast(o)
  local cast, unit = o.cast, o.unit
  if not o.cfg.castbar then cast:Hide() return end
  local direction = Enum.StatusBarTimerDirection
  local name, _, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
  local duration, dir = nil, direction.ElapsedTime
  if type(name) ~= "nil" then
    duration = UnitCastingDuration(unit)
  else
    name, _, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
    if type(name) ~= "nil" then
      duration = UnitChannelDuration(unit)
      dir = direction.RemainingTime
    end
  end
  if type(duration) == "nil" then cast:Hide() return end
  cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, dir)
  cast.text:SetText(name)
  cast.icon:SetTexture(texture)
  cast.shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
  cast:Show()
end

function E.StopCast(o) o.cast:Hide() end

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
  E.UpdateIndicators(o)
end
