local _, ns = ...

--[[ Sim export: the character as a SimulationCraft profile, and gear as SimC item options.

    The item option format follows the SimulationCraft addon's exporter (simc-addon by the SimulationCraft
    team, released under the Unlicense, https://github.com/simulationcraft/simc-addon), re-implemented here
    for Phoenix: which item link fields SimC reads (enchant, gems, bonus IDs, the modifier pairs for drop
    level, content tuning, crafted stats and redirected stats, gem bonus IDs) and the race and talent rules.
    Spec and profession names come from the game's own data (DB2 ChrSpecialization and SkillLine, build
    12.1.5.70448), not from that addon.

    Everything here reads plain item links and character APIs out of combat; links are checked with
    ns.Secret before they are parsed. ]]
local Secret = ns.Secret
local X = {}
ns.SimExport = X

-- Spec ID -> SimC spec token and role (ChrSpecialization: Name_lang tokenized; Role 0 tank, 1 healer, else
-- by PrimaryStatPriority 0 = intellect -> spell).
local SPECS = {
    [62] = { "arcane", "spell" }, [63] = { "fire", "spell" }, [64] = { "frost", "spell" },
    [65] = { "holy", "heal" }, [66] = { "protection", "tank" }, [70] = { "retribution", "attack" },
    [71] = { "arms", "attack" }, [72] = { "fury", "attack" }, [73] = { "protection", "tank" },
    [102] = { "balance", "spell" }, [103] = { "feral", "attack" }, [104] = { "guardian", "tank" },
    [105] = { "restoration", "heal" }, [250] = { "blood", "tank" }, [251] = { "frost", "attack" },
    [252] = { "unholy", "attack" }, [253] = { "beast_mastery", "attack" }, [254] = { "marksmanship", "attack" },
    [255] = { "survival", "attack" }, [256] = { "discipline", "heal" }, [257] = { "holy", "heal" },
    [258] = { "shadow", "spell" }, [259] = { "assassination", "attack" }, [260] = { "outlaw", "attack" },
    [261] = { "subtlety", "attack" }, [262] = { "elemental", "spell" }, [263] = { "enhancement", "attack" },
    [264] = { "restoration", "heal" }, [265] = { "affliction", "spell" }, [266] = { "demonology", "spell" },
    [267] = { "destruction", "spell" }, [268] = { "brewmaster", "tank" }, [269] = { "windwalker", "attack" },
    [270] = { "mistweaver", "heal" }, [577] = { "havoc", "attack" }, [581] = { "vengeance", "tank" },
    [1467] = { "devastation", "spell" }, [1468] = { "preservation", "heal" }, [1473] = { "augmentation", "spell" },
    [1480] = { "devourer", "spell" },
}
X.SPECS = SPECS
X.FURY = 72 -- Titan's Grip: two-handers go in either hand

-- Primary professions (SkillLine, CategoryID 11).
local PROFESSIONS = {
    [164] = "blacksmithing", [165] = "leatherworking", [171] = "alchemy", [182] = "herbalism", [186] = "mining",
    [197] = "tailoring", [202] = "engineering", [333] = "enchanting", [393] = "skinning", [755] = "jewelcrafting",
    [773] = "inscription",
}

-- Equipment slot -> SimC slot (shirt and tabard are exported but never compared).
X.SLOT_NAMES = {
    [1] = "head", [2] = "neck", [3] = "shoulder", [4] = "shirt", [5] = "chest", [6] = "waist", [7] = "legs",
    [8] = "feet", [9] = "wrist", [10] = "hands", [11] = "finger1", [12] = "finger2", [13] = "trinket1",
    [14] = "trinket2", [15] = "back", [16] = "main_hand", [17] = "off_hand", [19] = "tabard",
}
X.SLOT_ORDER = { 1, 2, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }

-- Item link modifier types SimC understands (ItemModification).
local MOD_DROP_LEVEL, MOD_CONTENT_TUNING, MOD_CRAFTED_1, MOD_CRAFTED_2, MOD_REDIRECTED = 9, 28, 29, 30, 64

local function tokenize(s)
    s = tostring(s or ""):lower():gsub("%s+", "_")
    return (s:gsub("[^a-z0-9_]", ""))
end
X.Tokenize = tokenize

-- "item:..." -> array of numbers (empty fields are 0); nil for anything that is not a plain item link.
function X.Split(link)
    if type(link) ~= "string" or Secret.IsSecret(link) then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local out, i = {}, 0
    for field in (body .. ":"):gmatch("([^:]*):") do
        i = i + 1
        out[i] = tonumber(field) or 0
    end
    out.n = i
    return out
end

-- Bonus IDs and the index after them (the modifier count).
local BONUS_COUNT = 13
local function bonuses(f)
    local list = {}
    local n = f[BONUS_COUNT] or 0
    for i = 1, math.min(n, 40) do list[i] = f[BONUS_COUNT + i] or 0 end
    return list, BONUS_COUNT + n + 1
end

-- Stable item identity shared with the Phoenix app: item ID and sorted bonus IDs ("212400:10390:11977").
function X.Key(link)
    local f = X.Split(link)
    if not f or (f[1] or 0) <= 0 then return nil end
    local list = bonuses(f)
    table.sort(list)
    local parts = { tostring(f[1]) }
    for _, b in ipairs(list) do if b > 0 then parts[#parts + 1] = tostring(b) end end
    return table.concat(parts, ":")
end

local function positive(list)
    for _, v in ipairs(list) do if v <= 0 then return false end end
    return #list > 0
end

local function gemsOf(f)
    local gems = {}
    for i = 3, 6 do gems[i - 2] = f[i] > 0 and f[i] or 0 end
    while #gems > 0 and gems[#gems] == 0 do gems[#gems] = nil end
    return gems
end

-- The modifier pairs after the bonus IDs (drop level, content tuning, crafted and redirected stats).
local function modifiers(f, at, out)
    local crafted = {}
    for i = 1, math.min(f[at] or 0, 20) do
        local kind, value = f[at + 2 * i - 1], f[at + 2 * i]
        if value and value > 0 then
            if kind == MOD_DROP_LEVEL then out[#out + 1] = "drop_level=" .. value
            elseif kind == MOD_CONTENT_TUNING then out[#out + 1] = "content_tuning=" .. value
            elseif kind == MOD_CRAFTED_1 or kind == MOD_CRAFTED_2 then crafted[#crafted + 1] = value
            elseif kind == MOD_REDIRECTED then out[#out + 1] = "redirected_base_stats=" .. value end
        end
    end
    if #crafted > 0 then out[#out + 1] = "crafted_stats=" .. table.concat(crafted, "/") end
end

-- Gem bonus IDs follow the modifiers, after the first relic's bonus count.
local function gemBonuses(f, at)
    local list = {}
    local gemAt = at + 2 * (f[at] or 0) + 2
    for i = 1, math.min(f[gemAt] or 0, 8) do
        local v = f[gemAt + i]
        if v and v > 0 then list[#list + 1] = v end
    end
    return list
end

-- SimC item options for a link: ",id=…,enchant_id=…,…" (what follows "slot=" in a profile).
function X.ItemLine(link)
    local f = X.Split(link)
    if not f or (f[1] or 0) <= 0 then return nil end
    local out = { ",id=" .. f[1] }
    if f[2] > 0 then out[#out + 1] = "enchant_id=" .. f[2] end
    local gems = gemsOf(f)
    if #gems > 0 then out[#out + 1] = "gem_id=" .. table.concat(gems, "/") end
    local list, at = bonuses(f)
    if positive(list) then out[#out + 1] = "bonus_id=" .. table.concat(list, "/") end
    modifiers(f, at, out)
    local gb = gemBonuses(f, at)
    if #gb > 0 then out[#out + 1] = "gem_bonus_id=" .. table.concat(gb, "/") end
    local quality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(link)
    if type(quality) == "number" and quality > 0 then out[#out + 1] = "crafting_quality=" .. quality end
    return table.concat(out, ",")
end

-- SimC race token: the race's file name split at capitals (VoidElf -> void_elf); Scourge is "undead";
-- the two Midnight races without a file name use SimC's skyborne names.
function X.Race()
    local _, file, raceID = UnitRace("player")
    if raceID == 95 then return "skyborne_alliance" end
    if raceID == 96 then return "skyborne_horde" end
    if file == "Scourge" then return "undead" end
    local words = {}
    for w in tostring(file or ""):gmatch("%u%l*") do words[#words + 1] = w end
    return tokenize(table.concat(words, " "))
end

local function talents()
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local s = C_Traits.GenerateImportString(configID)
    if type(s) == "string" and s:match("^[%w+/]+$") then return s end
end

-- Purchased entries of a trait system (Midnight's Omnium: system 48) as entryID:rank/…
local OMNIUM_SYSTEM = 48
local function omnium()
    local configID = C_Traits.GetConfigIDBySystemID and C_Traits.GetConfigIDBySystemID(OMNIUM_SYSTEM)
    local info = configID and C_Traits.GetConfigInfo(configID)
    if not (info and info.treeIDs) then return nil end
    local out = {}
    for _, treeID in ipairs(info.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if node and (node.ranksPurchased or 0) > 0 and node.activeEntry then
                out[#out + 1] = node.activeEntry.entryID .. ":" .. (node.currentRank or node.ranksPurchased)
            end
        end
    end
    return #out > 0 and table.concat(out, "/") or nil
end

local function professions()
    local out = {}
    local a, b = GetProfessions()
    for _, index in ipairs({ a or false, b or false }) do
        if index then
            local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
            if PROFESSIONS[skillLine] and rank then out[#out + 1] = PROFESSIONS[skillLine] .. "=" .. rank end
        end
    end
    return #out > 0 and table.concat(out, "/") or nil
end

function X.SpecID()
    local index = C_SpecializationInfo.GetSpecialization()
    return index and C_SpecializationInfo.GetSpecializationInfo(index)
end

-- The character part of the profile (without gear); nil, reason when it cannot be built yet.
function X.Header()
    local name = UnitName("player")
    local _, class = UnitClass("player")
    local specID = X.SpecID()
    local spec = SPECS[specID]
    if not (class and spec) then return nil, "SIM_ERR_SPEC" end
    local lines = {
        ("%s=\"%s\""):format(class:lower(), name or "Player"),
        "level=" .. UnitLevel("player"),
        "race=" .. X.Race(),
    }
    local region = tokenize(GetCurrentRegionName and GetCurrentRegionName() or "")
    if region ~= "" then lines[#lines + 1] = "region=" .. region end
    local server = tokenize(GetRealmName())
    if server ~= "" then lines[#lines + 1] = "server=" .. server end
    lines[#lines + 1] = "role=" .. spec[2]
    local prof = professions()
    if prof then lines[#lines + 1] = "professions=" .. prof end
    lines[#lines + 1] = "spec=" .. spec[1]
    local t = talents()
    if not t then return nil, "SIM_ERR_TALENTS" end
    lines[#lines + 1] = "talents=" .. t
    local o = omnium()
    if o then lines[#lines + 1] = "omnium_talents=" .. o end
    return lines
end

-- The full profile text: header and every equipped item.
function X.Profile()
    local lines, err = X.Header()
    if not lines then return nil, err end
    for _, slot in ipairs(X.SLOT_ORDER) do
        local link = GetInventoryItemLink("player", slot)
        local line = link and X.ItemLine(link)
        if line then lines[#lines + 1] = X.SLOT_NAMES[slot] .. "=" .. line end
    end
    return table.concat(lines, "\n")
end
