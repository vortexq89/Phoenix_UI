local _, ns = ...
local L = ns.L
local Style, Secret = ns.Style, ns.Secret

--[[ Quests: the objective tracker restyle (Tracker.lua), the quest helper — map and minimap pins for quest
    givers and turn-ins, a waypoint arrow (Pins.lua, Arrow.lua) — and quest automation (Auto.lua).
    Giver positions come from the load-on-demand Phoenix_UI_Data addon (facts from AllTheThings, MIT; turn-ins
    from Blizzard's QuestPOI tables), loaded only while a pin option is on. Everything here is plain quest
    and map API work out of combat; nothing protected is touched (docs/QUEST_DATA.md). ]]
local M = ns:NewModule("Quests", {
    label = "QUESTS", desc = "QUESTS_DESC", category = "utility", order = 25, icon = "maps", reloadOnToggle = true,
    defaults = {
        -- objective tracker
        restyle = true, width = 0, maxHeight = 0,
        header = Style.Text(14), objective = Style.Text(12),
        bar = "", difficulty = true, collapse = "off", level = true, superTrack = true,
        -- waypoint arrow
        arrow = true, arrowStyle = "phoenix", arrowSize = 44, distance = true, eta = true,
        -- map pins
        questLines = true, turnins = true, npcPins = true, minimap = true, pinSize = 18, hideTrivial = true,
        slices = { midnight = true, tww = true, forever = true },
        -- automation
        autoAccept = false, autoTurnIn = false, reward = "off",
        tooltip = true, contribute = false,
        progressSound = true, progressAnnounce = "off", -- Progress.lua
        -- NPC locations (NPCs.lua): giver spot in quest tooltips, townsfolk / rare pins, map search, /way
        npcLocation = true, townsfolk = false, rares = false, mapSearch = true, waySlash = true,
    },
    -- local collector recordings (Collector.lua): this install only, never uploaded
    globalDefaults = { collected = {}, vignettes = {} },
})

M.DATA_ADDON = "Phoenix_UI_Data"
-- Slices the data addon can hold (Phoenix_UI_Data/Manifest.lua), with the level cap of their content: quests
-- of a slice you have out-levelled count as trivial. The expansion filter shows only this client's slices.
M.SLICES = {
    { key = "midnight", label = "QUESTS_SLICE_MIDNIGHT", flavor = "retail", cap = 90 },
    { key = "tww", label = "QUESTS_SLICE_TWW", flavor = "retail", cap = 80 },
    { key = "forever", label = "QUESTS_SLICE_FOREVER", flavor = "forever", cap = 60 },
}
local SLICE = {}
for _, s in ipairs(M.SLICES) do SLICE[s.key] = s end

---------------------------------------------------------------- data addon
-- True when any option needs the giver/turn-in data.
function M:WantsData()
    local db = self.db
    return db.npcPins or db.turnins or db.tooltip or db.townsfolk or db.rares or db.mapSearch
end

-- Loads Phoenix_UI_Data once; nil (and a reason) when it is missing or disabled.
function M:Data()
    if self.data then return self.data end
    if self.dataError then return nil, self.dataError end
    if not C_AddOns.IsAddOnLoaded(self.DATA_ADDON) then
        local ok, reason = C_AddOns.LoadAddOn(self.DATA_ADDON)
        if not ok then
            self.dataError = reason or "MISSING"
            return nil, self.dataError
        end
    end
    local D = PhoenixUI_QuestData
    if type(D) ~= "table" or type(D.slices) ~= "table" or type(D.quests) ~= "table" then
        self.dataError = "INVALID"
        return nil, self.dataError
    end
    self.data, self.decoded, self.byQuest, self.npcIndex = D, {}, nil, nil
    return D
end

local function ids(s)
    if not s or s == "" then return nil end
    local out = {}
    for v in s:gmatch("%d+") do out[#out + 1] = tonumber(v) end
    return out
end

--[[ One packed record (tools/questdata/build_questdata.py):
    questID,npcID,x,y,minLevel,side,flags,classes/,races/,prerequisites/,needed,turnInMap,turnInX,turnInY
    x/y are in 0.1 % of the map. ]]
function M.Decode(rec, slice, mapID)
    local f, i = {}, 1
    for v in (rec .. ","):gmatch("([^,]*),") do f[i] = v; i = i + 1 end
    local flags = tonumber(f[7]) or 0
    local q = {
        id = tonumber(f[1]), npc = tonumber(f[2]) or 0, map = mapID, slice = slice,
        x = (tonumber(f[3]) or 0) / 1000, y = (tonumber(f[4]) or 0) / 1000,
        minLevel = tonumber(f[5]) or 0, side = tonumber(f[6]) or 0,
        daily = flags % 2 == 1, weekly = math.floor(flags / 2) % 2 == 1,
        breadcrumb = math.floor(flags / 4) % 2 == 1, repeatable = math.floor(flags / 8) % 2 == 1,
        classes = ids(f[8]), races = ids(f[9]), pre = ids(f[10]), need = tonumber(f[11]),
        turnMap = tonumber(f[12]),
    }
    if q.turnMap then q.turnX, q.turnY = (tonumber(f[13]) or 0) / 1000, (tonumber(f[14]) or 0) / 1000 end
    return q
end

function M:SliceOn(key)
    return self.db.slices[key] ~= false
end

-- Every quest record on a map from the slices that are switched on (decoded once per map and slice).
function M:QuestsOnMap(mapID)
    local D = self:Data()
    if not D or not mapID then return {} end
    local out = {}
    for _, s in ipairs(D.slices) do
        if self:SliceOn(s.key) then
            local cacheKey = s.key .. ":" .. mapID
            local list = self.decoded[cacheKey]
            if not list then
                list = {}
                local packed = D.quests[s.key] and D.quests[s.key][mapID]
                if packed then
                    for rec in packed:gmatch("[^;]+") do list[#list + 1] = M.Decode(rec, s.key, mapID) end
                end
                self.decoded[cacheKey] = list
            end
            for _, q in ipairs(list) do out[#out + 1] = q end
        end
    end
    return out
end

-- questID -> its first record (any map), for turn-ins and tooltips. Built on first use.
function M:Record(questID)
    local D = self:Data()
    if not D then return nil end
    if not self.byQuest then
        local index = {}
        for _, s in ipairs(D.slices) do
            for mapID, packed in pairs(D.quests[s.key] or {}) do
                for rec in packed:gmatch("[^;]+") do
                    local id = tonumber(rec:match("^(%d+)"))
                    if id and not index[id] then index[id] = { s.key, mapID, rec } end
                end
            end
        end
        self.byQuest = index
    end
    local hit = self.byQuest[questID]
    if not hit then return nil end
    if type(hit[3]) == "string" then self.byQuest[questID] = M.Decode(hit[3], hit[1], hit[2]) end
    return self.byQuest[questID]
end

-- NPC ID -> quests it gives (any map); for unit tooltips.
function M:QuestsFromNPC(npcID)
    local D = self:Data()
    if not D or not npcID then return {} end
    if not self.byNPC then
        local index = {}
        for _, s in ipairs(D.slices) do
            for mapID, packed in pairs(D.quests[s.key] or {}) do
                for rec in packed:gmatch("[^;]+") do
                    local id, npc = rec:match("^(%d+),(%d+)")
                    npc = tonumber(npc)
                    if npc and npc > 0 then
                        index[npc] = index[npc] or {}
                        index[npc][#index[npc] + 1] = { s.key, mapID, rec, tonumber(id) }
                    end
                end
            end
        end
        self.byNPC = index
    end
    local out, seen = {}, {}
    for _, hit in ipairs(self.byNPC[npcID] or {}) do
        if not seen[hit[4]] and self:SliceOn(hit[1]) then
            seen[hit[4]] = true
            out[#out + 1] = M.Decode(hit[3], hit[1], hit[2])
        end
    end
    return out
end

-- The game's localized title when it knows the quest, else the data's English one.
function M:QuestName(questID)
    local title = C_QuestLog.GetTitleForQuestID(questID)
    if type(title) == "string" and title ~= "" then return title end
    local D = self.data
    return D and D.questNames[questID] or ("#" .. tostring(questID))
end

function M:NPCName(npcID)
    local D = self.data
    return D and D.npcNames[npcID] or nil
end

---------------------------------------------------------------- availability
-- The player facts the filter needs, read once per refresh.
function M.Context()
    local faction = UnitFactionGroup("player")
    local _, _, raceID = UnitRace("player")
    local _, _, classID = UnitClass("player")
    local level = UnitLevel("player")
    local gap = UnitQuestTrivialLevelRange and UnitQuestTrivialLevelRange("player")
    return {
        side = faction == "Alliance" and 1 or (faction == "Horde" and 2 or 0),
        race = type(raceID) == "number" and raceID or 0, class = type(classID) == "number" and classID or 0,
        level = type(level) == "number" and level or 1, gap = type(gap) == "number" and gap or 8,
    }
end

local function has(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function done(questID) return C_QuestLog.IsQuestFlaggedCompleted(questID) == true end
local function inLog(questID)
    local index = C_QuestLog.GetLogIndexForQuestID(questID)
    return type(index) == "number" and index > 0
end

-- Trivial: you out-level the quest's requirement by the game's grey range, or the slice's level cap.
function M.IsTrivial(q, ctx)
    if q.minLevel > 0 and ctx.level - q.minLevel >= ctx.gap then return true end
    local s = SLICE[q.slice]
    return s ~= nil and ctx.level > s.cap
end

--[[ Can this character pick the quest up now? Not done, not in the log, right side/race/class, high enough
    and every prerequisite done (or `need` of them). Returns available, why-not key. ]]
function M:IsAvailable(q, ctx)
    if done(q.id) then return false, "done" end
    if inLog(q.id) then return false, "log" end
    if q.side ~= 0 and ctx.side ~= 0 and q.side ~= ctx.side then return false, "side" end
    if q.races and ctx.race ~= 0 and not has(q.races, ctx.race) then return false, "race" end
    if q.classes and ctx.class ~= 0 and not has(q.classes, ctx.class) then return false, "class" end
    if q.minLevel > ctx.level then return false, "level" end
    if q.pre then
        local n = 0
        for _, id in ipairs(q.pre) do if done(id) then n = n + 1 end end
        if n < (q.need or #q.pre) then return false, "prerequisite" end
    end
    if self.db.hideTrivial and M.IsTrivial(q, ctx) then return false, "trivial" end
    return true
end

-- Quests in your log that are ready to hand in, with their turn-in spot on mapID (from the data).
function M:TurnInsOnMap(mapID)
    local out = {}
    if not mapID then return out end
    local count = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, type(count) == "number" and count or 0 do
        local info = C_QuestLog.GetInfo(i)
        local id = info and not info.isHeader and info.questID
        if id and C_QuestLog.ReadyForTurnIn(id) then
            local q = self:Record(id)
            if q and q.turnMap == mapID then out[#out + 1] = q end
        end
    end
    return out
end

---------------------------------------------------------------- progress tooltips
-- "3/8 Boars slain" lines for a quest in the log, with an overall percentage.
function M.Progress(questID)
    local objectives = C_QuestLog.GetQuestObjectives(questID)
    if type(objectives) ~= "table" then return nil end
    local lines, sum, n = {}, 0, 0
    for _, o in ipairs(objectives) do
        if type(o.text) == "string" then
            local have, need = tonumber(o.numFulfilled), tonumber(o.numRequired)
            local part = o.finished and 1 or ((have and need and need > 0) and math.min(1, have / need) or 0)
            sum, n = sum + part, n + 1
            lines[#lines + 1] = { text = o.text, finished = o.finished and true or false }
        end
    end
    if n == 0 then return nil end
    return lines, math.floor(sum / n * 100 + 0.5)
end

-- Adds a quest's details (who gives it, level, repeat, progress) to a tooltip.
function M:AddQuestLines(tt, q, header)
    if header then tt:AddLine(self:QuestName(q.id), 1, 0.82, 0) end
    local who = q.npc and q.npc > 0 and self:NPCName(q.npc)
    if who then
        tt:AddLine(L.QUESTS_TIP_GIVER:format(who), 0.8, 0.8, 0.8)
        self:AddNPCLocation(tt, q.npc)
    end
    if q.minLevel > 0 then tt:AddLine(L.QUESTS_TIP_LEVEL:format(q.minLevel), 0.8, 0.8, 0.8) end
    if q.daily then tt:AddLine(L.QUESTS_TIP_DAILY, 0.3, 0.7, 1) elseif q.weekly then tt:AddLine(L.QUESTS_TIP_WEEKLY, 0.3, 0.7, 1) end
    if q.breadcrumb then tt:AddLine(L.QUESTS_TIP_BREADCRUMB, 0.7, 0.7, 0.7) end
    local lines, pct = M.Progress(q.id)
    if lines then
        tt:AddLine(L.QUESTS_TIP_PROGRESS:format(pct), 0.25, 0.81, 0.44)
        for _, line in ipairs(lines) do
            local c = line.finished and 0.5 or 1
            tt:AddLine("  " .. line.text, c, c, c)
        end
    end
end

local function npcFromGUID(guid)
    if type(guid) ~= "string" or Secret.IsSecret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end
M.NPCFromGUID = npcFromGUID

-- Unit tooltips: the quests this NPC can give you right now (from the data).
local function onUnit(tt, data)
    if not (M:IsEnabled() and M.db.tooltip and tt == GameTooltip) or tt:IsForbidden() then return end
    local npc = npcFromGUID(data and data.guid)
    if not npc or not M.data then return end
    local ctx, shown = M.Context(), 0
    for _, q in ipairs(M:QuestsFromNPC(npc)) do
        if M:IsAvailable(q, ctx) and shown < 4 then
            if shown == 0 then tt:AddLine(" ") end
            shown = shown + 1
            tt:AddLine(L.QUESTS_TIP_OFFERS:format(M:QuestName(q.id)), 1, 0.82, 0)
        end
    end
    if shown > 0 then tt:Show() end
end

---------------------------------------------------------------- lifecycle
local hooked
function M:OnEnable()
    if self:WantsData() then self:Data() end
    if not hooked then
        hooked = true
        if TooltipDataProcessor and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
                local ok, err = pcall(onUnit, tt, data)
                if not ok and not M.tipError then M.tipError = true; geterrorhandler()(err) end
            end)
        end
    end
    self:EnableTracker()
    self:EnablePins()
    self:EnableArrow()
    self:EnableAuto()
    self:EnableCollector()
    self:EnableMapSearch()
    self:RegisterWay()
    local function invalidate() self.ctxDirty = true; self:RefreshPins() end
    if self.SetupProgress then self:SetupProgress() end -- Progress.lua
    ns.Events:On("QUEST_TURNED_IN", self, invalidate)
    ns.Events:On("QUEST_ACCEPTED", self, invalidate)
    ns.Events:On("QUEST_REMOVED", self, invalidate)
    ns.Events:On("QUEST_LOG_UPDATE", self, function() self:RefreshPins(true) end)
    ns.Events:On("PLAYER_LEVEL_UP", self, invalidate)
    ns.Events:On("ZONE_CHANGED_NEW_AREA", self, function() self:RefreshPins(); self:ApplyCollapse(); self:RefreshArrow() end)
end

function M:OnDisable()
    if M.searchBox then M.searchBox:Hide() end
    self:DisablePins()
    self:DisableArrow()
end

function M:Refresh()
    if self:WantsData() then self:Data() end
    self.decoded = self.data and {} or self.decoded
    self.npcIndex = nil
    self:EnableMapSearch()
    self:RefreshTracker()
    self:RefreshPins()
    self:RefreshArrow()
end
