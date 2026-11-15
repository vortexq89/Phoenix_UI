-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns.modules.Automation

--[[ Auto combat logging: turns /combatlog on when you enter the content you picked (Mythic+ keys, raids,
    dungeons) and off again when you leave it, but only when Phoenix was the one that turned it on, so a log you
    started yourself is never stopped. Event driven (zone changes, key start); no polling. ]]

local started = false

-- "mplus" | "raid" | "dungeon" | nil for where you are now (plain instance info only).
function M.LogContext()
    local cm = C_ChallengeMode
    if cm and cm.IsChallengeModeActive then
        local ok, active = pcall(cm.IsChallengeModeActive)
        if ok and active == true then return "mplus" end
    end
    local inside, kind = IsInInstance()
    if not inside then return nil end
    if kind == "raid" then return "raid" end
    if kind == "party" then return "dungeon" end
    return nil
end

function M:WantsLog(context)
    local db = self.db
    if not (db.autoLog and context) then return false end
    if context == "mplus" then return db.autoLogMplus end
    if context == "raid" then return db.autoLogRaid end
    return db.autoLogDungeon
end

local function logging()
    if not LoggingCombat then return nil end
    local ok, on = pcall(LoggingCombat)
    if ok and type(on) == "boolean" then return on end
    return nil
end

function M:UpdateAutoLog()
    if not LoggingCombat then return end
    local want = self:IsEnabled() and self:WantsLog(M.LogContext())
    local on = logging()
    if want and on == false then
        if pcall(LoggingCombat, true) then
            started = true
            ns:Print(L.AUTO_LOG_ON)
        end
    elseif not want and started and on then
        pcall(LoggingCombat, false)
        started = false
        ns:Print(L.AUTO_LOG_OFF)
    elseif not want then
        started = false
    end
end

local pending = false
local function queue()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        ns.SafeCall(M.UpdateAutoLog, M)
    end)
end
M.QueueAutoLog = queue

function M:EnableAutoLog()
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED" }) do
        ns.Events:On(ev, self, queue)
    end
    queue()
end

-- live: a changed autoLog setting is applied at once, not on the next zone change
local previous = M.OnSettingChanged
function M:OnSettingChanged(key, ...)
    if previous then previous(self, key, ...) end
    if type(key) == "string" and key:find("^autoLog") then queue() end
end
