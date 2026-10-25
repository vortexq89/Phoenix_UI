local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test: the smoke suite runner. Test files call PUI.Tests:Add(suite, name, fn).
-- fn(t) may return a continuation function that runs one frame later (for
-- behaviour that is deferred by design). Results are printed and stored as a
-- Sentinel "test" record.
local Tests = { cases = {} }
PUI.Tests = Tests

local T = {}
T.__index = T

function T:ok(cond, msg)
  if not cond then error("expected true: " .. (msg or "?"), 2) end
end

function T:eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "eq", tostring(expected), tostring(actual)), 2)
  end
end

function T:same(actual, expected, msg)
  if not PUI.DB.DeepEqual(actual, expected) then error("tables differ: " .. (msg or "?"), 2) end
end

-- guardrails-allow: pcall 2026-10-25 approver=VortexQ8 reason=assert-that-code-raises-in-tests (Phase 1 plan t31s257)
function T:throws(fn, msg)
  local ok = pcall(fn)
  if ok then error("expected an error: " .. (msg or "?"), 2) end
end

-- Registers a cleanup to run after the case, pass or fail.
function T:cleanup(fn) self.cleanups[#self.cleanups + 1] = fn end

function Tests:Add(suite, name, fn)
  self.cases[#self.cases + 1] = { suite = suite, name = name, fn = fn }
end

local function traceback(err)
  return { message = PUI.Secret.ToText(err, 500), stack = debugstack(2) }
end

-- guardrails-allow: xpcall 2026-10-25 approver=VortexQ8 reason=isolate-test-cases-failures-are-reported (Phase 1 plan t31s257)
local function runStep(t, fn)
  local ok, res = xpcall(function() return fn(t) end, traceback)
  return ok, res
end

local function finishCase(t)
  for i = #t.cleanups, 1, -1 do t.cleanups[i]() end
end

-- Runs every case (optionally only one suite); calls done(results) at the end.
function Tests:Run(filter, done, quiet)
  local results = { pass = 0, fail = 0, cases = {} }
  local idx = 0
  local started = debugprofilestop()
  local nextCase
  local function record(case, ok, err, ms)
    local r = { suite = case.suite, name = case.name, pass = ok, ms = ms, error = (not ok) and err and err.message or nil }
    results.cases[#results.cases + 1] = r
    if ok then results.pass = results.pass + 1 else results.fail = results.fail + 1 end
    if not quiet and not ok then
      PUI.Slash.Print("|cffff0044FAIL|r " .. case.suite .. " / " .. case.name .. ": " .. tostring(r.error))
    end
  end
  function nextCase()
    idx = idx + 1
    local case = self.cases[idx]
    while case and filter and case.suite ~= filter do
      idx = idx + 1
      case = self.cases[idx]
    end
    if not case then
      results.ms = debugprofilestop() - started
      Tests:Store(results)
      if not quiet then
        PUI.Slash.Print(string.format("tests: %d passed, %d failed (%.1f ms)", results.pass, results.fail, results.ms))
      end
      if done then done(results) end
      return
    end
    local t = setmetatable({ cleanups = {} }, T)
    local t0 = debugprofilestop()
    local ok, res = runStep(t, case.fn)
    if ok and type(res) == "function" then
      C_Timer.After(0, function()
        local ok2, res2 = runStep(t, res)
        finishCase(t)
        record(case, ok2, res2, debugprofilestop() - t0)
        nextCase()
      end)
      return
    end
    finishCase(t)
    record(case, ok, res, debugprofilestop() - t0)
    nextCase()
  end
  nextCase()
  return results
end

function Tests:Store(results)
  local S = PUI.Sentinel
  if not (S and S.db) then return end
  local list = S.db.tests
  local failed = {}
  for i = 1, #results.cases do
    local c = results.cases[i]
    if not c.pass then failed[#failed + 1] = c.suite .. "/" .. c.name .. ": " .. tostring(c.error) end
  end
  list[#list + 1] = {
    session = S.db.session, at = time(), version = S:Version(), build = PUI.BUILD, forever = PUI.IS_FOREVER,
    summary = results.pass .. " passed, " .. results.fail .. " failed", failed = failed, ms = results.ms,
  }
  while #list > 10 do table.remove(list, 1) end
end

PUI.Slash:Register("test", function(rest)
  Tests:Run(rest ~= "" and rest or nil)
end, "[suite]: run the smoke suite")

-- Tester mode runs the suite once after login.
PUI.Kernel:On("LOGIN", function()
  if PUI.Schema:Get("sentinel.testerMode") then C_Timer.After(2, function() Tests:Run() end) end
end)
