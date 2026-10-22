local _, ns = ...
local L = ns.L
local W, Skin, Theme, Secret = ns.Widgets, ns.Skin, ns.Theme, ns.Secret
local M = ns:GetModule("MythicPlus")

--[[ Party keystones (roadmap S3). Keystone data travels over the LibKeystone protocol (BigWigs, DBM and
    other addons speak it): prefix "LibKS", "R" asks the party, "level,mapID,rating" answers. When an
    addon already embeds LibKeystone, Phoenix uses the library instead of answering a second time.
    Addon messages are restricted while chat is locked down (inside instances in 12.x): Phoenix never
    sends then (C_ChatInfo.InChatMessagingLockdown), keeps what it already knows and drops secret text. ]]
local PREFIX, REQUEST = "LibKS", "R"
local THROTTLE = 3
local K = { keys = {} }   -- keys[shortName] = { level, mapID, rating }
M.Keystones = K

local function short(name)
    if type(name) ~= "string" or Secret.IsSecret(name) then return nil end
    return Ambiguate(name, "short")
end

function K:Own()
    local level = tonumber(C_MythicPlus.GetOwnedKeystoneLevel()) or 0
    local mapID = tonumber(C_MythicPlus.GetOwnedKeystoneChallengeMapID()) or 0
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local rating = summary and summary.currentSeasonScore
    if Secret.IsSecret(rating) or type(rating) ~= "number" then rating = 0 end
    return level, mapID, rating
end

local function canSend()
    if not (IsInGroup() and not IsInRaid()) then return false end
    local locked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    return not (Secret.IsSecret(locked) or locked)
end

local function lib() return LibStub and LibStub("LibKeystone", true) end

local last = {}
local function send(text)
    if not canSend() then return false end
    local now = GetTime()
    if last[text] and now - last[text] < THROTTLE then return false end
    last[text] = now
    C_ChatInfo.SendAddonMessage(PREFIX, text, "PARTY")
    return true
end

local function store(name, level, mapID, rating)
    name = short(name)
    if not name then return end
    level, mapID, rating = tonumber(level), tonumber(mapID), tonumber(rating)
    if not (level and mapID) then return end
    K.keys[name] = { level = level, mapID = mapID, rating = rating or 0 }
    ns.Events:Fire("PUI_KEYSTONES_CHANGED")
end

function K:Share()
    if lib() then return end -- the library answers for us
    send(("%d,%d,%d"):format(self:Own()))
end

function K:Request()
    local L_ = lib()
    if L_ and L_.Request then
        if canSend() then L_.Request("PARTY") end
        return
    end
    send(REQUEST)
end

-- Party members only: names that left the group are forgotten.
function K:Prune()
    local present = {}
    for i = 1, 4 do
        local name = short(UnitName("party" .. i))
        if name then present[name] = true end
    end
    for name in pairs(self.keys) do if not present[name] then self.keys[name] = nil end end
end

-- Rows for the list: you first, then the party in roster order (unknown keys included).
function K:Rows()
    local rows = {}
    local level, mapID, rating = self:Own()
    rows[1] = { name = UnitName("player"), class = select(2, UnitClass("player")), level = level, mapID = mapID,
        rating = rating, own = true }
    for i = 1, 4 do
        local unit = "party" .. i
        local name = short(UnitName(unit))
        if name then
            local k = self.keys[name]
            rows[#rows + 1] = { name = name, class = select(2, UnitClass(unit)), level = k and k.level,
                mapID = k and k.mapID, rating = k and k.rating }
        end
    end
    return rows
end

local function onMessage(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX or channel ~= "PARTY" or Secret.IsSecret(text) or type(text) ~= "string" then return end
    if text == REQUEST then
        if not lib() then K:Share() end
        return
    end
    local level, mapID, rating = text:match("^(%-?%d+),(%-?%d+),(%d+)$")
    if level then store(sender, level, mapID, rating) end
end

local owner = {}
function M:EnableKeystones()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    local L_ = lib()
    if L_ and L_.Register then
        L_.Register(owner, function(level, mapID, rating, name, channel)
            if channel == "PARTY" then store(name, level, mapID, rating) end
        end)
    else
        ns.Events:On("CHAT_MSG_ADDON", owner, onMessage)
    end
    ns.Events:On("GROUP_ROSTER_UPDATE", owner, function()
        K:Prune()
        K:Share(); K:Request()
        ns.Events:Fire("PUI_KEYSTONES_CHANGED")
    end)
    ns.Events:On("BAG_UPDATE_DELAYED", owner, function()
        local level, mapID = K:Own()
        if level ~= K.lastLevel or mapID ~= K.lastMap then
            K.lastLevel, K.lastMap = level, mapID
            K:Share()
            ns.Events:Fire("PUI_KEYSTONES_CHANGED")
        end
    end)
end

function M:DisableKeystones()
    ns.Events:OffAll(owner)
end

---------------------------------------------------------------- options list
local ROW_H, MAX_ROWS = 22, 5

local function mapName(mapID)
    if not mapID or mapID <= 0 then return nil end
    return C_ChallengeMode.GetMapUIInfo(mapID)
end

-- K:Paint(list, rows): shared by the Mythic+ page and its preview (which passes sample rows).
function K:Paint(list, rows)
    for i = 1, MAX_ROWS do
        local r, data = list.rows[i], rows[i]
        r:SetShown(data ~= nil)
        if data then
            r.name:SetText(data.name or "")
            r.name:SetTextColor(ns.Util.ClassColor(data.class))
            local dungeon = data.dungeon or mapName(data.mapID)
            if data.level and data.level > 0 and dungeon then
                r.key:SetFormattedText("+%d  %s", data.level, dungeon)
                r.key:SetTextColor(Theme:Color("text.primary"))
            else
                r.key:SetText(data.level and L.MPLUS_KEYS_NONE or L.MPLUS_KEYS_UNKNOWN)
                r.key:SetTextColor(Theme:Color("text.muted"))
            end
            local rating = data.rating or 0
            r.rating:SetText(rating > 0 and BreakUpLargeNumbers(rating) or "")
            local color = rating > 0 and C_ChallengeMode.GetDungeonScoreRarityColor(rating)
            if color then r.rating:SetTextColor(color:GetRGB()) else r.rating:SetTextColor(Theme:Color("text.muted")) end
        end
    end
    list.hint:SetShown(#rows <= 1)
end

function K:NewList(parent)
    local list = CreateFrame("Frame", nil, parent)
    list.rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Frame", nil, list)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("RIGHT")
        r.name = W.Text(r, "body", "text.primary")
        r.name:SetPoint("LEFT")
        r.name:SetWidth(130)
        r.rating = W.Text(r, "number", "text.secondary", "RIGHT")
        r.rating:SetPoint("RIGHT")
        r.key = W.Text(r, "body", "text.primary")
        r.key:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.key:SetPoint("RIGHT", r.rating, "LEFT", -8, 0)
        list.rows[i] = r
    end
    list.hint = W.Text(list, "desc", "text.muted")
    list.hint:SetPoint("TOPLEFT", 0, -ROW_H - 4)
    list.hint:SetPoint("RIGHT")
    list.hint:SetWordWrap(true)
    list.hint:SetText(L.MPLUS_KEYS_SOLO)
    Skin:Register(list, function(self)
        for _, r in ipairs(self.rows) do
            Skin:Text(r.name, "body"); Skin:Text(r.key, "body"); Skin:Text(r.rating, "number")
        end
        Skin:Text(self.hint, "desc", "text.muted")
    end)
    list.height = MAX_ROWS * ROW_H
    return list
end

-- custom row builder for Options.lua
function K.BuildRow(row)
    local list = K:NewList(row)
    local function paint() if list:IsVisible() then K:Paint(list, K:Rows()) end end
    ns.Events:Listen("PUI_KEYSTONES_CHANGED", list, paint)
    list:SetScript("OnShow", function() K:Request(); K:Paint(list, K:Rows()) end)
    K:Paint(list, K:Rows())
    return list
end

---------------------------------------------------------------- party keys window (S16)
-- A small Phoenix window beside Blizzard's Mythic+ dungeon list (ChallengesFrame, Blizzard_ChallengesUI, load on
-- demand): our own frame anchored to it, shown from post-hooks; nothing is written onto Blizzard's frame.
local keysWindow, hookedChallenges
local loader = {} -- waits for Blizzard_ChallengesUI

local function buildKeysWindow()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(380, 5 * ROW_H + 44)
    f:SetFrameStrata("HIGH")
    f.title = W.Text(f, "heading", "text.secondary")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText(L.MPLUS_KEYS_LIST:upper())
    f.list = K:NewList(f)
    f.list:SetPoint("TOPLEFT", 12, -30)
    f.list:SetPoint("RIGHT", -12, 0)
    f.list:SetHeight(f.list.height)
    Skin:Register(f, function(self)
        Skin:Panel(self, "base", { border = "border.subtle", shadow = 10 })
        Skin:Text(self.title, "heading", "text.secondary")
    end)
    ns.Events:Listen("PUI_KEYSTONES_CHANGED", f, function() if f:IsShown() then K:Paint(f.list, K:Rows()) end end)
    f:Hide()
    return f
end

local function showKeysWindow()
    local challenges = rawget(_G, "ChallengesFrame") -- Blizzard_ChallengesUI (retail, load on demand)
    if not (M:IsEnabled() and M.db.partyKeys and M.db.keysWindow and challenges and challenges:IsVisible()) then
        if keysWindow then keysWindow:Hide() end
        return
    end
    keysWindow = keysWindow or buildKeysWindow()
    keysWindow:ClearAllPoints()
    keysWindow:SetPoint("TOPLEFT", challenges, "TOPRIGHT", 8, 0)
    keysWindow:Show()
    K:Request()
    K:Paint(keysWindow.list, K:Rows())
end

local function hookChallenges()
    local challenges = rawget(_G, "ChallengesFrame")
    if hookedChallenges or not challenges then return end
    hookedChallenges = true
    challenges:HookScript("OnShow", showKeysWindow)
    challenges:HookScript("OnHide", function() if keysWindow then keysWindow:Hide() end end)
end

function M:RefreshKeysWindow()
    if self.db.keysWindow then
        hookChallenges()
        if not hookedChallenges then
            ns.Events:On("ADDON_LOADED", loader, function()
                hookChallenges()
                if hookedChallenges then ns.Events:OffAll(loader) end
            end)
        end
    end
    showKeysWindow()
end

-- The preview of the window (same list painter, sample rows).
K.BuildKeysWindow = buildKeysWindow
