local _, ns = ...
local Theme = ns.Theme
local M = ns.modules.Minimap

--[[ Map reveal (EllesmereUI Forever Essentials reference; WoW Forever). Zone maps show the parts you have not
    explored yet, optionally tinted so they stay recognisable. The pieces are the client's own map overlays
    (Modules/Minimap/RevealData.lua, generated from the WorldMapOverlay DB2 tables by tools/mapreveal/build.py),
    picked by the shown map's art (C_Map.GetMapArtID); the ones C_MapExplorationInfo.GetExploredMapTextures already
    lists are left to Blizzard's own exploration layer. Our own textures on our own frame over WorldMapFrame's
    canvas, laid out on the art layer's tile grid like the game's (C_Map.GetMapArtLayers), redrawn from post-hooks
    on map change and zoom and on MAP_EXPLORATION_UPDATED; no data provider, nothing of Blizzard's is changed. ]]

local layer
local textures, used = {}, 0
local parsed = {} -- art ID -> overlay list, decoded once on first use
local owner = {} -- our own event owner, so the hook set up once keeps its event across module off / on

-- "w,h,x,y,cols,f.f.f" -> { w, h, x, y, cols, fids }; nil for a malformed entry.
function M.ParseOverlay(s)
    local w, h, x, y, cols, list = tostring(s):match("^(%d+),(%d+),(%-?%d+),(%-?%d+),(%d+),([%d%.]+)$")
    if not w then return nil end
    local fids = {}
    for f in list:gmatch("%d+") do fids[#fids + 1] = tonumber(f) end
    cols = tonumber(cols)
    if cols < 1 or #fids % cols ~= 0 then return nil end
    return { w = tonumber(w), h = tonumber(h), x = tonumber(x), y = tonumber(y), cols = cols, fids = fids }
end

local function overlaysFor(art)
    if parsed[art] ~= nil then return parsed[art] end
    local raw = ns.RevealData and ns.RevealData.arts[art]
    local list = {}
    for _, s in ipairs(raw or {}) do list[#list + 1] = M.ParseOverlay(s) end
    parsed[art] = list
    return list
end

-- The overlays of a map that are still dark for this character.
function M:UnexploredOverlays(mapID)
    local art = tonumber(mapID and C_Map.GetMapArtID(mapID))
    if not art then return {} end
    local explored = {}
    local done = C_MapExplorationInfo.GetExploredMapTextures(mapID)
    for _, t in ipairs(type(done) == "table" and done or {}) do
        explored[tostring(t.offsetX) .. ":" .. tostring(t.offsetY)] = true
    end
    local out = {}
    for _, o in ipairs(overlaysFor(art)) do
        if not explored[o.x .. ":" .. o.y] then out[#out + 1] = o end
    end
    return out
end

-- Size of a tile's file: the next power of two from 16 that holds the drawn part (the game's rule).
function M.RevealFileSize(px, tile)
    if px >= tile then return tile end
    local size = 16
    while size < px do size = size * 2 end
    return size
end

-- One overlay cut into its tiles: { x, y, w, h, u, v, fid } in canvas units.
function M.RevealTiles(o, tileW, tileH)
    local out = {}
    local rows = #o.fids / o.cols
    for j = 1, rows do
        local ph = j < rows and tileH or (o.h - tileH * (rows - 1))
        for k = 1, o.cols do
            local pw = k < o.cols and tileW or (o.w - tileW * (o.cols - 1))
            if pw > 0 and ph > 0 then
                out[#out + 1] = { x = o.x + tileW * (k - 1), y = o.y + tileH * (j - 1), w = pw, h = ph,
                    u = pw / M.RevealFileSize(pw, tileW), v = ph / M.RevealFileSize(ph, tileH),
                    fid = o.fids[(j - 1) * o.cols + k] }
            end
        end
    end
    return out
end

local function texture(i)
    local t = textures[i]
    if not t then
        t = layer:CreateTexture(nil, "ARTWORK")
        textures[i] = t
    end
    return t
end

function M:HideReveal()
    for i = 1, used do textures[i]:Hide() end
    used = 0
end

function M:DrawReveal()
    self:HideReveal()
    local map = WorldMapFrame
    if not (self:IsEnabled() and self.db.mapReveal and ns:Supports("mapReveal") and map and map:IsShown()) then return end
    local canvas, mapID = map:GetCanvas(), map:GetMapID()
    if not (canvas and mapID) then return end
    local layers = C_Map.GetMapArtLayers(mapID)
    local container = map.GetCanvasContainer and map:GetCanvasContainer()
    local index = tonumber(container and container.GetCurrentLayerIndex and container:GetCurrentLayerIndex()) or 1
    local info = type(layers) == "table" and (layers[index] or layers[1])
    local tileW, tileH = tonumber(type(info) == "table" and info.tileWidth), tonumber(type(info) == "table" and info.tileHeight)
    if not (tileW and tileH and tileW > 0 and tileH > 0) then return end
    if not layer then
        layer = CreateFrame("Frame", nil, canvas)
        layer:SetAllPoints()
        layer:EnableMouse(false)
    end
    layer:SetFrameLevel(canvas:GetFrameLevel() + 1)
    local r, g, b = 1, 1, 1
    if self.db.revealTint then r, g, b = Theme:Color("accent.soft") end
    local alpha = self.db.revealAlpha
    for _, o in ipairs(self:UnexploredOverlays(mapID)) do
        for _, p in ipairs(M.RevealTiles(o, tileW, tileH)) do
            used = used + 1
            local t = texture(used)
            t:ClearAllPoints()
            t:SetSize(p.w, p.h)
            t:SetPoint("TOPLEFT", layer, "TOPLEFT", p.x, -p.y)
            t:SetTexture(p.fid, nil, nil, "TRILINEAR")
            t:SetTexCoord(0, p.u, 0, p.v)
            t:SetVertexColor(r, g, b, alpha)
            t:Show()
        end
    end
end

function M:RevealCount() return used end

local hooked = false
function M:SetupReveal()
    if hooked or not WorldMapFrame or not ns:Supports("mapReveal") then return end
    hooked = true
    local function draw() ns.SafeCall(M.DrawReveal, M) end
    hooksecurefunc(WorldMapFrame, "OnMapChanged", draw)
    hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", draw)
    WorldMapFrame:HookScript("OnShow", draw)
    ns.Events:On("MAP_EXPLORATION_UPDATED", owner, draw)
end
