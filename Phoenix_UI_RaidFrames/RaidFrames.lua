local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Raid and Party Frames module (PUI_V2 5.4): two SecureGroupHeaderTemplate
-- headers (party and one merged raid header grouped by group, role or class).
-- Children are spawned out of combat when the module turns on (a header that
-- needs a new child in combat would otherwise configure it in combat), sized
-- by a restricted initialConfigFunction and given their Lua elements through
-- a CallMethod. One tracker routes unit events to every button showing that
-- unit and registers only the channels the settings need. Blizzard party and
-- raid frames are parked out of combat. Off by default.
local _, ns = ...
local Schema, Layout, CQ, Kernel = PUI.Schema, PUI.Layout, PUI.CombatQueue, PUI.Kernel
local E = ns.Elements
local OWNER = "RaidFrames"

local RF = { active = false, headers = {}, buttons = {}, byUnit = {}, parked = {}, byButton = setmetatable({}, { __mode = "k" }) }
ns.RF = RF
PUI.RaidFrames = RF

local s = {
  width = 90, height = 44, spacing = 2, orientation = "vertical", sort = "group", showPlayer = true, showSolo = false,
  colorMode = "class", healthText = "none", roleIcon = true, leader = true, raidMarker = true, statusIcons = true,
  rangeFade = true, rangeAlpha = 0.4, aggro = true, dispel = true, absorbs = true, healerMana = true, manaHeight = 4,
  privateAuras = 2, hideBlizzard = true,
}
RF.settings = s

local SORTS = {
  group = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8", sortMethod = "INDEX" },
  role = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE", sortMethod = "INDEX" },
  class = { groupBy = "CLASS", groupingOrder = "WARRIOR,DEATHKNIGHT,PALADIN,MONK,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,DEMONHUNTER,EVOKER", sortMethod = "INDEX" },
  name = { sortMethod = "NAME" },
}
RF.SORTS = SORTS
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

-- Channels -> events; each channel is on only when a setting needs it.
local CHANNELS = {
  base = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" },
  power = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" },
  prediction = { "UNIT_ABSORB_AMOUNT_CHANGED" },
  range = { "UNIT_IN_RANGE_UPDATE" },
  threat = { "UNIT_THREAT_SITUATION_UPDATE" },
  aura = { "UNIT_AURA" },
  status = { "UNIT_PHASE", "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED" },
}
RF.CHANNELS = CHANNELS
local HANDLERS = {
  UNIT_HEALTH = E.UpdateHealth, UNIT_MAXHEALTH = E.UpdateHealth, UNIT_CONNECTION = E.UpdateStatus,
  UNIT_FLAGS = E.UpdateStatus, UNIT_NAME_UPDATE = function(o) E.UpdateName(o) end,
  UNIT_POWER_UPDATE = E.UpdatePower, UNIT_MAXPOWER = E.UpdatePower, UNIT_DISPLAYPOWER = E.UpdateRole,
  UNIT_ABSORB_AMOUNT_CHANGED = E.UpdatePrediction, UNIT_IN_RANGE_UPDATE = E.UpdateRange,
  UNIT_THREAT_SITUATION_UPDATE = E.UpdateThreat, UNIT_AURA = E.UpdateDispel,
  UNIT_PHASE = E.UpdateCenter, INCOMING_RESURRECT_CHANGED = E.UpdateCenter, INCOMING_SUMMON_CHANGED = E.UpdateCenter,
}
RF.HANDLERS = HANDLERS

function RF.Channels()
  local c = { base = true }
  if s.healerMana then c.power = true end
  if s.absorbs then c.prediction = true end
  if s.rangeFade then c.range = true end
  if s.aggro then c.threat = true end
  if s.dispel then c.aura = true end
  if s.statusIcons then c.status = true end
  return c
end

local tracker
local function onUnitEvent(_, event, unit)
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

-- Buttons -----------------------------------------------------------------------
local function setUnit(o, unit)
  if o.unit and RF.byUnit[o.unit] then
    RF.byUnit[o.unit][o] = nil
    if next(RF.byUnit[o.unit]) == nil then RF.byUnit[o.unit] = nil end
  end
  o.unit = type(unit) == "string" and unit or nil
  if o.unit then
    RF.byUnit[o.unit] = RF.byUnit[o.unit] or {}
    RF.byUnit[o.unit][o] = true
    if RF.active then E.UpdateAll(o, s) end
  end
  if RF.active then E.UpdatePrivateAuras(o, s) end
end
RF.SetUnit = setUnit

local function onAttributeChanged(button, name, value)
  if name == "unit" and RF.byButton[button] then setUnit(RF.byButton[button], value) end
end

function RF.InitButton(button)
  if not button or RF.byButton[button] then return end
  local o = { button = button }
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

local function applyAttributes(h, kind)
  local vertical = s.orientation == "vertical"
  h:SetAttribute("phx-width", s.width)
  h:SetAttribute("phx-height", s.height)
  h:SetAttribute("point", vertical and "TOP" or "LEFT")
  h:SetAttribute("xOffset", vertical and 0 or s.spacing)
  h:SetAttribute("yOffset", vertical and -s.spacing or 0)
  h:SetAttribute("columnSpacing", s.spacing)
  h:SetAttribute("columnAnchorPoint", vertical and "LEFT" or "TOP")
  h:SetAttribute("unitsPerColumn", 5)
  h:SetAttribute("maxColumns", kind == "raid" and 8 or 1)
  if kind == "party" then
    h:SetAttribute("showParty", true)
    h:SetAttribute("showPlayer", s.showPlayer)
    h:SetAttribute("showSolo", s.showSolo)
  else
    h:SetAttribute("showRaid", true)
    local sort = SORTS[s.sort]
    h:SetAttribute("groupBy", sort.groupBy)
    h:SetAttribute("groupingOrder", sort.groupingOrder)
    h:SetAttribute("sortMethod", sort.sortMethod)
  end
end

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

-- Resizes existing children (protected; out of combat).
local function resize()
  for _, o in ipairs(RF.buttons) do
    o.button:SetSize(s.width, s.height)
    E.Layout(o, s)
  end
end

function RF.ApplyLayout()
  if not RF.active then return end
  CQ.Defer("rf.layout", function()
    if not RF.active then return end
    for kind, h in pairs(RF.headers) do
      applyAttributes(h, kind)
      RegisterStateDriver(h, "visibility", KINDS[kind].visibility())
      Layout:Place(h, "rf." .. kind)
    end
    resize()
  end)
end

function RF.RefreshAll()
  if not RF.active then return end
  for _, o in ipairs(RF.buttons) do
    if o.unit then E.UpdateAll(o, s) end
  end
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

-- Lifecycle ---------------------------------------------------------------------
local function allIndicators()
  for _, o in ipairs(RF.buttons) do if o.unit then E.UpdateIndicators(o, s) end end
end
local function allRoles()
  for _, o in ipairs(RF.buttons) do if o.unit then E.UpdateRole(o, s) end end
end

local function onEnable(mod)
  RF.active = true
  tracker = tracker or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  tracker:SetScript("OnEvent", onUnitEvent)
  RF.Track()
  CQ.Defer("rf.headers", function()
    if not RF.active then return end
    for kind in pairs(KINDS) do
      local h = RF.headers[kind]
      if not h then
        h = buildHeader(kind)
        spawnChildren(h, kind)
      end
    end
  end)
  RF.ApplyLayout()
  RF.ParkBlizzard(s.hideBlizzard)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", RF.RefreshAll)
  mod:RegisterEvent("PLAYER_ROLES_ASSIGNED", allRoles)
  mod:RegisterEvent("PARTY_LEADER_CHANGED", allIndicators)
  mod:RegisterEvent("RAID_TARGET_UPDATE", allIndicators)
  mod:RegisterEvent("READY_CHECK", allIndicators)
  mod:RegisterEvent("READY_CHECK_CONFIRM", allIndicators)
  mod:RegisterEvent("READY_CHECK_FINISHED", function() C_Timer.After(6, allIndicators) end)
  RF.RefreshAll()
end

local function onDisable()
  RF.active = false
  if tracker then tracker:UnregisterAllEvents() end
  CQ.Defer("rf.layout", function()
    if RF.active then return end
    for _, h in pairs(RF.headers) do
      UnregisterStateDriver(h, "visibility")
      h:Hide()
    end
  end)
  for _, o in ipairs(RF.buttons) do
    for i = #o.privateAnchors, 1, -1 do
      C_UnitAuras.RemovePrivateAuraAnchor(o.privateAnchors[i])
      o.privateAnchors[i] = nil
    end
  end
  RF.ParkBlizzard(false)
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
RF.schema = schema
local function key(name, def, field, kind)
  def.owner = OWNER
  def.apply = function(value)
    s[field] = value
    if kind == "layout" then RF.ApplyLayout()
    elseif kind == "blizzard" then if RF.active then RF.ParkBlizzard(value) end
    elseif kind == "private" then for _, o in ipairs(RF.buttons) do if RF.active then E.UpdatePrivateAuras(o, s) end end
    end
    RF.Track()
    RF.RefreshAll()
  end
  schema["rf." .. name] = def
end

key("width", { type = "range", default = 90, min = 40, max = 200, step = 1, label = "Group frame width",
  tooltip = "Width of each party/raid frame.", mode = "simple" }, "width", "layout")
key("height", { type = "range", default = 44, min = 16, max = 100, step = 1, label = "Group frame height",
  tooltip = "Height of each party/raid frame.", mode = "simple" }, "height", "layout")
key("spacing", { type = "range", default = 2, min = 0, max = 20, step = 1, label = "Group frame spacing",
  tooltip = "Gap between frames and between raid groups.", mode = "advanced" }, "spacing", "layout")
key("orientation", { type = "select", default = "vertical", choices = { "vertical", "horizontal" }, label = "Group layout",
  tooltip = "Vertical columns per group, or horizontal rows.", mode = "simple" }, "orientation", "layout")
key("sort", { type = "select", default = "group", choices = { "group", "role", "class", "name" }, label = "Raid sorting",
  tooltip = "Order raid frames by group, by role (tanks, healers, damage), by class or by name.", mode = "simple" }, "sort", "layout")
key("showPlayer", { type = "toggle", default = true, label = "Show yourself in party",
  tooltip = "Includes your own frame in the party frames.", mode = "simple" }, "showPlayer", "layout")
key("showSolo", { type = "toggle", default = false, label = "Show party frames when solo",
  tooltip = "Shows your frame even when you are not in a group.", mode = "advanced" }, "showSolo", "layout")
key("colorMode", { type = "select", default = "class", choices = { "class", "gradient", "accent" }, label = "Group health colour",
  tooltip = "Class colour, a red-to-green gradient by health, or the accent colour.", mode = "simple" }, "colorMode")
key("healthText", { type = "select", default = "none", choices = { "none", "percent", "deficit" }, label = "Group health text",
  tooltip = "Health percentage, missing health, or nothing (dead/offline always show).", mode = "advanced" }, "healthText")
key("roleIcon", { type = "toggle", default = true, label = "Role icons", tooltip = "Tank, healer and damage icons.", mode = "advanced" }, "roleIcon")
key("leader", { type = "toggle", default = true, label = "Leader icon", tooltip = "Marks the group leader.", mode = "advanced" }, "leader")
key("raidMarker", { type = "toggle", default = true, label = "Group raid markers", tooltip = "Raid target markers on group frames.", mode = "advanced" }, "raidMarker")
key("statusIcons", { type = "toggle", default = true, label = "Status icons",
  tooltip = "Ready check, incoming resurrection, pending summon and out-of-phase icons.", mode = "advanced" }, "statusIcons")
key("rangeFade", { type = "toggle", default = true, label = "Fade out of range",
  tooltip = "Fades frames of members out of your range.", mode = "simple" }, "rangeFade")
key("rangeAlpha", { type = "range", default = 0.4, min = 0.1, max = 1, step = 0.05, label = "Out-of-range opacity",
  tooltip = "Opacity of out-of-range frames.", mode = "advanced" }, "rangeAlpha")
key("aggro", { type = "toggle", default = true, label = "Aggro border", tooltip = "Red border on members with high threat.", mode = "advanced" }, "aggro")
key("dispel", { type = "toggle", default = true, label = "Dispel highlight",
  tooltip = "Highlights members carrying a debuff you can dispel.", mode = "simple" }, "dispel")
key("absorbs", { type = "toggle", default = true, label = "Group absorbs", tooltip = "Shows damage absorbs after the health fill.", mode = "advanced" }, "absorbs")
key("healerMana", { type = "toggle", default = true, label = "Healer mana",
  tooltip = "Mana bar on healers' frames only.", mode = "simple" }, "healerMana")
key("manaHeight", { type = "range", default = 4, min = 2, max = 12, step = 1, label = "Healer mana height",
  tooltip = "Height of the healer mana bar.", mode = "advanced" }, "manaHeight")
key("privateAuras", { type = "range", default = 2, min = 0, max = 3, step = 1, label = "Private aura slots",
  tooltip = "Boss mechanics the game hides from addons, drawn by the game on each frame; 0 turns them off.",
  mode = "advanced" }, "privateAuras", "private")
key("hideBlizzard", { type = "toggle", default = true, label = "Hide Blizzard party/raid frames",
  tooltip = "Hides the default party and raid frames while Phoenix group frames are on.", mode = "advanced" }, "hideBlizzard", "blizzard")

for kind, d in pairs(KINDS) do
  Layout:RegisterElement("rf." .. kind, { label = kind == "party" and "Party frames" or "Raid frames", owner = OWNER,
    size = { 90, 44 }, default = { point = d.pos[1], x = d.pos[2], y = d.pos[3] } })
end

local function syncFromDB()
  for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
end

RF.module = PUI:RegisterModule(OWNER, {
  label = "Raid and party frames",
  tooltip = "Phoenix party and raid frames with status icons, range fade, dispel highlight and private auras.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
RF.SyncFromDB = syncFromDB
