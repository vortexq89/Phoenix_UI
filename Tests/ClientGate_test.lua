local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Gate = PUI.Tests, PUI.ClientGate

Tests:Add("ClientGate", "client flags match the interface version", function(t)
  t:ok(PUI.gateOpen, "gate open")
  t:eq(PUI.IS_FOREVER, PUI.TOC >= 16000 and PUI.TOC < 20000, "IS_FOREVER")
  t:ok(PUI.IS_FOREVER or PUI.TOC >= 120100, "retail is 12.1 or newer")
end)

Tests:Add("ClientGate", "values that cannot be saved are rejected", function(t)
  t:ok(Gate.CheckSerializable({ a = 1, b = { "x", true } }), "plain table")
  t:eq((Gate.CheckSerializable({ f = function() end })), false, "function")
  t:eq((Gate.CheckSerializable({ n = 0 / 0 })), false, "NaN")
  t:eq((Gate.CheckSerializable({ [true] = 1 })), false, "boolean key")
  local cyc = {}
  cyc.self = cyc
  t:eq((Gate.CheckSerializable(cyc)), false, "cycle")
end)
