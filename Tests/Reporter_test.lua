local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Sentinel error reporter (step 9c): other addons'
-- errors, sessions / sources / search, resolved states, alerts, privacy,
-- preview, in-game sharing with accept + checksums, the BugSack picker.
local Tests, Hook, Schema = PUI.Tests, PUI.SentinelHook, PUI.Schema
local H = rawget(_G, "HARNESS")
local CORE = "[string \"@Interface/AddOns/Phoenix_UI/Core/Fake.lua\"]:10: in function <Interface/AddOns/Phoenix_UI/Core/Fake.lua:8>"
local OTHER = "[string \"@Interface/AddOns/SomeAddon/x.lua\"]:3: in function <Interface/AddOns/SomeAddon/x.lua:1>"

local function scratch(t)
  local S = PUI.Sentinel
  local saved, toast, last, unseen = S.db, S.toastEnabled, S.Alerts.last, S.Alerts.unseen
  S.toastEnabled = false
  S.Alerts.last, S.Alerts.unseen = {}, 0
  t:cleanup(function() S.db, S.toastEnabled, S.Alerts.last, S.Alerts.unseen = saved, toast, last, unseen; S.Alerts:PaintBadge() end)
  S:InitDB({})
  return S
end

Tests:Add("Sentinel", "reporter defaults: popup + badge on; sound, chat, auto-open off; others captured locally; auto-upload on", function(t)
  t:eq(Schema:Get("sentinel.toast"), true, "popup on")
  t:eq(Schema:Get("sentinel.alertBadge"), true, "badge on")
  t:eq(Schema:Get("sentinel.alertSound"), false, "sound off")
  t:eq(Schema:Get("sentinel.alertChat"), false, "chat line off")
  t:eq(Schema:Get("sentinel.autoOpen"), false, "auto-open off")
  t:eq(Schema:Get("sentinel.captureOthers"), true, "other addons captured")
  t:eq(Schema:Get("sentinel.uploadOthers"), false, "others never uploaded by default")
  t:eq(Schema:Get("sentinel.optIn"), true, "auto-upload via Companion on")
  t:eq(Schema:Def("sentinel.safeMode").hidden, true, "no safe mode")
end)

Tests:Add("Sentinel", "other addons' errors: own list, never in Phoenix reports or uploads unless allowed", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/SomeAddon/x.lua:3: oops", OTHER, "a = 1")
  Hook.Simulate("Interface/AddOns/SomeAddon/x.lua:3: oops", OTHER, "a = 2")
  local n = 0
  for _, inc in pairs(S.db.others) do n = n + 1; t:eq(inc.addon, "SomeAddon", "attributed to the addon"); t:eq(inc.count, 2, "deduplicated") end
  t:eq(n, 1, "one entry")
  t:eq(next(S.db.incidents), nil, "not a Phoenix incident")
  t:eq(#S.Export:Payload().reports, 0, "not uploaded")
  Schema:Set("sentinel.uploadOthers", true)
  t:cleanup(function() Schema:Set("sentinel.uploadOthers", false) end)
  t:eq(#S.Export:Payload().reports, 1, "uploaded only when allowed")
  Schema:Set("sentinel.captureOthers", false)
  t:cleanup(function() Schema:Set("sentinel.captureOthers", true) end)
  Hook.Simulate("Interface/AddOns/Other2/y.lua:1: x", "[string \"@Interface/AddOns/Other2/y.lua\"]:1", nil)
  local m = 0; for _ in pairs(S.db.others) do m = m + 1 end
  t:eq(m, 1, "switch off: not captured")
end)

Tests:Add("Sentinel", "viewer list: sessions, sources, plain search, fingerprints, resolved states persist", function(t)
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom", CORE, nil)
  Hook.Simulate("Interface/AddOns/SomeAddon/x.lua:3: oops (%d)", OTHER, nil)
  t:eq(#S.Store:List({ session = "this" }), 2, "this session: both")
  t:eq(#S.Store:List({ source = "phoenix" }), 1, "Phoenix only")
  t:eq(#S.Store:List({ source = "others" }), 1, "other addons")
  t:eq(#S.Store:List({ query = "(%d)" }), 1, "plain-text search, not a pattern")
  t:eq(#S.Store:List({ session = "previous" }), 0, "previous session empty")
  local inc = S.Store:List({ source = "phoenix" })[1]
  t:eq(#S.Store.Fingerprint(inc), 6, "short fingerprint")
  S.Store:SetState(inc.hash, "fixed", "9.9.9")
  local st, label = S.Store:State(inc)
  t:eq(st, "fixed", "fixed state"); t:ok(label:find("9.9.9", 1, true) ~= nil, "fixed in a version")
  S.Store:SetState(inc.hash, "ignored")
  t:eq(#S.Store:List({}), 2, "ignored errors are still listed (never hidden)")
  t:eq(S.Alerts:Decide(inc, 1000, "ignored"), false, "ignored errors do not alert")
  local text = S.Reporter.Text(inc, 1, 2)
  t:ok(text:find("Stack:", 1, true) and text:find("Locals:", 1, true) and text:find("fingerprint", 1, true), "viewer body has stack, locals, fingerprint")
  S.Store:Wipe(true)
  t:eq(#S.Store:List({}), 0, "wiped"); t:ok(S.db.resolved[inc.hash] ~= nil, "resolved states kept")
end)

Tests:Add("Sentinel", "alerts: one per signature per throttle window; badge counts; BugSack picker", function(t)
  local S = scratch(t)
  local inc = { hash = "abc", kind = "error" }
  S.Alerts.opts.throttle = 60
  t:eq(S.Alerts:Decide(inc, 100, "new"), true, "first alert")
  S.Alerts.last.abc = 100
  t:eq(S.Alerts:Decide(inc, 130, "new"), false, "throttled")
  t:eq(S.Alerts:Decide(inc, 161, "new"), true, "again after the window")
  t:eq(S.Alerts:Decide({ hash = "h", kind = "heartbeat" }, 1, "new"), false, "heartbeats never alert")
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom", CORE, nil)
  t:eq(S.Alerts.unseen, 1, "badge counts the new error")
  t:ok(S.Alerts.badge and S.Alerts.badge:IsShown(), "badge shown")
  S.Alerts:Seen()
  t:eq(S.Alerts.badge:IsShown(), false, "opened: badge clears")
  t:eq(PUI.Coexist:Yields("sentinel.display"), false, "without BugSack Sentinel shows errors")
end)

Tests:Add("Sentinel", "privacy: whole-word name and GUID kinds; preview is the exact payload", function(t)
  local S = scratch(t)
  local P = S.Privacy
  t:eq(P.Redact("Vexie hit Vexiel", "Vexie"), "[player] hit Vexiel", "whole word only")
  t:eq(P.Redact("guid Player-1084-0A1B2C3D x", nil), "guid Player-GUID x", "GUID keeps its kind")
  t:eq(P.Redact("a.b(c) a.b(c)x", "a.b(c)"), "[player] a.b(c)x", "names with pattern characters")
  S.db.optIn = true
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: Player-1084-0A1B2C3D failed", CORE, nil)
  local preview = S.Upload:PreviewText()
  t:ok(preview:find("Player-GUID", 1, true) ~= nil, "preview shows the redacted text")
  t:eq(preview:find("0A1B2C3D", 1, true), nil, "raw GUID never leaves")
  t:ok(S.Upload:Status():find("queued for the Companion", 1, true) ~= nil, "status line")
end)

Tests:Add("Sentinel", "in-game share: nothing sent before accept; chunks with checksum; refused when set to never", function(t)
  if not H then return end
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: share me " .. string.rep("x", 600), CORE, string.rep("l", 400))
  local inc = S.Store:List({})[1]
  wipe(H.addonMsgs)
  local offer = S.Share:Offer(inc, "Lumi")
  t:ok(offer.chunks >= 2, "chunked")
  t:eq(#H.addonMsgs, 1, "only the offer is sent first")
  t:ok(H.addonMsgs[1][2]:find("^O|"), "offer message"); t:eq(H.addonMsgs[1][4], "Lumi", "whisper to the player you chose")
  -- Receiver side: accept prompt first.
  local accepted
  local confirm = PUI.Dialogs.Confirm
  PUI.Dialogs.Confirm = function(_, spec) accepted = spec end
  t:cleanup(function() PUI.Dialogs.Confirm = confirm end)
  t:eq(S.Share:OnMessage("PUISEN", H.addonMsgs[1][2], "WHISPER", "Vex"), "asked", "receiver is asked")
  local chunk1 = string.format("C|%s|1|%s", offer.id, "zzz")
  t:eq(S.Share:OnMessage("PUISEN", chunk1, "WHISPER", "Vex"), "ignored", "chunks before accept are dropped")
  accepted.onAccept()
  t:ok(H.addonMsgs[#H.addonMsgs][2]:find("^A|"), "accept goes back to the sender")
  -- Sender gets the accept, the Ticker sends the chunks.
  S.Share:OnMessage("PUISEN", "A|" .. offer.id, "WHISPER", "Lumi")
  for _ = 1, offer.chunks do S.Share:Pump() end
  local result, report
  for _, m in ipairs(H.addonMsgs) do
    if m[2]:find("^C|") then result, report = S.Share:OnMessage("PUISEN", m[2], "WHISPER", "Vex") end
  end
  t:eq(result, "received", "assembled and checksum verified")
  t:ok(report.message:find("share me", 1, true) ~= nil, "same report")
  t:eq(PUI.Ticker.entries["sentinel.share"] ~= nil and S.Share.out[offer.id].state ~= "done", false, "transfer finished")
  -- Tampered chunk fails the checksum.
  S.Share.inbox["Vex|9"] = { chunks = 1, sum = "00000000", parts = {}, got = 0, accepted = true }
  t:eq(S.Share:OnMessage("PUISEN", "C|9|1|abc", "WHISPER", "Vex"), "checksum failed", "checksum checked")
  Schema:Set("sentinel.shareAccept", "never")
  t:cleanup(function() Schema:Set("sentinel.shareAccept", "ask") end)
  t:eq(S.Share:OnMessage("PUISEN", "O|5|1|abcd|10", "WHISPER", "Stranger"), "refused", "never accept")
end)

Tests:Add("Sentinel", "reporter window, diagnostics page and profiler report build", function(t)
  if not H then return end
  local S = scratch(t)
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom", CORE, nil)
  S.Reporter:Open()
  t:ok(S.Reporter.bodyText:find("boom", 1, true) ~= nil, "error shown")
  S.Reporter.tab = "diag"; S.Reporter:Paint()
  t:ok(S.Reporter.bodyText:find("Error capture", 1, true) ~= nil, "diagnostics page")
  S.Reporter.tab = "profile"; S.Reporter:Paint()
  t:ok(S.Reporter.bodyText:find("Profiler", 1, true) ~= nil, "profiler page")
  S.Reporter.frame:Hide()
end)

Tests:Add("Sentinel", "live preview follows the alert settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Sentinel(card)
  t:eq(P.State(card).sentinelLines, 6, "preview lines")
end)

Tests:Add("Sentinel", "outbox at logout is the previewed payload; nothing when auto-upload is off", function(t)
  local S = scratch(t)
  S.db.optIn = true
  Hook.Simulate("Interface/AddOns/Phoenix_UI/Core/Fake.lua:10: boom", CORE, nil)
  S.Upload:MarkSaved()
  t:eq(#S.db.outbox.reports, #S.Export:Payload().reports, "outbox = payload")
  S.db.optIn = false
  S.Upload:MarkSaved()
  t:eq(S.db.outbox, nil, "off: nothing queued")
end)
