local _, ns = ...
local L = ns.L
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

ns:RegisterOptions("Minimap", {
    { type = "preview", kind = "minimap" },
    { type = "header", label = "MINIMAP_SHAPE", icon = "minimap" },
    { type = "toggle", key = "square", label = "MINIMAP_SQUARE", desc = "MINIMAP_SQUARE_DESC", reload = true },
    { type = "custom", label = "MINIMAP_SIZE", desc = "MINIMAP_SIZE_DESC", get = function() return true end,
      keywords = "scale bigger smaller zoom", build = sizeRow },
    { type = "toggle", key = "zoneText", label = "MINIMAP_ZONE_TEXT", desc = "MINIMAP_ZONE_TEXT_DESC", reload = true },
    { type = "header", label = "MINIMAP_INFO", icon = "clock" },
    { type = "toggle", key = "coords", label = "MINIMAP_COORDS", desc = "MINIMAP_COORDS_DESC", keywords = "coordinates position" },
    { type = "header", label = "MINIMAP_BIN", icon = "bin" },
    { type = "toggle", key = "bin", label = "MINIMAP_BIN_ENABLE", desc = "MINIMAP_BIN_DESC", reload = true,
      keywords = "addon buttons libdbicon collect hide clutter" },
    { type = "range", key = "binColumns", label = "MINIMAP_BIN_COLUMNS", desc = "MINIMAP_BIN_COLUMNS_DESC", min = 1, max = 8, step = 1,
      disabled = function(m) return not m.db.bin end },
    { type = "button", label = "MINIMAP_BIN_OPEN", desc = "MINIMAP_BIN_OPEN_DESC", button = "MINIMAP_BIN_SHOW", icon = "bin",
      disabled = function(m) return not (m.db.bin and m:BinCount() > 0) end,
      func = function(m) m:OpenBin() end },
})
