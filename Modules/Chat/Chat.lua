local _, ns = ...
local L = ns.L
local W, Secret, Skin, Style, Media, Theme = ns.Widgets, ns.Secret, ns.Skin, ns.Style, ns.Media, ns.Theme

--[[ Chat: restyles Blizzard's chat windows and adds tools; it never replaces the chat frames.
    Chat.lua      URLs (copy popup), the per-window copy button, edit box history that persists across
                  sessions on the plain arrow keys, faster scrolling (Shift: top/bottom, Ctrl: page), tab colours.
    Window.lua    window backdrop and border (style library), line fading, kept lines, side buttons, the
                  jump-to-bottom button, hide in combat, tab fading, edit box position, style and font.
    Messages.lua  one message filter for URLs, short channel names, keyword highlight and
                  sound, item levels and icons in links, spam throttle; role icons through Blizzard's sender
                  name filter; whisper sound; the game's own chat CVars (timestamps, class colours, whispers).
    Bar.lua       the chat bar (channel buttons, roll, ready check, pull timer) and the raid icon picker.
    Midnight restricted chat: message filters only run on messages the game lets addons read (Blizzard's
    registry skips them otherwise), and every other path checks Secret.IsSecret before reading text; secret
    text is never stored, compared or changed. No chat global (format strings, ChatTypeInfo) is written. ]]
local M = ns:NewModule("Chat", {
    label = "CHAT", desc = "CHAT_DESC", category = "social", order = 10,
    defaults = {
        urls = true, copyButton = true, armoryLink = true, linkHover = true, arrowKeys = true, keepHistory = true, fastScroll = true,
        tabFlash = true, whisperTabs = true,
        urlColor = false,                                  -- false = the theme's info colour
        styleText = false,
        messages = Style.Text(14, { outline = "NONE", shadow = true }),  -- size stays the chat window's own
        tabs = Style.Text(11),
        -- window
        skinWindows = false,
        background = Style.Background({ alpha = 0.55 }),
        border = Style.Border(),
        fade = true, fadeAfter = 120, maxLines = 0,       -- 0 = the game's own (Blizzard keeps 128)
        hideInCombat = false, sideButtons = true, scrollButton = true,
        -- tabs
        fadeTabs = true, selectedTabColor = false, pillTabs = true,
        -- messages
        shortChannels = false, keywords = "", keywordOwnName = true, keywordColor = false, keywordSound = "",
        itemLevels = true, linkIcons = true, roleIcons = true, throttle = 0,
        -- edit box
        editBoxTop = false, skinEditBox = false, historyLines = 32,
        editBox = Style.Text(14, { outline = "NONE", shadow = true }),
        -- tools
        chatBar = false, chatBarSide = "TOP", raidIcons = true, whisperSound = "",
        emotes = false,                                    -- emote picker button on the chat bar (S17)
        timestampColor = false,                            -- false = the game's uncoloured timestamps (S17)
    },
    globalDefaults = { history = {} },
})
local function historyMax() return math.max(1, math.min(100, M.db.historyLines or 32)) end

local LINK = "|cff%s|Haddon:Phoenix_UI:url:%s|h[%s]|h|r"

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

M.ShowURL = showURL

---------------------------------------------------------------- armory link in unit menus
-- The official armory address for a player: worldofwarcraft.blizzard.com/<locale>/character/<region>/<realm>/<name>.
local REGION_LOCALE = { us = "en-us", eu = "en-gb", kr = "ko-kr", tw = "zh-tw", cn = "zh-cn" }
-- Realm slug as the armory writes it: lower case, apostrophes and hyphens dropped, spaces become "-".
-- Display names ("Area 52", "Twisting Nether") convert directly. A normalized name ("Area52", "TwistingNether",
-- what menus and GetNormalizedRealmName give) has lost its spaces: they come back before each capital that
-- follows a lower-case letter and between letters and digits. Hyphenated realms lose the hyphen in both forms,
-- which matches the armory ("Azjol-Nerub" -> "azjolnerub"), except where the split would add one (listed).
local SLUG_EXCEPTIONS = { azjolnerub = "azjolnerub", ["azjol-nerub"] = "azjolnerub" }
function M.RealmSlug(realm)
    realm = tostring(realm or "")
    if realm == "" then return nil end
    local s
    if realm:find(" ", 1, true) or realm:find("-", 1, true) then
        s = realm:gsub("['%-()]", ""):gsub("%s+", "-")
    else
        s = realm:gsub("(%l)(%u)", "%1-%2"):gsub("(%a)(%d)", "%1-%2"):gsub("(%d)(%a)", "%1-%2"):gsub("'", "")
    end
    s = s:lower()
    local raw = realm:lower():gsub("[%s']", "")
    return SLUG_EXCEPTIONS[raw] or s
end
function M.ArmoryURL(name, realm, region)
    if type(name) ~= "string" or name == "" then return nil end
    region = tostring(region or "us"):lower()
    local slug = M.RealmSlug(realm)
    if not slug then return nil end
    return ("https://worldofwarcraft.blizzard.com/%s/character/%s/%s/%s"):format(REGION_LOCALE[region] or "en-us",
        region, slug, name:lower())
end
local MENUS = { "MENU_UNIT_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_GUILD" }
local function addArmory(_, root, ctx)
    if not (M:IsEnabled() and M.db.armoryLink) or type(ctx) ~= "table" then return end
    local name, realm = ctx.name, ctx.server
    if Secret.IsSecret(name) or Secret.IsSecret(realm) or type(name) ~= "string" then return end
    -- own realm (or the menu gives the normalized form of it): the display name keeps the spaces
    local own = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" or realm == own then realm = GetRealmName() end
    local region = GetCurrentRegionName and GetCurrentRegionName()
    local url = M.ArmoryURL(name, realm, region)
    if not url then return end
    root:CreateDivider()
    root:CreateButton(L.CHAT_ARMORY_LINK, function() showURL(url) end)
end
M.AddArmory = addArmory

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
    while #history > historyMax() do table.remove(history, 1) end
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
    box:SetHistoryLines(historyMax())
end

---------------------------------------------------------------- tabs
-- Post-hooks of FCFTab_UpdateColors / FCF_StartAlertFlash: only colours change, Blizzard keeps the logic.
local function tabState(tab)
    if not (M:IsEnabled() and tab and tab.GetID) then return end
    local chatFrame = _G["ChatFrame" .. tab:GetID()]
    if not chatFrame then return end
    M:StyleTabState(tab, tab:GetFontString(), chatFrame.chatType, ChatFrameUtil.IsTabAlerting(tab))
    M:StyleSelectedTab(tab, chatFrame)
    if M.StylePill then M:StylePill(tab, chatFrame) end -- Pills.lua
end
M.TabState = tabState

local function onAlert(chatFrame)
    if chatFrame and chatFrame.GetName then tabState(_G[chatFrame:GetName() .. "Tab"]) end
end

---------------------------------------------------------------- scrolling
-- Runs after FloatingChatFrame_OnMouseScroll has moved one line. The scroll methods come from
-- ScrollingMessageFrameSecureMixin, which runs them untainted when addon code calls them.
local wheelHooked = {}
local function onWheel(chatFrame, delta)
    M:UpdateScrollButton(chatFrame)
    if not (M:IsEnabled() and M.db.fastScroll) then return end
    if IsShiftKeyDown() then
        if delta > 0 then chatFrame:ScrollToTop() else chatFrame:ScrollToBottom() end
    elseif IsControlKeyDown() then
        if delta > 0 then chatFrame:PageUp() else chatFrame:PageDown() end
    end
    M:UpdateScrollButton(chatFrame)
end

-- Hovering an item, spell, achievement or similar link shows its tooltip (ElvUI's hyperlink hover).
-- Only link kinds GameTooltip:SetHyperlink understands; player, url and addon links are left alone.
local HOVER = { item = true, spell = true, achievement = true, quest = true, currency = true, talent = true,
    enchant = true, instancelock = true, keystone = true, battlepet = true, mount = true, transmogappearance = true,
    toy = true, conduit = true, azessence = true, mawpower = true }
local function onLinkEnter(chatFrame, link)
    if not (M:IsEnabled() and M.db.linkHover) or type(link) ~= "string" then return end
    if not HOVER[link:match("^(%a+):") or ""] then return end
    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR")
    if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
end
local function onLinkLeave(chatFrame)
    if GameTooltip:GetOwner() == chatFrame then GameTooltip:Hide() end
end
M._onLinkEnter = onLinkEnter

local function onLink(_, link)
    if type(link) ~= "string" then return end
    local url = link:match("^addon:Phoenix_UI:url:(.+)$")
    if url and M:IsEnabled() then showURL(url) end
end

function M:OnEnable()
    self:EnableMessages()
    EventRegistry:RegisterCallback("SetItemRef", onLink, self)
    if not self.menuHooks and Menu and Menu.ModifyMenu then
        self.menuHooks = true -- hooks stay for the session; addArmory checks the setting each time
        for _, tag in ipairs(MENUS) do Menu.ModifyMenu(tag, addArmory) end
    end
    if not self.windowHooks then
        -- New and temporary (whisper) windows get the copy button, arrow keys and scrolling too.
        self.windowHooks = true
        local function onNewWindow() if M:IsEnabled() then M:Refresh() end end
        hooksecurefunc("FCF_OpenNewWindow", onNewWindow)
        hooksecurefunc("FCF_OpenTemporaryWindow", onNewWindow)
        hooksecurefunc("FCFTab_UpdateColors", tabState)
        hooksecurefunc("FCF_StartAlertFlash", onAlert)
        self:HookWindows()
        if self.HookPills then self:HookPills() end
    end
    self:Refresh()
end

function M:OnDisable()
    self:DisableMessages()
    self:ApplyTimestampColor(true)
    EventRegistry:UnregisterCallback("SetItemRef", self)
    for _, b in pairs(buttons) do b:Hide() end
    for box, saved in pairs(editBoxes) do box:SetAltArrowKeyMode(saved.altArrows) end
    self:RestoreWindows()
    if self.RefreshPills then self:RefreshPills() end -- IsEnabled is false here: pills and bars come off
    self:HideBar()
end

function M:Refresh()
    self:ApplyTimestampColor()
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
            chatFrame:HookScript("OnHyperlinkEnter", onLinkEnter)
            chatFrame:HookScript("OnHyperlinkLeave", onLinkLeave)
        end
        self:StyleWindow(chatFrame)
    end)
    self:RefreshMessages()
    if self.RefreshPills then self:RefreshPills() end
    self:RefreshBar()
end

function M:ClearHistory()
    self.global.history = {}
end
