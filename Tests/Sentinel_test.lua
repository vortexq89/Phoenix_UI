local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Hook = PUI.Tests, PUI.SentinelHook

local CORE_STACK = "[string \"@Interface/AddOns/Phoenix_UI/Core/Fake.lua\"]:10: in function <Interface/AddOns/Phoenix_UI/Core/Fake.lua:8>"

-- Scratch Sentinel DB for one case; real incidents are untouched.
local function scratch(t)
  local S = PUI.Sentinel
  t:ok(S and S.db, "Phoenix_UI_Sentinel is loaded")
  local saved, toast = S.db, S.toastEnabled
  S.toastEnabled = false
  t:cleanup(function() S.db, S.toastEnabled = saved, toast end)
  S:InitDB({})
  return S
end

local function count(tbl)
  local n = 0
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

Tests:Add("Sentinel", "an induced error becomes one deduplicated incident", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom 42", CORE_STACK, "x = 1")
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom 43", CORE_STACK, "x = 2")
  t:eq(count(S.db.incidents), 1, "deduplicated")
  local _, inc = next(S.db.incidents)
  t:eq(inc.count, 2, "two occurrences")
  t:eq(inc.module, "Core", "owner")
  t:eq(inc.kind, "error", "kind")
  t:ok(inc.context and inc.context.events, "context with event ring")
  Hook.Simulate("Interface/AddOns/OtherAddon/x.lua:1: not ours", "OtherAddon/x.lua:1", nil)
  t:eq(count(S.db.incidents), 1, "non-Phoenix errors are not recorded")
end)

Tests:Add("Sentinel", "secret values are stored as placeholders", function(t)
  scratch(t)
  local Secret = PUI.Secret
  local fake = setmetatable({}, { __tostring = function() error("a secret must never be converted") end })
  local probe = Secret.IsSecret
  Secret.IsSecret = function(v) return v == fake or probe(v) end
  t:cleanup(function() Secret.IsSecret = probe end)
  local rec = Hook.BuildRecord(fake, CORE_STACK, fake)
  t:eq(rec.message, "<secret>", "message")
  t:eq(rec.locals, "<secret>", "locals")
  t:eq(Secret.Storable(fake), "<secret>", "storable")
  t:eq(PUI.Sentinel.Export.ToJSON({ v = fake }), '{"v":"<secret>"}', "export")
end)

Tests:Add("Sentinel", "secret-value error signatures are tagged", function(t)
  local S = scratch(t)
  t:ok(S.SecretTag:IsSecretError("attempt to compare a secret value"), "compare")
  t:ok(S.SecretTag:IsSecretError("Auras cannot be accessed when secret"), "auras")
  t:eq(S.SecretTag:IsSecretError("attempt to index a nil value"), false, "ordinary")
  PUI:Log("api", "C_UnitAuras")
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:3: attempt to perform arithmetic on a secret value", CORE_STACK)
  local _, inc = next(S.db.incidents)
  t:eq(inc.kind, "secret", "kind")
  t:eq(inc.apiFamily, "C_UnitAuras", "api family from the ring")
end)

Tests:Add("Sentinel", "safe mode disables only the failing module", function(t)
  local S = scratch(t)
  for _, n in ipairs({ "PUITest_Bad", "PUITest_Good" }) do
    PUI:RegisterModule(n, { enabledByDefault = true })
    PUI.Kernel:Evaluate(n)
  end
  t:cleanup(function()
    for _, n in ipairs({ "PUITest_Bad", "PUITest_Good" }) do
      PUI.Kernel:SetSafeMode(n, false)
      PUI.Kernel:Unregister(n)
    end
  end)
  local hit = S.SafeMode:Evaluate({ PUITest_Bad = 6, PUITest_Good = 1, Core = 99 }, 5)
  t:eq(#hit, 1, "one module over threshold (Core is never disabled)")
  t:eq(hit[1], "PUITest_Bad", "the failing module")
  S.db.safeModed.PUITest_Bad = 6
  PUI.Kernel:SetSafeMode("PUITest_Bad", true)
  t:eq(PUI.Modules.PUITest_Bad.enabled, false, "failing module off")
  t:eq(PUI.Modules.PUITest_Good.enabled, true, "other module still on")
  S.SafeMode:Release("PUITest_Bad")
  t:eq(PUI.Modules.PUITest_Bad.enabled, true, "re-enabled live")
end)

Tests:Add("Sentinel", "export string decodes to the same contract v2 payload", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: export me", CORE_STACK, "y = \"q\n\"")
  local payload = S.Export:Payload()
  local text = S.Export.Encode(payload)
  t:eq(text:sub(1, 8), "!PUI_SEN", "prefix")
  local back = S.Export.Decode(text)
  t:same(back, S.Export.FromJSON(S.Export.ToJSON(payload)), "round trip")
  t:eq(back.schema, 2, "contract v2")
  t:eq(#back.reports, 1, "one report")
  t:eq(back.reports[1].kind, "error", "kind")
  t:ok(#back.installId >= 16, "install id")
  local id = back.reports[1].id
  t:ok(id:find("^" .. back.installId .. "%-%d+%-%d+$") ~= nil, "id is <installId>-<session>-<n>")
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:20: another one", CORE_STACK, "")
  local again = S.Export:Payload()
  local stable = false
  for i = 1, #again.reports do if again.reports[i].id == id then stable = true end end
  t:ok(stable, "an incident keeps its report id when others are added")
  t:eq(S.Export.StableN("0000000a"), 10, "hex hash -> n")
  t:ok(S.Export.StableN("test-1-2") < 4294967296, "non-hex hash -> bounded n")
  t:eq(S.Export:Build(), nil, "export refused without opt-in")
end)

Tests:Add("Sentinel", "every report carries the game flavor (retail | forever)", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:30: flavor me", CORE_STACK, "")
  local saved = PUI.IS_FOREVER
  t:cleanup(function() PUI.IS_FOREVER = saved end)
  PUI.IS_FOREVER = false
  local p = S.Export:Payload()
  t:eq(p.flavor, "retail", "payload flavor on retail")
  for i = 1, #p.reports do t:eq(p.reports[i].flavor, "retail", "report " .. i .. " flavor on retail") end
  PUI.IS_FOREVER = true
  p = S.Export:Payload()
  t:eq(p.flavor, "forever", "payload flavor on Forever")
  for i = 1, #p.reports do t:eq(p.reports[i].flavor, "forever", "report " .. i .. " flavor on Forever") end
  t:eq(S.Export.FromJSON(S.Export.ToJSON(p)).reports[1].flavor, "forever", "flavor survives the JSON round trip")
end)

Tests:Add("Sentinel", "the previous error handler is still called", function(t)
  local S = scratch(t)
  local calls = 0
  local saved = Hook.previous
  Hook.previous = function() calls = calls + 1 end
  t:cleanup(function() Hook.previous = saved end)
  Hook.onError("Interface/AddOns/Phoenix_UI/Core/Fake.lua:1: chained")
  t:eq(calls, 1, "previous handler ran")
  t:eq(count(S.db.incidents), 1, "and Sentinel captured it")
  t:ok(Hook.mode == "chained" or Hook.mode == "buggrabber", "installed: " .. tostring(Hook.mode))
end)

Tests:Add("Sentinel", "taint, drift, integrity and perf create incidents", function(t)
  local S = scratch(t)
  t:ok(S.Taint:OnAction("ADDON_ACTION_BLOCKED", "Phoenix_UI", "CastSpellByName()"), "taint for Phoenix")
  local other = S.Taint:OnAction("ADDON_ACTION_BLOCKED", "OtherAddon", "x()")
  t:eq(other and other.addon, "OtherAddon", "other addons' blocked actions join their own list")
  t:eq(other and other.kind, "taint", "kept as taint")
  PUI:RegisterModule("PUITest_Drift", { enabledByDefault = true })
  PUI.Kernel:Evaluate("PUITest_Drift")
  t:cleanup(function() PUI.Kernel:SetSafeMode("PUITest_Drift", false); PUI.Kernel:Unregister("PUITest_Drift") end)
  local missing = S.Drift:Run({ apis = { ["C_PhoenixFake.Nope"] = { owners = { "PUITest_Drift" } }, ["C_Timer.After"] = { owners = { "Core" } } } })
  t:eq(#missing, 1, "one missing API")
  t:eq(PUI.Modules.PUITest_Drift.enabled, false, "owner put in safe mode")
  local sv = { profiles = { Default = { ["sentinel.safeModeThreshold"] = "abc", ["future.key"] = 1 } }, chars = { ["A-B"] = "Gone" }, migrations = {} }
  local problems = S.Integrity:Check(sv)
  t:eq(sv.profiles.Default["sentinel.safeModeThreshold"], nil, "bad value repaired")
  t:eq(sv.profiles.Default["future.key"], 1, "unknown key kept")
  t:eq(sv.chars["A-B"], "Default", "orphaned profile repaired")
  t:ok(#problems >= 3, "problems reported")
  local streak = S.Perf.streak
  S.Perf.streak = {}
  t:cleanup(function() S.Perf.streak = streak end)
  S.Perf:Sample({ Core = 1 }, 60)
  S.Perf:Sample({ Core = 1 }, 60)
  t:eq(#S.Perf:Sample({ Core = 1 }, 60), 1, "perf incident on the third sample over budget")
end)

Tests:Add("Sentinel", "viewer shows full incident text and copies one or the session", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: viewer boom", CORE_STACK, "answer = 42")
  local list = S.Viewer:List(true)
  t:eq(#list, 1, "one incident this session")
  local text = S.Viewer:Text(list[1])
  t:ok(text:find("viewer boom", 1, true), "message shown")
  t:ok(text:find("Fake.lua", 1, true), "stack shown")
  t:ok(text:find("answer = 42", 1, true), "locals shown")
  t:ok(text:find("x1", 1, true), "count shown")
  t:ok(S.Viewer:SessionText():find("#1 of 1", 1, true), "session copy lists it")
  if not S.Panel.frame then S.Panel:Build() end
  local inc = S.Panel:Select(1)
  t:eq(inc, list[1], "panel selects the incident")
  local c = S.Panel:CopySelected()
  t:eq(c.copyText, text, "copy box holds the plain text")
  t:ok(S.Panel:CopySession().copyText:find("viewer boom", 1, true), "copy all")
  c:Hide()
  S.Panel.frame:Hide()
  t:ok(S.Export.PREFIX == "!PUI_SEN", "export string kept")
end)
