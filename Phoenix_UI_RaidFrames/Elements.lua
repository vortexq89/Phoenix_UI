local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group frame elements (PUI_V2 5.4, plan 5.2, mockup 03): everything drawn on
-- a party/raid button lives on one unprotected "content" child, so range fade
-- and "where to show" use alpha without touching the secure button.
--   health (class / gradient / accent / custom colour), name (class or white,
--   position), status text (dead / offline or the health text setting),
--   healer mana, heal prediction + absorbs + heal absorbs and both overflow
--   marks (PUI.Prediction), role (icon or letter, can hide in combat or for
--   damage dealers), leader, raid marker, one centre status icon (ready check
--   / resurrection / summon / phase), aggro border, dispel highlight (border,
--   glow and/or tint, coloured by debuff type), enemy target dots
--   (PUI.Targeting) and the mouse-over highlight.
-- Possibly secret values go only to widget methods (never compared).
local _, ns = ...
local Bars, Theme, Media, Secret = PUI.Bars, PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "RaidFrames"

local E = {}
ns.Elements = E

local function plain(v) return not Secret.IsSecret(v) end
local function fontString(parent, justify, kind)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(kind or "number"))
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
local ROLE_LETTERS = { TANK = "T", HEALER = "H", DAMAGER = "D" }
local ROLE_TOKENS = { TANK = "frost", HEALER = "life", DAMAGER = "void" }
E.ROLE_LETTERS = ROLE_LETTERS
local READY = { ready = "Interface\\RaidFrame\\ReadyCheck-Ready", notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting" }
E.READY = READY

-- Dispel type -> colour (x = the engine's dispel type id), one Step curve.
E.DISPEL_COLORS = { [0] = { 0.8, 0.8, 0.8 }, [1] = { 0.2, 0.6, 1 }, [2] = { 0.64, 0.19, 0.79 }, [3] = { 0.6, 0.4, 0 },
  [4] = { 0, 0.6, 0.1 }, [9] = { 1, 0.45, 0.1 }, [11] = { 0.85, 0.1, 0.1 } }
local dispelCurve
function E.DispelCurve()
  if dispelCurve then return dispelCurve end
  dispelCurve = C_CurveUtil.CreateColorCurve()
  dispelCurve:SetType(Enum.LuaCurveType.Step)
  local ids = {}
  for id in pairs(E.DISPEL_COLORS) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local c = E.DISPEL_COLORS[id]
    dispelCurve:AddPoint(id, CreateColor(c[1], c[2], c[3], 1))
  end
  return dispelCurve
end

-- Crisp edge frame we own (its colour can change per aura without the theme
-- repainting it back).
local function edges(parent, px, level)
  local f = PUI:CreateFrame("Frame", nil, parent, nil, OWNER)
  f:SetAllPoints(parent)
  if level then f:SetFrameLevel(level) end
  f.edges = {}
  local function edge(p1, p2, w, h)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetPoint(p1); t:SetPoint(p2)
    if w then t:SetWidth(w) else t:SetHeight(h) end
    f.edges[#f.edges + 1] = t
  end
  edge("TOPLEFT", "TOPRIGHT", nil, px); edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, px)
  edge("TOPLEFT", "BOTTOMLEFT", px, nil); edge("TOPRIGHT", "BOTTOMRIGHT", px, nil)
  function f:SetColor(r, g, b, a) for i = 1, 4 do self.edges[i]:SetColorTexture(r, g, b, a or 1) end end
  f:Hide()
  return f
end
E.Edges = edges

function E.Build(o)
  local b = o.button
  local c = PUI:CreateFrame("Frame", nil, b, nil, OWNER)
  c:SetAllPoints(b)
  o.content = c
  o.bg = Theme:Backdrop(c, "surface.0")
  o.frameEdge = edges(c, 1)
  o.frameEdge:SetColor(0, 0, 0, 1)
  o.frameEdge:Show()
  o.health = Bars:Create(c, OWNER)
  o.health:SetClipsChildren(true)
  o.pred = PUI.Prediction:Create(OWNER, o.health)
  o.tint = o.health:CreateTexture(nil, "ARTWORK", nil, 7)
  o.tint:SetAllPoints(o.health)
  o.tint:SetColorTexture(1, 1, 1, 1)
  o.tint:Hide()
  o.power = Bars:Create(c, OWNER)
  local layer = PUI:CreateFrame("Frame", nil, c, nil, OWNER)
  layer:SetAllPoints(c)
  layer:SetFrameLevel(o.health:GetFrameLevel() + 4)
  o.layer = layer
  o.name = fontString(layer, "CENTER", "label")
  o.status = fontString(layer, "CENTER")
  o.role = icon(layer, 12, "TOPLEFT", 2, -2, "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  o.roleText = fontString(layer, "LEFT")
  o.roleText:SetPoint("TOPLEFT", layer, "TOPLEFT", 3, -2)
  o.roleText:Hide()
  o.leader = icon(layer, 10, "TOPLEFT", 14, 4, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
  o.marker = icon(layer, 14, "TOPRIGHT", -2, -2, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  o.center = icon(layer, 18, "CENTER", 0, 0) -- ready check / resurrection / summon / phase
  o.aggro = edges(c, 2, layer:GetFrameLevel() + 1)
  o.aggro:SetColor(Theme:Color("danger"))
  o.dispel = edges(layer, 2, layer:GetFrameLevel() + 2)
  o.highlight = c:CreateTexture(nil, "HIGHLIGHT")
  o.highlight:SetAllPoints(c)
  o.highlight:SetColorTexture(1, 1, 1, 0.08)
  o.dots = {}
  for i = 1, 5 do
    local d = layer:CreateTexture(nil, "OVERLAY", nil, 6)
    local col = PUI.Targeting.COLORS[i]
    d:SetColorTexture(col.r, col.g, col.b, 1)
    d:Hide()
    o.dots[i] = d
  end
  o.privateAnchors = {}
  o.corners = {}
end

-- Size-dependent placement. The secure button is sized by the header (out of
-- combat); the content children are unprotected and follow it.
function E.Layout(o, s, width, height)
  width, height = width or o.width or 90, height or o.height or 44
  o.width, o.height = width, height
  local power = o.showPower and s.manaHeight or 0
  o.health:ClearAllPoints()
  o.health:SetPoint("TOPLEFT", o.content, "TOPLEFT", 1, -1)
  o.health:SetPoint("TOPRIGHT", o.content, "TOPRIGHT", -1, -1)
  o.health:SetHeight(math.max(1, height - 2 - (power > 0 and power + 1 or 0)))
  o.pred:Layout(width - 2, false)
  o.power:ClearAllPoints()
  o.power:SetPoint("TOPLEFT", o.health, "BOTTOMLEFT", 0, -1)
  o.power:SetPoint("TOPRIGHT", o.health, "BOTTOMRIGHT", 0, -1)
  o.power:SetHeight(math.max(1, power))
  o.power:SetShown(power > 0)
  o.name:ClearAllPoints()
  local pos = s.namePosition or "center"
  if pos == "top" then o.name:SetPoint("TOP", o.health, "TOP", 0, -3)
  elseif pos == "left" then o.name:SetPoint("LEFT", o.health, "LEFT", 4, 0)
  else o.name:SetPoint("CENTER", o.health, "CENTER", 0, 4) end
  o.name:SetJustifyH(pos == "left" and "LEFT" or "CENTER")
  o.name:SetWidth(math.max(10, width - 10))
  o.status:ClearAllPoints()
  o.status:SetPoint("TOP", o.name, "BOTTOM", 0, -1)
  local dot = math.max(3, s.dotSize or 6)
  for i, d in ipairs(o.dots) do
    d:SetSize(dot, dot)
    d:ClearAllPoints()
    d:SetPoint("TOP", o.content, "TOP", (i - 3) * (dot + 2), -2)
  end
end

function E.UpdateColor(o, s)
  local unit, bar = o.unit, o.health
  if s.colorMode == "class" and Bars.ClassColor(bar, unit) then return end
  if s.colorMode == "gradient" then
    local color = UnitHealthPercent(unit, true, Bars:HealthCurve())
    return bar:SetStatusBarColor(color:GetRGB())
  end
  if s.colorMode == "custom" and s.healthColor then
    local c = s.healthColor
    return bar:SetStatusBarColor(c.r, c.g, c.b, 1)
  end
  Bars.TokenColor(bar, "accent")
end

function E.UpdatePrediction(o, s)
  o.pred:Update(o.unit, { heals = s.heals, absorbs = s.absorbs, healAbsorbs = s.healAbsorbs, overflow = s.overflow })
end

function E.UpdateHealth(o, s)
  local unit = o.unit
  Bars:SetValues(o.health, UnitHealthMax(unit), UnitHealth(unit), false)
  if s.colorMode == "gradient" then E.UpdateColor(o, s) end
  E.UpdateStatus(o, s)
  E.UpdatePrediction(o, s)
end

-- Dead / offline text, else the health text setting.
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
  elseif s.healthText == "current" then
    o.status:SetText(AbbreviateNumbers(UnitHealth(unit)))
  else
    o.status:SetText("")
  end
end

function E.UpdateName(o, s)
  o.name:SetText(UnitName(o.unit))
  local color
  if s and s.nameColor == "class" then
    local _, token = UnitClass(o.unit)
    if token ~= nil then color = C_ClassColor.GetClassColor(token) end
  end
  if color then o.name:SetTextColor(color:GetRGB()) else o.name:SetTextColor(1, 1, 1) end
end

function E.UpdatePower(o, s)
  if not o.showPower then return end
  local unit = o.unit
  Bars:SetValues(o.power, UnitPowerMax(unit), UnitPower(unit), false)
end

-- Role icon / letter and the healer mana bar (healers only).
function E.UpdateRole(o, s)
  local role = UnitGroupRolesAssigned(o.unit)
  local known = plain(role) and ROLE_COORDS[role] and role or nil
  local show = s.roleStyle ~= "none" and known ~= nil
  if show and s.roleHideDamager and known == "DAMAGER" then show = false end
  if show and s.roleHideCombat and ns.RF and ns.RF.inCombat then show = false end
  o.role:Hide(); o.roleText:Hide()
  if show and s.roleStyle == "letter" then
    o.roleText:SetText(ROLE_LETTERS[known])
    Theme:Paint(o.roleText, ROLE_TOKENS[known], 1, "text")
    o.roleText:Show()
  elseif show then
    local c = ROLE_COORDS[known]
    o.role:SetTexCoord(c[1], c[2], c[3], c[4])
    o.role:Show()
  end
  local healer = s.healerMana and known == "HEALER" or false
  if healer ~= o.showPower then
    o.showPower = healer
    E.Layout(o, s)
  end
  if healer then Bars.PowerColor(o.power, o.unit); E.UpdatePower(o, s) end
end

-- Range alpha from PUI.Range (inRange may be secret: straight to the widget).
function E.ApplyRange(o, s, inRange, checked)
  if not s.rangeFade or o.unit == "player" then o.content:SetAlpha(1) return end
  if plain(checked) and checked == false then o.content:SetAlpha(1) return end
  o.content:SetAlphaFromBoolean(inRange, 1, s.rangeAlpha)
end

function E.UpdateThreat(o, s)
  if not s.aggro then o.aggro:Hide() return end
  local status = UnitThreatSituation(o.unit)
  o.aggro:SetShown(type(status) ~= "nil" and plain(status) and status >= 2 or false)
end

-- Dispel highlight. Source "mine" = debuffs you can dispel, "all" = any
-- dispellable debuff. Style: border, glow, tint or border + tint; colour by
-- debuff type (engine curve) or one fixed colour.
local FILTERS = { mine = "HARMFUL|RAID_PLAYER_DISPELLABLE", all = "DISPELLABLE|HARMFUL" }
E.DISPEL_FILTERS = FILTERS
local function paintDispel(o, s, on, r, g, b)
  local style = s.dispelStyle or "border"
  if on and (style == "border" or style == "both") then o.dispel:SetColor(r, g, b, 1); o.dispel:Show() else o.dispel:Hide() end
  if on and (style == "tint" or style == "both") then
    o.tint:SetVertexColor(r, g, b, 1); o.tint:SetAlpha(s.dispelTintAlpha or 0.35); o.tint:Show()
  else
    o.tint:Hide()
  end
  if on and style == "glow" then PUI.Glow:Start(o.content, "pulse", { r = r, g = g, b = b, a = 1 }) else PUI.Glow:Stop(o.content) end
  o.dispelShown = on
end
function E.UpdateDispel(o, s)
  local aura = s.dispel and C_UnitAuras.GetAuraDataByIndex(o.unit, 1, FILTERS[s.dispelSource] or FILTERS.mine) or nil
  local on = type(aura) ~= "nil"
  local r, g, b
  if on and s.dispelTypeColors then
    local color = C_UnitAuras.GetAuraDispelTypeColor(o.unit, aura.auraInstanceID, E.DispelCurve())
    if color then r, g, b = color:GetRGB() end
  end
  if on and r == nil then
    local c = s.dispelColor or { r = 0.96, g = 0.77, b = 0.42 }
    r, g, b = c.r, c.g, c.b
  end
  paintDispel(o, s, on, r, g, b)
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

function E.UpdateAll(o, s)
  E.Layout(o, s)
  E.UpdateRole(o, s)
  E.UpdateColor(o, s)
  E.UpdateHealth(o, s)
  E.UpdateName(o, s)
  E.UpdateThreat(o, s)
  E.UpdateDispel(o, s)
  E.UpdateIndicators(o, s)
  if ns.Indicators then ns.Indicators.UpdateCorners(o, s) end
end

------------------------------------------------------------------------------
-- Test mode and preview painting: fixed sample values, no unit reads.
-- { name, class, role, health, states }
E.SAMPLE = {
  { "Tankadin", "PALADIN", "TANK", 0.82, { aggro = true, leader = true } },
  { "Abdulrahman", "PRIEST", "HEALER", 0.96, { dispel = 1, absorb = 0.18 } },
  { "Kaelith", "MAGE", "DAMAGER", 0.64, { range = true } },
  { "Morv", "ROGUE", "DAMAGER", 0.38, { dispel = 4, healAbsorb = 0.2, dots = 2 } },
  { "Rexx", "HUNTER", "DAMAGER", 0, { dead = true } },
  { "Vex", "DEMONHUNTER", "TANK", 0.71, { dots = 1 } },
  { "Tor", "DRUID", "HEALER", 0.88, { heal = 0.1 } },
  { "Nyx", "WARLOCK", "DAMAGER", 0.55, { dispel = 2 } },
  { "Ash", "SHAMAN", "HEALER", 0.92, { ready = "ready" } },
  { "Sela", "MONK", "DAMAGER", 1, { ready = "waiting" } },
  { "Dain", "WARRIOR", "DAMAGER", 0.47, { summon = true } },
  { "Gale", "EVOKER", "HEALER", 0, { offline = true } },
}
local CLASS_RGB = { PALADIN = { 0.96, 0.55, 0.73 }, PRIEST = { 1, 1, 1 }, MAGE = { 0.25, 0.78, 0.92 }, ROGUE = { 1, 0.96, 0.41 },
  HUNTER = { 0.67, 0.83, 0.45 }, DEMONHUNTER = { 0.64, 0.19, 0.79 }, DRUID = { 1, 0.49, 0.04 }, WARLOCK = { 0.53, 0.53, 0.93 },
  SHAMAN = { 0, 0.44, 0.87 }, MONK = { 0, 1, 0.6 }, WARRIOR = { 0.78, 0.61, 0.43 }, EVOKER = { 0.2, 0.58, 0.5 },
  DEATHKNIGHT = { 0.77, 0.12, 0.23 } }
E.CLASS_RGB = CLASS_RGB

function E.PaintSample(o, s, i)
  local d = E.SAMPLE[((i - 1) % #E.SAMPLE) + 1]
  local name, class, role, hp, st = d[1], d[2], d[3], d[4], d[5]
  o.showPower = s.healerMana and role == "HEALER" or false
  E.Layout(o, s)
  o.health:SetMinMaxValues(0, 1)
  o.health:SetValue(hp)
  local c = CLASS_RGB[class]
  if s.colorMode == "gradient" then o.health:SetStatusBarColor(1 - hp, 0.2 + 0.7 * hp, 0.2, 1)
  elseif s.colorMode == "custom" and s.healthColor then o.health:SetStatusBarColor(s.healthColor.r, s.healthColor.g, s.healthColor.b, 1)
  elseif s.colorMode == "accent" then Bars.TokenColor(o.health, "accent")
  else o.health:SetStatusBarColor(c[1], c[2], c[3], 1) end
  o.name:SetText(name)
  if s.nameColor == "class" then o.name:SetTextColor(c[1], c[2], c[3]) else o.name:SetTextColor(1, 1, 1) end
  if st.dead then o.status:SetText("Dead")
  elseif st.offline then o.status:SetText("Offline")
  elseif s.healthText == "percent" then o.status:SetFormattedText("%d%%", hp * 100)
  elseif s.healthText == "deficit" then o.status:SetText(hp < 1 and string.format("-%dk", (1 - hp) * 300) or "")
  elseif s.healthText == "current" then o.status:SetFormattedText("%dk", hp * 300)
  else o.status:SetText("") end
  if o.showPower then o.power:SetMinMaxValues(0, 1); o.power:SetValue(0.7); o.power:SetStatusBarColor(0, 0.44, 0.87, 1) end
  o.pred:Sample(s.heals and st.heal or 0, s.absorbs and st.absorb or 0, s.healAbsorbs and st.healAbsorb or 0,
    false, s.overflow and st.healAbsorb ~= nil and hp < 0.4)
  o.role:Hide(); o.roleText:Hide()
  if s.roleStyle ~= "none" and not (s.roleHideDamager and role == "DAMAGER") then
    if s.roleStyle == "letter" then o.roleText:SetText(ROLE_LETTERS[role]); o.roleText:Show()
    else local rc = ROLE_COORDS[role]; o.role:SetTexCoord(rc[1], rc[2], rc[3], rc[4]); o.role:Show() end
  end
  o.leader:SetShown(s.leader and st.leader == true)
  o.marker:Hide()
  o.aggro:SetShown(s.aggro and st.aggro == true)
  local dispel = s.dispel and st.dispel or nil
  local rgb = dispel and (s.dispelTypeColors and E.DISPEL_COLORS[dispel] or { s.dispelColor.r, s.dispelColor.g, s.dispelColor.b })
  paintDispel(o, s, dispel ~= nil, rgb and rgb[1], rgb and rgb[2], rgb and rgb[3])
  local tex = s.statusIcons and ((st.ready and READY[st.ready]) or (st.summon and "Interface\\RaidFrame\\Raid-Icon-SummonPending")) or nil
  if tex then o.center:SetTexture(tex); o.center:Show() else o.center:Hide() end
  for k, dt in ipairs(o.dots) do dt:SetShown(s.targetDots and st.dots ~= nil and k <= st.dots); dt:SetAlpha(1) end
  o.content:SetAlpha((s.rangeFade and st.range) and s.rangeAlpha or 1)
end
