-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns:GetModule("Automation")

--[[ Announcements (WindTools idea, t193): three switches, all off by default, each one line to your group.
      * new keystone: after a Mythic+ run, your new key (dungeon and level) once it is in your bags
      * instance reset: when you reset instances, the group hears that it worked
      * thanks: after a finished key, your own short message (empty = a default thank-you)
    Group chat only (party, or instance chat in a looking-for-group party); never in combat, never in a raid. ]]

local function channel()
    if IsInRaid() or not IsInGroup() then return nil end
    if IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE or 2) then return "INSTANCE_CHAT" end
    return "PARTY"
end

function M.AnnounceSend(text)
    local ch = channel()
    if not ch or InCombatLockdown() or type(text) ~= "string" or text == "" then return false end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or _G.SendChatMessage
    if not send then return false end
    send(text, ch)
    return true
end

-- "Dungeon +N" for the keystone in your bags, or nil.
function M.KeystoneText()
    local mp = C_MythicPlus
    local map = mp and mp.GetOwnedKeystoneChallengeMapID and mp.GetOwnedKeystoneChallengeMapID()
    local level = mp and mp.GetOwnedKeystoneLevel and mp.GetOwnedKeystoneLevel()
    if type(map) ~= "number" or type(level) ~= "number" or level <= 0 then return nil end
    local name = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(map)
    if type(name) ~= "string" then return nil end
    return ("%s +%d"):format(name, level)
end

local owner, waitingKey, oldKey = {}, false, nil

local function onKeyBags()
    if not waitingKey then return end
    local now = M.KeystoneText()
    if now and now ~= oldKey then
        waitingKey = false
        M.AnnounceSend(L.ANNOUNCE_KEY_TEXT:format(now))
    end
end

local function onCompleted()
    if M.db.announceKey then oldKey, waitingKey = M.KeystoneText(), true end
    if M.db.announceThanks then
        local text = M.db.announceThanksText
        C_Timer.After(2, function() M.AnnounceSend((text ~= "" and text) or L.ANNOUNCE_THANKS_DEFAULT) end)
    end
end

-- the game's own "has been reset" line (INSTANCE_RESET_SUCCESS, "%s has been reset.") as a pattern
local function resetPattern()
    local s = _G.INSTANCE_RESET_SUCCESS
    if type(s) ~= "string" then return nil end
    return "^" .. s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
end
M.ResetPattern = resetPattern

local function onSystem(_, _, msg)
    if not M.db.announceReset or type(msg) ~= "string" or ns.Secret.IsSecret(msg) then return end
    local pat = resetPattern()
    local what = pat and msg:match(pat)
    if what then M.AnnounceSend(L.ANNOUNCE_RESET_TEXT:format(what)) end
end

function M:EnableAnnounce()
    ns.Events:OffAll(owner)
    local db = self.db
    if db.announceKey or db.announceThanks then ns.Events:On("CHALLENGE_MODE_COMPLETED", owner, onCompleted) end
    if db.announceKey then ns.Events:On("BAG_UPDATE_DELAYED", owner, onKeyBags) end
    if db.announceReset then ns.Events:On("CHAT_MSG_SYSTEM", owner, onSystem) end
end
M.OnKeyBags, M.OnCompleted, M.OnSystem = onKeyBags, onCompleted, onSystem

-- live: a changed announce switch takes effect at once
local previous = M.OnSettingChanged
function M:OnSettingChanged(key, ...)
    if previous then previous(self, key, ...) end
    if type(key) == "string" and key:find("^announce") then self:EnableAnnounce() end
end
