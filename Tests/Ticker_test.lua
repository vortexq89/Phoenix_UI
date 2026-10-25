local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Ticker = PUI.Tests, PUI.Ticker

Tests:Add("Ticker", "registration needs a key and an interval", function(t)
  t:throws(function() Ticker:Register(nil, 1, function() end) end, "no key")
  t:throws(function() Ticker:Register("test.k", nil, function() end) end, "no interval")
  t:throws(function() Ticker:Register("test.k", -1, function() end) end, "negative interval")
  Ticker:Register("test.k", 0.5, function() end, "Tests")
  t:cleanup(function() Ticker:Unregister("test.k") end)
  t:ok(Ticker:IsRegistered("test.k"), "registered")
  t:eq(Ticker.entries["test.k"].interval, 0.5, "interval stored")
  Ticker:UnregisterOwner("Tests")
  t:eq(Ticker:IsRegistered("test.k"), false, "owner cleanup")
end)

Tests:Add("Ticker", "stray OnUpdate scripts are flagged", function(t)
  local fn = function() end
  local fake = { GetScript = function(_, script) return script == "OnUpdate" and fn or nil end }
  local clean = { GetScript = function() return nil end }
  local stray = Ticker:Audit({ [fake] = "PUITest_Fake", [clean] = "PUITest_Clean" })
  t:eq(#stray, 1, "one stray")
  t:eq(stray[1].owner, "PUITest_Fake", "attributed")
  t:eq(#Ticker:Audit(), 0, "no Phoenix frame has an unregistered OnUpdate")
end)
