local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Forever child (flight timer, pet happiness).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local FV = ns.Forever
local Flight, Pet = FV.Flight, FV.Pet

Tests:Add("Forever", "turns on only in Forever; every key applies live", function(t)
  t:eq(FV.module.enabled, PUI.IS_FOREVER == true, "enabled exactly on the Forever client")
  for k, def in pairs(FV.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  Tests.Keep(t, "forever.flightScale")
  Schema:Set("forever.flightScale", 1.2)
  t:eq(FV.settings.flightScale, 1.2, "applies without a reload")
end)

Tests:Add("Forever", "flight timer: route from the taxi map and the hook, learned time, countdown text", function(t)
  if not H then return end
  local db = FV.DB()
  local saved = db.flights
  db.flights = {}
  t:cleanup(function() db.flights = saved; Flight.trip, Flight.pending = nil, nil; PUI.Ticker:Unregister("forever.flight"); H.taxiNodes = {} end)
  H.taxiNodes = { { nodeID = 10, name = "Ironforge", state = 0, slotIndex = 1 }, { nodeID = 20, name = "Stormwind", state = 1, slotIndex = 2 } }
  Flight.OnMapOpened()
  t:eq(Flight.origin, 10, "origin is the current node")
  Flight.OnTake(2)
  t:eq(Flight.pending.to, 20, "destination from the clicked slot")
  t:ok(Flight.Start(), "flight starts")
  local trip = Flight.trip
  t:ok(Flight.Text(trip, trip.t0 + 30):find("learning", 1, true), "unknown route: elapsed time")
  trip.t0 = trip.t0 - 120
  t:eq(Flight.Land(), 120, "route learned")
  t:eq(Flight.Known(10, 20), 120, "saved")
  Flight.OnTake(2); Flight.Start()
  local text, frac = Flight.Text(Flight.trip, Flight.trip.t0 + 30)
  t:ok(text:find("Stormwind  1:30", 1, true), "countdown on a known route")
  t:ok(math.abs(frac - 0.25) < 0.01, "bar progress")
  Flight.trip.t0 = Flight.trip.t0 - 100
  t:eq(Flight.Land(), 110, "later flights refine the average")
  t:eq(Flight.Land(), nil, "landing without a trip does nothing")
end)

Tests:Add("Forever", "pet happiness: badge colour and text, unhappy warning once per drop", function(t)
  if not (H and PUI.IS_FOREVER) then return end
  Tests.Keep(t, "forever.petWarn")
  Schema:Set("forever.petWarn", true)
  local print0, printed = PUI.Slash.Print, {}
  PUI.Slash.Print = function(m) printed[#printed + 1] = m end
  local hadPet = H.units.pet
  H.units.pet = true
  t:cleanup(function() PUI.Slash.Print = print0; H.petHappiness = nil; H.units.pet = hadPet; Pet.Refresh() end)
  H.petHappiness, H.petLoyalty = 3, 20
  Pet.last = nil
  Pet.Tick()
  t:ok(Pet.frame.text:GetText():find("Happy  +20", 1, true), "happy with loyalty")
  H.petHappiness = 1
  Pet.Tick()
  t:eq(#printed, 1, "one warning")
  Pet.Tick()
  t:eq(#printed, 1, "not repeated while unhappy")
end)

Tests:Add("Forever", "swing timer: off by default, combat log only in Forever while on, live settings, idle job goes away", function(t)
  local Swing = FV.Swing
  t:eq(FV.schema["forever.swingTimer"].default, false, "opt-in: off by default")
  Tests.Keep(t, "forever.swingTimer", "forever.swingScale")
  local reader0, speed0 = rawget(_G, "CombatLogGetCurrentEventInfo"), rawget(_G, "UnitAttackSpeed")
  local line = {}
  rawset(_G, "CombatLogGetCurrentEventInfo", function() return 0, line.sub, false, line.src end)
  rawset(_G, "UnitAttackSpeed", function() return 2.5 end)
  t:cleanup(function() rawset(_G, "CombatLogGetCurrentEventInfo", reader0); rawset(_G, "UnitAttackSpeed", speed0); Swing.Stop() end)
  Schema:Set("forever.swingTimer", false)
  t:eq(Swing.listening == true, false, "no combat-log event while off")
  t:eq(FV.module.handlers[Swing.EVENT], nil, "not registered while off")
  Schema:Set("forever.swingTimer", true)
  if not PUI.IS_FOREVER then
    t:eq(Swing.listening == true, false, "never registered outside Forever")
    t:eq(Swing.OnLog("SWING_DAMAGE", UnitGUID("player"), 1), false, "ignored outside Forever")
    return
  end
  t:ok(Swing.listening, "registered live once turned on")
  t:eq(type(FV.module.handlers[Swing.EVENT]), "function", "handler present")
  line.sub, line.src = "SPELL_DAMAGE", UnitGUID("player")
  Swing.OnEvent()
  t:eq(Swing.t0, nil, "spells do not start a swing")
  line.sub, line.src = "SWING_DAMAGE", "Creature-0-1"
  Swing.OnEvent()
  t:eq(Swing.t0, nil, "other units' swings are ignored")
  line.sub, line.src = "SWING_MISSED", UnitGUID("player")
  Swing.OnEvent()
  t:ok(Swing.t0 ~= nil and Swing.dur == 2.5, "own swing starts the timer at attack speed")
  t:ok(PUI.Ticker.entries["forever.swing"] ~= nil, "ticker job while swinging")
  t:ok(Swing.bar:IsShown(), "bar shown")
  local text, frac = Swing.Text(10, 2.5, 11.25)
  t:eq(text, "Swing  1.2", "countdown text"); t:ok(math.abs(frac - 0.5) < 0.01, "progress")
  Schema:Set("forever.swingScale", 1.4)
  t:eq(Swing.bar:GetScale(), 1.4, "size applies live")
  Swing.t0 = GetTime() - 10
  Swing.Paint()
  t:eq(PUI.Ticker.entries["forever.swing"], nil, "idle: job removed")
  t:eq(Swing.bar:IsShown(), false, "idle: bar hidden")
  Swing.OnLog("SWING_DAMAGE", UnitGUID("player"), GetTime())
  Schema:Set("forever.swingTimer", false)
  t:eq(Swing.listening, false, "unregistered live when turned off")
  t:eq(FV.module.handlers[Swing.EVENT], nil, "handler gone")
  t:eq(PUI.Ticker.entries["forever.swing"], nil, "job gone")
end)

Tests:Add("Forever", "fishing helper: fishing spells only, bar text, louder splash restored", function(t)
  if not H then return end
  local saved = { FV.active, FV.settings.fishHelper, FV.settings.fishLoud }
  t:cleanup(function()
    FV.Fish.Stop()
    FV.active, FV.settings.fishHelper, FV.settings.fishLoud = saved[1], saved[2], saved[3]
    H.channel = nil
  end)
  local Fish = FV.Fish
  t:eq(Fish.IsFishing(7620), true, "Fishing")
  t:eq(Fish.IsFishing(133), false, "not fishing")
  t:ok(Fish.Text(12.34, 3):find("12.3", 1, true) and Fish.Text(12.34, 3):find("catches 3", 1, true), "bar text")
  FV.active, FV.settings.fishHelper, FV.settings.fishLoud = true, false, true
  t:eq(Fish.Start(7620, 10), false, "off by default: nothing")
  FV.settings.fishHelper = true
  t:eq(Fish.Start(133, 10), false, "other channels ignored")
  C_CVar.SetCVar("Sound_SFXVolume", "0.3")
  local now = GetTime()
  H.channel = { spellID = 7620, start = now * 1000, stop = (now + 21) * 1000 }
  t:eq(Fish.Start(7620, now), true, "fishing starts the bar")
  t:ok(Fish.t1 and math.abs(Fish.t1 - (now + 21)) < 0.01, "end time from the channel")
  t:eq(C_CVar.GetCVar("Sound_SFXVolume"), "1", "louder while fishing")
  Fish.Stop()
  t:eq(C_CVar.GetCVar("Sound_SFXVolume"), "0.3", "volume restored")
  t:eq(FV.DB().fishVolume, nil, "nothing left to restore")
end)
