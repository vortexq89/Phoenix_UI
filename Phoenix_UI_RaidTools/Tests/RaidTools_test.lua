local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Raid Tools (countdowns, ready check, encounter stats).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local RT = ns.RT
local ST = RT.Stats

local function called(name)
  for _, c in ipairs(H.calls) do if c[1] == name then return c end end
end

Tests:Add("RaidTools", "owner of countdowns: /pui pull, /pui cd alias, shared state for Pulse", function(t)
  t:eq(Schema:Def("module.RaidTools").default, true, "on by default")
  for k, def in pairs(RT.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  if not H then return end
  local seen = {}
  PUI.Kernel:On("COUNTDOWN", function(c) seen[#seen + 1] = c and c.kind or "none" end)
  wipe(H.calls)
  PUI.Slash.commands.cd.fn("7")
  t:eq(called("DoCountdown")[2], 7, "/pui cd starts Blizzard's group countdown")
  H.fire("START_PLAYER_COUNTDOWN", "Tester", 7, 7)
  t:eq(RT.countdown.kind, "pull", "countdown state shared")
  t:eq(seen[#seen], "pull", "Kernel COUNTDOWN fired for Pulse")
  t:eq(RT.CountdownText(), "Pull 7", "bar text")
  H.fire("CANCEL_PLAYER_COUNTDOWN", "Tester")
  t:eq(RT.countdown, nil, "cancel clears it")
  t:ok(RT.Break(5), "break starts")
  t:eq(RT.CountdownText(), "Break 5:00", "break shows minutes")
  H.step(301)
  H.step()
  t:eq(RT.countdown, nil, "break ends by itself on the Ticker")
  wipe(H.calls)
  RT.KeyCountdown()
  t:eq(called("DoCountdown")[2], Schema:Get("rt.mplusCountdown"), "key countdown length")
  H.fire("START_PLAYER_COUNTDOWN", "Tester", 10, 10)
  t:eq(RT.countdown.kind, "mplus", "key countdown labelled")
  wipe(H.calls)
  RT.Cancel()
  t:eq(called("DoCountdown")[2], 0, "cancel sends a zero countdown")
  t:eq(RT.countdown, nil, "state cleared")
end)

Tests:Add("RaidTools", "ready check summary leaves hidden names out", function(t)
  if not H then return end
  wipe(RT.ready)
  RT.ready.player, RT.ready.party1 = true, false
  local name = UnitName
  UnitName = function(u) if u == "party1" then return "Pal" elseif u == "party2" then return H.secret("Ghost") end return "Tester" end
  t:cleanup(function() UnitName = name end)
  t:eq(RT.Summary({ "player", "party1", "party2" }), "Not ready: Pal - 1 more", "not ready named, secret name counted only")
  RT.ready.party1 = true
  t:eq(RT.Summary({ "player", "party1" }), "All ready", "all ready")
end)

Tests:Add("RaidTools", "encounter stats: kills, wipes, best compare, wipe trend, CSV, boss-mod stand-down", function(t)
  if not H then return end
  local store = ST.Store()
  local saved = {}
  for k, v in pairs(store) do saved[k] = v; store[k] = nil end
  t:cleanup(function() for k in pairs(store) do store[k] = nil end; for k, v in pairs(saved) do store[k] = v end end)
  local day = 1761500000
  ST.Record(3009, "Vexie", 16, 200, false, day)
  ST.Record(3009, "Vexie", 16, 260, false, day + 600)
  ST.Record(3009, "Vexie", 16, 342, true, day + 86400)
  local e = ST.Record(3009, "Vexie", 16, 350, true, day + 86400 * 2)
  t:eq(e.kills, 2, "kills"); t:eq(e.wipes, 2, "wipes")
  t:eq(e.best, 342, "best kill")
  t:eq(ST.Compare(e), "+0:08 vs best", "last pull compared with best")
  e = ST.Record(3009, "Vexie", 16, 330, true, day + 86400 * 3)
  t:eq(ST.Compare(e), "-0:12 vs best (new best)", "new best")
  t:ok(ST.TrendText(e):find("4:20", 1, true), "wipe trend uses the longest pull per night: " .. ST.TrendText(e))
  t:ok(ST.CSV():find("Vexie,16,3,2,5:30", 1, true), "CSV export")
  Schema:Set("module.RaidTools", true)
  H.addonLoaded.BigWigs = true
  H.fire("ENCOUNTER_START", 3010, "Cauldron", 16, 20)
  H.fire("ENCOUNTER_END", 3010, "Cauldron", 16, 20, 0)
  t:eq(store[ST.Key(3010, 16)], nil, "a boss mod keeps its own stats; Phoenix stands down")
  H.addonLoaded.BigWigs = nil
  H.fire("ENCOUNTER_START", 3010, "Cauldron", 16, 20)
  H.step(30)
  H.fire("ENCOUNTER_END", 3010, "Cauldron", 16, 20, 0)
  t:eq(store[ST.Key(3010, 16)].wipes, 1, "recorded without a boss mod")
  t:ok(ST.Reset(3010, 16), "reset one boss")
end)

Tests:Add("RaidTools", "live preview follows the bar settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = Schema:Get("rt.worldMarkers")
  t:cleanup(function() Schema:Set("rt.worldMarkers", saved) end)
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  Schema:Set("rt.worldMarkers", false)
  P.RaidTools(card)
  t:eq(P.State(card).rtLines, 5, "bar and stats lines")
  t:eq(P.State(card).hud.rt.lines[1]:GetText():find("world markers", 1, true), nil, "world markers left out live")
end)

Tests:Add("RaidTools", "notes out of combat, boss tooltip stats line, stats window with reset", function(t)
  if not H then return end
  local X = RT.Extras
  Tests.Keep(t, "rt.notesText"); Tests.Keep(t, "module.RaidTools"); Tests.Keep(t, "rt.stats.scope")
  Schema:Set("module.RaidTools", true)
  Schema:Set("rt.notesText", { "Dummy: soak the left orb", "*: lust on pull", "Other Boss: spread", "not a note" })
  t:eq(#X.NotesFor("Dummy"), 2, "boss lines plus * lines")
  t:eq(#X.NotesFor("dummy"), 2, "case-insensitive boss names")
  t:eq(#X.NotesFor(nil), 1, "only * lines without a boss")
  H.units.target = true
  t:cleanup(function() H.units.target = nil; H.inCombat = false end)
  H.fire("PLAYER_TARGET_CHANGED")
  t:ok(X.notes and X.notes:IsShown(), "notes shown out of combat")
  t:ok(X.notes.body:GetText():find("soak the left orb", 1, true), "target's boss lines")
  H.inCombat = true; H.fire("PLAYER_REGEN_DISABLED")
  t:eq(X.notes:IsShown(), false, "hidden when combat starts")
  H.inCombat = false; PUI.CombatQueue.Drain()
  t:ok(X.notes:IsShown(), "back after combat")
  -- tooltip line
  local store = ST.Store()
  local saved = {}
  for k, v in pairs(store) do saved[k] = v; store[k] = nil end
  t:cleanup(function() for k in pairs(store) do store[k] = nil end; for k, v in pairs(saved) do store[k] = v end end)
  ST.Record(9001, "Dummy", 0, 250, true, 1000); ST.Record(9001, "Dummy", 0, 200, false, 1100)
  local tip = CreateFrame("GameTooltip")
  X.OnTooltip(tip)
  t:ok(rawget(tip, "lines") == nil, "player tooltip unchanged")
  tip.GetUnit = function() return "Dummy", "boss1" end
  X.OnTooltip(tip)
  t:ok(rawget(tip, "lines") and tostring(tip.lines[1]):find("1 kills, 1 wipes", 1, true), "boss tooltip stats line")
  -- stats window
  local f = X.ShowStats()
  t:ok(f:IsShown() and f.rows[1]:IsShown(), "stats window lists the boss")
  local accepted
  local confirm = PUI.Dialogs.Confirm
  PUI.Dialogs.Confirm = function(_, o) accepted = o end
  t:cleanup(function() PUI.Dialogs.Confirm = confirm; f:Hide() end)
  f.rows[1].reset:GetScript("OnClick")(f.rows[1].reset)
  t:ok(accepted, "reset asks first")
  accepted.onAccept()
  t:eq(store["9001:0"], nil, "reset after confirm")
end)
