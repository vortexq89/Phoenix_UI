local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplates module (PUI_V2 5.5): pooled Phoenix frames over Blizzard plates.
-- NAME_PLATE_UNIT_ADDED acquires a frame and parks the Blizzard UnitFrame at
-- alpha 0; NAME_PLATE_UNIT_REMOVED restores it and returns the frame to the
-- pool. One dispatcher frame owns every unit event and routes it to the plate
-- for that unit token (one cast dispatcher). Nameplate CVars (stacking, scale)
-- are written only while the module is on and restored when it turns off.
-- Off by default; a disabled module owns no plates, events or CVars.
local _, ns = ...
local Schema, CQ, Secret = PUI.Schema, PUI.CombatQueue, PUI.Secret
local P = ns.Plate
local OWNER = "Nameplates"

local NP = { active = false, plates = {}, cvarsSaved = {} }
ns.NP = NP
PUI.Nameplates = NP

local s = {
  width = 140, height = 10, castbar = true, castHeight = 8, colorMode = "reaction", threat = true,
  friendlyNameOnly = true, nameText = true, healthText = "none", targetHighlight = true, execute = 0,
  raidMarker = true, classification = true, quest = true, stacking = "default", scale = 1,
}
NP.settings = s

-- Events -> handler(frame) for the plate whose unit token is arg1.
local UNIT_EVENTS = {
  UNIT_HEALTH = function(f) P.UpdateHealth(f, s) end,
  UNIT_MAXHEALTH = function(f) P.UpdateHealth(f, s) end,
  UNIT_NAME_UPDATE = function(f) P.UpdateName(f, s) end,
  UNIT_FACTION = function(f) P.ApplyMode(f, s); P.UpdateColor(f, s) end,
  UNIT_FLAGS = function(f) P.UpdateColor(f, s) end,
  UNIT_THREAT_LIST_UPDATE = function(f) P.UpdateColor(f, s) end,
  UNIT_THREAT_SITUATION_UPDATE = function(f) P.UpdateColor(f, s) end,
  UNIT_CLASSIFICATION_CHANGED = function(f) P.UpdateIcons(f, s) end,
}
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }
for _, ev in ipairs(CAST_EVENTS) do UNIT_EVENTS[ev] = function(f) P.UpdateCast(f, s) end end
NP.UNIT_EVENTS = UNIT_EVENTS

local dispatcher
local function dispatch(_, event, unit)
  local f = type(unit) == "string" and NP.plates[unit]
  if f then UNIT_EVENTS[event](f) end
end

-- Which unit events the current settings need.
function NP.WantedEvents()
  local want = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_FACTION = true, UNIT_FLAGS = true }
  if s.nameText or s.friendlyNameOnly then want.UNIT_NAME_UPDATE = true end
  if s.threat then want.UNIT_THREAT_LIST_UPDATE, want.UNIT_THREAT_SITUATION_UPDATE = true, true end
  if s.classification then want.UNIT_CLASSIFICATION_CHANGED = true end
  if s.castbar then for _, ev in ipairs(CAST_EVENTS) do want[ev] = true end end
  return want
end

function NP.Track()
  if not dispatcher then return end
  dispatcher:UnregisterAllEvents()
  if not NP.active then return end
  for ev in pairs(NP.WantedEvents()) do dispatcher:RegisterEvent(ev) end
end

-- Plates ----------------------------------------------------------------------
local function blizzardFrame(plate) return plate and plate.UnitFrame end

function NP.Add(unit)
  local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
  if not plate then return end
  local f = NP.plates[unit] or P.Acquire()
  f.unit, f.plate = unit, plate
  f:SetParent(plate)
  f:ClearAllPoints()
  f:SetPoint("CENTER", plate, "CENTER")
  local blizz = blizzardFrame(plate)
  if blizz then blizz:SetAlpha(0) end
  NP.plates[unit] = f
  P.UpdateAll(f, s)
  f:Show()
end

function NP.Remove(unit)
  local f = NP.plates[unit]
  if not f then return end
  NP.plates[unit] = nil
  local blizz = blizzardFrame(f.plate)
  if blizz then blizz:SetAlpha(1) end
  f.plate = nil
  P.Release(f)
end

function NP.RefreshAll()
  if not NP.active then return end
  for _, f in pairs(NP.plates) do P.UpdateAll(f, s) end
end

local function updateRole()
  local spec = C_SpecializationInfo.GetSpecialization()
  local role
  if spec then role = select(5, C_SpecializationInfo.GetSpecializationInfo(spec)) end
  ns.role = role
end

-- CVars: saved once per enable and restored on disable (out of combat).
local CVARS = { stacking = "nameplateMotion", scale = "nameplateGlobalScale" }
NP.CVARS = CVARS
local function writeCVar(name, value)
  CQ.Defer("np.cvar." .. name, function()
    if not NP.active then return end
    if NP.cvarsSaved[name] == nil then NP.cvarsSaved[name] = C_CVar.GetCVar(name) or "" end
    C_CVar.SetCVar(name, value)
  end)
end

function NP.ApplyCVars()
  if not NP.active then return end
  if s.stacking ~= "default" then writeCVar(CVARS.stacking, s.stacking == "stacked" and "1" or "0") end
  if s.scale ~= 1 then writeCVar(CVARS.scale, string.format("%.2f", s.scale)) end
end

function NP.RestoreCVars()
  CQ.Defer("np.cvar.restore", function()
    if NP.active then return end
    for name, value in pairs(NP.cvarsSaved) do C_CVar.SetCVar(name, value) end
    wipe(NP.cvarsSaved)
  end)
end

-- Lifecycle ---------------------------------------------------------------------
local function onEnable(mod)
  NP.active = true
  dispatcher = dispatcher or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  dispatcher:SetScript("OnEvent", dispatch)
  updateRole()
  NP.Track()
  mod:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, _, unit) NP.Add(unit) end)
  mod:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, _, unit) NP.Remove(unit) end)
  mod:RegisterEvent("PLAYER_TARGET_CHANGED", function() for _, f in pairs(NP.plates) do P.UpdateTarget(f, s) end end)
  mod:RegisterEvent("RAID_TARGET_UPDATE", function() for _, f in pairs(NP.plates) do P.UpdateIcons(f, s) end end)
  mod:RegisterEvent("QUEST_LOG_UPDATE", function() for _, f in pairs(NP.plates) do P.UpdateIcons(f, s) end end)
  mod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() updateRole(); NP.RefreshAll() end)
  for _, plate in ipairs(C_NamePlate.GetNamePlates(false) or {}) do
    local unit = plate.namePlateUnitToken
    if type(unit) == "string" then NP.Add(unit) end
  end
  NP.ApplyCVars()
end

local function onDisable()
  NP.active = false
  if dispatcher then dispatcher:UnregisterAllEvents() end
  local units = {}
  for unit in pairs(NP.plates) do units[#units + 1] = unit end
  for _, unit in ipairs(units) do NP.Remove(unit) end
  NP.RestoreCVars()
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
NP.schema = schema
local function key(name, def, set, after)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    if after then after() end
    NP.Track()
    NP.RefreshAll()
  end
  schema["np." .. name] = def
end
local function field(name) return function(v) s[name] = v end end

key("width", { type = "range", default = 140, min = 60, max = 300, step = 1, label = "Plate width",
  tooltip = "Width of Phoenix nameplates in pixels.", mode = "simple" }, field("width"))
key("height", { type = "range", default = 10, min = 4, max = 40, step = 1, label = "Plate health height",
  tooltip = "Height of the nameplate health bar.", mode = "simple" }, field("height"))
key("castbar", { type = "toggle", default = true, label = "Plate cast bars",
  tooltip = "Shows casts and channels under each plate (one shared cast dispatcher).", mode = "simple" }, field("castbar"))
key("castHeight", { type = "range", default = 8, min = 4, max = 24, step = 1, label = "Plate cast bar height",
  tooltip = "Height of the cast bar under each plate.", mode = "advanced" }, field("castHeight"))
key("colorMode", { type = "select", default = "reaction", choices = { "reaction", "class" }, label = "Plate health colour",
  tooltip = "Reaction colour, or class colour for players.", mode = "simple" }, field("colorMode"))
key("threat", { type = "toggle", default = true, label = "Threat colours",
  tooltip = "In combat, colour plates by your threat: tanks want aggro (green), others want none.", mode = "simple" }, field("threat"))
key("friendlyNameOnly", { type = "toggle", default = true, label = "Friendly plates: name only",
  tooltip = "Friendly units show only a class-coloured name.", mode = "simple" }, field("friendlyNameOnly"))
key("nameText", { type = "toggle", default = true, label = "Show names",
  tooltip = "Shows the unit's name above enemy plates.", mode = "advanced" }, field("nameText"))
key("healthText", { type = "select", default = "none", choices = { "none", "percent" }, label = "Plate health text",
  tooltip = "Health text on the plate.", mode = "advanced" }, field("healthText"))
key("targetHighlight", { type = "toggle", default = true, label = "Target highlight",
  tooltip = "Outlines your current target's plate in the accent colour.", mode = "advanced" }, field("targetHighlight"))
key("execute", { type = "range", default = 0, min = 0, max = 50, step = 1, label = "Execute marker (%)",
  tooltip = "Draws a marker at this health percentage; 0 hides it.", mode = "advanced" }, field("execute"))
key("icon.raidMarker", { type = "toggle", default = true, label = "Plate raid markers",
  tooltip = "Shows raid target markers beside plates.", mode = "advanced" }, field("raidMarker"))
key("icon.classification", { type = "toggle", default = true, label = "Plate elite / rare icon",
  tooltip = "Marks elite, rare and boss units.", mode = "advanced" }, field("classification"))
key("icon.quest", { type = "toggle", default = true, label = "Plate quest icon",
  tooltip = "Marks units related to one of your active quests.", mode = "advanced" }, field("quest"))
key("stacking", { type = "select", default = "default", choices = { "default", "stacked", "overlap" }, label = "Plate stacking",
  tooltip = "Stacked plates never overlap; overlapping plates stay over their units. Default leaves the game setting alone; the original value is restored when the module turns off.",
  mode = "simple" }, field("stacking"), function() NP.ApplyCVars() end)
key("scale", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = "Plate scale",
  tooltip = "Global nameplate scale; restored when the module turns off.", mode = "advanced" }, field("scale"), function() NP.ApplyCVars() end)

local function syncFromDB()
  for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
end

NP.module = PUI:RegisterModule(OWNER, {
  label = "Nameplates",
  tooltip = "Phoenix nameplates over the game's plates: health, casts, threat colours and icons.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
NP.SyncFromDB = syncFromDB
