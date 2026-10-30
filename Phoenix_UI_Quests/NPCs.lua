local _, ns = ...
local M = ns.modules.Quests
local L = ns.L

--[[ NPC locations: where quest givers, vendors, profession NPCs / trainers and rares stand, from Phoenix_UI_Data
    (NPCs_<Slice>.lua, AllTheThings facts; NPCs_Collected.lua, positions merged from the local collector) and
    the positions this install recorded itself (Collector.lua, not yet merged). One index serves the NPC search
    (/pui quests npc, the world map search box), the /way command, quest tooltips ("given by … at …") and the
    townsfolk / rare map pins, so nothing here duplicates the quest records. ]]
M.NPC_KINDS = { [0] = "other", [1] = "giver", [2] = "vendor", [3] = "trainer", [4] = "rare", [5] = "flight" }
M.NPC_ICONS = { other = "user", giver = "tracker", vendor = "gold", trainer = "spec", rare = "boss", flight = "maps" }
M.NPC_TOKENS = { other = "text.secondary", giver = "accent.primary", vendor = "state.warning", trainer = "state.info",
    rare = "state.danger", flight = "state.success" }
M.NPC_LABELS = { other = L.QUESTS_NPC_OTHER, giver = L.QUESTS_NPC_GIVER, vendor = L.QUESTS_NPC_VENDOR,
    trainer = L.QUESTS_NPC_TRAINER, rare = L.QUESTS_NPC_RARE, flight = L.QUESTS_NPC_FLIGHT }

-- "npcID,x,y,kind" (x/y in 0.1 %) -> spot
function M.DecodeNPC(rec, mapID, source)
    local id, x, y, kind = rec:match("^(%d+),(%d+),(%d+),?(%d*)")
    if not id then return nil end
    return { id = tonumber(id), map = mapID, x = tonumber(x) / 1000, y = tonumber(y) / 1000,
        kind = M.NPC_KINDS[tonumber(kind) or 0] or "other", source = source }
end

-- This install's own recordings (Collector.lua): npcID -> { [mapID] = { x, y, k, n } }.
function M:Recorded()
    local g = self.global
    return g and type(g.collected) == "table" and g.collected or {}
end

-- npcID -> every known spot, built once per data load (recordings are added live by the collector).
function M:NPCIndex()
    if self.npcIndex then return self.npcIndex end
    local D = self:Data()
    local index = {}
    local function add(packed, mapID, source)
        for rec in packed:gmatch("[^;]+") do
            local spot = M.DecodeNPC(rec, mapID, source)
            if spot then
                index[spot.id] = index[spot.id] or {}
                table.insert(index[spot.id], spot)
            end
        end
    end
    if D then
        for _, s in ipairs(D.slices) do
            if self:SliceOn(s.key) then
                for mapID, packed in pairs(D.npcs and D.npcs[s.key] or {}) do add(packed, mapID, s.key) end
            end
        end
        for mapID, packed in pairs(D.collected or {}) do add(packed, mapID, "collected") end
    end
    for npcID, maps in pairs(self:Recorded()) do
        for mapID, r in pairs(type(maps) == "table" and maps or {}) do
            if type(r) == "table" and r.x and r.y then
                index[npcID] = index[npcID] or {}
                table.insert(index[npcID], { id = npcID, map = mapID, x = r.x, y = r.y, kind = M.NPC_KINDS[r.k or 0] or "other",
                    source = "recorded" })
            end
        end
    end
    self.npcIndex = index
    return index
end

-- The best spot for an NPC: on the map you are on (or `preferMap`) first, else the first known one.
function M:NPCSpot(npcID, preferMap)
    local spots = npcID and self:NPCIndex()[npcID]
    if not spots then return nil end
    preferMap = preferMap or C_Map.GetBestMapForUnit("player")
    for _, s in ipairs(spots) do if s.map == preferMap then return s end end
    return spots[1]
end

-- Spots of one kind on a map (townsfolk and rare pins); one per NPC.
function M:NPCsOnMap(mapID, kinds)
    local out = {}
    if not mapID then return out end
    for _, spots in pairs(self:NPCIndex()) do
        for _, s in ipairs(spots) do
            if s.map == mapID and (not kinds or kinds[s.kind]) then
                out[#out + 1] = s
                break
            end
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function M.ZoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or ("#" .. tostring(mapID))
end

-- "Silvermoon City 45.3, 70.2"
function M.SpotText(spot)
    return L.QUESTS_NPC_AT:format(M.ZoneName(spot.map), spot.x * 100, spot.y * 100)
end

-- Search by NPC ID or by (part of) the English name the data carries; case-insensitive, plain text.
function M:FindNPCs(query, limit)
    local out = {}
    query = strtrim(tostring(query or ""))
    if query == "" then return out end
    limit = limit or 8
    local index = self:NPCIndex()
    local id = tonumber(query)
    if id then
        if index[id] then out[1] = { id = id, name = self:NPCName(id) or ("#" .. id), spot = self:NPCSpot(id) } end
        return out
    end
    local D, needle = self.data, query:lower()
    for npcID, name in pairs(D and D.npcNames or {}) do
        if index[npcID] and name:lower():find(needle, 1, true) then
            out[#out + 1] = { id = npcID, name = name, spot = self:NPCSpot(npcID) }
        end
    end
    table.sort(out, function(a, b)
        local ah, bh = a.spot.map == C_Map.GetBestMapForUnit("player"), b.spot.map == C_Map.GetBestMapForUnit("player")
        if ah ~= bh then return ah end
        return a.name < b.name
    end)
    for i = #out, limit + 1, -1 do out[i] = nil end
    return out
end

-- Point the arrow (and the game's map pin) at an NPC. True when a spot was known.
function M:WayToNPC(npcID)
    local spot = self:NPCSpot(npcID)
    if not spot then return false end
    self:SetTarget(spot.map, spot.x, spot.y, self:NPCName(npcID) or ("#" .. npcID))
    return true
end

--[[ /way [#mapID] x y [title] — x/y as map percentages ("45.3 70.2", "45,3 70,2" or "45.3, 70.2").
    Returns mapID, x, y (0-1), title; nil when the text is not a waypoint. ]]
function M.ParseWay(text, here)
    text = strtrim(tostring(text or ""))
    local mapID
    local m, rest = text:match("^#(%d+)%s*(.*)$")
    if m then mapID, text = tonumber(m), rest end
    local a, b, title = text:match("^(%d+[%.,]?%d*)[%s,]+(%d+[%.,]?%d*)%s*(.*)$")
    if not a then return nil end
    local x, y = tonumber((a:gsub(",", "."))), tonumber((b:gsub(",", ".")))
    if not (x and y) or x > 100 or y > 100 then return nil end
    mapID = mapID or here
    if not mapID then return nil end
    return mapID, x / 100, y / 100, title ~= "" and title or nil
end

function M:Way(text)
    local here = C_Map.GetBestMapForUnit("player")
    local mapID, x, y, title = M.ParseWay(text, here)
    if not mapID then
        -- not coordinates: treat it as an NPC name or ID
        local hit = self:FindNPCs(text, 1)[1]
        if hit and self:WayToNPC(hit.id) then
            ns:Print(L.QUESTS_WAY_SET:format(hit.name, M.SpotText(hit.spot)))
            return true
        end
        ns:Print(L.QUESTS_WAY_USAGE)
        return false
    end
    title = title or L.QUESTS_ARROW_PIN
    self:SetTarget(mapID, x, y, title)
    ns:Print(L.QUESTS_WAY_SET:format(title, M.SpotText({ map = mapID, x = x, y = y })))
    return true
end

-- /pui quests npc <name|id> | way <coords|name> | clear | collected
function M:OnSlash(rest)
    local cmd, arg = strtrim(rest or ""):match("^(%S*)%s*(.-)$")
    if cmd == "npc" or cmd == "find" then
        if not self:Data() then return ns:Print(L.QUESTS_DATA_MISSING) end
        local hits = self:FindNPCs(arg, 6)
        if #hits == 0 then return ns:Print(L.QUESTS_NPC_NONE:format(arg)) end
        for _, h in ipairs(hits) do ns:Print(("%s (#%d): %s"):format(h.name, h.id, M.SpotText(h.spot))) end
        self:WayToNPC(hits[1].id)
        return
    elseif cmd == "way" then
        return self:Way(arg)
    elseif cmd == "clear" then
        self:ClearTarget()
        return C_Map.ClearUserWaypoint()
    elseif cmd == "collected" then
        local n = self:RecordedCount()
        return ns:Print(L.QUESTS_COLLECT_COUNT:format(n))
    end
    ns.Config:Show(self.key)
end

-- Quest tooltips: "at <zone> x, y" under the giver line when the giver's spot is known.
function M:AddNPCLocation(tt, npcID)
    local spot = npcID and npcID > 0 and self.db.npcLocation and self:NPCSpot(npcID)
    if spot then tt:AddLine("  " .. M.SpotText(spot), 0.6, 0.6, 0.6) end
end

-- Pins for townsfolk / rares on a map (Pins.lua merges them into PinsFor).
function M:NPCPinsFor(mapID)
    local db, kinds = self.db, nil
    if db.townsfolk or db.rares then
        kinds = { vendor = db.townsfolk or nil, trainer = db.townsfolk or nil, flight = db.townsfolk or nil, rare = db.rares or nil }
    end
    local out = {}
    if not (kinds and self.data) then return out end
    for _, s in ipairs(self:NPCsOnMap(mapID, kinds)) do
        out[#out + 1] = { kind = s.kind, npc = s.id, x = s.x, y = s.y, name = self:NPCName(s.id) or ("#" .. s.id) }
    end
    return out
end

---------------------------------------------------------------- slash /way
-- /way is TomTom's command; Phoenix registers it only when TomTom is not loaded (/pway always works).
function M:RegisterWay()
    -- live: registered the first time the option is on; the handler reads the option, so off is a no-op without /reload
    if self.wayRegistered or not self.db.waySlash then return end
    self.wayRegistered = true
    local function way(msg) if M:IsEnabled() and M.db.waySlash then M:Way(msg) end end
    if C_AddOns.IsAddOnLoaded("TomTom") then
        RegisterNewSlashCommand(way, "pway", "phoenixway")
    else
        RegisterNewSlashCommand(way, "way", "pway")
    end
end

---------------------------------------------------------------- world map search
local search
local function result(i)
    local b = search.rows[i]
    if b then return b end
    b = CreateFrame("Button", nil, search.list)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", search.list, "TOPLEFT", 4, -4 - (i - 1) * 20)
    b:SetPoint("RIGHT", search.list, "RIGHT", -4, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 4, 0)
    b.text:SetPoint("RIGHT", -4, 0)
    b.text:SetJustifyH("LEFT")
    ns.Skin:Text(b.text, "body", "text.primary", 11)
    b:SetScript("OnClick", function(self)
        if self.hit and M:WayToNPC(self.hit.id) then ns:Print(L.QUESTS_WAY_SET:format(self.hit.name, M.SpotText(self.hit.spot))) end
        search.list:Hide()
    end)
    search.rows[i] = b
    return b
end

function M:SearchMap(text)
    if not search then return {} end
    local hits = (text and #text >= 2) and self:FindNPCs(text, 8) or {}
    for i, h in ipairs(hits) do
        local b = result(i)
        b.hit = h
        b.text:SetText(("%s  |cff999999%s|r"):format(h.name, M.SpotText(h.spot)))
        b:Show()
    end
    for i = #hits + 1, #search.rows do search.rows[i]:Hide() end
    search.list:SetHeight(8 + #hits * 20)
    search.list:SetShown(#hits > 0)
    return hits
end

function M:EnableMapSearch()
    local map = WorldMapFrame
    if not map then return end
    if not search and self.db.mapSearch then
        search = ns.Widgets:Input(map, 180, L.QUESTS_SEARCH_NPC)
        search:SetFrameStrata("HIGH")
        local anchor = map.ScrollContainer or map
        search:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -40, -6)
        search.rows = {}
        search.list = CreateFrame("Frame", nil, search)
        search.list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -2)
        search.list:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 120, -2)
        ns.Skin:Panel(search.list, "raised")
        search.list:Hide()
        search.onTextChanged = function(_, text) M:SearchMap(text) end
        search.onChange = function(_, text)
            local hit = M:SearchMap(text)[1]
            if hit and M:WayToNPC(hit.id) then ns:Print(L.QUESTS_WAY_SET:format(hit.name, M.SpotText(hit.spot))) end
        end
        M.searchBox = search
    end
    if search then search:SetShown(self:IsEnabled() and self.db.mapSearch and self.data ~= nil) end
end

