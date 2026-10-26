local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Pulse (timer bars, countdown bar, combat timer display).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local PL = ns.PL

Tests:Add("Pulse", "every key applies live; timer off and bars on by default", function(t)
  t:eq(Schema:Def("module.Pulse").default, true, "on by default")
  t:eq(Schema:Get("pulse.timer"), false, "combat timer display off at first install")
  t:eq(Schema:Get("pulse.timeline"), true, "boss bars on")
  for k, def in pairs(PL.schema) do t:eq(type(def.apply), "function", k .. " apply") end
  t:eq(PL.Bars.TimeText(75), "1:15", "minutes"); t:eq(PL.Bars.TimeText(4.26), "4.3", "tenths under 10")
  t:eq(PL.Bars.TimeText(12.2, "seconds"), "13", "whole seconds round up")
end)

Tests:Add("Pulse", "draws Raid Tools' countdown from the COUNTDOWN signal and releases it", function(t)
  if not H then return end
  Schema:Set("module.Pulse", true)
  PUI.RaidTools.StartState("pull", 10, "player")
  local f = PL.group and PL.group.live.countdown
  t:ok(f ~= nil, "countdown bar shown")
  t:eq(f and f.name:GetText(), "Pull", "labelled")
  t:ok(PUI.Ticker:IsRegistered("pulse.text.pulse"), "text pass runs only while bars show")
  Schema:Set("pulse.countdownBar", false)
  t:eq(PL.group.live.countdown, nil, "turning the bar off hides it live")
  Schema:Set("pulse.countdownBar", true)
  t:ok(PL.group.live.countdown ~= nil, "back on")
  PUI.RaidTools.StopState()
  t:eq(PL.group.live.countdown, nil, "released when the countdown ends")
  t:eq(PUI.Ticker:IsRegistered("pulse.text.pulse"), false, "no Ticker entry with no bars")
end)

Tests:Add("Pulse", "boss bars come from the encounter timeline; secret names and times go to widgets", function(t)
  if not H then return end
  Schema:Set("module.Pulse", true)
  H.timeline = { [7] = { id = 7, spellName = H.secret("Annihilation"), iconFileID = 99, duration = 20, isApproximate = false, severity = H.secret(2) } }
  H.fire("ENCOUNTER_TIMELINE_EVENT_ADDED", H.timeline[7])
  local f = PL.group.live.ev7
  t:ok(f ~= nil, "bar for the event")
  t:ok(f.status.timer ~= nil, "fill is engine-driven (SetTimerDuration)")
  H.timelineLeft = H.secret(12.5)
  PL.group:Text()
  t:eq(f.time:GetText(), "<secret-formatted>", "secret time left formatted by the engine")
  H.fire("ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT", 7)
  t:ok(PUI.Glow:IsGlowing(f), "highlight glows")
  H.fire("ENCOUNTER_TIMELINE_EVENT_REMOVED", 7)
  t:eq(PL.group.live.ev7, nil, "removed")
  H.addonLoaded.BigWigs = true
  t:cleanup(function() H.addonLoaded.BigWigs = nil; H.timeline = nil; H.timelineLeft = nil end)
  H.fire("ENCOUNTER_TIMELINE_EVENT_ADDED", H.timeline[7])
  t:eq(PL.group.live.ev7, nil, "with BigWigs loaded and no pick yet, Pulse stays quiet")
  Schema:Set("core.coexist.pulse.timeline", "phoenix")
  t:cleanup(function() Schema:Set("core.coexist.pulse.timeline", "ask") end)
  t:ok(PL.group.live.ev7 ~= nil, "picking Phoenix resyncs from the game's sorted list")
  PL.group:ReleaseAll()
end)

Tests:Add("Pulse", "combat timer display and history read the shared clock", function(t)
  if not H then return end
  Schema:Set("module.Pulse", true)
  Schema:Set("pulse.timer", true)
  t:cleanup(function() Schema:Set("pulse.timer", false) end)
  H.fire("ENCOUNTER_START", 3009, "Vexie", 16, 20)
  H.step(65)
  PL.PaintTimer()
  t:ok(PL.timerFrame and PL.timerFrame:IsShown(), "shown in a fight")
  t:ok(PL.timerFrame.text:GetText():find("Vexie  1:05", 1, true), "boss name and time: " .. tostring(PL.timerFrame.text:GetText()))
  H.fire("ENCOUNTER_END", 3009, "Vexie", 16, 20, 1)
  t:eq(PL.history[1].name, "Vexie", "fight kept in history")
  t:ok(PL.HistoryLines(1)[1]:find("1:05", 1, true), "history line")
  H.step(10)
  PL.PaintTimer()
  t:eq(PL.timerFrame:IsShown(), false, "hidden after the hold time")
  t:eq(PUI.Ticker:IsRegistered("pulse.timer"), false, "no timer Ticker out of combat")
  t:eq(PL.Test(), 4, "test bars"); PL.group:ReleaseAll()
end)

Tests:Add("Pulse", "live preview draws sample bars in the live style and stops its Ticker when hidden", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Pulse(card)
  t:eq(P.State(card).pulseBars, 5, "four boss bars and the pull bar")
  Schema:Set("pulse.timeline", false)
  t:cleanup(function() Schema:Set("pulse.timeline", true) end)
  P.Pulse(card)
  t:eq(P.State(card).pulseBars, 1, "boss bars off live")
  P.Update("Flow", card)
  t:eq(PUI.Ticker:IsRegistered("pulse.text.preview"), false, "leaving the page releases the preview bars")
end)
