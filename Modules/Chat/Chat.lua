local _, ns = ...
local L = ns.L
local W, Secret, Skin, Style, Media, Theme = ns.Widgets, ns.Secret, ns.Skin, ns.Style, ns.Media, ns.Theme

--[[ Chat: clickable URLs (copy popup), a per-window "copy chat" button, edit box history on the
    plain arrow keys that persists across sessions, and faster scrolling (Shift: top/bottom,
    Ctrl: page). Message filters see secret strings while chat is restricted: those pass through
    untouched, and secret text is never stored. ]]
local M = ns:NewModule("Chat", {
    label = "CHAT", desc = "CHAT_DESC", category = "social", order = 10,
    defaults = {
        urls = true, copyButton = true, arrowKeys = true, keepHistory = true, fastScroll = true,
        tabFlash = true, whisperTabs = true,
        urlColor = false,                                  -- false = the theme's info colour
        styleText = false,
        messages = Style.Text(14, { outline = "NONE", shadow = true }),  -- size stays the chat window's own
        tabs = Style.Text(11),
    },
    globalDefaults = { history = {} },
})
local HISTORY_MAX = 32 -- ChatFrameEditBoxTemplate historyLines

local EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
}
local LINK = "|cff%s|Haddon:Phoenix_UI:url:%s|h[%s]|h|r"
local PATTERNS = {
    "(%a[%w+.-]+://[^%s|]+)",            -- scheme://…
    "(www%.[%w_-]+%.[^%s|]+)",           -- www.example.com/…
    "([%w_.-]+%.%a%a+/[^%s|]*)",          -- example.com/path
}

---------------------------------------------------------------- style (shared with the options preview)
function M:URLHex() return ns.Util.Hex(Skin:SpecColor(self.db.urlColor, "state.info")) end
function M:Linkify(url) return LINK:format(self:URLHex(), url, url) end

-- Message text: face, outline and shadow from the settings; the size stays the window's (Blizzard's menu).
function M:StyleMessages(frame)
    if not self.db.styleText then return end
    local spec = self.db.messages
    local _, size = frame:GetFont()
    local path = spec.font ~= "" and Media:Font(spec.font) or Theme:Font("body")
    frame:SetFont(path, size or 14, Skin.OUTLINES[spec.outline] or "")
    frame:SetShadowColor(0, 0, 0, spec.shadow and 0.9 or 0)
    frame:SetShadowOffset(spec.shadow and 1 or 0, spec.shadow and -1 or 0)
end

function M:StyleTab(fs)
    if self.db.styleText and fs then Skin:TextSpec(fs, self.db.tabs, "small") end
end

local WHISPER = { WHISPER = true, BN_WHISPER = true }

-- Tab label colour: whisper windows take their channel colour (the game's chat colour settings).
function M:WhisperColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info and info.r then return info.r, info.g, info.b end
    return Theme:Color("accent.secondary")
end

-- tab: a chat tab (or a preview stand-in with .glow and a FontString); alerting: new messages waiting.
function M:StyleTabState(tab, fs, chatType, alerting)
    if self.db.whisperTabs and WHISPER[chatType] and fs then fs:SetTextColor(self:WhisperColor(chatType)) end
    if self.db.tabFlash and alerting and tab.glow then tab.glow:SetVertexColor(Theme:Color("accent.primary")) end
end

local function linkify(url) return M:Linkify(url) end

local function filter(_, _, msg, ...)
    if Secret.IsSecret(msg) or type(msg) ~= "string" or not M.db.urls then return false end
    if msg:find("|H", 1, true) then return false end -- never touch messages that already carry links
    local out, n = msg, 0
    for _, p in ipairs(PATTERNS) do
        local c
        out, c = out:gsub(p, linkify)
        n = n + c
        if c > 0 then break end
    end
    if n == 0 then return false end
    return false, out, ...
end

---------------------------------------------------------------- copy popups
local urlPopup, copyPopup

local function showURL(url)
    if not urlPopup then
        urlPopup = W:Popup(L.CHAT_COPY_URL, 460, 96, "link")
        urlPopup.input = W:Input(urlPopup, 428)
        urlPopup.input:SetPoint("BOTTOM", 0, 16)
        urlPopup.input:HookScript("OnEscapePressed", function() urlPopup:Hide() end)
        urlPopup.input:HookScript("OnTextChanged", function(self, user)
            if user then self:SetText(urlPopup.url); self:HighlightText() end
        end)
    end
    urlPopup.url = url
    urlPopup:Show()
    urlPopup.input:SetValue(url)
    urlPopup.input:SetFocus()
    urlPopup.input:HighlightText()
end

local function clean(text)
    return (text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function showCopy(chatFrame)
    if not copyPopup then
        copyPopup = W:Popup(L.CHAT_COPY, 620, 420, "copy")
        copyPopup.area = W:TextArea(copyPopup, 588, 360)
        copyPopup.area:SetPoint("BOTTOM", 0, 16)
        copyPopup.area.edit:HookScript("OnEscapePressed", function() copyPopup:Hide() end)
    end
    local lines = {}
    for i = 1, chatFrame:GetNumMessages() do
        local text = chatFrame:GetMessageInfo(i)
        if text and not Secret.IsSecret(text) then lines[#lines + 1] = clean(text) end
    end
    copyPopup:Show()
    copyPopup.area:SetValue(table.concat(lines, "\n"))
    copyPopup.area.edit:SetFocus()
end

local buttons = {}
local function copyButton(chatFrame)
    local b = buttons[chatFrame]
    if b then return b end
    b = W:IconButton(chatFrame, "copy", 20, L.CHAT_COPY, L.CHAT_COPY_DESC)
    b:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 2, 2)
    b:SetAlpha(0.35)
    b:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
    b:HookScript("OnLeave", function(self) self:SetAlpha(0.35) end)
    b.onClick = function() showCopy(chatFrame) end
    buttons[chatFrame] = b
    return b
end

---------------------------------------------------------------- edit box history
local restoring = false

-- Post-hook of EditBox:AddHistoryLine, which ChatFrameEditBoxMixin calls for every line sent.
local function onHistoryLine(_, text)
    if restoring or not (M:IsEnabled() and M.db.keepHistory) then return end
    if Secret.IsSecret(text) or type(text) ~= "string" or text == "" then return end
    local history = M.global.history
    if history[#history] == text then return end
    history[#history + 1] = text
    while #history > HISTORY_MAX do table.remove(history, 1) end
end

local editBoxes = {}
local function setupEditBox(chatFrame)
    local box = chatFrame.editBox
    if not box then return end
    if not editBoxes[box] then
        editBoxes[box] = { altArrows = box:GetAltArrowKeyMode() }
        hooksecurefunc(box, "AddHistoryLine", onHistoryLine)
        if M.db.keepHistory then
            restoring = true
            for _, text in ipairs(M.global.history) do box:AddHistoryLine(text) end
            restoring = false
        end
    end
    box:SetAltArrowKeyMode(not M.db.arrowKeys and editBoxes[box].altArrows)
end

---------------------------------------------------------------- tabs
-- Post-hooks of FCFTab_UpdateColors / FCF_StartAlertFlash: only colours change, Blizzard keeps the logic.
local function tabState(tab)
    if not (M:IsEnabled() and tab and tab.GetID) then return end
    local chatFrame = _G["ChatFrame" .. tab:GetID()]
    if not chatFrame then return end
    M:StyleTabState(tab, tab:GetFontString(), chatFrame.chatType, ChatFrameUtil.IsTabAlerting(tab))
end

local function onAlert(chatFrame)
    if chatFrame and chatFrame.GetName then tabState(_G[chatFrame:GetName() .. "Tab"]) end
end

---------------------------------------------------------------- scrolling
-- Runs after FloatingChatFrame_OnMouseScroll has moved one line. The scroll methods come from
-- ScrollingMessageFrameSecureMixin, which runs them untainted when addon code calls them.
local wheelHooked = {}
local function onWheel(chatFrame, delta)
    if not (M:IsEnabled() and M.db.fastScroll) then return end
    if IsShiftKeyDown() then
        if delta > 0 then chatFrame:ScrollToTop() else chatFrame:ScrollToBottom() end
    elseif IsControlKeyDown() then
        if delta > 0 then chatFrame:PageUp() else chatFrame:PageDown() end
    end
end

local function onLink(_, link)
    if type(link) ~= "string" then return end
    local url = link:match("^addon:Phoenix_UI:url:(.+)$")
    if url and M:IsEnabled() then showURL(url) end
end

function M:OnEnable()
    for _, event in ipairs(EVENTS) do ChatFrameUtil.AddMessageEventFilter(event, filter) end
    EventRegistry:RegisterCallback("SetItemRef", onLink, self)
    if not self.windowHooks then
        -- New and temporary (whisper) windows get the copy button, arrow keys and scrolling too.
        self.windowHooks = true
        local function onNewWindow() if M:IsEnabled() then M:Refresh() end end
        hooksecurefunc("FCF_OpenNewWindow", onNewWindow)
        hooksecurefunc("FCF_OpenTemporaryWindow", onNewWindow)
        hooksecurefunc("FCFTab_UpdateColors", tabState)
        hooksecurefunc("FCF_StartAlertFlash", onAlert)
    end
    self:Refresh()
end

function M:OnDisable()
    for _, event in ipairs(EVENTS) do ChatFrameUtil.RemoveMessageEventFilter(event, filter) end
    EventRegistry:UnregisterCallback("SetItemRef", self)
    for _, b in pairs(buttons) do b:Hide() end
    for box, saved in pairs(editBoxes) do box:SetAltArrowKeyMode(saved.altArrows) end
end

function M:Refresh()
    ChatFrameUtil.ForEachChatFrame(function(chatFrame)
        copyButton(chatFrame):SetShown(self.db.copyButton)
        setupEditBox(chatFrame)
        self:StyleMessages(chatFrame)
        local tab = _G[chatFrame:GetName() .. "Tab"]
        self:StyleTab(tab and tab.Text)
        tabState(tab)
        if not wheelHooked[chatFrame] then
            wheelHooked[chatFrame] = true
            chatFrame:HookScript("OnMouseWheel", onWheel)
        end
    end)
end

function M:ClearHistory()
    self.global.history = {}
end
