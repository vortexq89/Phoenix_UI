local _, ns = ...
local Style, Secret = ns.Style, ns.Secret

--[[ GroupFinder: filters, sorting, highlights and sign-up helpers for Blizzard's premade group list
    (LFGListFrame), plus applicant details for group leaders. Clean-room: the feature ideas are common to
    group-finder addons; the design and code are ours (docs/research/premade-groups-filter.md).

    Taint rules (AGENTS rule 2, docs/ARCHITECTURE.md §13):
      * Blizzard's list, selection and sign-up stay Blizzard's. Phoenix never writes LFGListFrame fields, never
        replaces or reorders its results table and never calls its select/sign-up functions or
        C_LFGList.ApplyToGroup (undocumented). Groups that fail a Phoenix filter are dimmed, not removed.
      * What really removes groups is the game's own advanced filter (C_LFGList.SaveAdvancedFilter, documented
        and applied by the client), written only when you change a "game filter" here.
      * Sign-up helpers click Blizzard's own buttons through SecureActionButtonTemplate "click" delegates
        (SecureTemplates.lua SECURE_ACTIONS.click) or a key you press, so every sign-up starts from your click.
      * GetSearchResultInfo and friends can return secret values during chat lockdowns: those fields read as
        unknown, and an unknown field never hides a group.

    Blizzard_GroupFinder does not load on WoW Forever (its TOC excludes the camelot game type; Forever ships the
    secure, load-on-demand Blizzard_GroupFinder_VanillaStyle instead), so the module is retail-only. ]]
local M = ns:NewModule("GroupFinder", {
    label = "GROUPFINDER", desc = "GROUPFINDER_DESC", category = "utility", order = 26, icon = "search",
    feature = "lfgList", reloadOnToggle = true,
    defaults = {
        -- filter panel
        panel = true, panelBackground = Style.Background({ alpha = 0.94 }), panelBorder = Style.Border({ style = "ember" }),
        -- the game's own filters (Blizzard's advanced filter; only written when changed here)
        diffNormal = false, diffHeroic = false, diffMythic = false, diffMythicPlus = false,
        needsMyRole = false, hasTank = false, hasHealer = false, minRating = 0,
        -- Phoenix filters (dim what fails)
        freeTank = false, freeHealer = false, freeDamage = false,
        minScore = 0, keyMin = 0, keyMax = 0, minMembers = 0, maxMembers = 0, maxAge = 0, minIlvl = 0,
        minPvp = 0, maxPvp = 0, friends = false, voice = "any", bosses = "any", hasLust = false, hasBrez = false,
        hideDeclined = true, noLeavers = false, expression = "",
        -- results
        nonMatch = "dim", dimAlpha = 0.3, highlight = true, highlightColor = false, sort = "fit", sortDesc = true,
        matchList = true, matchCount = true,
        -- helpers
        quickSignUp = true, enterSignUp = false, roleCheckKey = "off", teleport = true,
        entryScore = true, classBars = true, tooltip = true, lockout = true, skinEntries = true,
        applicantBest = true, applicantSpec = true, applicantMinScore = 0,
        preset = "none",
    },
})

---------------------------------------------------------------- facts
-- Classes that bring a Bloodlust-type haste effect or a combat resurrection (game design facts, Midnight).
M.LUST = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
M.BREZ = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }

-- Words of the filter language and what they read (shown on the help line and in docs/GROUP_FINDER.md).
M.WORDS = {
    age = "minutes listed", members = "players in the group", slots = "free places",
    tanks = "tanks", heals = "healers", dps = "damage dealers",
    tankfree = "free tank places", healfree = "free healer places", dpsfree = "free damage places",
    myrole = "a free place for your role", score = "leader's Mythic+ score",
    dungeonscore = "leader's score in this dungeon", bestkey = "leader's best key in this dungeon",
    timed = "leader timed that key", pvp = "leader's PvP rating", ilvl = "required item level",
    reqscore = "required score", reqrating = "required PvP rating", friends = "friends in the group",
    guild = "guild members in the group", voice = "uses voice chat", bosses = "bosses defeated",
    autoaccept = "joins without approval", warmode = "War Mode", crossfaction = "cross-faction",
    newfriendly = "new-player friendly", declined = "declined you before", leavers = "players flagged as leavers",
    lust = "has Bloodlust", brez = "has a battle resurrection", mythicplus = "Mythic+ key",
    mythic = "Mythic", heroic = "Heroic", normal = "Normal", raid = "raid", dungeon = "dungeon",
    pvpactivity = "PvP", rated = "rated PvP", saved = "you are saved to this raid",
}

local function plain(v)
    if v == nil or Secret.IsSecret(v) then return nil end
    return v
end
local function plainNum(v)
    v = plain(v)
    return type(v) == "number" and v or nil
end
M.Plain = plain

local function myRole()
    local spec = C_SpecializationInfo.GetSpecialization()
    local role = type(spec) == "number" and GetSpecializationRole(spec)
    return role == "TANK" and "tank" or role == "HEALER" and "heal" or "dps"
end
M.MyRole = myRole

local activityCache = {}
function M.Activity(activityID)
    if type(activityID) ~= "number" then return nil end
    local a = activityCache[activityID]
    if a == nil then
        local info = C_LFGList.GetActivityInfoTable(activityID)
        a = type(info) == "table" and info or false
        activityCache[activityID] = a
    end
    return a or nil
end

---------------------------------------------------------------- saved raid lockouts
-- instanceID .. ":" .. difficultyID -> { killed = { [bossName] = true }, total, down }
function M:Lockouts()
    if self.lockouts then return self.lockouts end
    local out = {}
    local n = GetNumSavedInstances()
    for i = 1, type(n) == "number" and n or 0 do
        local _, _, _, difficultyID, locked, _, _, isRaid, _, _, numEncounters, progress, _, instanceID = GetSavedInstanceInfo(i)
        if locked and isRaid and type(instanceID) == "number" then
            local entry = { killed = {}, total = numEncounters or 0, down = progress or 0 }
            for j = 1, type(numEncounters) == "number" and numEncounters or 0 do
                local boss, _, killed = GetSavedInstanceEncounterInfo(i, j)
                if killed and type(boss) == "string" then entry.killed[boss] = true end
            end
            out[instanceID .. ":" .. tostring(difficultyID)] = entry
        end
    end
    self.lockouts = out
    return out
end

---------------------------------------------------------------- one group as a plain record
-- The listing's own fields: size, age, requirements, friends, voice, flags and the leader's ratings.
local function readInfo(r, info)
    r.members = plainNum(info.numMembers)
    r.age = plainNum(info.age) and math.floor(info.age / 60) or nil
    r.ilvl = plainNum(info.requiredItemLevel)
    r.reqscore = plainNum(info.requiredDungeonScore) or 0
    r.reqrating = plainNum(info.requiredPvpRating) or 0
    local bn, cf, gm = plainNum(info.numBNetFriends), plainNum(info.numCharFriends), plainNum(info.numGuildMates)
    r.friends = (bn and cf) and (bn + cf) or nil
    r.guild = gm
    local voice = plain(info.voiceChat)
    if type(voice) == "string" then r.voice = voice ~= "" end
    r.autoaccept = plain(info.autoAccept) and true or false
    r.warmode = plain(info.isWarMode) and true or false
    r.crossfaction = plain(info.crossFactionListing) and true or false
    r.newfriendly = plain(info.newPlayerFriendly) and true or false
    r.delisted = plain(info.isDelisted) and true or false
    r.score = plainNum(info.leaderOverallDungeonScore) or 0
    local best = type(info.leaderDungeonScoreInfo) == "table" and info.leaderDungeonScoreInfo[1]
    if type(best) == "table" then
        r.dungeonscore = plainNum(best.mapScore)
        r.bestkey = plainNum(best.bestRunLevel)
        r.timed = plain(best.finishedSuccess) and true or false
    end
    local pvp = type(info.leaderPvpRatingInfo) == "table" and info.leaderPvpRatingInfo[1]
    r.pvp = type(pvp) == "table" and plainNum(pvp.rating) or 0
end

-- What kind of activity it is (difficulty, PvP, raid or dungeon).
local function readActivity(r, a)
    r.mythicplus = a.isMythicPlusActivity and true or false
    r.mythic = (a.isMythicActivity and not a.isMythicPlusActivity) and true or false
    r.heroic = a.isHeroicActivity and true or false
    r.normal = a.isNormalActivity and true or false
    r.pvpactivity = a.isPvpActivity and true or false
    r.rated = a.isRatedPvpActivity and true or false
    r.max = plainNum(a.maxNumPlayers)
    r.raid = (r.max and r.max > 5 and not r.pvpactivity) and true or false
    r.dungeon = (r.max == 5 and not r.pvpactivity) and true or false
end

-- Roles filled and free, the members' classes, Bloodlust and battle res, leavers.
local function readMembers(r, resultID)
    local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
    if type(counts) == "table" then
        r.tanks, r.heals, r.dps = plainNum(counts.TANK), plainNum(counts.HEALER), plainNum(counts.DAMAGER)
        r.tankfree, r.healfree, r.dpsfree = plainNum(counts.TANK_REMAINING), plainNum(counts.HEALER_REMAINING),
            plainNum(counts.DAMAGER_REMAINING)
    end
    if r.max and r.members then r.slots = math.max(0, r.max - r.members) end
    local role = myRole()
    local free = role == "tank" and r.tankfree or role == "heal" and r.healfree or r.dpsfree
    if free then r.myrole = free > 0 end
    r.classes, r.lust, r.brez, r.leavers = {}, false, false, 0
    for i = 1, r.members or 0 do
        local p = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
        local class = type(p) == "table" and plain(p.classFilename)
        if type(class) == "string" then
            r.classes[#r.classes + 1] = { class = class, role = plain(p.assignedRole), leader = plain(p.isLeader) and true or false }
            if M.LUST[class] then r.lust = true end
            if M.BREZ[class] then r.brez = true end
            if plain(p.isLeaver) then r.leavers = r.leavers + 1 end
        end
    end
end

--[[ Everything the filters, sort and decorations need, read once per result and cached until the game says
    the result changed (LFG_LIST_SEARCH_RESULT_UPDATED). Fields the game hides (secret) stay nil. ]]
function M:Record(resultID)
    self.records = self.records or {}
    local cached = self.records[resultID]
    if cached then return cached end
    if not C_LFGList.HasSearchResultInfo(resultID) then return nil end
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if type(info) ~= "table" then return nil end
    local activityID = type(info.activityIDs) == "table" and info.activityIDs[1] or nil
    local a = M.Activity(activityID) or {}
    local r = { id = resultID, activityID = activityID, mapID = a.mapID, difficultyID = a.difficultyID }
    readInfo(r, info)
    readActivity(r, a)
    readMembers(r, resultID)
    -- bosses down and your lockout
    local enc = C_LFGList.GetSearchResultEncounterInfo(resultID)
    r.bossNames = type(enc) == "table" and enc or {}
    r.bosses = #r.bossNames
    r.lock = (r.raid and a.mapID) and self:Lockouts()[a.mapID .. ":" .. tostring(a.difficultyID)] or nil
    r.saved = r.lock ~= nil
    local _, status, pending = C_LFGList.GetApplicationInfo(resultID)
    status = plain(status)
    r.status, r.pending = status, plain(pending)
    r.declined = type(status) == "string" and status:find("^declined") ~= nil or false
    self.records[resultID] = r
    return r
end

function M:Forget(resultID)
    if not self.records then return end
    if resultID then self.records[resultID] = nil else wipe(self.records) end
end

-- The current search results (plain list of IDs).
function M.Results()
    local _, list = C_LFGList.GetSearchResults()
    if type(list) ~= "table" then return {} end
    return list
end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    self:BuildFilter()
    ns.Events:On("LFG_LIST_SEARCH_RESULTS_RECEIVED", self, function() self:Forget(); self:OnResults() end)
    ns.Events:On("LFG_LIST_SEARCH_RESULT_UPDATED", self, function(_, _, id) self:Forget(id); self:OnResults(true) end)
    ns.Events:On("LFG_LIST_SEARCH_FAILED", self, function() self:OnResults() end)
    ns.Events:On("UPDATE_INSTANCE_INFO", self, function() self.lockouts = nil end)
    ns.Events:On("PLAYER_SPECIALIZATION_CHANGED", self, function() self:Forget(); self:OnResults(true) end)
    RequestRaidInfo()
    self:EnableList()
    self:EnablePanel()
    self:EnableHelpers()
    self:SetupTeleport() -- Teleport.lua
end

function M:OnDisable()
    self:DisablePanel()
    self:DisableHelpers()
end

-- New or changed results: refresh the counts, the match list and the decorated entries.
function M:OnResults(soft)
    self:Evaluate()
    self:RefreshPanel(soft)
    self:RefreshEntries()
end

function M:Refresh()
    self:BuildFilter()
    self:OnResults(true)
    self:StylePanel()
    self:RefreshHelpers()
end

function M:OnSettingChanged(path)
    if path == "preset" then self:ApplyPreset(self.db.preset) end
    if self.GAME_KEYS[path] then self:PushGameFilter() end
    self:Refresh()
end
