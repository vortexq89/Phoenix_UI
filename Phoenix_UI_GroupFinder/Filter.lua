local _, ns = ...
local L = ns.L
local X = ns.GroupFinderExpression
local M = ns:GetModule("GroupFinder")

--[[ Filters, sorting and presets. The simple controls and the typed expression become one list of checks;
    a group matches when every check passes. The "game filters" are Blizzard's own advanced filter, saved with
    C_LFGList.SaveAdvancedFilter so the client itself drops those groups from the list. ]]

---------------------------------------------------------------- simple checks
-- { setting, test(record, value) -> passes, reason key }. A nil record field never fails a check.
local function atLeast(field) return function(r, v) return v <= 0 or r[field] == nil or r[field] >= v end end
local function atMost(field) return function(r, v) return v <= 0 or r[field] == nil or r[field] <= v end end
local function flag(field) return function(r, v) return not v or r[field] ~= false end end
local function free(field) return function(r, v) return not v or r[field] == nil or r[field] > 0 end end

M.CHECKS = {
    { "freeTank", free("tankfree"), text = "LFG_WHY_TANK" },
    { "freeHealer", free("healfree"), text = "LFG_WHY_HEALER" },
    { "freeDamage", free("dpsfree"), text = "LFG_WHY_DAMAGE" },
    { "minScore", atLeast("score"), text = "LFG_WHY_SCORE" },
    { "keyMin", function(r, v) return v <= 0 or not r.mythicplus or r.bestkey == nil or r.bestkey >= v end, text = "LFG_WHY_KEY" },
    { "keyMax", function(r, v) return v <= 0 or not r.mythicplus or r.bestkey == nil or r.bestkey <= v end, text = "LFG_WHY_KEY" },
    { "minMembers", atLeast("members"), text = "LFG_WHY_MEMBERS" },
    { "maxMembers", atMost("members"), text = "LFG_WHY_MEMBERS" },
    { "maxAge", atMost("age"), text = "LFG_WHY_AGE" },
    { "minIlvl", atLeast("ilvl"), text = "LFG_WHY_ILVL" },
    { "minPvp", function(r, v) return v <= 0 or not r.pvpactivity or r.pvp >= v end, text = "LFG_WHY_PVP" },
    { "maxPvp", function(r, v) return v <= 0 or not r.pvpactivity or r.pvp <= v end, text = "LFG_WHY_PVP" },
    { "friends", function(r, v) return not v or ((r.friends or 0) + (r.guild or 0)) > 0 end, text = "LFG_WHY_FRIENDS" },
    { "voice", function(r, v) return v == "any" or r.voice == nil or r.voice == (v == "with") end, text = "LFG_WHY_VOICE" },
    { "bosses", function(r, v)
        if v == "any" or not r.raid then return true end
        if v == "fresh" then return r.bosses == 0 end
        return r.bosses > 0
    end, text = "LFG_WHY_BOSSES" },
    { "hasLust", flag("lust"), text = "LFG_WHY_LUST" },
    { "hasBrez", flag("brez"), text = "LFG_WHY_BREZ" },
    { "hideDeclined", function(r, v) return not v or not r.declined end, text = "LFG_WHY_DECLINED" },
    { "noLeavers", function(r, v) return not v or (r.leavers or 0) == 0 end, text = "LFG_WHY_LEAVERS" },
}

-- Compiles the current settings; self.filterError is the expression's error (nil when it compiled).
function M:BuildFilter()
    local db = self.db
    self.filterError = nil
    self.expressionFn = nil
    if db.expression ~= "" then
        local fn, err = X.Compile(db.expression, self.WORDS)
        if fn then self.expressionFn = fn else self.filterError = err end
    end
end

-- passes, reason (a locale key) for one record.
function M:Match(r)
    if not r then return true end
    local db = self.db
    for _, c in ipairs(self.CHECKS) do
        if not c[2](r, db[c[1]]) then return false, c.text end
    end
    if self.expressionFn and not self.expressionFn(r) then return false, "LFG_WHY_EXPRESSION" end
    return true
end

-- Human text for an expression error.
function M:ErrorText(err)
    err = err or self.filterError
    if not err then return nil end
    local kind, detail = err[1], err[2]
    if kind == "word" then return L.LFG_ERR_WORD:format(tostring(detail)) end
    if kind == "end" then return L.LFG_ERR_END end
    if kind == "paren" then return L.LFG_ERR_PAREN end
    return L.LFG_ERR_TOKEN:format(tostring(detail or "?"))
end

---------------------------------------------------------------- sort
-- "Fit": free place for your role first, then friends, then leader score, then newest.
M.SORTS = {
    fit = function(r) return (r.myrole and 1e9 or 0) + ((r.friends or 0) + (r.guild or 0)) * 1e7 + (r.score or 0) * 100 - (r.age or 0) end,
    age = function(r) return -(r.age or 0) end,
    score = function(r) return r.score or 0 end,
    key = function(r) return r.bestkey or 0 end,
    ilvl = function(r) return r.ilvl or 0 end,
    members = function(r) return r.members or 0 end,
    pvp = function(r) return r.pvp or 0 end,
}

M.SORT_LIST = {
    { value = "fit", label = "LFG_SORT_FIT" }, { value = "age", label = "LFG_SORT_AGE" }, { value = "score", label = "LFG_SORT_SCORE" },
    { value = "key", label = "LFG_SORT_KEY" }, { value = "ilvl", label = "LFG_SORT_ILVL" },
    { value = "members", label = "LFG_SORT_MEMBERS" }, { value = "pvp", label = "LFG_SORT_PVP" },
}

function M.Sort(list, by, desc)
    local key = M.SORTS[by] or M.SORTS.fit
    local value = {}
    for _, r in ipairs(list) do value[r] = key(r) end
    table.sort(list, function(a, b)
        local va, vb = value[a], value[b]
        if va == vb then return a.id < b.id end
        if desc then return va > vb end
        return va < vb
    end)
    return list
end

-- Runs every current result through the filter: self.matches (sorted records), self.total, self.why[id] (true or the reason).
function M:Evaluate()
    local matches, state = {}, {}
    local total = 0
    for _, id in ipairs(self.Results()) do
        local r = self:Record(id)
        if r and not r.delisted then
            total = total + 1
            local ok, why = self:Match(r)
            state[id] = ok and true or why
            if ok then matches[#matches + 1] = r end
        end
    end
    self.matches, self.total, self.why = M.Sort(matches, self.db.sort, self.db.sortDesc), total, state
    return #matches, total
end

---------------------------------------------------------------- the game's advanced filter
M.GAME_KEYS = { diffNormal = "difficultyNormal", diffHeroic = "difficultyHeroic", diffMythic = "difficultyMythic",
    diffMythicPlus = "difficultyMythicPlus", hasTank = "hasTank", hasHealer = "hasHealer", minRating = "minimumRating",
    needsMyRole = true }

-- Writes the game-filter settings into Blizzard's advanced filter, keeping its dungeon and playstyle picks.
function M:PushGameFilter()
    local current = C_LFGList.GetAdvancedFilter()
    if type(current) ~= "table" then return end
    local db, out = self.db, {}
    for k, v in pairs(current) do out[k] = v end
    for key, field in pairs(self.GAME_KEYS) do
        if field ~= true then out[field] = db[key] end
    end
    local role = M.MyRole()
    out.needsTank = db.needsMyRole and role == "tank" or false
    out.needsHealer = db.needsMyRole and role == "heal" or false
    out.needsDamage = db.needsMyRole and role == "dps" or false
    -- the game reads "no difficulty ticked" as "every difficulty"
    C_LFGList.SaveAdvancedFilter(out)
end

---------------------------------------------------------------- presets
-- Each preset resets the Phoenix filters, then sets its own values.
M.PRESETS = {
    { value = "none", label = "LFG_PRESET_NONE" },
    { value = "push", label = "LFG_PRESET_PUSH", set = { minScore = 2500, hasLust = true, maxAge = 30 } },
    { value = "relaxed", label = "LFG_PRESET_RELAXED", set = { keyMax = 10, maxAge = 60, noLeavers = true } },
    { value = "myrole", label = "LFG_PRESET_MYROLE", set = { expression = "myrole" } },
    { value = "fresh", label = "LFG_PRESET_FRESH", set = { bosses = "fresh", maxAge = 20 } },
    { value = "progress", label = "LFG_PRESET_PROGRESS", set = { bosses = "progress", minMembers = 10 } },
    { value = "friends", label = "LFG_PRESET_FRIENDS", set = { friends = true } },
    { value = "rated", label = "LFG_PRESET_RATED", set = { minPvp = 1800, voice = "with" } },
}
local PHOENIX_KEYS = { "freeTank", "freeHealer", "freeDamage", "minScore", "keyMin", "keyMax", "minMembers", "maxMembers",
    "maxAge", "minIlvl", "minPvp", "maxPvp", "friends", "voice", "bosses", "hasLust", "hasBrez", "noLeavers", "expression" }

function M:ApplyPreset(key)
    local preset
    for _, p in ipairs(self.PRESETS) do if p.value == key then preset = p end end
    if not preset or not preset.set then return end
    for _, k in ipairs(PHOENIX_KEYS) do self.db[k] = self.defaults[k] end
    for k, v in pairs(preset.set) do self.db[k] = v end
end
