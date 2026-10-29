local _, ns = ...
local L = ns.L
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media

--[[ Quality of life: small, independent tweaks of Blizzard behaviour.
    S16 adds:
    * hide zone text and the boss kill banner: their own events are unregistered (as UIErrorsFrame's error
      event already is in combat) and registered back when the option goes off; nothing else is touched;
    * (the raid markers bar moved to Group Frames > Markers, Modules/GroupFrames/Markers.lua; schema 7 migrates it)
    * a cursor ring (our frame following GetCursorPosition), a combat enter / leave banner and sound;
    * an "already known" tint on merchant items (tooltip data line ITEM_SPELL_KNOWN), icon vertex colour only.
    Camera distance and the safe CVars live on the page as CVar rows (account settings). ]]
local M = ns:NewModule("Quality", {
    label = "QUALITY", desc = "QUALITY_DESC", category = "utility", order = 10,
    defaults = {
        hideTalkingHead = false, filterErrors = false, achievementScreenshot = false,
        hideZoneText = false, hideBossBanner = false,
        cursorRing = false, ringSize = 48, ringCombatOnly = false,
        combatAlert = false, combatSound = "", knownTint = true,
        -- flight timer (Flight.lua)
        flight = { enabled = true, mapTimes = true, land = true, width = 260, point = "TOP", x = 0, y = -170 },
        -- loot feed (LootFeed.lua)
        feed = { enabled = false, items = true, money = true, currency = true, minQuality = 0, duration = 6, rows = 6,
            width = 240, grow = "up", point = "RIGHT", x = -320, y = -40 },
    },
    -- learned flight times per route and the learned flight speed (Flight.lua), shared by every character
    globalDefaults = { flight = { times = {} } },
})

local function talkingHeadHook()
    if M:IsEnabled() and M.db.hideTalkingHead then TalkingHeadFrame:CloseImmediately() end
end

---------------------------------------------------------------- banners
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local BOSS_EVENTS = { "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED" }
local muted = {}

local function setEvents(frame, events, off)
    if type(frame) ~= "table" or not frame.RegisterEvent or muted[frame] == off then return end
    muted[frame] = off
    for _, e in ipairs(events) do
        if off then frame:UnregisterEvent(e) else frame:RegisterEvent(e) end
    end
end

function M:ApplyBanners()
    local on = self:IsEnabled()
    setEvents(ZoneTextFrame, ZONE_EVENTS, on and self.db.hideZoneText or false)
    setEvents(BossBanner, BOSS_EVENTS, on and self.db.hideBossBanner or false)
end

---------------------------------------------------------------- cursor ring
local ring
function M:ApplyRing()
    local db = self.db
    local want = self:IsEnabled() and db.cursorRing
    if not want then if ring then ring:Hide() end return end
    if not ring then
        ring = CreateFrame("Frame", nil, UIParent)
        ring:SetFrameStrata("TOOLTIP")
        ring:EnableMouse(false)
        ring.tex = ring:CreateTexture(nil, "OVERLAY")
        ring.tex:SetAllPoints()
        ring.tex:SetTexture(Media.textures.RING_CIRCLE)
        ring:SetScript("OnUpdate", function(self)
            if M.db.ringCombatOnly and not InCombatLockdown() then self.tex:Hide(); return end
            self.tex:Show()
            local x, y = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        end)
    end
    ring:SetSize(db.ringSize, db.ringSize)
    ring.tex:SetVertexColor(Theme:Color("accent.primary"))
    ring:Show()
end

---------------------------------------------------------------- combat banner
local banner
local function showBanner(entering)
    if not (M:IsEnabled() and M.db.combatAlert) then return end
    if not banner then
        banner = CreateFrame("Frame", nil, UIParent)
        banner:SetSize(420, 40)
        banner:SetPoint("TOP", 0, -190)
        banner:SetFrameStrata("HIGH")
        banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        banner.text:SetPoint("CENTER")
        banner:Hide()
    end
    Skin:Text(banner.text, "title", entering and "state.danger" or "state.success", 22, "OUTLINE")
    banner.text:SetText(entering and L.QUALITY_COMBAT_IN or L.QUALITY_COMBAT_OUT)
    ns.Anim:FadeIn(banner, 0.15)
    C_Timer.After(1.4, function() if banner:IsShown() then ns.Anim:FadeOut(banner, 0.4) end end)
    if M.db.combatSound ~= "" then Media:PlaySound(M.db.combatSound) end
end
M.ShowCombatBanner = showBanner

---------------------------------------------------------------- known items at merchants
local function isKnown(index)
    local data = C_TooltipInfo and C_TooltipInfo.GetMerchantItem and C_TooltipInfo.GetMerchantItem(index)
    for _, line in ipairs(data and data.lines or {}) do
        if line.leftText == ITEM_SPELL_KNOWN then return true end
    end
    return false
end

local function onMerchant()
    if not (M:IsEnabled() and M.db.knownTint and MerchantFrame and MerchantFrame.selectedTab == 1) then return end
    for i = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button and button:IsShown() then
            local index = ((MerchantFrame.page or 1) - 1) * (MERCHANT_ITEMS_PER_PAGE or 10) + i
            if isKnown(index) and button.icon then button.icon:SetVertexColor(0.35, 0.95, 0.4) end
        end
    end
end

---------------------------------------------------------------- lifecycle
local hooked
function M:OnEnable()
    if not hooked then
        hooksecurefunc(TalkingHeadFrame, "PlayCurrent", talkingHeadHook)
        if type(MerchantFrame_UpdateMerchantInfo) == "function" then
            hooksecurefunc("MerchantFrame_UpdateMerchantInfo", onMerchant)
        end
        hooked = true
    end
    -- Error spam (not ready / out of range ...) is muted only while in combat.
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function()
        if self.db.filterErrors then UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE") end
        showBanner(true)
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", self, function()
        UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
        showBanner(false)
    end)
    ns.Events:On("ACHIEVEMENT_EARNED", self, function()
        if self.db.achievementScreenshot then C_Timer.After(1, Screenshot) end
    end)
    self:SetupFlight() -- Flight.lua
    self:SetupLootFeed() -- LootFeed.lua
    self:Refresh()
end

function M:Refresh()
    self:ApplyBanners()
    self:ApplyRing()
    if self.ApplyFlight then self:ApplyFlight() end
    if self.ApplyLootFeed then self:ApplyLootFeed() end
end

function M:OnDisable()
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    self:Refresh()
end
