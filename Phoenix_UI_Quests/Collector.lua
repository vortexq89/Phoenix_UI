local _, ns = ...
local M = ns.modules.Quests
local Secret = ns.Secret

--[[ Local NPC position collector (opt-in: Quests > Automation > "Record NPC positions", off by default).
    When you talk to an NPC (gossip, quest dialog, merchant, trainer, flight master) it notes the NPC's ID
    (UnitCreatureID("npc"), never parsed from a GUID), the map and your own position; when a vignette (rare,
    event) appears it notes the vignette ID and the position the game gives for it. Only in the open world,
    out of combat, and only when no value is secret. Nothing else is stored: no names, realms or GUIDs.
    Recordings live in PhoenixUIDB (global, this install only) and are never uploaded or shared; a maintainer
    may merge their own file into Phoenix_UI_Data with tools/questdata/merge_collected.py. ]]
M.COLLECT_CAP = 5000 -- NPC x map entries kept; further positions only refine existing ones
local KIND = { GOSSIP_SHOW = 0, QUEST_DETAIL = 1, QUEST_GREETING = 1, QUEST_PROGRESS = 1, QUEST_COMPLETE = 1,
    MERCHANT_SHOW = 2, TRAINER_SHOW = 3, TAXIMAP_OPENED = 5 }
M.COLLECT_EVENTS = KIND

local function secret(v) return Secret.IsSecret ~= nil and Secret.IsSecret(v) end

-- Why the collector would not record right now (nil when it would).
function M:CollectBlocked()
    if not (self:IsEnabled() and self.db.contribute) then return "off" end
    if InCombatLockdown() then return "combat" end
    local inInstance = IsInInstance()
    if inInstance then return "instance" end
    return nil
end

-- Your own map position, or nil when secret / unknown.
local function here()
    local mapID = C_Map.GetBestMapForUnit("player")
    if type(mapID) ~= "number" or secret(mapID) then return nil end
    local x, y = ns.Util.PlayerMapXY()
    if not x then return nil end
    return mapID, x, y
end

local function store()
    local g = M.global
    if type(g.collected) ~= "table" then g.collected = {} end
    if type(g.vignettes) ~= "table" then g.vignettes = {} end
    return g.collected, g.vignettes
end

function M:RecordedCount()
    local n = 0
    for _, maps in pairs(self:Recorded()) do for _ in pairs(maps) do n = n + 1 end end
    return n
end

-- Notes one position (0-1 map coordinates). Repeated sightings average out; a merchant / trainer / quest
-- kind beats plain gossip. Returns true when stored.
function M:RecordSpot(npcID, mapID, x, y, kind)
    if type(npcID) ~= "number" or npcID <= 0 or type(mapID) ~= "number" or not (x and y) then return false end
    local npcs = store()
    local maps = npcs[npcID]
    local r = maps and maps[mapID]
    if not r then
        if self:RecordedCount() >= M.COLLECT_CAP then return false end
        maps = maps or {}
        npcs[npcID] = maps
        r = { x = x, y = y, k = kind or 0, n = 1 }
        maps[mapID] = r
    else
        r.n = (r.n or 1) + 1
        r.x = r.x + (x - r.x) / r.n
        r.y = r.y + (y - r.y) / r.n
        if (kind or 0) > 0 then r.k = kind end
    end
    r.x, r.y = math.floor(r.x * 10000 + 0.5) / 10000, math.floor(r.y * 10000 + 0.5) / 10000
    self.npcIndex = nil
    return true
end

-- The NPC you are talking to (event handlers).
function M:RecordInteraction(event)
    if self:CollectBlocked() then return false end
    if not UnitExists("npc") then return false end
    local id = UnitCreatureID and UnitCreatureID("npc")
    if type(id) ~= "number" or secret(id) then return false end
    local mapID, x, y = here()
    if not mapID then return false end
    return self:RecordSpot(id, mapID, x, y, KIND[event] or 0)
end

-- Vignettes on your map: their ID and the position the game reports for them.
function M:RecordVignettes()
    if self:CollectBlocked() or not C_VignetteInfo then return 0 end
    local mapID = C_Map.GetBestMapForUnit("player")
    if type(mapID) ~= "number" or secret(mapID) then return 0 end
    local _, vignettes = store()
    local n = 0
    for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
        if not secret(guid) then
            local info = C_VignetteInfo.GetVignetteInfo(guid)
            local id = info and info.vignetteID
            local pos = C_VignetteInfo.GetVignettePosition(guid, mapID)
            if type(id) == "number" and not secret(id) and pos then
                local x, y = pos:GetXY()
                if x and y and not secret(x) and not secret(y) and not vignettes[id] then
                    vignettes[id] = { map = mapID, x = math.floor(x * 10000 + 0.5) / 10000, y = math.floor(y * 10000 + 0.5) / 10000 }
                    n = n + 1
                end
            end
        end
    end
    return n
end

function M:ClearRecorded()
    local g = self.global
    g.collected, g.vignettes = {}, {}
    self.npcIndex = nil
end

-- Its own event owner: Auto.lua already listens to the same gossip and quest events as the module.
local owner = {}
function M:EnableCollector()
    for event in pairs(KIND) do
        ns.Events:On(event, owner, function() M:RecordInteraction(event) end)
    end
    ns.Events:On("VIGNETTES_UPDATED", owner, function() M:RecordVignettes() end)
end
