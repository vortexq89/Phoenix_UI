-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns.modules.Tracker

--[[ Movement alert: one icon for your class's movement spell (the first one you know from M.MOBILITY), with
    its cooldown swipe and countdown, so you know when you can dash again. The cooldown comes from
    C_Spell.GetSpellCooldownDuration (a duration object) or C_Spell.GetSpellCooldown, and is handed to the
    Cooldown widget as it is, never compared; secret cooldowns in combat still draw. Event driven
    (SPELL_UPDATE_COOLDOWN, spec and talent changes) on a C_Timer batch; nothing runs per frame. ]]

local MOBILITY = M.MOBILITY -- Custom.lua (the "Fill movement row" list)

local holder

local function known(id)
    local api = C_SpellBook
    if not (api and api.IsSpellKnown) then return false end
    local ok, yes = pcall(api.IsSpellKnown, id)
    return ok and yes == true
end

-- The movement spell to show for a class token (first known), or nil.
function M.MobilitySpell(class)
    for _, id in ipairs(MOBILITY[class] or {}) do if known(id) then return id end end
    return nil
end

local function db() return M.db.mobility end

local function store()
    return {
        active = function() return M:IsEnabled() and db().enabled end,
        get = function() local p = db(); return { point = p.point, x = p.x, y = p.y } end,
        set = function(val)
            local p = db()
            p.point, p.x, p.y = val.point or p.point, val.x or p.x, val.y or p.y
        end,
        apply = function() M:RefreshMobility() end,
        reset = function()
            local p, d = db(), M.defaults.mobility
            p.point, p.x, p.y = d.point, d.x, d.y
            M:RefreshMobility()
        end,
    }
end

local function ensure()
    if holder then return holder end
    holder = CreateFrame("Frame", "PhoenixUI_CDM_mobility", UIParent)
    holder:SetSize(40, 40)
    holder.Icon = holder:CreateTexture(nil, "ARTWORK")
    holder.Icon:SetAllPoints()
    holder.Cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
    holder.Cooldown:SetAllPoints()
    holder.Cooldown:SetDrawEdge(false)
    holder.holder = CreateFrame("Frame", nil, holder)
    holder.holder:SetAllPoints()
    holder.holder:SetFrameLevel(holder.Cooldown:GetFrameLevel() + 1)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("cdm.mobility", holder, L.TRACKER_MOVE_ALERT, store()) end
    return holder
end

local function setCooldown(cd, id)
    local api = C_Spell
    if api and api.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
        local ok, d = pcall(api.GetSpellCooldownDuration, id)
        if ok and d and pcall(cd.SetCooldownFromDurationObject, cd, d) then return end
    end
    if api and api.GetSpellCooldown then
        local ok, info = pcall(api.GetSpellCooldown, id)
        if ok and type(info) == "table" then pcall(cd.SetCooldown, cd, info.startTime, info.duration) end
    end
end

function M:RefreshMobility(test)
    local p = db()
    local _, class = UnitClass("player")
    local id = test and (MOBILITY[class] or MOBILITY.WARRIOR)[1] or (self:IsEnabled() and p.enabled and M.MobilitySpell(class))
    if not id then if holder then holder:Hide() end return end
    ensure()
    holder:SetSize(p.size, p.size)
    holder:ClearAllPoints()
    holder:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    holder.Icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400)
    self:StyleIcon("utility", holder.Icon, holder.holder)
    setCooldown(holder.Cooldown, id)
    holder:Show()
end

local pending = false
local function queue()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        if M:IsEnabled() then ns.SafeCall(M.RefreshMobility, M) end
    end)
end

function M:EnableMobility()
    for _, ev in ipairs({ "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED",
        "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED" }) do
        self:On(ev, queue)
    end
    queue()
end

function M:DisableMobility() if holder then holder:Hide() end end
