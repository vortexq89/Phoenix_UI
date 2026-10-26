local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Spark (Blizzard SCT via the ledger, feed, merge, cap).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local SP = ns.SP
local E, F = SP.Engine, SP.Feed

local function lastText()
  local best
  for l in pairs(E.active) do if not best or (l.order or 0) > (best.order or 0) then best = l end end
  return best and best.text:GetText()
end
local function texts()
  local out = {}
  for l in pairs(E.active) do out[#out + 1] = tostring(l.text:GetText()) end
  table.sort(out)
  return table.concat(out, " | ")
end

Tests:Add("Spark", "on by default; turns ALL Blizzard combat text off through the CVar ledger and restores it", function(t)
  t:eq(Schema:Def("module.Spark").default, true, "on by default")
  for _, c in ipairs({ "outgoing", "incoming", "notifications" }) do t:eq(Schema:Get("spark.blizz_" .. c), true, c .. " off by default") end
  t:eq(Schema:Get("core.coexist.spark"), "ask", "MSBT conflict: you pick")
  for k, def in pairs(SP.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  if not H then return end
  Schema:Set("module.Spark", true)
  t:eq(H.cvars.floatingCombatTextCombatDamage, "0", "outgoing off")
  t:eq(H.cvars.enableFloatingCombatText, "0", "incoming off")
  t:eq(H.cvars.floatingCombatTextCombatState, "0", "notifications off")
  Schema:Set("spark.blizz_outgoing", false)
  t:eq(H.cvars.floatingCombatTextCombatDamage, "1", "one category restored live")
  Schema:Set("spark.blizz_outgoing", true)
  Schema:Set("module.Spark", false)
  t:eq(H.cvars.enableFloatingCombatText, "1", "Spark off restores everything")
  Schema:Set("module.Spark", true)
end)

Tests:Add("Spark", "message templates: secret amounts go to the formatter, plain tokens are escaped", function(t)
  local fmt, args = E.Compose("%a %s %c", { amount = "12.4K", spell = "100% Strike", count = 3 })
  t:eq(fmt, "%s 100%% Strike x3", "spell escaped, count token")
  t:eq(args[1], "12.4K", "amount is an argument")
  if not H then return end
  Schema:Set("module.Spark", true)
  E.Clear()
  F.OnUnitCombat("player", "WOUND", "CRITICAL", H.secret(12480), 4)
  E.Flush(true)
  t:eq(E.ActiveCount(), 1, "incoming line shown")
  t:eq(lastText(), "<secret-formatted>", "secret amount written by the engine")
  E.Clear()
end)

Tests:Add("Spark", "outgoing attribution from your own casts; merge; line cap", function(t)
  if not H then return end
  Schema:Set("module.Spark", true)
  E.Clear()
  F.lastCast = nil
  F.OnUnitCombat("target", "WOUND", nil, 900, 1)
  E.Flush(true)
  t:eq(E.ActiveCount(), 0, "unsure hit hidden in the default mode")
  F.OnCast("player", "g", 772)
  for _ = 1, 5 do F.OnUnitCombat("target", "WOUND", nil, 1200, 1) end
  E.Flush(true)
  t:eq(E.ActiveCount(), 1, "five hits merged into one line")
  t:eq(lastText(), "6K Spell 772 x5", "summed, named, counted: " .. tostring(lastText()))
  E.Clear()
  Schema:Set("spark.merge", false)
  Schema:Set("spark.area.outgoing.cap", 3)
  t:cleanup(function() Schema:Set("spark.merge", true); Schema:Set("spark.area.outgoing.cap", 12); E.Clear() end)
  F.OnCast("player", "g", 772)
  for _ = 1, 8 do F.OnUnitCombat("target", "WOUND", nil, 100, 1) end
  E.Flush(true)
  t:eq(E.ActiveCount(), 4, "three lines plus one \"+N more\"")
  t:ok(texts():find("+5 more", 1, true), "overflow merged: " .. texts())
end)

Tests:Add("Spark", "combat in/out, item ready, loot, money and XP presets", function(t)
  if not H then return end
  Schema:Set("module.Spark", true)
  E.Clear()
  H.inCombat = true
  H.fire("PLAYER_REGEN_DISABLED")
  E.Flush(true)
  t:ok(texts():find("+Combat", 1, true), "entering combat")
  H.step(0.6)
  t:eq(texts():find("-Combat", 1, true), nil, "still fighting")
  H.inCombat = false
  H.step(0.6)
  E.Flush(true)
  t:ok(texts():find("-Combat", 1, true), "leaving combat")
  t:eq(PUI.Ticker:IsRegistered("spark.combat"), false, "combat watch gone after the fight")
  E.Clear()
  H.itemCD[5512] = { GetTime(), 60 }
  H.fire("BAG_UPDATE_COOLDOWN")
  t:ok(PUI.Ticker:IsRegistered("spark.items"), "watching while on cooldown")
  H.itemCD[5512] = nil
  H.step(61); H.step(1)
  E.Flush(true)
  t:ok(texts():find("Item 5512 ready", 1, true), "item ready: " .. texts())
  t:eq(PUI.Ticker:IsRegistered("spark.items"), false, "watch ends")
  E.Clear()
  H.fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:1234::|h[Blade]|h|rx2.", "", "", "", "", "", 0, 0, "", 0, 1, UnitGUID("player"))
  H.fire("CHAT_MSG_LOOT", "Pal receives loot: |cffa335ee|Hitem:99::|h[Other]|h|r.", "", "", "", "", "", 0, 0, "", 0, 2, "Player-1-party1")
  E.Flush(true)
  t:ok(texts():find("[Blade]", 1, true) and texts():find("x2", 1, true), "own loot with count: " .. texts())
  t:eq(texts():find("[Other]", 1, true), nil, "other players' loot left out")
  E.Clear()
  t:eq(SP.Test() > 5, true, "test samples go through every area")
  E.Flush(true)
  t:ok(E.ActiveCount() > 5, "samples shown")
  E.Clear()
end)

Tests:Add("Spark", "live preview shows the four areas with sample lines", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Spark(card)
  t:eq(P.State(card).sparkAreas, 4, "four areas")
  Schema:Set("spark.area.static.enabled", false)
  t:cleanup(function() Schema:Set("spark.area.static.enabled", true) end)
  P.Spark(card)
  t:eq(P.State(card).sparkAreas, 3, "an area turned off leaves the preview live")
end)
