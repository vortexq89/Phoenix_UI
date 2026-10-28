local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Chat (plan 5.10, mockup 06): Blizzard's chat frames stay the data plane.
-- Phoenix skins them from the outside (its own panel frame behind each window,
-- font, shadow) and decorates lines at display time through the message-event
-- filter registry; there is no AddMessage hook, no FCF_* hook and no
-- reparenting. Rules (G38):
--   * window 1 is placed by Edit Mode: Phoenix never sets its points; the
--     settings button and /pui chat editmode open Edit Mode instead;
--   * window 3 (voice transcription) is never skinned, filtered or faded;
--   * a line whose arguments are secret (chat lockdown in M+, PvP, encounters)
--     is passed back untouched, so it looks exactly like stock Blizzard.
-- Features: keyword alerts, URL copy, emoji (+ autocomplete in Whisper.lua),
-- spam filter, short channel names, timestamps with per-line copy, role icons,
-- a one-line battleground join/leave summary, searchable history (History.lua),
-- smart whisper windows and the channel bar (Whisper.lua). Announcements are
-- routed by PUI.Announce (QoL page). Off by default.
local _, ns = ...
local Schema, Secret, Slash, Ticker, Media, Theme = PUI.Schema, PUI.Secret, PUI.Slash, PUI.Ticker, PUI.Media, PUI.Theme
local T = ns.Text
local OWNER = "Chat"
local MAX_WINDOWS = 20

local CH = { active = false, panels = {}, styled = {}, seenLine = {}, spam = {}, bg = { joined = {}, left = {} }, lastActivity = 0 }
ns.CH = CH
PUI.Chat = CH
CH.Text = T

local s = {}
CH.settings = s
CH.STAMPS = { off = false, ["HH:MM"] = "%H:%M", ["HH:MM:SS"] = "%H:%M:%S", ["hh:MM am"] = "%I:%M %p" }
CH.STYLES = { phoenix = { bg = 0.72, edge = true }, glass = { bg = 0.35, edge = false }, blizzard = { bg = 0, edge = false } }

local function plain(v) return type(v) == "string" and not Secret.IsSecret(v) end
CH.Plain = plain
-- Hex colour settings fall back to a default when the text is not 6 hex digits.
local function hex(v, fallback) if type(v) == "string" and v:match("^%x%x%x%x%x%x$") then return v end return fallback end
CH.Hex = hex

-- Window 3 is the voice transcription window (G38): never touched.
function CH.IsVoice(chat)
  if not chat then return true end
  if chat == rawget(_G, "ChatFrame3") then return true end
  return chat.GetID and chat:GetID() == 3 or false
end

function CH.Frames()
  local list = {}
  for i = 1, MAX_WINDOWS do
    local chat = rawget(_G, "ChatFrame" .. i)
    if chat and not CH.IsVoice(chat) then list[#list + 1] = chat end
  end
  return list
end

------------------------------------------------------------------------------
-- Skin: a Phoenix panel behind each window; Blizzard's own background is
-- dimmed with SetAlpha only (restored on disable).
local function blizzBackground(chat)
  local name = chat.GetName and chat:GetName()
  return name and rawget(_G, name .. "Background")
end

function CH.FontPath()
  if s.font == "blizzard" then return nil end
  return Media:Path("font", s.font) or Media:Font(s.font)
end

function CH.Style(chat)
  if CH.IsVoice(chat) then return end
  local p = CH.panels[chat]
  if not p then
    p = PUI:CreateFrame("Frame", nil, chat, nil, OWNER)
    p:SetFrameLevel(math.max(0, chat:GetFrameLevel() - 1))
    p.fill = p:CreateTexture(nil, "BACKGROUND")
    p.fill:SetAllPoints()
    CH.panels[chat] = p
  end
  local style = CH.STYLES[s.style] or CH.STYLES.phoenix
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", chat, "TOPLEFT", -s.padding, s.padding)
  p:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", s.padding, -s.padding)
  local c = s.panelColor
  p.fill:SetColorTexture(c.r, c.g, c.b, style.bg * s.panelAlpha)
  if style.edge and s.border and not p.outlined then Theme:Outline(p, "accent", 0.35); p.outlined = true end
  if s.style == "blizzard" then p:Hide() else p:Show() end
  local bg = blizzBackground(chat)
  if bg and bg.SetAlpha then bg:SetAlpha(s.style == "blizzard" and 1 or 0) end
  local path = CH.FontPath()
  if path and chat.SetFont then chat:SetFont(path, s.fontSize, s.outline == "none" and "" or s.outline) end
  if chat.SetShadowOffset then
    if s.shadow then chat:SetShadowOffset(1, -1); chat:SetShadowColor(0, 0, 0, 0.9) else chat:SetShadowOffset(0, 0) end
  end
  CH.styled[chat] = true
end

function CH.Unstyle(chat)
  local p = CH.panels[chat]
  if p then p:Hide() end
  local bg = blizzBackground(chat)
  if bg and bg.SetAlpha then bg:SetAlpha(1) end
  if chat.SetAlpha then chat:SetAlpha(1) end
  CH.styled[chat] = nil
end

function CH.Restyle()
  if not CH.active then return end
  for _, chat in ipairs(CH.Frames()) do CH.Style(chat) end
  CH.ArmFade()
end

------------------------------------------------------------------------------
-- Idle fade on the shared Ticker; any new line, hover or edit-box focus wakes.
function CH.SetFaded(faded)
  if CH.faded == faded then return end
  CH.faded = faded
  for _, chat in ipairs(CH.Frames()) do
    if chat.SetAlpha then chat:SetAlpha(faded and s.fadeAlpha or 1) end
    local p = CH.panels[chat]
    if p and p.SetAlpha then p:SetAlpha(faded and s.fadeAlpha or 1) end
  end
end
function CH.Wake() CH.lastActivity = GetTime(); CH.SetFaded(false) end
function CH.FadeTick()
  local box = rawget(_G, "ChatFrame1EditBox")
  if box and box.HasFocus and box:HasFocus() then CH.lastActivity = GetTime() end
  for _, chat in ipairs(CH.Frames()) do if chat.IsMouseOver and chat:IsMouseOver() then CH.lastActivity = GetTime() end end
  CH.SetFaded(GetTime() - CH.lastActivity >= s.idleFade)
end
function CH.ArmFade()
  local want = CH.active and (s.idleFade or 0) > 0
  if want and not Ticker:IsRegistered("chat.fade") then
    CH.lastActivity = GetTime()
    Ticker:Register("chat.fade", 0.5, CH.FadeTick, OWNER)
  elseif not want then
    if Ticker:IsRegistered("chat.fade") then Ticker:Unregister("chat.fade") end
    CH.SetFaded(false)
  end
end

------------------------------------------------------------------------------
-- Display-time filter. Runs once per window per line: work that must happen
-- once per line (history, alerts, spam memory) is keyed on the line ID.
CH.EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
  "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_SYSTEM" }
CH.CHANNEL_OF = { CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell", CHAT_MSG_EMOTE = "emote", CHAT_MSG_WHISPER = "whisper",
  CHAT_MSG_WHISPER_INFORM = "whisper", CHAT_MSG_BN_WHISPER = "whisper", CHAT_MSG_BN_WHISPER_INFORM = "whisper",
  CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
  CHAT_MSG_RAID_WARNING = "raid", CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance",
  CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer", CHAT_MSG_CHANNEL = "channel", CHAT_MSG_COMMUNITIES_CHANNEL = "community",
  CHAT_MSG_SYSTEM = "system", CHAT_MSG_BG_SYSTEM_NEUTRAL = "system", CHAT_MSG_BG_SYSTEM_ALLIANCE = "system", CHAT_MSG_BG_SYSTEM_HORDE = "system" }
local SELF_EVENTS = { CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER_INFORM = true }

-- Battleground join/leave lines: patterns from the client's own strings when
-- present, English fallbacks otherwise.
function CH.BGPatterns()
  if CH.bgPatterns then return CH.bgPatterns end
  local p = { join = {}, leave = {} }
  for _, name in ipairs({ "ERR_BATTLEGROUND_PLAYER_JOINED", "ERR_BG_PLAYER_JOINED_SS", "BG_PLAYER_JOINED" }) do
    local pat = T.FormatToPattern(rawget(_G, name)); if pat then p.join[#p.join + 1] = pat end
  end
  for _, name in ipairs({ "ERR_BATTLEGROUND_PLAYER_LEFT", "ERR_BG_PLAYER_LEFT_S", "BG_PLAYER_LEFT" }) do
    local pat = T.FormatToPattern(rawget(_G, name)); if pat then p.leave[#p.leave + 1] = pat end
  end
  p.join[#p.join + 1] = "^(.+) has joined the battle%.?$"
  p.leave[#p.leave + 1] = "^(.+) has left the battle%.?$"
  CH.bgPatterns = p
  return p
end

function CH.BGLine(msg)
  local p = CH.BGPatterns()
  for _, pat in ipairs(p.join) do local who = msg:match(pat); if who then return "join", who end end
  for _, pat in ipairs(p.leave) do local who = msg:match(pat); if who then return "leave", who end end
  return nil
end

function CH.FlushBG()
  if Ticker:IsRegistered("chat.bg") then Ticker:Unregister("chat.bg") end
  local b = CH.bg
  local line = T.BGSummary(b.joined, b.left)
  if line and DEFAULT_CHAT_FRAME then
    CH.lastBG = { joined = b.joined, left = b.left }
    DEFAULT_CHAT_FRAME:AddMessage("|cffe8a33d|H" .. T.LINK_PREFIX .. "bg:1|h[" .. line .. "]|h|r")
  end
  CH.bg = { joined = {}, left = {}, keys = {} }
  return line
end
CH.bg.keys = {}

local function stamp(lineID)
  local fmt = CH.STAMPS[s.timestamps]
  if not fmt then return "" end
  local text, color = date(fmt), hex(s.stampColor, "8a8a8a")
  if s.lineCopy and lineID then return "|cff" .. color .. "|H" .. T.LINK_PREFIX .. "copy:" .. lineID .. "|h" .. text .. "|h|r " end
  return "|cff" .. color .. text .. "|r "
end

local function roleIcon(author)
  if not s.roleIcons or not plain(author) or not UnitGroupRolesAssigned then return "" end
  local name = author:match("^[^%-]+")
  local role = name and UnitGroupRolesAssigned(name)
  if role == "TANK" then return "|A:groupfinder-icon-role-large-tank:12:12|a "
  elseif role == "HEALER" then return "|A:groupfinder-icon-role-large-heal:12:12|a " end
  return ""
end

-- Once per line (not per window): spam memory, history and alerts.
function CH.FirstSeen(lineID, event, msg, author, channelName)
  if lineID and CH.seenLine[lineID] ~= nil then return false, CH.seenLine[lineID] end
  local hidden = false
  if s.spamFilter and author and not SELF_EVENTS[event] and CH.CHANNEL_OF[event] ~= "system" then
    hidden = T.IsRepeat(CH.spam, author, msg, GetTime(), s.spamWindow)
  end
  if not hidden and CH.History then CH.History.Add(event, msg, author, channelName, lineID) end
  local own = author and author:match("^[^%-]+") == UnitName("player")
  if not hidden and #CH.keywords > 0 and not SELF_EVENTS[event] and not (s.skipOwn and own) then
    local _, hit = T.Highlight(msg, CH.keywords, nil)
    if hit then
      CH.alerts = (CH.alerts or 0) + 1
      if s.keywordSound then PlaySound(SOUNDKIT.TELL_MESSAGE) end
      if s.keywordFlash then FlashClientIcon() end
    end
  end
  if lineID then
    CH.seenLine[lineID] = hidden
    CH.seenCount = (CH.seenCount or 0) + 1
    if CH.seenCount > 400 then CH.seenLine, CH.seenCount = {}, 0 end
  end
  if CH.OnLine then CH.OnLine(event, msg, author, hidden) end
  return true, hidden
end

-- Returns the filter result: true (hide), false + new args, or false alone
-- (untouched). Tests call it directly.
function CH.Filter(frame, event, msg, author, a3, a4, a5, a6, a7, a8, a9, a10, lineID, ...)
  if not CH.active or CH.IsVoice(frame) then return false end
  if not plain(msg) or Secret.IsSecret(author) or Secret.IsSecret(a4) or Secret.IsSecret(a9) or Secret.IsSecret(lineID) then return false end
  if s.bgSummary and (event == "CHAT_MSG_SYSTEM" or event:find("^CHAT_MSG_BG_SYSTEM")) and C_PvP.IsBattleground() then
    local kind, who = CH.BGLine(msg)
    if kind then
      local k = lineID or msg
      if not CH.bg.keys[k] then
        CH.bg.keys[k] = true
        local list = kind == "join" and CH.bg.joined or CH.bg.left
        list[#list + 1] = who
        if not Ticker:IsRegistered("chat.bg") then Ticker:Register("chat.bg", s.bgDelay, CH.FlushBG, OWNER) end
      end
      return true
    end
  end
  local channelName = event == "CHAT_MSG_CHANNEL" and plain(a9) and a9 or nil
  local _, hidden = CH.FirstSeen(lineID, event, msg, plain(author) and author ~= "" and author or nil, channelName)
  if hidden then return true end
  CH.Wake()
  local out = msg
  if s.urls then out = T.LinkURLs(out, hex(s.urlColor, "4fb3ff")) end
  if s.emoji then out = T.ReplaceEmoji(out, s.emojiSize) end
  if s.keywordHighlight then out = T.Highlight(out, CH.keywords, hex(s.keywordColor, "ffd24a")) end
  out = stamp(lineID) .. roleIcon(author) .. out
  local channelString = a4
  if event == "CHAT_MSG_CHANNEL" and plain(a4) then channelString = T.ShortChannel(a4, s.channelNames) end
  if out == msg and channelString == a4 then return false end
  return false, out, author, a3, channelString, a5, a6, a7, a8, a9, a10, lineID, ...
end

------------------------------------------------------------------------------
-- Hyperlinks: Phoenix links are addon links handled through EventRegistry.
function CH.OnLink(_, link)
  if not plain(link) then return end
  local rest = link:match("^addon:PhoenixUI:(.*)$")
  if not rest then return end
  local kind, arg = rest:match("^(%a+):(.*)$")
  if kind == "url" and s.urls then
    PUI.Dialogs:Copy("Copy link", arg, "Ctrl+C to copy, Esc to close")
  elseif kind == "copy" and CH.History then
    local e = CH.History.ByLine(tonumber(arg))
    if e then PUI.Dialogs:Copy("Copy line", (e.author and (e.author .. ": ") or "") .. e.text, "Ctrl+C to copy") end
  elseif kind == "bg" and CH.lastBG then
    PUI.Dialogs:Copy("Battleground", "Joined: " .. table.concat(CH.lastBG.joined, ", ") .. "\nLeft: " .. table.concat(CH.lastBG.left, ", "))
  end
  return kind
end

local function addFilter(event, fn)
  local util = rawget(_G, "ChatFrameUtil")
  if util and util.AddMessageEventFilter then util.AddMessageEventFilter(event, fn) return true end
  local legacy = rawget(_G, "ChatFrame_AddMessageEventFilter")
  if legacy then legacy(event, fn) return true end
  return false
end

function CH.Hook()
  if CH.hooked then return end
  CH.hooked = true
  for _, ev in ipairs(CH.EVENTS) do addFilter(ev, CH.Filter) end
  if EventRegistry and EventRegistry.RegisterCallback then EventRegistry:RegisterCallback("SetItemRef", CH.OnLink, CH) end
end

-- Window 1 placement belongs to Edit Mode.
function CH.OpenEditMode()
  local em = rawget(_G, "EditModeManagerFrame")
  if em and not InCombatLockdown() then ShowUIPanel(em) return true end
  return false
end

Slash:Register("chat", function(rest)
  rest = (rest or ""):lower()
  if rest == "history" or rest == "search" then if CH.History then CH.History.Show() end
  elseif rest == "editmode" then CH.OpenEditMode()
  else PUI.Options:Open("Chat") end
end, "chat: history | editmode")
Slash:Register("copychat", function() if CH.History then CH.History.CopyAll() end end, "copy recent chat lines")

-- Whispers: sound on incoming, then the smart whisper window (Whisper.lua).
-- Secret senders or text are left to Blizzard's chat only.
function CH.OnWhisper(_, event, msg, author, ...)
  local incoming = event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER"
  if incoming and s.whisperSound then PlaySound(SOUNDKIT.TELL_MESSAGE) end
  if not plain(msg) or not plain(author) then return end
  local bnID = select(11, ...)
  if ns.Whisper then ns.Whisper.Incoming(author, msg, not incoming, event:find("BN_") and bnID or nil) end
end

function CH.OnEnable(mod)
  CH.active = true
  CH.Hook()
  CH.Restyle()
  if ns.Whisper then ns.Whisper.Enable(mod) end
  for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM" }) do
    mod:RegisterEvent(ev, CH.OnWhisper)
  end
  mod:RegisterEvent("UPDATE_CHAT_WINDOWS", CH.Restyle)
end

function CH.OnDisable()
  CH.active = false
  for chat in pairs(CH.styled) do CH.Unstyle(chat) end
  CH.ArmFade()
  if Ticker:IsRegistered("chat.bg") then CH.FlushBG() end
  if ns.Whisper then ns.Whisper.Disable() end
end

------------------------------------------------------------------------------
local schema = {}
CH.schema = schema
CH.keywords = {}
local function key(name, def, after)
  def.owner = OWNER
  def.apply = function(value)
    s[name] = value
    if after then after(value) end
    CH.Restyle()
    if ns.Whisper and ns.Whisper.Refresh then ns.Whisper.Refresh() end
  end
  schema["chat." .. name] = def
end
CH.Key = key
local function fonts() local l = { "blizzard" }; for _, n in ipairs(Media:List("font")) do l[#l + 1] = n end; return l end

-- Simple
key("style", { type = "select", default = "phoenix", choices = { "phoenix", "glass", "blizzard" },
  choiceLabels = { phoenix = "Phoenix (solid panel)", glass = "Glass (see-through)", blizzard = "Blizzard (unchanged)" },
  label = "Chat look", tooltip = "Panel style behind every chat window except the voice transcription window.", mode = "simple" })
key("font", { type = "select", default = "blizzard", choices = fonts, label = "Chat font",
  tooltip = "Font for chat lines. Blizzard keeps the game's own chat font.", mode = "simple" })
key("fontSize", { type = "range", default = 14, min = 8, max = 24, step = 1, label = "Font size", tooltip = "Size of chat text.", mode = "simple" })
key("outline", { type = "select", default = "none", choices = { "none", "OUTLINE", "THICKOUTLINE" },
  choiceLabels = { none = "None", OUTLINE = "Thin", THICKOUTLINE = "Thick" }, label = "Text outline", tooltip = "Outline around chat text.", mode = "simple" })
key("timestamps", { type = "select", default = "off", choices = { "off", "HH:MM", "HH:MM:SS", "hh:MM am" },
  label = "Timestamps", tooltip = "Time in front of each line. Lines the game keeps secret in restricted content are shown unchanged.", mode = "simple" })
key("channelNames", { type = "select", default = "short", choices = { "full", "short", "number" },
  choiceLabels = { full = "[2. Trade - City]", short = "[2. T]", number = "[2]" }, label = "Channel names",
  tooltip = "How numbered channels are written in front of a line.", mode = "simple" })
key("keywords", { type = "text", default = "", label = "Keyword alerts",
  tooltip = "Comma-separated words. A line containing one is highlighted, plays a sound and flashes the game icon.", mode = "simple",
  searchTags = { "alert", "highlight", "keyword" } }, function(v) CH.keywords = T.ParseKeywords(v) end)
key("urls", { type = "toggle", default = true, label = "Clickable links",
  tooltip = "Web addresses in chat become links; click one to copy it.", mode = "simple", searchTags = { "url", "copy", "link" } })
key("emoji", { type = "toggle", default = true, label = "Emoji",
  tooltip = "Turns :name: codes such as :star: or :tank: into icons, with suggestions while you type.", mode = "simple" })
key("phoenixEmoji", { type = "toggle", default = true, label = "Phoenix emoji art",
  tooltip = "Adds Phoenix's own emoji: :smile: :grin: :laugh: :wink: :sad: :cry: :angry: :cool: :wow: :think: :sleep: :gg: :heart: :fire: :thumbsup: :dead:.",
  mode = "advanced" }, function(v) T.SetPhoenixEmoji(v) end)
key("idleFade", { type = "range", default = 0, min = 0, max = 120, step = 5, label = "Fade when idle (seconds)",
  tooltip = "Chat fades after this many quiet seconds and wakes on a new line, hover or typing. 0 never fades.", mode = "simple" })
key("whisperSound", { type = "toggle", default = true, label = "Whisper sound", tooltip = "Plays a sound on incoming whispers.", mode = "simple" })
key("bgSummary", { type = "toggle", default = false, label = "Battleground join/leave summary",
  tooltip = "Replaces the stream of 'has joined/left the battle' lines with one summary line; click it to see the names.", mode = "simple" })
key("spamFilter", { type = "toggle", default = false, label = "Hide repeated lines",
  tooltip = "Hides a line when the same player repeats the same text within a short time.", mode = "simple", searchTags = { "spam" } })
-- Advanced: panel
key("panelColor", { type = "color", default = { r = 0.04, g = 0.04, b = 0.06 }, label = "Panel colour", tooltip = "Colour of the panel behind chat.", mode = "advanced" })
key("panelAlpha", { type = "range", default = 1, min = 0, max = 1, step = 0.05, label = "Panel opacity", tooltip = "Opacity of the chat panel.", mode = "advanced" })
key("padding", { type = "range", default = 4, min = 0, max = 16, step = 1, label = "Panel padding", tooltip = "Space between the text and the panel edge.", mode = "advanced" })
key("border", { type = "toggle", default = true, label = "Panel border", tooltip = "Thin accent border around the panel.", mode = "advanced" })
key("shadow", { type = "toggle", default = true, label = "Text shadow", tooltip = "Soft shadow under chat text.", mode = "advanced" })
key("fadeAlpha", { type = "range", default = 0.15, min = 0, max = 1, step = 0.05, label = "Faded opacity", tooltip = "How visible chat stays while faded.", mode = "advanced" })
-- Advanced: lines
key("stampColor", { type = "text", default = "8a8a8a", label = "Timestamp colour (hex)", tooltip = "Six hex digits, e.g. 8a8a8a.", mode = "advanced" })
key("lineCopy", { type = "toggle", default = true, label = "Click a timestamp to copy the line",
  tooltip = "Timestamps become links that open the line in the copy box.", mode = "advanced" })
key("urlColor", { type = "text", default = "4fb3ff", label = "Link colour (hex)", tooltip = "Colour of clickable web links (six hex digits).", mode = "advanced" })
key("emojiSize", { type = "range", default = 14, min = 10, max = 28, step = 1, label = "Emoji size", tooltip = "Icon size for emoji in chat.", mode = "advanced" })
key("keywordHighlight", { type = "toggle", default = true, label = "Highlight keywords", tooltip = "Colours matched keywords inside the line.", mode = "advanced" })
key("keywordColor", { type = "text", default = "ffd24a", label = "Keyword colour (hex)", tooltip = "Colour for highlighted keywords (six hex digits).", mode = "advanced" })
key("keywordSound", { type = "toggle", default = true, label = "Keyword sound", tooltip = "Plays a sound when a keyword matches.", mode = "advanced" })
key("keywordFlash", { type = "toggle", default = true, label = "Flash the game icon", tooltip = "Flashes the taskbar icon when a keyword matches.", mode = "advanced" })
key("skipOwn", { type = "toggle", default = true, label = "Ignore my own lines", tooltip = "Your own messages never trigger keyword alerts.", mode = "advanced" })
key("roleIcons", { type = "toggle", default = false, label = "Role icons", tooltip = "Tank and healer icons in front of group members' lines.", mode = "advanced" })
key("spamWindow", { type = "range", default = 30, min = 5, max = 300, step = 5, label = "Repeat window (seconds)",
  tooltip = "A repeat inside this time is hidden when Hide repeated lines is on.", mode = "advanced" })
key("bgDelay", { type = "range", default = 3, min = 1, max = 15, step = 1, label = "Summary delay (seconds)",
  tooltip = "Join and leave lines are collected for this long before the summary is printed.", mode = "advanced" })
