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
        elseif m.IsHidden(e) then
            self.badge:Set(L.MOVERS_HIDDEN, "state.warning")
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

-- A scale per Blizzard window (MoveAny level): pick the window, then its own scale; Reset follows the shared one.
local WINDOWS = {}
for _, name in ipairs(ns:GetModule("Movers").WINDOWS) do
    WINDOWS[#WINDOWS + 1] = { value = name, label = L["MOVERS_WIN_" .. name:upper()] }
end
local pickedWindow = WINDOWS[1].value

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
    -- drag and place Blizzard windows (saved by Skins: module = "Skins", so no saved setting moved; specs/005 T002)
    { type = "toggle", key = "moveWindows", module = "Skins", label = "SKINS_MOVE_WINDOWS", desc = "SKINS_MOVE_WINDOWS_DESC",
      keywords = "move drag reposition blizzard windows shifter" },
    { type = "button", label = "SKINS_MOVE_RESET", desc = "SKINS_MOVE_RESET_DESC", button = "SKINS_MOVE_RESET_BUTTON", icon = "reset",
      func = function() local sk = ns.modules.Skins; if sk and sk.ResetWindows then sk:ResetWindows() end end },
    { type = "range", key = "windowScale", label = "MOVERS_WINDOW_SCALE", desc = "MOVERS_WINDOW_SCALE_DESC", min = 0.6, max = 1.5,
      step = 0.05, percent = true, combat = true, keywords = "scale blizzard windows character bags collections size" },
    { type = "select", label = "MOVERS_WINDOW_PICK", desc = "MOVERS_WINDOW_PICK_DESC", values = WINDOWS,
      keywords = "scale window each own per window", get = function() return pickedWindow end,
      set = function(_, v) pickedWindow = v end },
    { type = "range", label = "MOVERS_WINDOW_OWN", desc = "MOVERS_WINDOW_OWN_DESC", min = 0.6, max = 1.5, step = 0.05,
      percent = true, combat = true, keywords = "scale window each own per window",
      get = function(m) return m.WindowScaleOf(pickedWindow) end,
      set = function(m, v) m:SetWindowScale(pickedWindow, v) end },
    { type = "button", label = "MOVERS_WINDOW_OWN_RESET", desc = "MOVERS_WINDOW_OWN_RESET_DESC", button = "RESET", icon = "reset",
      combat = true, disabled = function(m) return not (m.db.windowScales or {})[pickedWindow] end,
      func = function(m) m:SetWindowScale(pickedWindow, nil); if ns.Config.RebuildPage then ns.Config:RebuildPage("Movers") end end },
    { type = "header", label = "MOVERS_FRAMES", icon = "editmode" },
}
for _, e in ipairs(ns:GetModule("Movers").BLIZZARD) do
    schema[#schema + 1] = { type = "custom", label = e.label, get = function() return true end,
        build = function(row, m) return frameRow(row, m, e.key) end }
end
schema[#schema + 1] = { type = "custom", label = "BUGS_INDICATOR", get = function() return true end,
    build = function(row, m) return frameRow(row, m, "BugIndicator") end }
-- Find a frame (specs/005 T007): every Layout entry in one searchable list, grouped Phoenix / Blizzard / added.
local found
local function entryLabel(e)
    local t = e.text or (e.label and L[e.label]) or e.key
    return type(t) == "string" and t or tostring(e.key)
end
local function FRAMES(m)
    local groups = { L.MOVERS_GROUP_PHOENIX, L.MOVERS_GROUP_BLIZZARD, L.MOVERS_GROUP_ADDED }
    local lists = { {}, {}, {} }
    for _, e in ipairs(m:GetEntries()) do
        local i = e.owned and 1 or e.any and 3 or 2
        lists[i][#lists[i] + 1] = { value = e.key, label = entryLabel(e), group = groups[i] }
    end
    local out = {}
    for _, list in ipairs(lists) do
        table.sort(list, function(a, b) return a.label < b.label end)
        for _, it in ipairs(list) do out[#out + 1] = it end
    end
    return out
end
schema[#schema + 1] = { type = "header", label = "MOVERS_FIND", icon = "search" }
schema[#schema + 1] = { type = "select", label = "MOVERS_FIND_LIST", desc = "MOVERS_FIND_LIST_DESC", values = FRAMES,
    keywords = "find search frame list layout", get = function(m) return found or (FRAMES(m)[1] or {}).value end,
    set = function(_, v) found = v end }
schema[#schema + 1] = { type = "button", label = "MOVERS_FIND_GO", desc = "MOVERS_FIND_GO_DESC", button = "MOVERS_FIND_GO",
    icon = "movers", combat = true, func = function(m)
        local k = found or (FRAMES(m)[1] or {}).value
        if k then m:Focus(k) end
    end }
-- Layout profiles (specs/005 T008): Phoenix spots per Edit Mode layout, and copying one set into the one in use.
local copyFrom
local function LAYOUTS()
    local out = {}
    for _, n in ipairs(ns.EditMode:Layouts()) do out[#out + 1] = { value = n, label = n } end
    return out
end
local noLayouts = function() return #ns.EditMode:Layouts() == 0 end
schema[#schema + 1] = { type = "header", label = "MOVERS_PROFILES", icon = "profiles" }
schema[#schema + 1] = { type = "description", text = function() return L.MOVERS_PROFILES_TEXT:format(ns.EditMode:ActiveLayout()) end }
schema[#schema + 1] = { type = "select", label = "MOVERS_PROFILES_FROM", desc = "MOVERS_PROFILES_FROM_DESC", values = LAYOUTS,
    hidden = noLayouts, get = function() return copyFrom or ns.EditMode:Layouts()[1] end, set = function(_, v) copyFrom = v end }
schema[#schema + 1] = { type = "button", label = "MOVERS_PROFILES_COPY", desc = "MOVERS_PROFILES_COPY_DESC",
    button = "MOVERS_PROFILES_COPY", icon = "copy", combat = true, hidden = noLayouts, func = function()
        if ns.EditMode:CopyLayout(copyFrom or ns.EditMode:Layouts()[1]) then copyFrom = nil end
    end }
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
