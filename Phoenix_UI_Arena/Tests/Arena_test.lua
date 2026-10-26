local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Arena (state machine, DR opt-in, frames, match, card).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local AR = ns.AR
local ST, DR, M = AR.State, AR.DR, AR.Match

Tests:Add("Arena", "defaults: DR opt-in off, stealth guess off, conflict entry for sArena", function(t)
  t:eq(Schema:Get("arena.drBlizzard"), false, "DR tracking off at first install")
  t:eq(Schema:Get("arena.assumeRegen"), false, "assume regen in stealth off")
  t:eq(Schema:Get("arena.drAnchor"), "trinket", "DR tray right of the trinket")
  t:eq(Schema:Get("core.coexist.arena"), "ask", "sArena conflict: you pick")
  for k, def in pairs(AR.schema) do t:eq(type(def.apply), "function", k .. " apply") end
end)

Tests:Add("Arena", "racial and trinket share a cooldown both ways; secret spell IDs are skipped", function(t)
  ST.Reset()
  t:eq(ST.RacialUsed("arena1", H and H.secret(59752) or nil, 100), nil, "secret spell ID never compared")
  local u = ST.RacialUsed("arena1", 59752, 100)
  t:eq(ST.Remaining(u.racial, 100), 180, "Will to Survive own cooldown")
  t:eq(ST.Remaining(u.trinket, 100), 90, "locks the trinket for the shared time")
  ST.TrinketUsed("arena1", 400, 120)
  t:eq(ST.Remaining(u.racial, 400), 90, "trinket locks the racial")
  t:eq(u.trinketUses, 1, "trinket use counted for the card")
  ST.SetRace("arena2", "Gnome")
  ST.TrinketUsed("arena2", 400, 120)
  t:eq(ST.Remaining(ST.Unit("arena2").racial, 400), 0, "racials without a shared cooldown stay free")
  t:eq(ST.SetLife("arena3", "unseen"), "unseen", "lifecycle"); t:eq(ST.SetLife("arena3", "destroyed"), "left", "left the arena")
  ST.Reset()
end)

Tests:Add("Arena", "DR: opt-in writes and restores the game's CVar; tray draws the game's data, stage only when readable", function(t)
  if not H then return end
  H.cvars.spellDiminishPVPEnemiesEnabled = "0"
  Schema:Set("module.Arena", true)
  Schema:Set("arena.drBlizzard", true)
  t:eq(H.cvars.spellDiminishPVPEnemiesEnabled, "1", "turned on through the ledger")
  Schema:Set("arena.drBlizzard", false)
  t:eq(H.cvars.spellDiminishPVPEnemiesEnabled, "0", "your value restored")
  ST.Reset()
  local e = DR.Update("arena1", { category = 1, startTime = 100, duration = 18, showCountdown = true, isImmune = false }, 100)
  t:eq(DR.StageText(e), "1/2", "first stage")
  DR.Update("arena1", { category = 1, startTime = 104, duration = 18, showCountdown = true, isImmune = false }, 104)
  t:eq(DR.StageText(e), "1/4", "second stage in the same window")
  DR.Update("arena1", { category = 1, startTime = 108, duration = 18, showCountdown = true, isImmune = true }, 108)
  t:eq(DR.StageText(e), "immune", "immune from the game's flag")
  local s2 = DR.Update("arena2", { category = H.secret(2), startTime = H.secret(1), duration = H.secret(18), showCountdown = true, isImmune = H.secret(false) }, 108)
  t:eq(DR.StageText(s2), "", "secret values: no stage label")
  local tray = DR.BuildTray(CreateFrame("Frame"))
  t:eq(DR.Paint(tray, ST.Unit("arena2").dr, { size = 20, spacing = 2, grow = "RIGHT", text = true, colorBorder = true, stageText = true }), 1, "secret entry still drawn")
  t:ok(tray.icons[1].immune.alphaFlag ~= nil, "immune passed to SetAlphaFromBoolean")
  t:eq(DR.Expire("arena1", 200), 0, "plain window expires")
  ST.Reset()
end)

Tests:Add("Arena", "frames: arena-only events, test mode, mirror, tray movable, presets, Blizzard frames via the ledger", function(t)
  if not H then return end
  Schema:Set("module.Arena", true)
  t:eq(AR.module.handlers.ARENA_OPPONENT_UPDATE, nil, "no arena events outside an arena")
  H.instance = "arena"
  t:cleanup(function() H.instance = nil; H.fire("ZONE_CHANGED_NEW_AREA"); AR.SetTest(false) end)
  H.fire("ZONE_CHANGED_NEW_AREA")
  t:ok(AR.module.handlers.ARENA_OPPONENT_UPDATE ~= nil, "armed in an arena")
  t:ok(PUI.Targeting.subs.arena ~= nil, "party targeting through Core/Targeting")
  H.arenaSpecs = { 267, 261, 256 }
  t:cleanup(function() H.arenaSpecs = nil end)
  H.fire("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
  t:eq(AR.Count(), 3, "prep room shows three specs")
  t:eq(ST.Unit("arena1").life, "prep", "prep state")
  t:eq(AR.Frames.frames[1].spec.texture, 200267, "spec icon in prep")
  H.fire("ARENA_OPPONENT_UPDATE", "arena2", "unseen")
  t:eq(AR.Frames.frames[2].status:GetText(), "Stealthed", "stealthed look")
  Schema:Set("arena.assumeRegen", true)
  t:eq(AR.Frames.frames[2].status:GetText(), "Stealthed - 100%*", "cosmetic guess, marked")
  Schema:Set("arena.assumeRegen", false)
  AR.SetTest(true)
  local f1 = AR.Frames.frames[1]
  t:eq(f1.testDR, 2, "test mode draws the DR tray with the same paint")
  t:eq(f1.tray.point[2], f1.trinket, "tray anchored right of the trinket")
  Schema:Set("arena.drAnchor", "frame")
  t:eq(f1.tray.point[2], f1, "tray moved live")
  Schema:Set("arena.drX", 12)
  t:eq(f1.tray.point[4], 16, "offset applies")
  Schema:Set("arena.drAnchor", "trinket"); Schema:Set("arena.drX", 0)
  Schema:Set("arena.mirrored", true)
  t:eq(f1.trinket.point[1], "RIGHT", "mirror flips the trinket side")
  Schema:Set("arena.mirrored", false)
  Schema:Set("arena.preset", "compact")
  t:eq(Schema:Get("arena.width"), 170, "preset writes its values once")
  Schema:Set("arena.width", 199)
  t:eq(AR.Frames.frames[1].width, 199, "each part still its own setting")
  Schema:Set("arena.preset", "phoenix")
  t:eq(PUI.FrameLedger:Owner("arena.blizzard"), "Arena", "Blizzard arena frames hidden through the frame ledger")
  Schema:Set("arena.hideBlizzard", false)
  t:eq(PUI.FrameLedger:Owner("arena.blizzard"), nil, "restored")
  Schema:Set("arena.hideBlizzard", true)
end)

Tests:Add("Arena", "trinket from the game's CC info; match header; after-match card", function(t)
  if not H then return end
  Schema:Set("module.Arena", true)
  H.instance = "arena"
  H.units.arena1 = true
  t:cleanup(function() H.instance = nil; H.units.arena1 = nil; H.arenaCC = {}; H.matchActive = nil; H.scores = nil; H.fire("ZONE_CHANGED_NEW_AREA") end)
  H.fire("ZONE_CHANGED_NEW_AREA")
  H.fire("ARENA_OPPONENT_UPDATE", "arena1", "seen")
  H.arenaCC.arena1 = { 336126, 500, 120 }
  H.fire("ARENA_CROWD_CONTROL_SPELL_UPDATE", "arena1", 336126)
  t:eq(ST.Unit("arena1").trinketUses, 1, "trinket use recorded")
  t:eq(AR.Frames.frames[1].trinket.tex.texture, 100000 + 336126, "trinket icon from the game")
  H.matchActive, H.matchDuration = true, 161
  H.fire("PVP_MATCH_STATE_CHANGED")
  t:ok(PUI.Ticker:IsRegistered("arena.match"), "1 Hz match timer while live")
  t:ok(AR.holder.header:GetText():find("Match 2:41", 1, true), "match time: " .. tostring(AR.holder.header:GetText()))
  t:eq(M.ShadowsightText(30), "Shadowsight 1:00", "Shadowsight countdown")
  t:eq(M.ShadowsightText(120), "Shadowsight up", "eyes up")
  H.scores = { { name = "Me", faction = 1, classToken = "MAGE", talentSpec = "Frost", ratingChange = 14, rating = 2104 },
    { name = "Pal", faction = 1, classToken = "PRIEST", talentSpec = "Discipline" },
    { name = "Kaelith", faction = 0, classToken = "WARLOCK", talentSpec = H.secret("Destruction") } }
  H.fire("PVP_MATCH_COMPLETE", 1, 161)
  t:eq(PUI.Ticker:IsRegistered("arena.match"), false, "timer stops")
  t:eq(M.lastLines[1], "Victory  2:41", "result and time")
  t:eq(M.lastLines[2], "Your team: Frost / Discipline", "your comp")
  t:eq(M.lastLines[3], "Enemy team: WARLOCK", "hidden spec falls back to class")
  t:ok(M.lastLines[4]:find("trinket used 1 x", 1, true), "trinket history")
  t:eq(M.card.rating:GetText(), "+14 rating", "rating change")
  H.fire("ZONE_CHANGED_NEW_AREA")
end)

Tests:Add("Arena", "live preview follows the settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Arena(card)
  t:eq(P.State(card).arenaFrames, Schema:Get("arena.testCount"), "sample frames drawn")
  Schema:Set("arena.drBlizzard", false)
  P.Arena(card)
  t:ok(P.State(card).arenaNote:find("DR tracking is off", 1, true), "explains why no DR shows")
end)
