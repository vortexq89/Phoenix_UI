local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Resource Bars module (PUI_V2 5.8): a movable stack of personal bars for the
-- player - health, power (with hash lines), class resource, cast, global
-- cooldown and totems. Each bar is opt-in per setting; events are registered
-- only for the bars that are on, and the module owns nothing while disabled.
local _, ns = ...
local Schema, Layout, CQ, Ticker, Bars, Theme, Media = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker, PUI.Bars, PUI.Theme, PUI.Media
local CR = ns.ClassResource
local OWNER = "ResourceBars"
local GCD_SPELL = 61304 -- the global cooldown spell

local RB = { active = false, bars = {}, ticks = {} }
ns.RB = RB
PUI.ResourceBars = RB

local ORDER = { "health", "power", "class", "cast", "gcd", "totem" }
RB.ORDER = ORDER
local DEFAULTS = {
  health = { on = false, h = 10 }, power = { on = true, h = 10 }, class = { on = true, h = 8 },
  cast = { on = false, h = 14 }, gcd = { on = false, h = 3 }, totem = { on = false, h = 14 },
}
local cfg = { width = 240, spacing = 2, ticks = {}, smooth = false, hideBlizzardCast = false }
RB.cfg = cfg
for k, d in pairs(DEFAULTS) do cfg[k] = { on = d.on, height = d.h } end

-- Frames -------------------------------------------------------------------------
local function container()
  if RB.frame then return RB.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_ResourceBars", UIParent, nil, OWNER)
  f:SetSize(cfg.width, 40)
  RB.frame = f
  local slots = {}
  for _, key in ipairs(ORDER) do
    local slot = PUI:CreateFrame("Frame", nil, f, nil, OWNER)
    slots[key] = slot
  end
  RB.slots = slots
  local health = Bars:Create(slots.health, OWNER); health:SetAllPoints(slots.health)
  local power = Bars:Create(slots.power, OWNER); power:SetAllPoints(slots.power)
  local cast = Bars:Create(slots.cast, OWNER); cast:SetAllPoints(slots.cast)
  cast.text = cast:CreateFontString(nil, "OVERLAY")
  cast.text:SetFontObject(Media:FontObject("small"))
  cast.text:SetPoint("LEFT", cast, "LEFT", 3, 0)
  Bars.TokenColor(cast, "accent")
  local gcd = Bars:Create(slots.gcd, OWNER); gcd:SetAllPoints(slots.gcd)
  Bars.TokenColor(gcd, "text.secondary")
  RB.bars = { health = health, power = power, cast = cast, gcd = gcd, totem = {} }
  Layout:Place(f, "rb.stack")
  return f
end

local function totemBar(i)
  local list = RB.bars.totem
  if list[i] then return list[i] end
  local bar = Bars:Create(RB.slots.totem, OWNER)
  bar.icon = bar:CreateTexture(nil, "OVERLAY")
  bar.icon:SetPoint("RIGHT", bar, "LEFT", -1, 0)
  Bars.TokenColor(bar, "life")
  list[i] = bar
  return bar
end

-- Positions the enabled slots top to bottom and sizes the container.
function RB.Layout()
  local f = RB.frame
  if not f then return end
  local y = 0
  CR.kind = nil
  if cfg.class.on then CR.kind = (CR.Resolve()) end
  for _, key in ipairs(ORDER) do
    local slot, c = RB.slots[key], cfg[key]
    local shown = c.on and (key ~= "class" or CR.kind ~= nil)
    slot:ClearAllPoints()
    if shown then
      slot:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
      slot:SetSize(cfg.width, c.height)
      slot:Show()
      y = y + c.height + cfg.spacing
    else
      slot:Hide()
    end
  end
  f:SetSize(cfg.width, math.max(1, y - cfg.spacing))
  local el = Layout:Element("rb.stack")
  if el then el.size = { cfg.width, math.max(1, y - cfg.spacing) } end
  RB.LayoutTicks()
  if cfg.class.on then CR.Configure(RB.slots.class, cfg.width, cfg.class.height) end
  local n = 0
  if cfg.totem.on then n = GetNumTotemSlots() end
  for i = 1, n do
    local bar = totemBar(i)
    local h = cfg.totem.height
    local w = (cfg.width - (n - 1) * 2) / n
    bar.icon:SetSize(h, h)
    bar:ClearAllPoints()
    bar:SetSize(w - h - 1, h)
    bar:SetPoint("LEFT", RB.slots.totem, "LEFT", (i - 1) * (w + 2) + h + 1, 0)
  end
end

-- Hash lines on the power bar at fixed percentages (geometry only).
function RB.LayoutTicks()
  local power = RB.bars.power
  for i, t in ipairs(RB.ticks) do t:Hide() end
  for i, pct in ipairs(cfg.ticks) do
    local t = RB.ticks[i]
    if not t then
      t = power:CreateTexture(nil, "OVERLAY")
      Theme:Paint(t, "text.primary", 0.8)
      RB.ticks[i] = t
    end
    t:ClearAllPoints()
    t:SetSize(1, cfg.power.height)
    t:SetPoint("LEFT", power, "LEFT", math.floor(cfg.width * pct / 100 + 0.5), 0)
    t:Show()
  end
end

-- Updates ---------------------------------------------------------------------------
function RB.UpdateHealth()
  Bars:SetValues(RB.bars.health, UnitHealthMax("player"), UnitHealth("player"), cfg.smooth)
  Bars.ClassColor(RB.bars.health, "player")
end

function RB.UpdatePower()
  if cfg.power.on then Bars:SetValues(RB.bars.power, UnitPowerMax("player"), UnitPower("player"), cfg.smooth) end
  if cfg.class.on then CR.Update() end
end

function RB.UpdatePowerType()
  Bars.PowerColor(RB.bars.power, "player")
  RB.Reconfigure()
end

function RB.UpdateCast()
  local cast = RB.bars.cast
  local direction = Enum.StatusBarTimerDirection
  local name = UnitCastingInfo("player")
  local duration, dir = nil, direction.ElapsedTime
  if type(name) ~= "nil" then
    duration = UnitCastingDuration("player")
  else
    name = UnitChannelInfo("player")
    if type(name) ~= "nil" then duration, dir = UnitChannelDuration("player"), direction.RemainingTime end
  end
  if type(duration) == "nil" then cast:Hide() return end
  cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, dir)
  cast.text:SetText(name)
  cast:Show()
end

function RB.UpdateGCD()
  local bar = RB.bars.gcd
  local d = C_Spell.GetSpellCooldownDuration(GCD_SPELL)
  if type(d) == "nil" then bar:SetAlpha(0) return end
  bar:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
  bar:SetAlphaFromBoolean(d:IsZero(), 0, 1)
end

function RB.UpdateTotems()
  for i, bar in ipairs(RB.bars.totem) do
    local have, _, _, _, icon = GetTotemInfo(i)
    local d = GetTotemDuration(i)
    bar.icon:SetTexture(icon)
    if type(d) ~= "nil" then
      bar:SetTimerDuration(d, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
    end
    bar:SetAlphaFromBoolean(have, 1, 0)
    bar.icon:SetAlphaFromBoolean(have, 1, 0)
  end
end

function RB.UpdateAll()
  if not RB.active then return end
  if cfg.health.on then RB.UpdateHealth() end
  Bars.PowerColor(RB.bars.power, "player")
  RB.UpdatePower()
  if cfg.cast.on then RB.UpdateCast() else RB.bars.cast:Hide() end
  if cfg.gcd.on then RB.UpdateGCD() end
  if cfg.totem.on then RB.UpdateTotems() end
end

-- Event wiring: only the events the enabled bars need ---------------------------------
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }
local ALL = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "RUNE_POWER_UPDATE",
  "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "TRAIT_CONFIG_UPDATED", "SPELL_UPDATE_COOLDOWN",
  "PLAYER_TOTEM_UPDATE", "PLAYER_ENTERING_WORLD" }
for _, ev in ipairs(CAST_EVENTS) do ALL[#ALL + 1] = ev end
RB.ALL_EVENTS = ALL

function RB.Wire()
  local mod = RB.mod
  if not (mod and RB.active) then return end
  for _, ev in ipairs(ALL) do mod:UnregisterEvent(ev) end
  if Ticker:IsRegistered("rb.stagger") then Ticker:Unregister("rb.stagger") end
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() RB.Reconfigure() end)
  if cfg.health.on then
    mod:RegisterUnitEvent("UNIT_HEALTH", RB.UpdateHealth, "player")
    mod:RegisterUnitEvent("UNIT_MAXHEALTH", RB.UpdateHealth, "player")
  end
  if cfg.power.on or cfg.class.on then
    mod:RegisterUnitEvent("UNIT_POWER_UPDATE", RB.UpdatePower, "player")
    mod:RegisterUnitEvent("UNIT_MAXPOWER", function() RB.Reconfigure() end, "player")
    mod:RegisterUnitEvent("UNIT_DISPLAYPOWER", RB.UpdatePowerType, "player")
  end
  if cfg.class.on then
    mod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() RB.Reconfigure() end)
    mod:RegisterEvent("UPDATE_SHAPESHIFT_FORM", function() RB.Reconfigure() end)
    mod:RegisterEvent("TRAIT_CONFIG_UPDATED", function() RB.Reconfigure() end)
    if CR.kind == "runes" then mod:RegisterEvent("RUNE_POWER_UPDATE", function() CR.Update() end) end
    if CR.kind == "stagger" then Ticker:Register("rb.stagger", 0.1, function() CR.Update() end, OWNER) end
  end
  if cfg.cast.on then
    for _, ev in ipairs(CAST_EVENTS) do mod:RegisterUnitEvent(ev, RB.UpdateCast, "player") end
  end
  if cfg.gcd.on then mod:RegisterEvent("SPELL_UPDATE_COOLDOWN", RB.UpdateGCD) end
  if cfg.totem.on then mod:RegisterEvent("PLAYER_TOTEM_UPDATE", RB.UpdateTotems) end
end

function RB.Reconfigure()
  if not RB.active then return end
  RB.Layout()
  RB.Wire()
  RB.UpdateAll()
end

-- Blizzard player cast bar (optional park while the Phoenix cast bar is on).
local function blizzardCast()
  local frame = _G.PlayerCastingBarFrame
  if not frame then return end
  local want = RB.active and cfg.cast.on and cfg.hideBlizzardCast
  CQ.Defer("rb.blizzardCast", function()
    if want and not RB.castParent then
      RB.castHider = RB.castHider or PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
      RB.castHider:Hide()
      RB.castParent = frame:GetParent() or UIParent
      frame:SetParent(RB.castHider)
    elseif not want and RB.castParent then
      frame:SetParent(RB.castParent)
      RB.castParent = nil
    end
  end)
end
RB.BlizzardCast = blizzardCast

-- Lifecycle ----------------------------------------------------------------------------------
local function onEnable(mod)
  RB.active, RB.mod = true, mod
  container():Show()
  RB.Reconfigure()
  blizzardCast()
end

local function onDisable()
  RB.active = false
  if RB.frame then RB.frame:Hide() end
  blizzardCast()
end

-- Schema -----------------------------------------------------------------------------------------
local schema = {}
RB.schema = schema
local function key(name, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    RB.Reconfigure()
    blizzardCast()
  end
  schema[name] = def
end

-- "30, 60" -> { 30, 60 } (1-99, at most 8 lines). Invalid entries are ignored.
function RB.ParseTicks(text)
  local out = {}
  for n in tostring(text):gmatch("[^,%s]+") do
    local v = tonumber(n)
    if v and v > 0 and v < 100 and #out < 8 then out[#out + 1] = v end
  end
  return out
end

key("rb.width", { type = "range", default = 240, min = 80, max = 600, step = 1, label = "Resource bar width",
  tooltip = "Width of the personal resource bar stack.", mode = "simple" }, function(v) cfg.width = v end)
key("rb.spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = "Resource bar spacing",
  tooltip = "Gap between stacked resource bars.", mode = "advanced" }, function(v) cfg.spacing = v end)
key("rb.smooth", { type = "toggle", default = false, label = "Smooth resource bars",
  tooltip = "Health and power bars glide to new values.", mode = "advanced" }, function(v) cfg.smooth = v end)
key("rb.power.ticks", { type = "text", default = "", label = "Power hash lines",
  tooltip = "Comma-separated percentages (1-99) where thin lines are drawn on the power bar, e.g. 30, 60.",
  mode = "advanced" }, function(v) cfg.ticks = RB.ParseTicks(v) end)
key("rb.cast.hideBlizzard", { type = "toggle", default = false, label = "Hide Blizzard cast bar",
  tooltip = "Hides the default player cast bar while the Phoenix cast bar is shown.", mode = "advanced" },
  function(v) cfg.hideBlizzardCast = v end)
local LABELS = { health = "Health bar", power = "Power bar", class = "Class resource", cast = "Cast bar",
  gcd = "Global cooldown bar", totem = "Totem bars" }
for _, name in ipairs(ORDER) do
  local d = DEFAULTS[name]
  key("rb." .. name .. ".enabled", { type = "toggle", default = d.on, label = LABELS[name],
    tooltip = "Shows the " .. LABELS[name]:lower() .. " in the resource stack.", mode = "simple" },
    function(v) cfg[name].on = v end)
  key("rb." .. name .. ".height", { type = "range", default = d.h, min = 2, max = 40, step = 1, label = LABELS[name] .. " height",
    tooltip = "Height of the " .. LABELS[name]:lower() .. ".", mode = "advanced" }, function(v) cfg[name].height = v end)
end

Layout:RegisterElement("rb.stack", { label = "Resource bars", owner = OWNER, size = { 240, 30 },
  default = { point = "CENTER", x = 0, y = -178 } })

RB.module = PUI:RegisterModule(OWNER, {
  label = "Resource bars",
  tooltip = "Personal health, power, class resource, cast, global cooldown and totem bars.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for name, def in pairs(schema) do def.apply(Schema:Get(name)) end
