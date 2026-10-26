local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Prediction (plan 5.2 study "one shared heal-prediction/absorb renderer";
-- 1.O): incoming heals, damage absorbs and heal absorbs drawn on a health bar,
-- plus the two overflow marks Blizzard's calculator reports:
--   over-absorb    shield larger than the missing health (mark at the far edge)
--   heal-absorb overflow  heal absorb larger than current health (mark at the
--                  near edge, so a "dead on next hit" member stands out)
-- Unit frames, party/raid frames and arena frames create one renderer per
-- health bar. Values come from UnitGetDetailedHealPrediction and may be
-- secret: amounts go to StatusBar setters and the "clamped" flags go to
-- SetAlphaFromBoolean; nothing here compares them.
--   r = Prediction:Create(owner, healthBar)
--   r:Layout(width, reverse)          after size / fill direction changes
--   r:Update(unit, opts)              opts = { heals, absorbs, healAbsorbs, overflow }
--   r:Colors(colors)                  { heals = {r,g,b,a}, absorbs = ..., healAbsorbs = ..., over = ... }
local Bars = PUI.Bars
local Prediction = { DEFAULT_COLORS = {
  heals = { r = 0.35, g = 0.95, b = 0.55, a = 0.45 }, absorbs = { r = 0.85, g = 0.92, b = 1, a = 0.55 },
  healAbsorbs = { r = 0.9, g = 0.2, b = 0.3, a = 0.55 }, over = { r = 1, g = 1, b = 1, a = 0.9 },
  overHeal = { r = 1, g = 0.25, b = 0.3, a = 1 } } }
PUI.Prediction = Prediction

local R = {}
R.__index = R

local function segment(owner, health)
  local bar = Bars:Create(health, owner, "BACKGROUND")
  bar.bg:SetAlpha(0)
  bar:SetFrameLevel(health:GetFrameLevel() + 1)
  return bar
end

local function mark(health, owner)
  local holder = PUI:CreateFrame("Frame", nil, health, nil, owner)
  holder:SetAllPoints(health)
  holder:SetFrameLevel(health:GetFrameLevel() + 2)
  local t = holder:CreateTexture(nil, "OVERLAY")
  t:SetWidth(2)
  t:SetAlpha(0)
  return t
end

-- Configures the calculator so "clamped" means what the marks show.
local function configure(calc)
  local E = rawget(_G, "Enum")
  if not (E and calc) then return end
  if calc.SetDamageAbsorbClampMode and E.UnitDamageAbsorbClampMode then
    calc:SetDamageAbsorbClampMode(E.UnitDamageAbsorbClampMode.MissingHealth)
  end
  if calc.SetHealAbsorbClampMode and E.UnitHealAbsorbClampMode then
    calc:SetHealAbsorbClampMode(E.UnitHealAbsorbClampMode.CurrentHealth)
  end
  if calc.SetIncomingHealClampMode and E.UnitIncomingHealClampMode then
    calc:SetIncomingHealClampMode(E.UnitIncomingHealClampMode.MissingHealth)
  end
end

Prediction.Configure = configure

function Prediction:Create(owner, health)
  assert(type(owner) == "string" and health, "Prediction:Create(owner, healthBar)")
  local r = setmetatable({ owner = owner, health = health }, R)
  r.incoming = segment(owner, health)
  r.absorb = segment(owner, health)
  r.healAbsorb = segment(owner, health)
  r.over = mark(health, owner)
  r.overHeal = mark(health, owner)
  r.calc = CreateUnitHealPredictionCalculator()
  configure(r.calc)
  r:Colors()
  r:Layout(health:GetWidth(), false)
  return r
end

function R:Colors(colors)
  local c = colors or {}
  local d = Prediction.DEFAULT_COLORS
  local function paint(bar, col) Bars.Color(bar, col.r, col.g, col.b, col.a or 1) end
  paint(self.incoming, c.heals or d.heals)
  paint(self.absorb, c.absorbs or d.absorbs)
  paint(self.healAbsorb, c.healAbsorbs or d.healAbsorbs)
  local o, oh = c.over or d.over, c.overHeal or d.overHeal
  self.over:SetColorTexture(o.r, o.g, o.b, o.a or 1)
  self.overHeal:SetColorTexture(oh.r, oh.g, oh.b, oh.a or 1)
end

-- Segments start where the health fill ends (heals, shields) or sit inside its
-- end (heal absorbs), mirrored when the bar fills right to left.
function R:Layout(width, reverse)
  local h, fill = self.health, self.health:GetStatusBarTexture()
  local near, far = "LEFT", "RIGHT"
  if reverse then near, far = "RIGHT", "LEFT" end
  local function after(bar)
    bar:ClearAllPoints()
    bar:SetPoint("TOP", h, "TOP"); bar:SetPoint("BOTTOM", h, "BOTTOM")
    bar:SetPoint(near, fill, far)
    bar:SetReverseFill(reverse == true)
    bar:SetWidth(math.max(1, width or 1))
  end
  after(self.incoming)
  after(self.absorb)
  self.absorb:ClearAllPoints()
  self.absorb:SetPoint("TOP", h, "TOP"); self.absorb:SetPoint("BOTTOM", h, "BOTTOM")
  self.absorb:SetPoint(near, self.incoming:GetStatusBarTexture(), far)
  local ha = self.healAbsorb
  ha:ClearAllPoints()
  ha:SetPoint("TOP", h, "TOP"); ha:SetPoint("BOTTOM", h, "BOTTOM")
  ha:SetPoint(far, fill, far)
  ha:SetReverseFill(not reverse)
  ha:SetWidth(math.max(1, width or 1))
  self.over:ClearAllPoints()
  self.over:SetPoint("TOP" .. far, h, "TOP" .. far); self.over:SetPoint("BOTTOM" .. far, h, "BOTTOM" .. far)
  self.overHeal:ClearAllPoints()
  self.overHeal:SetPoint("TOP" .. near, h, "TOP" .. near); self.overHeal:SetPoint("BOTTOM" .. near, h, "BOTTOM" .. near)
  self.width, self.reverse = width, reverse
end

-- opts: heals, absorbs, healAbsorbs, overflow (booleans from settings).
function R:Update(unit, opts)
  opts = opts or {}
  self.incoming:SetShown(opts.heals == true)
  self.absorb:SetShown(opts.absorbs == true)
  self.healAbsorb:SetShown(opts.healAbsorbs == true)
  if not unit or not (opts.heals or opts.absorbs or opts.healAbsorbs) then
    self.over:SetAlpha(0); self.overHeal:SetAlpha(0)
    return
  end
  local calc = self.calc
  UnitGetDetailedHealPrediction(unit, "player", calc)
  local maxHealth = UnitHealthMax(unit)
  if opts.heals then Bars:SetValues(self.incoming, maxHealth, (calc:GetIncomingHeals())) end
  if opts.absorbs then
    local amount, clamped = calc:GetDamageAbsorbs()
    Bars:SetValues(self.absorb, maxHealth, amount)
    if opts.overflow then self.over:SetAlphaFromBoolean(clamped, 1, 0) else self.over:SetAlpha(0) end
  else
    self.over:SetAlpha(0)
  end
  if opts.healAbsorbs then
    local amount, clamped = calc:GetHealAbsorbs()
    Bars:SetValues(self.healAbsorb, maxHealth, amount)
    if opts.overflow then self.overHeal:SetAlphaFromBoolean(clamped, 1, 0) else self.overHeal:SetAlpha(0) end
  else
    self.overHeal:SetAlpha(0)
  end
end

-- Sample values for previews and test frames (fractions of max health).
function R:Sample(heals, absorbs, healAbsorbs, over, overHeal)
  for bar, v in pairs({ [self.incoming] = heals or 0, [self.absorb] = absorbs or 0, [self.healAbsorb] = healAbsorbs or 0 }) do
    bar:SetMinMaxValues(0, 1); bar:SetValue(v); bar:SetShown(v > 0)
  end
  self.over:SetAlpha(over and 1 or 0)
  self.overHeal:SetAlpha(overHeal and 1 or 0)
end
