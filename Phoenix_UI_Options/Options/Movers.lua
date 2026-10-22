local _, ns = ...
local L = ns.L
local W = ns.Widgets

-- One row per movable frame: state badge + reset.
local function frameRow(row, m, key)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(W.CONTROL_WIDTH, 28)
    holder.reset = W:Button(holder, L.RESET, "secondary", "reset", 96)
    holder.reset:SetPoint("RIGHT")
    holder.reset.onClick = function() m:ResetFrame(key) end
    holder.badge = W:Badge(holder, "", "text.muted")
    holder.badge:SetPoint("RIGHT", holder.reset, "LEFT", -10, 0)
    function holder:SetValue()
        local e = m:GetEntry(key)
        local f = e and m.Usable(e)
        local moved = m.db.frames[key] ~= nil
        if not f then
            self.badge:Set(L.MOVERS_NOT_LOADED, "text.muted")
        elseif moved then
            self.badge:Set(L.MOVERS_MOVED, "accent.primary")
        else
            self.badge:Set(L.MOVERS_DEFAULT, "state.success")
        end
        W.SetEnabledState(self.reset, moved)
    end
    ns.Events:Listen("PUI_MOVERS", holder, function() holder:SetValue() end)
    return holder
end

local schema = {
    { type = "header", label = "MOVERS_UNLOCK_HEADER", icon = "movers" },
    { type = "description", text = "MOVERS_INTRO" },
    { type = "button", label = "MOVERS_UNLOCK", desc = "MOVERS_UNLOCK_DESC", button = "MOVERS_UNLOCK_BUTTON", icon = "movers",
      variant = "primary", combat = true, disabled = function(m) return not m:IsEnabled() end,
      func = function(m) ns.Config.frame:Hide(); m:SetUnlocked(true) end },
    { type = "toggle", key = "grid", label = "MOVERS_GRID", desc = "MOVERS_GRID_DESC" },
    { type = "range", key = "gridSize", label = "MOVERS_GRID_SIZE", min = 8, max = 128, step = 8 },
    { type = "toggle", key = "snap", label = "MOVERS_SNAP", desc = "MOVERS_SNAP_DESC" },
    { type = "toggle", key = "snapFrames", label = "MOVERS_SNAP_FRAMES", desc = "MOVERS_SNAP_FRAMES_DESC",
      keywords = "snap edges align magnet" },
    { type = "toggle", key = "arrows", label = "MOVERS_ARROWS", desc = "MOVERS_ARROWS_DESC", keywords = "arrow keys nudge pixel" },
    { type = "toggle", key = "coords", label = "MOVERS_COORDS", desc = "MOVERS_COORDS_DESC", keywords = "coordinates position x y" },
    { type = "input", key = "unlockKey", label = "MOVERS_KEY", desc = "MOVERS_KEY_DESC", combat = true,
      keywords = "keybind hotkey shortcut unlock" },
    { type = "header", label = "MOVERS_WINDOWS", icon = "skins" },
    { type = "range", key = "windowScale", label = "MOVERS_WINDOW_SCALE", desc = "MOVERS_WINDOW_SCALE_DESC", min = 0.6, max = 1.5,
      step = 0.05, percent = true, combat = true, keywords = "scale blizzard windows character bags collections size" },
    { type = "header", label = "MOVERS_FRAMES", icon = "editmode" },
}
for _, e in ipairs(ns:GetModule("Movers").BLIZZARD) do
    schema[#schema + 1] = { type = "custom", label = e.label, get = function() return true end,
        build = function(row, m) return frameRow(row, m, e.key) end }
end
schema[#schema + 1] = { type = "custom", label = "BUGS_INDICATOR", get = function() return true end,
    build = function(row, m) return frameRow(row, m, "BugIndicator") end }
local tail = {
    { type = "button", label = "MOVERS_RESET_ALL", desc = "MOVERS_RESET_ALL_DESC", button = "RESET", icon = "reset", variant = "danger",
      func = function(m) m:ResetAll() end },
    { type = "header", label = "MOVERS_EDIT_MODE", icon = "editmode" },
    { type = "description", text = "MOVERS_EDIT_MODE_TEXT" },
    { type = "button", label = "MOVERS_EDIT_MODE_OPEN", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
    { type = "header", label = "MOVERS_EXCLUDED", icon = "lock" },
    { type = "description", text = "MOVERS_EXCLUDED_TEXT" },
}
for _, item in ipairs(tail) do schema[#schema + 1] = item end

ns:RegisterOptions("Movers", schema)
