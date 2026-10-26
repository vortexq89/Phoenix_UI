local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.CastBar (plan 1.O "Cast bars", "Own kick readiness"): one cast bar
-- element for Unit Frames, Resource Bars, Nameplates, Arena and the CDM focus
-- kick bar. Modules call CastBar:Create(); the 13-event dispatcher below is
-- shared and is registered only while at least one bar is active (G21, G30).
-- Timing is engine-driven (StatusBar:SetTimerDuration with the unit's duration
-- object), so a bar runs no Lua per frame (G2). Name, icon and the
-- "not interruptible" flag may be secret: they go straight to widgets (G1, G35).
local CastBar = { bars = {}, byUnit = {}, active = 0 }
PUI.CastBar = CastBar
local Theme = PUI.Theme

local EVENTS = {
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
  "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
CastBar.EVENTS = EVENTS
local START = { UNIT_SPELLCAST_START = "cast", UNIT_SPELLCAST_DELAYED = "cast", UNIT_SPELLCAST_CHANNEL_START = "channel",
  UNIT_SPELLCAST_CHANNEL_UPDATE = "channel", UNIT_SPELLCAST_EMPOWER_START = "empower", UNIT_SPELLCAST_EMPOWER_UPDATE = "empower" }
local STOP = { UNIT_SPELLCAST_STOP = "stop", UNIT_SPELLCAST_CHANNEL_STOP = "stop", UNIT_SPELLCAST_EMPOWER_STOP = "stop",
  UNIT_SPELLCAST_FAILED = "failed", UNIT_SPELLCAST_INTERRUPTED = "interrupted" }

CastBar.DEFAULT_STYLE = {
  width = 220, height = 18, icon = true, iconSide = "LEFT", spellName = true, timer = true, spark = true,
  shield = true, kick = true, texture = nil, fadeOut = 0.35,
  colors = { cast = { r = 1, g = 0.62, b = 0.18 }, channel = { r = 0.36, g = 0.7, b = 1 }, empower = { r = 0.69, g = 0.49, b = 1 },
    locked = { r = 0.55, g = 0.56, b = 0.6 }, failed = { r = 0.9, g = 0.31, b = 0.42 }, done = { r = 0.24, g = 0.86, b = 0.59 } },
}

local dispatcher = PUI:CreateFrame("Frame", nil, nil, nil, "Core")

local function setArmed(on)
  for i = 1, #EVENTS do
    if on then dispatcher:RegisterEvent(EVENTS[i]) else dispatcher:UnregisterEvent(EVENTS[i]) end
  end
  if on then dispatcher:RegisterEvent("SPELL_UPDATE_COOLDOWN") else dispatcher:UnregisterEvent("SPELL_UPDATE_COOLDOWN") end
  CastBar.armed = on
end

------------------------------------------------------------------------------
-- Own interrupt (one state for every surface). Spell IDs are class data.
local Kick = { spellID = nil, subs = {} }
CastBar.Kick = Kick
Kick.CLASS_SPELLS = {
  WARRIOR = { 6552 }, ROGUE = { 1766 }, PALADIN = { 96231 }, DEATHKNIGHT = { 47528 }, DEMONHUNTER = { 183752 },
  DRUID = { 106839, 78675 }, HUNTER = { 147362, 187707 }, MAGE = { 2139 }, MONK = { 116705 }, SHAMAN = { 57994 },
  PRIEST = { 15487 }, WARLOCK = { 119910, 19647 }, EVOKER = { 351338 },
}

function Kick:Refresh()
  local _, class = UnitClass("player")
  local list = self.CLASS_SPELLS[class] or {}
  local found
  for i = 1, #list do
    if C_SpellBook.IsSpellKnown(list[i]) then found = list[i]; break end
  end
  self.spellID = found
  return found
end

-- Duration object of the kick cooldown (secret-safe; hand it to a Cooldown widget).
function Kick:Duration()
  if not self.spellID then return nil end
  return C_Spell.GetSpellCooldownDuration(self.spellID)
end

local function paintKick(bar)
  local k = bar.kick
  if not k then return end
  local show = bar.style.kick and Kick.spellID ~= nil and bar.casting
  k:SetShown(show == true)
  if show then
    local d = Kick:Duration()
    if d and k.cd.SetCooldownFromDurationObject then k.cd:SetCooldownFromDurationObject(d) else k.cd:Clear() end
  end
end

------------------------------------------------------------------------------
local Bar = {}
Bar.__index = Bar

local function color(tex, c) tex:SetStatusBarColor(c.r, c.g, c.b, c.a or 1) end

local function build(bar, parent)
  local f = PUI:CreateFrame("Frame", nil, parent, nil, bar.owner)
  local status = CreateFrame("StatusBar", nil, f)
  status:SetAllPoints()
  status:SetStatusBarTexture(PUI.Media:Texture(bar.style.texture or "flat") or "Interface\\Buttons\\WHITE8X8")
  local bg = status:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  Theme:Paint(bg, "bg0", 0.8)
  local icon = f:CreateTexture(nil, "ARTWORK")
  local name = status:CreateFontString(nil, "OVERLAY")
  name:SetFontObject(PUI.Media:FontObject("body"))
  name:SetJustifyH("LEFT")
  name:SetPoint("LEFT", 6, 0)
  name:SetPoint("RIGHT", -46, 0)
  name:SetWordWrap(false)
  local timer = status:CreateFontString(nil, "OVERLAY")
  timer:SetFontObject(PUI.Media:FontObject("number"))
  timer:SetPoint("RIGHT", -6, 0)
  -- "Not interruptible" overlay: a frame, so a secret flag can drive its alpha.
  local shield = CreateFrame("Frame", nil, status)
  shield:SetAllPoints()
  local lockTex = shield:CreateTexture(nil, "OVERLAY")
  lockTex:SetAllPoints()
  lockTex:SetColorTexture(0.55, 0.56, 0.6, 0.55)
  shield:SetAlpha(0)
  -- Own-kick indicator: icon + engine cooldown swipe at the right edge.
  local kick = CreateFrame("Frame", nil, f)
  local kickIcon = kick:CreateTexture(nil, "ARTWORK")
  kickIcon:SetAllPoints()
  kick.cd = CreateFrame("Cooldown", nil, kick, "CooldownFrameTemplate")
  kick.cd:SetAllPoints()
  kick.icon = kickIcon
  kick:Hide()
  bar.frame, bar.status, bar.bg, bar.icon, bar.name, bar.timer, bar.shield, bar.kick = f, status, bg, icon, name, timer, shield, kick
  -- Fade-out after a cast ends: C-side alpha animation (G2).
  local ag = f:CreateAnimationGroup()
  local fade = ag:CreateAnimation("Alpha")
  fade:SetFromAlpha(1); fade:SetToAlpha(0)
  ag:SetScript("OnFinished", function() if not bar.casting then f:Hide(); f:SetAlpha(1) end end)
  bar.fadeGroup, bar.fade = ag, fade
  f:Hide()
end

function Bar:ApplyStyle(style)
  local s = self.style
  for k, v in pairs(style or {}) do s[k] = v end
  local f = self.frame
  f:SetSize(math.floor(s.width + 0.5), math.floor(s.height + 0.5)) -- whole pixels (G23)
  self.icon:ClearAllPoints()
  self.icon:SetSize(s.height, s.height)
  if s.iconSide == "RIGHT" then self.icon:SetPoint("LEFT", f, "RIGHT", 2, 0) else self.icon:SetPoint("RIGHT", f, "LEFT", -2, 0) end
  self.icon:SetShown(s.icon == true)
  self.name:SetShown(s.spellName == true)
  self.timer:SetShown(s.timer == true)
  self.kick:ClearAllPoints()
  self.kick:SetSize(s.height, s.height)
  self.kick:SetPoint("LEFT", f, "RIGHT", s.icon and s.iconSide == "RIGHT" and (s.height + 4) or 2, 0)
  self.fade:SetDuration(math.max(0.01, s.fadeOut or 0))
  self:Refresh()
end

-- Re-reads the unit's current cast (used on create, unit change and target swaps).
function Bar:Refresh()
  if not self.enabled then return end
  -- Duration objects are never secret, so presence is tested on them (G1).
  if UnitCastingDuration(self.unit) ~= nil then return self:Start("cast")
  elseif UnitChannelDuration(self.unit) ~= nil then return self:Start("channel") end
  self:Stop("stop", true)
end

function Bar:Start(kind)
  local unit, s = self.unit, self.style
  local _, name, texture, notInterruptible, duration
  if kind == "cast" then
    name, _, texture, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    duration = UnitCastingDuration(unit)
  else
    name, _, texture, _, _, _, notInterruptible = UnitChannelInfo(unit)
    duration = UnitChannelDuration(unit)
  end
  if duration == nil then return self:Stop("stop", true) end
  self.casting, self.kind = true, kind
  self.fadeGroup:Stop()
  self.frame:SetAlpha(1)
  color(self.status, s.colors[kind] or s.colors.cast)
  local dir = Enum.StatusBarTimerDirection and (kind == "channel" and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
  local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
  self.status:SetTimerDuration(duration, interp, dir)
  self.name:SetText(name) -- passed through untested: may be secret (G1)
  self.icon:SetTexture(texture)
  if s.shield then self.shield:SetAlphaFromBoolean(notInterruptible, 1, 0) else self.shield:SetAlpha(0) end
  if s.timer and self.timer.SetTimerDuration then self.timer:SetTimerDuration(duration) end
  self.frame:Show()
  paintKick(self)
end

function Bar:Stop(how, silent)
  local was = self.casting
  self.casting, self.kind = false, nil
  if self.kick then self.kick:Hide() end
  if not was or silent then self.frame:Hide(); return end
  local s = self.style
  if how == "failed" or how == "interrupted" then color(self.status, s.colors.failed)
  else color(self.status, s.colors.done) end
  if (s.fadeOut or 0) > 0 then self.fadeGroup:Play() else self.frame:Hide() end
end

local function index(bar, on)
  local set = CastBar.byUnit[bar.unit]
  if on then
    if not set then set = {}; CastBar.byUnit[bar.unit] = set end
    set[bar] = true
  elseif set then
    set[bar] = nil
    if next(set) == nil then CastBar.byUnit[bar.unit] = nil end
  end
end

function Bar:SetUnit(unit)
  if unit == self.unit then return self:Refresh() end
  if self.enabled then index(self, false) end
  self.unit = unit
  if self.enabled then index(self, true) end
  self:Refresh()
end

function Bar:Enable()
  if self.enabled then return end
  self.enabled = true
  index(self, true)
  CastBar.active = CastBar.active + 1
  if CastBar.active == 1 then setArmed(true); Kick:Refresh() end
  self:Refresh()
end

function Bar:Disable()
  if not self.enabled then return end
  self.enabled = false
  index(self, false)
  CastBar.active = CastBar.active - 1
  if CastBar.active == 0 then setArmed(false) end
  self:Stop("stop", true)
end

-- Release: back to a clean state for pooling (G37).
function Bar:Release()
  self:Disable()
  self.name:SetText("")
  self.icon:SetTexture(nil)
  self.status:SetMinMaxValues(0, 0)
  self.status:SetValue(0)
  self.shield:SetAlpha(0)
  self.frame:SetAlpha(1)
  CastBar.bars[self] = nil
end

-- Create(owner, parent, unit[, style]) -> bar (enabled).
function CastBar:Create(owner, parent, unit, style)
  assert(type(owner) == "string" and owner ~= "", "CastBar:Create needs an owner")
  assert(type(unit) == "string", "CastBar:Create needs a unit")
  local s = PUI.Schema.Copy(self.DEFAULT_STYLE)
  local bar = setmetatable({ owner = owner, unit = unit, style = s }, Bar)
  build(bar, parent or UIParent)
  self.bars[bar] = true
  bar:ApplyStyle(style)
  bar:Enable()
  return bar
end

dispatcher:SetScript("OnEvent", function(_, event, unit)
  if event == "SPELL_UPDATE_COOLDOWN" then
    for bar in pairs(CastBar.bars) do if bar.casting then paintKick(bar) end end
    return
  end
  local set = CastBar.byUnit[unit]
  if not set then return end
  for bar in pairs(set) do
    if START[event] then bar:Start(START[event])
    elseif STOP[event] then bar:Stop(STOP[event])
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then bar.shield:SetAlpha(0)
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" and bar.style.shield then bar.shield:SetAlpha(1) end
  end
end)

local kickFrame = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
kickFrame:RegisterEvent("SPELLS_CHANGED")
kickFrame:SetScript("OnEvent", function() if CastBar.active > 0 then Kick:Refresh() end end)
