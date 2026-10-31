-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...

--[[ ns.Journal: the one place Phoenix reads the game's Encounter Journal (expansions, instances, bosses, the
    ability tree). Used by the journal window (Skins) and the boss modules (Encounters). Secret or missing names
    are skipped; everything is guarded so builds without the journal get empty lists. ]]
local J = {}
ns.Journal = J

local function plain(v) return v ~= nil and not (ns.Secret and ns.Secret.IsSecret(v)) end
function J.Has() return EJ_GetInstanceByIndex ~= nil and EJ_GetEncounterInfoByIndex ~= nil end

-- { { tier = i, name = "…" }, … }
function J.Tiers()
    local out = {}
    if not (EJ_GetNumTiers and EJ_GetTierInfo) then return out end
    for i = 1, tonumber(EJ_GetNumTiers()) or 0 do
        local name = EJ_GetTierInfo(i)
        if plain(name) then out[#out + 1] = { tier = i, name = tostring(name) } end
    end
    return out
end

-- Instances of the selected tier (or the given one): { { id, name }, … }
function J.Instances(isRaid, tier)
    local out = {}
    if not J.Has() then return out end
    if tier and EJ_SelectTier then EJ_SelectTier(tier) end
    for i = 1, 200 do
        local id, name = EJ_GetInstanceByIndex(i, isRaid and true or false)
        if not id then break end
        if plain(name) then out[#out + 1] = { id = id, name = tostring(name) } end
    end
    return out
end

-- Bosses of the given instance (or the selected one): { { id, name }, … }
function J.Bosses(instanceID)
    local out = {}
    if not J.Has() then return out end
    for i = 1, 40 do
        local name, _, id = EJ_GetEncounterInfoByIndex(i, instanceID)
        if not name then break end
        if plain(name) then out[#out + 1] = { id = id, name = tostring(name) } end
    end
    return out
end

--[[ Walks the ability tree from rootID. visit(info, id, depth) returns true to descend into the children.
    Sections filtered out by the current difficulty are skipped. ]]
function J.Walk(rootID, visit)
    if not (C_EncounterJournal and C_EncounterJournal.GetSectionInfo) then return end
    local guard = 0
    local function walk(id, depth)
        while id and id > 0 and guard < 400 do
            guard = guard + 1
            local info = C_EncounterJournal.GetSectionInfo(id)
            if type(info) ~= "table" then return end
            if not info.filteredByDifficulty and visit(info, id, depth) then
                walk(tonumber(info.firstChildSectionID), depth + 1)
            end
            id = tonumber(info.siblingSectionID)
        end
    end
    walk(tonumber(rootID), 0)
end

function J.RootSection(encounterID)
    if not (EJ_GetEncounterInfo and encounterID) then return nil end
    return select(4, EJ_GetEncounterInfo(encounterID))
end

-- A boss's abilities that carry a spell ID, whole tree: { { spellID, name }, … }
function J.Abilities(encounterID)
    local out, seen = {}, {}
    J.Walk(J.RootSection(encounterID), function(info)
        local spell = tonumber(info.spellID)
        if spell and spell > 0 and not seen[spell] and plain(info.title) then
            seen[spell] = true
            out[#out + 1] = { spellID = spell, name = tostring(info.title) }
        end
        return true
    end)
    return out
end
