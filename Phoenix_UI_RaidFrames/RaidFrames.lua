local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Raid and Party Frames module (PUI_V2 5.4, plan 5.2 / 13.3 / 15.3, mockup 03).
-- Two SecureGroupHeaderTemplate headers: party, and one raid header that shows
-- groups as columns (or rows). Layout comes from a size tier picked by group
-- size (party / up to 10 / up to 20 / up to 40, each its own size, spacing,
-- growth and units per column) or a fixed tier. Children are spawned out of
-- combat when the module turns on, sized by a restricted initialConfigFunction
-- and handed to Lua through a CallMethod. One tracker routes unit events to
-- every button showing that unit and registers only the channels the settings
-- need. Range uses PUI.Range, auras PUI.Auras, enemy target dots
-- PUI.Targeting (shared with Arena), heal prediction PUI.Prediction, "where to
-- show" PUI.Visibility. Every protected change goes through the CombatQueue.
-- Off by default.
local _, ns = ...
local Schema, Layout, CQ, Kernel = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Kernel
local E, I = ns.Elements, ns.Indicators
local OWNER = "RaidFrames"

local RF = { active = false, test = false, inCombat = false, headers = {}, buttons = {}, byUnit = {}, parked = {},
  byButton = setmetatable({}, { __mode = "k" }), corners = {}, testFrames = {}, tier = "medium" }
ns.RF = RF
PUI.RaidFrames = RF
RF.Elements, RF.Indicators = E, I

local TIERS = { "party", "small", "medium", "large" }
local TIER_LABELS = { party = "Party (5)", small = "Raid up to 10", medium = "Raid up to 20", large = "Raid up to 40" }
local TIER_DEFAULTS = {
  party = { width = 110, height = 48 }, small = { width = 100, height = 44 },
  medium = { width = 90, height = 40 }, large = { width = 72, height = 34 },
}
RF.TIERS, RF.TIER_LABELS = TIERS, TIER_LABELS

local function tierTable(d)
  return { width = d.width, height = d.height, orientation = "vertical", spacing = 2, groupSpacing = 6, perColumn = 5,
    growUp = false, growLeft = false }
end
local s = {
  autoTier = true, tier = "medium", tiers = {},
  sort = "group", roleOrder = "TANK,HEALER,DAMAGER", partySort = "index", mythicCap = true, showPlayer = true, showSolo = false,
  colorMode = "class", healthColor = { r = 0.24, g = 0.86, b = 0.59 }, healthText = "none", nameColor = "class",
  namePosition = "center", roleStyle = "icon", roleHideCombat = false, roleHideDamager = false,
  leader = true, raidMarker = true, statusIcons = true, rangeFade = true, rangeAlpha = 0.4, aggro = true,
  dispel = true, dispelSource = "mine", dispelStyle = "border", dispelTypeColors = true,
  dispelColor = { r = 0.96, g = 0.77, b = 0.42 }, dispelTintAlpha = 0.3,
  heals = true, absorbs = true, healAbsorbs = true, overflow = true, healerMana = true, manaHeight = 4,
  auras = {
    debuffs = { enabled = true, max = 3, size = 16, point = "BOTTOMLEFT", filter = "raid" },
    buffs = { enabled = true, max = 3, size = 14, point = "BOTTOMRIGHT", filter = "mine" },
    defensive = { enabled = true, max = 1, size = 18, point = "CENTER", filter = "bigExternal" },
  },
  lockouts = true, cornerList = {}, cornerSize = 7,
  privateAuras = 2, privateSize = 0, privatePoint = "RIGHT", privateNumbers = false, privateDispel = true,
  targetDots = true, targetDotsBoss = false, dotSize = 6,
  visibility = { party = { mode = "always" }, raid = { mode = "always" } }, hiddenAlpha = 0,
  hideBlizzard = true,
}
for _, t in ipairs(TIERS) do s.tiers[t] = tierTable(TIER_DEFAULTS[t]) end
RF.settings = s

local SORTS = {
  group = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8", sortMethod = "INDEX" },
  role = { groupBy = "ASSIGNEDROLE", sortMethod = "INDEX" },
  class = { groupBy = "CLASS", groupingOrder = "WARRIOR,DEATHKNIGHT,PALADIN,MONK,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,DEMONHUNTER,EVOKER", sortMethod = "INDEX" },
  name = { sortMethod = "NAME" },
}
RF.SORTS = SORTS
RF.ROLE_ORDERS = { "TANK,HEALER,DAMAGER", "HEALER,TANK,DAMAGER", "TANK,DAMAGER,HEALER", "DAMAGER,HEALER,TANK" }
local KINDS = {
  party = { max = 5, visibility = function() return s.showSolo and "[group:raid] hide; show" or "[group:raid] hide; [group:party] show; hide" end,
    pos = { "TOPLEFT", 27, -213 } },
  raid = { max = 40, visibility = function() return "[group:raid] show; hide" end, pos = { "TOPLEFT", 27, -213 } },
}
RF.KINDS = KINDS

-- Restricted: size each child from header attributes, set default clicks, hand
-- the child to Lua for its unprotected elements.
local INIT = [[
  local header = self:GetParent()
  self:SetWidth(header:GetAttribute("phx-width"))
  self:SetHeight(header:GetAttribute("phx-height"))
  self:SetAttribute("*type1", "target")
  self:SetAttribute("*type2", "togglemenu")
  header:CallMethod("PhoenixInit", self:GetName())
]]
RF.INIT = INIT

-- Size tier ------------------------------------------------------------------
function RF.TierFor(count)
  if count <= 10 then return "small" elseif count <= 20 then return "medium" end
  return "large"
end
function RF.CurrentTier()
  if not s.autoTier then return s.tier end
  return RF.TierFor(GetNumGroupMembers() or 0)
end
local function kindTier(kind) return kind == "party" and "party" or RF.tier end
RF.KindTier = kindTier

-- Mythic raids hold 20 players (groups 1-4); benched groups 5-8 are left out.
function RF.GroupFilter()
  if s.mythicCap then
    local _, _, difficulty = GetInstanceInfo()
    if difficulty == 16 then return "1,2,3,4" end
  end
  return "1,2,3,4,5,6,7,8"
end

-- Channels -> events; each channel is on only when a setting needs it.
local CHANNELS = {
  base = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" },
  power = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" },
  prediction = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION" },
  threat = { "UNIT_THREAT_SITUATION_UPDATE" },
  aura = { "UNIT_AURA" },
  status = { "UNIT_PHASE", "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED" },
}
RF.CHANNELS = CHANNELS
local HANDLERS = {
  UNIT_HEALTH = E.UpdateHealth, UNIT_MAXHEALTH = E.UpdateHealth, UNIT_CONNECTION = E.UpdateStatus,
  UNIT_FLAGS = E.UpdateStatus, UNIT_NAME_UPDATE = E.UpdateName,
  UNIT_POWER_UPDATE = E.UpdatePower, UNIT_MAXPOWER = E.UpdatePower, UNIT_DISPLAYPOWER = E.UpdateRole,
  UNIT_ABSORB_AMOUNT_CHANGED = E.UpdatePrediction, UNIT_HEAL_ABSORB_AMOUNT_CHANGED = E.UpdatePrediction,
  UNIT_HEAL_PREDICTION = E.UpdatePrediction, UNIT_THREAT_SITUATION_UPDATE = E.UpdateThreat,
  UNIT_AURA = function(o) E.UpdateDispel(o, s); I.UpdateCorners(o, s) end,
  UNIT_PHASE = E.UpdateCenter, INCOMING_RESURRECT_CHANGED = E.UpdateCenter, INCOMING_SUMMON_CHANGED = E.UpdateCenter,
}
RF.HANDLERS = HANDLERS

function RF.Channels()
  local c = { base = true }
  if s.healerMana then c.power = true end
  if s.absorbs or s.heals or s.healAbsorbs then c.prediction = true end
  if s.aggro then c.threat = true end
  if s.dispel or #RF.corners > 0 then c.aura = true end
  if s.statusIcons then c.status = true end
  return c
end

local tracker
local function onUnitEvent(_, event, unit)
  if RF.test then return end
  local list = type(unit) == "string" and RF.byUnit[unit]
  if not list then return end
  local fn = HANDLERS[event]
  for o in pairs(list) do fn(o, s) end
end

function RF.Track()
  if not tracker then return end
  tracker:UnregisterAllEvents()
  if not RF.active then return end
  for channel in pairs(RF.Channels()) do
    for _, ev in ipairs(CHANNELS[channel]) do tracker:RegisterEvent(ev) end
  end
end

-- Range (PUI.Range, refcounted, one poll for every unit) -----------------------
function RF.Range(o)
  local want = RF.active and s.rangeFade and o.unit ~= nil and o.unit ~= "player" and not RF.test
  if o.range and (not want or o.range.unit ~= o.unit) then
    PUI.Range:Release(o.range)
    o.range = nil
    o.content:SetAlpha(1)
  end
  if want and not o.range then
    o.range = PUI.Range:Acquire(OWNER, o.unit, function(inRange, checked) E.ApplyRange(o, s, inRange, checked) end)
  end
end

-- Buttons -----------------------------------------------------------------------
local function refreshButton(o)
  if not (RF.active and o.unit) then return end
  E.UpdateAll(o, s)
  I.SetupAuras(o, s)
  I.LayoutCorners(o, s)
  I.UpdateCorners(o, s)
  I.PaintDots(o, s)
  RF.Range(o)
end

local function setUnit(o, unit)
  if o.unit and RF.byUnit[o.unit] then
    RF.byUnit[o.unit][o] = nil
    if next(RF.byUnit[o.unit]) == nil then RF.byUnit[o.unit] = nil end
  end
  o.unit = type(unit) == "string" and unit or nil
  if o.unit then
    RF.byUnit[o.unit] = RF.byUnit[o.unit] or {}
    RF.byUnit[o.unit][o] = true
    refreshButton(o)
  elseif o.auras then
    I.OffAuras(o)
  end
  RF.Range(o)
  if RF.active then I.UpdatePrivate(o, s) end
end
RF.SetUnit = setUnit

local function onAttributeChanged(button, name, value)
  if name == "unit" and RF.byButton[button] then setUnit(RF.byButton[button], value) end
end

function RF.InitButton(button)
  if not button or RF.byButton[button] then return end
  local kind = (RF.headers.raid and button:GetParent() == RF.headers.raid) and "raid" or "party"
  local t = s.tiers[kindTier(kind)]
  local o = { button = button, kind = kind, width = t.width, height = t.height }
  RF.byButton[button] = o
  button:RegisterForClicks("AnyUp")
  button:HookScript("OnAttributeChanged", onAttributeChanged)
  button:HookScript("OnEnter", function(self)
    if not o.unit then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(o.unit)
    GameTooltip:Show()
  end)
  button:HookScript("OnLeave", function() GameTooltip:Hide() end)
  E.Build(o)
  RF.buttons[#RF.buttons + 1] = o
  local clickCast = rawget(_G, "ClickCastFrames")
  if clickCast == nil then
    clickCast = {}
    _G.ClickCastFrames = clickCast
  end
  clickCast[button] = true
  Kernel:Fire("CLICKCAST_FRAME", button)
  local unit = button:GetAttribute("unit")
  if unit then setUnit(o, unit) end
end

-- Header attributes from the kind's tier, growth and sort settings.
local function applyAttributes(h, kind)
  local t = s.tiers[kindTier(kind)]
  local vertical = t.orientation == "vertical"
  h:SetAttribute("phx-width", t.width)
  h:SetAttribute("phx-height", t.height)
  if vertical then
    h:SetAttribute("point", t.growUp and "BOTTOM" or "TOP")
    h:SetAttribute("xOffset", 0)
    h:SetAttribute("yOffset", t.growUp and t.spacing or -t.spacing)
    h:SetAttribute("columnAnchorPoint", t.growLeft and "RIGHT" or "LEFT")
  else
    h:SetAttribute("point", t.growLeft and "RIGHT" or "LEFT")
    h:SetAttribute("xOffset", t.growLeft and -t.spacing or t.spacing)
    h:SetAttribute("yOffset", 0)
    h:SetAttribute("columnAnchorPoint", t.growUp and "BOTTOM" or "TOP")
  end
  h:SetAttribute("columnSpacing", t.groupSpacing)
  h:SetAttribute("unitsPerColumn", t.perColumn)
  h:SetAttribute("maxColumns", math.ceil(KINDS[kind].max / t.perColumn))
  if kind == "party" then
    h:SetAttribute("showParty", true)
    h:SetAttribute("showPlayer", s.showPlayer)
    h:SetAttribute("showSolo", s.showSolo)
    if s.partySort == "role" then
      h:SetAttribute("groupBy", "ASSIGNEDROLE")
      h:SetAttribute("groupingOrder", s.roleOrder .. ",NONE")
      h:SetAttribute("sortMethod", "INDEX")
    else
      h:SetAttribute("groupBy", nil)
      h:SetAttribute("groupingOrder", nil)
      h:SetAttribute("sortMethod", s.partySort == "name" and "NAME" or "INDEX")
    end
  else
    h:SetAttribute("showRaid", true)
    local sort = SORTS[s.sort]
    h:SetAttribute("groupFilter", RF.GroupFilter())
    h:SetAttribute("groupBy", sort.groupBy)
    h:SetAttribute("groupingOrder", s.sort == "role" and (s.roleOrder .. ",NONE") or sort.groupingOrder)
    h:SetAttribute("sortMethod", sort.sortMethod)
  end
end
RF.ApplyAttributes = applyAttributes

local function buildHeader(kind)
  local h = PUI:CreateFrame("Frame", "PhoenixUI_RF_" .. kind, UIParent, "SecureGroupHeaderTemplate", OWNER)
  h.PhoenixInit = function(_, childName) RF.InitButton(_G[childName]) end
  h:SetAttribute("template", "SecureUnitButtonTemplate,PingableUnitFrameTemplate")
  h:SetAttribute("initialConfigFunction", INIT)
  applyAttributes(h, kind)
  RF.headers[kind] = h
  return h
end

-- Spawns every child now (out of combat): show the header with startingIndex
-- pulled back so all slots are created, then restore it.
local function spawnChildren(h, kind)
  local max = KINDS[kind].max
  h:SetAttribute("startingIndex", -max + 1)
  h:Show()
  h:SetAttribute("startingIndex", 1)
end

-- Resizes existing children to their kind's tier (protected; out of combat).
local function resize()
  for _, o in ipairs(RF.buttons) do
    local t = s.tiers[kindTier(o.kind)]
    o.button:SetSize(t.width, t.height)
    E.Layout(o, s, t.width, t.height)
    if o.unit then I.SetupAuras(o, s); I.LayoutCorners(o, s); I.UpdatePrivate(o, s) end
  end
end

function RF.ApplyLayout()
  if not RF.active then return end
  CQ.Defer("rf.layout", function()
    if not RF.active then return end
    RF.tier = RF.CurrentTier()
    for kind, h in pairs(RF.headers) do
      applyAttributes(h, kind)
      RegisterStateDriver(h, "visibility", KINDS[kind].visibility())
      Layout:Place(h, "rf." .. kind)
    end
    resize()
    if RF.test then RF.BuildTest() end
  end)
end

-- Roster changes may cross a tier boundary: re-layout only then.
local function onRoster()
  local tier = RF.CurrentTier()
  if tier ~= RF.tier then RF.ApplyLayout() end
  RF.RefreshAll()
end
RF.OnRoster = onRoster

function RF.RefreshAll()
  if not RF.active or RF.test then return end
  for _, o in ipairs(RF.buttons) do refreshButton(o) end
end

function RF.RefreshPrivate()
  if not RF.active then return end
  for _, o in ipairs(RF.buttons) do I.UpdatePrivate(o, s) end
end

-- "Where to show" (PUI.Visibility): header alpha only, so it is combat-safe.
local function headerAlpha(kind)
  if RF.test then return 0 end
  local shown = RF.shown and RF.shown[kind]
  if shown == false then return s.hiddenAlpha end
  return 1
end
function RF.WatchVisibility()
  RF.shown = RF.shown or {}
  for kind in pairs(KINDS) do
    local id = "rf." .. kind
    if RF.active then
      PUI.Visibility:Watch(id, s.visibility[kind], function(shown)
        RF.shown[kind] = shown
        local h = RF.headers[kind]
        if h then h:SetAlpha(headerAlpha(kind)) end
      end)
    else
      PUI.Visibility:Unwatch(id)
    end
  end
end

-- Enemy target dots (PUI.Targeting, shared with Arena).
local function paintAllDots()
  for _, o in ipairs(RF.buttons) do if o.unit then I.PaintDots(o, s) end end
end
function RF.WatchTargeting()
  if RF.active and s.targetDots then PUI.Targeting:Subscribe("rf.dots", paintAllDots)
  else PUI.Targeting:Unsubscribe("rf.dots"); paintAllDots() end
end

-- Blizzard party / raid frames ---------------------------------------------------
local BLIZZARD = { "PartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }
RF.BLIZZARD = BLIZZARD
local hider
function RF.ParkBlizzard(park)
  CQ.Defer("rf.blizzard", function()
    for _, name in ipairs(BLIZZARD) do
      local frame = _G[name]
      if frame then
        if park and not RF.parked[name] then
          if not hider then
            hider = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
            hider:Hide()
            RF.hider = hider
          end
          RF.parked[name] = frame:GetParent() or UIParent
          frame:SetParent(hider)
        elseif not park and RF.parked[name] then
          frame:SetParent(RF.parked[name])
          RF.parked[name] = nil
        end
      end
    end
  end)
end

-- Test mode ----------------------------------------------------------------------
-- Plain (unsecured) frames with sample members laid out exactly like the live
-- headers for the chosen group size; the headers are faded out meanwhile.
-- Out of combat only; entering combat ends it.
local testHolder
local function testFrame(i)
  local o = RF.testFrames[i]
  if o then return o end
  o = { button = PUI:CreateFrame("Frame", nil, testHolder, nil, OWNER), test = true }
  E.Build(o)
  RF.testFrames[i] = o
  return o
end

function RF.TestPosition(i, t)
  local col, row = math.floor((i - 1) / t.perColumn), (i - 1) % t.perColumn
  local x, y
  if t.orientation == "vertical" then
    x, y = col * (t.width + t.groupSpacing), row * (t.height + t.spacing)
  else
    x, y = row * (t.width + t.spacing), col * (t.height + t.groupSpacing)
  end
  return (t.growLeft and -x or x), (t.growUp and y or -y)
end

function RF.BuildTest()
  local count = RF.testCount or 20
  local kind = count <= 5 and "party" or "raid"
  local tier = kind == "party" and "party" or (s.autoTier and RF.TierFor(count) or s.tier)
  local t = s.tiers[tier]
  testHolder = testHolder or PUI:CreateFrame("Frame", "PhoenixUI_RF_Test", UIParent, nil, OWNER)
  RF.testHolder = testHolder
  testHolder:ClearAllPoints()
  local anchor = RF.headers[kind]
  if anchor then testHolder:SetPoint(t.growUp and "BOTTOMLEFT" or "TOPLEFT", anchor, t.growUp and "BOTTOMLEFT" or "TOPLEFT")
  else testHolder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", KINDS[kind].pos[2], KINDS[kind].pos[3]) end
  testHolder:SetSize(1, 1)
  testHolder:Show()
  for i = 1, math.max(count, #RF.testFrames) do
    if i <= count then
      local o = testFrame(i)
      o.button:SetSize(t.width, t.height)
      o.button:ClearAllPoints()
      local x, y = RF.TestPosition(i, t)
      local p = (t.growUp and "BOTTOM" or "TOP") .. (t.growLeft and "RIGHT" or "LEFT")
      o.button:SetPoint(p, testHolder, p, x, y)
      E.Layout(o, s, t.width, t.height)
      E.PaintSample(o, s, i)
      o.button:Show()
    else
      RF.testFrames[i].button:Hide()
    end
  end
  RF.testTier = tier
end

function RF.SetTestMode(on, count)
  on = on == true
  if count then RF.testCount = math.max(1, math.min(40, count)) end
  if on and InCombatLockdown() then return false, "not in combat" end
  if on and not RF.active then return false, "turn Raid and party frames on first" end
  RF.test = on
  if on then
    RF.BuildTest()
  elseif testHolder then
    testHolder:Hide()
  end
  for kind, h in pairs(RF.headers) do h:SetAlpha(headerAlpha(kind)) end
  for _, o in ipairs(RF.buttons) do RF.Range(o) end
  if not on then RF.RefreshAll() end
  Kernel:Fire("RF_TEST_MODE", on)
  return true
end

-- Lifecycle ---------------------------------------------------------------------
local function allIndicators()
  if RF.test then return end
  for _, o in ipairs(RF.buttons) do if o.unit then E.UpdateIndicators(o, s) end end
end
local function allRoles()
  if RF.test then return end
  for _, o in ipairs(RF.buttons) do if o.unit then E.UpdateRole(o, s) end end
end

local function combatStart()
  RF.inCombat = true
  if RF.test then RF.SetTestMode(false) end
  if s.roleHideCombat then allRoles() end
  CQ.Defer("rf.combatEnd", function()
    RF.inCombat = false
    if s.roleHideCombat then allRoles() end
  end)
end

local function onEnable(mod)
  RF.active = true
  tracker = tracker or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  tracker:SetScript("OnEvent", onUnitEvent)
  RF.Track()
  CQ.Defer("rf.headers", function()
    if not RF.active then return end
    for kind in pairs(KINDS) do
      if not RF.headers[kind] then spawnChildren(buildHeader(kind), kind) end
    end
  end)
  RF.ApplyLayout()
  RF.ParkBlizzard(s.hideBlizzard)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", onRoster)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", function() RF.ApplyLayout(); RF.RefreshAll() end)
  mod:RegisterEvent("PLAYER_ROLES_ASSIGNED", allRoles)
  mod:RegisterEvent("PARTY_LEADER_CHANGED", allIndicators)
  mod:RegisterEvent("RAID_TARGET_UPDATE", allIndicators)
  mod:RegisterEvent("READY_CHECK", allIndicators)
  mod:RegisterEvent("READY_CHECK_CONFIRM", allIndicators)
  mod:RegisterEvent("READY_CHECK_FINISHED", function() C_Timer.After(6, allIndicators) end)
  mod:RegisterEvent("PLAYER_REGEN_DISABLED", combatStart)
  RF.WatchVisibility()
  RF.WatchTargeting()
  RF.RefreshAll()
end

local function onDisable()
  RF.active = false
  if RF.test then RF.SetTestMode(false) end
  if tracker then tracker:UnregisterAllEvents() end
  CQ.Defer("rf.layout", function()
    if RF.active then return end
    for _, h in pairs(RF.headers) do
      UnregisterStateDriver(h, "visibility")
      h:Hide()
    end
  end)
  for _, o in ipairs(RF.buttons) do
    I.ClearPrivate(o)
    if o.auras then I.OffAuras(o) end
    RF.Range(o)
  end
  RF.WatchVisibility()
  RF.WatchTargeting()
  RF.ParkBlizzard(false)
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
RF.schema = schema
local REFRESH = {
  layout = function() RF.ApplyLayout() end,
  blizzard = function(v) if RF.active then RF.ParkBlizzard(v) end end,
  private = function() RF.RefreshPrivate() end,
  visibility = function() if RF.active then RF.WatchVisibility() end end,
  dots = function() RF.WatchTargeting() end,
  corners = function()
    RF.corners = I.CompileCorners(s.cornerList)
    if RF.active then for _, o in ipairs(RF.buttons) do I.LayoutCorners(o, s) end end
  end,
}
local function key(name, def, set, refresh)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    if refresh then REFRESH[refresh](value) end
    RF.Track()
    RF.RefreshAll()
    if RF.test then RF.BuildTest() end
    Kernel:Fire("RF_SETTINGS")
  end
  schema["rf." .. name] = def
end
RF.key = key
local function choiceLabels(t) return t end

-- Size tiers and layout.
key("autoTier", { type = "toggle", default = true, label = "Pick the layout by group size",
  tooltip = "Uses the Party, Raid up to 10, Raid up to 20 or Raid up to 40 layout automatically as people join and leave. Turn off to always use one raid layout.",
  mode = "simple", overridable = true, searchTags = { "size", "tier", "5", "10", "20", "40" } },
  function(v) s.autoTier = v end, "layout")
key("tier", { type = "select", default = "medium", choices = { "small", "medium", "large" }, choiceLabels = TIER_LABELS,
  label = "Raid layout when not automatic", tooltip = "The raid layout used for every raid size when automatic picking is off.",
  mode = "advanced", overridable = true }, function(v) s.tier = v end, "layout")
for _, t in ipairs(TIERS) do
  local L, d = TIER_LABELS[t], s.tiers[t]
  local simple = (t == "party" or t == "medium") and "simple" or "advanced"
  key(t .. ".width", { type = "range", default = d.width, min = 40, max = 220, step = 1, label = L .. ": frame width",
    tooltip = "Width of each frame in this layout.", mode = simple, overridable = true, searchTags = { "size" } },
    function(v) s.tiers[t].width = v end, "layout")
  key(t .. ".height", { type = "range", default = d.height, min = 16, max = 110, step = 1, label = L .. ": frame height",
    tooltip = "Height of each frame in this layout.", mode = simple, overridable = true, searchTags = { "size" } },
    function(v) s.tiers[t].height = v end, "layout")
  key(t .. ".orientation", { type = "select", default = "vertical", choices = { "vertical", "horizontal" },
    choiceLabels = { vertical = "Groups as columns", horizontal = "Groups as rows" }, label = L .. ": arrangement",
    tooltip = "Members stack downwards with each group in its own column, or sideways with each group in its own row.",
    mode = simple, overridable = true }, function(v) s.tiers[t].orientation = v end, "layout")
  key(t .. ".spacing", { type = "range", default = 2, min = 0, max = 20, step = 1, label = L .. ": gap between frames",
    tooltip = "Space between members of one group.", mode = "advanced", overridable = true },
    function(v) s.tiers[t].spacing = v end, "layout")
  key(t .. ".groupSpacing", { type = "range", default = 6, min = 0, max = 40, step = 1, label = L .. ": gap between groups",
    tooltip = "Space between groups (columns or rows).", mode = "advanced", overridable = true },
    function(v) s.tiers[t].groupSpacing = v end, "layout")
  key(t .. ".perColumn", { type = "range", default = 5, min = 1, max = t == "party" and 5 or 40, step = 1,
    label = L .. ": members per column", tooltip = "How many frames before a new column (or row) starts. 5 keeps one group per column.",
    mode = "advanced", overridable = true }, function(v) s.tiers[t].perColumn = v end, "layout")
  key(t .. ".growUp", { type = "toggle", default = false, label = L .. ": grow upwards",
    tooltip = "New members are added above instead of below.", mode = "advanced", overridable = true },
    function(v) s.tiers[t].growUp = v end, "layout")
  key(t .. ".growLeft", { type = "toggle", default = false, label = L .. ": grow to the left",
    tooltip = "New columns are added to the left instead of the right.", mode = "advanced", overridable = true },
    function(v) s.tiers[t].growLeft = v end, "layout")
end

-- Sorting and who is shown.
key("sort", { type = "select", default = "group", choices = { "group", "role", "class", "name" },
  choiceLabels = { group = "By group", role = "By role", class = "By class", name = "By name" }, label = "Raid sorting",
  tooltip = "Order raid frames by group, by role (in the role order below), by class or by name.", mode = "simple",
  overridable = true }, function(v) s.sort = v end, "layout")
key("roleOrder", { type = "select", default = "TANK,HEALER,DAMAGER", choices = RF.ROLE_ORDERS,
  choiceLabels = { ["TANK,HEALER,DAMAGER"] = "Tanks, healers, damage", ["HEALER,TANK,DAMAGER"] = "Healers, tanks, damage",
    ["TANK,DAMAGER,HEALER"] = "Tanks, damage, healers", ["DAMAGER,HEALER,TANK"] = "Damage, healers, tanks" },
  label = "Role order", tooltip = "Order used when sorting by role (raid and party).", mode = "advanced", overridable = true },
  function(v) s.roleOrder = v end, "layout")
key("partySort", { type = "select", default = "index", choices = { "index", "role", "name" },
  choiceLabels = { index = "Party order", role = "By role", name = "By name" }, label = "Party sorting",
  tooltip = "Order of the party frames.", mode = "simple", overridable = true }, function(v) s.partySort = v end, "layout")
key("mythicCap", { type = "toggle", default = true, label = "Mythic raids: groups 1 to 4 only",
  tooltip = "In Mythic raids only the 20 players in groups 1 to 4 are shown; benched players in groups 5 to 8 are left out.",
  mode = "advanced" }, function(v) s.mythicCap = v end, "layout")
key("showPlayer", { type = "toggle", default = true, label = "Show yourself in party",
  tooltip = "Includes your own frame in the party frames.", mode = "simple" }, function(v) s.showPlayer = v end, "layout")
key("showSolo", { type = "toggle", default = false, label = "Show party frames when solo",
  tooltip = "Shows your frame even when you are not in a group.", mode = "advanced" }, function(v) s.showSolo = v end, "layout")

-- Health, name, text.
key("colorMode", { type = "select", default = "class", choices = { "class", "gradient", "accent", "custom" },
  choiceLabels = { class = "Class", gradient = "By health", accent = "Accent", custom = "Custom" }, label = "Group health colour",
  tooltip = "Class colour, a red-to-green gradient by health, the accent colour or your own colour.", mode = "simple",
  overridable = true }, function(v) s.colorMode = v end)
key("healthColor", { type = "color", default = { r = 0.24, g = 0.86, b = 0.59 }, label = "Custom group health colour",
  tooltip = "Used when Group health colour is Custom.", mode = "advanced" }, function(v) s.healthColor = v end)
key("healthText", { type = "select", default = "none", choices = { "none", "percent", "deficit", "current" },
  choiceLabels = { none = "None", percent = "Percent", deficit = "Missing health", current = "Current health" },
  label = "Group health text", tooltip = "Health percentage, missing health, current health or nothing (dead and offline always show).",
  mode = "advanced", overridable = true }, function(v) s.healthText = v end)
key("nameColor", { type = "select", default = "class", choices = { "class", "white" },
  choiceLabels = { class = "Class colour", white = "White" }, label = "Name colour", tooltip = "Colour of member names.",
  mode = "advanced" }, function(v) s.nameColor = v end)
key("namePosition", { type = "select", default = "center", choices = { "center", "top", "left" },
  choiceLabels = { center = "Centre", top = "Top", left = "Left" }, label = "Name position",
  tooltip = "Where the name sits on the frame.", mode = "advanced" }, function(v) s.namePosition = v end)

-- Icons.
key("roleStyle", { type = "select", default = "icon", choices = { "icon", "letter", "none" },
  choiceLabels = { icon = "Icon", letter = "Letter (T / H / D)", none = "Hidden" }, label = "Role icons",
  tooltip = "Tank, healer and damage markers as icons, coloured letters, or hidden.", mode = "simple" },
  function(v) s.roleStyle = v end)
key("roleHideCombat", { type = "toggle", default = false, label = "Hide role icons in combat",
  tooltip = "Role markers fade away while you are in combat.", mode = "advanced" }, function(v) s.roleHideCombat = v end)
key("roleHideDamager", { type = "toggle", default = false, label = "Hide the damage role icon",
  tooltip = "Only tanks and healers get a role marker.", mode = "advanced" }, function(v) s.roleHideDamager = v end)
key("leader", { type = "toggle", default = true, label = "Leader icon", tooltip = "Marks the group leader.", mode = "advanced" },
  function(v) s.leader = v end)
key("raidMarker", { type = "toggle", default = true, label = "Group raid markers", tooltip = "Raid target markers on group frames.",
  mode = "advanced" }, function(v) s.raidMarker = v end)
key("statusIcons", { type = "toggle", default = true, label = "Status icons",
  tooltip = "Ready check, incoming resurrection, pending summon and out-of-phase icons.", mode = "advanced" },
  function(v) s.statusIcons = v end)

-- Range and threat.
key("rangeFade", { type = "toggle", default = true, label = "Fade out of range",
  tooltip = "Fades frames of members out of your range.", mode = "simple", overridable = true }, function(v) s.rangeFade = v end)
key("rangeAlpha", { type = "range", default = 0.4, min = 0.1, max = 1, step = 0.05, label = "Out-of-range opacity",
  tooltip = "Opacity of out-of-range frames.", mode = "advanced", overridable = true }, function(v) s.rangeAlpha = v end)
key("aggro", { type = "toggle", default = true, label = "Aggro border", tooltip = "Red border on members with high threat.",
  mode = "advanced", overridable = true }, function(v) s.aggro = v end)

-- Dispel highlight.
key("dispel", { type = "toggle", default = true, label = "Dispel highlight",
  tooltip = "Highlights members carrying a debuff that can be dispelled.", mode = "simple", overridable = true },
  function(v) s.dispel = v end)
key("dispelSource", { type = "select", default = "mine", choices = { "mine", "all" },
  choiceLabels = { mine = "Only what I can dispel", all = "Anything dispellable" }, label = "Dispel highlight shows",
  tooltip = "Only debuffs your class and spec can remove, or any dispellable debuff (useful to call for help).",
  mode = "advanced", overridable = true }, function(v) s.dispelSource = v end)
key("dispelStyle", { type = "select", default = "border", choices = { "border", "glow", "tint", "both" },
  choiceLabels = { border = "Border", glow = "Glowing border", tint = "Tinted health", both = "Border and tint" },
  label = "Dispel highlight style", tooltip = "How a dispellable debuff is shown on the frame.", mode = "simple",
  overridable = true }, function(v) s.dispelStyle = v end)
key("dispelTypeColors", { type = "toggle", default = true, label = "Colour by debuff type",
  tooltip = "Magic blue, curse purple, disease brown, poison green, bleed red. Off uses the colour below.",
  mode = "advanced" }, function(v) s.dispelTypeColors = v end)
key("dispelColor", { type = "color", default = { r = 0.96, g = 0.77, b = 0.42 }, label = "Dispel highlight colour",
  tooltip = "Used when Colour by debuff type is off.", mode = "advanced" }, function(v) s.dispelColor = v end)
key("dispelTintAlpha", { type = "range", default = 0.3, min = 0.1, max = 0.8, step = 0.05, label = "Dispel tint strength",
  tooltip = "How strongly the health bar is tinted.", mode = "advanced" }, function(v) s.dispelTintAlpha = v end)

-- Heal prediction and absorbs (PUI.Prediction).
key("heals", { type = "toggle", default = true, label = "Incoming heals", tooltip = "Predicted heals after the health fill.",
  mode = "simple", overridable = true }, function(v) s.heals = v end)
key("absorbs", { type = "toggle", default = true, label = "Group absorbs", tooltip = "Damage shields after the health fill.",
  mode = "advanced", overridable = true }, function(v) s.absorbs = v end)
key("healAbsorbs", { type = "toggle", default = true, label = "Heal absorbs",
  tooltip = "Effects that eat healing, drawn in red inside the health fill.", mode = "advanced", overridable = true },
  function(v) s.healAbsorbs = v end)
key("overflow", { type = "toggle", default = true, label = "Overflow marks",
  tooltip = "A white edge when a shield is bigger than the missing health, and a red edge when a heal absorb is bigger than the current health.",
  mode = "advanced" }, function(v) s.overflow = v end)
key("healerMana", { type = "toggle", default = true, label = "Healer mana", tooltip = "Mana bar on healers' frames only.",
  mode = "simple" }, function(v) s.healerMana = v end)
key("manaHeight", { type = "range", default = 4, min = 2, max = 12, step = 1, label = "Healer mana height",
  tooltip = "Height of the healer mana bar.", mode = "advanced" }, function(v) s.manaHeight = v end)

-- Aura icons (PUI.Auras).
local AURA_LABELS = { debuffs = "Debuffs", buffs = "Buffs", defensive = "Big defensive" }
for _, kind in ipairs(I.KINDS) do
  local a, L = s.auras[kind], AURA_LABELS[kind]
  key(kind .. ".enabled", { type = "toggle", default = a.enabled, label = L .. " on group frames",
    tooltip = kind == "defensive" and "One large icon in the middle for a big personal or external defensive." or
      ("Shows " .. L:lower() .. " icons on each frame."), mode = "simple", overridable = true },
    function(v) s.auras[kind].enabled = v end)
  key(kind .. ".max", { type = "range", default = a.max, min = 1, max = kind == "defensive" and 3 or 8, step = 1,
    label = L .. ": how many", tooltip = "Largest number of icons shown.", mode = "advanced", overridable = true },
    function(v) s.auras[kind].max = v end)
  key(kind .. ".size", { type = "range", default = a.size, min = 8, max = 40, step = 1, label = L .. ": icon size",
    tooltip = "Icon size in pixels.", mode = "advanced", overridable = true }, function(v) s.auras[kind].size = v end)
  key(kind .. ".point", { type = "select", default = a.point, choices = I.POINTS, choiceLabels = I.POINT_LABELS,
    label = L .. ": position", tooltip = "Corner or edge of the frame the icons start from.", mode = "advanced" },
    function(v) s.auras[kind].point = v end)
  key(kind .. ".filter", { type = "select", default = a.filter, choices = I.FILTERS[kind], choiceLabels = I.FILTER_LABELS,
    label = L .. ": which ones", tooltip = "Which auras are shown.", mode = "advanced", overridable = true },
    function(v) s.auras[kind].filter = v end)
end
key("lockouts", { type = "toggle", default = true, label = "Hide lockout debuffs",
  tooltip = "Leaves Sated, Exhaustion, Temporal Displacement, Forbearance and similar lockouts off the debuff icons (where the game allows it).",
  mode = "advanced", searchTags = { "sated", "bloodlust", "heroism", "exhaustion" } }, function(v) s.lockouts = v end)

-- Corner indicators (Buff Manager).
key("corners", { type = "list", default = {}, maxItems = 16, label = "Corner indicators",
  tooltip = "Spells you want to see as small squares in a corner, one per line as CORNER:spellID, then optionally :mine or :any and a colour (RRGGBB). Example: TOPLEFT:774:mine. Use the preset button for your class's heals. In some restricted fights the game hides other players' auras; then a square stays off.",
  mode = "simple", itemValidate = I.ValidateCorner, itemLabel = I.CornerLabel, overridable = true,
  searchTags = { "hot", "buff manager", "indicator", "corner" } }, function(v) s.cornerList = v end, "corners")
key("cornerSize", { type = "range", default = 7, min = 4, max = 16, step = 1, label = "Corner indicator size",
  tooltip = "Size of each corner square.", mode = "advanced" }, function(v) s.cornerSize = v end, "corners")

-- Private auras (raid option, PUI.Auras private anchors).
key("privateAuras", { type = "range", default = 2, min = 0, max = 4, step = 1, label = "Private aura slots",
  tooltip = "Boss mechanics the game hides from addons, drawn by the game itself on each frame; 0 turns them off.",
  mode = "simple", overridable = true }, function(v) s.privateAuras = v end, "private")
key("privateSize", { type = "range", default = 0, min = 0, max = 48, step = 1, label = "Private aura size",
  tooltip = "Icon size; 0 follows the frame height.", mode = "advanced" }, function(v) s.privateSize = v end, "private")
key("privatePoint", { type = "select", default = "RIGHT", choices = I.POINTS, choiceLabels = I.POINT_LABELS,
  label = "Private aura position", tooltip = "Where on the frame the private auras sit.", mode = "advanced" },
  function(v) s.privatePoint = v end, "private")
key("privateNumbers", { type = "toggle", default = false, label = "Private aura countdown numbers",
  tooltip = "Shows the seconds left on private auras.", mode = "advanced" }, function(v) s.privateNumbers = v end, "private")
key("privateDispel", { type = "toggle", default = true, label = "Private aura dispel type",
  tooltip = "Lets the game mark the dispel type on private auras.", mode = "advanced" }, function(v) s.privateDispel = v end, "private")

-- Enemy target dots (shared PUI.Targeting service).
key("targetDots", { type = "toggle", default = true, label = "Enemy target dots",
  tooltip = "In arenas, a coloured dot for each enemy that is targeting this member (the same colours as your arena frames).",
  mode = "simple", searchTags = { "arena", "target", "dots" } }, function(v) s.targetDots = v end, "dots")
key("targetDotsBoss", { type = "toggle", default = false, label = "Boss target dots",
  tooltip = "Also shows a dot for each boss targeting this member.", mode = "advanced" }, function(v) s.targetDotsBoss = v end, "dots")
key("dotSize", { type = "range", default = 6, min = 3, max = 14, step = 1, label = "Target dot size",
  tooltip = "Size of the enemy target dots.", mode = "advanced" }, function(v) s.dotSize = v end)

-- Where to show.
for kind in pairs(KINDS) do
  local L = kind == "party" and "Party frames" or "Raid frames"
  key(kind .. ".visibility", { type = "visibility", default = { mode = "always" }, label = L .. ": where to show",
    tooltip = "Show the " .. L:lower() .. " everywhere, never, or only in the content, combat state and group you pick. The line below explains why they are hidden right now.",
    mode = "simple", overridable = true, watchId = "rf." .. kind, searchTags = { "visibility", "hide", "combat" } },
    function(v) s.visibility[kind] = v end, "visibility")
end
key("hiddenAlpha", { type = "range", default = 0, min = 0, max = 1, step = 0.05, label = "Group frames opacity when hidden",
  tooltip = "Opacity used when the where-to-show rule hides the frames (0 = invisible). They stay clickable in combat because the game locks that.",
  mode = "advanced", overridable = true }, function(v) s.hiddenAlpha = v end, "visibility")
key("hideBlizzard", { type = "toggle", default = true, label = "Hide Blizzard party/raid frames",
  tooltip = "Hides the default party and raid frames while Phoenix group frames are on.", mode = "advanced" },
  function(v) s.hideBlizzard = v end, "blizzard")

for kind, d in pairs(KINDS) do
  Layout:RegisterElement("rf." .. kind, { label = kind == "party" and "Party frames" or "Raid frames", owner = OWNER,
    size = { 90, 44 }, default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

-- One-time move of the pre-tier size keys (rf.width/height/spacing/orientation)
-- into every tier of this profile. Values are moved, never reset.
local LEGACY = { width = "width", height = "height", spacing = "spacing", orientation = "orientation" }
function RF.MigrateLegacy()
  local DB = PUI.DB
  if not DB.profile then return 0 end
  local n = 0
  for old, field in pairs(LEGACY) do
    local v = DB.profile["rf." .. old]
    if v ~= nil then
      for _, t in ipairs(TIERS) do
        if DB.profile["rf." .. t .. "." .. field] == nil then DB.profile["rf." .. t .. "." .. field] = v end
      end
      DB.profile["rf." .. old] = nil
      n = n + 1
    end
  end
  return n
end

local function syncFromDB()
  RF.MigrateLegacy()
  for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
end

RF.module = PUI:RegisterModule(OWNER, {
  label = "Raid and party frames",
  tooltip = "Phoenix party and raid frames: layouts by group size, sorting, role icons, dispel highlight, aura icons, corner indicators, private auras, heal prediction, range fade and a test mode.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
RF.SyncFromDB = syncFromDB
PUI.Kernel:On("PROFILES_CHANGED", function() if RF.MigrateLegacy() > 0 then syncFromDB() end end)

PUI.Slash:Register("rftest", function(arg)
  local n = tonumber(arg)
  local want = n ~= nil or not RF.test
  local ok, why = RF.SetTestMode(want, n)
  if not ok then PUI.Slash.Print("Group frame test mode: " .. tostring(why)) return end
  PUI.Slash.Print(want and ("Group frame test mode on (" .. (RF.testCount or 20) .. " members). /pui rftest to turn it off.")
    or "Group frame test mode off.")
end, "toggle group frame test mode; /pui rftest 5|10|20|40 picks the group size")
