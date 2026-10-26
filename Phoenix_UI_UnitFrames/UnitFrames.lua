local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit Frames module (PUI_V2 5.3): secure unit buttons for player, target,
-- focus, pet, target of target, focus target and boss1-5, each group with a
-- source (Phoenix / Blizzard / hidden). One tracker frame per unit registers
-- unit events with RegisterUnitEvent and only for the channels a setting needs;
-- target of target and focus target refresh on one shared 0.5 s Ticker entry
-- that exists only while one of them is shown by Phoenix. Off by default; a
-- disabled module owns no buttons, events, drivers or tickers.
local _, ns = ...
local Schema, Layout, CQ, Ticker, Tags = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker, ns.Tags
local E, B = ns.Elements, ns.Blizzard
local OWNER = "UnitFrames"

local UF = { units = {}, active = false }
ns.UF = UF
PUI.UnitFrames = UF

local BOSSES = { "boss1", "boss2", "boss3", "boss4", "boss5" }
local GROUPS = {
  player = { label = "Player", units = { "player" }, w = 220, h = 44, p = 8, pos = { "CENTER", -300, -200 },
    texts = { "name", "none", "health:current-percent", "power:current" }, cast = false, reverse = false },
  target = { label = "Target", units = { "target" }, w = 220, h = 44, p = 8, pos = { "CENTER", 300, -200 },
    texts = { "level:name", "none", "health:current-percent", "power:current" }, cast = true, reverse = true },
  focus = { label = "Focus", units = { "focus" }, w = 170, h = 32, p = 4, pos = { "CENTER", -300, -290 },
    texts = { "name", "none", "health:percent", "none" }, cast = true, reverse = false },
  pet = { label = "Pet", units = { "pet" }, w = 120, h = 24, p = 4, pos = { "CENTER", -380, -250 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = false },
  targettarget = { label = "Target of target", units = { "targettarget" }, w = 120, h = 24, p = 0, pos = { "CENTER", 470, -200 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = true, polled = true },
  focustarget = { label = "Focus target", units = { "focustarget" }, w = 120, h = 24, p = 0, pos = { "CENTER", -130, -290 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = false, polled = true },
  boss = { label = "Boss", units = BOSSES, w = 180, h = 36, p = 6, pos = { "RIGHT", -120, 160 },
    texts = { "name", "none", "health:percent", "none" }, cast = true, reverse = true },
}
local ORDER = { "player", "target", "focus", "pet", "targettarget", "focustarget", "boss" }
UF.GROUPS, UF.ORDER = GROUPS, ORDER

-- Resolved settings (kept in sync by every apply function).
local settings = {
  colorMode = "class", smooth = false, absorbs = true, healPrediction = false, fillAlpha = 1,
  indicators = { raidMarker = true, leader = true, combat = true, resting = false, classification = false, pvp = false },
}
ns.settings = settings
local cfg = {}
UF.cfg = cfg
for g, d in pairs(GROUPS) do
  cfg[g] = { source = "phoenix", width = d.w, height = d.h, powerHeight = d.p, castbar = d.cast, portrait = "off",
    reverse = d.reverse, texts = { left = d.texts[1], center = d.texts[2], right = d.texts[3], power = d.texts[4] } }
end

-- Trackers -----------------------------------------------------------------
local CHANNEL_EVENTS = {
  base = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_CONNECTION" },
  power = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" },
  prediction = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION" },
  portrait = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" },
  cast = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" },
}
UF.CHANNEL_EVENTS = CHANNEL_EVENTS

local HANDLERS = {
  UNIT_HEALTH = function(o) E.UpdateHealth(o); E.UpdatePrediction(o) end,
  UNIT_MAXHEALTH = function(o) E.UpdateHealth(o); E.UpdatePrediction(o) end,
  UNIT_NAME_UPDATE = function(o) E.UpdateTexts(o, "name") end,
  UNIT_LEVEL = function(o) E.UpdateTexts(o, "name") end,
  UNIT_FACTION = function(o) E.UpdateHealthColor(o); E.UpdateIndicators(o) end,
  UNIT_FLAGS = function(o) E.UpdateIndicators(o) end,
  UNIT_CONNECTION = function(o) E.UpdateHealth(o) end,
  UNIT_POWER_UPDATE = function(o) E.UpdatePower(o) end,
  UNIT_MAXPOWER = function(o) E.UpdatePower(o) end,
  UNIT_DISPLAYPOWER = function(o) E.UpdatePowerType(o) end,
  UNIT_ABSORB_AMOUNT_CHANGED = function(o) E.UpdatePrediction(o) end,
  UNIT_HEAL_ABSORB_AMOUNT_CHANGED = function(o) E.UpdatePrediction(o) end,
  UNIT_HEAL_PREDICTION = function(o) E.UpdatePrediction(o) end,
  UNIT_PORTRAIT_UPDATE = function(o) E.UpdatePortrait(o) end,
  UNIT_MODEL_CHANGED = function(o) E.UpdatePortrait(o) end,
}
for _, ev in ipairs(CHANNEL_EVENTS.cast) do HANDLERS[ev] = function(o) E.UpdateCast(o) end end
HANDLERS.UNIT_SPELLCAST_STOP = function(o) E.StopCast(o) end
HANDLERS.UNIT_SPELLCAST_CHANNEL_STOP = function(o) E.StopCast(o) end
HANDLERS.UNIT_SPELLCAST_EMPOWER_STOP = function(o) E.StopCast(o) end
HANDLERS.UNIT_SPELLCAST_FAILED = function(o) E.StopCast(o) end
HANDLERS.UNIT_SPELLCAST_INTERRUPTED = function(o) E.StopCast(o) end
UF.HANDLERS = HANDLERS

local function trackerOnEvent(frame, event)
  local o = frame.owner
  local fn = HANDLERS[event]
  if fn and o.live then fn(o) end
end

-- Channels a unit needs right now (from its group's settings).
function UF.Channels(o)
  local c = cfg[o.group]
  local list = { base = true }
  local tagChannels = Tags.Channels({ c.texts.left, c.texts.center, c.texts.right, c.texts.power }, {})
  if c.powerHeight > 0 or tagChannels.power then list.power = true end
  if settings.absorbs or settings.healPrediction then list.prediction = true end
  if c.portrait ~= "off" then list.portrait = true end
  if c.castbar then list.cast = true end
  return list
end

function UF.Track(o)
  local t = o.tracker
  t:UnregisterAllEvents()
  if not o.live or GROUPS[o.group].polled then return end
  for channel in pairs(UF.Channels(o)) do
    local events = CHANNEL_EVENTS[channel]
    for i = 1, #events do t:RegisterUnitEvent(events[i], o.unit) end
  end
  if settings.absorbs or settings.healPrediction then
    o.calc = o.calc or CreateUnitHealPredictionCalculator()
  end
end

-- Buttons --------------------------------------------------------------------
local function onEnter(self)
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  GameTooltip:SetUnit(self.phoenixUnit)
  GameTooltip:Show()
end
local function onLeave() GameTooltip:Hide() end

local function stateHider()
  if UF.hider then return UF.hider end
  local h = PUI:CreateFrame("Frame", "PhoenixUI_UnitFrameHider", UIParent, "SecureHandlerStateTemplate", OWNER)
  h:SetAllPoints(UIParent)
  UF.hider = h
  return h
end

-- Creates the secure button and children for one unit (out of combat only).
local function build(group, unit)
  local b = PUI:CreateFrame("Button", "PhoenixUI_UF_" .. unit, stateHider(), "SecureUnitButtonTemplate,PingableUnitFrameTemplate", OWNER)
  b.phoenixUnit = unit
  b:SetAttribute("unit", unit)
  b:SetAttribute("type1", "target")
  b:SetAttribute("type2", "togglemenu")
  b:RegisterForClicks("AnyUp")
  b:SetScript("OnEnter", onEnter)
  b:SetScript("OnLeave", onLeave)
  b:Hide()
  local clickCast = rawget(_G, "ClickCastFrames")
  if clickCast == nil then
    clickCast = {}
    _G.ClickCastFrames = clickCast
  end
  clickCast[b] = true
  local o = { unit = unit, group = group, button = b, cfg = cfg[group], live = false }
  o.tracker = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  o.tracker.owner = o
  o.tracker:SetScript("OnEvent", trackerOnEvent)
  E.Build(o)
  UF.units[unit] = o
  return o
end

local function place(group)
  local d, c = GROUPS[group], cfg[group]
  for i, unit in ipairs(d.units) do
    local o = UF.units[unit]
    if o then
      o.button:SetSize(c.width, c.height)
      if i == 1 then
        Layout:Place(o.button, "uf." .. group)
      else
        local prev = UF.units[d.units[i - 1]].button
        o.button:ClearAllPoints()
        o.button:SetPoint("TOP", prev, "BOTTOM", 0, -(8 + (c.castbar and 18 or 0)))
      end
      E.Layout(o, c)
    end
  end
  local el = Layout:Element("uf." .. group)
  if el then el.size = { c.width, c.height } end
end

local function setLive(o, live)
  o.live = live
  if live then
    if o.unit == "player" then o.button:Show() else RegisterUnitWatch(o.button) end
    UF.Track(o)
    E.UpdateAll(o)
  else
    o.tracker:UnregisterAllEvents()
    if o.unit ~= "player" then UnregisterUnitWatch(o.button) end
    o.button:Hide()
  end
end

local function anyPolled()
  for g, d in pairs(GROUPS) do
    if d.polled and cfg[g].source == "phoenix" then return true end
  end
  return false
end

local function pollTick()
  for g, d in pairs(GROUPS) do
    if d.polled then
      local o = UF.units[d.units[1]]
      if o and o.live then E.UpdateAll(o) end
    end
  end
end

function UF.UpdatePolling()
  if UF.active and anyPolled() then
    if not Ticker:IsRegistered("uf.polled") then Ticker:Register("uf.polled", 0.5, pollTick, OWNER) end
  elseif Ticker:IsRegistered("uf.polled") then
    Ticker:Unregister("uf.polled")
  end
end

-- Applies a group's source now or after combat.
function UF.ApplySource(group)
  if not UF.active then return end
  CQ.Defer("uf.source." .. group, function()
    if not UF.active then return end
    local source = cfg[group].source
    for _, unit in ipairs(GROUPS[group].units) do
      local o = UF.units[unit]
      if source == "phoenix" then
        o = o or build(group, unit)
        if not o.live then setLive(o, true) end
      elseif o and o.live then
        setLive(o, false)
      end
    end
    if source == "phoenix" then place(group) end
    if source == "blizzard" then B.Restore(group) else B.Park(group) end
    UF.UpdatePolling()
  end)
end

-- Refreshes a group after a setting change (layout, channels, visuals).
function UF.Refresh(group)
  if not UF.active then return end
  local groups = group and { group } or ORDER
  for _, g in ipairs(groups) do
    if cfg[g].source == "phoenix" then
      CQ.Defer("uf.place." .. g, function() if UF.active then place(g) end end)
      for _, unit in ipairs(GROUPS[g].units) do
        local o = UF.units[unit]
        if o and o.live then
          E.Layout(o, cfg[g])
          UF.Track(o)
          E.UpdateAll(o)
        end
      end
    end
  end
end

function UF.RefreshUnits(groupList)
  for _, g in ipairs(groupList) do
    for _, unit in ipairs(GROUPS[g].units) do
      local o = UF.units[unit]
      if o and o.live then E.UpdateAll(o) end
    end
  end
end

local function indicatorsAll()
  for _, o in pairs(UF.units) do
    if o.live then E.UpdateIndicators(o) end
  end
end

-- Module lifecycle ---------------------------------------------------------------
local function onEnable(mod)
  UF.active = true
  UF.mod = mod
  CQ.Defer("uf.hider", function()
    if UF.active then RegisterStateDriver(stateHider(), "visibility", "[petbattle] hide; show") end
  end)
  for _, g in ipairs(ORDER) do UF.ApplySource(g) end
  mod:RegisterEvent("PLAYER_TARGET_CHANGED", function() UF.RefreshUnits({ "target", "targettarget" }) end)
  mod:RegisterEvent("PLAYER_FOCUS_CHANGED", function() UF.RefreshUnits({ "focus", "focustarget" }) end)
  mod:RegisterUnitEvent("UNIT_PET", function() UF.RefreshUnits({ "pet" }) end, "player")
  mod:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", function() UF.RefreshUnits({ "boss" }) end)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() UF.RefreshUnits(ORDER) end)
  mod:RegisterEvent("RAID_TARGET_UPDATE", indicatorsAll)
  mod:RegisterEvent("PARTY_LEADER_CHANGED", indicatorsAll)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", indicatorsAll)
  mod:RegisterEvent("PLAYER_UPDATE_RESTING", indicatorsAll)
end

local function onDisable()
  UF.active = false
  for unit, o in pairs(UF.units) do
    o.tracker:UnregisterAllEvents()
    o.live = false
    CQ.Defer("uf.off." .. unit, function()
      if UF.active then return end
      if unit ~= "player" then UnregisterUnitWatch(o.button) end
      o.button:Hide()
    end)
  end
  CQ.Defer("uf.hider", function()
    if not UF.active and UF.hider then UnregisterStateDriver(UF.hider, "visibility") end
  end)
  for _, g in ipairs(ORDER) do B.Restore(g) end
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
UF.schema = schema
local SOURCES = { "phoenix", "blizzard", "hidden" }
local PORTRAITS = { "off", "2d", "3d" }

local function global(key, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    UF.Refresh()
  end
  schema[key] = def
end

global("uf.colorMode", { type = "select", default = "class", choices = { "class", "reaction", "gradient", "accent" },
  label = "Health colour", tooltip = "Class colour (players), reaction colour, a red-to-green gradient by health, or the accent colour.",
  mode = "simple", searchTags = { "colour", "color", "health" } }, function(v) settings.colorMode = v end)
global("uf.smooth", { type = "toggle", default = false, label = "Smooth bars",
  tooltip = "Health and power bars glide to new values instead of jumping.", mode = "advanced" }, function(v) settings.smooth = v end)
global("uf.absorbs", { type = "toggle", default = true, label = "Show absorbs",
  tooltip = "Shows damage absorbs after the health fill and heal absorbs on it.", mode = "advanced" }, function(v) settings.absorbs = v end)
global("uf.healPrediction", { type = "toggle", default = false, label = "Show incoming heals",
  tooltip = "Shows predicted incoming heals after the health fill.", mode = "advanced" }, function(v) settings.healPrediction = v end)
global("uf.fillAlpha", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = "Health fill opacity",
  tooltip = "Opacity of the health fill.", mode = "advanced" }, function(v) settings.fillAlpha = v end)
for _, name in ipairs({ "raidMarker", "leader", "combat", "resting", "classification", "pvp" }) do
  local labels = { raidMarker = "raid markers", leader = "group leader", combat = "in combat", resting = "resting (player)",
    classification = "elite / rare", pvp = "PvP flag" }
  global("uf.indicator." .. name, { type = "toggle", default = settings.indicators[name], label = "Indicator: " .. labels[name],
    tooltip = "Shows the " .. labels[name] .. " icon on unit frames.", mode = "advanced" }, function(v) settings.indicators[name] = v end)
end

local function groupKey(g, key, def, set, refresh)
  def.owner = OWNER
  def.apply = function(value)
    set(cfg[g], value)
    if refresh == "source" then UF.ApplySource(g) else UF.Refresh(g) end
  end
  schema["uf." .. g .. "." .. key] = def
end

for _, g in ipairs(ORDER) do
  local d, label = GROUPS[g], GROUPS[g].label
  local simple = (g == "player" or g == "target") and "simple" or "advanced"
  groupKey(g, "source", { type = "select", default = "phoenix", choices = SOURCES, label = label .. " frame",
    tooltip = "Phoenix draws this frame, Blizzard shows the default frame, or hidden shows neither.", mode = "simple" },
    function(c, v) c.source = v end, "source")
  groupKey(g, "width", { type = "range", default = d.w, min = 60, max = 400, step = 1, label = label .. " width",
    tooltip = "Width of the " .. label:lower() .. " frame in pixels.", mode = simple }, function(c, v) c.width = v end)
  groupKey(g, "height", { type = "range", default = d.h, min = 12, max = 120, step = 1, label = label .. " height",
    tooltip = "Height of the " .. label:lower() .. " frame in pixels.", mode = simple }, function(c, v) c.height = v end)
  groupKey(g, "powerHeight", { type = "range", default = d.p, min = 0, max = 30, step = 1, label = label .. " power bar height",
    tooltip = "Height of the power bar; 0 hides it.", mode = "advanced" }, function(c, v) c.powerHeight = v end)
  groupKey(g, "castbar", { type = "toggle", default = d.cast, label = label .. " cast bar",
    tooltip = "Shows a cast bar under the " .. label:lower() .. " frame.", mode = "advanced" }, function(c, v) c.castbar = v end)
  groupKey(g, "portrait", { type = "select", default = "off", choices = PORTRAITS, label = label .. " portrait",
    tooltip = "Portrait beside the frame: off, 2D or 3D.", mode = "advanced" }, function(c, v) c.portrait = v end)
  groupKey(g, "reverse", { type = "toggle", default = d.reverse, label = label .. " fill right to left",
    tooltip = "Bars fill from the right.", mode = "advanced" }, function(c, v) c.reverse = v end)
  for i, zone in ipairs(E.ZONES) do
    groupKey(g, "text." .. zone, { type = "select", default = d.texts[i], choices = Tags.order,
      label = label .. " text (" .. zone .. ")", tooltip = "What the " .. zone .. " text zone shows.", mode = "advanced" },
      function(c, v) c.texts[zone] = v end)
  end
end

for _, g in ipairs(ORDER) do
  local d = GROUPS[g]
  Layout:RegisterElement("uf." .. g, { label = d.label .. " frame", owner = OWNER, size = { d.w, d.h },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

-- Settings registered after Phoenix_UI's ApplyAll: read stored values now so the
-- resolved tables match the profile before the module first enables.
local function syncFromDB()
  for key, def in pairs(schema) do def.apply(Schema:Get(key)) end
end

UF.module = PUI:RegisterModule(OWNER, {
  label = "Unit frames",
  tooltip = "Phoenix player, target, focus, pet, target-of-target, focus-target and boss frames.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
UF.SyncFromDB = syncFromDB
