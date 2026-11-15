local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Spark (plan 5.21 "Spark", 1.O rows "Combat enter/leave alert", "Item /
-- potion cooldown ready", "Combat text CVars", "Loot / money / rep / XP
-- text"; mockup 09; MSBT parity 15.7 rebuilt in Phoenix's own code).
-- Settings inherit event row -> area -> master. Blizzard's own combat text is
-- three switches (outgoing, incoming, notifications), all turned off at first
-- install through the CVar ledger and restored when a switch or Spark goes off.
-- Conflict: with MikScrollingBattleText loaded, nothing changes until you pick.
local _, ns = ...
local Schema = PUI.Schema
local E, F = ns.Engine, ns.Feed
local OWNER = "Spark"
local SP = { active = false }
ns.SP = SP
PUI.Spark = SP
SP.Engine, SP.Feed = E, F

local S = { master = {}, areas = {}, rows = {} }
SP.settings = S
for _, id in ipairs(E.AREAS) do S.areas[id] = {} end
for _, r in ipairs(F.ROWS) do S.rows[r.id] = {} end
E.master = S.master
E.settingsFor = function(id) return S.areas[id] end

-- Blizzard combat text: CVars per category (unknown names are skipped by the ledger).
SP.BLIZZARD = {
  outgoing = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatHealing", "floatingCombatTextPetMeleeDamage", "floatingCombatTextPetSpellDamage" },
  incoming = { "enableFloatingCombatText" },
  notifications = { "floatingCombatTextCombatState", "floatingCombatTextReactives", "floatingCombatTextLowManaHealth", "floatingCombatTextHonorGains",
    "floatingCombatTextRepChanges", "floatingCombatTextEnergyGains", "floatingCombatTextAuras", "floatingCombatTextDodgeParryMiss" },
}
SP.BLIZZARD_LABELS = { outgoing = "Outgoing", incoming = "Incoming", notifications = "Notifications" }
function SP.ApplyBlizzard()
  for cat, list in pairs(SP.BLIZZARD) do
    local off = SP.active and S.master["blizz_" .. cat]
    for _, cvar in ipairs(list) do
      if off then PUI.CVars:Set(OWNER, cvar, "0") else PUI.CVars:Restore(OWNER, cvar) end
    end
  end
end

-- Test: three sample lines through each area (the preview's "fire samples").
function SP.Test()
  local n = 0
  local samples = {
    { "inDamage", { amount = 12480 }, { crit = true } }, { "inHeal", { amount = 8400 } }, { "inAvoid", { event = "Dodge" } },
    { "outDamage", { amount = 48210, spell = "Mortal Strike" }, { crit = true } }, { "outDamage", { amount = 1200, spell = "Rend" }, { mergeKey = "rend", plainAmount = 1200 } },
    { "outHeal", { amount = 6200, spell = "Heal" } }, { "combatIn", {} }, { "money", { spell = "1g 20s" } }, { "xp", { amount = 1200 } },
  }
  for _, x in ipairs(samples) do if F.Emit(x[1], x[2], x[3]) then n = n + 1 end end
  return n
end

local function onEnable(mod)
  SP.active = true
  for _, id in ipairs(E.AREAS) do E.Area(id) end
  F.Enable(mod, S)
  SP.ApplyBlizzard()
end
local function onDisable()
  SP.active = false
  F.Disable()
  E.Clear()
  SP.ApplyBlizzard()
end

-- Schema ----------------------------------------------------------------------------
local schema = {}
SP.schema = schema
local function reg(k, def, target, field)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v)
    target[field] = v
    if field:sub(1, 6) == "blizz_" then SP.ApplyBlizzard() end
  end
  schema[k] = def
end
local M = S.master
reg("spark.blizz_outgoing", { type = "toggle", default = true, mode = "simple", label = "Turn off Blizzard's outgoing combat text",
  tooltip = "While Spark is on, the game's own damage and healing numbers over enemies are off. Your old setting comes back when this or Spark is off.",
  searchTags = { "sct", "floating", "combat text", "blizzard" } }, M, "blizz_outgoing")
reg("spark.blizz_incoming", { type = "toggle", default = true, mode = "simple", label = "Turn off Blizzard's incoming combat text",
  tooltip = "While Spark is on, the game's own text over your character is off. Restored when this or Spark is off." }, M, "blizz_incoming")
reg("spark.blizz_notifications", { type = "toggle", default = true, mode = "simple", label = "Turn off Blizzard's combat notifications",
  tooltip = "While Spark is on, the game's combat state, reactive, honor and reputation popups are off. Restored when this or Spark is off." }, M, "blizz_notifications")
reg("spark.capOn", { type = "toggle", default = true, mode = "simple", label = "Line cap in big pulls",
  tooltip = "When too many lines come at once, the extra ones are counted and shown as one \"+N more\" line." }, M, "capOn")
reg("spark.merge", { type = "toggle", default = true, label = "Merge repeated hits", tooltip = "Hits from the same spell close together become one line (Rend x5)." }, M, "merge")
reg("spark.mergeWindow", { type = "range", default = 0.3, min = 0, max = 1.5, step = 0.05, label = "Merge window (s)", tooltip = "How long Spark waits to merge repeated hits." }, M, "mergeWindow")
reg("spark.shortNumbers", { type = "toggle", default = true, mode = "simple", label = "Short numbers", tooltip = "12.4K instead of 12,400." }, M, "shortNumbers")
reg("spark.critScale", { type = "range", default = 1.5, min = 1, max = 3, step = 0.1, label = "Critical hit size", tooltip = "How much bigger critical hits are." }, M, "critScale")
reg("spark.outline", { type = "select", default = "OUTLINE", choices = { "NONE", "OUTLINE", "THICKOUTLINE" },
  choiceLabels = { NONE = "None", OUTLINE = "Thin", THICKOUTLINE = "Thick" }, label = "Text outline", tooltip = "Outline around combat text." }, M, "outline")
reg("spark.icons", { type = "toggle", default = true, label = "Spell icons", tooltip = "Shows the spell or item icon beside a line." }, M, "icons")
reg("spark.speed", { type = "range", default = 1, min = 0.5, max = 2, step = 0.05, label = "Animation speed", tooltip = "Speed of every scroll area." }, M, "speed")
reg("spark.schoolColors", { type = "toggle", default = true, label = "Damage school colours", tooltip = "Fire is orange, frost light blue and so on." }, M, "schoolColors")
reg("spark.outgoingMode", { type = "select", default = "confident", choices = { "confident", "all" },
  choiceLabels = { confident = "Only hits Spark is sure are mine", all = "All hits on my target (unsure ones without a name)" },
  label = "Outgoing hits", tooltip = "There is no combat log in Midnight: Spark works out your hits from your own casts." }, M, "outgoingMode")
reg("spark.attributionWindow", { type = "range", default = 0.6, min = 0.2, max = 1.5, step = 0.05, label = "Attribution window (s)",
  tooltip = "A hit on your target this soon after your cast counts as yours." }, M, "attributionWindow")
reg("spark.items", { type = "list", default = { "5512" }, maxItems = 30, label = "Items to watch", tooltip = "Item IDs that say when they are ready again (Healthstone is 5512). Potions you add here work the same." }, M, "items")
reg("spark.itemThreshold", { type = "range", default = 10, min = 2, max = 120, step = 1, label = "Only cooldowns longer than (s)", tooltip = "Short item cooldowns are not announced." }, M, "itemThreshold")
reg("spark.lootQuality", { type = "range", default = 1, min = 0, max = 7, step = 1, label = "Lowest loot quality", tooltip = "0 poor, 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary, 6 artifact, 7 heirloom." }, M, "lootQuality")

for _, id in ipairs(E.AREAS) do
  local d, A = E.AREA_DEFAULTS[id], S.areas[id]
  local L = E.AREA_LABELS[id]
  local p = "spark.area." .. id .. "."
  reg(p .. "enabled", { type = "toggle", default = true, mode = "simple", label = L .. ": on", tooltip = "Shows the " .. L:lower() .. " scroll area." }, A, "enabled")
  reg(p .. "behaviour", { type = "select", default = d.behaviour, choices = { "scroll", "parabola", "static" },
    choiceLabels = { scroll = "Straight", parabola = "Curve", static = "Stay in place" }, label = L .. ": animation", tooltip = "How lines move." }, A, "behaviour")
  reg(p .. "direction", { type = "select", default = d.direction, choices = { "up", "down" }, choiceLabels = { up = "Up", down = "Down" },
    label = L .. ": direction", tooltip = "Which way lines scroll." }, A, "direction")
  reg(p .. "align", { type = "select", default = d.align, choices = { "LEFT", "CENTER", "RIGHT" }, choiceLabels = { LEFT = "Left", CENTER = "Centre", RIGHT = "Right" },
    label = L .. ": text align", tooltip = "Where text lines up in the area." }, A, "align")
  reg(p .. "size", { type = "range", default = d.size, min = 10, max = 48, step = 1, label = L .. ": text size", tooltip = "Normal text size in this area." }, A, "size")
  reg(p .. "distance", { type = "range", default = 160, min = 40, max = 400, step = 5, label = L .. ": scroll height", tooltip = "How far lines travel." }, A, "distance")
  reg(p .. "duration", { type = "range", default = 2.2, min = 0.6, max = 6, step = 0.1, label = L .. ": time on screen (s)", tooltip = "How long a line stays." }, A, "duration")
  reg(p .. "alpha", { type = "range", default = 1, min = 0.2, max = 1, step = 0.05, label = L .. ": opacity", tooltip = "Opacity of the text." }, A, "alpha")
  reg(p .. "cap", { type = "range", default = id == "static" and 3 or 12, min = 1, max = 40, step = 1, label = L .. ": most lines per second",
    tooltip = "The line cap for this area in big pulls." }, A, "cap")
  PUI.Layout:RegisterElement("spark." .. id, { label = "Spark: " .. L, owner = OWNER, size = { 260, 200 }, default = { point = "CENTER", x = d.x, y = d.y } })
end

local AREA_CHOICES = { "incoming", "outgoing", "notification", "static" }
for _, r in ipairs(F.ROWS) do
  local R = S.rows[r.id]
  local p = "spark.ev." .. r.id .. "."
  reg(p .. "on", { type = "toggle", default = true, mode = (r.id == "outDamage" or r.id == "inDamage" or r.id == "loot") and "simple" or "advanced",
    label = r.label, tooltip = "Shows " .. r.label:lower() .. " in Spark." }, R, "on")
  reg(p .. "area", { type = "select", default = r.area, choices = AREA_CHOICES, choiceLabels = E.AREA_LABELS, label = r.label .. ": area", tooltip = "Which scroll area shows it." }, R, "area")
  reg(p .. "color", { type = "color", default = { r = r.color.r, g = r.color.g, b = r.color.b, a = 1 }, label = r.label .. ": colour", tooltip = "Text colour." }, R, "color")
  reg(p .. "template", { type = "text", default = "", label = r.label .. ": message",
    tooltip = "Empty uses \"" .. r.template .. "\". Tokens: %a amount, %s spell or item, %c count, %e event, %t trailer (crushing, glancing)." }, R, "template")
end
local ckey, cdef = PUI.Coexist:Define("spark", { module = OWNER, job = "Scrolling combat text", addons = { "MikScrollingBattleText", "Parrot", "xCT+" } })
cdef.owner = OWNER
schema[ckey] = cdef

PUI.Slash:Register("spark", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "test" then SP.Test() elseif word == "clear" then E.Clear() else PUI.Slash.Print("/pui spark test | clear") end
end, "Spark combat text: test, clear")

SP.module = PUI:RegisterModule(OWNER, {
  label = "Spark", tooltip = "Scrolling combat text in four areas, combat in and out, item ready, loot, money, reputation and XP. Turns Blizzard's combat text off while on.",
  enabledByDefault = true, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return PUI.Coexist:Allows("spark") end,
})
for k, def in pairs(schema) do if def.type ~= "layout" and k:sub(1, 6) == "spark." then def.apply(Schema:Get(k)) end end
