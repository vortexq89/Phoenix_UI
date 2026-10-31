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
        hideZoneText = false, hideBossBanner = false, hideBossEmotes = false, hideWhere = "always",
        quietList = {}, -- instanceID -> instance name, for hideWhere = "listed"
        -- boss fights: mute these sound channels from pull to kill or wipe (inside the quiet scope)
        muteMusic = false, muteAmbience = false, muteSfx = false, muteErrorSpeech = false,
        cursorRing = false, ringSize = 48, ringCombatOnly = false,
        combatAlert = false, combatSound = "", knownTint = true,
        -- flight timer (Flight.lua)
        flight = { enabled = true, mapTimes = true, land = true, width = 260, point = "TOP", x = 0, y = -170 },
        -- loot feed (LootFeed.lua)
        feed = { enabled = false, items = true, money = true, currency = true, minQuality = 0, duration = 6, rows = 6,
            width = 240, grow = "up", point = "RIGHT", x = -320, y = -40 },
    },
    -- learned flight times per route and the learned flight speed (Flight.lua), shared by every character
    -- soundLedger: the sound CVars a boss fight turned off (restored at the end, or at the next login after a
    -- disconnect or crash mid-fight)
    globalDefaults = { flight = { times = {} }, soundLedger = {} },
})

-- Quiet scope (BigWigs BossBlock idea): the hide switches below (talking heads, zone text, boss banner, boss emotes)
-- apply everywhere, only in dungeons and raids, only in raids, or only in the instances you listed.
local function currentInstance()
    local inside = IsInInstance()
    if not inside then return nil end
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    if type(id) ~= "number" or id <= 0 then return nil end
    return id, name
end
M.CurrentInstance = currentInstance

function M.QuietHere(where)
    where = where or M.db.hideWhere
    if where == "listed" then
        local id = currentInstance()
        return id ~= nil and M.db.quietList[id] ~= nil
    end
    if where ~= "instances" and where ~= "raids" then return true end
    local inside, kind = IsInInstance()
    if not inside then return false end
    if where == "raids" then return kind == "raid" end
    return kind == "party" or kind == "raid" or kind == "scenario"
end

-- The instance list (Quality > Where to hide > Only listed instances): add the one you are in, remove any.
function M:QuietListAdd()
    local id, name = currentInstance()
    if not id then return nil end
    self.db.quietList[id] = (type(name) == "string" and name ~= "") and name or ("#" .. id)
    self:ApplyBanners()
    return self.db.quietList[id]
end

function M:QuietListRemove(id)
    if self.db.quietList[id] == nil then return false end
    self.db.quietList[id] = nil
    self:ApplyBanners()
    return true
end

function M.QuietListEntries()
    local out = {}
    for id, name in pairs(M.db.quietList) do out[#out + 1] = { id = id, name = name } end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function talkingHeadHook()
    if M:IsEnabled() and M.db.hideTalkingHead and M.QuietHere() then TalkingHeadFrame:CloseImmediately() end
end

---------------------------------------------------------------- banners
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local BOSS_EVENTS = { "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED" }
-- boss emotes and whispers in the middle of the screen (Blizzard_RaidWarning, RaidWarningUtil.MessageTypeEvents);
-- raid warnings from players and boss mods stay. The text still reaches chat.
local EMOTE_EVENTS = { "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" }
local muted = {} -- frame -> the events we unregistered (only those are registered back)

local function setEvents(frame, events, off)
    if type(frame) ~= "table" or not frame.RegisterEvent or (muted[frame] ~= nil) == off then return end
    if off then
        local list = {}
        for _, e in ipairs(events) do
            if not frame.IsEventRegistered or frame:IsEventRegistered(e) then frame:UnregisterEvent(e); list[#list + 1] = e end
        end
        muted[frame] = list
    else
        for _, e in ipairs(muted[frame]) do frame:RegisterEvent(e) end
        muted[frame] = nil
    end
end
M.MutedEvents = muted

function M:ApplyBanners()
    local on = self:IsEnabled() and M.QuietHere()
    setEvents(ZoneTextFrame, ZONE_EVENTS, on and self.db.hideZoneText or false)
    setEvents(BossBanner, BOSS_EVENTS, on and self.db.hideBossBanner or false)
    setEvents(rawget(_G, "RaidWarningFrame"), EMOTE_EVENTS, on and self.db.hideBossEmotes or false)
end

---------------------------------------------------------------- boss fight sound (BigWigs BossBlock idea)
-- Sound CVars are not combat-protected (Blizzard's own music toggle key binding flips them any time), so they are
-- set straight away at the pull. Only channels that were on are turned off, and each one is written to the ledger
-- first, so the end of the fight (or the next login, if the game closed mid-fight) puts back exactly those.
local MUTE_CVARS = { muteMusic = "Sound_EnableMusic", muteAmbience = "Sound_EnableAmbience",
    muteSfx = "Sound_EnableSFX", muteErrorSpeech = "Sound_EnableErrorSpeech" }
M.MUTE_CVARS = MUTE_CVARS

local function soundLedger()
    local g = M.global
    if type(g.soundLedger) ~= "table" then g.soundLedger = {} end
    return g.soundLedger
end

function M:MuteBossSound()
    if not M.QuietHere() then return 0 end
    local ledger, n = soundLedger(), 0
    for key, cvar in pairs(MUTE_CVARS) do
        if self.db[key] and not ledger[cvar] and C_CVar.GetCVar(cvar) == "1" then
            ledger[cvar] = true
            C_CVar.SetCVar(cvar, "0")
            n = n + 1
        end
    end
    return n
end

function M:RestoreBossSound()
    local ledger, n = soundLedger(), 0
    for cvar in pairs(ledger) do
        C_CVar.SetCVar(cvar, "1")
        ledger[cvar] = nil
        n = n + 1
    end
    return n
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
    -- boss fight sound: the ledger first puts back anything a fight left off (disconnect, crash, reload mid-pull)
    if not C_InstanceEncounter.IsEncounterInProgress() then self:RestoreBossSound() end
    ns.Events:On("ENCOUNTER_START", self, function() self:MuteBossSound() end)
    ns.Events:On("ENCOUNTER_END", self, function() self:RestoreBossSound() end)
    -- the quiet scope follows you in and out of instances
    ns.Events:On("PLAYER_ENTERING_WORLD", self, function() self:ApplyBanners() end)
    ns.Events:On("ZONE_CHANGED_NEW_AREA", self, function() self:ApplyBanners() end)
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
    self:RestoreBossSound()
    self:Refresh()
end
