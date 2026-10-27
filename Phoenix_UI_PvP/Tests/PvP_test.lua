local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for PvP (rated data, title progress, columns, leave
-- countdown, Solo Shuffle rounds).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local PV = ns.PvP
local R, C, M = PV.Rated, PV.Columns, PV.Match

Tests:Add("PvP", "first-install defaults; every key applies live", function(t)
  t:eq(Schema:Def("module.PvP").default, true, "on")
  t:eq(Schema:Get("pvp.leave"), true, "leave countdown on")
  t:eq(Schema:Get("pvp.leaveSeconds"), 15, "15 s")
  t:eq(Schema:Get("pvp.chatChange"), false, "chat line opt-in")
  for k, def in pairs(PV.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  Schema:Set("pvp.leaveSeconds", 20)
  t:eq(PV.settings.leaveSeconds, 20, "applies without a reload")
  Schema:Set("pvp.leaveSeconds", 15)
end)

Tests:Add("PvP", "rating change, wins at the title rating, weekly record", function(t)
  local before = { ["3v3"] = { rating = 2400, seasonWon = 30 }, shuffle = { rating = 2380, roundsSeasonWon = 10 } }
  local after = { ["3v3"] = { rating = 2416, seasonWon = 31 }, shuffle = { rating = 2410, roundsSeasonWon = 14 } }
  local d = R.Diff(before, after, "3v3")
  t:eq(d.change, 16, "rating change")
  t:eq(d.wins, 1, "one win")
  local db = {}
  R.Count(db, 7, d, "3v3", { gladiator = 2400 })
  t:eq(db.progress[7].gladiator, 1, "win at 2400 counts for Gladiator")
  R.Count(db, 7, R.Diff(before, after, "shuffle"), "shuffle", { legend = 2400 })
  t:eq(db.progress[7].legend, nil, "rounds below the rating do not count")
  local have, need, src = R.Progress("gladiator", db, 7, { need_gladiator = 50, ach_gladiator = 0 })
  t:eq(have, 1, "have"); t:eq(need, 50, "need"); t:eq(src, "phoenix", "Phoenix's own count without an achievement")
  local won, lost = R.WeekRecord({ ["2v2"] = { weekWon = 3, weekPlayed = 5 }, shuffle = { roundsWeek = 12, roundsWeekWon = 7 } })
  t:eq(won, 10, "week wins incl. rounds"); t:eq(lost, 7, "week losses")
  local db2 = {}
  for i = 1, 4 do R.Remember(db2, { n = i }, 3) end
  t:eq(#db2.history, 3, "history capped"); t:eq(db2.history[1].n, 4, "newest first")
end)

Tests:Add("PvP", "scoreboard column registry: other addons add columns; your order; sort; secrets", function(t)
  C:Register("PUITest_col", { label = "Test", value = function(sc) return sc.x end, external = true })
  local picked = C:Pick({ "PUITest_col", "nope", "name" })
  t:eq(#picked, 2, "unknown ids skipped"); t:eq(picked[1].id, "PUITest_col", "your order kept")
  local rows = C.Sort({ { damageDone = 5 }, { damageDone = 9 }, { damageDone = 1 } }, "damage", true)
  t:eq(rows[1].damageDone, 9, "highest first")
  t:eq(C.Format(1234567, "short"), "1.2M", "short numbers")
  t:eq(C.Format(-12, "signed"), "-12", "signed")
  if H then t:eq(C.Format(H.secret(5), "number"), nil, "secret goes to the widget unformatted") end
  t:eq(C.Mine({ guid = "G" }, "G", 0), "me", "you")
  t:eq(C.Mine({ guid = "X", faction = 1 }, "G", 1), "team", "your team")
  C.defs.PUITest_col = nil
  for i, id in ipairs(C.order) do if id == "PUITest_col" then table.remove(C.order, i) end end
end)

Tests:Add("PvP", "leave countdown: counts down, waits in combat, never in arenas", function(t)
  local st = { left = 2 }
  local s = { leaveNotInCombat = true }
  t:eq(M.Step(st, false, s), "counting", "2 -> 1")
  t:eq(M.Step(st, true, s), "waiting", "0 in combat waits")
  t:eq(M.Step(st, false, s), "leave", "leaves out of combat")
  t:eq(M.Step({}, false, s), "idle", "nothing running")
  if not H then return end
  Schema:Set("module.PvP", true)
  H.pvp = "arena"
  PV.OnMatchComplete()
  t:eq(M.left, nil, "arenas are never left for you")
  H.pvp = "bg"
  PV.OnMatchComplete()
  t:eq(M.left, 15, "battleground countdown starts at 15")
  t:ok(PUI.Ticker.entries["pvp.leave"] ~= nil, "one Ticker entry while counting")
  M.Cancel()
  t:eq(PUI.Ticker.entries["pvp.leave"], nil, "cancel stops it")
  H.pvp = nil
end)

Tests:Add("PvP", "Solo Shuffle round tracker follows the game's match state", function(t)
  if not H then return end
  local s = { shuffleTracker = true }
  M.ResetRounds()
  H.soloShuffle, H.matchState = true, Enum.PvPMatchState.Engaged
  M.OnState(s)
  t:eq(M.round, 1, "round 1")
  H.matchState = Enum.PvPMatchState.PostRound; M.OnState(s)
  H.matchState = Enum.PvPMatchState.Engaged; M.OnState(s)
  t:eq(M.round, 2, "round 2")
  t:ok(M.RoundText():find("Round 2 of 6", 1, true) ~= nil, "text")
  M.ResetRounds(); H.soloShuffle = nil
end)

Tests:Add("PvP", "rated card lines and the test command", function(t)
  if not H then return end
  Schema:Set("module.PvP", true)
  local e = PV.Test()
  t:eq(e.change, 16, "sample result")
  local lines = PV.Card.Lines(PV.settings, PV.DB(), 0, {})
  local text = {}
  for _, l in ipairs(lines) do text[#text + 1] = l[1] end
  text = table.concat(text, "\n")
  t:ok(text:find("+16", 1, true) ~= nil, "rating change on the card")
  t:ok(text:find("Gladiator", 1, true) ~= nil, "title progress")
  M.Cancel()
end)

Tests:Add("PvP", "live preview follows the settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.PvP(card)
  local n = P.State(card).pvpLines
  Schema:Set("pvp.cardProgress", false)
  t:cleanup(function() Schema:Set("pvp.cardProgress", true) end)
  P.PvP(card)
  t:eq(P.State(card).pvpLines, n - 3, "progress lines leave the preview at once")
end)
