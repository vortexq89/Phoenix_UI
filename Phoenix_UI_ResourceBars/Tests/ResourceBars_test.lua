local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Resource Bars.
local _, ns = ...
local H = rawget(_G, "HARNESS") -- the offline harness, nil in game
local Tests, Schema, Ticker = PUI.Tests, PUI.Schema, PUI.Ticker
local RB, CR = ns.RB, ns.ClassResource

local function enable(t, ...)
  local keys = { "module.ResourceBars", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    PUI.CombatQueue.Drain()
  end)
  Schema:Set("module.ResourceBars", true)
end

local function registered(ev) return RB.module.frame:IsEventRegistered(ev) end

Tests:Add("ResourceBars", "off by default and zero cost while off", function(t)
  t:eq(Schema:Def("module.ResourceBars").default, false, "module defaults off")
  if Schema:Get("module.ResourceBars") then return end
  t:eq(RB.module:RegisteredEventCount(), 0, "no events")
  t:eq(Ticker:IsRegistered("rb.stagger"), false, "no ticker")
  t:ok(not RB.frame or not RB.frame:IsShown(), "no visible stack")
end)

Tests:Add("ResourceBars", "events follow the enabled bars, live", function(t)
  enable(t, "rb.health.enabled", "rb.cast.enabled", "rb.gcd.enabled", "rb.totem.enabled")
  t:ok(RB.frame:IsShown(), "stack shown")
  t:eq(PUI.Layout:Frame("rb.stack"), RB.frame, "placed through Layout (Studio)")
  if not H then return end
  t:ok(registered("UNIT_POWER_UPDATE"), "power on by default")
  t:eq(registered("UNIT_HEALTH"), false, "health off by default")
  t:eq(RB.castBar == nil or not RB.castBar.enabled, true, "cast off by default")
  Schema:Set("rb.health.enabled", true)
  Schema:Set("rb.cast.enabled", true)
  Schema:Set("rb.gcd.enabled", true)
  Schema:Set("rb.totem.enabled", true)
  t:ok(registered("UNIT_HEALTH"), "health wired")
  t:ok(RB.castBar and RB.castBar.enabled, "player cast bar on the shared PUI.CastBar")
  t:eq(PUI.CastBar.byUnit.player[RB.castBar], true, "fed by the one shared cast dispatcher")
  t:eq(registered("UNIT_SPELLCAST_START"), false, "Resource Bars registers no cast events of its own")
  t:ok(registered("SPELL_UPDATE_COOLDOWN") and registered("PLAYER_TOTEM_UPDATE"), "gcd and totems wired")
  t:eq(#RB.bars.totem, 4, "one bar per totem slot")
  t:ok(RB.bars.gcd.timer ~= nil, "GCD bar runs from a duration object")
  Schema:Set("rb.health.enabled", false)
  t:eq(registered("UNIT_HEALTH"), false, "health unwired when turned off")
end)

Tests:Add("ResourceBars", "class resource pips, runes and stagger", function(t)
  enable(t, "rb.power.ticks")
  if not H then return end
  t:cleanup(function() H.class, H.spec, H.secretMode = "MAGE", 1, false; RB.Reconfigure() end)
  RB.Reconfigure()
  t:eq(CR.kind, "points", "arcane charges for a mage with a positive max")
  t:eq(CR.shown, 4, "four pips")
  H.secretMode = true
  CR.Update() -- secret amount goes to SetValue on every pip
  H.secretMode = false
  H.class = "DEATHKNIGHT"
  RB.Reconfigure()
  t:eq(CR.kind, "runes", "runes for a death knight")
  t:ok(registered("RUNE_POWER_UPDATE"), "rune event wired")
  t:ok(CR.pips[5].timer ~= nil, "recharging rune animates from a duration object")
  H.secretMode = true
  CR.Update()
  H.secretMode = false
  H.class, H.spec = "MONK", 1
  RB.Reconfigure()
  t:eq(CR.kind, "stagger", "stagger for a Brewmaster")
  t:ok(Ticker:IsRegistered("rb.stagger"), "stagger ticker only while shown")
  H.class = "WARRIOR"
  RB.Reconfigure()
  t:eq(CR.kind, nil, "no class resource")
  t:eq(Ticker:IsRegistered("rb.stagger"), false, "stagger ticker removed")
  Schema:Set("rb.power.ticks", "30, 60, abc, 150")
  t:same(RB.cfg.ticks, { 30, 60 }, "hash lines parsed")
  t:ok(RB.ticks[2]:IsShown(), "hash lines drawn")
end)

Tests:Add("ResourceBars", "disabling releases events and tickers", function(t)
  enable(t, "rb.cast.enabled", "rb.cast.hideBlizzard")
  Schema:Set("rb.cast.enabled", true)
  Schema:Set("rb.cast.hideBlizzard", true)
  if H then t:ok(PlayerCastingBarFrame:GetParent() ~= UIParent, "Blizzard cast bar parked on request") end
  Schema:Set("module.ResourceBars", false)
  t:eq(RB.module:RegisteredEventCount(), 0, "no events")
  t:eq(RB.frame:IsShown(), false, "stack hidden")
  if H then t:eq(PlayerCastingBarFrame:GetParent(), UIParent, "Blizzard cast bar restored") end
end)

-- Step 6 ---------------------------------------------------------------------------
Tests:Add("ResourceBars", "cast bar parts and colours are live settings", function(t)
  enable(t, "rb.cast.enabled", "rb.cast.icon", "rb.cast.castColor", "rb.width", "rb.cast.height")
  Schema:Set("rb.cast.enabled", true)
  Schema:Set("rb.width", 300)
  Schema:Set("rb.cast.height", 20)
  local bar = RB.castBar
  t:eq(bar.style.width, 300 - 22, "icon space taken from the width")
  t:eq(bar.style.height, 20, "height")
  Schema:Set("rb.cast.icon", false)
  t:eq(bar.style.width, 300, "full width without an icon")
  t:eq(bar.style.kick, false, "no kick marker on your own cast bar")
  Schema:Set("rb.cast.castColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 })
  t:eq(bar.style.colors.cast.r, 0.1, "colour applies live")
  if H then
    H.casting = true
    t:cleanup(function() H.casting = nil end)
    H.fire("UNIT_SPELLCAST_START", "player")
    t:eq(bar.casting, true, "shared dispatcher starts the bar")
    t:ok(bar.status.timer ~= nil, "engine timer, no per-frame Lua")
  end
  Schema:Set("rb.cast.enabled", false)
  t:eq(bar.enabled, false, "turned off releases the dispatcher hold")
end)

Tests:Add("ResourceBars", "power text, colour mode and host width", function(t)
  enable(t, "rb.power.text", "rb.power.color", "rb.matchHostWidth")
  if not H then return end
  H.secretMode = true
  Schema:Set("rb.power.text", "both")
  H.secretMode = false
  t:eq(RB.bars.power.valueText:GetText(), "<secret-formatted>", "secret power goes straight to the font string")
  Schema:Set("rb.power.text", "percent")
  t:eq(RB.bars.power.valueText:GetText(), "50%", "percent text")
  Schema:Set("rb.power.text", "none")
  t:eq(RB.bars.power.valueText:GetText(), "", "no text")
  Schema:Set("rb.power.color", "accent")
  local host = CreateFrame("Frame", nil, UIParent)
  host:SetSize(180, 40)
  RB.SetHost(host, 2, true)
  t:cleanup(function() RB.SetHost(nil) end)
  t:eq(RB.widthNow, 180, "attached bars take the player frame width")
  Schema:Set("rb.matchHostWidth", false)
  t:eq(RB.widthNow, Schema:Get("rb.width"), "own width when matching is off")
end)
