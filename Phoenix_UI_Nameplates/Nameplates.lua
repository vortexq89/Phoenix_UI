local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplates module (PUI_V2 5.5, plan 5.3 / 13.4 / 15.6 / 15.7, mockup 02).
-- Pooled Phoenix frames over Blizzard plates: NAME_PLATE_UNIT_ADDED acquires a
-- frame and parks the Blizzard UnitFrame at alpha 0; NAME_PLATE_UNIT_REMOVED
-- restores it and returns the frame to the pool. Forbidden plates are never
-- touched. One dispatcher routes unit events to the plate for that token and
-- registers only what the settings need; casts run on the shared PUI.CastBar
-- dispatcher, auras on PUI.Auras containers. Friendly plates are name-only or
-- health bars per content type (name-only everywhere by default). Nameplate
-- CVars go through the PUI.CVars ledger, are written only when the user
-- changes them, out of combat, and are given back when the module turns off.
-- Off by default; a disabled module owns no plates, events or CVars.
local _, ns = ...
local Schema, CQ, Kernel = PUI.Schema, PUI.CombatQueue, PUI.Kernel
local P, R = ns.Plate, ns.Rules
local OWNER = "Nameplates"

local NP = { active = false, plates = {}, Plate = P, Rules = R }
ns.NP = NP
PUI.Nameplates = NP

local CONTENT = PUI.Visibility.CONTENT
local function contentRow() local t = {}; for _, c in ipairs(CONTENT) do t[c] = false end; return t end
local function rgb(r, g, b) return { r = r, g = g, b = b } end

local s = {
  style = "ember", font = nil, nameSize = 10, content = "world",
  enemy = { width = 140, height = 12, name = true, namePos = "top", healthText = "percent", hideNameCasting = false },
  friendly = { bars = { players = contentRow(), npcs = contentRow() }, width = 110, height = 8, nameSize = 11,
    classNames = true, guild = true },
  colors = { mode = "reaction", hostile = rgb(0.9, 0.31, 0.27), neutral = rgb(0.96, 0.77, 0.29), friendly = rgb(0.24, 0.86, 0.59),
    tapped = rgb(0.5, 0.5, 0.5), threat = true, threatStyle = "role", safe = rgb(0.24, 0.86, 0.59), warn = rgb(1, 0.66, 0.3),
    danger = rgb(1, 0.33, 0.41), offTank = true, offTankColor = rgb(0.35, 0.7, 1), quest = false, questColor = rgb(1, 0.82, 0.1) },
  cast = { enabled = true, height = 10, icon = true, name = true, timer = true, shield = true, kick = true, important = true,
    fade = 0.35, colorCast = rgb(1, 0.62, 0.18), colorChannel = rgb(0.36, 0.7, 1), colorLocked = rgb(0.55, 0.56, 0.6),
    colorFailed = rgb(0.9, 0.31, 0.42), importantColor = rgb(1, 0.33, 0.41) },
  auras = {
    debuffs = { enabled = true, max = 6, size = 20, filter = "plate" },
    buffs = { enabled = true, max = 3, size = 20, filter = "important" },
    cc = { enabled = true, max = 1, size = 28, filter = "cc" },
  },
  target = { highlight = "outline", color = rgb(1, 0.48, 0.1), scale = 1.1, arrows = true, nonTargetAlpha = 0.6,
    focus = true, focusColor = rgb(0.69, 0.49, 1), focusLetter = true },
  icons = { raidMarker = true, markerSize = 18, classification = true, quest = true, execute = 0, executeLine = true,
    executeRecolor = false, executeColor = rgb(1, 0.33, 0.41), forces = true },
  resource = { enabled = false, height = 4, color = rgb(0.96, 0.77, 0.42) },
  rules = { list = {}, priority = "rules" },
  system = { stacking = "game", scale = 0, overlapV = 0, maxDistance = 0, selectedScale = 0 },
}
NP.settings = s

-- Events -> handler(frame) for the plate whose unit token is arg1.
local UNIT_EVENTS = {
  UNIT_HEALTH = function(f) P.UpdateHealth(f, s) end,
  UNIT_MAXHEALTH = function(f) P.UpdateHealth(f, s) end,
  UNIT_NAME_UPDATE = function(f) P.ApplyMode(f, s); P.UpdateName(f, s); P.UpdateColor(f, s) end,
  UNIT_FACTION = function(f) P.UpdateAll(f, s) end,
  UNIT_FLAGS = function(f) P.UpdateColor(f, s) end,
  UNIT_THREAT_LIST_UPDATE = function(f) P.UpdateColor(f, s) end,
  UNIT_THREAT_SITUATION_UPDATE = function(f) P.UpdateColor(f, s) end,
  UNIT_CLASSIFICATION_CHANGED = function(f) P.UpdateIcons(f, s) end,
}
-- Cast extras only (the bar itself listens through PUI.CastBar).
local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }
for _, ev in ipairs(CAST_EVENTS) do UNIT_EVENTS[ev] = function(f) P.UpdateCastExtras(f, s) end end
NP.UNIT_EVENTS, NP.CAST_EVENTS = UNIT_EVENTS, CAST_EVENTS

local dispatcher
local function dispatch(_, event, unit)
  if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
    if unit == "player" then NP.ForTarget(P.UpdateResource) end
    return
  end
  local f = type(unit) == "string" and NP.plates[unit]
  if f then UNIT_EVENTS[event](f) end
end

-- Which unit events the current settings need.
function NP.WantedEvents()
  local want = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_FACTION = true, UNIT_FLAGS = true, UNIT_NAME_UPDATE = true }
  if s.colors.threat then want.UNIT_THREAT_LIST_UPDATE, want.UNIT_THREAT_SITUATION_UPDATE = true, true end
  if s.icons.classification then want.UNIT_CLASSIFICATION_CHANGED = true end
  if s.cast.enabled and (s.cast.important or s.enemy.hideNameCasting) then
    for _, ev in ipairs(CAST_EVENTS) do want[ev] = true end
  end
  if s.resource.enabled then want.UNIT_POWER_UPDATE, want.UNIT_MAXPOWER = true, true end
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
  local plate = C_NamePlate.GetNamePlateForUnit(unit, false) -- nil for forbidden plates: never touched
  if not plate then return end
  local f = NP.plates[unit] or P.Acquire()
  f.unit, f.plate = unit, plate
  f:SetParent(plate)
  f:ClearAllPoints()
  f:SetPoint("CENTER", plate, "CENTER")
  P.Attach(f, unit)
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

function NP.ForAll(fn) for _, f in pairs(NP.plates) do fn(f, s) end end
function NP.ForTarget(fn) for _, f in pairs(NP.plates) do if f.isTarget then fn(f, s) end end end

local function updateRole()
  local spec = C_SpecializationInfo.GetSpecialization()
  local role
  if spec then role = select(5, C_SpecializationInfo.GetSpecializationInfo(spec)) end
  ns.role = role
end

-- Content type for the friendly name-only / health-bar grid.
function NP.UpdateContent()
  local c = PUI.Visibility.Probe().content
  if c ~= s.content then
    s.content = c
    NP.RefreshAll()
  end
end

-- CVars (ledger) -------------------------------------------------------------------
-- A value of "game" / 0 leaves the game's own setting alone (and gives back
-- a value Phoenix wrote earlier). Writes wait for the end of combat.
NP.CVARS = {
  stacking = { name = "nameplateMotion", value = function(v) if v == "game" then return nil end return v == "stacked" and "1" or "0" end },
  scale = { name = "nameplateGlobalScale" },
  overlapV = { name = "nameplateOverlapV" },
  maxDistance = { name = "nameplateMaxDistance" },
  selectedScale = { name = "nameplateSelectedScale" },
}
local function cvarValue(k)
  local spec, v = NP.CVARS[k], s.system[k]
  if spec.value then return spec.value(v) end
  if v == 0 then return nil end
  return ("%.2f"):format(v):gsub("%.?0+$", "")
end

function NP.ApplyCVars()
  CQ.Defer("np.cvars", function()
    for k, spec in pairs(NP.CVARS) do
      local v = NP.active and cvarValue(k) or nil
      if v ~= nil then PUI.CVars:Set(OWNER, spec.name, v) else PUI.CVars:Restore(OWNER, spec.name) end
    end
  end)
end

-- Lifecycle ---------------------------------------------------------------------
local function onEnable(mod)
  NP.active = true
  dispatcher = dispatcher or PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
  dispatcher:SetScript("OnEvent", dispatch)
  updateRole()
  s.content = PUI.Visibility.Probe().content
  NP.Track()
  mod:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, _, unit) NP.Add(unit) end)
  mod:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, _, unit) NP.Remove(unit) end)
  mod:RegisterEvent("PLAYER_TARGET_CHANGED", function() NP.ForAll(P.UpdateTarget) end)
  mod:RegisterEvent("PLAYER_FOCUS_CHANGED", function() NP.ForAll(P.UpdateFocus) end)
  mod:RegisterEvent("RAID_TARGET_UPDATE", function() NP.ForAll(P.UpdateIcons) end)
  mod:RegisterEvent("QUEST_LOG_UPDATE", function() NP.ForAll(P.UpdateIcons) end)
  mod:RegisterEvent("SCENARIO_CRITERIA_UPDATE", function() NP.ForAll(P.UpdateForces) end)
  mod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() updateRole(); NP.RefreshAll() end)
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", NP.UpdateContent)
  mod:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() NP.UpdateContent(); if NP.DataPacks then NP.DataPacks.OnZone() end end)
  mod:RegisterEvent("GROUP_ROSTER_UPDATE", function() if s.colors.offTank then NP.ForAll(P.UpdateColor) end end)
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
  NP.ApplyCVars() -- the ledger also restores on MODULE_DISABLED
end

-- Schema ---------------------------------------------------------------------------
local schema = {}
NP.schema = schema
local REFRESH = {
  cvars = function() NP.ApplyCVars() end,
  rules = function() R.Compile(s.rules.list) end,
}
local function key(name, def, set, refresh)
  def.owner = OWNER
  def.apply = function(value)
    set(value)
    if refresh then REFRESH[refresh](value) end
    NP.Track()
    NP.RefreshAll()
    Kernel:Fire("NP_SETTINGS")
  end
  schema["np." .. name] = def
end
NP.key = key
local function at(path)
  local t, k = s, nil
  local parts = {}
  for p in path:gmatch("[^.]+") do parts[#parts + 1] = p end
  return function(v)
    t = s
    for i = 1, #parts - 1 do t = t[parts[i]] end
    k = parts[#parts]
    t[k] = v
  end
end
local function copyColor(c) return { r = c.r, g = c.g, b = c.b } end

-- General.
key("style", { type = "select", default = "ember", choices = P.STYLES, choiceLabels = P.STYLE_LABELS, label = "Plate look",
  tooltip = "The border and backdrop style of every plate. Each part below can still be changed on its own.", mode = "simple",
  searchTags = { "theme", "border", "skin" } }, at("style"))
key("nameSize", { type = "range", default = 10, min = 6, max = 20, step = 1, label = "Enemy name size",
  tooltip = "Font size of names on enemy plates.", mode = "simple", overridable = true }, at("nameSize"))

-- Enemy plates.
key("enemy.width", { type = "range", default = 140, min = 60, max = 300, step = 1, label = "Enemy plate width",
  tooltip = "Width of enemy health bars in pixels.", mode = "simple", overridable = true, searchTags = { "size" } }, at("enemy.width"))
key("enemy.height", { type = "range", default = 12, min = 4, max = 40, step = 1, label = "Enemy plate height",
  tooltip = "Height of enemy health bars.", mode = "simple", overridable = true, searchTags = { "size" } }, at("enemy.height"))
key("enemy.name", { type = "toggle", default = true, label = "Show enemy names", tooltip = "Shows the unit's name on enemy plates.",
  mode = "simple" }, at("enemy.name"))
key("enemy.namePos", { type = "select", default = "top", choices = { "top", "inside" },
  choiceLabels = { top = "Above the bar", inside = "Inside the bar" }, label = "Enemy name position",
  tooltip = "Puts the name above the health bar or inside it, left aligned.", mode = "advanced" }, at("enemy.namePos"))
key("enemy.healthText", { type = "select", default = "percent", choices = { "none", "percent", "value", "both" },
  choiceLabels = { none = "None", percent = "Percent", value = "Value", both = "Value and percent" }, label = "Enemy health text",
  tooltip = "Health text on the right of enemy plates.", mode = "simple", overridable = true }, at("enemy.healthText"))
key("enemy.hideNameCasting", { type = "toggle", default = false, label = "Hide the name while casting",
  tooltip = "Hides the enemy's name while it casts so the cast bar is easier to read.", mode = "advanced" }, at("enemy.hideNameCasting"))

-- Friendly plates.
key("friendly.bars", { type = "grid", default = { players = contentRow(), npcs = contentRow() },
  rows = { { id = "players", label = "Friendly players" }, { id = "npcs", label = "Friendly NPCs" } },
  columns = function()
    local out = {}
    for i, c in ipairs(CONTENT) do out[i] = { id = c, label = PUI.Visibility.CONTENT_LABELS[c] } end
    return out
  end,
  label = "Friendly health bars by content", tooltip = "Tick a box to show health bars for that kind of friendly unit in that content. Unticked shows the name only (the default everywhere). Inside instances the game may keep friendly plates for itself; then its own plate shows.",
  mode = "simple", searchTags = { "name only", "friendly", "health bars", "content" } }, at("friendly.bars"))
key("friendly.width", { type = "range", default = 110, min = 40, max = 300, step = 1, label = "Friendly bar width",
  tooltip = "Width of friendly health bars where they are switched on.", mode = "advanced", overridable = true }, at("friendly.width"))
key("friendly.height", { type = "range", default = 8, min = 2, max = 30, step = 1, label = "Friendly bar height",
  tooltip = "Height of friendly health bars where they are switched on.", mode = "advanced", overridable = true }, at("friendly.height"))
key("friendly.nameSize", { type = "range", default = 11, min = 6, max = 20, step = 1, label = "Friendly name size",
  tooltip = "Font size of names on friendly plates.", mode = "simple" }, at("friendly.nameSize"))
key("friendly.classNames", { type = "toggle", default = true, label = "Class-coloured friendly names",
  tooltip = "Friendly players' names use their class colour.", mode = "simple" }, at("friendly.classNames"))
key("friendly.guild", { type = "toggle", default = true, label = "Show guild under friendly names",
  tooltip = "Shows <Guild> under friendly players' names in name-only mode.", mode = "advanced" }, at("friendly.guild"))

-- Colours.
key("colors.mode", { type = "select", default = "reaction", choices = { "reaction", "class" },
  choiceLabels = { reaction = "Reaction colours", class = "Class colours for players" }, label = "Health colour",
  tooltip = "Colour enemy bars by reaction (hostile, neutral, friendly), or use class colours for players.", mode = "simple" },
  at("colors.mode"))
for _, c in ipairs({ { "hostile", "Hostile colour" }, { "neutral", "Neutral colour" }, { "friendly", "Friendly colour" },
  { "tapped", "Tapped colour" } }) do
  key("colors." .. c[1], { type = "color", default = copyColor(s.colors[c[1]]), label = c[2],
    tooltip = "Health bar colour for " .. c[1] .. " units.", mode = "advanced" }, at("colors." .. c[1]))
end
key("colors.threat", { type = "toggle", default = true, label = "Threat colours",
  tooltip = "In combat, colour enemy plates by your threat. Tanks want aggro; everyone else wants none.", mode = "simple",
  overridable = true, searchTags = { "aggro", "tank" } }, at("colors.threat"))
key("colors.threatStyle", { type = "select", default = "role", choices = { "role", "classic" },
  choiceLabels = { role = "By my role (tank or not)", classic = "Classic: only when I have aggro" }, label = "Threat colour style",
  tooltip = "By role colours every state for tanks and others. Classic only colours plates that are on you or about to be.",
  mode = "advanced", overridable = true }, at("colors.threatStyle"))
for _, c in ipairs({ { "safe", "Threat: as wanted" }, { "warn", "Threat: changing" }, { "danger", "Threat: wrong" } }) do
  key("colors." .. c[1], { type = "color", default = copyColor(s.colors[c[1]]), label = c[2],
    tooltip = "Colour used when threat is in this state.", mode = "advanced" }, at("colors." .. c[1]))
end
key("colors.offTank", { type = "toggle", default = true, label = "Off-tank colour",
  tooltip = "As a tank, plates another tank in your group is holding get their own colour instead of the danger colour.",
  mode = "advanced", overridable = true }, at("colors.offTank"))
key("colors.offTankColor", { type = "color", default = copyColor(s.colors.offTankColor), label = "Off-tank colour",
  tooltip = "Colour for plates another tank is holding.", mode = "advanced" }, at("colors.offTankColor"))
key("colors.quest", { type = "toggle", default = false, label = "Colour quest enemies",
  tooltip = "Enemies you need for an active quest get the quest colour (out of combat or when threat colours are off).",
  mode = "advanced" }, at("colors.quest"))
key("colors.questColor", { type = "color", default = copyColor(s.colors.questColor), label = "Quest enemy colour",
  tooltip = "Colour for enemies tied to one of your quests.", mode = "advanced" }, at("colors.questColor"))

-- Cast bars (PUI.CastBar).
key("cast.enabled", { type = "toggle", default = true, label = "Cast bars on plates",
  tooltip = "Shows casts and channels under enemy plates, with the shield for casts you cannot interrupt.", mode = "simple" },
  at("cast.enabled"))
key("cast.height", { type = "range", default = 10, min = 4, max = 24, step = 1, label = "Cast bar height",
  tooltip = "Height of the cast bar under each plate.", mode = "simple", overridable = true }, at("cast.height"))
key("cast.icon", { type = "toggle", default = true, label = "Spell icon", tooltip = "Shows the spell icon left of the cast bar.",
  mode = "advanced" }, at("cast.icon"))
key("cast.name", { type = "toggle", default = true, label = "Spell name", tooltip = "Shows the spell name on the cast bar.",
  mode = "advanced" }, at("cast.name"))
key("cast.timer", { type = "toggle", default = true, label = "Cast time", tooltip = "Shows the remaining time on the cast bar.",
  mode = "advanced" }, at("cast.timer"))
key("cast.shield", { type = "toggle", default = true, label = "Mark casts you cannot interrupt",
  tooltip = "Greys the bar over casts that cannot be interrupted.", mode = "advanced" }, at("cast.shield"))
key("cast.kick", { type = "toggle", default = true, label = "Show my interrupt",
  tooltip = "Shows your interrupt and its cooldown next to each cast, so you see at a glance whether your kick is ready.",
  mode = "simple", searchTags = { "kick", "interrupt" } }, at("cast.kick"))
key("cast.important", { type = "toggle", default = true, label = "Glow important casts",
  tooltip = "Outlines casts the game marks as important (big hits, heals, crowd control).", mode = "simple" }, at("cast.important"))
key("cast.importantColor", { type = "color", default = copyColor(s.cast.importantColor), label = "Important cast glow colour",
  tooltip = "Colour of the outline on important casts.", mode = "advanced" }, at("cast.importantColor"))
key("cast.fade", { type = "range", default = 0.35, min = 0, max = 1.5, step = 0.05, label = "Interrupted / finished flash",
  tooltip = "How long the bar stays after a cast ends, in the interrupted or finished colour; 0 hides it at once.",
  mode = "advanced" }, at("cast.fade"))
for _, c in ipairs({ { "colorCast", "Cast colour" }, { "colorChannel", "Channel colour" }, { "colorLocked", "Uninterruptible colour" },
  { "colorFailed", "Interrupted colour" } }) do
  key("cast." .. c[1], { type = "color", default = copyColor(s.cast[c[1]]), label = c[2], tooltip = c[2] .. " of plate cast bars.",
    mode = "advanced" }, at("cast." .. c[1]))
end

-- Aura lanes (PUI.Auras).
local LANE_LABEL = { debuffs = "Your debuffs", buffs = "Enemy buffs", cc = "Crowd control" }
local LANE_TIP = { debuffs = "Your debuffs on the enemy, above the plate.", buffs = "Important or purgeable buffs, right of the plate.",
  cc = "Crowd control on the unit as one big icon right of the plate." }
for _, lane in ipairs(P.LANES) do
  local a, L = s.auras[lane], LANE_LABEL[lane]
  key("auras." .. lane .. ".enabled", { type = "toggle", default = a.enabled, label = L, tooltip = LANE_TIP[lane], mode = "simple",
    overridable = true }, at("auras." .. lane .. ".enabled"))
  key("auras." .. lane .. ".max", { type = "range", default = a.max, min = 1, max = 12, step = 1, label = L .. ": how many",
    tooltip = "Most icons shown in this lane.", mode = "advanced", overridable = true }, at("auras." .. lane .. ".max"))
  key("auras." .. lane .. ".size", { type = "range", default = a.size, min = 10, max = 48, step = 1, label = L .. ": icon size",
    tooltip = "Icon size in this lane.", mode = "advanced", overridable = true }, at("auras." .. lane .. ".size"))
  key("auras." .. lane .. ".filter", { type = "select", default = a.filter, choices = P.LANE_FILTER_CHOICES[lane],
    choiceLabels = P.LANE_FILTER_LABELS, label = L .. ": which ones", tooltip = "Which auras this lane shows.", mode = "advanced",
    overridable = true }, at("auras." .. lane .. ".filter"))
end

-- Target and focus.
key("target.highlight", { type = "select", default = "outline", choices = { "outline", "glow", "none" },
  choiceLabels = { outline = "Outline", glow = "Soft glow", none = "None" }, label = "Target highlight",
  tooltip = "How your current target's plate is marked.", mode = "simple" }, at("target.highlight"))
key("target.color", { type = "color", default = copyColor(s.target.color), label = "Target highlight colour",
  tooltip = "Colour of the target outline and arrows.", mode = "advanced" }, at("target.color"))
key("target.arrows", { type = "toggle", default = true, label = "Target arrows", tooltip = "Arrows either side of your target's plate.",
  mode = "simple" }, at("target.arrows"))
key("target.scale", { type = "range", default = 1.1, min = 1, max = 1.6, step = 0.05, label = "Target plate size",
  tooltip = "Makes your target's plate bigger; 1 keeps it the same.", mode = "advanced", overridable = true }, at("target.scale"))
key("target.nonTargetAlpha", { type = "range", default = 0.6, min = 0.1, max = 1, step = 0.05, label = "Other plates' opacity",
  tooltip = "Opacity of plates that are not your target while you have one; 1 keeps them fully visible.", mode = "simple",
  overridable = true }, at("target.nonTargetAlpha"))
key("target.focus", { type = "toggle", default = true, label = "Focus highlight", tooltip = "Outlines your focus target's plate.",
  mode = "simple" }, at("target.focus"))
key("target.focusColor", { type = "color", default = copyColor(s.target.focusColor), label = "Focus colour",
  tooltip = "Colour of the focus outline and letter.", mode = "advanced" }, at("target.focusColor"))
key("target.focusLetter", { type = "toggle", default = true, label = "Focus letter",
  tooltip = "Shows a small F at the corner of your focus target's plate.", mode = "advanced" }, at("target.focusLetter"))

-- Icons and indicators.
key("icons.raidMarker", { type = "toggle", default = true, label = "Raid markers", tooltip = "Shows raid target markers above plates.",
  mode = "simple" }, at("icons.raidMarker"))
key("icons.markerSize", { type = "range", default = 18, min = 10, max = 40, step = 1, label = "Raid marker size",
  tooltip = "Size of the raid marker icon.", mode = "advanced" }, at("icons.markerSize"))
key("icons.classification", { type = "toggle", default = true, label = "Elite and rare icon",
  tooltip = "Marks elite, rare and boss units.", mode = "advanced" }, at("icons.classification"))
key("icons.quest", { type = "toggle", default = true, label = "Quest icon", tooltip = "Marks units tied to one of your active quests.",
  mode = "simple" }, at("icons.quest"))
key("icons.execute", { type = "range", default = 0, min = 0, max = 50, step = 1, label = "Execute range (%)",
  tooltip = "Health percent where your execute range starts; 0 turns the execute marker and recolour off.", mode = "simple",
  overridable = true, searchTags = { "execute", "low health" } }, at("icons.execute"))
key("icons.executeLine", { type = "toggle", default = true, label = "Execute line", tooltip = "Draws a thin line at the execute percent.",
  mode = "advanced" }, at("icons.executeLine"))
key("icons.executeRecolor", { type = "toggle", default = false, label = "Recolour in execute range",
  tooltip = "Enemies below the execute percent use the execute colour.", mode = "advanced" }, at("icons.executeRecolor"))
key("icons.executeColor", { type = "color", default = copyColor(s.icons.executeColor), label = "Execute colour",
  tooltip = "Health colour below the execute percent.", mode = "advanced" }, at("icons.executeColor"))
key("icons.forces", { type = "toggle", default = true, label = "Mythic+ enemy forces",
  tooltip = "In Mythic+, shows how much enemy forces each enemy is worth, next to its plate.", mode = "simple",
  searchTags = { "m+", "count", "percent", "forces" } }, at("icons.forces"))

-- Class resource on the target plate (Resource Bars owns the resolver).
key("resource.enabled", { type = "toggle", default = false, label = "Class resource on target plate",
  tooltip = "Shows your combo points, holy power, chi and similar under your target's plate. Needs the Resource Bars add-on loaded (it does not have to be switched on).",
  mode = "simple", overridable = true, searchTags = { "combo points", "holy power", "chi" } }, at("resource.enabled"))
key("resource.height", { type = "range", default = 4, min = 2, max = 12, step = 1, label = "Class resource height",
  tooltip = "Height of the resource pips under the target plate.", mode = "advanced" }, at("resource.height"))
key("resource.color", { type = "color", default = copyColor(s.resource.color), label = "Class resource colour",
  tooltip = "Colour of the resource pips.", mode = "advanced" }, at("resource.color"))

-- NPC rules (list editor).
key("rules.list", { type = "list", default = {}, maxItems = 200, label = "Custom NPC colours",
  tooltip = "One NPC per line: its NPC id or exact name, a colour, then optionally a size and 'glow'. Examples: 185680:B07CFF  -  Void Acolyte:B07CFF:1.1  -  Explosive:FF5468:1.2:glow. The first line for an NPC wins. In some restricted content the game hides NPC ids and names; then a rule waits until they are visible.",
  mode = "simple", itemValidate = R.Validate, itemLabel = R.Label, overridable = true,
  searchTags = { "npc", "colour", "plater", "mob", "rules" } }, at("rules.list"), "rules")
key("rules.priority", { type = "select", default = "rules", choices = { "rules", "threat" },
  choiceLabels = { rules = "NPC colours win", threat = "Threat colours win in combat" }, label = "When an NPC colour meets threat",
  tooltip = "Which colour a listed NPC gets in combat.", mode = "advanced" }, at("rules.priority"))

-- Game nameplate settings (CVar ledger; "game" / 0 leaves the game's value).
key("system.stacking", { type = "select", default = "game", choices = { "game", "stacked", "overlap" },
  choiceLabels = { game = "Keep the game's setting", stacked = "Stacked (never overlap)", overlap = "Overlapping" },
  label = "Plate stacking", tooltip = "Stacked plates never overlap; overlapping plates stay over their units. Your own value comes back when Phoenix nameplates turn off.",
  mode = "simple", searchTags = { "cvar", "overlap" } }, at("system.stacking"), "cvars")
key("system.scale", { type = "range", default = 0, min = 0, max = 2, step = 0.05, label = "Game plate scale",
  tooltip = "The game's nameplate scale; 0 keeps the game's value.", mode = "advanced", searchTags = { "cvar" } },
  at("system.scale"), "cvars")
key("system.overlapV", { type = "range", default = 0, min = 0, max = 3, step = 0.05, label = "Vertical spacing when stacked",
  tooltip = "Space between stacked plates; 0 keeps the game's value.", mode = "advanced", searchTags = { "cvar" } },
  at("system.overlapV"), "cvars")
key("system.maxDistance", { type = "range", default = 0, min = 0, max = 60, step = 1, label = "Plate view distance (yards)",
  tooltip = "How far away plates appear; 0 keeps the game's value.", mode = "advanced", searchTags = { "cvar", "range" } },
  at("system.maxDistance"), "cvars")
key("system.selectedScale", { type = "range", default = 0, min = 0, max = 2, step = 0.05, label = "Game target scale",
  tooltip = "The game's own target plate scale; 0 keeps the game's value. Phoenix's target size above works on top of it.",
  mode = "advanced", searchTags = { "cvar" } }, at("system.selectedScale"), "cvars")

-- Legacy (step 3) keys move into their new homes; values move, never reset.
local LEGACY = {
  ["np.width"] = "np.enemy.width", ["np.height"] = "np.enemy.height", ["np.castbar"] = "np.cast.enabled",
  ["np.castHeight"] = "np.cast.height", ["np.colorMode"] = "np.colors.mode", ["np.threat"] = "np.colors.threat",
  ["np.nameText"] = "np.enemy.name", ["np.healthText"] = "np.enemy.healthText", ["np.execute"] = "np.icons.execute",
  ["np.icon.raidMarker"] = "np.icons.raidMarker", ["np.icon.classification"] = "np.icons.classification",
  ["np.icon.quest"] = "np.icons.quest",
}
NP.LEGACY = LEGACY
function NP.MigrateLegacy()
  local prof = PUI.DB.profile
  if not prof then return 0 end
  local n = 0
  local function move(old, new, v)
    if prof[new] == nil and v ~= nil then prof[new] = v end
    prof[old] = nil
    n = n + 1
  end
  for old, new in pairs(LEGACY) do if prof[old] ~= nil then move(old, new, prof[old]) end end
  if prof["np.friendlyNameOnly"] ~= nil then
    local bars = prof["np.friendlyNameOnly"] == false
    local grid = { players = {}, npcs = {} }
    for _, c in ipairs(CONTENT) do grid.players[c] = bars; grid.npcs[c] = bars end
    move("np.friendlyNameOnly", "np.friendly.bars", grid)
  end
  if prof["np.targetHighlight"] ~= nil then
    move("np.targetHighlight", "np.target.highlight", prof["np.targetHighlight"] == false and "none" or nil)
  end
  if prof["np.stacking"] ~= nil then
    local v = prof["np.stacking"]
    move("np.stacking", "np.system.stacking", v ~= "default" and v or nil)
  end
  if prof["np.scale"] ~= nil then
    local v = prof["np.scale"]
    move("np.scale", "np.system.scale", v ~= 1 and v or nil)
  end
  return n
end

local function syncFromDB()
  NP.MigrateLegacy()
  for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
end

NP.module = PUI:RegisterModule(OWNER, {
  label = "Nameplates",
  tooltip = "Phoenix nameplates: enemy and friendly styles, threat and NPC colours, cast bars with your interrupt, aura lanes, target and focus highlights, quest, execute and Mythic+ forces indicators.",
  enabledByDefault = false,
  schema = schema,
  onEnable = onEnable,
  onDisable = onDisable,
})
syncFromDB()
NP.SyncFromDB = syncFromDB
Kernel:On("PROFILES_CHANGED", function() if NP.MigrateLegacy() > 0 then syncFromDB() end end)
