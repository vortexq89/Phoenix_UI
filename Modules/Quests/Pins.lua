local _, ns = ...
local M = ns.modules.Quests
local L, Secret = ns.L, ns.Secret

--[[ Quest pins on the world map and the minimap.
    World map: our own plain frames on WorldMapFrame's canvas, redrawn from post-hooks on OnMapChanged and
    OnCanvasScaleChanged (hooksecurefunc keeps Blizzard's map code secure; no data provider is added).
    Sources: available quest lines (C_QuestLine, the game's own list), quest givers from Phoenix_UI_Data (only
    quests the game did not already list) and turn-ins for completed quests in your log.
    Minimap: the same records for the player's map, placed by world distance (C_Map.GetWorldPosFromMapPos)
    inside C_Minimap.GetViewRadius, rotated with the minimap when "Rotate Minimap" is on. ]]
local ATLAS = { available = "QuestNormal", daily = "QuestDaily", turnin = "QuestTurnin", repeatable = "QuestRepeatableTurnin" }

-- The game answers RequestQuestLinesForMap with QUESTLINE_UPDATE; ask once per map so a redraw never loops.
local requested = {}

-- Pins wanted on a map: { kind, questID, x, y, record = data record|nil, name = string|nil }.
function M:PinsFor(mapID)
    local db, out, listed = self.db, {}, {}
    if not mapID then return out end
    if db.questLines then
        if not requested[mapID] then
            requested[mapID] = true
            C_QuestLine.RequestQuestLinesForMap(mapID)
        end
        for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
            if type(info.questID) == "number" and not info.isHidden then
                listed[info.questID] = true
                out[#out + 1] = { kind = info.isDaily and "daily" or "available", questID = info.questID, x = info.x, y = info.y,
                    name = info.questName, line = info.questLineName }
            end
        end
    end
    if db.npcPins and self.data then
        local ctx = self.ctx or M.Context()
        self.ctx = ctx
        for _, q in ipairs(self:QuestsOnMap(mapID)) do
            if not listed[q.id] and self:IsAvailable(q, ctx) then
                listed[q.id] = true
                out[#out + 1] = { kind = (q.daily or q.weekly) and "daily" or (q.repeatable and "repeatable" or "available"),
                    questID = q.id, x = q.x, y = q.y, record = q }
            end
        end
    end
    if db.turnins and self.data then
        for _, q in ipairs(self:TurnInsOnMap(mapID)) do
            out[#out + 1] = { kind = "turnin", questID = q.id, x = q.turnX, y = q.turnY, record = q }
        end
    end
    return out
end

---------------------------------------------------------------- pin frames
local function pinTooltip(pin)
    local p = pin.data
    if not p then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(M:QuestName(p.questID) or p.name, 1, 0.82, 0)
    if p.line then GameTooltip:AddLine(p.line, 0.8, 0.8, 0.8) end
    if p.kind == "turnin" then GameTooltip:AddLine(L.QUESTS_TIP_TURNIN, 0.25, 0.81, 0.44) end
    if p.record then M:AddQuestLines(GameTooltip, p.record, false) end
    GameTooltip:AddLine(L.QUESTS_TIP_CLICK, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function pinClick(pin)
    local p, map = pin.data, pin.mapID
    if not (p and map) then return end
    M:SetTarget(map, p.x, p.y, M:QuestName(p.questID) or p.name)
end

local function newPin(parent, pool)
    local pin = CreateFrame("Button", nil, parent)
    pin.icon = pin:CreateTexture(nil, "OVERLAY")
    pin.icon:SetAllPoints()
    pin:SetScript("OnEnter", pinTooltip)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", pinClick)
    pool[#pool + 1] = pin
    return pin
end

local function setKind(pin, kind)
    if pin.kind ~= kind then
        pin.kind = kind
        pin.icon:SetAtlas(ATLAS[kind] or ATLAS.available)
    end
end

---------------------------------------------------------------- world map
local mapPins, mapLayer = {}, nil

function M:DrawWorldMap()
    local map = WorldMapFrame
    for _, pin in ipairs(mapPins) do pin:Hide() end
    if not (map and map:IsShown() and self:IsEnabled()) then return end
    local canvas = map:GetCanvas()
    if not canvas then return end
    if not mapLayer then
        mapLayer = CreateFrame("Frame", nil, canvas)
        mapLayer:SetAllPoints()
    end
    mapLayer:SetFrameLevel(canvas:GetFrameLevel() + 2000)
    local mapID = map:GetMapID()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local scale = map:GetCanvasScale()
    local size = self.db.pinSize / ((type(scale) == "number" and scale > 0) and scale or 1)
    for i, p in ipairs(self:PinsFor(mapID)) do
        local pin = mapPins[i] or newPin(mapLayer, mapPins)
        pin.data, pin.mapID = p, mapID
        setKind(pin, p.kind)
        pin:SetSize(size, size)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", mapLayer, "TOPLEFT", p.x * w, -p.y * h)
        pin:Show()
    end
end

local function resizeMapPins()
    local map = WorldMapFrame
    if not (map and mapLayer) then return end
    local scale = map:GetCanvasScale()
    local size = M.db.pinSize / ((type(scale) == "number" and scale > 0) and scale or 1)
    for _, pin in ipairs(mapPins) do if pin:IsShown() then pin:SetSize(size, size) end end
end

---------------------------------------------------------------- minimap
local miniPins, miniFrame = {}, nil
local VEC = CreateVector2D

local function worldPos(mapID, x, y)
    local cont, pos = C_Map.GetWorldPosFromMapPos(mapID, VEC(x, y))
    if not pos then return nil end
    local wx, wy = pos:GetXY()
    if Secret.IsSecret and (Secret.IsSecret(wx) or Secret.IsSecret(wy)) then return nil end
    return cont, wx, wy
end

-- Offset of a world point from the player in minimap pixels, or nil when off the minimap.
function M.MinimapOffset(px, py, tx, ty, radiusYards, radiusPx, facing)
    local north, west = tx - px, ty - py -- world X runs north, world Y runs west
    local ex, ny = -west, north
    if facing then
        local c, s = math.cos(-facing), math.sin(-facing)
        ex, ny = ex * c - ny * s, ex * s + ny * c
    end
    local dist = math.sqrt(ex * ex + ny * ny)
    if dist > radiusYards then return nil end
    local k = radiusPx / radiusYards
    return ex * k, ny * k
end

local function updateMinimap()
    if not (M:IsEnabled() and M.db.minimap and Minimap and Minimap:IsVisible()) then
        for _, pin in ipairs(miniPins) do pin:Hide() end
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local x, y = ns.Util.PlayerMapXY()
    local list = M.miniList
    if not (mapID and x and list) then
        for _, pin in ipairs(miniPins) do pin:Hide() end
        return
    end
    local cont, px, py = worldPos(mapID, x, y)
    local radius = C_Minimap.GetViewRadius()
    if not (cont and type(radius) == "number" and radius > 0) then return end
    local facing
    if C_CVar.GetCVar("rotateMinimap") == "1" then
        local f = GetPlayerFacing()
        if type(f) == "number" and not Secret.IsSecret(f) then facing = f end
    end
    local radiusPx = Minimap:GetWidth() / 2
    local used = 0
    for _, p in ipairs(list) do
        if p.wx and p.cont == cont then
            local ox, oy = M.MinimapOffset(px, py, p.wx, p.wy, radius, radiusPx - 4, facing)
            if ox then
                used = used + 1
                local pin = miniPins[used] or newPin(miniFrame, miniPins)
                pin.data, pin.mapID = p, p.mapID
                setKind(pin, p.kind)
                pin:SetSize(M.db.pinSize * 0.8, M.db.pinSize * 0.8)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
                pin:Show()
            end
        end
    end
    for i = used + 1, #miniPins do miniPins[i]:Hide() end
end

-- The minimap list is rebuilt on map or quest changes; positions follow the player every 0.2 s.
function M:RebuildMinimap()
    self.miniList = nil
    if not (self:IsEnabled() and self.db.minimap) then return updateMinimap() end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return updateMinimap() end
    local list = {}
    for _, p in ipairs(self:PinsFor(mapID)) do
        local cont, wx, wy = worldPos(mapID, p.x, p.y)
        if cont then
            p.cont, p.wx, p.wy, p.mapID = cont, wx, wy, mapID
            list[#list + 1] = p
        end
    end
    self.miniList = list
    updateMinimap()
end

---------------------------------------------------------------- lifecycle
local pinsHooked
function M:EnablePins()
    if not pinsHooked and WorldMapFrame then
        pinsHooked = true
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() M:DrawWorldMap() end)
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", resizeMapPins)
        WorldMapFrame:HookScript("OnShow", function() M:DrawWorldMap() end)
    end
    if not miniFrame and Minimap then
        miniFrame = CreateFrame("Frame", nil, Minimap)
        miniFrame:SetAllPoints()
        miniFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        local acc = 0
        miniFrame:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc < 0.2 then return end
            acc = 0
            updateMinimap()
        end)
    end
    ns.Events:On("QUESTLINE_UPDATE", self, function() self:RefreshPins(true) end)
    ns.Events:On("PLAYER_ENTERING_WORLD", self, function() self:RefreshPins() end)
    self:RefreshPins()
end

function M:DisablePins()
    for _, pin in ipairs(mapPins) do pin:Hide() end
    for _, pin in ipairs(miniPins) do pin:Hide() end
end

-- Redraw both; `soft` (quest log churn) waits a moment so bursts of events cost one rebuild.
function M:RefreshPins(soft)
    if not self:IsEnabled() then return end
    if soft then
        if self.pinsPending then return end
        self.pinsPending = true
        C_Timer.After(1, function() self.pinsPending = nil; self:RefreshPins() end)
        return
    end
    if self.ctxDirty or not self.ctx then self.ctx, self.ctxDirty = M.Context(), nil end
    if (self.db.npcPins or self.db.turnins) and not self.data then self:Data() end
    self:DrawWorldMap()
    self:RebuildMinimap()
end
