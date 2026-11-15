local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Resource Bars deferred batch (Extras.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local RB = ns.RB
local X = RB.Extras

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
local function shown(list)
  local n = 0
  for _, m in ipairs(list or {}) do if m:IsShown() then n = n + 1 end end
  return n
end

Tests:Add("ResourceBarsX", "new settings are labelled, moded and live", function(t)
  t:ok(#X.KEYS >= 14, "keys")
  for _, k in ipairs(X.KEYS) do
    local d = Schema:Def(k)
    t:ok(d and d.label and d.tooltip and (d.mode == "simple" or d.mode == "advanced") and type(d.apply) == "function", k)
  end
  t:eq(X.ParseTicks("15407=6, 5143 = 5, 9=1, x=3")[15407], 6, "ticks parsed")
  t:eq(X.ParseTicks("9=1")[9], nil, "one tick is no tick")
end)

Tests:Add("ResourceBarsX", "latency zone on casts, ticks on channels, stage marks on empowers", function(t)
  if not H then return end
  enable(t, "rb.cast.enabled", "rb.cast.latency", "rb.cast.channelTicks", "rb.cast.empowerStages")
  Schema:Set("rb.cast.enabled", true)
  Schema:Set("rb.cast.latency", true)
  Schema:Set("rb.cast.channelTicks", "777=4")
  local bar = RB.castBar
  t:ok(bar and rawget(bar, "puiExtras"), "cast bar hooked")
  H.casting = true
  t:cleanup(function() H.casting = nil; H.channel = nil end)
  bar:Start("cast")
  t:ok(rawget(bar, "puiLatency") and bar.puiLatency:IsShown(), "latency zone shown")
  bar:Stop("stop")
  t:eq(bar.puiLatency:IsShown(), false, "gone after the cast")
  H.casting = nil
  H.channel = { spellID = 777, start = 0, stop = 3000 }
  bar:Start("channel")
  t:eq(shown(rawget(bar, "puiMarks")), 3, "4 ticks = 3 lines")
  H.channel = { spellID = 1, start = 0, stop = 3000, empowered = true, stages = 4 }
  bar:Start("empower")
  t:eq(shown(bar.puiMarks), 4, "a mark at the end of each stage inside the cast")
  Schema:Set("rb.cast.empowerStages", false)
  bar:Start("empower")
  t:eq(shown(bar.puiMarks), 0, "off: no marks")
end)

Tests:Add("ResourceBarsX", "global cooldown bar modes", function(t)
  if not H then return end
  enable(t, "rb.gcd.enabled", "rb.gcd.mode")
  Schema:Set("rb.gcd.enabled", true)
  Schema:Set("rb.gcd.mode", "instance")
  H.instance = false
  RB.UpdateGCD()
  t:eq(RB.bars.gcd:GetAlpha(), 0, "hidden in the open world")
  t:eq(X.GcdAllowed(), false, "instance mode")
  H.instance = true
  t:cleanup(function() H.instance = false; H.casting = nil end)
  t:eq(X.GcdAllowed(), true, "shown in an instance")
  Schema:Set("rb.gcd.mode", "instant")
  H.casting = true
  t:eq(X.GcdAllowed(), false, "hidden while casting")
  H.casting = nil
  t:eq(X.GcdAllowed(), true, "back for instants")
end)

Tests:Add("ResourceBarsX", "power threshold colours come from an engine curve", function(t)
  if not H then return end
  enable(t, "rb.power.enabled", "rb.power.thresholds", "rb.power.lowPct")
  Schema:Set("rb.power.enabled", true)
  Schema:Set("rb.power.thresholds", true)
  Schema:Set("rb.power.lowPct", 30)
  t:ok(H.powerCurve and H.powerCurve.isColor, "colour curve passed to UnitPowerPercent")
  t:eq(H.powerCurve.points[2][1], 0.3, "low threshold applied live")
  t:eq(RB.bars.power.barColor[2], 0.9, "bar painted from the curve")
end)

Tests:Add("ResourceBarsX", "aura stack bar fills from stacks and closes up when the aura is missing", function(t)
  if not H then return end
  enable(t, "rb.aura.enabled", "rb.aura.spell", "rb.aura.max", "rb.collapse")
  Schema:Set("rb.aura.spell", 4242)
  Schema:Set("rb.aura.enabled", true)
  t:eq(RB.slots.aura:IsShown(), false, "no aura: no room taken")
  H.auras[4242] = { applications = 3 }
  t:cleanup(function() H.auras[4242] = nil end)
  H.fire("UNIT_AURA", "player")
  t:eq(RB.slots.aura:IsShown(), true, "aura up: bar shown")
  t:eq(X.auraBar:GetValue(), 3, "stacks fill the bar")
  Schema:Set("rb.collapse", false)
  H.auras[4242] = nil
  H.fire("UNIT_AURA", "player")
  t:eq(RB.slots.aura:IsShown(), true, "collapse off: the slot stays")
end)
