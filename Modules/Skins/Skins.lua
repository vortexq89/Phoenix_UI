local _, ns = ...
local Skin, Style, W = ns.Skin, ns.Style, ns.Widgets

--[[ Skins: the Phoenix look (style-library background and border, accent title, flat tabs and close button)
    for Blizzard's windows and dialogs, one switch per window. Load-on-demand windows (talents, collections,
    professions, auction house …) are dressed when their Blizzard addon loads.

    Safety: art is hidden with alpha only (Skin:HideRegion records the original), our textures and frames are
    added beside it, and selected-tab colours follow a post-hook of PanelTemplates_SelectTab. Nothing is
    re-parented, re-anchored, resized or written onto a Blizzard frame, so secure buttons inside these windows
    stay untainted. The bank window belongs to Bags (one place for bank slots and its frame). ]]
local M = ns:NewModule("Skins", {
    label = "SKINS", desc = "SKINS_DESC", category = "interface", order = 5, reloadOnToggle = true,
    defaults = {
        gameMenu = true, microMenu = true, worldMap = true, popups = true, readyCheck = true,
        character = true, inspect = true, spellbook = true, groupFinder = true, collections = true, professions = true,
        auction = true, mail = true, merchant = true, gossip = true, loot = true, achievements = true, journal = true,
        calendar = true, communities = true, friends = true, settings = true, vault = true, keystone = true,
        trade = true, dressUp = true, transmog = true, pgf = true, alerts = false,
        backdrop = Style.Background({ alpha = 0.94 }), border = Style.Border({ shadow = "soft" }),
        titleStyle = "phoenix", closeStyle = "phoenix", tabs = true,
        moveWindows = false, movedWindows = {}, mailAlts = true, premadeSearches = {},
    },
})

-- Dedicated window skins register here: SETUPS run on enable and whenever a Blizzard addon loads (they must be
-- safe to call again), RESKINS run on every settings change (live on / off).
M.SETUPS, M.RESKINS = {}, {}
function M:RunSetups() for _, fn in ipairs(self.SETUPS) do ns.SafeCall(self[fn], self) end end
function M:RunReskins() for _, fn in ipairs(self.RESKINS) do ns.SafeCall(self[fn], self) end end

-- key -> frames (global names), the Blizzard addon that creates them (nil = always loaded), dialog = small
-- panel look (no title strip), feature = client gate (ns:Supports).
M.WINDOWS = {
    { key = "gameMenu", frames = { "GameMenuFrame" }, dialog = true },
    { key = "popups", frames = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }, dialog = true },
    { key = "readyCheck", frames = { "ReadyCheckListenerFrame" }, dialog = true },
    { key = "character", frames = { "CharacterFrame" } },
    { key = "inspect", frames = { "InspectFrame" }, addon = "Blizzard_InspectUI" },
    { key = "spellbook", frames = { "PlayerSpellsFrame" }, addon = "Blizzard_PlayerSpells" },
    { key = "groupFinder", frames = { "PVEFrame" }, addon = "Blizzard_GroupFinder" },
    { key = "groupFinder", frames = { "PVPUIFrame" }, addon = "Blizzard_PVPUI" },
    { key = "collections", frames = { "CollectionsJournal" }, addon = "Blizzard_Collections" },
    { key = "professions", frames = { "ProfessionsFrame" }, addon = "Blizzard_Professions" },
    { key = "auction", frames = { "AuctionHouseFrame" }, addon = "Blizzard_AuctionHouseUI" },
    { key = "mail", frames = { "MailFrame", "OpenMailFrame" } },
    { key = "merchant", frames = { "MerchantFrame" } },
    { key = "gossip", frames = { "GossipFrame", "QuestFrame" } },
    { key = "loot", frames = { "LootFrame", "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" } },
    { key = "achievements", frames = { "AchievementFrame" }, addon = "Blizzard_AchievementUI" },
    { key = "journal", frames = { "EncounterJournal" }, addon = "Blizzard_EncounterJournal" },
    { key = "calendar", frames = { "CalendarFrame" }, addon = "Blizzard_Calendar" },
    { key = "communities", frames = { "CommunitiesFrame" }, addon = "Blizzard_Communities" },
    { key = "friends", frames = { "FriendsFrame" } },
    { key = "settings", frames = { "SettingsPanel", "AddonList" } },
    { key = "vault", frames = { "WeeklyRewardsFrame" }, addon = "Blizzard_WeeklyRewards", feature = "vault" },
    { key = "keystone", frames = { "ChallengesKeystoneFrame" }, addon = "Blizzard_ChallengesUI", feature = "mythicplus" },
    { key = "trade", frames = { "TradeFrame" } },
    { key = "dressUp", frames = { "DressUpFrame" } },
    -- other addons' windows (skinned only when that addon is loaded)
    { key = "pgf", frames = { "PremadeGroupsFilterDialog" }, addon = "PremadeGroupsFilter", dialog = true },
}

local ART = { "Border", "NineSlice", "BG", "Bg", "Background", "TopTileStreaks", "PortraitContainer" }
local HEADER_ART = { "LeftBG", "RightBG", "CenterBG" }
local INSET_ART = { "Bg", "NineSlice" }
local CLOSE_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local TAB_ART = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight",
    "RightHighlight", "LeftDisabled", "MiddleDisabled", "RightDisabled" }

local extras = setmetatable({}, { __mode = "k" }) -- [blizzard frame] = { strip, glyph … } (our regions)
local skinnedTabs = setmetatable({}, { __mode = "k" })

local function titleOf(frame)
    local tc = frame.TitleContainer
    return (tc and tc.TitleText) or frame.TitleText or (frame.Header and frame.Header.Text)
end

-- Phoenix close button: Blizzard's art faded out, our glyph on a child frame of ours.
local function closeButton(button)
    if not button then return end
    if extras[button] then -- switched back on live
        for _, getter in ipairs(CLOSE_ART) do
            local tex = button[getter] and button[getter](button)
            if tex then Skin:HideRegion(tex) end
        end
        extras[button].holder:Show()
        return
    end
    for _, getter in ipairs(CLOSE_ART) do
        local tex = button[getter] and button[getter](button)
        if tex then Skin:HideRegion(tex) end
    end
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints()
    holder:SetFrameLevel(button:GetFrameLevel() + 1)
    local glyph = W.Icon(holder, "close", 12, "text.secondary")
    glyph:SetPoint("CENTER")
    extras[button] = { holder = holder, glyph = glyph }
    button:HookScript("OnEnter", function() ns.Icons:Tint(glyph, "accent.primary") end)
    button:HookScript("OnLeave", function() ns.Icons:Tint(glyph, "text.secondary") end)
end

local function tabsOf(frame)
    local out = {}
    if type(frame.Tabs) == "table" then for _, t in ipairs(frame.Tabs) do out[#out + 1] = t end end
    local name = frame:GetName()
    if name and #out == 0 then
        for i = 1, 12 do
            local t = _G[name .. "Tab" .. i]
            if not t then break end
            out[#out + 1] = t
        end
    end
    return out
end

local function paintTab(tab)
    local selected = tab.isSelected
    if selected == nil and tab.IsEnabled then selected = not tab:IsEnabled() end
    Skin:Panel(tab, selected and "raised" or "sunken", { border = selected and "accent.primary" or "border.subtle", inset = 2 })
    local fs = tab.Text or (tab.GetFontString and tab:GetFontString())
    if fs then Skin:Text(fs, "small", selected and "accent.text" or "text.secondary") end
end
M.PaintTab = paintTab

local function skinTabs(frame)
    for _, tab in ipairs(tabsOf(frame)) do
        if not skinnedTabs[tab] then
            skinnedTabs[tab] = true
            for _, key in ipairs(TAB_ART) do Skin:HideRegion(tab[key]) end
            Skin:Register(tab, paintTab)
        else
            paintTab(tab)
        end
    end
end

-- One window or dialog. dialog: a centred panel without a title strip.
local winOn, winSeen = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function window(frame, dialog)
    if not frame or winOn[frame] then return end
    if Skin:IsSkinned(frame) and not winSeen[frame] then return end -- dressed by another Phoenix module
    winOn[frame], winSeen[frame] = true, true
    local db = M.db
    for _, key in ipairs(ART) do
        if key ~= "PortraitContainer" or db.titleStyle ~= "blizzard" then Skin:HideRegion(frame[key]) end
    end
    local header = frame.Header
    if header then
        for _, key in ipairs(HEADER_ART) do Skin:HideRegion(header[key]) end
    end
    local inset = frame.Inset
    if inset then for _, key in ipairs(INSET_ART) do Skin:HideRegion(inset[key]) end end
    local e = extras[frame] or {}
    extras[frame] = e
    if not dialog and db.titleStyle == "phoenix" and not e.strip then
        e.strip = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        e.strip:SetTexture(ns.Media.textures.WHITE)
        e.strip:SetPoint("TOPLEFT", 1, -1)
        e.strip:SetPoint("TOPRIGHT", -1, -1)
        e.strip:SetHeight(22)
    end
    if e.strip then e.strip:Show() end
    if db.closeStyle == "phoenix" then closeButton(frame.CloseButton or frame.ClosePanelButton) end
    Skin:Register(frame, function(self)
        local now = M.db
        Skin:Backdrop(self, now.backdrop, "bg.base")
        Skin:BorderSpec(self, now.border, "border.strong")
        if e.strip then W.Color(e.strip, "bg.raised") end
        if inset then Skin:Panel(inset, "sunken", { border = "border.subtle" }) end
        local title = titleOf(self)
        if title and (dialog or now.titleStyle ~= "blizzard") then
            Skin:Text(title, "heading", now.titleStyle == "minimal" and "text.primary" or "accent.primary", dialog and 13 or 12)
        end
    end)
    if db.tabs and not dialog then skinTabs(frame) end
end
M.SkinWindow = window

-- Live switch off: Blizzard's own art and title font back, our pieces hidden (window() redoes it when on).
local function unwindow(frame)
    if not frame or not winOn[frame] then return end
    winOn[frame] = nil
    for _, key in ipairs(ART) do Skin:Restore(frame[key]) end
    local header = frame.Header
    if header then for _, key in ipairs(HEADER_ART) do Skin:Restore(header[key]) end end
    local inset = frame.Inset
    if inset then
        for _, key in ipairs(INSET_ART) do Skin:Restore(inset[key]) end
        Skin:Restore(inset)
    end
    local e = extras[frame]
    if e and e.strip then e.strip:Hide() end
    local close = frame.CloseButton or frame.ClosePanelButton
    if close and extras[close] then
        for _, getter in ipairs(CLOSE_ART) do
            local tex = close[getter] and close[getter](close)
            if tex then Skin:Restore(tex) end
        end
        extras[close].holder:Hide()
    end
    local title = titleOf(frame)
    if title then Skin:Restore(title) end
    for _, tab in ipairs(tabsOf(frame)) do
        if skinnedTabs[tab] then
            skinnedTabs[tab] = nil
            for _, key in ipairs(TAB_ART) do Skin:Restore(tab[key]) end
            local fs = tab.Text or (tab.GetFontString and tab:GetFontString())
            if fs then Skin:Restore(fs) end
            Skin:Restore(tab)
        end
    end
    Skin:Restore(frame)
end
M.UnskinWindow = unwindow
function M.IsWindowOn(frame) return winOn[frame] and true or false end

-- Windows whose switch applies live both ways (the rest restore Blizzard's look after /reload).
M.LIVE = { gameMenu = true, character = true, popups = true, readyCheck = true, groupFinder = true, spellbook = true,
    loot = true, auction = true, professions = true, friends = true, communities = true, journal = true,
    achievements = true, collections = true, mail = true, merchant = true, vault = true, calendar = true, dressUp = true }
function M:ApplyLive()
    for _, entry in ipairs(self.WINDOWS) do
        if self.LIVE[entry.key] then
            local on = self:IsEnabled() and self:Wanted(entry)
            for _, name in ipairs(entry.frames) do
                if on then window(_G[name], entry.dialog) else unwindow(_G[name]) end
            end
        end
    end
end

function M:Wanted(entry)
    if entry.feature and not ns:Supports(entry.feature) then return false end
    return self.db[entry.key] and true or false
end

local function apply(entry)
    if not M:Wanted(entry) then return end
    for _, name in ipairs(entry.frames) do window(_G[name], entry.dialog) end
end

---------------------------------------------------------------- alerts and toasts (S17)
--[[ Every toast the game shows (achievements, loot, money, garrison, new mounts …) goes through
    AlertFrame:AddAlertFrame(frame); a post-hook fades the frame's own background art and puts a Phoenix panel
    behind it on a child frame of ours. Icons, text and animations stay Blizzard's. ]]
M.ALERT_ART = { "Background", "BG", "Background2", "Background3", "Border", "BackgroundFrame", "ToastBackground" }
local alertPanels = setmetatable({}, { __mode = "k" })
function M.SkinAlert(frame)
    if not (frame and M:IsEnabled() and M.db.alerts) or alertPanels[frame] then return end
    for _, key in ipairs(M.ALERT_ART) do
        local r = frame[key]
        if type(r) == "table" and r.SetAlpha and r.GetObjectType and r:GetObjectType() == "Texture" then Skin:HideRegion(r) end
    end
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", 6, -6)
    panel:SetPoint("BOTTOMRIGHT", -6, 6)
    panel:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    alertPanels[frame] = panel
    Skin:Register(panel, function(self)
        Skin:Backdrop(self, M.db.backdrop, "bg.base")
        Skin:BorderSpec(self, M.db.border, "border.strong")
    end)
end

local tabHooked, alertHooked
function M:OnEnable()
    if self.db.alerts and not alertHooked and AlertFrame and AlertFrame.AddAlertFrame then
        alertHooked = true
        hooksecurefunc(AlertFrame, "AddAlertFrame", function(_, frame) M.SkinAlert(frame) end)
    end
    local byAddon = {}
    for _, entry in ipairs(self.WINDOWS) do
        if entry.addon and not C_AddOns.IsAddOnLoaded(entry.addon) then
            byAddon[entry.addon] = entry
        else
            apply(entry)
        end
    end
    local moveByAddon = {}
    for _, entry in ipairs(self.WINDOWS) do if entry.addon and not entry.dialog then moveByAddon[entry.addon] = entry end end
    ns.Events:On("ADDON_LOADED", self, function(_, _, name)
        local entry = byAddon[name]
        if entry then byAddon[name] = nil; apply(entry) end
        if name:find("^Blizzard_") then M:RunSetups() end
        local mv = moveByAddon[name]
        if mv then for _, f in ipairs(mv.frames) do M:HookMovable(f) end end
    end)
    if self.SetupGameMenu then self:SetupGameMenu() end -- GameMenu.lua
    if self.SkinMicroMenu then self:SkinMicroMenu() end -- MicroMenu.lua
    if self.SetupWorldMap then self:SetupWorldMap() end -- WorldMap.lua
    if self.SetupCharacter then self:SetupCharacter() end -- Character.lua
    if self.SetupCharacterLists then self:SetupCharacterLists() end -- CharacterLists.lua
    if self.SetupPopups then self:SetupPopups() end -- Popups.lua
    self:RunSetups()
    if self.SetupMoving then self:SetupMoving() end
    if self.RefreshMailAlts then self:RefreshMailAlts() end
    if self.db.tabs and not tabHooked and PanelTemplates_SelectTab then
        tabHooked = true
        hooksecurefunc("PanelTemplates_SelectTab", function(tab)
            if skinnedTabs[tab] then
                for t in pairs(skinnedTabs) do paintTab(t) end
            end
        end)
    end
end
