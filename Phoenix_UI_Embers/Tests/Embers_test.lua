local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Embers.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local EM = ns.EM

local function enable(t)
  local saved = { Schema:Get("module.Embers"), Schema:Get("embers.segments"), Schema:Get("embers.windows") }
  t:cleanup(function()
    Schema:Set("embers.windows", saved[3]); Schema:Set("embers.segments", saved[2]); Schema:Set("module.Embers", saved[1])
    H.meter.current = nil; H.meter.sessions = {}; H.meter.list = {}; H.inCombat = false; H.secretMode = false; H.chatLocked = false; wipe(H.chat)
  end)
  Schema:Set("module.Embers", true)
end

local ROWS = { { name = "Tester", class = "MAGE", amount = 9000, aps = 300, me = true }, { name = "Ally", class = "PRIEST", amount = 6000, aps = 200 } }

Tests:Add("Embers", "off by default; zero cost; every setting has apply", function(t)
  t:eq(Schema:Def("module.Embers").default, false, "module defaults off")
  for key, def in pairs(EM.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.Embers") then
    t:eq(Ticker:IsRegistered("embers.graph"), false, "no sampler while off")
    t:eq(#EM.windows, 0, "no windows built while off")
  end
end)

Tests:Add("Embers", "live window takes secret values without touching them", function(t)
  if not H then return end
  enable(t)
  H.meter.current = { max = 9000, total = 15000, duration = 30, rows = ROWS }
  H.secretMode = true
  EM.RefreshWindows()
  local w = EM.windows[1]
  t:ok(w.rows[1]:IsShown() and w.rows[2]:IsShown(), "rows drawn from secret data")
  t:eq(w.rows[3]:IsShown(), false, "no extra rows")
  H.secretMode = false
  Schema:Set("embers.windows", 3)
  t:ok(EM.windows[3] and EM.windows[3].frame:IsShown(), "windows count applies live")
  Schema:Set("embers.windows", 1)
  t:eq(EM.windows[3].frame:IsShown(), false, "extra windows hidden")
end)

Tests:Add("Embers", "finished sessions saved after combat; secrets dropped; cap and pins", function(t)
  if not H then return end
  enable(t)
  Schema:Set("embers.segments", {})
  H.meter.sessions[5] = { max = 9000, total = 15000, duration = 30, rows = ROWS }
  H.meter.list = { { sessionID = 5, name = "Boss A" } }
  H.inCombat = true
  EM.OnSession(nil, nil, 0, 5)
  t:eq(#EM.Store(), 0, "nothing saved in combat")
  H.inCombat = false
  CQ.Drain()
  local seg = EM.Store()[1]
  t:ok(seg and seg.name == "Boss A" and seg.rows[1].name == "Tester", "segment saved with sorted rows")
  H.secretMode = true
  t:eq(EM.Capture(5, "Hidden"), nil, "fully secret session is not kept")
  H.secretMode = false
  EM.Pin(1, true)
  Schema:Set("embers.maxSegments", 5)
  t:cleanup(function() Schema:Set("embers.maxSegments", 30) end)
  for i = 1, 7 do EM.Save(EM.Capture(5, "Trash " .. i)) end
  local pinned, n = false, 0
  for _, x in ipairs(EM.Store()) do n = n + 1; if x.pinned then pinned = true end end
  t:eq(n, 6, "cap of 5 plus the pinned one")
  t:ok(pinned, "pinned segment kept")
end)

Tests:Add("Embers", "merge, compare, export/import, report gating", function(t)
  if not H then return end
  enable(t)
  Schema:Set("embers.segments", {})
  H.meter.sessions[1] = { max = 9000, total = 15000, duration = 30, rows = ROWS }
  EM.Save(EM.Capture(1, "Pull")); EM.Save(EM.Capture(1, "Pull"))
  local merged = EM.Merge({ 1, 2 }, "Both")
  t:eq(merged.rows[1].amount, 18000, "amounts summed")
  local cmp = EM.Compare("Pull", "Tester")
  t:eq(cmp.runs, 2, "two runs compared")
  local text = EM.Export(1)
  t:ok(text:sub(1, 10) == "!PUI_EMB1:", "export prefix")
  local back = EM.Import(text)
  t:eq(back.rows[1].amount, 18000, "import round trip")
  t:eq(EM.Import("garbage"), nil, "bad string refused")
  H.chatLocked = true
  local ok = EM.Report(1, "party")
  t:eq(ok, false, "no report while chat is locked")
  H.chatLocked = false
  t:ok(EM.Report(1, "party"), "report sent")
  t:eq(H.chat[1][2], "PARTY", "to the chosen channel")
  t:ok(#H.chat >= 2, "header and rows")
end)
