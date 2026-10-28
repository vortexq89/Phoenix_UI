local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Chat (skin, display-time filter, history, whispers) and
-- the shared announcement router it hands lines to.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local CH, T = ns.CH, ns.Text

local function with(t, values)
  local keys = { "module.Chat" }
  for k in pairs(values) do keys[#keys + 1] = k end
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end end)
  Schema:Set("module.Chat", true)
  for k, v in pairs(values) do Schema:Set(k, v) end
end

Tests:Add("Chat", "off by default; every setting has apply; conflict entry", function(t)
  t:eq(Schema:Def("module.Chat").default, false, "module defaults off")
  for key, def in pairs(CH.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  t:ok(Schema:Def("core.coexist.chat") ~= nil, "Prat/Chattynator conflict notice entry")
  t:eq(Schema:Def("chat.whisperWindows").default, "off", "whisper windows start off")
  if not Schema:Get("module.Chat") then t:eq(next(CH.styled), nil, "nothing styled while off") end
end)

Tests:Add("Chat", "text helpers: links, emoji, keywords, channels, UTF-8, patterns", function(t)
  local linked = T.LinkURLs("see raider.io/x and https://a.b/c?d=1, ok", "4fb3ff")
  t:ok(linked:find("|Haddon:PhoenixUI:url:raider.io/x|h", 1, true) ~= nil, "bare domain with path linked")
  t:ok(linked:find("url:https://a.b/c?d=1|h", 1, true) ~= nil, "scheme link linked, trailing comma dropped")
  local inLink = "|Hitem:1|h[www.fake.com]|h"
  t:eq(T.LinkURLs(inLink, "fff"), inLink, "text inside an existing link untouched")
  t:ok(T.ReplaceEmoji("gg :star: :nope:", 14):find("RaidTargetingIcon_1:14|t", 1, true) ~= nil, "emoji replaced")
  t:ok(T.ReplaceEmoji("x :nope:", 14):find(":nope:", 1, true) ~= nil, "unknown code kept")
  t:same(T.CompleteEmoji(T.EmojiPrefix("hi :ta"), 6), { "tank" }, "autocomplete prefix")
  t:eq(T.InsertEmoji("hi :ta", "tank"), "hi :tank: ", "insert replaces the open code")
  local out, hit = T.Highlight("need a SUMMON pls", T.ParseKeywords(" summon , inv"), "ffd24a")
  t:ok(hit and out:find("|cffffd24aSUMMON|r", 1, true) ~= nil, "keyword highlighted, case kept")
  t:eq(T.ShortChannel("2. Trade - City", "short"), "2. T", "short channel")
  t:eq(T.ShortChannel("2. Trade - City", "number"), "2", "number only")
  t:eq(T.ShortChannel("5. MyGuildChan", "short"), "5. MGC", "custom channel initials")
  t:eq(T.Truncate("ab\195\169c", 3), "ab", "UTF-8 never cut mid-character")
  local pat = T.FormatToPattern("%s has joined (the) battle.")
  t:eq(("Bob-Realm has joined (the) battle."):match(pat), "Bob-Realm", "format string to escaped pattern")
  t:eq(T.BGSummary({ "a", "b" }, { "c" }), "Battleground: 2 joined, 1 left", "summary text")
  local list = { { t = 100, ch = "guild", author = "Ann", text = "hello" }, { t = 200, ch = "party", author = "Bob", text = "Hello key" },
    { t = 300, ch = "party", author = "Ann-X", text = "bye" } }
  t:eq(#T.Search(list, { q = "hello" }), 2, "text search")
  t:eq(#T.Search(list, { channel = "party", player = "ann" }), 1, "channel + player")
  t:eq(#T.Search(list, { from = 150 }), 2, "date from")
end)

Tests:Add("Chat", "filter: secret lines untouched, voice window skipped, decoration", function(t)
  if not H then return end
  with(t, { ["chat.timestamps"] = "off", ["chat.urls"] = true, ["chat.channelNames"] = "short", ["chat.keywords"] = "" })
  local secret = H.secret("raider.io/x")
  local r1, r2 = CH.Filter(ChatFrame1, "CHAT_MSG_SAY", secret, "Bob", nil, nil, nil, nil, nil, nil, nil, nil, 1)
  t:eq(r1, false, "secret: not hidden")
  t:eq(r2, nil, "secret: no replacement args (stock Blizzard line)")
  local _, a2 = CH.Filter(ChatFrame1, "CHAT_MSG_SAY", "hi", H.secret("Bob"), nil, nil, nil, nil, nil, nil, nil, nil, 2)
  t:eq(a2, nil, "secret author: untouched")
  local voice = CreateFrame("ScrollingMessageFrame", "ChatFrame3", UIParent)
  t:cleanup(function() rawset(_G, "ChatFrame3", nil) end)
  local _, v2 = CH.Filter(voice, "CHAT_MSG_SAY", "see raider.io/x", "Bob", nil, nil, nil, nil, nil, nil, nil, nil, 3)
  t:eq(v2, nil, "window 3 (voice transcription) never decorated")
  local _, msg, _, _, chan = CH.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", "wts raider.io/x", "Bob", "", "2. Trade - City",
    nil, nil, nil, 2, "Trade - City", nil, 4)
  t:ok(msg and msg:find("url:raider.io/x", 1, true) ~= nil, "URL linked")
  t:eq(chan, "2. T", "channel name shortened through the filter args")
  t:eq(CH.OnLink(nil, "addon:PhoenixUI:url:raider.io/x"), "url", "link click handled (copy dialog)")
end)

Tests:Add("Chat", "once-per-line work: keyword alert, history, spam across windows", function(t)
  if not H then return end
  with(t, { ["chat.keywords"] = "summon", ["chat.spamFilter"] = true, ["chat.history"] = true, ["chat.persistHistory"] = false })
  local before = CH.alerts or 0
  H.flashed = false
  CH.Filter(ChatFrame1, "CHAT_MSG_PARTY", "need a SUMMON", "Ann-Realm", nil, nil, nil, nil, nil, nil, nil, nil, 9001)
  CH.Filter(ChatFrame2, "CHAT_MSG_PARTY", "need a SUMMON", "Ann-Realm", nil, nil, nil, nil, nil, nil, nil, nil, 9001)
  t:eq((CH.alerts or 0) - before, 1, "one alert for one line shown in two windows")
  t:ok(H.flashed, "icon flashed")
  local found = CH.History.Query({ q = "summon", channel = "party", player = "ann", range = "all" })
  t:eq(#found, 1, "history recorded once, searchable by channel and player")
  t:eq(CH.History.ByLine(9001).author, "Ann-Realm", "line copy lookup")
  local hide = CH.Filter(ChatFrame1, "CHAT_MSG_PARTY", "need a SUMMON", "Ann-Realm", nil, nil, nil, nil, nil, nil, nil, nil, 9002)
  t:eq(hide, true, "repeat inside the window hidden")
  local trimmed = { { t = 1 }, { t = 2 }, { t = 3 }, { t = 4 } }
  t:eq(CH.History.Trim(trimmed, 2, 0, 10), 2, "trim by count")
  t:eq(trimmed[1].t, 3, "oldest dropped")
end)

Tests:Add("Chat", "battleground join/leave lines become one summary", function(t)
  if not H then return end
  with(t, { ["chat.bgSummary"] = true })
  H.pvp = "bg"
  t:cleanup(function() H.pvp = nil end)
  t:eq(CH.Filter(ChatFrame1, "CHAT_MSG_BG_SYSTEM_NEUTRAL", "Ann has joined the battle", "", nil, nil, nil, nil, nil, nil, nil, nil, 50), true, "join hidden")
  CH.Filter(ChatFrame2, "CHAT_MSG_BG_SYSTEM_NEUTRAL", "Ann has joined the battle", "", nil, nil, nil, nil, nil, nil, nil, nil, 50)
  CH.Filter(ChatFrame1, "CHAT_MSG_BG_SYSTEM_NEUTRAL", "Bob has left the battle", "", nil, nil, nil, nil, nil, nil, nil, nil, 51)
  t:ok(PUI.Ticker:IsRegistered("chat.bg"), "summary waits on a one-shot Ticker entry")
  t:eq(CH.FlushBG(), "Battleground: 1 joined, 1 left", "same line in two windows counted once")
  t:ok(not PUI.Ticker:IsRegistered("chat.bg"), "one-shot entry removed")
end)

Tests:Add("Chat", "skin: panel per window, never window 3; live settings; restore", function(t)
  if not H then return end
  with(t, { ["chat.style"] = "phoenix", ["chat.idleFade"] = 0 })
  local p = CH.panels[ChatFrame1]
  t:ok(p and p:IsShown(), "panel behind window 1")
  Schema:Set("chat.style", "blizzard")
  t:eq(p:IsShown(), false, "Blizzard look hides the panel live")
  Schema:Set("chat.idleFade", 30)
  t:ok(PUI.Ticker:IsRegistered("chat.fade"), "idle fade on the Ticker")
  Schema:Set("chat.idleFade", 0)
  t:ok(not PUI.Ticker:IsRegistered("chat.fade"), "no ticker when fade is off")
  Schema:Set("module.Chat", false)
  t:eq(next(CH.styled), nil, "everything restored when turned off")
end)

Tests:Add("Chat", "whisper windows: tabs, unread, lockdown-safe send", function(t)
  if not H then return end
  local W = ns.Whisper
  with(t, { ["chat.whisperWindows"] = "popup" })
  wipe(W.convos); wipe(W.order); W.current = nil
  CH.OnWhisper(nil, "CHAT_MSG_WHISPER", "you still need a tank?", "Vex-Realm")
  t:ok(W.frame and W.frame:IsShown(), "popup on a new whisper")
  t:eq(W.current, "vex-realm", "conversation selected")
  CH.OnWhisper(nil, "CHAT_MSG_WHISPER", "hi", "Zed-Realm")
  t:eq(W.convos["zed-realm"].unread, 1, "unread counted on the other tab")
  t:eq(W.order[1], "zed-realm", "newest conversation first")
  CH.OnWhisper(nil, "CHAT_MSG_WHISPER", H.secret("x"), "Vex-Realm")
  t:eq(#W.convos["vex-realm"].lines, 1, "secret whisper never stored")
  t:same(W.TabWidths(3, 90, 200, 40), { 66, 66, 66 }, "tabs shrink evenly on overflow")
  H.chatLocked = true
  local ok = W.Send("vex-realm", "yes")
  t:eq(ok, false, "send refused during chat lockdown")
  H.chatLocked = false
  local n = #H.chat
  t:eq(W.Send("vex-realm", "yes"), true, "send")
  t:same(H.chat[n + 1], { "yes", "WHISPER" }, "sent as a whisper")
  W.frame:Hide()
end)

Tests:Add("Chat", "announcement router: off by default, per content, self when locked", function(t)
  if not H then return end
  local A = PUI.Announce
  local saved = { Schema:Get("announce.enabled"), Schema:Get("announce.channel"), Schema:Get("announce.where") }
  t:cleanup(function() Schema:Set("announce.enabled", saved[1]); Schema:Set("announce.channel", saved[2]); Schema:Set("announce.where", saved[3]) end)
  t:eq(Schema:Def("announce.enabled").default, false, "off at first install")
  t:eq(Schema:Def("announce.channel").default, "self", "self channel by default")
  t:eq(A:Send("quest", "Quest done", "world"), "off", "nothing sent while off")
  Schema:Set("announce.enabled", true)
  t:eq(A:Send("quest", "Quest done", "world"), "off", "topic not ticked for this content")
  local where = Schema.Copy(Schema:Get("announce.where"))
  where.quest.world = true
  Schema:Set("announce.where", where)
  t:eq(A:Send("quest", "Quest done", "world"), "self", "local line by default")
  Schema:Set("announce.channel", "PARTY")
  local n = #H.chat
  t:eq(A:Send("quest", "Quest done 2", "world"), "sent", "sent to party")
  t:same(H.chat[n + 1], { "Quest done 2", "PARTY" }, "router used SendChatMessage")
  t:eq(A:Send("quest", "Quest done 2", "world"), "throttled", "repeat skipped")
  H.chatLocked = true
  t:eq(A:Send("quest", "Quest done 3", "world"), "self", "lockdown: shown to you only")
  H.chatLocked = false
  t:eq(A:Send("quest", H.secret("x"), "world"), "off", "secret text never announced")
end)

Tests:Add("Chat", "live preview draws sample lines with the real text helpers", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = Schema:Get("chat.channelNames")
  t:cleanup(function() Schema:Set("chat.channelNames", saved) end)
  Schema:Set("chat.channelNames", "number")
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.Chat(card)
  local h = P.State(card).hud.chat
  t:ok(h and h.lines[1]:GetText():find("[2] Thrall", 1, true) ~= nil, "channel name style shown")
  t:ok(h.lines[1]:GetText():find("url:raider.io/x", 1, true) ~= nil, "link sample")
end)

Tests:Add("Chat", "migration keeps old chat and bag choices", function(t)
  local sv = { profiles = { A = { ["chat.abbreviate"] = false, ["vault.mode"] = "compact", ["chat.fade"] = 10 } } }
  t:eq(PUI.DB.migrations["0008b_chat_vault_keys"](sv), true, "migration ran")
  t:same(sv.profiles.A, { ["chat.channelNames"] = "full", ["vault.view"] = "compact" }, "choices carried over")
end)
