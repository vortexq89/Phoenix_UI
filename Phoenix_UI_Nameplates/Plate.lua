local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplate elements (PUI_V2 5.5): one pooled Phoenix frame per visible plate,
-- parented to the Blizzard plate. Health, name, health text, cast bar, raid
-- marker, target highlight, classification and quest icons and an execute
-- marker. Possibly secret values (health, names, cast info, booleans) go only
-- to widget methods; Lua only compares values after Secret.IsSecret says no.
local _, ns = ...
local Bars, Theme, Media, Secret = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "Nameplates"

local P = { pool = {} }
ns.Plate = P

local function fontString(parent, justify, size)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(size or "number"))
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  return fs
end

local function icon(parent, size)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size, size)
  t:Hide()
  return t
end

-- Builds one plate frame (unprotected; created in or out of combat).
function P.Build()
  local f = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
  f:Hide()
  f.health = Bars:Create(f, OWNER)
  f.outline = Theme:Outline(f.health, "line")
  f.name = fontString(f, "CENTER", "body")
  f.name:SetPoint("BOTTOM", f.health, "TOP", 0, 2)
  f.hp = fontString(f.health, "RIGHT")
  f.hp:SetPoint("RIGHT", f.health, "RIGHT", -2, 0)
  f.cast = Bars:Create(f, OWNER)
  f.cast:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
  f.cast:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -2)
  Bars.TokenColor(f.cast, "accent")
  f.cast.text = fontString(f.cast, "LEFT")
  f.cast.text:SetPoint("LEFT", f.cast, "LEFT", 2, 0)
  f.cast.text:SetPoint("RIGHT", f.cast, "RIGHT", -2, 0)
  f.cast.icon = f.cast:CreateTexture(nil, "ARTWORK")
  f.cast.icon:SetPoint("RIGHT", f.cast, "LEFT", -2, 0)
  f.cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.cast.shield = PUI:CreateFrame("Frame", nil, f.cast, nil, OWNER)
  f.cast.shield:SetAllPoints(f.cast)
  local tint = f.cast.shield:CreateTexture(nil, "OVERLAY")
  tint:SetAllPoints()
  Theme:Paint(tint, "text.secondary", 0.45)
  f.cast.shield:SetAlpha(0)
  f.cast:Hide()
  -- Target highlight: a frame so its alpha can follow a boolean.
  f.glow = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
  f.glow:SetPoint("TOPLEFT", f.health, "TOPLEFT", -2, 2)
  f.glow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 2, -2)
  f.glow.tex = Theme:Outline(f.glow, "accent")
  f.glow:SetAlpha(0)
  f.marker = icon(f, 18)
  f.marker:SetPoint("RIGHT", f.health, "LEFT", -4, 0)
  f.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.classif = icon(f, 14)
  f.classif:SetPoint("LEFT", f.health, "RIGHT", 2, 0)
  f.classif:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  f.quest = icon(f, 14)
  f.quest:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", -2, 2)
  f.quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  f.execute = f.health:CreateTexture(nil, "OVERLAY")
  f.execute:SetWidth(1)
  f.execute:SetColorTexture(1, 1, 1, 0.8)
  f.execute:Hide()
  return f
end

function P.Acquire()
  local f = table.remove(P.pool)
  return f or P.Build()
end

function P.Release(f)
  f:Hide()
  f:ClearAllPoints()
  f:SetParent(UIParent)
  f.unit = nil
  f.cast:Hide()
  P.pool[#P.pool + 1] = f
end

-- Geometry from resolved settings s.
function P.Layout(f, s)
  f:SetSize(s.width, s.height + (s.castbar and (s.castHeight + 2) or 0))
  f.health:ClearAllPoints()
  f.health:SetPoint("TOPLEFT", f, "TOPLEFT")
  f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT")
  f.health:SetHeight(s.height)
  f.cast:SetHeight(s.castHeight)
  f.cast.icon:SetSize(s.castHeight, s.castHeight)
  if s.execute > 0 then
    f.execute:ClearAllPoints()
    f.execute:SetPoint("TOP", f.health, "TOPLEFT", s.width * s.execute / 100, 0)
    f.execute:SetPoint("BOTTOM", f.health, "BOTTOMLEFT", s.width * s.execute / 100, 0)
    f.execute:Show()
  else
    f.execute:Hide()
  end
end

-- Colours ---------------------------------------------------------------------
-- Threat status 0-3 (UnitThreatSituation); tanks want 3, others want 0.
local THREAT = {
  tank = { [0] = "danger", [1] = "spark", [2] = "spark", [3] = "success" },
  other = { [0] = "success", [1] = "spark", [2] = "spark", [3] = "danger" },
}
P.THREAT = THREAT

local function plain(v) return not Secret.IsSecret(v) end

function P.ThreatToken(unit, role)
  local status = UnitThreatSituation("player", unit)
  if type(status) == "nil" or not plain(status) then return nil end
  return THREAT[role == "TANK" and "tank" or "other"][status]
end

function P.UpdateColor(f, s)
  local unit, bar = f.unit, f.health
  local tapped = UnitIsTapDenied(unit)
  if plain(tapped) and tapped then return Bars.Color(bar, 0.5, 0.5, 0.5) end
  if s.threat then
    local inCombat = UnitAffectingCombat(unit)
    if plain(inCombat) and inCombat then
      local token = P.ThreatToken(unit, ns.role)
      if token then return Bars.TokenColor(bar, token) end
    end
  end
  if s.colorMode == "class" then
    local isPlayer = UnitIsPlayer(unit)
    if (Secret.IsSecret(isPlayer) or isPlayer) and Bars.ClassColor(bar, unit) then return end
  end
  Bars.Color(bar, UnitSelectionColor(unit))
end

-- Channels ---------------------------------------------------------------------
function P.UpdateHealth(f, s)
  local unit = f.unit
  Bars:SetValues(f.health, UnitHealthMax(unit), UnitHealth(unit), false)
  if s.healthText == "percent" then
    f.hp:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    f.hp:Show()
  else
    f.hp:Hide()
  end
end

function P.UpdateName(f, s)
  if not s.nameText and not f.nameOnly then f.name:Hide() return end
  f.name:SetText(UnitName(f.unit))
  f.name:Show()
end

function P.UpdateCast(f, s)
  local cast, unit = f.cast, f.unit
  if not s.castbar or f.nameOnly then cast:Hide() return end
  local dirs = Enum.StatusBarTimerDirection
  local name, _, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
  local duration, dir = nil, dirs.ElapsedTime
  if type(name) ~= "nil" then
    duration = UnitCastingDuration(unit)
  else
    name, _, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
    if type(name) ~= "nil" then
      duration = UnitChannelDuration(unit)
      dir = dirs.RemainingTime
    end
  end
  if type(duration) == "nil" then cast:Hide() return end
  cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, dir)
  cast.text:SetText(name)
  cast.icon:SetTexture(texture)
  cast.shield:SetAlphaFromBoolean(notInterruptible, 1, 0)
  cast:Show()
end

function P.UpdateTarget(f, s)
  if not s.targetHighlight then f.glow:SetAlpha(0) return end
  f.glow:SetAlphaFromBoolean(UnitIsUnit("target", f.unit), 1, 0)
end

function P.UpdateIcons(f, s)
  local unit = f.unit
  local idx
  if s.raidMarker then idx = GetRaidTargetIndex(unit) end
  if type(idx) == "nil" then f.marker:Hide() else f.marker:SetSpriteSheetCell(idx, 4, 4); f.marker:Show() end
  local c = s.classification and UnitClassification(unit)
  if c and plain(c) and (c == "elite" or c == "rareelite" or c == "rare" or c == "worldboss") then
    f.classif:SetVertexColor(c == "rare" and 0.7 or 1, c == "rare" and 0.7 or 0.85, c == "rare" and 1 or 0.2)
    f.classif:Show()
  else
    f.classif:Hide()
  end
  local q = s.quest and C_QuestLog.UnitIsRelatedToActiveQuest(unit)
  f.quest:SetShown(q and plain(q) and q == true or false)
end

-- Friendly name-only mode: a friendly unit shows only its class-coloured name.
function P.ApplyMode(f, s)
  local nameOnly = false
  if s.friendlyNameOnly then
    local friend = UnitIsFriend("player", f.unit)
    nameOnly = plain(friend) and friend == true
  end
  f.nameOnly = nameOnly
  f.health:SetShown(not nameOnly)
  if nameOnly then
    local _, token = UnitClass(f.unit)
    local color = type(token) ~= "nil" and C_ClassColor.GetClassColor(token)
    if color then f.name:SetTextColor(color:GetRGB()) else f.name:SetTextColor(1, 1, 1) end
  else
    f.name:SetTextColor(1, 1, 1)
  end
end

function P.UpdateAll(f, s)
  P.Layout(f, s)
  P.ApplyMode(f, s)
  P.UpdateColor(f, s)
  P.UpdateHealth(f, s)
  P.UpdateName(f, s)
  P.UpdateCast(f, s)
  P.UpdateTarget(f, s)
  P.UpdateIcons(f, s)
end
