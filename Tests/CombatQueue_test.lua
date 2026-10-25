local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, CQ = PUI.Tests, PUI.CombatQueue

Tests:Add("CombatQueue", "runs immediately out of combat", function(t)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return false end
  local ran = false
  t:eq(CQ.Defer("test.now", function() ran = true end), true, "ran now")
  t:ok(ran, "callback ran")
end)

Tests:Add("CombatQueue", "keyed jobs replace and drain in order", function(t)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  local log = {}
  CQ.Defer("test.a", function() log[#log + 1] = "a1" end)
  CQ.Defer("test.b", function() log[#log + 1] = "b" end)
  CQ.Defer("test.a", function() log[#log + 1] = "a2" end)
  t:eq(CQ.Pending(), 2, "two keys queued")
  t:eq(#log, 0, "nothing ran in combat")
  CQ.InCombat = function() return false end
  t:eq(CQ.Drain(), 2, "drained two")
  t:eq(table.concat(log, ","), "a2,b", "newest job per key, first-queued order")
  t:eq(CQ.Pending(), 0, "empty")
  t:throws(function() CQ.Defer(nil, function() end) end, "key required")
end)
