local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group frame elements (PUI_V2 5.4): everything drawn on a party/raid button
-- lives on one unprotected "content" child so range fade can use
-- SetAlphaFromBoolean without touching the secure button. Health, name,
-- status text, healer mana, absorbs, role/leader/marker/ready-check/
-- resurrection/summon/phase icons, aggro and dispel borders, private aura
-- anchors. Possibly secret values go only to widget methods.
local _, ns = ...
local Bars, Theme, Media, Secret = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "RaidFrames"

local E = {}
ns.Elements = E

local function plain(v) return not Secret.IsSecret(v) end
local function fontString(parent, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject("number"))
  fs:SetJustifyH(justify)
  fs:SetWordWrap(false)
  return fs
end
local function icon(parent, size, point, x, y, path)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(size, size)
  t:SetPoint(point, parent, point, x, y)
  if path then t:SetTexture(path) end
  t:Hide()
  return t
end

local ROLE_COORDS = { TANK = { 0, 19 / 64, 22 / 64, 41 / 64 }, HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
  DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 } }
E.ROLE_COORDS = ROLE_COORDS
local READY = { ready = "Interface\\RaidFrame\\ReadyCheck-Ready", notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting" }
E.READY = READY

local function border(parent, token, inset)
  local f = PUI:CreateFrame("Frame", nil, parent, nil, OWNER)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", inset or 0, -(inset or 0))
  f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(inset or 0), inset or 0)
  Theme:Outline(f, token)
  f:Hide()
  return f
end

function E.Build(o)
  local b = o.button
  local c = PUI:CreateFrame("Frame", nil, b, nil, OWNER)
  c:SetAllPoints(b)
  o.content = c
  o.bg = Theme:Backdrop(c, "surface.0")
  o.health = Bars:Create(c, OWNER)
  o.health:SetClipsChildren(true)
  o.absorb = Bars:Create(o.health, OWNER)
  o.absorb.bg:SetAlpha(0)
  Bars.Color(o.absorb, 0.85, 0.9, 1, 0.5)
  o.absorb:SetPoint("TOPLEFT", o.health:GetStatusBarTexture(), "TOPRIGHT")
  o.absorb:SetPoint("BOTTOMLEFT", o.health:GetStatusBarTexture(), "BOTTOMRIGHT")
  o.power = Bars:Create(c, OWNER)
  local layer = PUI:CreateFrame("Frame", nil, c, nil, OWNER)
  layer:SetAllPoints(c)
  layer:SetFrameLevel(o.health:GetFrameLevel() + 3)
  o.layer = layer
  o.name = fontString(layer, "CENTER")
  o.name:SetPoint("CENTER", o.health, "CENTER", 0, 4)
  o.status = fontString(layer, "CENTER")
  o.status:SetPoint("TOP", o.name, "BOTTOM", 0, -1)
  o.role = icon(layer, 12, "TOPLEFT", 2, -2, "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  o.leader = icon(layer, 10, "TOPLEFT", 14, 4, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
  o.marker = icon(layer, 14, "TOPRIGHT", -2, -2, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  o.center = icon(layer, 18, "CENTER", 0, 0) -- ready check / resurrection / summon / phase
  o.aggro = border(c, "danger")
  o.dispel = border(layer, "spark", 2)
  o.privateAnchors = {}
end

function E.Layout(o, s)
  local power = o.showPower and s.manaHeight or 0
  o.health:ClearAllPoints()
  o.health:SetPoint("TOPLEFT", o.content, "TOPLEFT", 1, -1)
  o.health:SetPoint("TOPRIGHT", o.content, "TOPRIGHT", -1, -1)
  o.health:SetHeight(math.max(1, s.height - 2 - (power > 0 and power + 1 or 0)))
  o.absorb:SetWidth(s.width - 2)
  o.power:ClearAllPoints()
  o.power:SetPoint("TOPLEFT", o.health, "BOTTOMLEFT", 0, -1)
  o.power:SetPoint("TOPRIGHT", o.health, "BOTTOMRIGHT", 0, -1)
  o.power:SetHeight(math.max(1, power))
  o.power:SetShown(power > 0)
end

function E.UpdateColor(o, s)
  local unit, bar = o.unit, o.health
  if s.colorMode == "class" and Bars.ClassColor(bar, unit) then return end
  if s.colorMode == "gradient" then
    local color = UnitHealthPercent(unit, true, Bars:HealthCurve())
    return bar:SetStatusBarColor(color:GetRGB())
  end
  Bars.TokenColor(bar, "accent")
end

function E.UpdateHealth(o, s)
  local unit = o.unit
  Bars:SetValues(o.health, UnitHealthMax(unit), UnitHealth(unit), false)
  if s.colorMode == "gradient" then E.UpdateColor(o, s) end
  E.UpdateStatus(o, s)
end

-- Dead / offline / ghost text, else the health text setting.
function E.UpdateStatus(o, s)
  local unit = o.unit
  local online = UnitIsConnected(unit)
  if plain(online) and online == false then o.status:SetText("Offline") return end
  local dead = UnitIsDeadOrGhost(unit)
  if plain(dead) and dead then o.status:SetText("Dead") return end
  if s.healthText == "percent" then
    o.status:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
  elseif s.healthText == "deficit" then
    o.status:SetFormattedText("-%s", AbbreviateNumbers(UnitHealthMissing(unit)))
  else
    o.status:SetText("")
  end
end

function E.UpdateName(o) o.name:SetText(UnitName(o.unit)) end

function E.UpdatePower(o, s)
  if not o.showPower then return end
  local unit = o.unit
  Bars:SetValues(o.power, UnitPowerMax(unit), UnitPower(unit), false)
end

-- Healer mana: shown only for units whose assigned role is HEALER.
function E.UpdateRole(o, s)
  local role = UnitGroupRolesAssigned(o.unit)
  local known = plain(role) and ROLE_COORDS[role]
  if s.roleIcon and known then
    o.role:SetTexCoord(known[1], known[2], known[3], known[4])
    o.role:Show()
  else
    o.role:Hide()
  end
  local healer = s.healerMana and plain(role) and role == "HEALER" or false
  if healer ~= o.showPower then
    o.showPower = healer
    E.Layout(o, s)
  end
  if healer then Bars.PowerColor(o.power, o.unit); E.UpdatePower(o, s) end
end

function E.UpdatePrediction(o, s)
  if not s.absorbs then o.absorb:Hide() return end
  o.calc = o.calc or CreateUnitHealPredictionCalculator()
  UnitGetDetailedHealPrediction(o.unit, "player", o.calc)
  Bars:SetValues(o.absorb, UnitHealthMax(o.unit), (o.calc:GetDamageAbsorbs()))
  o.absorb:Show()
end

function E.UpdateRange(o, s)
  if not s.rangeFade or o.unit == "player" then o.content:SetAlpha(1) return end
  local inRange, checked = UnitInRange(o.unit)
  if plain(checked) and checked == false then o.content:SetAlpha(1) return end
  o.content:SetAlphaFromBoolean(inRange, 1, s.rangeAlpha)
end

function E.UpdateThreat(o, s)
  if not s.aggro then o.aggro:Hide() return end
  local status = UnitThreatSituation(o.unit)
  o.aggro:SetShown(type(status) ~= "nil" and plain(status) and status >= 2 or false)
end

-- Dispel highlight: any debuff the player can dispel on this unit.
function E.UpdateDispel(o, s)
  if not s.dispel then o.dispel:Hide() return end
  local aura = C_UnitAuras.GetAuraDataByIndex(o.unit, 1, "HARMFUL|RAID_PLAYER_DISPELLABLE")
  o.dispel:SetShown(type(aura) ~= "nil")
end

function E.UpdateIndicators(o, s)
  local unit = o.unit
  local leader = s.leader and UnitIsGroupLeader(unit)
  o.leader:SetShown(leader and plain(leader) and leader == true or false)
  local idx
  if s.raidMarker then idx = GetRaidTargetIndex(unit) end
  if type(idx) == "nil" then o.marker:Hide() else o.marker:SetSpriteSheetCell(idx, 4, 4); o.marker:Show() end
  E.UpdateCenter(o, s)
end

-- One centre icon, by priority: ready check, resurrection, summon, phase.
function E.UpdateCenter(o, s)
  local unit, tex = o.unit, nil
  if s.statusIcons then
    local ready = GetReadyCheckStatus(unit)
    if plain(ready) and READY[ready] then
      tex = READY[ready]
    else
      local res = UnitHasIncomingResurrection(unit)
      if plain(res) and res then
        tex = "Interface\\RaidFrame\\Raid-Icon-Rez"
      else
        local summon = C_IncomingSummon.IncomingSummonStatus(unit)
        if plain(summon) and summon == 1 then
          tex = "Interface\\RaidFrame\\Raid-Icon-SummonPending"
        else
          local phase = UnitPhaseReason(unit)
          if type(phase) ~= "nil" and plain(phase) then tex = "Interface\\TargetingFrame\\UI-PhasingIcon" end
        end
      end
    end
  end
  if tex then o.center:SetTexture(tex); o.center:Show() else o.center:Hide() end
end

-- Private auras: anchors the engine fills itself; we never see their data.
function E.UpdatePrivateAuras(o, s)
  for i = #o.privateAnchors, 1, -1 do
    C_UnitAuras.RemovePrivateAuraAnchor(o.privateAnchors[i])
    o.privateAnchors[i] = nil
  end
  if s.privateAuras <= 0 or not o.unit then return end
  local size = math.max(10, math.floor(s.height * 0.45))
  for i = 1, s.privateAuras do
    local id = C_UnitAuras.AddPrivateAuraAnchor({
      unitToken = o.unit, auraIndex = i, parent = o.layer, showCooldownFrame = true, showCooldownEdge = false,
      showCountdownNumbers = false, showDispelIcon = false, isContainer = false,
      iconInfo = { iconAnchor = { point = "BOTTOMRIGHT", relativeTo = o.layer, relativePoint = "BOTTOMRIGHT",
        offsetX = -2 - (i - 1) * (size + 1), offsetY = 2 }, iconWidth = size, iconHeight = size },
    })
    if type(id) ~= "nil" then o.privateAnchors[#o.privateAnchors + 1] = id end
  end
end

function E.UpdateAll(o, s)
  E.Layout(o, s)
  E.UpdateRole(o, s)
  E.UpdateColor(o, s)
  E.UpdateHealth(o, s)
  E.UpdateName(o)
  E.UpdatePrediction(o, s)
  E.UpdateRange(o, s)
  E.UpdateThreat(o, s)
  E.UpdateDispel(o, s)
  E.UpdateIndicators(o, s)
end
