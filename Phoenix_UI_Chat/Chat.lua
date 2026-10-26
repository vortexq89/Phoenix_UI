local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Chat (PUI_V2 5.12) - taint-safe mirror. The game's chat frames stay the
-- secure plane: their text container is set to alpha 0 and nothing of theirs
-- is replaced. A post-hook on each frame's AddMessage copies the formatted
-- line into a Phoenix ScrollingMessageFrame laid over it with the same font,
-- and a post-hook on SetScrollOffset keeps both scrolled in lockstep so the
-- game's hyperlink hit zones line up with the mirrored text. Lines that are
-- secret (M+, PvP, encounters) are passed through untouched; only plain lines
-- get timestamps, channel abbreviations, keyword alerts and copy history.
-- Never touched: AddMessage (replaced), ScrollToBottom, GetMessageInfo,
-- SetItemRef, ItemRefTooltip.SetHyperlink, window management, tabs.
-- Off by default.
local _, ns = ...
local Schema, Secret, Slash = PUI.Schema, PUI.Secret, PUI.Slash
local OWNER = "Chat"
local MAX_WINDOWS, HISTORY = 20, 500

local CH = { active = false, mirrors = {}, hooked = {}, history = {} }
ns.CH = CH
PUI.Chat = CH

local s = { timestamps = "off", abbreviate = true, keywords = "", whisperSound = true, fade = 0 }
CH.settings = s
CH.STAMPS = { off = false, ["HH:MM"] = "%H:%M", ["HH:MM:SS"] = "%H:%M:%S" }

local function plain(v) return type(v) == "string" and not Secret.IsSecret(v) end

-- Keywords: lower-case, comma separated, plain-text match.
local keywords = {}
function CH.SetKeywords(text)
  wipe(keywords)
  for w in (text or ""):gmatch("[^,]+") do
    w = w:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if w ~= "" then keywords[#keywords + 1] = w end
  end
end
function CH.MatchesKeyword(msg)
  if not plain(msg) then return false end
  local lower = msg:lower()
  for i = 1, #keywords do if lower:find(keywords[i], 1, true) then return true end end
  return false
end

-- Plain-line decoration; secret lines are returned unchanged.
function CH.Decorate(msg)
  if not plain(msg) then return msg end
  if s.abbreviate then msg = msg:gsub("^|Hchannel:([^|]+)|h%[(%d+)%. [^%]]+%]|h", "|Hchannel:%1|h[%2]|h") end
  local fmt = CH.STAMPS[s.timestamps]
  if fmt then msg = "|cff8a8a8a" .. date(fmt) .. "|r " .. msg end
  return msg
end

local function remember(msg)
  if not plain(msg) then return end
  local h = CH.history
  h[#h + 1] = msg
  if #h > HISTORY then table.remove(h, 1) end
end

local function mirrorFor(chat)
  local m = CH.mirrors[chat]
  if m then return m end
  m = PUI:CreateFrame("ScrollingMessageFrame", nil, chat, nil, OWNER)
  m:SetAllPoints(chat)
  m:SetFrameLevel(chat:GetFrameLevel() + 1)
  m:EnableMouse(false)
  m:SetHyperlinksEnabled(false)
  m:SetMaxLines(chat:GetMaxLines())
  m:SetFading(false)
  CH.mirrors[chat] = m
  return m
end

function CH.Style(chat)
  local m = mirrorFor(chat)
  local font, size, flags = chat:GetFont()
  if font then m:SetFont(font, size, flags) end
  m:SetJustifyH(chat:GetJustifyH())
  m:SetSpacing(chat:GetSpacing())
  m:SetFading(s.fade > 0)
  if s.fade > 0 then m:SetTimeVisible(s.fade) end
end

function CH.OnAddMessage(chat, msg, r, g, b, ...)
  if not CH.active then return end
  local m = CH.mirrors[chat]
  if not m then return end
  m:AddMessage(CH.Decorate(msg), r, g, b, ...)
  m:SetScrollOffset(chat:GetScrollOffset())
  remember(msg)
  if #keywords > 0 and CH.MatchesKeyword(msg) then
    PlaySound(SOUNDKIT.TELL_MESSAGE)
    FlashClientIcon()
  end
end

function CH.OnScroll(chat)
  local m = CH.active and CH.mirrors[chat]
  if m then m:SetScrollOffset(chat:GetScrollOffset()) end
end

function CH.Frames()
  local list = {}
  for i = 1, MAX_WINDOWS do
    local chat = rawget(_G, "ChatFrame" .. i)
    if chat then list[#list + 1] = chat end
  end
  return list
end

local function attach(chat)
  if not CH.hooked[chat] then
    hooksecurefunc(chat, "AddMessage", CH.OnAddMessage)
    hooksecurefunc(chat, "SetScrollOffset", CH.OnScroll)
    CH.hooked[chat] = true
  end
  CH.Style(chat)
  CH.mirrors[chat]:Show()
  if chat.FontStringContainer then chat.FontStringContainer:SetAlpha(0) end
end

local function detach(chat)
  local m = CH.mirrors[chat]
  if m then m:Hide(); m:Clear() end
  if chat.FontStringContainer then chat.FontStringContainer:SetAlpha(1) end
end

-- Copy window: plain history in a scrollable edit box.
function CH.ShowCopy()
  local f = CH.copy
  if not f then
    f = PUI:CreateFrame("Frame", "PhoenixUI_ChatCopy", UIParent, nil, OWNER)
    f:SetSize(600, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    PUI.Theme:Backdrop(f, "surface.1")
    f:EnableMouse(true)
    local scroll = PUI:CreateFrame("ScrollFrame", nil, f, "ScrollFrameTemplate", OWNER)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local box = PUI:CreateFrame("EditBox", nil, scroll, nil, OWNER)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(PUI.Media:FontObject("body"))
    box:SetWidth(560)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(box)
    f.box = box
    tinsert(UISpecialFrames, "PhoenixUI_ChatCopy")
    CH.copy = f
  end
  f.box:SetText(table.concat(CH.history, "\n"))
  f:Show()
end

Slash:Register("copychat", function() if CH.active then CH.ShowCopy() end end, "copy recent chat lines")

local function onEnable(mod)
  CH.active = true
  for _, chat in ipairs(CH.Frames()) do attach(chat) end
  mod:RegisterEvent("CHAT_MSG_WHISPER", function() if s.whisperSound then PlaySound(SOUNDKIT.TELL_MESSAGE) end end)
  mod:RegisterEvent("CHAT_MSG_BN_WHISPER", function() if s.whisperSound then PlaySound(SOUNDKIT.TELL_MESSAGE) end end)
end

local function onDisable()
  CH.active = false
  for _, chat in ipairs(CH.Frames()) do detach(chat) end
end

local schema = {}
CH.schema = schema
local function key(name, def, after)
  def.owner = OWNER
  def.apply = function(value)
    s[name] = value
    if after then after(value) end
    if CH.active then for _, chat in ipairs(CH.Frames()) do CH.Style(chat) end end
  end
  schema["chat." .. name] = def
end
key("timestamps", { type = "select", default = "off", choices = { "off", "HH:MM", "HH:MM:SS" }, label = "Chat timestamps",
  tooltip = "Time in front of each new line (lines hidden by the game in restricted content are shown unchanged).", mode = "simple" })
key("abbreviate", { type = "toggle", default = true, label = "Short channel names",
  tooltip = "Shows [2] instead of [2. Trade - City].", mode = "advanced" })
key("keywords", { type = "text", default = "", label = "Keyword alerts",
  tooltip = "Comma-separated words; a new line containing one plays a sound and flashes the game icon.", mode = "simple" },
  CH.SetKeywords)
key("whisperSound", { type = "toggle", default = true, label = "Whisper sound", tooltip = "Plays a sound on incoming whispers.", mode = "advanced" })
key("fade", { type = "range", default = 0, min = 0, max = 120, step = 5, label = "Fade idle lines (seconds)",
  tooltip = "Mirrored lines fade after this many seconds; 0 keeps them.", mode = "advanced" })

CH.module = PUI:RegisterModule(OWNER, {
  label = "Chat", tooltip = "Taint-safe chat mirror with timestamps, short channels, keyword alerts and copy.", enabledByDefault = false,
  schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do def.apply(Schema:Get(k)) end
