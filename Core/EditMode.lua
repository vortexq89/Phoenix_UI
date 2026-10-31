local _, ns = ...

--[[ ns.EditMode — puts Phoenix-owned frames into Blizzard Edit Mode via LibEditMode, and into Phoenix's own
    Layout mode (Movers) with the same saved place, so either mode moves them (review 28: the encounter bars and
    warnings, M+ timer, spell history, XP bar and data text panels were only in Edit Mode).
    Positions are stored per Edit Mode layout in PhoenixUIDB.global.layouts[layout][key]; a place set in Layout
    mode also carries the frame's scale and opacity. Blizzard's own systems are never moved by Phoenix_UI. ]]
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
    local scale = tonumber(pos.scale) or 1
    if pos.scale then f:SetScale(ns.Util.SafeScale(scale)) end
    if pos.alpha then f:SetAlpha(pos.alpha) end
    -- Layout mode saves offsets in UIParent units (pos.ui); LibEditMode in the frame's own
    local k = pos.ui and scale or 1
    f:ClearAllPoints()
    f:SetPoint(pos.point, UIParent, pos.point, pos.x / k, pos.y / k)
end

-- The same place as a Layout mode store (Modules/Movers/Movers.lua `saved` / `apply`).
local function moverStore(entry, opts)
    return {
        active = opts.active,
        preview = opts.preview,
        get = function()
            local p = store()[entry.key] or entry.default
            local k = p.ui and 1 or (tonumber(p.scale) or 1)
            return { point = p.point, x = p.x * k, y = p.y * k, scale = p.scale, alpha = p.alpha }
        end,
        set = function(v)
            local p = store()[entry.key] or entry.default
            store()[entry.key] = { point = v.point or p.point, x = v.x or p.x, y = v.y or p.y, ui = true,
                scale = v.scale or p.scale, alpha = v.alpha or p.alpha }
        end,
        apply = function() apply(entry) end,
        reset = function()
            local old = store()[entry.key]
            store()[entry.key] = nil
            if old and old.scale then entry.frame:SetScale(1) end
            if old and old.alpha then entry.frame:SetAlpha(1) end
            apply(entry)
        end,
    }
end

local function moverLabel(name)
    local prefix = (ns.title or "") .. " – "
    if type(name) == "string" and name:sub(1, #prefix) == prefix then return name:sub(#prefix + 1) end
    return name
end

-- opts = { key, name, default = { point, x, y }, settings = { LibEditMode SettingObjects },
--         active() (Layout mode: false = no box), preview(unlocked) (Layout mode: show a sample while unlocked),
--         noScale / noAlpha (the frame has its own scale / opacity setting, so Layout mode leaves them alone) }
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
    local movers = ns.GetModule and ns:GetModule("Movers")
    if movers and movers.Register then
        movers:Register("em." .. opts.key, frame, moverLabel(opts.name), moverStore(entry, opts))
        local e = movers.GetEntry and movers:GetEntry("em." .. opts.key)
        if e then e.noScale, e.noAlpha = opts.noScale, opts.noAlpha end
    end
    apply(entry)
end

function EM:Open()
    ns.Combat:Run("editmode.open", function()
        if EditModeManagerFrame and not EditModeManagerFrame:IsShown() then ShowUIPanel(EditModeManagerFrame) end
    end)
end

LEM:RegisterCallback("layout", function(layoutName)
    for _, entry in pairs(registered) do ns.SafeCall(apply, entry, layoutName) end
end)
