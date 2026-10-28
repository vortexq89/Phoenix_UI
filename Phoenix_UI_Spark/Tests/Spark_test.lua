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

Tests:Add("Spark", "per-event sounds, aura rows, substitutions, triggers and builder, MSBT import", function(t)
  if not H then return end
  local X = SP.Extras
  for _, k in ipairs({ "module.Spark", "spark.ev.auraGain.on", "spark.ev.auraFade.on", "spark.substitutions", "spark.abbreviate", "spark.triggers",
    "spark.ev.inDamage.sound", "spark.area.incoming.behaviour", "spark.area.incoming.direction", "spark.ev.outDamage.template", "spark.shortNumbers",
    "spark.ev.loot.on", "spark.ev.inDamage.color" }) do Tests.Keep(t, k) end
  Schema:Set("module.Spark", true)
  t:cleanup(function() E.Clear() end)
  -- sound per row (throttled)
  PUI.Media:Register("sound", "Ding", "Interface\\Ding.ogg")
  local played = {}
  local psf = rawget(_G, "PlaySoundFile")
  rawset(_G, "PlaySoundFile", function(path) played[#played + 1] = path end)
  t:cleanup(function() rawset(_G, "PlaySoundFile", psf) end)
  Schema:Set("spark.ev.inDamage.sound", "Ding")
  F.Emit("inDamage", { amount = 10 }); F.Emit("inDamage", { amount = 11 })
  t:eq(#played, 1, "row sound, throttled")
  -- aura rows
  Schema:Set("spark.ev.auraGain.on", true); Schema:Set("spark.ev.auraFade.on", true)
  E.Clear()
  X.OnAura("player", { addedAuras = { { auraInstanceID = 41, name = "Power Word: Fortitude" }, { auraInstanceID = 42, name = H.secret("Hidden") } } })
  E.Flush(true)
  t:ok(texts():find("+Power Word: Fortitude", 1, true), "aura gain line")
  t:eq(X.auraNames[42], nil, "secret aura name skipped")
  X.OnAura("player", { removedAuraInstanceIDs = { 41 } })
  E.Flush(true)
  t:ok(texts():find("-Power Word: Fortitude", 1, true), "aura fade line")
  -- substitutions and abbreviation
  Schema:Set("spark.substitutions", { "Mortal Strike = MS" })
  t:eq(X.Text("Mortal Strike"), "MS", "substitution")
  Schema:Set("spark.abbreviate", true)
  t:eq(X.Text("Shadow Word: Pain Extended"), "SWPE", "long names shortened")
  t:eq(X.Text(H.secret("x")) ~= nil, true, "secret names pass through untouched")
  Schema:Set("spark.abbreviate", false)
  -- triggers and builder
  local b = X.Builder()
  X.CycleKind()
  t:eq(b.draft.kind, "auraGain", "builder cycles the condition")
  b.draft.match = "Bloodlust"; b.draft.message = "LUST!"; b.draft.hex = "ff0000"
  t:ok(X.AddDraft(), "builder adds a line")
  t:eq(Schema:Get("spark.triggers")[1], "auraGain | Bloodlust | LUST! | ff0000 | ", "stored as a readable line")
  b:Hide()
  E.Clear()
  X.OnAura("player", { addedAuras = { { auraInstanceID = 50, name = "Bloodlust" } } })
  E.Flush(true)
  t:ok(texts():find("LUST!", 1, true), "trigger fired on the aura")
  Schema:Set("spark.triggers", { "cast | 133 | Fireball out |  | " })
  t:eq(X.Fire("cast", "Fireball", 133), 1, "cast trigger by spell ID")
  t:eq(X.Fire("cast", H.secret("Fireball"), H.secret(133)), 0, "secret cast never compared")
  -- MSBT import
  local sv = { profiles = { Main = {
    scrollAreas = { Incoming = { animationStyle = "Straight", direction = "Up", textAlignIndex = 2, scrollHeight = 900 } },
    events = { OUTGOING_DAMAGE = { message = "%a (%n) %sl" }, NOTIFICATION_LOOT = { disabled = true }, INCOMING_DAMAGE = { colorR = 0.5, colorG = 0, colorB = 0 } },
    shortenNumbers = false, abilitySubstitutions = { ["Mortal Strike"] = "Morty" } } } }
  t:eq(select(2, X.ImportMSBT(nil, nil)), "MikScrollingBattleText's saved settings are not loaded", "needs MSBT's data")
  local n = X.ImportMSBT(sv, { currentProfileName = "Main" })
  t:ok(n >= 8, "settings written: " .. tostring(n))
  t:eq(Schema:Get("spark.area.incoming.behaviour"), "scroll", "animation mapped")
  t:eq(Schema:Get("spark.area.incoming.direction"), "up", "direction mapped")
  t:eq(Schema:Get("spark.ev.outDamage.template"), "%a %s", "message tokens mapped")
  t:eq(Schema:Get("spark.ev.loot.on"), false, "event off mapped")
  t:eq(Schema:Get("spark.ev.inDamage.color").r, 0.5, "colour mapped")
  t:eq(Schema:Get("spark.substitutions")[1], "Mortal Strike = Morty", "substitutions imported")
end)
