local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Resource Bars module (PUI_V2 5.8): a movable stack of personal bars for the
-- player - health, power (with hash lines), class resource, cast, global
-- cooldown and totems. Each bar is opt-in per setting; events are registered
-- only for the bars that are on, and the module owns nothing while disabled.
-- Step 6 (plan 5.6, 13.7, 1.O): the player cast bar is the shared PUI.CastBar
-- element (one 13-event dispatcher for every cast bar, engine timing, own
-- colours and parts as settings); health and power text, power colour modes
-- and the "attach under the player frame / keep separate" host setting live
-- here as well as on the Unit Frames page.
local _, ns = ...
local Schema, Layout, CQ, Ticker, Bars, Theme, Media = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker, PUI.Bars, PUI.Theme, PUI.Media
local CR = ns.ClassResource
local OWNER = "ResourceBars"
local GCD_SPELL = 61304 -- the global cooldown spell

local RB = { active = false, bars = {}, ticks = {} }
ns.RB = RB
PUI.ResourceBars = RB
RB.ClassResource = CR -- read-only resolver for the target-plate resource (Nameplates)

local ORDER = { "health", "power", "class", "cast", "gcd", "totem" }
RB.ORDER = ORDER
local DEFAULTS = {
  health = { on = false, h = 10 }, power = { on = true, h = 10 }, class = { on = true, h = 8 },
  cast = { on = false, h = 14 }, gcd = { on = false, h = 3 }, totem = { on = false, h = 14 },
}
local cfg = { width = 240, spacing = 2, ticks = {}, smooth = false, hideBlizzardCast = false, matchHost = true,
  healthText = "none", powerText = "none", powerColor = "power",
  castStyle = { icon = true, iconSide = "LEFT", spellName = true, timer = true, shield = false, kick = false, fadeOut = 0.35,
    colors = { cast = { r = 1, g = 0.62, b = 0.18 }, channel = { r = 0.36, g = 0.7, b = 1 } } } }
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
  for _, b in ipairs({ health, power }) do
    b.valueText = b:CreateFontString(nil, "OVERLAY")
    b.valueText:SetFontObject(Media:FontObject("number"))
    b.valueText:SetPoint("CENTER", b, "CENTER", 0, 0)
  end
  local gcd = Bars:Create(slots.gcd, OWNER); gcd:SetAllPoints(slots.gcd)
  Bars.TokenColor(gcd, "text.secondary")
  RB.bars = { health = health, power = power, gcd = gcd, totem = {} }
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
  local width = cfg.width
  local host = RB.host
  if host and host.matchWidth and cfg.matchHost and host.frame:GetWidth() > 0 then width = math.floor(host.frame:GetWidth() + 0.5) end
  RB.widthNow = width
  local y = 0
  CR.kind = nil
  if cfg.class.on then CR.kind = (CR.Resolve()) end
  for _, key in ipairs(ORDER) do
    local slot, c = RB.slots[key], cfg[key]
    local shown = c.on and (key ~= "class" or CR.kind ~= nil)
    slot:ClearAllPoints()
    if shown then
      slot:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -y)
      slot:SetSize(width, c.height)
      slot:Show()
      y = y + c.height + cfg.spacing
    else
      slot:Hide()
    end
  end
  f:SetSize(width, math.max(1, y - cfg.spacing))
  local el = Layout:Element("rb.stack")
  if el then el.size = { width, math.max(1, y - cfg.spacing) } end
  if host then
    f:ClearAllPoints()
    f:SetPoint("TOP", host.frame, "BOTTOM", 0, -host.gap)
  elseif RB.wasHosted then
    RB.wasHosted = nil
    Layout:Place(f, "rb.stack")
  end
  RB.LayoutTicks()
  if cfg.class.on then CR.Configure(RB.slots.class, width, cfg.class.height) end
  RB.LayoutCast(width)
  local n = 0
  if cfg.totem.on then n = GetNumTotemSlots() end
  for i = 1, n do
    local bar = totemBar(i)
    local h = cfg.totem.height
    local w = (width - (n - 1) * 2) / n
    bar.icon:SetSize(h, h)
    bar:ClearAllPoints()
    bar:SetSize(w - h - 1, h)
    bar:SetPoint("LEFT", RB.slots.totem, "LEFT", (i - 1) * (w + 2) + h + 1, 0)
  end
end

-- Player cast bar on the shared PUI.CastBar element (created on first use).
function RB.CastStyle(width)
  local c, st = cfg.cast, cfg.castStyle
  local h = c.height
  local s = PUI.Schema.Copy(st)
  s.width = math.max(20, width - (st.icon and (h + 2) or 0))
  s.height = h
  local base = PUI.CastBar.DEFAULT_STYLE.colors
  s.colors = { cast = st.colors.cast, channel = st.colors.channel, empower = base.empower, locked = base.locked,
    failed = base.failed, done = base.done }
  return s
end

function RB.LayoutCast(width)
  local bar = RB.castBar
  if not (RB.active and cfg.cast.on) then
    if bar then bar:Disable() end
    return
  end
  if not bar then
    bar = PUI.CastBar:Create(OWNER, RB.slots.cast, "player", RB.CastStyle(width))
    RB.castBar = bar
  else
    bar:ApplyStyle(RB.CastStyle(width))
    bar:Enable()
  end
  bar.frame:ClearAllPoints()
  if cfg.castStyle.icon and cfg.castStyle.iconSide == "RIGHT" then
    bar.frame:SetPoint("LEFT", RB.slots.cast, "LEFT", 0, 0)
  else
    bar.frame:SetPoint("RIGHT", RB.slots.cast, "RIGHT", 0, 0)
  end
end

-- Hosting (plan 1.O "Player cast bar / class resource"): Resource Bars owns
-- the elements; the Unit Frames player frame may host the stack under itself
-- ("attach here") or leave it where Studio placed it ("keep separate").
-- SetHost(frame, gap, matchWidth) attaches; SetHost(nil) returns to Studio.
function RB.SetHost(frame, gap, matchWidth)
  if frame then
    RB.host = { frame = frame, gap = gap or 2, matchWidth = matchWidth ~= false }
  else
    if RB.host then RB.wasHosted = true end
    RB.host = nil
  end
  if RB.active then RB.Layout() end
end
function RB.Host() return RB.host and RB.host.frame or nil end

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
    t:SetPoint("LEFT", power, "LEFT", math.floor((RB.widthNow or cfg.width) * pct / 100 + 0.5), 0)
    t:Show()
  end
end

-- Updates ---------------------------------------------------------------------------
-- Value text: engine values go straight to the font string (may be secret).
local Format = PUI.Format
function RB.ValueText(fs, mode, value, pct)
  if mode == "none" then fs:SetText("") return end
  if mode == "percent" then fs:SetFormattedText("%.0f%%", pct) return end
  if mode == "value" then fs:SetText(Format.Number(value)) return end
  fs:SetFormattedText("%s - %.0f%%", Format.Number(value), pct)
end

function RB.UpdateHealth()
  Bars:SetValues(RB.bars.health, UnitHealthMax("player"), UnitHealth("player"), cfg.smooth)
  Bars.ClassColor(RB.bars.health, "player")
  RB.ValueText(RB.bars.health.valueText, cfg.healthText, UnitHealth("player"), UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
end

function RB.UpdatePower()
  if cfg.power.on then
    Bars:SetValues(RB.bars.power, UnitPowerMax("player"), UnitPower("player"), cfg.smooth)
    RB.ValueText(RB.bars.power.valueText, cfg.powerText, UnitPower("player"), UnitPowerPercent("player", nil, false, CurveConstants.ScaleTo100))
  end
  if cfg.class.on then CR.Update() end
end

function RB.PaintPower()
  local bar = RB.bars.power
  if cfg.powerColor == "class" then Bars.ClassColor(bar, "player")
  elseif cfg.powerColor == "accent" then Bars.TokenColor(bar, "accent")
  else Bars.PowerColor(bar, "player") end
end

function RB.UpdatePowerType()
  RB.PaintPower()
  RB.Reconfigure()
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
  RB.PaintPower()
  RB.UpdatePower()
  if RB.castBar and cfg.cast.on then RB.castBar:Refresh() end
  if cfg.gcd.on then RB.UpdateGCD() end
  if cfg.totem.on then RB.UpdateTotems() end
end

-- Event wiring: only the events the enabled bars need ---------------------------------
local ALL = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "RUNE_POWER_UPDATE",
  "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "TRAIT_CONFIG_UPDATED", "SPELL_UPDATE_COOLDOWN",
  "PLAYER_TOTEM_UPDATE", "PLAYER_ENTERING_WORLD" }
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
  if RB.castBar then RB.castBar:Disable() end
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
key("rb.matchHostWidth", { type = "toggle", default = true, label = "Match the player frame width when attached",
  tooltip = "When Unit Frames attaches these bars under your player frame, they take its width. Off keeps the width set here.",
  mode = "advanced", searchTags = { "attach", "player frame", "width" } }, function(v) cfg.matchHost = v end)
local TEXT = { "none", "percent", "value", "both" }
local TEXT_LABELS = { none = "No text", percent = "Percent", value = "Value", both = "Value and percent" }
key("rb.health.text", { type = "select", default = "none", choices = TEXT, choiceLabels = TEXT_LABELS, label = "Health bar text",
  tooltip = "Text on the health bar.", mode = "advanced" }, function(v) cfg.healthText = v end)
key("rb.power.text", { type = "select", default = "none", choices = TEXT, choiceLabels = TEXT_LABELS, label = "Power bar text",
  tooltip = "Text on the power bar.", mode = "simple" }, function(v) cfg.powerText = v end)
key("rb.power.color", { type = "select", default = "power", choices = { "power", "class", "accent" },
  choiceLabels = { power = "Power type (mana blue, rage red...)", class = "Class colour", accent = "Phoenix accent" },
  label = "Power bar colour", tooltip = "How the power bar is coloured.", mode = "advanced" }, function(v) cfg.powerColor = v end)
local function castKey(name, def, set)
  key("rb.cast." .. name, def, function(v) set(cfg.castStyle, v) end)
end
castKey("icon", { type = "toggle", default = true, label = "Cast bar icon", tooltip = "Shows the spell icon beside the cast bar.",
  mode = "simple" }, function(st, v) st.icon = v end)
castKey("iconSide", { type = "select", default = "LEFT", choices = { "LEFT", "RIGHT" }, choiceLabels = { LEFT = "Left", RIGHT = "Right" },
  label = "Cast bar icon side", tooltip = "Which side of the cast bar the icon sits on.", mode = "advanced" }, function(st, v) st.iconSide = v end)
castKey("spellName", { type = "toggle", default = true, label = "Cast bar spell name", tooltip = "Shows the spell name on the cast bar.",
  mode = "advanced" }, function(st, v) st.spellName = v end)
castKey("timer", { type = "toggle", default = true, label = "Cast bar time", tooltip = "Shows the time left on the cast bar.",
  mode = "advanced" }, function(st, v) st.timer = v end)
castKey("fadeOut", { type = "range", default = 0.35, min = 0, max = 1.5, step = 0.05, label = "Cast bar fade out",
  tooltip = "Seconds the finished or interrupted cast stays visible while fading (0 hides it at once).", mode = "advanced" },
  function(st, v) st.fadeOut = v end)
castKey("castColor", { type = "color", default = { r = 1, g = 0.62, b = 0.18, a = 1 }, label = "Cast bar colour",
  tooltip = "Colour of the cast bar while casting.", mode = "advanced" }, function(st, v) st.colors.cast = v end)
castKey("channelColor", { type = "color", default = { r = 0.36, g = 0.7, b = 1, a = 1 }, label = "Channel bar colour",
  tooltip = "Colour of the cast bar while channelling.", mode = "advanced" }, function(st, v) st.colors.channel = v end)
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

local Coexist = PUI.Coexist
local ckey, cdef = Coexist:Define("resourcebars", { module = OWNER, job = "Personal resource bars",
  addons = { "EllesmereUIResourceBars", "SenseiClassResourceBar", "PersonalResourceReskin" } })
cdef.owner = OWNER
schema[ckey] = cdef

Layout:RegisterElement("rb.stack", { label = "Resource bars", owner = OWNER, size = { 240, 30 },
  default = { point = "CENTER", x = 0, y = -178 } })

RB.module = PUI:RegisterModule(OWNER, {
  label = "Resource bars",
  tooltip = "Personal health, power, class resource, cast, global cooldown and totem bars.",
  enabledByDefault = false,
  loadCondition = function() return Coexist:Allows("resourcebars") end,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
for name, def in pairs(schema) do if name ~= ckey then def.apply(Schema:Get(name)) end end
