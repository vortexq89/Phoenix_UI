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
