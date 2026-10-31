-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...
local Secret = ns.Secret
local M = ns:GetModule("Encounters")

--[[ Boss modules, step 1 (BigWigs / LittleWigs parity, t201): every raid and dungeon of every expansion, read
    from the game's Encounter Journal (no shipped boss list to go stale), and per-ability choices for each boss:
    hide, emphasise, sound or count-in on the timeline bars (Bars.lua). Choices are stored per spell ID in
    timeline.abilities; data defaults come from ns.EncounterData (Data.lua). Out of an encounter the journal's
    names are plain; anything secret is skipped. ]]

local function plain(v) return v ~= nil and not Secret.IsSecret(v) end
local function has() return EJ_GetNumTiers and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex end
M.HasJournal = has

function M.JournalTiers()
    local out = {}
    if not has() then return out end
    for i = 1, tonumber(EJ_GetNumTiers()) or 0 do
        local name = EJ_GetTierInfo(i)
        if plain(name) then out[#out + 1] = { value = i, label = tostring(name) } end
    end
    return out
end

function M.JournalInstances(tier, raid)
    local out = {}
    if not has() or not tier then return out end
    EJ_SelectTier(tier)
    for i = 1, 200 do
        local id, name = EJ_GetInstanceByIndex(i, raid and true or false)
        if not id then break end
        if plain(name) then out[#out + 1] = { value = id, label = tostring(name) } end
    end
    return out
end

function M.JournalBosses(instanceID)
    local out = {}
    if not has() or not instanceID then return out end
    for i = 1, 40 do
        local name, _, id = EJ_GetEncounterInfoByIndex(i, instanceID)
        if not name then break end
        if plain(name) then out[#out + 1] = { value = id, label = tostring(name) } end
    end
    return out
end

-- The boss's abilities that carry a spell ID: { value = spellID, label = title }, walked from the journal tree.
function M.BossAbilities(encounterID)
    local out, seen = {}, {}
    if not (EJ_GetEncounterInfo and C_EncounterJournal and C_EncounterJournal.GetSectionInfo and encounterID) then
        return out
    end
    local root = select(4, EJ_GetEncounterInfo(encounterID))
    local guard = 0
    local function walk(id)
        while id and id > 0 and guard < 400 do
            guard = guard + 1
            local info = C_EncounterJournal.GetSectionInfo(id)
            if type(info) ~= "table" then return end
            local spell = tonumber(info.spellID)
            if spell and spell > 0 and not seen[spell] and plain(info.title) then
                seen[spell] = true
                out[#out + 1] = { value = spell, label = tostring(info.title) }
            end
            walk(tonumber(info.firstChildSectionID))
            id = tonumber(info.siblingSectionID)
        end
    end
    walk(tonumber(root))
    return out
end

-- The data default for a spell in any encounter (ns.EncounterData), or nil.
local byspell
function M.DataDefault(spellID)
    if not byspell then
        byspell = {}
        local data = ns.EncounterData and ns.EncounterData.encounters or {}
        for _, abilities in pairs(data) do
            for id, a in pairs(abilities) do if type(a) == "table" then byspell[id] = a end end
        end
    end
    local a = byspell[spellID]
    return a and a.default
end

M.CHOICES = { default = true, hide = true, emph = true, sound = true, count = true }
function M:SetAbilityChoice(spellID, what)
    if type(spellID) ~= "number" or not M.CHOICES[what] then return false end
    local t = self.db.timeline
    t.abilities = type(t.abilities) == "table" and t.abilities or {}
    t.abilities[spellID] = what ~= "default" and what or nil
    return true
end
function M:AbilityChoice(spellID)
    local t = self.db.timeline.abilities
    return type(t) == "table" and t[spellID] or "default"
end
