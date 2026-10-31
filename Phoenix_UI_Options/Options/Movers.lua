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
    { type = "preview", kind = "movers" },
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
-- Any frame (MoveAny level): type a name or click a frame, then it is a Layout mode entry like the ones above.
local anyName, anyPicked = "", nil
local function rebuild() if ns.Config.RebuildPage then ns.Config:RebuildPage("Movers") end end
local function anyAdd(m, name)
    local ok, why = m:AddAnyFrame(name)
    if ok then anyPicked, anyName = ok, ""; rebuild() else ns:Print(L[why]) end
end
local function ANY(m)
    local out = {}
    for _, n in ipairs(m.db.any or {}) do out[#out + 1] = { value = n, label = n } end
    return out
end
schema[#schema + 1] = { type = "header", label = "MOVERS_ANY", icon = "search" }
schema[#schema + 1] = { type = "description", text = "MOVERS_ANY_TEXT" }
schema[#schema + 1] = { type = "button", label = "MOVERS_ANY_PICK", desc = "MOVERS_ANY_PICK_DESC", button = "MOVERS_ANY_PICK_BUTTON",
    icon = "search", combat = true, keywords = "moveany any frame pick click choose",
    func = function(m)
        ns.Config.frame:Hide()
        m:PickFrame(function(name)
            if name then anyAdd(m, name) else ns:Print(L.MOVERS_ANY_NONE) end
            ns.Config.frame:Show()
        end)
    end }
schema[#schema + 1] = { type = "input", label = "MOVERS_ANY_NAME", desc = "MOVERS_ANY_NAME_DESC", keywords = "moveany frame name",
    get = function() return anyName end, set = function(_, v) anyName = v or "" end }
schema[#schema + 1] = { type = "button", label = "MOVERS_ANY_ADD", desc = "MOVERS_ANY_ADD_DESC", button = "MOVERS_ANY_ADD", icon = "add",
    combat = true, func = function(m) anyAdd(m, anyName) end }
schema[#schema + 1] = { type = "select", label = "MOVERS_ANY_LIST", desc = "MOVERS_ANY_LIST_DESC", values = ANY,
    hidden = function(m) return #(m.db.any or {}) == 0 end,
    get = function(m) return anyPicked or (m.db.any or {})[1] end, set = function(_, v) anyPicked = v end }
schema[#schema + 1] = { type = "button", label = "MOVERS_ANY_REMOVE", desc = "MOVERS_ANY_REMOVE_DESC", button = "DELETE", icon = "delete",
    hidden = function(m) return #(m.db.any or {}) == 0 end,
    func = function(m)
        local n = anyPicked or (m.db.any or {})[1]
        if n and m:RemoveAnyFrame(n) then anyPicked = nil; rebuild() end
    end }
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
