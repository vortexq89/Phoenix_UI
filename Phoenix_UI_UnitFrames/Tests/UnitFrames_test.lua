local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Unit Frames. Tests that enable the module restore every
-- touched setting and the module toggle in cleanup.
local _, ns = ...
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local UF, E = ns.UF, ns.Elements

local function keep(t, ...)
  local keys = { "module.UnitFrames", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
end

local function enable(t, ...)
  keep(t, ...)
  Schema:Set("module.UnitFrames", true)
  return UF.units
end

Tests:Add("UnitFrames", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.UnitFrames").default, false, "module defaults off")
  if Schema:Get("module.UnitFrames") then return end
  t:eq(UF.active, false, "inactive")
  t:eq(Ticker:IsRegistered("uf.polled"), false, "no polling ticker")
  t:eq(UF.module:RegisteredEventCount(), 0, "no module events")
  for _, o in pairs(UF.units) do
    t:eq(o.live, false, o.unit .. " not live")
    t:eq(next(o.tracker.events or {}) == nil or not o.tracker.events, true, o.unit .. " tracker has no events")
  end
end)

Tests:Add("UnitFrames", "every setting has a schema entry with apply", function(t)
  local n = 0
  for key, def in pairs(UF.schema) do
    n = n + 1
    t:ok(Schema:Def(key) == def, key .. " registered")
    t:eq(type(def.apply), "function", key .. " apply")
  end
  t:ok(n >= 7 * 11, "per-unit keys registered (" .. n .. ")")
end)

Tests:Add("UnitFrames", "enabling builds secure buttons and parks Blizzard frames", function(t)
  local units = enable(t)
  local o = units.player
  t:ok(o and o.live, "player frame live")
  local b = o.button
  t:eq(b:GetAttribute("unit"), "player", "unit attribute")
  t:eq(b:GetAttribute("type1"), "target", "left click targets")
  t:eq(b:GetAttribute("type2"), "togglemenu", "right click opens the menu")
  t:ok(rawget(_G, "ClickCastFrames")[b] == true, "registered for click-casting")
  t:ok(units.target and units.boss5, "target and boss frames built")
  t:eq(PUI.Layout:Frame("uf.player"), b, "placed through Layout (Studio)")
  t:ok(ns.Blizzard.IsParked("player"), "Blizzard player frame parked")
  if HARNESS then
    t:eq(PlayerFrame:GetParent(), ns.Blizzard.hider, "PlayerFrame reparented to the hider")
    t:eq(HARNESS.stateDrivers[UF.hider].visibility, "[petbattle] hide; show", "pet battle state driver")
    t:ok(HARNESS.unitWatch[units.target.button], "target visibility via unit watch")
    t:ok(units.target.tracker:IsEventRegistered("UNIT_HEALTH"), "health channel registered")
    t:ok(units.target.tracker:IsEventRegistered("UNIT_SPELLCAST_START"), "cast channel on for target")
    t:eq(units.player.tracker:IsEventRegistered("UNIT_SPELLCAST_START"), false, "cast channel off for player")
    t:eq(units.player.tracker:IsEventRegistered("UNIT_PORTRAIT_UPDATE"), false, "portrait channel off")
    t:eq(units.targettarget.tracker:IsEventRegistered("UNIT_HEALTH"), false, "polled units register no unit events")
  end
  t:ok(Ticker:IsRegistered("uf.polled"), "shared ToT/FoT ticker while shown")
end)

Tests:Add("UnitFrames", "settings apply live (size, text, channels, source)", function(t)
  local units = enable(t, "uf.player.width", "uf.player.text.left", "uf.player.portrait", "uf.player.source",
    "uf.targettarget.source", "uf.focustarget.source")
  local o = units.player
  Schema:Set("uf.player.width", 260)
  t:eq(o.button:GetWidth(), 260, "width applied")
  Schema:Set("uf.player.text.left", "health:percent")
  if HARNESS then t:eq(o.texts.left:GetText(), "80%", "text zone re-rendered") end
  Schema:Set("uf.player.portrait", "2d")
  t:ok(o.portrait:IsShown(), "portrait shown")
  if HARNESS then t:ok(o.tracker:IsEventRegistered("UNIT_PORTRAIT_UPDATE"), "portrait channel registered on demand") end
  Schema:Set("uf.player.source", "blizzard")
  t:eq(o.live, false, "Phoenix player frame off")
  t:eq(ns.Blizzard.IsParked("player"), false, "Blizzard player frame restored")
  Schema:Set("uf.targettarget.source", "hidden")
  Schema:Set("uf.focustarget.source", "hidden")
  t:eq(Ticker:IsRegistered("uf.polled"), false, "ticker removed when no polled frame is shown")
end)

Tests:Add("UnitFrames", "source change in combat waits for combat to end", function(t)
  local units = enable(t, "uf.focus.source")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  Schema:Set("uf.focus.source", "hidden")
  t:eq(units.focus.live, true, "unchanged in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(units.focus.live, false, "applied after combat")
end)

Tests:Add("UnitFrames", "secret values only reach widgets", function(t)
  local units = enable(t, "uf.colorMode", "uf.player.text.left", "uf.player.text.right", "uf.healPrediction")
  if not HARNESS then return end
  HARNESS.secretMode, HARNESS.casting = true, true
  t:cleanup(function() HARNESS.secretMode, HARNESS.casting = false, false end)
  Schema:Set("uf.healPrediction", true)
  for _, mode in ipairs({ "class", "reaction", "gradient", "accent" }) do
    Schema:Set("uf.colorMode", mode)
    for _, tag in ipairs(ns.Tags.order) do
      Schema:Set("uf.player.text.left", tag)
      E.UpdateAll(units.player)
      E.UpdateAll(units.target)
    end
  end
  t:ok(units.target.cast:IsShown(), "cast bar shown from a duration object")
  t:ok(units.target.cast.timer ~= nil, "SetTimerDuration used")
  t:ok(units.target.ind.raidMarker:IsShown(), "secret raid marker index drawn through the sprite sheet")
end)

Tests:Add("UnitFrames", "disabling releases events, drivers and Blizzard frames", function(t)
  local units = enable(t)
  Schema:Set("module.UnitFrames", false)
  t:eq(UF.active, false, "inactive")
  t:eq(Ticker:IsRegistered("uf.polled"), false, "ticker gone")
  for unit, o in pairs(units) do
    t:eq(o.live, false, unit .. " not live")
    if HARNESS then t:eq(next(o.tracker.events), nil, unit .. " tracker silent") end
  end
  t:eq(ns.Blizzard.IsParked("player"), false, "Blizzard frames restored")
  if HARNESS then
    t:eq(PlayerFrame:GetParent(), UIParent, "PlayerFrame back on UIParent")
    t:eq(HARNESS.stateDrivers[UF.hider].visibility, nil, "state driver removed")
    t:eq(HARNESS.unitWatch[units.target.button], nil, "unit watch removed")
  end
end)
