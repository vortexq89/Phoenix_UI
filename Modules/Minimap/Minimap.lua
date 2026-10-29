local _, ns = ...
local L, Skin, Media, W, Style = ns.L, ns.Skin, ns.Media, ns.Widgets, ns.Style

--[[ Minimap: shape (round, square or a rectangle band), a Phoenix border from the style library, themed zone,
    clock and coordinate texts, Blizzard's minimap buttons shown or tucked away, mouse wheel zoom with an
    automatic zoom-out, ping names and world map coordinates.
    Size, position and scale stay with Blizzard Edit Mode (the page shows the Edit Mode size and opens it):
    MinimapCluster is an Edit Mode system and is never moved, scaled or reparented. Blizzard's own buttons are
    "tucked" by reparenting them to a hidden frame and given back the same way; nothing protected is touched.
    Button bin: minimap buttons made with LibDBIcon (the library most addons use, embedded in theirs) are
    gathered into a Phoenix flyout opened from one glyph on the minimap's corner. Only addon-owned buttons
    are moved, never Blizzard frames; buttons their addon hides stay hidden. ]]
local M = ns:NewModule("Minimap", {
    label = "MINIMAP", desc = "MINIMAP_DESC", category = "interface", order = 80, reloadOnToggle = true,
    defaults = {
        shape = "SQUARE", rectHeight = 80,
        border = Style.Border({ size = 2 }),
        wheelZoom = true, autoZoom = 0, zoomButtons = true,
        zoneText = true, zone = Style.Text(12, { outline = "OUTLINE" }), zonePvP = true,
        clock = true, clockText = Style.Text(11, { outline = "OUTLINE" }),
        coords = true, coordDecimals = 1,
        coordsText = Style.Text(11, { outline = "OUTLINE", anchor = "BOTTOM", y = 8 }),
        calendar = true, tracking = true, mail = true, craftingOrder = true, difficulty = true, expansion = true,
        compartment = true,
        bin = true, binColumns = 4, binSize = 28, binIgnore = "", binMouseover = false,
        pingNames = true, worldMapCoords = true, worldMapScale = 1, zoneLevels = true,
    },
})

M.SHAPES = { ROUND = true, SQUARE = true, RECTANGLE = true }
M.RECTS = { 50, 60, 70, 80, 90 }
local RECT_MASK = {
    [50] = Media.textures.MINIMAP_RECT50, [60] = Media.textures.MINIMAP_RECT60, [70] = Media.textures.MINIMAP_RECT70,
    [80] = Media.textures.MINIMAP_RECT80, [90] = Media.textures.MINIMAP_RECT90,
}

---------------------------------------------------------------- pure helpers (shared with the preview and tests)
-- The rectangle height the page offers nearest to `pct` (saved values from other builds snap to a mask we ship).
function M.SnapRect(pct)
    local best, dist = 80, math.huge
    for _, v in ipairs(M.RECTS) do
        local d = math.abs(v - (tonumber(pct) or 80))
        if d < dist then best, dist = v, d end
    end
    return best
end

-- Vertical inset (each side) of the visible band for a map `height` tall.
function M.BandInset(shape, pct, height)
    if shape ~= "RECTANGLE" then return 0 end
    return math.floor((height or 0) * (100 - M.SnapRect(pct)) / 200 + 0.5)
end

function M.MaskFor(shape, pct)
    if shape == "RECTANGLE" then return RECT_MASK[M.SnapRect(pct)] end
    if shape == "SQUARE" then return Media.textures.WHITE end
end

local COORD_FORMAT = { [0] = "%d  %d", [1] = "%.1f  %.1f", [2] = "%.2f  %.2f" }
-- x, y are 0..1 map fractions; decimals 0..2.
function M.FormatCoords(x, y, decimals)
    local d = math.max(0, math.min(2, math.floor(tonumber(decimals) or 1)))
    if d == 0 then return COORD_FORMAT[0]:format(math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)) end
    return COORD_FORMAT[d]:format(x * 100, y * 100)
end

-- "Alpha, beta ,Gamma" -> { alpha = true, beta = true, gamma = true }
function M.ParseIgnore(text)
    local out = {}
    for word in tostring(text or ""):gmatch("[^,;]+") do
        word = word:gsub("^%s+", ""):gsub("%s+$", ""):lower()
        if word ~= "" then out[word] = true end
    end
    return out
end

function M:Shape() return M.SHAPES[self.db.shape] and self.db.shape or "SQUARE" end

---------------------------------------------------------------- Blizzard's minimap buttons
-- Each element: a resolver (frames differ between Midnight and WoW Forever, and some load on demand).
local function cluster(key) return MinimapCluster and MinimapCluster[key] end
local function indicator(key) local f = cluster("IndicatorFrame"); return f and f[key] end
M.ELEMENTS = {
    { key = "calendar", get = function() return GameTimeFrame end },
    { key = "tracking", get = function() return cluster("Tracking") end },
    { key = "mail", get = function() return indicator("MailFrame") end },
    { key = "craftingOrder", get = function() return indicator("CraftingOrderFrame") end },
    { key = "difficulty", get = function() return cluster("InstanceDifficulty") end },
    { key = "expansion", get = function() return ExpansionLandingPageMinimapButton end },
    { key = "compartment", get = function() return AddonCompartmentFrame end },
    { key = "zoomButtons", get = function() return Minimap.ZoomIn end },
    { key = "zoomButtons", get = function() return Minimap.ZoomOut end },
    { key = "clock", get = function() return TimeManagerClockButton end },
    { key = "zoneText", get = function() return cluster("ZoneTextButton") end },
    { key = "zoneText", get = function() return cluster("BorderTop") end },
}
local tucked = {} -- [frame] = original parent
local tuckParent

local function tuck(frame, show)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if show then
        local parent = tucked[frame]
        if parent then
            tucked[frame] = nil
            frame:SetParent(parent)
        end
    elseif not tucked[frame] then
        tuckParent = tuckParent or CreateFrame("Frame")
        tuckParent:Hide()
        tucked[frame] = frame:GetParent()
        frame:SetParent(tuckParent)
    end
end

function M:IsTucked(frame) return tucked[frame] ~= nil end

function M:ApplyElements()
    local on = self:IsEnabled()
    for _, e in ipairs(M.ELEMENTS) do
        local frame = e.get()
        if frame then tuck(frame, not on or self.db[e.key] ~= false) end
    end
    local ind = cluster("IndicatorFrame")
    if ind and ind.Layout then ind:Layout() end
end

---------------------------------------------------------------- shape and border
local holder -- the visible area: the whole map, or the rectangle band; carries the border and our texts

local function band()
    if not holder then
        holder = CreateFrame("Frame", nil, Minimap)
        holder:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    end
    local inset = M.BandInset(M:Shape(), M.db.rectHeight, Minimap:GetHeight())
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, -inset)
    holder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, inset)
    -- the hidden strips of a rectangle neither ping nor show tooltips
    Minimap:SetHitRectInsets(0, 0, inset, inset)
    return holder
end
M.Holder = function() return holder end

local function styleBorder()
    local h = band()
    if M:Shape() == "ROUND" then
        Skin:BorderSpec(h, { style = "none", shadow = "none" })
    else
        Skin:BorderSpec(h, M.db.border, "border.black")
    end
end

local function hybridMask()
    local mask = M.MaskFor(M:Shape(), M.db.rectHeight)
    if mask and HybridMinimap and HybridMinimap.CircleMask then HybridMinimap.CircleMask:SetTexture(mask) end
end

local function applyShape(self)
    local mask = M.MaskFor(self:Shape(), self.db.rectHeight)
    if mask then
        Minimap:SetMaskTexture(mask)
        -- Community convention read by LibDBIcon and other minimap-button addons to lay buttons out
        -- along a square edge. The one global Phoenix defines besides its SavedVariables.
        function GetMinimapShape() return "SQUARE" end
        if HybridMinimap then hybridMask() end
        Skin:HideRegion(MinimapCompassTexture)
    end
    Skin:Register(band(), styleBorder)
end

---------------------------------------------------------------- texts
local coords, ticker

local function updateCoords()
    local x, y = ns.Util.PlayerMapXY()
    coords:SetText(x and M.FormatCoords(x, y, M.db.coordDecimals) or "")
end

local function setupCoords(self)
    if not coords then coords = band():CreateFontString(nil, "OVERLAY", "GameFontHighlight") end
    Skin:TextSpec(coords, self.db.coordsText, "number", "text.primary")
    Skin:Place(coords, band(), self.db.coordsText)
    if ticker then ticker:Cancel(); ticker = nil end
    coords:SetShown(self.db.coords)
    -- Blizzard's own coordinates (Edit Mode "Show coordinates") would sit right under ours
    local blizz = MinimapCluster and MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords
    if blizz then blizz:SetAlpha(self.db.coords and 0 or 1) end
    -- Polls only while the minimap is on screen (the position has no event).
    if self.db.coords and Minimap:IsVisible() then
        updateCoords()
        ticker = C_Timer.NewTicker(0.25, updateCoords)
    end
end

-- Zone text: Blizzard colours it by PvP status in Minimap_Update; without "PvP colours" ours wins.
local function styleZone()
    if not (M:IsEnabled() and MinimapZoneText) then return end
    local spec = M.db.zone
    Skin:TextSpec(MinimapZoneText, spec, "heading", (not M.db.zonePvP) and "accent.primary" or nil)
end

local function styleClock()
    if not (M:IsEnabled() and TimeManagerClockTicker) then return end
    Skin:TextSpec(TimeManagerClockTicker, M.db.clockText, "number", "text.primary")
    if TimeManagerClockButton then tuck(TimeManagerClockButton, M.db.clock) end
end

---------------------------------------------------------------- zoom
local zoomTimer
local function scheduleZoomOut()
    if zoomTimer then zoomTimer:Cancel(); zoomTimer = nil end
    local delay = M.db.autoZoom or 0
    if not M:IsEnabled() or delay <= 0 or Minimap:GetZoom() == 0 then return end
    zoomTimer = C_Timer.NewTimer(delay, function()
        zoomTimer = nil
        if Minimap:GetZoom() > 0 then
            Minimap:SetZoom(0)
            if Minimap.ZoomIn then Minimap.ZoomIn:Enable() end
            if Minimap.ZoomOut then Minimap.ZoomOut:Disable() end
        end
    end)
end
M.ScheduleZoomOut = scheduleZoomOut

---------------------------------------------------------------- ping names
local pingText, pingTimer
local function onPing(_, unit)
    if not (M:IsEnabled() and M.db.pingNames) or not unit then return end
    local name = UnitName(unit)
    if ns.Secret.IsSecret(name) or not name then return end
    if not pingText then pingText = band():CreateFontString(nil, "OVERLAY", "GameFontHighlight") end
    Skin:Text(pingText, "small", "accent.secondary", 11, "OUTLINE")
    pingText:ClearAllPoints()
    pingText:SetPoint("TOP", band(), "TOP", 0, -6)
    local _, classFile = UnitClass(unit)
    if not ns.Secret.IsSecret(classFile) and classFile then pingText:SetTextColor(ns.Util.ClassColor(classFile)) end
    pingText:SetText(name)
    pingText:Show()
    if pingTimer then pingTimer:Cancel() end
    pingTimer = C_Timer.NewTimer(3, function() pingTimer = nil; pingText:Hide() end)
end
M.OnPing = onPing

---------------------------------------------------------------- world map coordinates
local mapCoords
local function updateMapCoords()
    local map = WorldMapFrame
    if not (mapCoords and map and map:IsShown()) then return end
    local text = ""
    local mapID = map.GetMapID and map:GetMapID()
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local d = M.db.coordDecimals
    if pos then
        local x, y = pos:GetXY()
        if not ns.Secret.IsSecret(x) and x and y and not (x == 0 and y == 0) then
            text = L.MINIMAP_MAP_PLAYER:format(M.FormatCoords(x, y, d))
        end
    end
    if map.ScrollContainer and map.ScrollContainer:IsMouseOver() and map.GetNormalizedCursorPosition then
        local cx, cy = map:GetNormalizedCursorPosition()
        if cx and cy and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
            text = text .. "     " .. L.MINIMAP_MAP_CURSOR:format(M.FormatCoords(cx, cy, d))
        end
    end
    mapCoords.text:SetText(text)
end

local function setupMapCoords()
    local map = WorldMapFrame
    if not (map and map.ScrollContainer) then return end
    if not mapCoords then
        mapCoords = CreateFrame("Frame", nil, map.ScrollContainer)
        mapCoords:SetSize(320, 18)
        mapCoords:SetPoint("BOTTOM", map.ScrollContainer, "BOTTOM", 0, 6)
        mapCoords:SetFrameLevel(map.ScrollContainer:GetFrameLevel() + 20)
        mapCoords.text = mapCoords:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        mapCoords.text:SetPoint("CENTER")
        local elapsed = 0
        mapCoords:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed > 0.1 then elapsed = 0; updateMapCoords() end
        end)
    end
    Skin:Text(mapCoords.text, "number", "text.primary", 12, "OUTLINE")
    mapCoords:SetShown(M:IsEnabled() and M.db.worldMapCoords and ns:Supports("worldMapCoords"))
end

---------------------------------------------------------------- world map scale (windowed map only)
-- The windowed world map takes this scale; the maximized (full screen) map stays the game's. Out of combat.
local mapScaled = false
local function applyMapScale()
    local map = WorldMapFrame
    if not (map and map.SetScale) then return end
    local want = (M:IsEnabled() and ns:Supports("worldMapCoords")) and (tonumber(M.db.worldMapScale) or 1) or 1
    if map.IsMaximized and map:IsMaximized() then want = 1 end
    if want == 1 and not mapScaled then return end
    mapScaled = want ~= 1
    ns.Combat:Run("minimap.mapScale", map.SetScale, map, want)
end
M.ApplyMapScale = applyMapScale

local mapHooked = false
local function hookMapScale()
    if mapHooked or not WorldMapFrame then return end
    mapHooked = true
    WorldMapFrame:HookScript("OnShow", applyMapScale)
    EventRegistry:RegisterCallback("WorldMapMinimized", applyMapScale, M)
    EventRegistry:RegisterCallback("WorldMapMaximized", applyMapScale, M)
end

---------------------------------------------------------------- button bin
local PAD = 8
local bin -- { toggle, flyout, buttons = { [button] = name }, list = { button } }
local placing -- recursion guard for the SetPoint hook

local function libIcon() return LibStub and LibStub("LibDBIcon-1.0", true) end

local function layoutBin()
    if not bin then return end
    local cols = math.max(1, M.db.binColumns or 4)
    local size = math.max(16, M.db.binSize or 28)
    local cell = size + 4
    local ignore = M.ParseIgnore(M.db.binIgnore)
    local shown = {}
    local lib = libIcon()
    placing = true
    for _, b in ipairs(bin.list) do
        local name = bin.buttons[b]
        if ignore[name:lower()] then
            -- an ignored button goes back to the minimap edge, where LibDBIcon places it
            if b:GetParent() == bin.flyout then
                b:SetParent(Minimap)
                b:SetScale(1)
                if lib and lib.Refresh then pcall(lib.Refresh, lib, name) end
            end
        elseif not (b.db and b.db.hide) then
            shown[#shown + 1] = b
        end
    end
    table.sort(shown, function(a, b) return bin.buttons[a] < bin.buttons[b] end)
    for i, b in ipairs(shown) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local scale = ns.Util.SafeScale(size / math.max(1, b:GetWidth() or 31))
        b:SetParent(bin.flyout)
        b:SetScale(scale)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bin.flyout, "TOPLEFT", (PAD + col * cell) / scale, (-PAD - row * cell) / scale)
        b:SetFrameLevel(bin.flyout:GetFrameLevel() + 2)
        b:SetAlpha(1)
    end
    placing = nil
    local rows = math.max(1, math.ceil(#shown / cols))
    bin.flyout:SetSize(PAD * 2 + math.min(#shown, cols) * cell - 4, PAD * 2 + rows * cell - 4)
    bin.count = #shown
    bin.toggle:SetShown(M.db.bin and #shown > 0)
    bin.toggle:SetAlpha((M.db.binMouseover and not Minimap:IsMouseOver()) and 0 or 1)
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

local BIN_SIZE = 22
local function buildBin()
    bin = { buttons = {}, list = {} }
    local glyph = CreateFrame("Frame", nil, Minimap)
    glyph:SetSize(BIN_SIZE, BIN_SIZE)
    glyph:SetPoint("TOPRIGHT", band(), "TOPRIGHT", -4, -4)
    glyph:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    Skin:Register(glyph, function(self) Skin:Panel(self, "raised", { border = "border.default" }) end)
    glyph:Hide()
    local t = W:IconButton(glyph, "bin", BIN_SIZE, L.MINIMAP_BIN, L.MINIMAP_BIN_TIP)
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
    -- "only on mouse-over": the glyph shows while the pointer is over the map, the glyph or the open bin
    local function hover()
        if not M.db.binMouseover then glyph:SetAlpha(1); return end
        glyph:SetAlpha((Minimap:IsMouseOver() or glyph:IsMouseOver() or f:IsShown()) and 1 or 0)
    end
    Minimap:HookScript("OnEnter", hover)
    Minimap:HookScript("OnLeave", function() C_Timer.After(0.2, hover) end)
    t:HookScript("OnLeave", function() C_Timer.After(0.2, hover) end)
    f:HookScript("OnHide", hover)
    bin.toggle, bin.flyout, bin.hover = glyph, f, hover
end

---------------------------------------------------------------- lifecycle
local function onAddOn(_, name)
    if name == "Blizzard_HybridMinimap" then hybridMask()
    elseif name == "Blizzard_TimeManager" then styleClock()
    elseif name == "Blizzard_WorldMap" then setupMapCoords(); hookMapScale(); applyMapScale(); M:SetupZoneLevels() end
    if M.db.bin then scanSoon() end
end

function M:OnEnable()
    applyShape(self) -- 2.0 builds saved a plain "square" switch; Migrations step 5 turns it into `shape`
    Skin:Register(MinimapZoneText, styleZone)
    if not self.hooked then
        self.hooked = true
        Minimap:HookScript("OnShow", function() if M:IsEnabled() then setupCoords(M) end end)
        Minimap:HookScript("OnHide", function() if ticker then ticker:Cancel(); ticker = nil end end)
        Minimap:HookScript("OnSizeChanged", function() if M:IsEnabled() then styleBorder() end end)
        if Minimap_Update then hooksecurefunc("Minimap_Update", styleZone) end
    end
    if self.db.bin then
        if not bin then buildBin() end
        scan()
    end
    ns.Events:On("PLAYER_ENTERING_WORLD", self, function() if M.db.bin then scanSoon() end; M:ApplyElements() end)
    ns.Events:On("ADDON_LOADED", self, onAddOn)
    ns.Events:On("MINIMAP_UPDATE_ZOOM", self, scheduleZoomOut)
    self:Refresh()
end

function M:Refresh()
    Minimap:EnableMouseWheel(self.db.wheelZoom)
    styleBorder()
    setupCoords(self)
    styleZone()
    styleClock()
    setupMapCoords()
    hookMapScale()
    applyMapScale()
    self:SetupZoneLevels() -- ZoneLevels.lua
    self:DrawZoneLevels()
    self:ApplyElements()
    scheduleZoomOut()
    if bin then layoutBin() end
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
    if mapCoords then mapCoords:Hide() end
    applyMapScale()
    for frame in pairs(tucked) do tuck(frame, true) end
    Minimap:EnableMouseWheel(true)
end
