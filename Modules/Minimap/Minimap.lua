local _, ns = ...
local L, Skin, Media, W = ns.L, ns.Skin, ns.Media, ns.Widgets

--[[ Minimap: optional square shape with a Phoenix border, themed zone text and player coordinates.
    Size (50-200 %), position and wheel zoom stay with Blizzard Edit Mode / the default Minimap; the
    settings page shows the current Edit Mode size and opens Edit Mode to change it.
    Button bin: minimap buttons made with LibDBIcon (the library most addons use, embedded in theirs) are
    gathered into a Phoenix flyout opened from one glyph on the minimap's corner. Only addon-owned buttons
    are moved, never Blizzard frames; buttons their addon hides stay hidden. ]]
local M = ns:NewModule("Minimap", {
    label = "MINIMAP", desc = "MINIMAP_DESC", category = "interface", order = 80, reloadOnToggle = true,
    defaults = { square = true, coords = true, zoneText = true, bin = true, binColumns = 4 },
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
    -- Polls only while the minimap is on screen (the position has no event).
    if self.db.coords and Minimap:IsVisible() then
        updateCoords()
        ticker = C_Timer.NewTicker(0.25, updateCoords)
    end
end

---------------------------------------------------------------- button bin
local BIN_SIZE, CELL, PAD = 22, 32, 8
local bin -- { toggle, flyout, buttons = { [button] = name }, list = { button } }
local placing -- recursion guard for the SetPoint hook

local function libIcon() return LibStub and LibStub("LibDBIcon-1.0", true) end

local function layoutBin()
    if not bin then return end
    local cols = math.max(1, M.db.binColumns or 4)
    local shown = {}
    for _, b in ipairs(bin.list) do
        if not (b.db and b.db.hide) then shown[#shown + 1] = b end
    end
    table.sort(shown, function(a, b) return bin.buttons[a] < bin.buttons[b] end)
    placing = true
    for i, b in ipairs(shown) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        b:SetParent(bin.flyout)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bin.flyout, "TOPLEFT", PAD + col * CELL, -PAD - row * CELL)
        b:SetFrameLevel(bin.flyout:GetFrameLevel() + 2)
        b:SetAlpha(1)
    end
    placing = nil
    local rows = math.max(1, math.ceil(#shown / cols))
    bin.flyout:SetSize(PAD * 2 + math.min(#shown, cols) * CELL - (CELL - 31), PAD * 2 + rows * CELL - 1)
    bin.count = #shown
    bin.toggle:SetShown(M.db.bin and #shown > 0)
    if #shown == 0 then bin.flyout:Hide() end
end

local function collect(name, button)
    if not (bin and button) or bin.buttons[button] then return end
    bin.buttons[button] = name
    bin.list[#bin.list + 1] = button
    -- LibDBIcon re-anchors a button on drag, on show and on lib:Refresh; put it back in its cell.
    hooksecurefunc(button, "SetPoint", function()
        if not placing and M.db.bin then C_Timer.After(0, layoutBin) end
    end)
    button:RegisterForDrag() -- dragging around the minimap edge makes no sense inside the bin
    if button.Show then hooksecurefunc(button, "Show", function() if not placing then C_Timer.After(0, layoutBin) end end) end
    if button.Hide then hooksecurefunc(button, "Hide", function() if not placing then C_Timer.After(0, layoutBin) end end) end
end

local scanPending
local function scan()
    scanPending = nil
    local lib = libIcon()
    if not (bin and lib) then return end
    for _, name in ipairs(lib:GetButtonList()) do collect(name, lib:GetMinimapButton(name)) end
    if not bin.registered then
        bin.registered = true
        lib.RegisterCallback(M, "LibDBIcon_IconCreated", function(_, button, name)
            collect(name, button); C_Timer.After(0, layoutBin)
        end)
    end
    layoutBin()
end
local function scanSoon()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.5, scan)
end
M.ScanBin = scan

-- Buttons currently in the bin, and a way to show it from the settings page.
function M:BinCount() return bin and bin.count or 0 end
function M:OpenBin() if bin and (bin.count or 0) > 0 then bin.flyout:Show() end end

local function buildBin()
    bin = { buttons = {}, list = {} }
    local holder = CreateFrame("Frame", nil, Minimap)
    holder:SetSize(BIN_SIZE, BIN_SIZE)
    holder:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -4, -4)
    holder:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    Skin:Register(holder, function(self) Skin:Panel(self, "raised", { border = "border.default" }) end)
    holder:Hide()
    local t = W:IconButton(holder, "bin", BIN_SIZE, L.MINIMAP_BIN, L.MINIMAP_BIN_TIP)
    t:SetAllPoints()
    local f = CreateFrame("Frame", "PhoenixUIMinimapBin", UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 0, -4)
    f:SetClampedToScreen(true)
    f:Hide()
    Skin:Register(f, function(self) Skin:Panel(self, "raised", { border = "border.default", shadow = true }) end)
    tinsert(UISpecialFrames, "PhoenixUIMinimapBin") -- Escape closes it
    t.onClick = function() f:SetShown(not f:IsShown()) end
    local function state(open) t.active = open; ns.Icons:SetState(t.icon, open and "active" or nil) end
    f:SetScript("OnShow", function() state(true) end)
    f:SetScript("OnHide", function() state(false) end)
    bin.toggle, bin.flyout = holder, f
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
    if not self.hooked then
        self.hooked = true
        Minimap:HookScript("OnShow", function() if M:IsEnabled() then setupCoords(M) end end)
        Minimap:HookScript("OnHide", function() if ticker then ticker:Cancel(); ticker = nil end end)
    end
    if self.db.bin then
        if not bin then buildBin() end
        scan()
        ns.Events:On("PLAYER_ENTERING_WORLD", self, scanSoon)
        ns.Events:On("ADDON_LOADED", self, scanSoon)
    end
end

function M:Refresh()
    setupCoords(self)
    layoutBin()
end

-- Edit Mode's Minimap "Size" setting as a percentage, or nil before Edit Mode has initialized.
-- EditModeSystemMixin:GetSettingValue only reads the system's settingMap.
function M:GetEditModeSize()
    if not (MinimapCluster and MinimapCluster.GetSettingValue and MinimapCluster:IsInitialized()) then return nil end
    return MinimapCluster:GetSettingValue(Enum.EditModeMinimapSetting.Size)
end

function M:OnDisable()
    if ticker then ticker:Cancel(); ticker = nil end
    if coords then coords:Hide() end
end

