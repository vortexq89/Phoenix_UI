local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Arena frames (mockup 04): one paint function over data presets, so every
-- look, the test mode and the live preview draw the same way.
-- Each frame: secure unit button (click targets, built and moved out of combat
-- only), spec icon, health and power bars (secret values passed straight to
-- the bars), name, health text through the engine formatter, the shared Core
-- cast bar (with your kick state), trinket and racial cooldowns, the DR tray
-- (right of the trinket by default, movable), party targeting dots
-- (PUI.Targeting) and borders for your target and focus.
local _, ns = ...
local Secret, CQ = PUI.Secret, PUI.CombatQueue
local ST, DR = ns.State, ns.DR
local FR = { frames = {} }
ns.Frames = FR
local OWNER = "Arena"

-- Presets are data only; every value is also its own setting (advanced view).
FR.PRESETS = {
  phoenix = { width = 220, height = 46, power = 6, spacing = 22, icon = "LEFT", trinket = 34 },
  compact = { width = 170, height = 34, power = 4, spacing = 12, icon = "LEFT", trinket = 28 },
  gladiator = { width = 240, height = 52, power = 8, spacing = 26, icon = "RIGHT", trinket = 38 },
}
FR.PRESET_LABELS = { phoenix = "Phoenix", compact = "Compact", gladiator = "Gladiator style" }
FR.DOT_COLORS = { { 0.35, 0.71, 1 }, { 0.24, 0.86, 0.59 }, { 1, 0.76, 0.29 }, { 0.69, 0.49, 1 }, { 1, 0.33, 0.41 } }
FR.PARTY = { "player", "party1", "party2", "party3", "party4" }

local function cd(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edge = b:CreateTexture(nil, "BORDER"); b.edge:SetPoint("TOPLEFT", -1, 1); b.edge:SetPoint("BOTTOMRIGHT", 1, -1); b.edge:SetColorTexture(0, 0, 0, 1)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); b.cd:SetAllPoints()
  return b
end

function FR.Build(i, parent)
  if FR.frames[i] then return FR.frames[i] end
  local unit = ST.UNITS[i]
  local f = CreateFrame("Button", "PhoenixUIArena" .. i, parent, "SecureUnitButtonTemplate")
  f.unit, f.index = unit, i
  f:SetAttribute("unit", unit)
  f:SetAttribute("type1", "target"); f:SetAttribute("type2", "focus")
  f:RegisterForClicks("AnyUp")
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.04, 0.05, 0.06, 0.9)
  f.border = f:CreateTexture(nil, "BORDER"); f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
  f.health = CreateFrame("StatusBar", nil, f)
  f.healthBg = f.health:CreateTexture(nil, "BACKGROUND"); f.healthBg:SetAllPoints()
  f.power = CreateFrame("StatusBar", nil, f)
  f.spec = f:CreateTexture(nil, "ARTWORK"); f.spec:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.name = f.health:CreateFontString(nil, "OVERLAY"); f.name:SetPoint("LEFT", f.health, "LEFT", 6, 0)
  f.hp = f.health:CreateFontString(nil, "OVERLAY"); f.hp:SetPoint("RIGHT", f.health, "RIGHT", -6, 0)
  f.number = f:CreateFontString(nil, "OVERLAY")
  f.status = f.health:CreateFontString(nil, "OVERLAY"); f.status:SetPoint("CENTER", f.health, "CENTER", 0, 0)
  f.stealth = f.health:CreateTexture(nil, "OVERLAY"); f.stealth:SetAllPoints(); f.stealth:SetColorTexture(0.4, 0.35, 0.6, 0.35)
  f.trinket, f.racial = cd(f), cd(f)
  f.tray = DR.BuildTray(f)
  f.phxCast = false
  f.dots = {}
  for d = 1, 5 do
    local t = f:CreateTexture(nil, "OVERLAY"); t:SetSize(7, 7)
    t:SetColorTexture(FR.DOT_COLORS[d][1], FR.DOT_COLORS[d][2], FR.DOT_COLORS[d][3], 1)
    f.dots[d] = t
  end
  f.targetBorder = f:CreateTexture(nil, "OVERLAY"); f.targetBorder:SetPoint("TOPLEFT", -2, 2); f.targetBorder:SetPoint("BOTTOMRIGHT", 2, -2)
  f.targetBorder:SetColorTexture(1, 0.82, 0.2, 0.0)
  f.focusMark = f:CreateTexture(nil, "OVERLAY"); f.focusMark:SetSize(10, 10); f.focusMark:SetColorTexture(0.69, 0.49, 1, 1)
  FR.frames[i] = f
  return f
end

-- Layout(f, s): geometry from settings (mirrored flips sides).
function FR.Layout(f, s, holder)
  local i = f.index
  local mirror = s.mirrored
  local iconSide = s.iconSide
  if mirror then iconSide = iconSide == "LEFT" and "RIGHT" or "LEFT" end
  f:SetSize(s.width, s.height)
  f:ClearAllPoints()
  local step = (s.height + s.spacing) * (s.grow == "UP" and 1 or -1)
  f:SetPoint(s.grow == "UP" and "BOTTOM" or "TOP", holder, s.grow == "UP" and "BOTTOM" or "TOP", 0, (i - 1) * step)
  local ph = s.showPower and s.powerHeight or 0
  f.spec:SetShown(s.specIcon)
  f.spec:SetSize(s.height, s.height)
  f.spec:ClearAllPoints()
  local inset = 0 -- the spec icon sits outside the frame edge so the bars keep full width
  if iconSide == "RIGHT" then f.spec:SetPoint("LEFT", f, "RIGHT", 2, 0) else f.spec:SetPoint("RIGHT", f, "LEFT", -2, 0) end
  f.health:ClearAllPoints()
  f.health:SetPoint("TOPLEFT", f, "TOPLEFT", inset, 0)
  f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, ph > 0 and (ph + 1) or 0)
  f.power:SetShown(s.showPower)
  f.power:ClearAllPoints()
  f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, 0); f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  f.power:SetHeight(math.max(1, ph))
  local tex = PUI.Bars and PUI.Bars:TexturePath() or "Interface\\Buttons\\WHITE8X8"
  f.health:SetStatusBarTexture(tex); f.power:SetStatusBarTexture(tex); f.healthBg:SetTexture(tex)
  -- trinket then racial on the outer side; the tray right of the trinket by default
  local side = mirror and "LEFT" or "RIGHT"
  local sz = s.trinketSize
  for _, b in ipairs({ f.trinket, f.racial }) do b:SetSize(sz, sz); b:ClearAllPoints() end
  local gap = s.specIcon and iconSide == side and (s.height + 4) or 2
  if side == "RIGHT" then
    f.trinket:SetPoint("LEFT", f, "RIGHT", gap, 0)
    f.racial:SetPoint("LEFT", f.trinket, "RIGHT", 2, 0)
  else
    f.trinket:SetPoint("RIGHT", f, "LEFT", -gap, 0)
    f.racial:SetPoint("RIGHT", f.trinket, "LEFT", -2, 0)
  end
  f.trinket:SetShown(s.trinket)
  f.racial:SetShown(s.racial)
  FR.PlaceTray(f, s)
  for d, t in ipairs(f.dots) do
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", (d - 1) * 9, 2)
  end
  f.focusMark:ClearAllPoints(); f.focusMark:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 8)
  f.number:ClearAllPoints(); f.number:SetPoint(side == "RIGHT" and "RIGHT" or "LEFT", f, side == "RIGHT" and "LEFT" or "RIGHT", side == "RIGHT" and -4 - (s.specIcon and iconSide ~= side and s.height or 0) or 4, 0)
  f.number:SetShown(s.arenaNumber)
  local font = PUI.Media:FontObject(s.font)
  f.name:SetFontObject(font); f.hp:SetFontObject(font); f.status:SetFontObject(font); f.number:SetFontObject(PUI.Media:FontObject("small"))
  f.number:SetText(tostring(i))
  if f.phxCast then f.phxCast:ApplyStyle({ width = s.width, height = s.castHeight }); f.phxCast.frame:SetShown(s.castBar) end
end

-- The tray anchors to the trinket (default), the racial, or the frame; x/y move it.
FR.TRAY_ANCHORS = { "trinket", "racial", "frame" }
function FR.PlaceTray(f, s)
  local tray = f.tray
  tray:ClearAllPoints()
  local anchor = (s.drAnchor == "racial" and s.racial and f.racial) or (s.drAnchor == "frame" and f) or (s.trinket and f.trinket) or f
  local right = not s.mirrored
  if s.drGrow == "LEFT" then right = false elseif s.drGrow == "RIGHT" then right = true end
  if right then tray:SetPoint("LEFT", anchor, "RIGHT", 4 + s.drX, s.drY) else tray:SetPoint("RIGHT", anchor, "LEFT", -4 + s.drX, s.drY) end
  tray:SetShown(s.drTray)
end

-- Paint(f, s): unit data. Secret health/power/name go straight to widgets.
function FR.PaintUnit(f, s)
  local unit = f.unit
  local u = ST.Unit(unit)
  local exists = UnitExists(unit)
  f.status:SetText("")
  f.stealth:SetShown(false)
  f:SetAlpha(1)
  if u.life == "prep" or (not exists and u.life == "none") then
    f.name:SetText(u.specName or "")
    f.health:SetMinMaxValues(0, 1); f.health:SetValue(1)
    f.hp:SetText("")
  elseif exists then
    f.name:SetText(s.name and UnitName(unit) or "")
    f.health:SetMinMaxValues(0, UnitHealthMax(unit))
    f.health:SetValue(UnitHealth(unit))
    if s.healthText ~= "none" and UnitHealthPercent and CurveConstants then
      f.hp:SetFormattedText("%d%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    else f.hp:SetText("") end
    f.power:SetMinMaxValues(0, UnitPowerMax(unit))
    f.power:SetValue(UnitPower(unit))
    local _, class = UnitClass(unit)
    local c = class and not Secret.IsSecret(class) and s.classColors and C_ClassColor.GetClassColor(class)
    if c then f.health:SetStatusBarColor(c.r, c.g, c.b, 1); f.healthBg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2, 0.8)
    else f.health:SetStatusBarColor(0.3, 0.72, 0.36, 1); f.healthBg:SetVertexColor(0.06, 0.14, 0.07, 0.8) end
    local _, ptoken = UnitPowerType(unit)
    local pc = ptoken and not Secret.IsSecret(ptoken) and PowerBarColor[ptoken]
    if pc then f.power:SetStatusBarColor(pc.r, pc.g, pc.b, 1) else f.power:SetStatusBarColor(0.3, 0.5, 1, 1) end
    local _, race = UnitRace(unit)
    ST.SetRace(unit, race)
  elseif u.life == "unseen" then
    f.status:SetText(s.assumeRegen and "Stealthed - 100%*" or "Stealthed")
    f.stealth:SetShown(true)
    if s.assumeRegen then f.health:SetMinMaxValues(0, 1); f.health:SetValue(1) end
  elseif u.life == "left" then
    f.status:SetText("Left arena")
    f:SetAlpha(s.staleAlpha)
  end
  if u.spec then
    local _, specName, _, icon = GetSpecializationInfoForSpecID(u.spec)
    f.spec:SetTexture(icon)
    u.specName = specName
  end
  FR.PaintCooldowns(f, s)
  FR.PaintTray(f, s)
end

function FR.PaintCooldowns(f, s)
  local u = ST.Unit(f.unit)
  local now = GetTime()
  local spellID, start, duration
  if UnitExists(f.unit) then spellID, start, duration = C_PvP.GetArenaCrowdControlInfo(f.unit) end
  if spellID ~= nil then
    f.trinket.tex:SetTexture(C_Spell.GetSpellTexture(spellID))
    if start ~= nil then f.trinket.cd:SetCooldown(start, duration) end
  else
    local faction = s.trinketFaction and UnitFactionGroup(f.unit)
    local horde = faction ~= nil and not Secret.IsSecret(faction) and faction == "Horde"
    f.trinket.tex:SetTexture(horde and 1322720 or 1322721)
  end
  if u.racialSpell then f.racial.tex:SetTexture(C_Spell.GetSpellTexture(u.racialSpell))
  elseif u.race and ST.RACE_ICON[u.race] then f.racial.tex:SetTexture(ST.RACE_ICON[u.race]) end
  local left = ST.Remaining(u.racial, now)
  if left > 0 then f.racial.cd:SetCooldown(u.racial.ends - (u.racialInfo and u.racialInfo.cd or left), u.racialInfo and u.racialInfo.cd or left)
  else f.racial.cd:Clear() end
  f.racial.tex:SetDesaturated(left > 0 and s.desaturate)
end

function FR.TrayStyle(s)
  return { size = s.drSize, spacing = s.drSpacing, grow = s.drGrow == "AUTO" and (s.mirrored and "LEFT" or "RIGHT") or s.drGrow,
    text = s.drText, colorBorder = s.drColorBorder, stageText = s.drStage }
end
function FR.PaintTray(f, s)
  if not s.drTray then return 0 end
  return DR.Paint(f.tray, ST.Unit(f.unit).dr, FR.TrayStyle(s))
end

-- Targeting dots: dot d shows when party member d targets this enemy; your
-- own target and focus get a border. UnitIsUnit may be secret -> alpha only.
function FR.PaintTargets(f, s)
  for d, t in ipairs(f.dots) do
    local friend = FR.PARTY[d]
    if s.targetDots and UnitExists(friend) and UnitExists(f.unit) then
      t:Show(); t:SetAlphaFromBoolean(UnitIsUnit(friend .. "target", f.unit), 1, 0)
    else t:Hide() end
  end
  if UnitExists(f.unit) then
    f.targetBorder:SetColorTexture(1, 0.82, 0.2, 1)
    f.targetBorder:SetAlphaFromBoolean(UnitIsUnit("target", f.unit), s.targetBorder and 0.9 or 0, 0)
    f.focusMark:SetAlphaFromBoolean(UnitIsUnit("focus", f.unit), s.focusMark and 1 or 0, 0)
  else
    f.targetBorder:SetAlpha(0); f.focusMark:SetAlpha(0)
  end
end

function FR.AttachCast(f, s)
  if f.phxCast then if s.castBar then f.phxCast:Enable() else f.phxCast:Disable() end return end
  if not s.castBar then return end
  f.phxCast = PUI.CastBar:Create(OWNER, f, f.unit, { width = s.width, height = s.castHeight, kick = true })
  f.phxCast.frame:ClearAllPoints()
  f.phxCast.frame:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
end

-- Cast bars stop listening outside arenas (no work while nothing is shown).
function FR.Sleep()
  for _, f in ipairs(FR.frames) do if f.phxCast then f.phxCast:Disable() end end
end

-- Secure geometry waits for the end of combat.
function FR.Apply(s, holder, count)
  if CQ.InCombat() then CQ.Defer("arena.layout", function() FR.Apply(s, holder, count) end); return false end
  for i = 1, 5 do
    local f = FR.Build(i, holder)
    FR.Layout(f, s, holder)
    if i <= count then FR.AttachCast(f, s) end
  end
  return true
end
