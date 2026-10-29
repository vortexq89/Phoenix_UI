local _, ns = ...
local L, Skin, Secret = ns.L, ns.Skin, ns.Secret
local M = ns.modules.MythicPlus

--[[ Interrupt tracker (EllesmereUI Mythic+ Tools "kick tracker" studied for the idea; original code). One icon per
    group member who has an interrupt: their class's (or spec's) interrupt spell, its name, and a cooldown swipe that
    starts when they cast it. The swipe is the game's own Cooldown widget, so no timer of ours runs.
    Source: UNIT_SPELLCAST_SUCCEEDED for player and party1-4. In restricted content (keys, raids) the game can make the
    spell ID secret: such a cast is skipped (a secret is never compared or used as a table key), so the icon then
    stays "ready" until a readable cast arrives. This is the 12.x limit, shown in the setting's description.
    Cooldowns are the base values from the client's SpellCooldowns table (DB2, 12.1.5); talents that shorten an
    interrupt are not applied. Plain frames, no secure code; movable in Layout mode. ]]

-- spellID -> base cooldown in seconds (SpellCooldowns, DifficultyID 0)
local IDS = { 1766, 6552, 96231, 47528, 106839 } -- spellIDs(retail): Kick, Pummel, Rebuke, Mind Freeze, Skull Bash
local IDS2 = { 78675, 147362, 187707, 2139, 57994 } -- spellIDs(retail): Solar Beam, Counter Shot, Muzzle, Counterspell, Wind Shear
local IDS3 = { 116705, 183752, 15487, 351338, 119910 } -- spellIDs(retail): Spear Hand Strike, Disrupt, Silence, Quell, Spell Lock
for _, id in ipairs(IDS2) do IDS[#IDS + 1] = id end
for _, id in ipairs(IDS3) do IDS[#IDS + 1] = id end
local CDS = { 15, 15, 15, 15, 15, 60, 24, 15, 25, 12, 15, 15, 30, 20, 24 }
local KICK_CD = {}
for i, id in ipairs(IDS) do KICK_CD[id] = CDS[i] end
M.KICK_CD = KICK_CD

-- class -> its usual interrupt; specID -> a different one, or false for a spec without one
local CLASS_KICK = { ROGUE = 1766, WARRIOR = 6552, PALADIN = 96231, DEATHKNIGHT = 47528, DRUID = 106839, HUNTER = 147362,
    MAGE = 2139, SHAMAN = 57994, MONK = 116705, DEMONHUNTER = 183752, PRIEST = 15487, EVOKER = 351338, WARLOCK = 119910 }
local SPEC_KICK = {
    [65] = false,                                -- Holy Paladin
    [102] = 78675, [105] = false,                -- Balance (Solar Beam), Restoration Druid
    [255] = 187707,                              -- Survival Hunter (Muzzle)
    [256] = false, [257] = false,                -- Discipline, Holy Priest (Shadow keeps Silence)
    [270] = false,                               -- Mistweaver Monk
}
M.CLASS_KICK, M.SPEC_KICK = CLASS_KICK, SPEC_KICK

-- The interrupt a member has: spec first (when known), else the class's. nil = none or unknown.
function M.KickFor(class, specID)
    if specID and SPEC_KICK[specID] ~= nil then return SPEC_KICK[specID] or nil end
    if class == "PRIEST" and not specID then return nil end -- spec not known yet: only Shadow has Silence
    return CLASS_KICK[class]
end

-- Whether the tracker shows here: "always", "group" (in a party) or "dungeon" (party instance).
function M.KicksShownWhere(where, inGroup, instanceType)
    if where == "always" then return true end
    if where == "group" then return inGroup and true or false end
    return inGroup and instanceType == "party" or false
end

local UNITS = { "player", "party1", "party2", "party3", "party4" }
local holder
local rows = {}       -- unit -> row frame
local started = {}    -- unit -> { start, duration } (plain numbers we made from GetTime)
local owner = {}

local function readable(v) return v ~= nil and not Secret.IsSecret(v) end

local function memberKick(unit)
    if not UnitExists(unit) then return nil end
    local _, class = UnitClass(unit)
    if not readable(class) then return nil end
    local spec
    if unit == "player" then
        local idx = GetSpecialization and GetSpecialization()
        spec = idx and GetSpecializationInfo and GetSpecializationInfo(idx) or nil
    elseif GetInspectSpecialization then
        spec = GetInspectSpecialization(unit)
        if not readable(spec) or spec == 0 then spec = nil end
    end
    if not readable(spec) then spec = nil end
    return M.KickFor(class, spec)
end

local function newRow()
    local r = CreateFrame("Frame", nil, holder)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.cd = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
    r.cd:SetAllPoints(r.icon)
    r.cd:SetHideCountdownNumbers(false)
    r.name = r:CreateFontString(nil, "OVERLAY")
    return r
end

function M:LayoutKicks()
    if not holder then return end
    local s = self.db.kicks
    local shown = 0
    for _, unit in ipairs(UNITS) do
        local r = rows[unit]
        if r and r.spell then
            shown = shown + 1
            r:SetSize(s.size + (s.names and 90 or 0), s.size)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(shown - 1) * (s.size + s.spacing))
            r.icon:SetSize(s.size, s.size)
            r.icon:ClearAllPoints()
            r.icon:SetPoint("LEFT")
            r.icon:SetTexture(C_Spell.GetSpellTexture(r.spell)) -- the game's own spell icon
            Skin:IconZoom(r.icon, s.zoom)
            Skin:Border(r, "border.strong")
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            Skin:TextSpec(r.name, s.text, "body", "text.primary")
            r.name:SetShown(s.names)
            r:Show()
        elseif r then
            r:Hide()
        end
    end
    holder:SetSize(s.size + (s.names and 96 or 0), math.max(1, shown) * (s.size + s.spacing))
    holder:ClearAllPoints()
    holder:SetPoint(s.point, UIParent, s.point, s.x, s.y)
end

-- Rebuilds the member list (roster, spec or setting changes).
function M:UpdateKicks()
    if not holder then return end
    local s = self.db.kicks
    local inGroup = IsInGroup and IsInGroup() or false
    local _, instanceType = IsInInstance()
    local on = self:IsEnabled() and s.show and (self.kicksTest or M.KicksShownWhere(s.where, inGroup, instanceType))
    for _, unit in ipairs(UNITS) do
        local spell = on and (self.kicksTest and M.TestKick(unit) or memberKick(unit)) or nil
        local r = rows[unit]
        if spell and not r then r = newRow(); rows[unit] = r end
        if r then
            if r.spell ~= spell then started[unit] = nil; r.cd:Clear() end
            r.spell, r.unit = spell, unit
            if spell then
                local name = self.kicksTest and L["MPLUS_KICKS_TEST_" .. unit:upper()] or UnitName(unit)
                r.name:SetText(name or "") -- a name is only ever handed to the font string
            end
        end
    end
    self:LayoutKicks()
    holder:SetShown(on and true or false)
end

-- A cast by a tracked unit: start its swipe when it was the interrupt. A secret spell ID is skipped.
function M.NoteKickCast(unit, spellID)
    local r = rows[unit]
    if not (r and r.spell) or Secret.IsSecret(spellID) or type(spellID) ~= "number" then return false end
    local cd = KICK_CD[spellID]
    if not cd then return false end
    if spellID ~= r.spell then r.spell = spellID; M:LayoutKicks() end -- e.g. a Balance druid's Solar Beam
    local now = GetTime()
    started[unit] = { now, cd }
    r.cd:SetCooldown(now, cd)
    return true
end

function M:KickState(unit) return started[unit], rows[unit] and rows[unit].spell end

-- Test icons for the page's test button: one of each role's usual interrupt.
local TEST = { player = 1766, party1 = 6552, party2 = 57994, party3 = 2139, party4 = 183752 }
function M.TestKick(unit) return TEST[unit] end
function M:TestKicks(on)
    self.kicksTest = on and true or nil
    self:UpdateKicks()
    if on then M.NoteKickCast("party2", 57994) end
end

local function store()
    return {
        active = function() return M:IsEnabled() and M.db.kicks.show end,
        get = function() local t = M.db.kicks; return { point = t.point, x = t.x, y = t.y } end,
        set = function(v) local t = M.db.kicks; t.point, t.x, t.y = v.point or t.point, v.x or t.x, v.y or t.y end,
        apply = function() M:LayoutKicks() end,
        reset = function()
            local d, t = M.defaults.kicks, M.db.kicks
            t.point, t.x, t.y = d.point, d.x, d.y
            M:LayoutKicks()
        end,
    }
end

local function onCast(_, _, unit, _, spellID) ns.SafeCall(M.NoteKickCast, unit, spellID) end

function M:EnableKicks()
    if not holder then
        holder = CreateFrame("Frame", "PhoenixUI_Kicks", UIParent)
        holder:Hide()
        M.kicksHolder = holder
        local movers = ns:GetModule("Movers")
        if movers then movers:Register("mplus.kicks", holder, L.MPLUS_KICKS, store()) end
    end
    ns.Events:OffAll(owner)
    if self.db.kicks.show then
        local update = function() ns.SafeCall(M.UpdateKicks, M) end
        ns.Events:On("GROUP_ROSTER_UPDATE", owner, update)
        ns.Events:On("PLAYER_ENTERING_WORLD", owner, update)
        ns.Events:On("PLAYER_SPECIALIZATION_CHANGED", owner, update)
        ns.Events:On("INSPECT_READY", owner, update)
        ns.Events:OnUnit("UNIT_SPELLCAST_SUCCEEDED", owner, onCast, "player", "party1")
        ns.Events:OnUnit("UNIT_SPELLCAST_SUCCEEDED", owner, onCast, "party2", "party3")
        ns.Events:OnUnit("UNIT_SPELLCAST_SUCCEEDED", owner, onCast, "party4")
    end
    self:UpdateKicks()
end
