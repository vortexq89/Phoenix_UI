local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Smart whisper windows, the channel bar and emoji autocomplete (plan 5.10).
-- Whisper windows: one Phoenix window with a fixed-width tab per person
-- (tabs shrink evenly when they overflow); each tab keeps that conversation
-- and has its own reply box. Sending goes through C_ChatInfo.SendChatMessage
-- (BNSendWhisper for Battle.net friends) and is refused during chat lockdown,
-- with a note. Blizzard's chat still shows every whisper as usual.
-- Channel bar: plain buttons that open the chat edit box on a channel (no
-- edit-box hooks). Emoji autocomplete: a post-hook on the chat edit box's
-- OnTextChanged shows suggestions; click one (or press Tab) to insert it.
local _, ns = ...
local CH, T = ns.CH, ns.Text
local Theme, Media, Secret = PUI.Theme, PUI.Media, PUI.Secret
local OWNER = "Chat"
local s = CH.settings

local W = { convos = {}, order = {}, tabs = {}, current = nil }
ns.Whisper = W
CH.Whisper = W
W.MAX_LINES, W.MAX_TABS = 200, 12

-- Conversation model (pure; tested) ---------------------------------------
function W.Key(author) return (author or ""):lower() end

function W.Record(author, msg, outgoing, bnID, t)
  local k = W.Key(author)
  local c = W.convos[k]
  if not c then
    c = { name = author, lines = {}, unread = 0, bnID = bnID }
    W.convos[k] = c
    table.insert(W.order, 1, k)
    if #W.order > W.MAX_TABS then
      local drop = table.remove(W.order)
      W.convos[drop] = nil
    end
  else
    for i, v in ipairs(W.order) do if v == k then table.remove(W.order, i); break end end
    table.insert(W.order, 1, k)
  end
  if bnID then c.bnID = bnID end
  c.lines[#c.lines + 1] = { t = t or time(), out = outgoing, text = msg }
  if #c.lines > W.MAX_LINES then table.remove(c.lines, 1) end
  if not outgoing and W.current ~= k then c.unread = c.unread + 1 end
  return c
end

-- Tab widths: fixed width until they overflow, then shrink evenly.
function W.TabWidths(n, fixed, total, min)
  local w = fixed
  if n * fixed > total then w = math.max(min, math.floor(total / n)) end
  local out = {}
  for i = 1, n do out[i] = w end
  return out
end

function W.Send(k, text)
  local c = W.convos[k]
  if not c or type(text) ~= "string" or text == "" then return false, "nothing to send" end
  if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
    return false, "chat is restricted right now; reply from the normal chat box"
  end
  if c.bnID and BNSendWhisper then BNSendWhisper(c.bnID, text)
  else C_ChatInfo.SendChatMessage(text, "WHISPER", nil, c.name) end
  return true
end

-- Window ---------------------------------------------------------------------
local function build()
  if W.frame then return W.frame end
  local f = PUI:CreateFrame("Frame", "PhoenixUI_Whispers", UIParent, nil, OWNER)
  f:SetSize(s.whisperWidth, 240)
  f:SetPoint("CENTER", 260, 80)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  Theme:Backdrop(f, "surface.1")
  Theme:Outline(f, "accent", 0.5)
  local close = PUI:CreateFrame("Button", nil, f, "UIPanelCloseButton", OWNER)
  close:SetPoint("TOPRIGHT", 2, 2)
  f.lines = PUI:CreateFrame("ScrollingMessageFrame", nil, f, nil, OWNER)
  f.lines:SetPoint("TOPLEFT", 10, -34)
  f.lines:SetPoint("BOTTOMRIGHT", -10, 36)
  f.lines:SetFontObject(Media:FontObject("body"))
  f.lines:SetJustifyH("LEFT")
  f.lines:SetFading(false)
  f.lines:SetMaxLines(W.MAX_LINES)
  f.lines:EnableMouseWheel(true)
  f.lines:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
  f.input = PUI:CreateFrame("EditBox", nil, f, "InputBoxTemplate", OWNER)
  f.input:SetHeight(20)
  f.input:SetPoint("BOTTOMLEFT", 16, 10)
  f.input:SetPoint("BOTTOMRIGHT", -12, 10)
  f.input:SetAutoFocus(false)
  f.input:SetScript("OnEnterPressed", function(self)
    local ok, why = W.Send(W.current, self:GetText())
    if ok then self:SetText("") elseif why then f.note:SetText(why) end
  end)
  f.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.note = f:CreateFontString(nil, "OVERLAY")
  f.note:SetFontObject(Media:FontObject("small"))
  f.note:SetPoint("BOTTOMLEFT", f.input, "TOPLEFT", -4, 4)
  tinsert(UISpecialFrames, "PhoenixUI_Whispers")
  f:Hide()
  W.frame = f
  return f
end

local function tab(i)
  local b = W.tabs[i]
  if b then return b end
  b = PUI:CreateFrame("Button", nil, build(), nil, OWNER)
  b:SetHeight(20)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFontObject(Media:FontObject("small"))
  b.text:SetPoint("LEFT", 6, 0)
  b.text:SetPoint("RIGHT", -6, 0)
  b.text:SetWordWrap(false)
  b:SetScript("OnClick", function(self) W.Select(self.key) end)
  W.tabs[i] = b
  return b
end

function W.Render()
  local f = W.frame
  if not f then return end
  f:SetWidth(s.whisperWidth)
  local widths = W.TabWidths(#W.order, s.whisperTabWidth, s.whisperWidth - 40, 40)
  local x = 8
  for i, k in ipairs(W.order) do
    local c, b = W.convos[k], tab(i)
    b.key = k
    b:SetWidth(widths[i])
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -8)
    x = x + widths[i] + 2
    local r, g, bl = Theme:Color(k == W.current and "accent" or "surface.2")
    b.bg:SetColorTexture(r, g, bl, 0.9)
    b.text:SetText((c.name:match("^[^%-#]+") or c.name) .. (c.unread > 0 and (" (" .. c.unread .. ")") or ""))
    b:Show()
  end
  for i = #W.order + 1, #W.tabs do W.tabs[i]:Hide() end
  f.lines:Clear()
  local c = W.current and W.convos[W.current]
  if c then
    for _, l in ipairs(c.lines) do
      local who = l.out and "|cff9aa0aaTo|r " or ("|cffe0a0ff" .. (c.name:match("^[^%-#]+") or c.name) .. "|r: ")
      f.lines:AddMessage(date("%H:%M", l.t) .. " " .. who .. (s.emoji and T.ReplaceEmoji(l.text, s.emojiSize) or l.text))
    end
  end
end

function W.Select(k)
  W.current = k
  local c = W.convos[k]
  if c then c.unread = 0 end
  W.Render()
end

function W.Incoming(author, msg, outgoing, bnID)
  if s.whisperWindows == "off" or not CH.active then return end
  if Secret.IsSecret(author) or Secret.IsSecret(msg) then return end
  local c = W.Record(author, msg, outgoing, bnID)
  local f = build()
  if not W.current or (not f:IsShown() and not outgoing) then W.current = W.Key(author) end
  if W.current == W.Key(author) then c.unread = 0 end
  if not outgoing and s.whisperWindows == "popup" and not InCombatLockdown() then f:Show() end
  W.Render()
end

function W.Toggle()
  local f = build()
  if f:IsShown() then f:Hide() else f:Show(); W.Render() end
end

-- Channel bar ------------------------------------------------------------
W.BAR = { { "S", "/s " }, { "P", "/p " }, { "I", "/i " }, { "R", "/raid " }, { "G", "/g " }, { "O", "/o " }, { "W", "/w " }, { "1", "/1 " }, { "2", "/2 " } }
function W.Bar()
  if W.bar then return W.bar end
  local chat = rawget(_G, "ChatFrame1")
  if not chat then return nil end
  local bar = PUI:CreateFrame("Frame", nil, chat, nil, OWNER)
  bar:SetSize(#W.BAR * 22, 20)
  bar.buttons = {}
  for i, e in ipairs(W.BAR) do
    local b = PUI:CreateFrame("Button", nil, bar, nil, OWNER)
    b:SetSize(20, 18)
    b:SetPoint("LEFT", (i - 1) * 22, 0)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    local r, g, bl = Theme:Color("surface.2")
    b.bg:SetColorTexture(r, g, bl, 0.9)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFontObject(Media:FontObject("small"))
    b.text:SetPoint("CENTER")
    b.text:SetText(e[1])
    b:SetScript("OnClick", function() if ChatFrame_OpenChat then ChatFrame_OpenChat(e[2], chat) end end)
    bar.buttons[i] = b
  end
  W.bar = bar
  return bar
end

function W.PlaceBar()
  local want = CH.active and s.channelBar
  local bar = want and W.Bar() or W.bar
  if not bar then return end
  if not want then bar:Hide() return end
  bar:ClearAllPoints()
  local chat = rawget(_G, "ChatFrame1")
  if s.channelBarSide == "top" then bar:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, 26)
  else bar:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", 0, -30) end
  bar:Show()
end

-- Emoji autocomplete ---------------------------------------------------------
function W.Suggest(box)
  if not (CH.active and s.emoji and s.emojiComplete) then if W.pop then W.pop:Hide() end return end
  local text = box:GetText()
  if Secret.IsSecret(text) then return end
  local names = T.CompleteEmoji(T.EmojiPrefix(text), 6)
  local pop = W.pop
  if #names == 0 then if pop then pop:Hide() end W.pending = nil return end
  if not pop then
    pop = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
    pop:SetFrameStrata("TOOLTIP")
    Theme:Backdrop(pop, "surface.1")
    pop.items = {}
    W.pop = pop
  end
  pop:ClearAllPoints()
  pop:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 4)
  pop:SetSize(150, #names * 20 + 8)
  for i, name in ipairs(names) do
    local b = pop.items[i]
    if not b then
      b = PUI:CreateFrame("Button", nil, pop, nil, OWNER)
      b:SetSize(142, 20)
      b.text = b:CreateFontString(nil, "OVERLAY")
      b.text:SetFontObject(Media:FontObject("body"))
      b.text:SetPoint("LEFT", 4, 0)
      pop.items[i] = b
    end
    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
    b.text:SetText(T.EmojiMarkup(T.EMOJI_BY[name], 14) .. " :" .. name .. ":")
    b:SetScript("OnClick", function() box:SetText(T.InsertEmoji(box:GetText(), name)); pop:Hide() end)
    b:Show()
  end
  for i = #names + 1, #pop.items do pop.items[i]:Hide() end
  W.pending = { box = box, name = names[1] }
  pop:Show()
end

function W.OnTab(box)
  local p = W.pending
  if p and p.box == box and W.pop and W.pop:IsShown() then
    box:SetText(T.InsertEmoji(box:GetText(), p.name))
    W.pop:Hide()
    W.pending = nil
  end
end

function W.HookEditBoxes()
  if W.boxesHooked then return end
  W.boxesHooked = true
  for i = 1, 20 do
    local box = rawget(_G, "ChatFrame" .. i .. "EditBox")
    if box and box.HookScript and i ~= 3 then
      box:HookScript("OnTextChanged", W.Suggest)
      box:HookScript("OnTabPressed", W.OnTab)
      box:HookScript("OnEditFocusLost", function() if W.pop then W.pop:Hide() end end)
    end
  end
end

function W.Refresh()
  W.PlaceBar()
  if W.frame then W.Render() end
end
function W.Enable() W.HookEditBoxes(); W.Refresh() end
function W.Disable()
  if W.frame then W.frame:Hide() end
  if W.pop then W.pop:Hide() end
  if W.bar then W.bar:Hide() end
end

PUI.Slash:Register("whispers", function() if CH.active then W.Toggle() end end, "open the whisper window")

local key = CH.Key
key("whisperWindows", { type = "select", default = "off", choices = { "off", "tab", "popup" },
  choiceLabels = { off = "Off", tab = "Collect quietly (open with /pui whispers)", popup = "Pop up on a new whisper" },
  label = "Smart whisper windows", tooltip = "Keeps each whisper conversation in its own tab of a small window with a reply box. Never pops up in combat.",
  mode = "simple", searchTags = { "whisper", "tell", "window" } })
key("whisperWidth", { type = "range", default = 360, min = 260, max = 700, step = 10, label = "Whisper window width",
  tooltip = "Width of the whisper window.", mode = "advanced" })
key("whisperTabWidth", { type = "range", default = 90, min = 50, max = 160, step = 5, label = "Whisper tab width",
  tooltip = "Fixed width of each whisper tab; tabs shrink evenly only when they no longer fit.", mode = "advanced" })
key("emojiComplete", { type = "toggle", default = true, label = "Emoji suggestions while typing",
  tooltip = "Typing : and a few letters shows matching emoji; click one or press Tab to insert it.", mode = "advanced" })
key("channelBar", { type = "toggle", default = false, label = "Channel bar",
  tooltip = "A row of small buttons (Say, Party, Instance, Raid, Guild, Officer, Whisper, 1, 2) that open the chat box on that channel.", mode = "simple" })
key("channelBarSide", { type = "select", default = "top", choices = { "top", "bottom" }, choiceLabels = { top = "Above chat", bottom = "Below chat" },
  label = "Channel bar position", tooltip = "Where the channel bar sits next to chat window 1.", mode = "advanced" })
