local _, ns = ...
local Style, Secret = ns.Style, ns.Secret

--[[ GroupFrames v2 (plan v2 S11): party, raid, main tank / assist and pet frames.

    mode "phoenix"   Phoenix-owned secure group headers (SecureGroupHeaderTemplate and its party / raid / pet
                     variants, loaded on retail and WoW Forever alike) make SecureUnitButtonTemplate buttons; each
                     button is dressed by Unit Frames' own build code (UnitFrames:Build with opts.frame), so bars,
                     absorbs, heal prediction, tags, indicators, aura buttons and range fade are the S8 code, read
                     through UnitFrames.UNIT_SOURCES ("group.party" …). Group-only parts (dispel highlight, private
                     aura anchors, HoT corners, debuff row, big defensive, phase, role-based power bar) are here.
    mode "blizzard"  Blizzard's CompactUnitFrames, dressed by the 2.0 skin (Blizzard.lua).

    Three layout profiles: party (up to 5), raid (6-20, also Mythic) and large (21-40). The raid headers switch
    between the raid and large profiles out of combat only (size, place and header attributes are protected); a
    roster change in combat is applied when combat ends. Header attributes (growth, spacing, sorting, filters)
    are computed by pure helpers below and set through ns.Combat:Run.

    Files: GroupFrames.lua (saved shape, profiles, pure layout helpers, lifecycle), Headers.lua (secure headers,
    button set-up, Blizzard parking, movers, events), Update.lua (group parts on each button, samples, Test frames
    and the options preview), Blizzard.lua (the 2.0 skin). ]]

local UF = ns.modules.UnitFrames

-- One layout profile: a unit-frame settings table (UnitFrames' own shape) plus the group layout.
local function profile(o)
    local p = UF.NewUnitSettings({ w = o.w, h = o.h, point = "TOPLEFT", x = o.x, y = o.y, text = o.text or 11,
        power = "always", ph = o.ph or 4, range = true, role = true, threat = true, leader = true,
        nameTag = "[name]", healthTag = "[status]", nameLength = o.nameLength or 10, color = "class" })
    p.background = Style.Background({ alpha = 0.85 })
    p.name.anchor, p.name.y = "CENTER", 5
    p.health.anchor, p.health.y = "CENTER", -7
    p.power.show = false
    p.info.show = false
    p.icons.markerAnchor, p.icons.markerSize, p.icons.size = "TOP", 14, 12
    p.auras.max, p.auras.size = 3, 16
    p.tooltip = "ooc"
    -- layout (the unit settings' spacing / growth are the unit spacing and growth)
    p.spacing, p.growth = o.spacing or 3, o.growth or "DOWN"
    p.groupGrowth, p.groupSpacing = o.groupGrowth or "RIGHT", o.groupSpacing or 6
    p.sortBy, p.sortDir = o.sortBy or "group", "ASC"
    p.roleOrder = "TANK,HEALER,DAMAGER"
    p.showPlayer, p.showSolo = true, false
    p.groups, p.perColumn, p.mythicGroups = 8, 5, true
    p.roleCombat = false
    p.powerRoles = { TANK = true, HEALER = true, DAMAGER = o.dpsPower or false }
    p.dispel = { mode = "border", mine = false, size = 2, alpha = 0.3 }
    p.icons.phase = true
    p.groupAuras = {
        buffs = { mode = "corners", filter = "mine", size = o.buffSize or 12, max = 3 },
        debuffs = { mode = "row", filter = "all", size = o.debuffSize or 16, max = o.debuffMax or 3 },
        defensive = { enabled = true, size = o.defSize or 18 },
        private = { enabled = true, size = o.privSize or 18, max = 2, countdown = true, numbers = false },
    }
    return p
end

local DEFAULTS = {
    mode = "phoenix",
    profiles = {
        party = profile({ w = 120, h = 50, x = 24, y = -300, text = 12, sortBy = "role", spacing = 4, nameLength = 12,
                          buffSize = 14, debuffSize = 18, defSize = 22, privSize = 20 }),
        raid = profile({ w = 92, h = 46, x = 24, y = -260 }),
        large = profile({ w = 72, h = 36, x = 24, y = -260, text = 10, ph = 3, spacing = 2, groupSpacing = 4, nameLength = 7,
                          buffSize = 10, debuffSize = 13, debuffMax = 2, defSize = 15, privSize = 14 }),
    },
    -- main tank / main assist and pets: their own size and place, drawn with the active profile's look
    tanks = { enabled = true, assist = true, width = 110, height = 40, point = "TOPLEFT", x = 24, y = -120, spacing = 3,
              growth = "DOWN", scale = 1 },
    pets = { enabled = false, width = 80, height = 22, point = "TOPLEFT", x = 24, y = -600, spacing = 2, growth = "RIGHT",
             scale = 1 },
    -- raid marker bar (Markers.lua): off by default
    markers = { show = false, where = "group", target = true, world = true, extras = true, vertical = false,
                size = 22, spacing = 3, point = "TOP", x = 0, y = -14 },
    -- Phoenix click casting (ClickCast.lua): off by default; Blizzard's Click Casting and Clique keep working
    clickCast = {
        enabled = false,
        bindings = {
            { mod = "", button = 1, action = "none", text = "" },
            { mod = "", button = 2, action = "none", text = "" },
            { mod = "", button = 3, action = "none", text = "" },
            { mod = "shift", button = 1, action = "none", text = "" },
            { mod = "shift", button = 2, action = "none", text = "" },
            { mod = "shift", button = 3, action = "none", text = "" },
        },
    },
    hideManager = false,          -- Blizzard's raid manager (ready check, markers) stays unless asked
    testSize = 20,
    -- the 2.0 keys (Blizzard mode, Blizzard.lua)
    texture = true, fonts = true,
    bar = "",                                       -- "" = the theme's bar texture
    border = Style.Border(),
    background = Style.Background({ alpha = 0 }),
    name = Style.Text(11),
    status = Style.Text(10),
}

local M = ns:NewModule("GroupFrames", {
    label = "GROUPFRAMES", desc = "GROUPFRAMES_DESC", category = "interface", order = 30, reloadOnToggle = true,
    defaults = DEFAULTS,
})
M.DEFAULTS = DEFAULTS
M.PROFILES = { "party", "raid", "large" }
M.SIZE_OF = { party = 5, raid = 20, large = 40 }

local function plain(v) return not Secret.IsSecret(v) end
M.plain = plain

function M:IsPhoenix() return self.db.mode == "phoenix" end
function M:Profile(key) return self.db.profiles[key] or self.db.profiles.party end

---------------------------------------------------------------- settings sources (UnitFrames draws with them)
-- The raid headers show the raid or the large profile (M.raidProfile); tanks and pets use it with their own size.
M.raidProfile = "raid"
local function derived(which)
    return setmetatable({}, { __index = function(_, k)
        local own = M.db[which]
        if k == "width" or k == "height" or k == "spacing" or k == "growth" or k == "scale" or k == "point" or k == "x"
            or k == "y" then
            return own[k]
        end
        return M:Profile(M.raidProfile)[k]
    end })
end
local DERIVED = { tanks = derived("tanks"), pets = derived("pets") }
for _, key in ipairs(M.PROFILES) do UF.UNIT_SOURCES["group." .. key] = function() return M:Profile(key) end end
UF.UNIT_SOURCES["group.tanks"] = function() return DERIVED.tanks end
UF.UNIT_SOURCES["group.pets"] = function() return DERIVED.pets end

---------------------------------------------------------------- pure layout helpers
-- unit growth -> header point and offset signs (SecureGroupHeader: x/yOffset are used as given along its axis)
local GROW = { DOWN = { "TOP", 0, -1 }, UP = { "BOTTOM", 0, 1 }, RIGHT = { "LEFT", 1, 0 }, LEFT = { "RIGHT", -1, 0 } }
local VERTICAL = { DOWN = true, UP = true }
M.GROW = GROW

-- The group (column) growth, forced across the unit growth: units down -> groups right unless left is asked.
function M.GroupGrowth(unitGrowth, groupGrowth)
    if VERTICAL[unitGrowth] then
        return (groupGrowth == "LEFT") and "LEFT" or "RIGHT"
    end
    return (groupGrowth == "UP") and "UP" or "DOWN"
end

-- The corner the first button sits in (and the holder anchors the header by).
function M.Corner(unitGrowth, groupGrowth)
    groupGrowth = M.GroupGrowth(unitGrowth, groupGrowth)
    local v = VERTICAL[unitGrowth] and unitGrowth or groupGrowth
    local h = VERTICAL[unitGrowth] and groupGrowth or unitGrowth
    return (v == "UP" and "BOTTOM" or "TOP") .. (h == "LEFT" and "RIGHT" or "LEFT")
end

local CLASS_ORDER = "WARRIOR,DEATHKNIGHT,PALADIN,MONK,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,DEMONHUNTER,EVOKER"
M.CLASS_ORDER = CLASS_ORDER
M.ROLE_ORDERS = { "TANK,HEALER,DAMAGER", "HEALER,TANK,DAMAGER", "TANK,DAMAGER,HEALER", "DAMAGER,HEALER,TANK" }

local function groupFilter(n)
    local t = {}
    for i = 1, math.max(1, math.min(8, n)) do t[i] = tostring(i) end
    return table.concat(t, ",")
end
M.GroupFilter = groupFilter

--[[ Header attributes for profile p. kind: "party" (party header), "raid" (one raid header sorting everyone),
    "group" (raid header i of eight, one group each: `index`). groups: how many raid groups are shown. ]]
function M.HeaderAttributes(p, kind, index, groups)
    local g = GROW[p.growth] or GROW.DOWN
    local gg = M.GroupGrowth(p.growth, p.groupGrowth)
    local col = GROW[gg]
    local a = {
        point = g[1], xOffset = g[2] * p.spacing, yOffset = g[3] * p.spacing,
        sortMethod = "INDEX", sortDir = p.sortDir == "DESC" and "DESC" or "ASC",
        groupBy = nil, groupingOrder = nil, groupFilter = nil, roleFilter = nil,
        unitsPerColumn = nil, maxColumns = 1, columnSpacing = p.groupSpacing, columnAnchorPoint = col[1],
        showParty = false, showRaid = false, showPlayer = true, showSolo = false,
    }
    local by = p.sortBy
    if by == "role" then
        a.groupBy, a.groupingOrder = "ASSIGNEDROLE", p.roleOrder .. ",NONE"
    elseif by == "class" then
        a.groupBy, a.groupingOrder = "CLASS", CLASS_ORDER
    elseif by == "name" then
        a.sortMethod = "NAME"
    end
    if kind == "party" then
        a.showParty, a.showPlayer, a.showSolo = true, p.showPlayer and true or false, p.showSolo and true or false
        if not a.showPlayer then a.showSolo = false end
    elseif kind == "group" then
        a.showRaid = true
        a.groupFilter = tostring(index)
        a.groupBy, a.groupingOrder = nil, nil
        if by == "role" then a.groupBy, a.groupingOrder = "ASSIGNEDROLE", p.roleOrder .. ",NONE" end
        if by == "group" then a.sortMethod = "INDEX" end
    else -- one raid header for every shown group
        a.showRaid = true
        a.groupFilter = groupFilter(groups or 8)
        if by == "group" then a.groupBy, a.groupingOrder = "GROUP", groupFilter(8) end
        local per = math.max(1, math.min(40, p.perColumn or 5))
        a.unitsPerColumn, a.maxColumns = per, math.ceil(40 / per)
    end
    return a
end

-- Whether the raid is laid out as eight group headers (sort by group) or one sorted header.
function M.SplitGroups(p) return p.sortBy == "group" end

-- Offsets (from the corner) of n buttons laid out like the headers would: `per` per column, groups along the
-- group growth. -> { {x, y}, … } with x growing right and y growing up (corner-relative signs applied).
function M.Slots(p, n, per, width, height)
    width, height = width or p.width, height or p.height
    per = math.max(1, per or 5)
    local unit, grp = p.growth, M.GroupGrowth(p.growth, p.groupGrowth)
    local out = {}
    for i = 1, n do
        local k, c = (i - 1) % per, math.floor((i - 1) / per)
        local x, y
        if VERTICAL[unit] then
            y = k * (height + p.spacing)
            x = c * (width + p.groupSpacing)
        else
            x = k * (width + p.spacing)
            y = c * (height + p.groupSpacing)
        end
        if unit == "DOWN" or grp == "DOWN" then y = -y end
        if unit == "LEFT" or grp == "LEFT" then x = -x end
        out[i] = { x, y }
    end
    return out
end

-- The size n buttons take (`per` to a column / row).
function M.GroupSize(p, n, per, width, height)
    width, height = width or p.width, height or p.height
    per = math.max(1, per or 5)
    local along = math.min(n, per)
    local across = math.max(1, math.ceil(n / per))
    local a1 = along * (VERTICAL[p.growth] and height or width) + (along - 1) * p.spacing
    local a2 = across * (VERTICAL[p.growth] and width or height) + (across - 1) * p.groupSpacing
    if VERTICAL[p.growth] then return a2, a1 end
    return a1, a2
end

-- Which raid profile a roster of `count` members uses (raid up to 20, large above).
function M.ProfileFor(inRaid, count)
    if not inRaid then return "party" end
    return (tonumber(count) or 0) > 20 and "large" or "raid"
end

-- How many groups the raid headers show: the profile's count, four in a Mythic raid when asked (retail).
function M.GroupsShown(p, difficultyID)
    local n = p.groups or 8
    if p.mythicGroups and difficultyID == 16 and ns:Supports("mythicRaid") then n = math.min(n, 4) end
    return n
end

-- Whether a unit of `role` gets a power bar (power by role).
function M.PowerFor(p, role)
    local r = p.powerRoles
    if role == "TANK" or role == "HEALER" then return r[role] and true or false end
    return r.DAMAGER and true or false
end

-- Buff / debuff filter words -> aura filter strings (12.x-safe filter flags, no aura data is read)
M.BUFF_FILTERS = { mine = "HELPFUL|PLAYER|RAID_IN_COMBAT", raid = "HELPFUL|RAID", all = "HELPFUL",
    external = "HELPFUL|EXTERNAL_DEFENSIVE" }
M.DEBUFF_FILTERS = { all = "HARMFUL", raid = "HARMFUL|RAID", dispellable = "HARMFUL|RAID_PLAYER_DISPELLABLE",
    cc = "HARMFUL|CROWD_CONTROL" }
function M.DispelFilter(mine) return mine and "HARMFUL|RAID" or "HARMFUL|RAID_PLAYER_DISPELLABLE" end

---------------------------------------------------------------- lifecycle
function M:OnEnable()
    if self:IsPhoenix() then
        self:EnablePhoenix()  -- Headers.lua
    else
        self:EnableBlizzard() -- Blizzard.lua
    end
    self:EnableMarkers() -- Markers.lua
    ns.Events:Listen("PUI_THEME_CHANGED", self, function() M:Refresh() end)
    ns.Events:On("PLAYER_REGEN_DISABLED", self, function() if M.testShown then M:ShowTest(false) end end)
end

function M:OnDisable() self:ShowTest(false) end

function M:Refresh()
    if self:IsPhoenix() then self:RefreshPhoenix(); self:ApplyAllClickCast() else self:RefreshBlizzard() end
    self:EnableMarkers()
    if self.testShown then self:ShowTest(true) end
end

function M:OnSettingChanged() self:Refresh() end

-- Test frames: a fake group of 5, 20 or 40 (db.testSize) where the frames sit (out of combat only).
function M:ShowTest(show, size)
    if show and InCombatLockdown() then return false end
    if size then self.db.testSize = size end
    self.testShown = show and true or nil
    if not self:IsPhoenix() then return true end
    return self:ShowPhoenixTest(show) -- Update.lua
end
