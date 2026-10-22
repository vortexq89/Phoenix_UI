local _, ns = ...
local L, Opt = ns.L, ns.Opt
local W = ns.Widgets

-- Size lives in Edit Mode (EditModeMinimapSetting.Size, 50-200 %). Writing Edit Mode layouts from an
-- addon only takes effect after Edit Mode reloads them, and touching the system frame would taint it,
-- so this row reports the current size and opens Edit Mode.
local function sizeRow(row, m)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(W.CONTROL_WIDTH, 28)
    holder.open = W:Button(holder, L.OPEN_EDIT_MODE, "secondary", "editmode", 112)
    holder.open:SetPoint("RIGHT")
    holder.open.onClick = function() ns.EditMode:Open() end
    holder.badge = W:Badge(holder, "", "accent.primary")
    holder.badge:SetPoint("RIGHT", holder.open, "LEFT", -10, 0)
    function holder:SetValue()
        local size = m:GetEditModeSize()
        self.badge:Set(size and ("%d%%"):format(size) or "—", "accent.primary")
    end
    EventRegistry:RegisterCallback("EditMode.Exit", function() holder:SetValue() end, holder)
    return holder
end

local function round(m) return m.db.shape == "ROUND" end
local function notRect(m) return m.db.shape ~= "RECTANGLE" end
local function off(key) return function(m) return not m.db[key] end end
local RECTS = {}
for _, pct in ipairs({ 50, 60, 70, 80, 90 }) do RECTS[#RECTS + 1] = { value = pct, label = ("%d%%"):format(pct) } end

ns:RegisterOptions("Minimap", {
    { type = "preview", kind = "minimap" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "MINIMAP_SHAPE", icon = "minimap" },
    { type = "select", key = "shape", label = "MINIMAP_SHAPE_PICK", desc = "MINIMAP_SHAPE_PICK_DESC", reload = true,
      keywords = "square round circle rectangle", values = {
        { value = "ROUND", label = "MINIMAP_SHAPE_ROUND" }, { value = "SQUARE", label = "MINIMAP_SHAPE_SQUARE" },
        { value = "RECTANGLE", label = "MINIMAP_SHAPE_RECTANGLE" },
    } },
    { type = "select", key = "rectHeight", label = "MINIMAP_RECT_HEIGHT", desc = "MINIMAP_RECT_HEIGHT_DESC", values = RECTS,
      disabled = notRect, keywords = "rectangle band height crop" },
    { type = "custom", label = "MINIMAP_SIZE", desc = "MINIMAP_SIZE_DESC", get = function() return true end,
      keywords = "scale bigger smaller zoom", build = sizeRow },
    Opt.With(Opt.Border("border", "MINIMAP_BORDER", "border.black"), { disabled = round }),
    { type = "header", label = "MINIMAP_TEXTS", icon = "fonts" },
    { type = "toggle", key = "zoneText", label = "MINIMAP_ZONE_TEXT", desc = "MINIMAP_ZONE_TEXT_DESC",
      keywords = "zone name header" },
    Opt.Text("zone", "MINIMAP_ZONE_FONT", { max = 20, token = "accent.primary", row = { disabled = off("zoneText") } }),
    { type = "toggle", key = "zonePvP", label = "MINIMAP_ZONE_PVP", desc = "MINIMAP_ZONE_PVP_DESC",
      disabled = off("zoneText"), keywords = "sanctuary contested hostile friendly colour color" },
    { type = "toggle", key = "clock", label = "MINIMAP_CLOCK", desc = "MINIMAP_CLOCK_DESC", keywords = "time" },
    Opt.Text("clockText", "MINIMAP_CLOCK_FONT", { max = 20, row = { disabled = off("clock") } }),
    { type = "toggle", key = "coords", label = "MINIMAP_COORDS", desc = "MINIMAP_COORDS_DESC", keywords = "coordinates position" },
    { type = "select", key = "coordDecimals", label = "MINIMAP_COORD_DECIMALS", desc = "MINIMAP_COORD_DECIMALS_DESC",
      disabled = off("coords"), values = {
        { value = 0, label = "48  62" }, { value = 1, label = "48.2  61.7" }, { value = 2, label = "48.23  61.70" },
    } },
    Opt.Text("coordsText", "MINIMAP_COORDS_FONT", { max = 20, place = true, row = { disabled = off("coords") } }),
    { type = "tab", label = "MINIMAP_TAB_BUTTONS" },
    { type = "header", label = "MINIMAP_BUTTONS", icon = "minimap" },
    { type = "toggle", key = "calendar", label = "MINIMAP_CALENDAR", desc = "MINIMAP_CALENDAR_DESC",
      keywords = "calendar invites events" },
    { type = "toggle", key = "tracking", label = "MINIMAP_TRACKING", desc = "MINIMAP_TRACKING_DESC",
      keywords = "tracking herbs ore" },
    { type = "toggle", key = "mail", label = "MINIMAP_MAIL", desc = "MINIMAP_MAIL_DESC",
      keywords = "mail letter" },
    { type = "toggle", key = "craftingOrder", label = "MINIMAP_CRAFTING", desc = "MINIMAP_CRAFTING_DESC",
      feature = "craftingOrders", keywords = "crafting orders profession" },
    { type = "toggle", key = "difficulty", label = "MINIMAP_DIFFICULTY", desc = "MINIMAP_DIFFICULTY_DESC",
      keywords = "instance difficulty heroic mythic badge" },
    { type = "toggle", key = "expansion", label = "MINIMAP_EXPANSION", desc = "MINIMAP_EXPANSION_DESC",
      keywords = "expansion landing page housing renown" },
    { type = "toggle", key = "compartment", label = "MINIMAP_COMPARTMENT", desc = "MINIMAP_COMPARTMENT_DESC",
      keywords = "addon compartment list" },
    { type = "header", label = "MINIMAP_ZOOM", icon = "search" },
    { type = "toggle", key = "wheelZoom", label = "MINIMAP_WHEEL", desc = "MINIMAP_WHEEL_DESC", keywords = "mouse wheel scroll zoom" },
    { type = "toggle", key = "zoomButtons", label = "MINIMAP_ZOOM_BUTTONS", desc = "MINIMAP_ZOOM_BUTTONS_DESC",
      keywords = "plus minus zoom" },
    { type = "range", key = "autoZoom", label = "MINIMAP_AUTO_ZOOM", desc = "MINIMAP_AUTO_ZOOM_DESC", min = 0, max = 60, step = 5,
      keywords = "zoom out reset seconds" },
    { type = "header", label = "MINIMAP_BIN", icon = "bin" },
    { type = "toggle", key = "bin", label = "MINIMAP_BIN_ENABLE", desc = "MINIMAP_BIN_DESC", reload = true,
      keywords = "addon buttons libdbicon collect hide clutter" },
    { type = "range", key = "binColumns", label = "MINIMAP_BIN_COLUMNS", desc = "MINIMAP_BIN_COLUMNS_DESC", min = 1, max = 8, step = 1,
      disabled = off("bin") },
    { type = "range", key = "binSize", label = "MINIMAP_BIN_SIZE", desc = "MINIMAP_BIN_SIZE_DESC", min = 18, max = 40, step = 1,
      disabled = off("bin") },
    { type = "input", key = "binIgnore", label = "MINIMAP_BIN_IGNORE", desc = "MINIMAP_BIN_IGNORE_DESC", disabled = off("bin"),
      keywords = "exclude keep on minimap" },
    { type = "toggle", key = "binMouseover", label = "MINIMAP_BIN_MOUSEOVER", desc = "MINIMAP_BIN_MOUSEOVER_DESC",
      disabled = off("bin") },
    { type = "button", label = "MINIMAP_BIN_OPEN", desc = "MINIMAP_BIN_OPEN_DESC", button = "MINIMAP_BIN_SHOW", icon = "bin",
      disabled = function(m) return not (m.db.bin and m:BinCount() > 0) end,
      func = function(m) m:OpenBin() end },
    { type = "header", label = "MINIMAP_EXTRAS", icon = "maps" },
    { type = "toggle", key = "pingNames", label = "MINIMAP_PING_NAMES", desc = "MINIMAP_PING_NAMES_DESC", keywords = "ping who" },
    { type = "toggle", key = "worldMapCoords", label = "MINIMAP_MAP_COORDS", desc = "MINIMAP_MAP_COORDS_DESC",
      feature = "worldMapCoords", keywords = "world map cursor coordinates" },
    { type = "range", key = "worldMapScale", label = "MINIMAP_MAP_SCALE", desc = "MINIMAP_MAP_SCALE_DESC", min = 0.5, max = 1.5,
      step = 0.05, percent = true, feature = "worldMapCoords", keywords = "world map scale size smaller bigger" },
})
