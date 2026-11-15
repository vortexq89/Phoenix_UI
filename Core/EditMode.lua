local _, ns = ...

--[[ ns.EditMode — puts Phoenix-owned frames into Phoenix's Layout mode (Movers). They were also in Blizzard Edit
    Mode via LibEditMode until specs/005 made Layout the one way to move them; LibEditMode is still used for the
    active Edit Mode layout name, so saved spots follow Blizzard's layout switch as before (review 28: the encounter bars and
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
    -- Layout only (specs/005, owner t227): Phoenix frames are no longer added to Blizzard Edit Mode, so each frame
    -- has one way to move. Saved spots stay where they were (per Edit Mode layout name, read by apply()).
    local movers = ns.GetModule and ns:GetModule("Movers")
    if movers and movers.Register then
        movers:Register("em." .. opts.key, frame, moverLabel(opts.name), moverStore(entry, opts))
        local e = movers.GetEntry and movers:GetEntry("em." .. opts.key)
        if e then e.noScale, e.noAlpha = opts.noScale, opts.noAlpha end
    end
    apply(entry)
end

-- Layout with this Phoenix frame selected (the frames are in Layout as "em.<key>").
function EM:Focus(key)
    local movers = ns.GetModule and ns:GetModule("Movers")
    if movers and movers.Focus then return movers:Focus("em." .. key) end
    self:Open()
end

function EM:Open()
    ns.Combat:Run("editmode.open", function()
        if EditModeManagerFrame and not EditModeManagerFrame:IsShown() then ShowUIPanel(EditModeManagerFrame) end
    end)
end

-- Layout profiles (specs/005 T008): Phoenix frame spots are kept per Blizzard Edit Mode layout, so switching
-- layouts there switches them here. These let the Layout page show the set in use and copy one set to another.
function EM:ActiveLayout() return LEM:GetActiveLayoutName() or "Default" end

function EM:Layouts()
    local out, active = {}, self:ActiveLayout()
    for name, set in pairs(ns.DB.sv.global.layouts or {}) do
        if name ~= active and type(set) == "table" and next(set) then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function EM:CopyLayout(from)
    local src = (ns.DB.sv.global.layouts or {})[from]
    if type(src) ~= "table" or from == self:ActiveLayout() then return false end
    local dst = store()
    for key, pos in pairs(src) do
        local copy = {}
        for k, v in pairs(pos) do copy[k] = v end
        dst[key] = copy
    end
    for _, entry in pairs(registered) do ns.SafeCall(apply, entry) end
    return true
end

LEM:RegisterCallback("layout", function(layoutName)
    for _, entry in pairs(registered) do ns.SafeCall(apply, entry, layoutName) end
end)
