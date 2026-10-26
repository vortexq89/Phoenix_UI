local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Unit Frames module (plan 5.1, 13.2, 15.3, 15.6, mockup 01): secure unit
-- buttons for player, target, focus, pet, target of target, focus target and
-- boss1-5, each group with a source (Phoenix / Blizzard / hidden). Looks:
-- Ember (default), Glass, Blizzard-like, Classic-like; every attribute of a
-- look is also its own setting (D-MOD-DEF). One tracker frame per unit
-- registers unit events with RegisterUnitEvent and only for the channels a
-- setting needs; cast bars run on the shared PUI.CastBar dispatcher; auras on
-- PUI.Auras; range on PUI.Range; "where to show" on PUI.Visibility. Target of
-- target and focus target refresh on one shared Ticker entry that exists only
-- while one of them is shown. Off by default; a disabled module owns no
-- buttons, events, drivers or tickers. Unit tokens live in secure attributes
-- and in our own tables only, never as a `.unit` field on a frame (plan 16).
local _, ns = ...
local Schema, Layout, CQ, Ticker, Tags = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Ticker, ns.Tags
local E, B, A, Styles = ns.Elements, ns.Blizzard, ns.UFAuras, ns.Styles
local OWNER = "UnitFrames"

local UF = { units = {}, active = false, test = false }
ns.UF = UF
PUI.UnitFrames = UF
UF.Styles = Styles

local BOSSES = { "boss1", "boss2", "boss3", "boss4", "boss5" }
-- Per-group starting values (first install only; every one is a setting).
local GROUPS = {
  player = { label = "Player", units = { "player" }, w = 230, h = 46, p = 9, pos = { "CENTER", -190, -110 },
    texts = { "name", "none", "health:current-percent", "power:current" }, cast = false, reverse = false, portrait = "look",
    side = "left", buffs = { false, 8, "all" }, debuffs = { false, 8, "all" } },
  target = { label = "Target", units = { "target" }, w = 230, h = 46, p = 9, pos = { "CENTER", 190, -110 },
    texts = { "level:name", "none", "health:current-percent", "power:current" }, cast = true, reverse = false, portrait = "look",
    side = "right", buffs = { true, 8, "all" }, debuffs = { true, 8, "mine" } },
  focus = { label = "Focus", units = { "focus" }, w = 180, h = 34, p = 5, pos = { "CENTER", -390, -40 },
    texts = { "name", "none", "health:percent", "none" }, cast = true, reverse = false, portrait = "off",
    side = "left", buffs = { false, 4, "all" }, debuffs = { true, 4, "mine" } },
  pet = { label = "Pet", units = { "pet" }, w = 120, h = 24, p = 4, pos = { "CENTER", -280, -160 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = false, portrait = "off",
    side = "left", buffs = { false, 4, "all" }, debuffs = { false, 4, "all" } },
  targettarget = { label = "Target of target", units = { "targettarget" }, w = 120, h = 24, p = 0, pos = { "CENTER", 360, -160 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = false, portrait = "off", polled = true,
    side = "right", buffs = { false, 4, "all" }, debuffs = { false, 4, "all" } },
  focustarget = { label = "Focus target", units = { "focustarget" }, w = 120, h = 24, p = 0, pos = { "CENTER", -520, -40 },
    texts = { "name", "none", "health:percent", "none" }, cast = false, reverse = false, portrait = "off", polled = true,
    side = "left", buffs = { false, 4, "all" }, debuffs = { false, 4, "all" } },
  boss = { label = "Boss", units = BOSSES, w = 190, h = 38, p = 6, pos = { "RIGHT", -120, 160 },
    texts = { "name", "none", "health:percent", "none" }, cast = true, reverse = false, portrait = "off",
    side = "right", buffs = { true, 3, "important" }, debuffs = { true, 4, "mine" } },
}
local ORDER = { "player", "target", "focus", "pet", "targettarget", "focustarget", "boss" }
UF.GROUPS, UF.ORDER = GROUPS, ORDER
local RANGE_GROUPS = { target = true, focus = true, boss = true, focustarget = true, targettarget = true }

-- Resolved settings (kept in sync by every apply function).
local CAST_COLORS = {
  cast = { r = 1, g = 0.62, b = 0.18 }, channel = { r = 0.36, g = 0.7, b = 1 }, empower = { r = 0.69, g = 0.49, b = 1 },
  locked = { r = 0.55, g = 0.56, b = 0.6 }, failed = { r = 0.9, g = 0.31, b = 0.42 }, done = { r = 0.24, g = 0.86, b = 0.59 },
}
local settings = {
  style = "ember", border = "look", borderColor = "look", background = "look", powerStyle = "look", portraitShape = "look",
  edge = "look", colorMode = "look", healthColor = { r = 0.24, g = 0.86, b = 0.59 }, darkMode = false,
  smooth = false, absorbs = true, healPrediction = false, fillAlpha = 1, threat = true,
  rangeFade = true, rangeAlpha = 0.45, font = "global", fontSize = 12, fontOutline = "shadow", castFade = 0.35,
  castColors = PUI.Schema.Copy(CAST_COLORS),
  indicators = { raidMarker = true, leader = true, combat = true, resting = false, classification = false, pvp = false },
}
ns.settings = settings
UF.settings = settings
local cfg = {}
UF.cfg = cfg
for g, d in pairs(GROUPS) do
  cfg[g] = { source = "phoenix", width = d.w, height = d.h, powerHeight = d.p, reverse = d.reverse, vertical = false,
    portrait = d.portrait, portraitSide = d.side, texture = "global",
    castbar = d.cast, castHeight = 16, castWidth = 0, castIcon = true, castName = true, castTimer = true, castShield = true,
    castKick = g == "target" or g == "focus", castPosition = "below",
    visibility = { mode = "always" }, hiddenAlpha = 0,
    growth = "down", spacing = 12, resources = "attach", resourcesGap = 3,
    texts = { left = d.texts[1], center = d.texts[2], right = d.texts[3], power = d.texts[4] },
    auras = {
      buffs = { enabled = d.buffs[1], max = d.buffs[2], size = 22, perRow = 8, position = "below", filter = d.buffs[3], sort = "default" },
      debuffs = { enabled = d.debuffs[1], max = d.debuffs[2], size = 22, perRow = 8, position = g == "boss" and "left" or "below",
        filter = d.debuffs[3], sort = "expiration" },
    } }
end

-- Trackers -----------------------------------------------------------------
local CHANNEL_EVENTS = {
  base = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_FLAGS", "UNIT_CONNECTION" },
  power = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" },
  prediction = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION" },
  portrait = { "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED" },
  threat = { "UNIT_THREAT_SITUATION_UPDATE" },
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
  UNIT_THREAT_SITUATION_UPDATE = function(o) E.UpdateThreat(o) end,
}
UF.HANDLERS = HANDLERS

local function trackerOnEvent(frame, event)
  local o = UF.trackerOwner[frame]
  local fn = HANDLERS[event]
  if o and fn and o.live and not UF.test then fn(o) end
end
UF.trackerOwner = setmetatable({}, { __mode = "k" })

-- Channels a unit needs right now (from its group's settings).
function UF.Channels(o)
  local c = cfg[o.group]
  local list = { base = true }
  local tagChannels = Tags.Channels({ c.texts.left, c.texts.center, c.texts.right, c.texts.power }, {})
  if c.powerHeight > 0 or tagChannels.power then list.power = true end
  if settings.absorbs or settings.healPrediction then list.prediction = true end
  local look = o.look or E.Look(o)
  if look.portrait ~= "off" then list.portrait = true end
  if settings.threat and (o.group == "player" or o.group == "target" or o.group == "focus" or o.group == "boss") then list.threat = true end
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

-- Range fade (PUI.Range, refcounted): target / focus / boss / ToT / FoT.
function UF.Range(o)
  local want = o.live and settings.rangeFade and RANGE_GROUPS[o.group] and not UF.test
  if want and not o.range then
    o.range = PUI.Range:Acquire(OWNER, o.unit, function(inRange, checked)
      if PUI.Secret.IsSecret(checked) or checked then o.body:SetAlphaFromBoolean(inRange, 1, settings.rangeAlpha)
      else o.body:SetAlpha(1) end -- not checkable (e.g. hostile units): never faded
    end)
  elseif not want and o.range then
    PUI.Range:Release(o.range)
    o.range = nil
    o.body:SetAlpha(1)
  end
end

-- Buttons --------------------------------------------------------------------
local function onEnter(self)
  GameTooltip_SetDefaultAnchor(GameTooltip, self)
  GameTooltip:SetUnit(self:GetAttribute("unit"))
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
  PUI.Kernel:Fire("CLICKCAST_FRAME", b)
  local o = { unit = unit, group = group, button = b, cfg = cfg[group], live = false }
  o.tracker = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  UF.trackerOwner[o.tracker] = o
  o.tracker:SetScript("OnEvent", trackerOnEvent)
  E.Build(o)
  UF.units[unit] = o
  return o
end

-- Vertical space one boss frame takes in the stack (frame + cast + auras below).
function UF.StackStep(group)
  local c = cfg[group]
  local step = c.height + E.CastSpace(group, c)
  for _, kind in ipairs(A.KINDS) do
    local a = c.auras[kind]
    if a.enabled and a.position == "below" then
      local rows = math.ceil(a.max / math.max(1, a.perRow))
      step = step + rows * (a.size + 2) + 3
    end
  end
  return step + c.spacing
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
        local step = UF.StackStep(group) - c.height
        if c.growth == "up" then o.button:SetPoint("BOTTOM", prev, "TOP", 0, step)
        else o.button:SetPoint("TOP", prev, "BOTTOM", 0, -step) end
      end
      E.Layout(o, c)
      A.Setup(o, group, c)
    end
  end
  local el = Layout:Element("uf." .. group)
  if el then el.size = { c.width, c.height } end
  if group == "player" then UF.HostResources() end
end

-- Resource Bars hosting (plan 1.O): attach the stack under the player frame or
-- leave it where Studio placed it. Resource Bars owns the bars either way.
function UF.HostResources()
  local RB = PUI.ResourceBars
  if not (RB and RB.SetHost) then return end
  local o = UF.units.player
  local c = cfg.player
  local want = UF.active and o and o.live and c.resources == "attach"
  local hostFrame = want and o.button or nil
  if want then
    local below = 0
    for _, kind in ipairs(A.KINDS) do
      local a = c.auras[kind]
      if a.enabled and a.position == "below" then below = below + math.ceil(a.max / math.max(1, a.perRow)) * (a.size + 2) + 3 end
    end
    RB.SetHost(hostFrame, c.resourcesGap + below, true)
  elseif RB.Host() and RB.Host() == (o and o.button) then
    RB.SetHost(nil)
  end
end

-- "Where to show" (PUI.Visibility). Alpha only, so it is safe in combat; the
-- reason is kept for the options "why hidden" readout.
function UF.WatchVisibility(group)
  local id = "uf." .. group
  local c = cfg[group]
  if not (UF.active and c.source == "phoenix") then PUI.Visibility:Unwatch(id) return end
  local rule = c.visibility
  local fn = function(shown)
    UF.shown = UF.shown or {}
    UF.shown[group] = shown
    for _, unit in ipairs(GROUPS[group].units) do
      local o = UF.units[unit]
      if o then o.button:SetAlpha(shown and 1 or c.hiddenAlpha) end
    end
  end
  PUI.Visibility:Watch(id, rule, fn) -- replaces any earlier watch and applies now
end

local function setLive(o, live)
  o.live = live
  if live then
    if o.unit == "player" then o.button:Show() else RegisterUnitWatch(o.button) end
    UF.Track(o)
    E.Layout(o, cfg[o.group])
    A.Setup(o, o.group, cfg[o.group])
    UF.Range(o)
    E.UpdateAll(o)
  else
    o.tracker:UnregisterAllEvents()
    if o.castbar then o.castbar:Disable() end
    A.Off(o)
    UF.Range(o)
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
  if UF.test then return end
  for _, d in pairs(GROUPS) do
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
    UF.WatchVisibility(group)
    UF.UpdatePolling()
    if group == "player" then UF.HostResources() end
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
          A.Setup(o, g, cfg[g])
          UF.Track(o)
          UF.Range(o)
          if UF.test then E.PaintSample(o, tonumber(unit:match("%d+"))) else E.UpdateAll(o) end
        end
      end
      UF.WatchVisibility(g)
    end
  end
  if ns.AuraBars then ns.AuraBars.Apply() end
end

function UF.RefreshUnits(groupList)
  if UF.test then return end
  for _, g in ipairs(groupList) do
    for _, unit in ipairs(GROUPS[g].units) do
      local o = UF.units[unit]
      if o and o.live then E.UpdateAll(o) end
    end
  end
end

local function indicatorsAll()
  if UF.test then return end
  for _, o in pairs(UF.units) do
    if o.live then E.UpdateIndicators(o) end
  end
end

-- Test frames: every Phoenix frame shows sample data (all five boss frames
-- too) so layouts can be set up anywhere. Out of combat only; leaving combat
-- or turning it off restores the live units.
function UF.SetTestMode(on)
  on = on == true
  if on == UF.test then return true end
  if on and InCombatLockdown() then return false, "not in combat" end
  CQ.Defer("uf.test", function()
    UF.test = on
    for _, g in ipairs(ORDER) do
      for i, unit in ipairs(GROUPS[g].units) do
        local o = UF.units[unit]
        if o and o.live then
          if on then
            if unit ~= "player" then UnregisterUnitWatch(o.button) end
            o.button:Show()
            UF.Range(o)
            E.PaintSample(o, i)
          else
            if unit ~= "player" then RegisterUnitWatch(o.button) end
            UF.Range(o)
            E.UpdateAll(o)
          end
        end
      end
    end
    PUI.Kernel:Fire("UF_TEST_MODE", on)
  end)
  return true
end

-- "Copy settings from..." (plan 13.2): every per-group key of `from` that exists
-- on `to` is copied with Schema:Set (validated, live, undo = reset).
function UF.CopyGroup(from, to)
  if from == to or not (GROUPS[from] and GROUPS[to]) then return 0 end
  local n = 0
  local prefix = "uf." .. from .. "."
  for key, def in pairs(UF.schema) do
    if key:sub(1, #prefix) == prefix then
      local rest = key:sub(#prefix + 1)
      local target = "uf." .. to .. "." .. rest
      if rest ~= "source" and UF.schema[target] then
        local v = Schema:Get(key)
        if Schema:Validate(UF.schema[target], v) and not PUI.DB.DeepEqual(v, Schema:Get(target)) then
          Schema:Set(target, v)
          n = n + 1
        end
      end
    end
  end
  return n
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
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", function() if UF.test then UF.SetTestMode(false) end end)
  if ns.AuraBars then CQ.Defer("uf.aurabars", function() if UF.active then ns.AuraBars.Apply() end end) end
end

local function onDisable()
  UF.active = false
  UF.test = false
  for unit, o in pairs(UF.units) do
    o.tracker:UnregisterAllEvents()
    o.live = false
    if o.castbar then o.castbar:Disable() end
    A.Off(o)
    o.auras = nil -- handles are released by PUI.Auras on MODULE_DISABLED
    UF.Range(o)
    CQ.Defer("uf.off." .. unit, function()
      if UF.active then return end
      if unit ~= "player" then UnregisterUnitWatch(o.button) end
      o.button:Hide()
    end)
  end
  for _, g in ipairs(ORDER) do PUI.Visibility:Unwatch("uf." .. g) end
  CQ.Defer("uf.hider", function()
    if not UF.active and UF.hider then UnregisterStateDriver(UF.hider, "visibility") end
  end)
  for _, g in ipairs(ORDER) do B.Restore(g) end
  if ns.AuraBars then ns.AuraBars.Off(); ns.AuraBars.handles = {} end
  local RB = PUI.ResourceBars
  if RB and RB.SetHost and RB.Host() and UF.units.player and RB.Host() == UF.units.player.button then RB.SetHost(nil) end
  Ticker:Unregister("uf.polled")
end

PUI.Kernel:On("BARS_CHANGED", function() if UF.active then UF.Refresh() end end)
PUI.Kernel:On("MEDIA_CHANGED", function() if UF.active then UF.Refresh() end end)
PUI.Kernel:On("MODULE_ENABLED", function(name) if name == "ResourceBars" and UF.active then UF.HostResources() end end)

-- Schema ---------------------------------------------------------------------------
local schema = {}
UF.schema = schema
local SOURCES = { "phoenix", "blizzard", "hidden" }
local SOURCE_LABELS = { phoenix = "Phoenix", blizzard = "Blizzard", hidden = "Hidden" }
local function labels(extra)
  local t = { look = "From the look" }
  for k, v in pairs(extra) do t[k] = v end
  return t
end

local function global(key, def, set)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    UF.Refresh()
  end
  schema[key] = def
end

global("uf.style", { type = "select", default = "ember", choices = Styles.order, choiceLabels = Styles.LABELS,
  label = "Look", tooltip = "Ember (portrait, flat bars, thick power), Glass (rounded, thin power, class icon), Blizzard-like or Classic-like. Each part of the look can also be changed on its own below.",
  mode = "simple", searchTags = { "style", "theme", "skin", "ember", "glass" } }, function(v) settings.style = v end)
global("uf.border", { type = "select", default = "look", choices = Styles.BORDERS,
  choiceLabels = labels({ none = "None", thin = "Thin", thick = "Thick", glow = "Soft glow" }),
  label = "Border", tooltip = "Frame border thickness.", mode = "advanced", searchTags = { "outline", "edge" } }, function(v) settings.border = v end)
global("uf.borderColor", { type = "select", default = "look", choices = Styles.BORDER_COLORS,
  choiceLabels = labels({ black = "Black", class = "Class colour", accent = "Accent", gold = "Gold" }),
  label = "Border colour", tooltip = "Colour of the frame border.", mode = "advanced" }, function(v) settings.borderColor = v end)
global("uf.background", { type = "select", default = "look", choices = Styles.BACKGROUNDS,
  choiceLabels = labels({ solid = "Solid", translucent = "See-through", clear = "None" }),
  label = "Background", tooltip = "Background behind the bars.", mode = "advanced" }, function(v) settings.background = v end)
global("uf.powerStyle", { type = "select", default = "look", choices = Styles.POWER,
  choiceLabels = labels({ attached = "Under health", inset = "Inside health", floating = "Below the frame" }),
  label = "Power bar placement", tooltip = "Where the power bar sits.", mode = "advanced" }, function(v) settings.powerStyle = v end)
global("uf.portraitShape", { type = "select", default = "look", choices = Styles.SHAPES,
  choiceLabels = labels({ square = "Square", circle = "Round" }),
  label = "Portrait shape", tooltip = "Square or round portraits.", mode = "advanced" }, function(v) settings.portraitShape = v end)
global("uf.edge", { type = "select", default = "look", choices = { "look", "on", "off" },
  choiceLabels = labels({ on = "On", off = "Off" }), label = "Accent line",
  tooltip = "A thin accent-coloured line under the health bar.", mode = "advanced" }, function(v) settings.edge = v end)
global("uf.colorMode", { type = "select", default = "look", choices = { "look", "class", "reaction", "gradient", "accent", "custom" },
  choiceLabels = labels({ class = "Class", reaction = "Reaction", gradient = "By health", accent = "Accent", custom = "Custom" }),
  label = "Health colour", tooltip = "Class colour (players), reaction colour, a red-to-green gradient by health, the accent colour or your own colour.",
  mode = "simple", overridable = true, searchTags = { "colour", "color", "health" } }, function(v) settings.colorMode = v end)
global("uf.healthColor", { type = "color", default = { r = 0.24, g = 0.86, b = 0.59 }, label = "Custom health colour",
  tooltip = "Used when Health colour is Custom.", mode = "advanced" }, function(v) settings.healthColor = v end)
global("uf.darkMode", { type = "toggle", default = false, label = "Dark mode",
  tooltip = "Dark health fill with the class colour behind it.", mode = "advanced", searchTags = { "dark", "inverted" } },
  function(v) settings.darkMode = v end)
global("uf.smooth", { type = "toggle", default = false, label = "Smooth bars",
  tooltip = "Health and power bars glide to new values instead of jumping.", mode = "advanced" }, function(v) settings.smooth = v end)
global("uf.absorbs", { type = "toggle", default = true, label = "Show absorbs",
  tooltip = "Shows damage absorbs after the health fill and heal absorbs on it.", mode = "advanced" }, function(v) settings.absorbs = v end)
global("uf.healPrediction", { type = "toggle", default = false, label = "Show incoming heals",
  tooltip = "Shows predicted incoming heals after the health fill.", mode = "advanced" }, function(v) settings.healPrediction = v end)
global("uf.fillAlpha", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = "Health fill opacity",
  tooltip = "Opacity of the health fill.", mode = "advanced" }, function(v) settings.fillAlpha = v end)
global("uf.threat", { type = "toggle", default = true, label = "Threat glow",
  tooltip = "A coloured glow around player, target, focus and boss frames when you have threat.", mode = "advanced",
  searchTags = { "aggro", "tank" } }, function(v) settings.threat = v end)
global("uf.rangeFade", { type = "toggle", default = true, label = "Fade out of range",
  tooltip = "Fades target, focus and boss frames that are out of range (when the game can tell).", mode = "simple",
  overridable = true, searchTags = { "range", "distance" } }, function(v) settings.rangeFade = v end)
global("uf.rangeAlpha", { type = "range", default = 0.45, min = 0, max = 1, step = 0.05, label = "Out of range opacity",
  tooltip = "Opacity of a frame whose unit is out of range.", mode = "advanced", overridable = true }, function(v) settings.rangeAlpha = v end)
local function fontChoices()
  local out = { "global" }
  for _, n in ipairs(PUI.Media.fontOrder or {}) do out[#out + 1] = n end
  return out
end
global("uf.font", { type = "select", default = "global", choices = fontChoices, preview = "font",
  choiceLabels = { global = "Theme number font" }, label = "Text font",
  tooltip = "Font of unit-frame text. Theme number font follows Theme & Media.", mode = "advanced" }, function(v) settings.font = v end)
global("uf.fontSize", { type = "range", default = 12, min = 8, max = 24, step = 1, label = "Text size",
  tooltip = "Size of unit-frame text.", mode = "simple" }, function(v) settings.fontSize = v end)
global("uf.fontOutline", { type = "select", default = "shadow", choices = { "none", "shadow", "outline", "thick" },
  choiceLabels = { none = "None", shadow = "Shadow", outline = "Outline", thick = "Thick outline" }, label = "Text outline",
  tooltip = "Outline or shadow behind unit-frame text.", mode = "advanced" }, function(v) settings.fontOutline = v end)
global("uf.cast.fade", { type = "range", default = 0.35, min = 0, max = 1.5, step = 0.05, label = "Cast bar fade-out",
  tooltip = "Seconds a finished or interrupted cast bar takes to fade.", mode = "advanced" }, function(v) settings.castFade = v end)
local CAST_LABELS = { cast = "Casting", channel = "Channelling", empower = "Empowering", locked = "Can't interrupt",
  failed = "Interrupted / failed", done = "Finished" }
for _, k in ipairs({ "cast", "channel", "empower", "locked", "failed", "done" }) do
  global("uf.cast.color." .. k, { type = "color", default = PUI.Schema.Copy(CAST_COLORS[k]), label = "Cast bar colour: " .. CAST_LABELS[k]:lower(),
    tooltip = "Cast bar colour while " .. CAST_LABELS[k]:lower() .. ".", mode = "advanced", searchTags = { "castbar", "interrupt", "kick" } },
    function(v) settings.castColors[k] = v end)
end
for _, name in ipairs({ "raidMarker", "leader", "combat", "resting", "classification", "pvp" }) do
  local names = { raidMarker = "raid markers", leader = "group leader", combat = "in combat", resting = "resting (player)",
    classification = "elite / rare", pvp = "PvP flag" }
  global("uf.indicator." .. name, { type = "toggle", default = settings.indicators[name], label = "Indicator: " .. names[name],
    tooltip = "Shows the " .. names[name] .. " icon on unit frames.", mode = "advanced" }, function(v) settings.indicators[name] = v end)
end

local function groupKey(g, key, def, set, refresh)
  def.owner = OWNER
  def.apply = function(value)
    set(cfg[g], value)
    if refresh == "source" then UF.ApplySource(g)
    elseif refresh == "visibility" then UF.WatchVisibility(g)
    elseif refresh == "host" then UF.HostResources()
    else UF.Refresh(g) end
  end
  schema["uf." .. g .. "." .. key] = def
end
UF.groupKey = groupKey

for _, g in ipairs(ORDER) do
  local d, label = GROUPS[g], GROUPS[g].label
  local main = (g == "player" or g == "target")
  local simple = main and "simple" or "advanced"
  local lower = label:lower()
  groupKey(g, "source", { type = "select", default = "phoenix", choices = SOURCES, choiceLabels = SOURCE_LABELS, label = label .. " frame",
    tooltip = "Phoenix draws this frame, Blizzard shows the default frame, or hidden shows neither.", mode = "simple" },
    function(c, v) c.source = v end, "source")
  groupKey(g, "width", { type = "range", default = d.w, min = 60, max = 400, step = 1, label = label .. " width",
    tooltip = "Width of the " .. lower .. " frame in pixels.", mode = simple, overridable = true }, function(c, v) c.width = v end)
  groupKey(g, "height", { type = "range", default = d.h, min = 12, max = 120, step = 1, label = label .. " height",
    tooltip = "Height of the " .. lower .. " frame in pixels.", mode = simple, overridable = true }, function(c, v) c.height = v end)
  groupKey(g, "powerHeight", { type = "range", default = d.p, min = 0, max = 30, step = 1, label = label .. " power bar height",
    tooltip = "Height of the power bar; 0 hides it.", mode = "advanced", overridable = true }, function(c, v) c.powerHeight = v end)
  groupKey(g, "reverse", { type = "toggle", default = d.reverse, label = label .. " fill right to left",
    tooltip = "Bars fill from the right.", mode = "advanced" }, function(c, v) c.reverse = v end)
  groupKey(g, "vertical", { type = "toggle", default = false, label = label .. " fill bottom to top",
    tooltip = "Health fills upwards instead of sideways.", mode = "advanced" }, function(c, v) c.vertical = v end)
  groupKey(g, "texture", { type = "select", default = "global", choices = function()
      local out = { "global" }
      for _, n in ipairs(PUI.Media:List("statusbar")) do out[#out + 1] = n end
      return out
    end, choiceLabels = { global = "Theme bar texture" }, preview = "statusbar", label = label .. " bar texture",
    tooltip = "Bar texture for this frame; Theme bar texture follows Theme & Media.", mode = "advanced" }, function(c, v) c.texture = v end)
  groupKey(g, "portrait", { type = "select", default = d.portrait, choices = Styles.PORTRAITS,
    choiceLabels = { look = "From the look", off = "Off", ["2d"] = "2D", ["3d"] = "3D", class = "Class icon" },
    label = label .. " portrait", tooltip = "Portrait beside the frame: from the look, off, 2D, 3D or a class icon.",
    mode = simple, overridable = true }, function(c, v) c.portrait = v end)
  groupKey(g, "portraitSide", { type = "select", default = d.side, choices = { "left", "right" },
    choiceLabels = { left = "Left", right = "Right" }, label = label .. " portrait side",
    tooltip = "Which side of the frame the portrait sits on.", mode = "advanced" }, function(c, v) c.portraitSide = v end)
  for i, zone in ipairs(E.ZONES) do
    groupKey(g, "text." .. zone, { type = "select", default = d.texts[i], choices = Tags.order, choiceLabels = Tags.LABELS,
      label = label .. " text (" .. zone .. ")", tooltip = "What the " .. zone .. " text zone shows.", mode = "advanced",
      overridable = true }, function(c, v) c.texts[zone] = v end)
  end
  groupKey(g, "visibility", { type = "visibility", default = { mode = "always" }, label = label .. ": where to show",
    tooltip = "Show the " .. lower .. " frame everywhere, never, or only in the content, combat state and group you pick. The line below explains why it is hidden right now.",
    mode = simple, overridable = true, watchId = "uf." .. g, searchTags = { "visibility", "fade", "combat", "hide" } },
    function(c, v) c.visibility = v end, "visibility")
  groupKey(g, "hiddenAlpha", { type = "range", default = 0, min = 0, max = 1, step = 0.05, label = label .. " opacity when hidden",
    tooltip = "Opacity used when the where-to-show rule hides the frame (0 = invisible, higher = faded).", mode = "advanced",
    overridable = true }, function(c, v) c.hiddenAlpha = v end, "visibility")
  if not E.NO_CAST[g] then
    groupKey(g, "castbar", { type = "toggle", default = d.cast, label = label .. " cast bar",
      tooltip = "Shows a cast bar for this frame.", mode = simple, overridable = true }, function(c, v) c.castbar = v end)
    groupKey(g, "castHeight", { type = "range", default = 16, min = 6, max = 40, step = 1, label = label .. " cast bar height",
      tooltip = "Height of the cast bar.", mode = "advanced", overridable = true }, function(c, v) c.castHeight = v end)
    groupKey(g, "castWidth", { type = "range", default = 0, min = 0, max = 400, step = 1, label = label .. " cast bar width",
      tooltip = "Width of the cast bar; 0 matches the frame.", mode = "advanced" }, function(c, v) c.castWidth = v end)
    groupKey(g, "castPosition", { type = "select", default = "below", choices = { "below", "above" },
      choiceLabels = { below = "Below", above = "Above" }, label = label .. " cast bar position",
      tooltip = "Cast bar under or over the frame.", mode = "advanced" }, function(c, v) c.castPosition = v end)
    groupKey(g, "castIcon", { type = "toggle", default = true, label = label .. " cast icon",
      tooltip = "Spell icon beside the cast bar.", mode = "advanced" }, function(c, v) c.castIcon = v end)
    groupKey(g, "castName", { type = "toggle", default = true, label = label .. " cast spell name",
      tooltip = "Spell name on the cast bar.", mode = "advanced" }, function(c, v) c.castName = v end)
    groupKey(g, "castTimer", { type = "toggle", default = true, label = label .. " cast time",
      tooltip = "Time left on the cast bar.", mode = "advanced" }, function(c, v) c.castTimer = v end)
    groupKey(g, "castShield", { type = "toggle", default = true, label = label .. " can't-interrupt shade",
      tooltip = "Greys the bar while the cast can't be interrupted.", mode = "advanced" }, function(c, v) c.castShield = v end)
    groupKey(g, "castKick", { type = "toggle", default = g == "target" or g == "focus", label = label .. " your interrupt",
      tooltip = "Shows your interrupt and its cooldown beside the cast bar.", mode = "advanced",
      searchTags = { "kick", "interrupt" } }, function(c, v) c.castKick = v end)
  end
  for _, kind in ipairs(A.KINDS) do
    local K = kind == "buffs" and "Buffs" or "Debuffs"
    local a = cfg[g].auras[kind]
    local base = "auras." .. kind .. "."
    groupKey(g, base .. "enabled", { type = "toggle", default = a.enabled, label = label .. " " .. kind,
      tooltip = "Shows " .. kind .. " on the " .. lower .. " frame.", mode = simple, overridable = true },
      function(c, v) c.auras[kind].enabled = v end)
    groupKey(g, base .. "max", { type = "range", default = a.max, min = 1, max = 40, step = 1, label = label .. " " .. kind .. " shown",
      tooltip = "Largest number of " .. kind .. " shown.", mode = "advanced", overridable = true }, function(c, v) c.auras[kind].max = v end)
    groupKey(g, base .. "size", { type = "range", default = a.size, min = 10, max = 60, step = 1, label = label .. " " .. kind .. " size",
      tooltip = "Icon size.", mode = "advanced", overridable = true }, function(c, v) c.auras[kind].size = v end)
    groupKey(g, base .. "perRow", { type = "range", default = a.perRow, min = 1, max = 20, step = 1, label = label .. " " .. kind .. " per row",
      tooltip = "Icons per row.", mode = "advanced" }, function(c, v) c.auras[kind].perRow = v end)
    groupKey(g, base .. "position", { type = "select", default = a.position, choices = A.POSITIONS,
      choiceLabels = { below = "Below", above = "Above", left = "Left", right = "Right" }, label = label .. " " .. kind .. " position",
      tooltip = "Side of the frame the icons sit on.", mode = "advanced" }, function(c, v) c.auras[kind].position = v end)
    groupKey(g, base .. "filter", { type = "select", default = a.filter, choices = A.FILTERS[kind], choiceLabels = A.FILTER_LABELS,
      label = label .. " " .. kind .. " shown", tooltip = K .. " to show.", mode = "advanced", overridable = true },
      function(c, v) c.auras[kind].filter = v end)
    groupKey(g, base .. "sort", { type = "select", default = a.sort, choices = PUI.Auras.SORTS,
      choiceLabels = { default = "Blizzard order", expiration = "Time left", name = "Name", bigDefensive = "Defensives first",
        unitFrameDebuff = "Debuff priority", important = "Important first" }, label = label .. " " .. kind .. " order",
      tooltip = "How icons are ordered.", mode = "advanced" }, function(c, v) c.auras[kind].sort = v end)
  end
end

-- Group-only extras.
groupKey("boss", "growth", { type = "select", default = "down", choices = { "down", "up" },
  choiceLabels = { down = "Downwards", up = "Upwards" }, label = "Boss frames stack",
  tooltip = "Which way boss frames 2 to 5 are added.", mode = "advanced" }, function(c, v) c.growth = v end)
groupKey("boss", "spacing", { type = "range", default = 12, min = 0, max = 60, step = 1, label = "Boss frame spacing",
  tooltip = "Gap between boss frames.", mode = "advanced", overridable = true }, function(c, v) c.spacing = v end)
groupKey("player", "resources", { type = "select", default = "attach", choices = { "attach", "separate" },
  choiceLabels = { attach = "Attach here", separate = "Keep separate" }, label = "Class resource and cast bar",
  tooltip = "Resource Bars' class resource, power and your cast bar sit under the player frame, or stay where you placed them in Studio. Turn the bars on in Resource Bars.",
  mode = "simple", searchTags = { "combo", "holy power", "runes", "castbar", "resource" } }, function(c, v) c.resources = v end, "host")
groupKey("player", "resourcesGap", { type = "range", default = 3, min = 0, max = 40, step = 1, label = "Gap to resource bars",
  tooltip = "Space between the player frame and the attached resource bars.", mode = "advanced" },
  function(c, v) c.resourcesGap = v end, "host")

for _, g in ipairs(ORDER) do
  local d = GROUPS[g]
  Layout:RegisterElement("uf." .. g, { label = d.label .. " frame", owner = OWNER, size = { d.w, d.h },
    default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end
for k, def in pairs(ns.AuraBars and ns.AuraBars.schema or {}) do schema[k] = def end

-- Settings registered after Phoenix_UI's ApplyAll: read stored values now so the
-- resolved tables match the profile before the module first enables.
local function syncFromDB()
  for key, def in pairs(schema) do def.apply(Schema:Get(key)) end
end

UF.module = PUI:RegisterModule(OWNER, {
  label = "Unit frames",
  tooltip = "Phoenix player, target, focus, pet, target-of-target, focus-target and boss frames, and your buff and debuff rows.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
UF.SyncFromDB = syncFromDB

PUI.Slash:Register("uftest", function()
  local want = not UF.test
  local ok, why = UF.SetTestMode(want)
  if not ok then PUI.Slash.Print("Unit frame test frames: " .. tostring(why)) return end
  PUI.Slash.Print("Unit frame test frames " .. (want and "on" or "off") .. ".")
end, "toggle unit frame test frames (all boss frames with sample data)")
