local _, ns = ...
local Skin, Theme = ns.Skin, ns.Theme
local M = ns.modules.Minimap

--[[ Zone levels on the world map (EllesmereUI Forever Essentials reference; both clients). On a continent map each
    zone shows its name and level range at its middle, the range coloured by how hard it is for you (the game's
    quest difficulty colours). Levels come from the game (C_Map.GetMapLevels), places from C_Map.GetMapRectOnMap:
    no zone data is shipped. Our own plain font strings on a layer of WorldMapFrame's canvas, redrawn from
    post-hooks on map change and zoom; the text keeps one size on screen at any zoom. ]]

local SIZE = 12
local layer
local labels = {}

-- "10-20", "60" (one level) or nil (a zone without levels).
function M.ZoneLevelText(lo, hi)
    lo, hi = tonumber(lo) or 0, tonumber(hi) or 0
    if hi <= 0 then return nil end
    if lo <= 0 or lo == hi then return tostring(hi) end
    return lo .. "-" .. hi
end

-- Zones of a continent map with levels: { name, text, lo, hi, x, y } (x, y = middle, 0..1 on the map).
function M:ZoneLevelList(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not (info and info.mapType == Enum.UIMapType.Continent) then return {} end
    local out = {}
    for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, Enum.UIMapType.Zone) or {}) do
        local lo, hi = C_Map.GetMapLevels(child.mapID)
        local text = M.ZoneLevelText(lo, hi)
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(child.mapID, mapID)
        if text and minX and maxX and minY and maxY and maxX > minX and maxY > minY then
            out[#out + 1] = { name = child.name, text = text, lo = tonumber(lo) or 0, hi = tonumber(hi) or 0,
                x = (minX + maxX) / 2, y = (minY + maxY) / 2 }
        end
    end
    return out
end

local function label(i)
    local l = labels[i]
    if l then return l end
    l = CreateFrame("Frame", nil, layer)
    l:SetSize(1, 1)
    l:EnableMouse(false)
    l.name = l:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l.name:SetPoint("BOTTOM", l, "CENTER", 0, 1)
    l.range = l:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l.range:SetPoint("TOP", l, "CENTER", 0, -1)
    labels[i] = l
    return l
end

local function color(lo)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(lo)
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return Theme:Color("text.primary")
end

function M:DrawZoneLevels()
    for _, l in ipairs(labels) do l:Hide() end
    local map = WorldMapFrame
    if not (self:IsEnabled() and self.db.zoneLevels and map and map:IsShown()) then return end
    local canvas = map:GetCanvas()
    if not canvas then return end
    if not layer then
        layer = CreateFrame("Frame", nil, canvas)
        layer:SetAllPoints()
    end
    layer:SetFrameLevel(canvas:GetFrameLevel() + 1500)
    local scale = map:GetCanvasScale()
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local size = SIZE / scale
    for i, z in ipairs(self:ZoneLevelList(map:GetMapID())) do
        local l = label(i)
        Skin:Text(l.name, "body", "text.primary", size, "OUTLINE")
        Skin:Text(l.range, "number", "text.primary", size, "OUTLINE")
        l.name:SetText(z.name)
        l.range:SetText(z.text)
        l.range:SetTextColor(color(z.lo))
        l:ClearAllPoints()
        l:SetPoint("CENTER", layer, "TOPLEFT", z.x * w, -z.y * h)
        l:Show()
    end
end

function M:ZoneLevelLabels() return labels end

local hooked = false
function M:SetupZoneLevels()
    if hooked or not WorldMapFrame then return end
    hooked = true
    local function draw() ns.SafeCall(M.DrawZoneLevels, M) end
    hooksecurefunc(WorldMapFrame, "OnMapChanged", draw)
    hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", draw)
    WorldMapFrame:HookScript("OnShow", draw)
end
