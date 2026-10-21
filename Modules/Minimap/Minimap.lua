local _, ns = ...
local Skin, Media = ns.Skin, ns.Media

--[[ Minimap: optional square shape with a Phoenix border, themed zone text and player coordinates.
    Size, position and wheel zoom stay with Blizzard Edit Mode / the default Minimap. ]]
local M = ns:NewModule("Minimap", {
    label = "MINIMAP", desc = "MINIMAP_DESC", category = "interface", order = 80, reloadOnToggle = true,
    defaults = { square = true, coords = true, zoneText = true },
})

local coords, ticker

local function updateCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then coords:SetText(""); return end
    local x, y = pos:GetXY()
    if ns.Secret.IsSecret(x) or not (x and y) or (x == 0 and y == 0) then coords:SetText(""); return end
    coords:SetFormattedText("%.1f  %.1f", x * 100, y * 100)
end

local function setupCoords(self)
    if not coords then
        coords = Minimap:CreateFontString(nil, "OVERLAY")
        coords:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 8)
        Skin:Register(coords, function(fs) Skin:Text(fs, "number", "text.primary", 11, "OUTLINE") end)
    end
    if ticker then ticker:Cancel(); ticker = nil end
    coords:SetShown(self.db.coords)
    if self.db.coords then
        updateCoords()
        ticker = C_Timer.NewTicker(0.25, updateCoords)
    end
end

-- The zoomed-in indoor/city map (Blizzard_HybridMinimap, load-on-demand) draws through its own circular mask.
local function squareHybridMinimap()
    HybridMinimap.CircleMask:SetTexture(Media.textures.WHITE)
end

function M:OnEnable()
    if self.db.square then
        Minimap:SetMaskTexture(Media.textures.WHITE)
        -- Community convention read by LibDBIcon and other minimap-button addons to lay buttons out
        -- along a square edge. The one global Phoenix defines besides its SavedVariables.
        function GetMinimapShape() return "SQUARE" end
        if HybridMinimap then
            squareHybridMinimap()
        else
            EventUtil.ContinueOnAddOnLoaded("Blizzard_HybridMinimap", squareHybridMinimap)
        end
        Skin:HideRegion(MinimapCompassTexture)
        Skin:Register(Minimap, function(frame)
            Skin:Border(frame, "border.black")
            Skin:Shadow(frame, 10)
        end)
    end
    if self.db.zoneText then
        Skin:Register(MinimapZoneText, function(fs) Skin:Text(fs, "heading", nil, 12) end)
    end
    setupCoords(self)
end

function M:Refresh()
    setupCoords(self)
end

function M:OnDisable()
    if ticker then ticker:Cancel(); ticker = nil end
    if coords then coords:Hide() end
end

