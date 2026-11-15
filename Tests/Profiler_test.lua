local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the developer profiler (plan 1.32): zero cost off,
-- self vs inclusive, generations, hidden rows, restore on stop, A/B.
local Tests, P = PUI.Tests, PUI.Profiler

Tests:Add("Profiler", "off: no wrappers; on: times entry points; stop restores originals", function(t)
  t:eq(P.running, false, "off at first install")
  t:eq(P:IsWrapping(), false, "nothing wrapped while off")
  local obj = {}
  function obj.outer() obj.inner(); return 7 end
  function obj.inner() local x = 0; for i = 1, 2000 do x = x + i end; return x end
  local origOuter = obj.outer
  P:Register("PUITest", "outer", obj, "outer")
  P:Register("PUITest", "inner", obj, "inner")
  t:cleanup(function() P:Stop(); P.entries["PUITest:outer"], P.entries["PUITest:inner"] = nil, nil end)
  local gen = P.generation
  P:Start()
  t:eq(P.generation, gen + 1, "new measurement generation")
  t:ok(obj.outer ~= origOuter, "wrapped while running")
  t:eq(obj.outer(), 7, "return values pass through")
  local o, i = P.stats["PUITest:outer"], P.stats["PUITest:inner"]
  t:eq(o.calls, 1, "counted")
  t:ok(o.incl >= i.incl, "inclusive includes the child")
  t:ok(o.self <= o.incl, "self excludes the child")
  P:Stop()
  t:eq(obj.outer, origOuter, "original restored")
  t:eq(P:IsWrapping(), false, "no wrappers after stop")
  local r = P:Report(1e9)
  t:eq(#r.groups, 0, "rows under the floor are hidden"); t:ok(r.hidden >= 2, "and counted as hidden")
  t:ok(P:ReportText():find("Profiler", 1, true) ~= nil, "report text")
end)

Tests:Add("Profiler", "Ticker jobs are timed only while running; A/B helper", function(t)
  P:Start()
  t:cleanup(function() P:Stop(); PUI.Ticker:Unregister("PUITest.prof") end)
  local e = PUI.Ticker:Register("PUITest.prof", 1, function() end, "PUITest")
  t:ok(e.fn ~= e.rawFn, "new job wrapped while running")
  P:Stop()
  t:eq(e.fn, e.rawFn, "restored")
  local a, b = P.AB(function() end, function() for i = 1, 500 do local _ = i * 2 end end, 20)
  t:ok(type(a) == "number" and type(b) == "number", "interleaved averages")
end)
