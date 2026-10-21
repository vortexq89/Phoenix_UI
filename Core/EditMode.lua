local _, ns = ...

--[[ ns.EditMode — puts Phoenix-owned frames into Blizzard Edit Mode via LibEditMode.
    Positions are stored per Edit Mode layout in PhoenixUIDB.global.layouts[layout][key].
    Blizzard's own systems are never moved by Phoenix_UI. ]]
local LEM = LibStub("LibEditMode")
local EM = {}
ns.EditMode = EM
local registered = {}

local function store(layoutName)
    local layouts = ns.DB.sv.global.layouts
    layoutName = layoutName or LEM:GetActiveLayoutName() or "Default"
    layouts[layoutName] = layouts[layoutName] or {}
    return layouts[layoutName]
end

local function apply(entry, layoutName)
    local pos = store(layoutName)[entry.key] or entry.default
    local f = entry.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end

-- opts = { key, name, default = { point, x, y }, settings = { LibEditMode SettingObjects } }
function EM:Register(frame, opts)
    if registered[opts.key] then
        registered[opts.key].frame = frame
        apply(registered[opts.key])
        return
    end
    local entry = { key = opts.key, frame = frame, default = opts.default }
    registered[opts.key] = entry
    frame.editModeName = opts.name
    LEM:AddFrame(frame, function(_, layoutName, point, x, y)
        store(layoutName)[opts.key] = { point = point, x = x, y = y }
    end, opts.default, opts.name)
    if opts.settings then LEM:AddFrameSettings(frame, opts.settings) end
    apply(entry)
end

function EM:IsEditing()
    return LEM:IsInEditMode()
end

function EM:Open()
    ns.Combat:Run("editmode.open", function()
        if EditModeManagerFrame and not EditModeManagerFrame:IsShown() then ShowUIPanel(EditModeManagerFrame) end
    end)
end

LEM:RegisterCallback("layout", function(layoutName)
    for _, entry in pairs(registered) do ns.SafeCall(apply, entry, layoutName) end
end)
LEM:RegisterCallback("enter", function() ns.Events:Fire("PUI_EDITMODE", true) end)
LEM:RegisterCallback("exit", function() ns.Events:Fire("PUI_EDITMODE", false) end)
