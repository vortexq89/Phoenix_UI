local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Class resources for the player (PUI_V2 5.8): pips for point resources,
-- rune pips with engine-driven recharge, and the Brewmaster stagger bar.
-- Each pip is a StatusBar spanning [i-1, i] that receives the whole resource
-- value, so the engine clamps the fill and Lua never compares the (possibly
-- secret) amount. Which resource shows is decided by the class and by
-- UnitPowerMax > 0 for that power type, which also follows spec and form.
local _, ns = ...
local Bars, Secret = PUI.Bars, PUI.Secret
local OWNER = "ResourceBars"

local CR = { pips = {}, shown = 0 }
ns.ClassResource = CR

local P = Enum.PowerType
-- class -> candidate point resources (first with a positive max wins).
local CANDIDATES = {
  ROGUE = { P.ComboPoints }, DRUID = { P.ComboPoints }, PALADIN = { P.HolyPower }, MONK = { P.Chi },
  WARLOCK = { P.SoulShards }, MAGE = { P.ArcaneCharges }, EVOKER = { P.Essence },
}
CR.CANDIDATES = CANDIDATES
local SHARD_SCALE = 10 -- soul shards report tenths with unmodified=true (Destruction fragments)

local function classToken()
  local _, token = UnitClass("player")
  return token
end

-- What the player shows now: "points", "runes", "stagger" or nil; plus power type.
function CR.Resolve()
  local class = classToken()
  if class == "DEATHKNIGHT" then return "runes" end
  if class == "MONK" and C_SpecializationInfo.GetSpecialization() == 1 then return "stagger" end
  local list = CANDIDATES[class]
  if not list then return nil end
  for i = 1, #list do
    local max = UnitPowerMax("player", list[i])
    if not Secret.IsSecret(max) and max > 0 then
      if class == "DRUID" then
        local _, token = UnitPowerType("player")
        if token ~= "ENERGY" then return nil end
      end
      return "points", list[i], max
    end
  end
  return nil
end

local function pip(container, i)
  local p = CR.pips[i]
  if p then return p end
  p = Bars:Create(container, OWNER)
  Bars.TokenColor(p, "accent")
  CR.pips[i] = p
  return p
end

-- Lays out n pips across the container width with a 2 px gap.
local function layoutPips(container, n, width, height)
  local gap = 2
  local w = (width - gap * (n - 1)) / n
  for i = 1, n do
    local p = pip(container, i)
    p:ClearAllPoints()
    p:SetSize(w, height)
    p:SetPoint("LEFT", container, "LEFT", (i - 1) * (w + gap), 0)
    p:Show()
  end
  for i = n + 1, #CR.pips do CR.pips[i]:Hide() end
  CR.shown = n
end

function CR.Configure(container, width, height)
  local kind, powerType, max = CR.Resolve()
  CR.kind, CR.powerType = kind, powerType
  if CR.stagger then CR.stagger:Hide() end
  if kind == "points" then
    layoutPips(container, max, width, height)
    local scale = powerType == P.SoulShards and SHARD_SCALE or 1
    for i = 1, max do CR.pips[i]:SetMinMaxValues((i - 1) * scale, i * scale) end
    CR.scale = scale
  elseif kind == "runes" then
    layoutPips(container, 6, width, height)
    for i = 1, 6 do CR.pips[i]:SetMinMaxValues(0, 1) end
    CR.durations = CR.durations or {}
  elseif kind == "stagger" then
    layoutPips(container, 0, width, height)
    if not CR.stagger then
      CR.stagger = Bars:Create(container, OWNER)
      CR.stagger:SetAllPoints(container)
      Bars.TokenColor(CR.stagger, "spark")
    end
    CR.stagger:Show()
  else
    layoutPips(container, 0, width, height)
  end
  return kind ~= nil
end

local function updatePoints()
  local unmodified = CR.scale ~= 1
  local value = UnitPower("player", CR.powerType, unmodified)
  for i = 1, CR.shown do CR.pips[i]:SetValue(value) end
end

local function updateRunes()
  local direction = Enum.StatusBarTimerDirection.ElapsedTime
  for i = 1, 6 do
    local p = CR.pips[i]
    local start, duration, ready = GetRuneCooldown(i)
    if Secret.IsSecret(ready) or Secret.IsSecret(start) then
      p:SetValue(1)
      p:SetAlphaFromBoolean(ready, 1, 0.35)
    elseif ready or not start then
      p:SetAlpha(1)
      p:SetMinMaxValues(0, 1)
      p:SetValue(ready and 1 or 0)
    else
      p:SetAlpha(0.6)
      local d = CR.durations[i] or C_DurationUtil.CreateDuration()
      CR.durations[i] = d
      d:SetTimeFromStart(start, duration)
      p:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, direction)
    end
  end
end

local function updateStagger()
  local bar = CR.stagger
  Bars:SetValues(bar, UnitHealthMax("player"), UnitStagger("player"))
end

function CR.Update()
  if CR.kind == "points" then updatePoints()
  elseif CR.kind == "runes" then updateRunes()
  elseif CR.kind == "stagger" then updateStagger() end
end
