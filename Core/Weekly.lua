local _, ns = ...

--[[ ns.Weekly — Great Vault progress and the Mythic+ season at a glance (roadmap S4), for Home.
    Data only: C_WeeklyRewards.GetActivities, C_MythicPlus.GetRunHistory and the player's rating summary.
    All plain values; anything unexpected (nil, secret, missing API) reads as "no data". ]]
local Wk = {}
ns.Weekly = Wk
local Secret = ns.Secret

local function num(v)
    if Secret.IsSecret(v) then return nil end
    return tonumber(v)
end

-- Rows in display order. kind = Enum.WeeklyRewardChestThresholdType value (fallbacks: 1, 3, 6).
Wk.TRACKS = {
    { key = "dungeons", label = "HOME_VAULT_DUNGEONS", kind = "Activities", fallback = 1 },
    { key = "raid", label = "HOME_VAULT_RAID", kind = "Raid", fallback = 3 },
    { key = "world", label = "HOME_VAULT_WORLD", kind = "World", fallback = 6 },
}

local function kindOf(track)
    local enum = Enum and Enum.WeeklyRewardChestThresholdType
    return num(enum and enum[track.kind]) or track.fallback
end

-- { slots = { { threshold, progress, level, done }, … }, progress = n, done = unlocked slots }
function Wk:Track(track)
    local out = { slots = {}, progress = 0, done = 0 }
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return out end
    local ok, list = pcall(C_WeeklyRewards.GetActivities, kindOf(track))
    if not ok or type(list) ~= "table" then return out end
    table.sort(list, function(a, b) return (num(a.index) or 0) < (num(b.index) or 0) end)
    for _, a in ipairs(list) do
        local threshold, progress, level = num(a.threshold), num(a.progress), num(a.level)
        if threshold and progress then
            local done = progress >= threshold
            out.slots[#out.slots + 1] = { threshold = threshold, progress = progress, level = level or 0, done = done }
            out.progress = math.max(out.progress, progress)
            if done then out.done = out.done + 1 end
        end
    end
    return out
end

-- { rating, runs (this week), best (highest key level this week) }
function Wk:Season()
    local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
        and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    local rating = num(type(summary) == "table" and summary.currentSeasonScore) or 0
    local runs, best = 0, 0
    local ok, history = pcall(C_MythicPlus.GetRunHistory, false, true)
    if ok and type(history) == "table" then
        for _, run in ipairs(history) do
            if run.thisWeek ~= false then
                runs = runs + 1
                best = math.max(best, num(run.level) or 0)
            end
        end
    end
    return { rating = rating, runs = runs, best = best }
end

-- Ask the client for fresh data (answers arrive as WEEKLY_REWARDS_UPDATE / CHALLENGE_MODE_MAPS_UPDATE).
function Wk:Request()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then pcall(C_MythicPlus.RequestMapInfo) end
end
