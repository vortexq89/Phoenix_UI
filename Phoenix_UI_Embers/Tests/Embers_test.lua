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

-- Step 8c ------------------------------------------------------------------------
local function many(n, meAt)
  local rows = {}
  for i = 1, n do rows[i] = { name = "P" .. i, class = "MAGE", amount = 10000 - i * 100, aps = 100 - i, me = i == meAt } end
  return rows
end

Tests:Add("Embers", "up to four windows, per-window meter and fight; own row pinned with its rank", function(t)
  if not H then return end
  enable(t)
  local saved = { Schema:Get("embers.w2.meter"), Schema:Get("embers.rows"), Schema:Get("embers.pinSelf") }
  t:cleanup(function() Schema:Set("embers.w2.meter", saved[1]); Schema:Set("embers.rows", saved[2]); Schema:Set("embers.pinSelf", saved[3]) end)
  t:eq(Schema:Def("embers.windows").max, 4, "four windows at most")
  Schema:Set("embers.windows", 2)
  Schema:Set("embers.w2.meter", "Interrupts")
  t:eq(EM.windows[2].meter, "Interrupts", "window 2 meter applies live")
  Schema:Set("embers.rows", 5)
  H.meter.current = { max = 10000, total = 99999, duration = 30, rows = many(12, 11) }
  EM.RefreshWindows()
  local w = EM.windows[1]
  t:eq(w.rows[5].data.name, "P11", "your row takes the last place")
  t:ok(w.rows[5].nameText:GetText():find("^11%. "), "with your real rank")
  t:eq(w.rows[6]:IsShown(), false, "no sixth row")
  Schema:Set("embers.pinSelf", false)
  t:eq(w.rows[5].data.name, "P5", "pin off: plain top five")
  local list = EM.Window.Visible(many(3, 2), 5, true)
  t:eq(#list, 3, "fewer rows than space: nothing replaced")
end)

Tests:Add("Embers", "threat window, breakdown flyout and death recap take secret values as they are", function(t)
  if not H then return end
  enable(t)
  local saved = Schema:Get("embers.w1.meter")
  t:cleanup(function() Schema:Set("embers.w1.meter", saved); H.threatPct = {}; H.meter.spells = {}; H.recaps = {}; EM.Recap.Close(); EM.Recap.HideBreakdown() end)
  H.threatPct.player = 87
  H.secretMode = true
  Schema:Set("embers.w1.meter", "Threat")
  local w = EM.windows[1]
  t:ok(w.rows[1]:IsShown(), "threat row drawn from a secret percent")
  t:ok(w.title.text:GetText():find("Threat", 1, true), "title names the window type")
  H.secretMode = false
  Schema:Set("embers.w1.meter", "DamageDone")
  local rows = { { name = "Tester", class = "MAGE", amount = 9000, aps = 300, me = true } }
  H.meter.current = { max = 9000, total = 9000, duration = 30, rows = rows }
  EM.RefreshWindows()
  w.rows[1].data.guid = "Player-1"
  H.meter.spells["Player-1"] = { { 133, 6000 }, { 11366, 3000 } }
  H.secretMode = true
  EM.Window.OnEnter(w, w.rows[1])
  t:ok(EM.Recap.flyout:IsShown(), "breakdown flyout opens on hover")
  t:eq(EM.Recap.spells[2]:IsShown(), true, "one line per spell")
  t:ok(EM.Recap.side == "left" or EM.Recap.side == "right", "flyout picks a side")
  H.recaps[7] = { { "Poison Bolt", 412000, 18, "Kyveza" }, { "Melee", 120000, 40, "Add" } }
  local n = EM.Recap.Open(7, "Tester", "MAGE")
  H.secretMode = false
  t:eq(n, 2, "recap lists the events")
  t:ok(EM.Recap.frame:IsShown(), "recap window open")
  t:eq(EM.Recap.Open(99, "Nobody"), 0, "missing recap explained, no error")
  t:ok(EM.Recap.lines[1]:GetText():find("No recap", 1, true), "explains why it is empty")
end)

Tests:Add("Embers", "best pull on the same boss: header, marker on my row, result after the pull", function(t)
  if not H then return end
  enable(t)
  Schema:Set("embers.segments", {})
  local rows = function(aps) return { { name = "Tester", class = "MAGE", amount = aps * 30, aps = aps, me = true }, { name = "Ally", class = "PRIEST", amount = 1000, aps = 30 } } end
  -- an earlier kill of boss 2900 on difficulty 16
  H.meter.sessions[1] = { max = 9000, total = 10000, duration = 30, rows = rows(300) }
  H.meter.list = { { sessionID = 1, name = "Boss A" } }
  EM.OnEncounterEnd(nil, nil, 2900, "Boss A", 16, 20, 1)
  EM.OnSession(nil, nil, 0, 1)
  local best = EM.BestPull(2900, 16)
  t:eq(best and best.aps, 300, "best pull found by boss and difficulty")
  t:eq(EM.BestPull(2900, 15), nil, "other difficulty is separate")
  -- a new pull that beats it by 10%
  H.meter.sessions[2] = { max = 9900, total = 11000, duration = 30, rows = rows(330) }
  H.meter.list = { { sessionID = 2, name = "Boss A" } }
  EM.OnSession(nil, nil, 0, 2)
  local seg = EM.Store()[1]
  t:ok(seg.vsBest and math.abs(seg.vsBest - 10) < 0.01, "result against your best is kept (+10%)")
  -- live: during the encounter the header shows your best and your row gets the marker
  H.fire("ENCOUNTER_START", 2900, "Boss A", 16, 20)
  t:cleanup(function() H.fire("ENCOUNTER_END", 2900, "Boss A", 16, 20, 0) end)
  H.meter.current = { max = 9900, total = 11000, duration = 30, rows = rows(200) }
  H.secretMode = true
  EM.RefreshWindows()
  H.secretMode = false
  local w = EM.windows[1]
  t:ok(w.title.right:GetText():find("best", 1, true), "header shows your best on this boss")
  t:ok(w.rows[1].ghost:IsShown(), "best-pull marker on your row")
  t:eq(w.rows[2].ghost:IsShown(), false, "no marker on other rows")
end)

Tests:Add("Embers", "owners: deaths, interrupts and run totals for Ascent; shared combat timer in the title", function(t)
  if not H then return end
  enable(t)
  H.meter.current = { max = 6, total = 10, duration = 30, rows = { { name = "Tester", class = "MAGE", amount = 6, aps = 0.2, me = true }, { name = "Ally", class = "PRIEST", amount = 4, aps = 0.1 } } }
  local kicks = EM.Interrupts("Overall")
  t:eq(#kicks, 2, "interrupt counts for every source")
  t:eq(kicks[1].count, 6, "count as the API gives it")
  local totals = EM.Totals({ "DamageDone", "Interrupts" })
  t:eq(totals.Ally.Interrupts, 4, "run totals by name")
  H.secretMode = true
  t:eq(next(EM.Totals({ "DamageDone" })), nil, "secret names are left out of saved totals")
  H.secretMode = false
  local T = PUI.CombatTimer
  H.inCombat = true
  H.fire("PLAYER_REGEN_DISABLED")
  t:ok(T:Running(), "timer runs in combat")
  t:ok(Ticker:IsRegistered("timer.watch"), "combat-end watch on the Ticker")
  for _ = 1, 10 do H.step(0.5) end
  EM.RefreshWindows()
  t:ok(EM.windows[1].title.right:GetText():find("%d:%d%d"), "title shows the shared timer")
  H.inCombat = false
  T:Watch()
  t:eq(T:Running(), false, "stops when combat ends")
  t:eq(Ticker:IsRegistered("timer.watch"), false, "no timer job out of combat")
  t:ok(T.last.seconds >= 4, "last fight length kept")
end)

Tests:Add("Embers", "conflict notice with Details; settings carried over from step 6", function(t)
  if not H then return end
  enable(t, "core.coexist.embers")
  local saved = Schema:Get("core.coexist.embers")
  H.addonLoaded.Details = true
  t:cleanup(function() H.addonLoaded.Details = nil; Schema:Set("core.coexist.embers", saved); PUI.Kernel:Evaluate("Embers") end)
  PUI.Kernel:Evaluate("Embers")
  t:eq(EM.active, false, "dormant until the user picks")
  PUI.Coexist:Pick("embers", "phoenix")
  t:eq(EM.active, true, "Phoenix keeps the meter")
  local sv = { profiles = { Default = { ["embers.meter"] = "HealingDone", ["embers.look"] = "bars", ["embers.windows"] = 5 } } }
  t:eq(PUI.DB.migrations["0008c_embers_keys"](sv), true, "migration ran")
  local p = sv.profiles.Default
  t:same({ p["embers.w1.meter"], p["embers.look"], p["embers.windows"], p["embers.meter"] }, { "HealingDone", "phoenix", 4, nil }, "choices kept, nothing reset")
end)

Tests:Add("Embers", "live preview uses the module's look, pinned row and number format", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = { Schema:Get("embers.rows"), Schema:Get("embers.forcedUnit") }
  t:cleanup(function() Schema:Set("embers.rows", saved[1]); Schema:Set("embers.forcedUnit", saved[2]) end)
  Schema:Set("embers.rows", 6)
  Schema:Set("embers.forcedUnit", "K")
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Embers(card)
  local h = P.State(card).hud.embers
  t:eq(P.State(card).embersRows, 6, "rows follow the setting")
  t:ok(h.mrows[6].l:GetText():find("You", 1, true), "your row pinned in the preview")
  t:ok(h.mrows[1].r:GetText():find("K", 1, true), "forced unit applied")
end)
