local _, ns = ...
local L = ns.L
local W, Secret = ns.Widgets, ns.Secret

--[[ Chat: clickable URLs (copy popup) and a per-window "copy chat" button.
    Message filters see secret strings while chat is restricted: those pass through untouched. ]]
local M = ns:NewModule("Chat", {
    label = "CHAT", desc = "CHAT_DESC", category = "social", order = 10,
    defaults = { urls = true, copyButton = true },
})

local EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
}
local LINK = "|cff4da3ff|Haddon:Phoenix_UI:url:%s|h[%s]|h|r"
local PATTERNS = {
    "(%a[%w+.-]+://[^%s|]+)",            -- scheme://…
    "(www%.[%w_-]+%.[^%s|]+)",           -- www.example.com/…
    "([%w_.-]+%.%a%a+/[^%s|]*)",          -- example.com/path
}

local function linkify(url) return LINK:format(url, url) end

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
        urlPopup = W:Popup(L.CHAT_COPY_URL, 460, 96)
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
        copyPopup = W:Popup(L.CHAT_COPY, 620, 420)
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
    b = W:IconButton(chatFrame, "export", 20, L.CHAT_COPY, L.CHAT_COPY_DESC)
    b:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 2, 2)
    b:SetAlpha(0.35)
    b:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
    b:HookScript("OnLeave", function(self) self:SetAlpha(0.35) end)
    b.onClick = function() showCopy(chatFrame) end
    buttons[chatFrame] = b
    return b
end

local function onLink(_, link)
    if type(link) ~= "string" then return end
    local url = link:match("^addon:Phoenix_UI:url:(.+)$")
    if url and M:IsEnabled() then showURL(url) end
end

function M:OnEnable()
    for _, event in ipairs(EVENTS) do ChatFrameUtil.AddMessageEventFilter(event, filter) end
    EventRegistry:RegisterCallback("SetItemRef", onLink, self)
    self:Refresh()
end

function M:OnDisable()
    for _, event in ipairs(EVENTS) do ChatFrameUtil.RemoveMessageEventFilter(event, filter) end
    EventRegistry:UnregisterCallback("SetItemRef", self)
    for _, b in pairs(buttons) do b:Hide() end
end

function M:Refresh()
    ChatFrameUtil.ForEachChatFrame(function(chatFrame)
        copyButton(chatFrame):SetShown(self.db.copyButton)
    end)
end
