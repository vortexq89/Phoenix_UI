-- Runs the Phoenix UI smoke suite offline: lua5.1 .tools/harness/run_tests.lua
-- Env: PUI_ROOT (repo root, default "."), PUI_FLAVOR (retail|forever).
local here = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(here .. "/wow_stub.lua")

H.loadAddon("Phoenix_UI")
H.fire("PLAYER_LOGIN")
for _ = 1, 3 do H.step() end

local PUI = PhoenixUI
local failures = 0
local function check(cond, msg)
  if not cond then failures = failures + 1; print("HARNESS FAIL: " .. msg) end
end
check(PUI.Sentinel and PUI.Sentinel.db, "Sentinel child loaded at DB_READY")
check(PUI.SentinelHook.mode == "chained", "error handler chained")

local results
PUI.Tests:Run(nil, function(r) results = r end, true)
local guard = 0
while not results and guard < 600 do H.step(); guard = guard + 1 end
check(results ~= nil, "suite finished")

-- End-to-end: an induced error travels engine handler -> hook -> incident.
local before = 0
for _ in pairs(PUI.Sentinel.db.incidents) do before = before + 1 end
SlashCmdList.PHOENIXUI("sentinel induce")
for _ = 1, 3 do H.step() end
local found
for _, inc in pairs(PUI.Sentinel.db.incidents) do
  if inc.message:find("induced test error", 1, true) then found = inc end
end
check(found ~= nil, "induced error captured as an incident")
check(found and found.module == "Sentinel", "induced error attributed to Sentinel")

-- Every setting applies live through /pui set.
SlashCmdList.PHOENIXUI("set sentinel.safeModeThreshold 7")
check(PUI.Sentinel.safeModeThreshold == 7, "/pui set applies live")
SlashCmdList.PHOENIXUI("set sentinel.safeModeThreshold 5")

-- Perf sampler runs only while enabled (Ticker registry).
check(not PUI.Ticker:IsRegistered("sentinel.perf"), "perf sampler off by default")
PUI.Schema:Set("sentinel.perfSampler", true)
check(PUI.Ticker:IsRegistered("sentinel.perf"), "perf sampler registered when enabled")
PUI.Schema:Set("sentinel.perfSampler", false)
check(not PUI.Ticker:IsRegistered("sentinel.perf"), "perf sampler gone when disabled")

H.fire("PLAYER_LOGOUT")
local ok, where = PUI.ClientGate.CheckSerializable(PhoenixUIDB, "PhoenixUIDB")
check(ok, "PhoenixUIDB serializable at logout " .. tostring(where))
ok, where = PUI.ClientGate.CheckSerializable(PhoenixUISentinelDB, "PhoenixUISentinelDB")
check(ok, "PhoenixUISentinelDB serializable at logout " .. tostring(where))
check(#PhoenixUISentinelDB.heartbeats == 1, "heartbeat written at logout")

-- The harness's own handler stands in for Blizzard's/BugSack's: it must still
-- receive the induced error (chaining), and nothing else may reach it.
local reachedPrior = false
for _, line in ipairs(H.output) do
  if line:find("UNHANDLED") then
    if line:find("induced test error", 1, true) then reachedPrior = true
    else failures = failures + 1; io.stderr:write(line, "\n") end
  end
end
check(reachedPrior, "induced error also reached the previous error handler")
io.stdout:write(string.format("[%s] /pui test: %d passed, %d failed\n", H.flavor, results and results.pass or 0, results and results.fail or -1))
for _, c in ipairs(results and results.cases or {}) do
  io.stdout:write(string.format("  %s %-12s %s%s\n", c.pass and "PASS" or "FAIL", c.suite, c.name, c.error and (" -- " .. c.error) or ""))
end
io.stdout:write(string.format("[%s] harness checks: %s\n", H.flavor, failures == 0 and "ok" or (failures .. " failed")))
os.exit((failures == 0 and results and results.fail == 0) and 0 or 1)
