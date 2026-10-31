local _, ns = ...
local L = ns.L
local M = ns.modules.GroupFrames
local UF = ns.modules.UnitFrames

--[[ Phoenix mode: secure group headers, their buttons, Blizzard's group frames parked, movers and events.

    Headers (all SecureGroupHeaderTemplate / SecureGroupPetHeaderTemplate, Blizzard's own restricted code):
      party        party members and the player outside raids (showParty / showPlayer / showSolo)
      g1 … g8      one per raid group, side by side (sort by group)
      raid         every shown group in one sorted header (sort by role, class, name or index)
      tanks        main tanks and main assists (roleFilter MAINTANK,MAINASSIST)
      pets         party / raid pets (filterOnPet)
    Each header makes SecureUnitButtonTemplate buttons. Their initialConfigFunction (restricted code) sizes them
    from the header's phoenix-width / phoenix-height attributes, sets Blizzard's click conventions
    (*type1 = target, *type2 = togglemenu) and calls the header's PhoenixInit method, where Unit Frames' build code
    dresses the button (UnitFrames:Build with opts.frame) and Clique / click-cast addons get it through the
    ClickCastFrames table; Blizzard's own click bindings work through SecureUnitButton_OnClick. Buttons are made
    ahead of time out of combat (startingIndex), so none is made under lockdown. A button's unit changes with the
    roster (its "unit" attribute): its events follow (UnitFrames.WatchUnit). Every attribute, size and place
    change runs out of combat (ns.Combat:Run). ]]

local headers, holders, buttons = {}, {}, {}
M.headers, M.holders, M.buttons = headers, holders, buttons
local spawned, parking

local TEMPLATE = "SecureUnitButtonTemplate,PingableUnitFrameTemplate"
-- restricted code: `self` is the new button
local INIT = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("phoenix-width") or 80)
    self:SetHeight(header:GetAttribute("phoenix-height") or 40)
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    self:SetAttribute("toggleForVehicle", true)
    header:CallMethod("PhoenixInit", self:GetName())
]]
-- unit events beyond Unit Frames' own (they reach the group parts through f.onUnitEvent)
local EXTRA_EVENTS = { "UNIT_PHASE", "UNIT_OTHER_PARTY_CHANGED", "UNIT_IN_RANGE_UPDATE" }
-- how many buttons each header makes ahead of time
local NEED = { party = 5, raid = 40, tanks = 8, pets = 40 }
for i = 1, 8 do NEED["g" .. i] = 5 end

---------------------------------------------------------------- Blizzard parking
local BLIZZARD = { "PartyFrame", "CompactRaidFrameContainer" }
M.BLIZZARD_FRAMES = BLIZZARD
local function park(name)
    local fr = rawget(_G, name)
    if type(fr) ~= "table" or not fr.SetParent or fr:IsForbidden() then return end
    fr:UnregisterAllEvents()
    fr:Hide()
    fr:SetParent(parking)
end

local function parkBlizzard()
    if not parking then
        parking = CreateFrame("Frame", "PhoenixUI_GroupFrameParking", UIParent)
        parking:Hide()
    end
    for _, name in ipairs(BLIZZARD) do park(name) end
    local cpf = rawget(_G, "CompactPartyFrame")
    if type(cpf) == "table" and cpf.UnregisterAllEvents and not cpf:IsForbidden() then cpf:UnregisterAllEvents() end
    if M.db.hideManager then park("CompactRaidFrameManager") end
end
M.ParkBlizzard = parkBlizzard

---------------------------------------------------------------- buttons
local function onAttribute(b, name, value)
    if name == "unit" then M:SetButtonUnit(b, value) end
end

-- PhoenixInit: a header made button b (restricted code already sized it and set its click attributes).
function M:InitButton(header, b)
    if type(b) ~= "table" or b.dressed then return end
    b.dressed = true
    UF:Build(nil, header.unitKey, { frame = b })
    b.groupHeader = header
    b.ev = {}
    b.onUnitEvent = M.OnUnitEvent -- Update.lua
    self:BuildGroupParts(b)         -- Update.lua
    if not InCombatLockdown() then
        b:RegisterForClicks("AnyUp")
        b:EnableMouse(true)
        self:ApplyClickCast(b) -- ClickCast.lua
    else
        self:ApplyAllClickCast() -- runs once combat ends
    end
    -- Clique and other click-casting addons read this shared table
    local clickCast = rawget(_G, "ClickCastFrames")
    if type(clickCast) ~= "table" then clickCast = {}; rawset(_G, "ClickCastFrames", clickCast) end
    clickCast[b] = true
    b:HookScript("OnAttributeChanged", onAttribute)
    b:HookScript("OnShow", function(self) M:UpdateButton(self) end)
    header.buttons[#header.buttons + 1] = b
    buttons[#buttons + 1] = b
    local unit = b:GetAttribute("unit")
    if type(unit) == "string" then self:SetButtonUnit(b, unit) end
end

function M:SetButtonUnit(b, unit)
    if type(unit) ~= "string" or unit == "" then unit = nil end
    if unit == b.unit and b.watching then return end
    b.watching = unit ~= nil
    UF.WatchUnit(b, unit, EXTRA_EVENTS)
    self:AnchorPrivate(b) -- Update.lua
    if unit then self:UpdateButton(b) end
end

-- The settings key a header's buttons draw with; the raid headers follow the raid / large switch.
local function keyOf(hkey)
    if hkey == "party" then return "group.party" end
    if hkey == "tanks" or hkey == "pets" then return "group." .. hkey end
    return "group." .. M.raidProfile
end

local function setKey(b, key)
    if b.unitKey == key and b.layoutDone then return end
    b.unitKey = key
    b.Buffs.key, b.Debuffs.key = key, key
    for _, c in ipairs(b.groupContainers or {}) do c.key = key end
    b.layoutDone = nil
end

---------------------------------------------------------------- headers
local HOLDER_OF = { party = "party", raid = "raid", tanks = "tanks", pets = "pets" }
for i = 1, 8 do HOLDER_OF["g" .. i] = "raid" end

local function newHeader(hkey)
    local template = hkey == "pets" and "SecureGroupPetHeaderTemplate" or "SecureGroupHeaderTemplate"
    local h = CreateFrame("Frame", "PhoenixUI_GF_" .. hkey, holders[HOLDER_OF[hkey]], template)
    h.hkey, h.unitKey, h.buttons = hkey, keyOf(hkey), {}
    h.PhoenixInit = function(self, childName) M:InitButton(self, _G[childName]) end
    h:SetAttribute("template", TEMPLATE)
    h:SetAttribute("templateType", "Button")
    h:SetAttribute("initialConfigFunction", INIT)
    headers[hkey] = h
    return h
end

-- the size of the frames a header makes
local function sizeOf(hkey)
    local u = UF:Unit(keyOf(hkey))
    return u.width, u.height
end

-- Makes `n` buttons now (out of combat): a negative starting index shows n buttons whatever the roster holds.
local function precreate(h, n)
    if #h.buttons >= n then return end
    local shown = h:IsShown()
    h:Show()
    h:SetAttribute("startingIndex", 1 - n)
    h:SetAttribute("startingIndex", 1)
    if not shown then h:Hide() end
end

local function setAttributes(h, attrs)
    for _, name in ipairs({ "point", "xOffset", "yOffset", "sortMethod", "sortDir", "groupBy", "groupingOrder",
        "groupFilter", "roleFilter", "unitsPerColumn", "maxColumns", "columnSpacing", "columnAnchorPoint",
        "showParty", "showRaid", "showPlayer", "showSolo", "useOwnerUnit", "filterOnPet" }) do
        h:SetAttribute(name, attrs[name])
    end
end

-- tanks and pets: a plain list growing one way
local function listAttributes(own, hkey)
    local g = M.GROW[own.growth] or M.GROW.DOWN
    local a = { point = g[1], xOffset = g[2] * own.spacing, yOffset = g[3] * own.spacing, sortMethod = "INDEX",
        maxColumns = 1, showRaid = true, showParty = hkey == "pets", showPlayer = hkey == "pets" }
    if hkey == "tanks" then
        a.roleFilter = M.db.tanks.assist and "MAINTANK,MAINASSIST" or "MAINTANK"
        a.groupBy, a.groupingOrder = "ROLE", "MAINTANK,MAINASSIST"
        a.showParty, a.showPlayer = false, false
    else
        a.filterOnPet = true
    end
    return a
end

local function corner(p) return M.Corner(p.growth, p.groupGrowth) end
local SHIFT = { RIGHT = { "LEFT", "RIGHT", 1, 0 }, LEFT = { "RIGHT", "LEFT", -1, 0 }, DOWN = { "TOP", "BOTTOM", 0, -1 },
    UP = { "BOTTOM", "TOP", 0, 1 } }

-- Sizes, attributes, places and shows one header (out of combat).
local function applyHeader(h, p, attrs, shown)
    local key = keyOf(h.hkey)
    local w, hgt = sizeOf(h.hkey)
    h:SetAttribute("phoenix-width", w)
    h:SetAttribute("phoenix-height", hgt)
    for _, b in ipairs(h.buttons) do
        setKey(b, key)
        b:SetSize(w, hgt)
        b:SetFrameStrata(p.strata or "LOW")
    end
    -- hidden while its attributes change: the header lays its buttons out once, when it shows again
    h:Hide()
    setAttributes(h, attrs)
    h:SetFrameStrata(p.strata or "LOW")
    if shown then
        h:Show()
        precreate(h, NEED[h.hkey])
    end
    for _, b in ipairs(h.buttons) do
        if not b.layoutDone then UF:Layout(b) end
        if b:IsShown() then M:UpdateButton(b) end
    end
end

local function placeHolder(holder, p, w, hgt)
    local scale = (p.scale or 1) > 0 and p.scale or 1
    holder:SetScale(scale)
    holder:SetSize(math.max(1, w), math.max(1, hgt))
    holder:ClearAllPoints()
    holder:SetPoint(p.point, UIParent, p.point, p.x / scale, p.y / scale)
end

local function difficulty()
    local _, _, id = GetInstanceInfo()
    return M.plain(id) and id or 0
end

local function inRaid() local r = IsInRaid(); return M.plain(r) and r and true or false end
local function members() local n = GetNumGroupMembers(); return M.plain(n) and n or 0 end

-- Everything: the raid profile for the roster, each header's attributes, places and visibility (out of combat).
local function layoutNow()
    if not spawned then return end
    local raid = inRaid()
    M.raidProfile = raid and M.ProfileFor(true, members()) or (M.raidProfile == "large" and "large" or "raid")
    -- party
    local pp = M:Profile("party")
    local ph = headers.party
    local c = corner(pp)
    ph:ClearAllPoints()
    ph:SetPoint(c, holders.party, c, 0, 0)
    applyHeader(ph, pp, M.HeaderAttributes(pp, "party"), true)
    placeHolder(holders.party, pp, M.GroupSize(pp, 5, 5))
    -- raid: eight group headers or one sorted header
    local rp = M:Profile(M.raidProfile)
    local groups = M.GroupsShown(rp, difficulty())
    local split = M.SplitGroups(rp)
    c = corner(rp)
    local shift = SHIFT[M.GroupGrowth(rp.growth, rp.groupGrowth)]
    for i = 1, 8 do
        local h = headers["g" .. i]
        h:ClearAllPoints()
        if i == 1 then
            h:SetPoint(c, holders.raid, c, 0, 0)
        else
            local from = c:gsub(shift[1], shift[2])
            h:SetPoint(c, headers["g" .. (i - 1)], from, shift[3] * rp.groupSpacing, shift[4] * rp.groupSpacing)
        end
        applyHeader(h, rp, M.HeaderAttributes(rp, "group", i, groups), split and i <= groups)
    end
    local rh = headers.raid
    rh:ClearAllPoints()
    rh:SetPoint(c, holders.raid, c, 0, 0)
    applyHeader(rh, rp, M.HeaderAttributes(rp, "raid", nil, groups), not split)
    placeHolder(holders.raid, rp, M.GroupSize(rp, math.min(40, groups * 5), split and 5 or rp.perColumn))
    -- main tanks / assists and pets
    for _, hkey in ipairs({ "tanks", "pets" }) do
        local own = M.db[hkey]
        local h = headers[hkey]
        local list = M.GROW[own.growth] or M.GROW.DOWN
        local first = (list[1] == "TOP" or list[1] == "BOTTOM") and list[1] .. "LEFT" or "TOP" .. list[1]
        h:ClearAllPoints()
        h:SetPoint(first, holders[hkey], first, 0, 0)
        applyHeader(h, rp, listAttributes(own, hkey), own.enabled)
        local n = hkey == "tanks" and 4 or 5
        local vertical = own.growth == "DOWN" or own.growth == "UP"
        local w = vertical and own.width or (n * own.width + (n - 1) * own.spacing)
        local hgt = vertical and (n * own.height + (n - 1) * own.spacing) or own.height
        placeHolder(holders[hkey], own, w, hgt)
    end
    ns.Events:Fire("PUI_GF_LAYOUT")
end

function M:Layout() ns.Combat:Run("gf.layout", layoutNow) end

---------------------------------------------------------------- movers
local MOVERS = { labels = { party = "GF_PARTY", raid = "GF_RAID", tanks = "GF_TANKS", pets = "GF_PETS" } }
local function settingsOf(key)
    if key == "party" then return M:Profile("party") end
    if key == "raid" then return M:Profile(M.raidProfile) end
    return M.db[key]
end
local function defaultsOf(key)
    if key == "party" then return M.DEFAULTS.profiles.party end
    if key == "raid" then return M.DEFAULTS.profiles[M.raidProfile] end
    return M.DEFAULTS[key]
end
local function store(key)
    return {
        active = function()
            if not (M:IsEnabled() and M:IsPhoenix()) then return false end
            return (key ~= "tanks" and key ~= "pets") or M.db[key].enabled
        end,
        get = function() local s = settingsOf(key); return { point = s.point, x = s.x, y = s.y, scale = s.scale } end,
        set = function(v)
            local s = settingsOf(key)
            s.point, s.x, s.y = v.point or s.point, v.x or s.x, v.y or s.y
            if v.scale then s.scale = v.scale end
        end,
        apply = function() M:Layout() end,
        reset = function()
            local s, d = settingsOf(key), defaultsOf(key)
            s.point, s.x, s.y, s.scale = d.point, d.x, d.y, d.scale
            M:Layout()
        end,
    }
end
M.MoverStore = store

---------------------------------------------------------------- events
local function eachShown(fn)
    for _, b in ipairs(buttons) do if b:IsVisible() and b.unit then fn(b) end end
end
function M:UpdateAllButtons() eachShown(function(b) M:UpdateButton(b) end) end

local lastProfile
local function rosterChanged()
    local want = inRaid() and M.ProfileFor(true, members()) or M.raidProfile
    if want ~= lastProfile then
        lastProfile = want
        M:Layout()
    end
    M:UpdateAllButtons()
end

local function registerEvents()
    local E = ns.Events
    local all = function() M:UpdateAllButtons() end
    E:On("GROUP_ROSTER_UPDATE", M, rosterChanged)
    for _, ev in ipairs({ "PARTY_LEADER_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_ROLES_ASSIGNED", "READY_CHECK",
        "READY_CHECK_CONFIRM", "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED", "PLAYER_TARGET_CHANGED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_PET" }) do
        E:On(ev, M, all)
    end
    E:On("READY_CHECK_FINISHED", M, function() C_Timer.After(6, all) end)
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED" }) do
        E:On(ev, M, function()
            ns.Combat:Run("gf.park", parkBlizzard)
            M:Layout()
        end)
    end
    -- range of pets and anything without a range event; cheap (visible buttons only)
    C_Timer.NewTicker(0.5, function()
        ns.SafeCall(eachShown, function(b) UF:UpdateRange(b, UF:SourceOf(b)) end)
    end)
end

---------------------------------------------------------------- lifecycle
local function spawn()
    if spawned then return end
    spawned = true
    parkBlizzard()
    for _, key in ipairs({ "party", "raid", "tanks", "pets" }) do
        local holder = CreateFrame("Frame", "PhoenixUI_GF_" .. key .. "Holder", UIParent)
        holder:SetSize(1, 1)
        holders[key] = holder
    end
    newHeader("party")
    for i = 1, 8 do newHeader("g" .. i) end
    newHeader("raid")
    newHeader("tanks")
    newHeader("pets")
    -- Clique's own header (when loaded) registers our buttons too; ClickCastFrames covers the rest
    layoutNow()
    lastProfile = M.raidProfile
    registerEvents()
    local movers = ns:GetModule("Movers")
    if movers then
        for key, label in pairs(MOVERS.labels) do movers:Register("gf." .. key, holders[key], L[label], store(key)) end
    end
end

function M:EnablePhoenix()
    ns.Combat:Run("gf.spawn", spawn)
end

function M:RefreshPhoenix()
    if not spawned then return end
    for _, b in ipairs(buttons) do b.layoutDone = nil end
    self:Layout()
    if not InCombatLockdown() then return end
    -- in combat: the parts that are not protected re-lay out now (sizes wait for the queue)
    for _, b in ipairs(buttons) do UF:Layout(b); self:UpdateButton(b) end
end

function M:IsSpawned() return spawned end
