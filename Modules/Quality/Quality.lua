local _, ns = ...
local L = ns.L
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media

--[[ Quality of life: small, independent tweaks of Blizzard behaviour.
    S16 adds:
    * hide zone text and the boss kill banner: their own events are unregistered (as UIErrorsFrame's error
      event already is in combat) and registered back when the option goes off; nothing else is touched;
    * a raid markers bar: our own SecureActionButtons running /tm (left click) and /wm (right click), made out
      of combat, shown in a group through a state driver, placed with Phoenix Edit Mode;
    * a cursor ring (our frame following GetCursorPosition), a combat enter / leave banner and sound;
    * an "already known" tint on merchant items (tooltip data line ITEM_SPELL_KNOWN), icon vertex colour only.
    Camera distance and the safe CVars live on the page as CVar rows (account settings). ]]
local M = ns:NewModule("Quality", {
    label = "QUALITY", desc = "QUALITY_DESC", category = "utility", order = 10,
    defaults = {
        hideTalkingHead = false, filterErrors = false, achievementScreenshot = false,
        hideZoneText = false, hideBossBanner = false,
        markers = false, cursorRing = false, ringSize = 48, ringCombatOnly = false,
        combatAlert = false, combatSound = "", knownTint = true,
        -- flight timer (Flight.lua)
        flight = { enabled = true, mapTimes = true, land = true, width = 260, point = "TOP", x = 0, y = -170 },
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

---------------------------------------------------------------- raid markers bar
local MARKERS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local SIZE, GAP = 24, 3
local bar

function M.SetMarker(tex, i)
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    tex:SetTexture(MARKERS)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

local function markerTip(self, i)
    ns.Widgets.ShowTooltip(self, i <= 8 and _G["RAID_TARGET_" .. i] or L.QUALITY_MARKERS_CLEAR, L.QUALITY_MARKERS_TIP)
end

local function markerButton(parent, i)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type1", "macro")
    b:SetAttribute("type2", "macro")
    -- 9 = clear: /tm 0 clears the target's icon, /cwm 0 clears every world marker
    b:SetAttribute("macrotext1", i <= 8 and ("/tm " .. i) or "/tm 0")
    b:SetAttribute("macrotext2", i <= 8 and ("/wm " .. i) or "/cwm 0")
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 3, -3); b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    if i <= 8 then M.SetMarker(b.tex, i) else ns.Icons:Apply(b.tex, "close", SIZE - 8) end
    b:SetScript("OnEnter", function(self) markerTip(self, i) end)
    b:SetScript("OnLeave", function() ns.Widgets.HideTooltip() end)
    return b
end

local function buildBar()
    local f = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    f:SetSize(9 * (SIZE + GAP) - GAP + 8, SIZE + 8)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    for i = 1, 9 do
        local b = markerButton(f, i)
        b:SetPoint("LEFT", 4 + (i - 1) * (SIZE + GAP), 0)
    end
    Skin:Register(f, function(self) Skin:Panel(self, "base", { border = "border.subtle", shadow = 8 }) end)
    ns.EditMode:Register(f, { key = "QualityMarkers", name = ns.title .. " – " .. L.QUALITY_MARKERS,
        default = { point = "TOP", x = 0, y = -120 } })
    return f
end

function M:ApplyMarkers()
    local want = self:IsEnabled() and self.db.markers
    if not want and not bar then return end
    ns.Combat:Run("quality.markers", function()
        if want then
            bar = bar or buildBar()
            RegisterStateDriver(bar, "visibility", "[petbattle] hide; [group] show; hide")
        elseif bar then
            UnregisterStateDriver(bar, "visibility")
            bar:Hide()
        end
    end)
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
    self:Refresh()
end

function M:Refresh()
    self:ApplyBanners()
    self:ApplyMarkers()
    self:ApplyRing()
    if self.ApplyFlight then self:ApplyFlight() end
end

function M:OnDisable()
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    self:Refresh()
end
