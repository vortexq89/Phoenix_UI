local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Pulse (plan 5.21 "Pulse", 1.O "Encounter timers", "Pull / break / M+
-- countdown" and "Combat / encounter / stage timer"):
--  * boss timer bars drawn from the game's own encounter timeline
--    (C_EncounterTimeline: sorted event list, engine duration objects,
--    highlight events), never index-walking a fixed list, so a fight that
--    outruns the list still warns. With BigWigs or DBM loaded the bars are a
--    soft conflict: nothing changes until you pick (Coexist "pulse.timeline").
--  * the countdown bar: Raid Tools owns pull/break/key countdowns and fires
--    Kernel "COUNTDOWN"; Pulse only draws it.
--  * the page and display for the shared combat and encounter timer
--    (PUI.CombatTimer in Core): a small timer frame and a history of the last
--    fights. Embers, Ascent and the Quest Tracker read the same clock.
-- Event-driven; the only periodic Lua is the bar text pass and the timer text
-- (Ticker entries that exist only while something is shown).
local _, ns = ...
local Schema, Ticker, Secret, Kernel = PUI.Schema, PUI.Ticker, PUI.Secret, PUI.Kernel
local Bars = ns.Bars
local OWNER = "Pulse"
local PL = { active = false, history = {}, log = {} }
ns.PL = PL
PUI.Pulse = PL
PL.Bars = Bars

local s = {
  timeline = true, countdownBar = true, timer = false, timerWhen = "combat", timerFormat = "clock", timerHold = 5,
  timerSize = 22, timerLabel = true, history = 10, severityColors = true, highlight = true, countdownSound = false,
  colorCountdown = { r = 0.91, g = 0.64, b = 0.24, a = 1 }, colorNormal = { r = 0.36, g = 0.62, b = 0.95, a = 1 },
  colorHigh = { r = 0.95, g = 0.33, b = 0.35, a = 1 }, colorMedium = { r = 0.98, g = 0.72, b = 0.25, a = 1 },
  approximate = true,
}
PL.settings = s
local style = {}
for k, v in pairs(Bars.DEFAULT) do style[k] = v end
style.emphasisColor = { r = 1, g = 0.48, b = 0.1, a = 1 }
PL.style = style
local function did(w) PL.log[#PL.log + 1] = w; if #PL.log > 40 then table.remove(PL.log, 1) end end

-- Groups are built lazily (first bar or first enable).
function PL.Group()
  if not PL.group then
    PL.group = Bars.NewGroup(OWNER, "pulse", style)
    PUI.Layout:Place(PL.group.anchor, "pulse.bars")
  end
  return PL.group
end

-- Countdown bar (drawn from Raid Tools' shared state) ------------------------
local KIND_LABEL = { pull = "Pull", ["break"] = "Break", mplus = "Key" }
function PL.OnCountdown(c)
  if not PL.active then return end
  local g = PL.Group()
  if not c or not s.countdownBar then g:Release("countdown"); return end
  local left = c.deadline - GetTime()
  g:Acquire("countdown"):Fill({ name = KIND_LABEL[c.kind] or "Countdown", icon = 136106, color = s.colorCountdown,
    start = c.deadline - c.total, length = c.total, sortKey = left, autoRelease = true })
  if s.countdownSound and c.kind ~= "break" then PUI.Media:Alert(SOUNDKIT.READY_CHECK) end
  did("countdown " .. tostring(c.kind))
end

-- Encounter timeline ----------------------------------------------------------
function PL.TimelineAllowed()
  return PL.active and s.timeline and not PUI.Coexist:Yields("pulse.timeline")
end

local SEVERITY = { [0] = "colorNormal", [1] = "colorMedium", [2] = "colorHigh" }
-- Colour for an event: severity may be secret, so with severity colours on we
-- ask the game for the event colour (a colour object goes straight to the bar).
function PL.EventColor(id, info)
  if s.severityColors and C_EncounterTimeline.GetEventColor then
    local c = C_EncounterTimeline.GetEventColor(id)
    if c and not Secret.IsSecret(c) and c.r then return { r = c.r, g = c.g, b = c.b } end
    local sev = info and info.severity
    if sev ~= nil and not Secret.IsSecret(sev) and SEVERITY[sev] then return s[SEVERITY[sev]] end
  end
  return s.colorNormal
end

function PL.AddEvent(info)
  if not (PL.TimelineAllowed() and type(info) == "table") then return end
  local id = info.id -- never secret (documented NeverSecret)
  if id == nil then return end
  local name = info.spellName
  if s.approximate and info.isApproximate == true then name = nil end
  local g = PL.Group()
  local bar = g:Acquire("ev" .. id)
  bar:Fill({ name = name or info.spellName, icon = info.iconFileID, color = PL.EventColor(id, info),
    duration = C_EncounterTimeline.GetEventTimer(id),
    remaining = function() return C_EncounterTimeline.GetEventTimeRemaining(id) end })
  if s.approximate and info.isApproximate == true then bar.time:SetText("~") end
  did("event")
end
function PL.OnEventAdded(_, _, info) PL.AddEvent(info) end
function PL.OnEventRemoved(_, _, id) if PL.group and id ~= nil then PL.group:Release("ev" .. id) end end
function PL.OnEventHighlight(_, _, id)
  if not (PL.group and s.highlight and id ~= nil) then return end
  local f = PL.group.live["ev" .. id]
  if f then PUI.Glow:Start(f, "pulse", style.emphasisColor) end
end
-- Rebuild from the game's sorted list (after a reload, or when settings change).
function PL.Resync()
  if PL.group then
    for i = #PL.group.order, 1, -1 do local k = PL.group.order[i]; if k:sub(1, 2) == "ev" then PL.group:Release(k) end end
  end
  if not PL.TimelineAllowed() then return 0 end
  local list = C_EncounterTimeline.GetSortedEventList(style.max, 600, true, true) or {}
  for _, id in ipairs(list) do PL.AddEvent(C_EncounterTimeline.GetEventInfo(id)) end
  return #list
end

-- Combat and encounter timer display ----------------------------------------------
function PL.TimerWanted()
  if not (PL.active and s.timer) then return false end
  local T = PUI.CombatTimer
  local kind = T:Kind()
  local live = T:Running() or (T.stopped and GetTime() - T.stopped < s.timerHold)
  if not live then return false end
  if s.timerWhen == "encounter" then return kind == "encounter" end
  return true
end
function PL.TimerText()
  local T = PUI.CombatTimer
  local txt = T:Text(s.timerFormat)
  if not s.timerLabel then return txt end
  local e = T:Encounter()
  local label = (T:Kind() == "encounter") and (e and e.name or "Boss") or "Combat"
  return label .. "  " .. txt
end
function PL.BuildTimer()
  if PL.timerFrame then return PL.timerFrame end
  local f = PUI:CreateFrame("Frame", "PhoenixUIPulseTimer", UIParent, nil, OWNER)
  f:SetSize(160, 30)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.75)
  f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("BOTTOMLEFT"); f.accent:SetPoint("BOTTOMRIGHT"); f.accent:SetHeight(2)
  f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
  f.text = f:CreateFontString(nil, "OVERLAY"); f.text:SetPoint("CENTER")
  PL.timerFrame = f
  PUI.Layout:Place(f, "pulse.timer")
  return f
end
function PL.PaintTimer()
  local want = PL.TimerWanted()
  if want then
    local f = PL.BuildTimer()
    f.text:SetFontObject(PUI.Media:FontObject(s.timerSize >= 20 and "header" or "normal"))
    f.text:SetText(PL.TimerText())
    f:Show()
    if not Ticker:IsRegistered("pulse.timer") then Ticker:Register("pulse.timer", s.timerFormat == "tenths" and 0.1 or 0.5, PL.PaintTimer, OWNER) end
  else
    if PL.timerFrame then PL.timerFrame:Hide() end
    Ticker:Unregister("pulse.timer")
  end
end
-- History ring of finished fights (session only; Embers keeps the saved ones).
function PL.OnCombatTimer(what)
  if what == "stop" then
    local last = PUI.CombatTimer.last
    if last then
      table.insert(PL.history, 1, { kind = last.kind, seconds = last.seconds, name = last.encounter and last.encounter.name })
      while #PL.history > s.history do table.remove(PL.history) end
    end
  end
  PL.PaintTimer()
end
function PL.HistoryLines(n)
  local out = {}
  for i = 1, math.min(n or 5, #PL.history) do
    local h = PL.history[i]
    out[i] = string.format("%s  %s", h.name or (h.kind == "encounter" and "Boss" or "Combat"), PUI.CombatTimer.Format(h.seconds))
  end
  return out
end

-- Test bars (button on the page and /pui pulse test): plain sample timers.
PL.SAMPLES = { { "Annihilation", 136186, 8 }, { "Shadow Crash", 136201, 14 }, { "Soul Rend", 135945, 21 }, { "Phase 2", 134400, 33 } }
function PL.Test()
  local g = PL.Group()
  local now = GetTime()
  for i, x in ipairs(PL.SAMPLES) do
    g:Acquire("test" .. i):Fill({ name = x[1], icon = x[2], color = i == 1 and s.colorHigh or (i == 2 and s.colorMedium or s.colorNormal),
      start = now, length = x[3], sortKey = x[3], emphasis = i == 1 and s.highlight })
  end
  return g:Count()
end

local function restyle()
  if PL.group then PL.group:Restyle() end
end

local function onEnable(mod)
  PL.active = true
  mod:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", PL.OnEventAdded)
  mod:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED", PL.OnEventRemoved)
  mod:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT", PL.OnEventHighlight)
  PL.Resync()
  if PUI.RaidTools and PUI.RaidTools.countdown then PL.OnCountdown(PUI.RaidTools.countdown) end
  PL.PaintTimer()
end
local function onDisable()
  PL.active = false
  if PL.group then PL.group:ReleaseAll() end
  PL.PaintTimer()
end
Kernel:On("COUNTDOWN", PL.OnCountdown)
Kernel:On("COMBAT_TIMER", PL.OnCombatTimer)

local schema = {}
PL.schema = schema
local function key(name, def, target)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    if target == "style" then style[name] = v; restyle() else s[name] = v end
    if name == "timeline" or name == "approximate" or name == "severityColors" then if PL.active then PL.Resync() end end
    if name == "countdownBar" and PL.active then PL.OnCountdown(PUI.RaidTools and PUI.RaidTools.countdown) end
    if name:sub(1, 5) == "timer" then PL.PaintTimer() end
  end
  schema["pulse." .. name] = def
end
key("timeline", { type = "toggle", default = true, label = "Boss timer bars", mode = "simple",
  tooltip = "Bars for upcoming boss abilities, read from the game's own encounter timeline. With BigWigs or DBM loaded, you choose who shows them.",
  searchTags = { "boss", "timer", "bigwigs", "dbm", "timeline" } })
key("countdownBar", { type = "toggle", default = true, label = "Pull and break bar", mode = "simple",
  tooltip = "Draws the pull, break and key countdown that Raid Tools runs (yours or anyone's in the group)." })
key("countdownSound", { type = "toggle", default = false, label = "Countdown sound", tooltip = "Plays a short sound when a pull or key countdown starts." })
key("highlight", { type = "toggle", default = true, label = "Glow when an ability is close",
  tooltip = "A bar glows when the game marks the ability as about to happen (the timing comes from the game)." })
key("severityColors", { type = "toggle", default = true, label = "Colour by danger",
  tooltip = "Bars use the game's colour for how dangerous each ability is. Off: every bar uses the normal colour." })
key("approximate", { type = "toggle", default = true, label = "Mark rough timings",
  tooltip = "Abilities the game only estimates show a ~ until their time is firm." })
key("colorNormal", { type = "color", default = { r = 0.36, g = 0.62, b = 0.95, a = 1 }, label = "Normal colour", tooltip = "Colour for ordinary abilities." })
key("colorMedium", { type = "color", default = { r = 0.98, g = 0.72, b = 0.25, a = 1 }, label = "Dangerous colour", tooltip = "Colour for dangerous abilities when the game does not give one." })
key("colorHigh", { type = "color", default = { r = 0.95, g = 0.33, b = 0.35, a = 1 }, label = "Deadly colour", tooltip = "Colour for deadly abilities when the game does not give one." })
key("colorCountdown", { type = "color", default = { r = 0.91, g = 0.64, b = 0.24, a = 1 }, label = "Countdown colour", tooltip = "Colour of the pull, break and key bar." })
key("width", { type = "range", default = 240, min = 120, max = 420, step = 5, label = "Bar width", tooltip = "Width of each timer bar.", mode = "simple" }, "style")
key("height", { type = "range", default = 20, min = 12, max = 40, step = 1, label = "Bar height", tooltip = "Height of each timer bar." }, "style")
key("gap", { type = "range", default = 3, min = 0, max = 12, step = 1, label = "Space between bars", tooltip = "Gap between bars." }, "style")
key("max", { type = "range", default = 8, min = 1, max = 16, step = 1, label = "Most bars shown", tooltip = "Bars past this number wait until a slot frees up (soonest first)." }, "style")
key("grow", { type = "select", default = "down", choices = { "down", "up" }, choiceLabels = { down = "Downwards", up = "Upwards" },
  label = "Bars grow", tooltip = "Direction new bars are added." }, "style")
key("icon", { type = "toggle", default = true, label = "Ability icon", tooltip = "Shows the ability icon beside each bar." }, "style")
key("iconSide", { type = "select", default = "LEFT", choices = { "LEFT", "RIGHT" }, choiceLabels = { LEFT = "Left", RIGHT = "Right" },
  label = "Icon side", tooltip = "Which side of the bar the icon sits on." }, "style")
key("font", { type = "select", default = "small", choices = { "small", "normal", "header" }, choiceLabels = { small = "Small", normal = "Normal", header = "Large" },
  label = "Text size", tooltip = "Size of the ability name and time." }, "style")
key("timeFormat", { type = "select", default = "auto", choices = { "auto", "seconds", "tenths" },
  choiceLabels = { auto = "Tenths under 10 s", seconds = "Whole seconds", tenths = "Always tenths" }, label = "Time format", tooltip = "How the time left is written." }, "style")
key("alpha", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = "Bar opacity", tooltip = "Opacity of the bars." }, "style")
key("background", { type = "range", default = 0.55, min = 0, max = 1, step = 0.05, label = "Background opacity", tooltip = "Opacity of the empty part of each bar." }, "style")
key("spark", { type = "toggle", default = true, label = "Spark on the bar edge", tooltip = "A bright line where the bar is draining." }, "style")
key("timer", { type = "toggle", default = false, label = "Combat timer", mode = "simple",
  tooltip = "A small clock for the current fight. It is the one shared timer: the Embers title bar and the Mythic+ card read the same clock." })
key("timerWhen", { type = "select", default = "combat", choices = { "combat", "encounter" }, choiceLabels = { combat = "Any fight", encounter = "Boss fights only" },
  label = "Timer shows in", tooltip = "When the combat timer is shown." })
key("timerFormat", { type = "select", default = "clock", choices = { "clock", "tenths" }, choiceLabels = { clock = "3:42", tenths = "3:42.5" },
  label = "Timer format", tooltip = "How the fight time is written." })
key("timerHold", { type = "range", default = 5, min = 0, max = 30, step = 1, label = "Keep after the fight (s)", tooltip = "How long the final time stays on screen after a fight." })
key("timerSize", { type = "range", default = 22, min = 10, max = 36, step = 1, label = "Timer text size", tooltip = "Size of the combat timer text." })
key("timerLabel", { type = "toggle", default = true, label = "Name the fight", tooltip = "Writes the boss name (or Combat) before the time." })
key("history", { type = "range", default = 10, min = 1, max = 30, step = 1, label = "Fights in history", tooltip = "How many finished fights the Pulse page lists with their times." })
local ckey, cdef = PUI.Coexist:Define("pulse.timeline", { module = OWNER, job = "Boss timer bars", soft = true, addons = { "BigWigs", "DBM-Core" } })
cdef.owner = OWNER
local capply = cdef.apply
cdef.apply = function(v) capply(v); if PL.active then PL.Resync() end end
schema[ckey] = cdef
PUI.Layout:RegisterElement("pulse.bars", { label = "Pulse timer bars", owner = OWNER, size = { 240, 120 }, default = { point = "CENTER", x = 320, y = 120 } })
PUI.Layout:RegisterElement("pulse.timer", { label = "Combat timer", owner = OWNER, size = { 160, 30 }, default = { point = "TOP", x = 0, y = -90 } })

PUI.Slash:Register("pulse", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "test" then PL.Test()
  elseif word == "clear" then if PL.group then PL.group:ReleaseAll() end
  elseif word == "history" then for _, l in ipairs(PL.HistoryLines(s.history)) do PUI.Slash.Print(l) end
  else PUI.Slash.Print("/pui pulse test | clear | history") end
end, "Pulse timer bars: test, clear, history")

PL.module = PUI:RegisterModule(OWNER, {
  label = "Pulse", tooltip = "Boss timer bars from the game's encounter timeline, the pull and break bar, and the shared combat timer.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
