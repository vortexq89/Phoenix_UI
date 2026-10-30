-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local L = ns.L
local M = ns.modules.Automation

--[[ Loadout manager: for each spec, pick a talent loadout and an equipment set per kind of content (raid,
    dungeon, arena, battleground, open world). Entering that content offers the switch in a small window with an
    Apply button (or applies it at once when Auto apply is on). Never in combat; event driven. ]]

M.LOADOUT_CONTEXTS = { "raid", "dungeon", "arena", "pvp", "world" }

function M.LoadoutContext()
    local inside, kind = IsInInstance()
    if not inside then return "world" end
    if kind == "raid" then return "raid" end
    if kind == "party" then return "dungeon" end
    if kind == "arena" then return "arena" end
    if kind == "pvp" then return "pvp" end
    return "world"
end

local function specID()
    local api = C_SpecializationInfo
    local idx = api and api.GetSpecialization and api.GetSpecialization()
    local id = type(idx) == "number" and api.GetSpecializationInfo and api.GetSpecializationInfo(idx)
    return type(id) == "number" and id or 0
end

function M:LoadoutFor(context, spec)
    local all = self.db.loadouts
    local s = all and all[spec or specID()]
    return s and s[context] or nil
end

function M:SetLoadout(context, field, value)
    local db = self.db
    db.loadouts = db.loadouts or {}
    local spec = specID()
    db.loadouts[spec] = db.loadouts[spec] or {}
    local e = db.loadouts[spec][context] or {}
    e[field] = (value ~= 0 and value) or nil
    db.loadouts[spec][context] = next(e) and e or nil
end

-- dropdown values: talent loadouts of the current spec / equipment sets, each with a "none" first
function M.TalentChoices()
    local out = { { value = 0, label = L.NONE } }
    local CT = C_ClassTalents
    if CT and CT.GetConfigIDsBySpecID and C_Traits and C_Traits.GetConfigInfo then
        for _, id in ipairs(CT.GetConfigIDsBySpecID(specID()) or {}) do
            local info = C_Traits.GetConfigInfo(id)
            if info and info.name then out[#out + 1] = { value = id, label = info.name } end
        end
    end
    return out
end

function M.GearChoices()
    local out = { { value = 0, label = L.NONE } }
    local E = C_EquipmentSet
    if E and E.GetEquipmentSetIDs then
        for _, id in ipairs(E.GetEquipmentSetIDs() or {}) do
            local name = E.GetEquipmentSetInfo(id)
            if name then out[#out + 1] = { value = id, label = name } end
        end
    end
    return out
end

-- what would change: { talent = configID?, gear = setID? } (only parts that differ from now)
function M:LoadoutChanges(context)
    local want = self:LoadoutFor(context)
    if not want then return nil end
    local out = {}
    local CT = C_ClassTalents
    if want.talent and CT and CT.GetLastSelectedSavedConfigID then
        if CT.GetLastSelectedSavedConfigID(specID()) ~= want.talent then out.talent = want.talent end
    end
    if want.gear and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
        local _, _, _, equipped = C_EquipmentSet.GetEquipmentSetInfo(want.gear)
        if not equipped then out.gear = want.gear end
    end
    return next(out) and out or nil
end

function M:ApplyLoadout(changes)
    if InCombatLockdown() or not changes then return false end
    if changes.talent and C_ClassTalents.LoadConfig then pcall(C_ClassTalents.LoadConfig, changes.talent, true) end
    if changes.gear and C_EquipmentSet.UseEquipmentSet then pcall(C_EquipmentSet.UseEquipmentSet, changes.gear) end
    return true
end

local win
function M:OfferLoadout(context, changes)
    local W = ns.Widgets
    if not win then
        win = W:Popup(L.LOADOUT_TITLE, 380, 150, "spec")
        win.text = W.Text(win, "body", "text.primary"); win.text:SetPoint("TOPLEFT", 18, -48)
        win.text:SetPoint("RIGHT", -18, 0); win.text:SetWordWrap(true)
        win.apply = W:Button(win, L.LOADOUT_APPLY, "primary", "check", 120); win.apply:SetPoint("BOTTOMRIGHT", -16, 14)
        win.apply.onClick = function() M:ApplyLoadout(win.changes); win:Hide() end
    end
    win.changes = changes
    win.text:SetText(L.LOADOUT_OFFER:format(L["LOADOUT_CTX_" .. context:upper()] or context))
    win:Show()
    return win
end

function M:CheckLoadout()
    if not (self:IsEnabled() and self.db.loadoutsOn) or InCombatLockdown() then return end
    local context = M.LoadoutContext()
    local changes = self:LoadoutChanges(context)
    if not changes then return end
    if self.db.loadoutsAuto then self:ApplyLoadout(changes) else self:OfferLoadout(context, changes) end
end

local owner, pending = {}, false
function M:EnableLoadouts()
    local function queue()
        if pending then return end
        pending = true
        C_Timer.After(2, function() pending = false; ns.SafeCall(M.CheckLoadout, M) end)
    end
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do ns.Events:On(ev, owner, queue) end
end
