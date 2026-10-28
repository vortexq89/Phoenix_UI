local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Unit Frames. Tests that enable the module restore every
-- touched setting and the module toggle in cleanup.
local _, ns = ...
local H = rawget(_G, "HARNESS") -- the offline harness, nil in game
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
  if H then
    t:eq(PlayerFrame:GetParent(), ns.Blizzard.hider, "PlayerFrame reparented to the hider")
    t:eq(H.stateDrivers[UF.hider].visibility, "[petbattle] hide; show", "pet battle state driver")
    t:ok(H.unitWatch[units.target.button], "target visibility via unit watch")
    t:ok(units.target.tracker:IsEventRegistered("UNIT_HEALTH"), "health channel registered")
    t:ok(units.target.castbar and units.target.castbar.enabled, "target cast bar on the shared PUI.CastBar")
    t:eq(units.player.castbar, nil, "no Unit Frames cast bar for the player (Resource Bars owns it)")
    t:eq(units.target.tracker:IsEventRegistered("UNIT_SPELLCAST_START"), false, "no per-frame cast events (one dispatcher)")
    t:ok(units.player.tracker:IsEventRegistered("UNIT_PORTRAIT_UPDATE"), "Ember look: player portrait channel on")
    t:eq(units.focus.tracker:IsEventRegistered("UNIT_PORTRAIT_UPDATE"), false, "portrait off: no portrait channel")
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
  if H then t:eq(o.texts.left:GetText(), "80%", "text zone re-rendered") end
  Schema:Set("uf.player.portrait", "2d")
  t:ok(o.portrait:IsShown(), "portrait shown")
  if H then t:ok(o.tracker:IsEventRegistered("UNIT_PORTRAIT_UPDATE"), "portrait channel registered on demand") end
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
  if not H then return end
  H.secretMode, H.casting = true, true
  t:cleanup(function() H.secretMode, H.casting = false, false end)
  Schema:Set("uf.healPrediction", true)
  for _, mode in ipairs({ "class", "reaction", "gradient", "accent" }) do
    Schema:Set("uf.colorMode", mode)
    for _, tag in ipairs(ns.Tags.order) do
      Schema:Set("uf.player.text.left", tag)
      E.UpdateAll(units.player)
      E.UpdateAll(units.target)
    end
  end
  units.target.castbar:Refresh()
  t:ok(units.target.castbar.frame:IsShown(), "cast bar shown from a duration object")
  t:ok(units.target.castbar.status.timer ~= nil, "SetTimerDuration used")
  t:ok(units.target.ind.raidMarker:IsShown(), "secret raid marker index drawn through the sprite sheet")
end)

Tests:Add("UnitFrames", "disabling releases events, drivers and Blizzard frames", function(t)
  local units = enable(t)
  Schema:Set("module.UnitFrames", false)
  t:eq(UF.active, false, "inactive")
  t:eq(Ticker:IsRegistered("uf.polled"), false, "ticker gone")
  for unit, o in pairs(units) do
    t:eq(o.live, false, unit .. " not live")
    if H then t:eq(next(o.tracker.events), nil, unit .. " tracker silent") end
  end
  t:eq(ns.Blizzard.IsParked("player"), false, "Blizzard frames restored")
  if H then
    t:eq(PlayerFrame:GetParent(), UIParent, "PlayerFrame back on UIParent")
    t:eq(H.stateDrivers[UF.hider].visibility, nil, "state driver removed")
    t:eq(H.unitWatch[units.target.button], nil, "unit watch removed")
  end
end)

-- Step 3 additions ------------------------------------------------------------------
local Styles, UFA, AB = ns.Styles, ns.UFAuras, ns.AuraBars

Tests:Add("UnitFrames", "looks resolve, and each part can be changed on its own", function(t)
  for _, look in ipairs(Styles.order) do
    local r = Styles.Resolve(look, {})
    t:ok(r.borderPx ~= nil and r.bgAlpha ~= nil and r.portrait ~= nil, look .. " resolves every part")
  end
  t:eq(Styles.Resolve("glass", {}).portrait, "class", "glass uses class-icon portraits")
  t:eq(Styles.Resolve("ember", { border = "look" }).border, "thick", "'look' follows the look")
  t:eq(Styles.Resolve("ember", { border = "none" }).borderPx, 0, "an own choice wins over the look")
  t:eq(Styles.Resolve("nope", {}).border, "thick", "unknown look falls back to Ember")
  local units = enable(t, "uf.style", "uf.border")
  Schema:Set("uf.style", "glass")
  t:eq(UF.settings.style, "glass", "look switches live")
  Schema:Set("uf.border", "none")
  t:eq(UF.settings.border, "none", "border applies live")
  t:ok(units.player.button ~= nil, "frames still built")
end)

Tests:Add("UnitFrames", "cast bars use PUI.CastBar and turn off live", function(t)
  local units = enable(t, "uf.target.castbar")
  t:ok(units.target.castbar.enabled, "target cast bar enabled")
  Schema:Set("uf.target.castbar", false)
  t:ok(not units.target.castbar.enabled, "turning the cast bar off disables it")
  Schema:Set("uf.target.castbar", true)
  t:ok(units.target.castbar.enabled, "and back on, no reload")
end)

Tests:Add("UnitFrames", "auras: plain filters map to engine tokens, count 0 turns a kind off", function(t)
  t:eq(UFA.FilterFor("buffs", "all"), PUI.Auras.Filter("HELPFUL"), "all buffs")
  t:eq(UFA.FilterFor("debuffs", "dispellable"), PUI.Auras.Filter("HARMFUL", "RAID_PLAYER_DISPELLABLE"), "dispellable debuffs")
  for kind, list in pairs(UFA.FILTERS) do
    for _, c in ipairs(list) do t:ok(UFA.FilterFor(kind, c) ~= nil, kind .. " " .. c .. " has a filter") end
  end
  local units = enable(t, "uf.target.auras.debuffs.max")
  local o = units.target
  t:ok(o.auras and o.auras.debuffs, "target debuffs configured through PUI.Auras")
  t:eq(Schema:Validate(Schema:Def("uf.target.auras.debuffs.max"), 0), false, "count below 1 is rejected (use the toggle)")
  Schema:Set("uf.target.auras.debuffs.max", 3)
  local st = o.auras.debuffs:GroupState("debuffs")
  t:eq(st and st.cap, 3, "count applies live to the engine group")
end)

Tests:Add("UnitFrames", "where to show: alpha only, with a reason", function(t)
  local units = enable(t, "uf.focus.visibility", "uf.focus.hiddenAlpha")
  Schema:Set("uf.focus.hiddenAlpha", 0)
  Schema:Set("uf.focus.visibility", { mode = "never" })
  t:eq(units.focus.button.alpha, 0, "hidden by alpha, so it is combat-safe")
  local _, why = PUI.Visibility:Why("uf.focus")
  t:ok(type(why) == "string" and why ~= "", "a 'why hidden' reason is available")
  Schema:Set("uf.focus.visibility", { mode = "always" })
  t:eq(units.focus.button.alpha, 1, "shown again live")
  t:ok(PUI.Visibility.Validate({ mode = "always" }), "valid rule")
  t:ok(not PUI.Visibility.Validate({ mode = "sometimes" }), "unknown mode rejected")
  t:ok(type(PUI.Visibility.Describe({ mode = "never" })) == "string", "rule has a plain description")
end)

Tests:Add("UnitFrames", "test frames and copy settings", function(t)
  local units = enable(t, "uf.boss.width", "uf.focus.width")
  t:ok(UF.SetTestMode(true), "test mode on")
  CQ.Drain()
  t:ok(units.boss3.button:IsShown(), "boss frames shown for setting up")
  UF.SetTestMode(false)
  CQ.Drain()
  t:eq(UF.test, false, "test mode off")
  if H then t:ok(H.unitWatch[units.boss3.button], "unit watch restored") end
  Schema:Set("uf.boss.width", 211)
  t:ok(UF.CopyGroup("boss", "focus") >= 1, "settings copied")
  t:eq(Schema:Get("uf.focus.width"), 211, "focus width copied from boss")
  t:eq(UF.CopyGroup("boss", "boss"), 0, "copying onto itself does nothing")
end)

Tests:Add("UnitFrames", "player aura bars park the Blizzard buff frame through the ledger", function(t)
  enable(t, "uf.auraBars.source")
  Schema:Set("uf.auraBars.source", "phoenix")
  t:ok(ns.Blizzard.IsParked("buffs"), "BuffFrame parked")
  local found = false
  for _, f in ipairs(PUI.FrameLedger:List()) do if f.id == "uf.blizzard.buffs" then found = true end end
  t:ok(found, "takeover recorded in the frame ledger")
  Schema:Set("uf.auraBars.source", "blizzard")
  t:ok(not ns.Blizzard.IsParked("buffs"), "Blizzard buffs back live")
end)

Tests:Add("UnitFrames", "player frame hosts Resource Bars when attached", function(t)
  local RB = PUI.ResourceBars
  if not (RB and RB.SetHost) then return end
  local units = enable(t, "uf.player.resources")
  Schema:Set("uf.player.resources", "attach")
  t:eq(RB.Host(), units.player.button, "resource bars hosted under the player frame")
  Schema:Set("uf.player.resources", "separate")
  t:eq(RB.Host(), nil, "kept separate (Studio places them)")
end)

Tests:Add("UnitFrames", "dispel slots, lockout preset, purge glow and overflow marks apply live", function(t)
  if not H then return end
  local units = enable(t, "uf.target.dispel.enabled", "uf.target.auras.debuffs.hideLockouts", "uf.purgeGlow", "uf.overflow")
  local o = units.target
  -- Dispel slots: their own engine group on the dispellable filter.
  t:ok(o.dispelHandle, "target has a dispel-slot group")
  local st = o.dispelHandle:GroupState("dispel")
  t:eq(st and st.filter, PUI.Auras.Filter("HARMFUL", "RAID_PLAYER_DISPELLABLE"), "dispel slots use the dispellable filter")
  Schema:Set("uf.target.dispel.enabled", false)
  t:ok(not o.dispelHolder:IsShown(), "dispel slots turn off live")
  -- Lockout preset on debuffs.
  t:eq(#(o.auras.debuffs.exclusions or {}), #PUI.Auras.LOCKOUTS, "lockouts excluded by default")
  Schema:Set("uf.target.auras.debuffs.hideLockouts", false)
  t:eq(#(o.auras.debuffs.exclusions or {}), 0, "lockout preset turns off live")
  -- Purge glow: only with an offensive dispel known, a hostile unit and a purgeable buff.
  H.known[370], H.hostile.target, H.purgeable = true, true, { target = true }
  t:cleanup(function() H.known[370], H.hostile.target, H.purgeable = nil, nil, nil end)
  E.UpdatePurge(o)
  t:ok(o.purging, "purge glow shows")
  Schema:Set("uf.purgeGlow", false)
  E.UpdatePurge(o)
  t:ok(not o.purging, "purge glow turns off live")
  -- Overflow marks never compare the secret clamped flag.
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  Schema:Set("uf.overflow", true)
  o.calc = o.calc or CreateUnitHealPredictionCalculator()
  E.UpdatePrediction(o)
  t:ok(o.healAbsorbOver and o.absorbOver, "overflow marks exist")
end)
