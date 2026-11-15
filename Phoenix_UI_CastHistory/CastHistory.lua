local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Cast History (plan 1.O owner of spell/cast history; mockup 17; TrufiGCD
-- parity 15.7, all 10 features, rebuilt in Phoenix's own code):
--  1 strip per unit (you, target, focus, party 1-4, arena 1-3), each on/off
--  2 direction   3 icon size and spacing   4 number of icons
--  5 moving strip or still-and-fade, with speed   6 catch-up speed
--  7 cancelled and interrupted crosses   8 spell blocklist (built-in + yours)
--    and item blocklist, Ctrl+Alt+click to add, picker with every name match
--  9 tooltip on hover, pause on hover, print link and ID (opt-in)
-- 10 where to show (always, in combat, in instances, in PvP)
-- Plus: held empowered casts, a glow on the newest icon, PvP trinket in
-- faction art, zoom and border, profiles through Core profiles only.
-- Unit events are registered per watched unit only while the module is on.
local _, ns = ...
local Schema = PUI.Schema
local T, SR = ns.Tracker, ns.Strip
local OWNER = "CastHistory"
local CH = { active = false, frames = {} }
ns.CH = CH
PUI.CastHistory = CH
CH.Tracker, CH.Strip = T, SR

local s = { units = {} }
CH.settings = s
SR.s = s

CH.UNITS = { "player", "target", "focus", "party1", "party2", "party3", "party4", "arena1", "arena2", "arena3" }
CH.UNIT_LABELS = { player = "You", target = "Target", focus = "Focus", party1 = "Party 1", party2 = "Party 2", party3 = "Party 3", party4 = "Party 4",
  arena1 = "Arena 1", arena2 = "Arena 2", arena3 = "Arena 3" }
CH.UNIT_DEFAULT = { player = true, target = true, arena1 = true, arena2 = true, arena3 = true }
CH.EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP" }

local sink = {
  add = function(unit, spellID, kind) return SR.Add(unit, spellID, kind, s) end,
  mark = function(icon, state) SR.Mark(icon, state) end,
}
function CH.OnEvent(event, unit, guid, spellID)
  if not (CH.active and s.units[unit]) then return end
  return T.On(event, unit, guid, spellID, sink, s)
end

-- Where to show (TrufiGCD feature 10).
function CH.Visible()
  if not CH.active then return false end
  if s.where == "combat" then return PUI.CombatTimer:Running() end
  local inside, kind = IsInInstance()
  if s.where == "instance" then return inside == true end
  if s.where == "pvp" then return kind == "arena" or kind == "pvp" end
  return true
end
function CH.PaintVisibility()
  for _, unit in ipairs(CH.UNITS) do
    local st = SR.strips[unit]
    if st then st.frame:SetShown(CH.Visible() and s.units[unit] == true) end
  end
end

local function unitFrame(unit)
  local f = CH.frames[unit]
  if not f then
    f = PUI:CreateFrame("Frame", nil, nil, nil, OWNER)
    f:SetScript("OnEvent", function(_, event, u, guid, spellID) if u == unit then CH.OnEvent(event, u, guid, spellID) end end)
    CH.frames[unit] = f
  end
  return f
end
function CH.Wire()
  for _, unit in ipairs(CH.UNITS) do
    local f = unitFrame(unit)
    local on = CH.active and s.units[unit] == true
    for _, ev in ipairs(CH.EVENTS) do
      if on then f:RegisterUnitEvent(ev, unit) else f:UnregisterEvent(ev) end
    end
    if on then SR.Get(unit, s) end
  end
  CH.PaintVisibility()
end

function ns.AddBlock(spellID)
  local list = Schema:Get("ch.blockSpells")
  for _, v in ipairs(list) do if tonumber(v) == spellID then return false end end
  list[#list + 1] = tostring(spellID)
  Schema:Set("ch.blockSpells", list)
  PUI.Slash.Print(string.format("cast history: %s (ID %d) added to your blocklist", C_Spell.GetSpellName(spellID) or "?", spellID))
  return true
end
CH.AddBlock = ns.AddBlock
-- In-combat visibility follows the shared combat timer (start and stop).
PUI.Kernel:On("COMBAT_TIMER", function() if CH.active then CH.PaintVisibility() end end)

-- Test: sample casts on your strip (button on the page, /pui casthistory test).
CH.SAMPLES = { 116, 133, 2948, 11366, 108853, 190319 }
function CH.Test()
  local unit = "player"
  for i, id in ipairs(CH.SAMPLES) do
    local b = SR.Add(unit, id, i == 3 and "empower" or "instant", s)
    if i == 2 then SR.Mark(b, "interrupted") end
  end
  return #SR.Get(unit, s).icons
end

local function onEnable(mod)
  CH.active = true
  mod:RegisterEvent("PLAYER_ENTERING_WORLD", CH.PaintVisibility)
  CH.Wire()
end
local function onDisable()
  CH.active = false
  CH.Wire()
  SR.ClearAll()
  wipe(T.current)
end

local schema = {}
CH.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    s[name] = v
    if name == "blockSpells" or name == "blockItems" then T.RebuildBlocks(s.blockSpells, s.blockItems) end
    if name == "mode" then SR.ClearAll() end
    if name == "where" then CH.PaintVisibility() end
    SR.Restyle(s)
  end
  schema["ch." .. name] = def
end
for _, unit in ipairs(CH.UNITS) do
  schema["ch.unit." .. unit] = { type = "toggle", default = CH.UNIT_DEFAULT[unit] == true, owner = OWNER,
    mode = (unit == "player" or unit == "target") and "simple" or "advanced",
    label = "Show: " .. CH.UNIT_LABELS[unit], tooltip = "A strip of recent casts for " .. CH.UNIT_LABELS[unit]:lower() .. ".",
    apply = function(v) s.units[unit] = v; CH.Wire() end }
  PUI.Layout:RegisterElement("casthistory." .. unit, { label = "Cast history: " .. CH.UNIT_LABELS[unit], owner = OWNER, size = { 200, 30 },
    default = { point = "CENTER", x = unit:find("arena") and 360 or (unit:find("party") and -360 or 0),
      y = (unit == "player" and -160) or (unit == "target" and -120) or (unit == "focus" and -80) or (100 - 40 * (tonumber(unit:match("%d") or 1))) } })
end
key("mode", { type = "select", default = "move", choices = { "move", "fade" }, choiceLabels = { move = "Moving strip", fade = "Still and fade" }, mode = "simple",
  label = "Style", tooltip = "Moving strip: new casts push the old ones along. Still and fade: icons stay put and fade out." })
key("direction", { type = "select", default = "LEFT", choices = { "LEFT", "RIGHT", "UP", "DOWN" }, choiceLabels = { LEFT = "Left", RIGHT = "Right", UP = "Up", DOWN = "Down" },
  label = "Direction", tooltip = "Which way older casts move.", mode = "simple" })
key("iconSize", { type = "range", default = 30, min = 14, max = 64, step = 1, label = "Icon size", tooltip = "Size of each cast icon.", mode = "simple" })
key("count", { type = "range", default = 8, min = 1, max = 20, step = 1, label = "Number of icons", tooltip = "How many casts each strip shows." })
key("spacing", { type = "range", default = 2, min = 0, max = 12, step = 1, label = "Spacing", tooltip = "Gap between icons." })
key("speed", { type = "range", default = 0.25, min = 0.05, max = 1.5, step = 0.05, label = "Slide time (s)", tooltip = "How long an icon takes to move one place." })
key("catchUp", { type = "range", default = 2.5, min = 1, max = 6, step = 0.25, label = "Catch-up speed", tooltip = "When casts come faster than the strip moves, it speeds up this much." })
key("fadeAfter", { type = "range", default = 6, min = 1, max = 30, step = 0.5, label = "Fade after (s)", tooltip = "Still-and-fade style: how long an icon stays." })
key("showCancelled", { type = "toggle", default = true, label = "Cross on cancelled casts", tooltip = "A grey cross when a cast is stopped before it finishes." })
key("showInterrupted", { type = "toggle", default = true, label = "Cross on interrupted casts", tooltip = "A red cross when a cast is interrupted.", mode = "simple" })
key("showChannel", { type = "toggle", default = true, label = "Channels", tooltip = "Adds channelled spells to the strip." })
key("empowerHeld", { type = "toggle", default = true, label = "Mark held empowered casts", tooltip = "Empowered spells show \"hold\" until released." })
key("glowNewest", { type = "toggle", default = true, label = "Glow on the newest icon", tooltip = "The latest cast glows.", mode = "simple" })
key("glowStyle", { type = "select", default = "solid", choices = PUI.Glow.STYLES, choiceLabels = PUI.Glow.STYLE_LABELS, label = "Newest icon glow", tooltip = "How the newest icon glows." })
key("builtIn", { type = "toggle", default = true, label = "Hide auto attacks and similar", tooltip = "Built-in blocklist: auto attack, auto shot, shoot and the global cooldown." })
key("blockSpells", { type = "list", default = {}, maxItems = 200, label = "Spell blocklist", tooltip = "Spell IDs never shown. Ctrl+Alt+click an icon to add it; the picker lists every spell matching a name." })
key("blockItems", { type = "list", default = {}, maxItems = 100, label = "Item blocklist", tooltip = "Item IDs whose use is never shown (for example a Healthstone, 5512)." })
key("clickBlock", { type = "toggle", default = true, label = "Ctrl+Alt+click adds to the blocklist", tooltip = "Ctrl+Alt+click a cast icon to hide that spell from now on." })
key("tooltip", { type = "toggle", default = true, label = "Tooltip on hover", tooltip = "Shows the spell tooltip when you point at an icon." })
key("pauseOnHover", { type = "toggle", default = true, label = "Pause on hover", tooltip = "The strip stops moving while you point at it." })
key("printLink", { type = "toggle", default = false, label = "Shift+click prints name and ID", tooltip = "Shift+click an icon to print the spell name and ID in chat (off so hovering never spams)." })
key("trinketArt", { type = "toggle", default = true, label = "PvP trinket in faction art", tooltip = "The PvP trinket shows the Horde or Alliance medal." })
key("zoom", { type = "toggle", default = true, label = "Zoom icons", tooltip = "Trims the icon edges." })
key("border", { type = "toggle", default = true, label = "Icon border", tooltip = "A thin dark border around each icon." })
key("where", { type = "select", default = "always", choices = { "always", "combat", "instance", "pvp" },
  choiceLabels = { always = "Always", combat = "In combat", instance = "In instances", pvp = "In arenas and battlegrounds" },
  label = "Where to show", tooltip = "When cast history strips are shown.", mode = "simple" })

PUI.Slash:Register("casthistory", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  if word == "test" then CH.Test()
  elseif word == "find" then for _, m in ipairs(T.Find(arg)) do PUI.Slash.Print(string.format("%d  %s", m.id, tostring(m.name))) end
  elseif word == "block" and tonumber(arg) then ns.AddBlock(tonumber(arg))
  elseif word == "clear" then SR.ClearAll()
  else PUI.Slash.Print("/pui casthistory test | find <name> | block <id> | clear") end
end, "Cast history: test, find a spell, block, clear")

CH.module = PUI:RegisterModule(OWNER, {
  label = "Cast History", tooltip = "Recent casts for you, your target, focus, party and arena enemies. The one owner of spell history; the damage meter links here.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
