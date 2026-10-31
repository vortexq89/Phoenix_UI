local _, ns = ...
local L, Theme = ns.L, ns.Theme

--[[ Tooltip extras: name colours, guild rank, realm, targeted by, inspect (item level and specialization),
    mount, PvP-line hiding, health text, item counts and IDs; on items (S17) the vendor price when the game shows
    none, whether you have collected it (appearance, toy, mount, pet) and, for keystones, the dungeon's timer and
    your season best there.
    Every value read from a unit may be secret in restricted content (instances, combat); each one goes through
    M.Plain first and is skipped when secret, never compared. Inspect requests are throttled, never sent in
    combat or while the Inspect window is open, and cached per GUID for five minutes. ]]
local M = ns.modules.Tooltip
local plain = M.Plain

local INSPECT_TTL, INSPECT_GAP = 300, 1.5

local function lineFS(tt, i)
    local name = tt.GetName and tt:GetName()
    return name and _G[name .. "TextLeft" .. i]
end

---------------------------------------------------------------- pure helpers
-- The ID line text for a kind ("Spell ID: 123").
local ID_LABEL = {
    spell = L.TOOLTIP_ID_SPELL, item = L.TOOLTIP_ID_ITEM, unit = L.TOOLTIP_ID_NPC, aura = L.TOOLTIP_ID_SPELL,
    currency = L.TOOLTIP_ID_CURRENCY, quest = L.TOOLTIP_ID_QUEST, achievement = L.TOOLTIP_ID_ACHIEVEMENT,
    mount = L.TOOLTIP_ID_MOUNT,
}
function M.IDLine(kind, id)
    local label = ID_LABEL[kind]
    return label and label:format(id) or nil
end

-- "Bags 3 · Bank 10 · Warband 2", leaving out empty places; nil when you have none.
function M.CountLine(bags, withBank, withAll)
    bags, withBank, withAll = bags or 0, withBank or bags or 0, withAll or withBank or bags or 0
    local parts = {}
    if bags > 0 then parts[#parts + 1] = L.TOOLTIP_COUNT_BAGS:format(bags) end
    if withBank - bags > 0 then parts[#parts + 1] = L.TOOLTIP_COUNT_BANK:format(withBank - bags) end
    if withAll - withBank > 0 then parts[#parts + 1] = L.TOOLTIP_COUNT_WARBAND:format(withAll - withBank) end
    return #parts > 0 and table.concat(parts, "  ") or nil
end

---------------------------------------------------------------- IDs and item counts
-- NPC IDs come from UnitCreatureID (never parsed out of a GUID; AGENTS.md rule 4).
function M:AddID(tt, kind, data, unit)
    if not (self.db.ids and self.db.idKinds[kind]) or not data then return end
    local id = data.id
    if kind == "unit" then id = unit and UnitCreatureID(unit) end
    if not (plain(id) and type(id) == "number") then return end
    GameTooltip_AddColoredLine(tt, M.IDLine(kind, id), GRAY_FONT_COLOR)
end

function M:AddItemCount(tt, data)
    local id = data and data.id
    if not (plain(id) and type(id) == "number") then return end
    local bags = C_Item.GetItemCount(id)
    local bank = C_Item.GetItemCount(id, true, false, true)
    local all = C_Item.GetItemCount(id, true, false, true, true)
    if not plain(bags, bank, all) then return end
    local text = M.CountLine(bags, bank, all)
    if text then GameTooltip_AddColoredLine(tt, text, GRAY_FONT_COLOR) end
end

---------------------------------------------------------------- item extras (S17)
-- "keystone:180653:mapID:level:affix…" -> mapID, level, { affixIDs } (nil for anything else; pure).
function M.ParseKeystone(link)
    if type(link) ~= "string" then return nil end
    local body = link:match("keystone:([%d:]+)")
    if not body then return nil end
    local parts = {}
    for n in body:gmatch("(%d+)") do parts[#parts + 1] = tonumber(n) end
    local mapID, level = parts[2], parts[3]
    if not (mapID and mapID > 0 and level) then return nil end
    local affixes = {}
    for i = 4, #parts do if parts[i] > 0 then affixes[#affixes + 1] = parts[i] end end
    return mapID, level, affixes
end

-- "33:00" for a number of seconds (pure).
function M.Clock(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- Does the tooltip data already carry the game's sell price line?
local function hasSellPrice(data)
    local kind = Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice
    for _, line in ipairs(type(data) == "table" and data.lines or {}) do
        if plain(line) and line.type == kind and kind ~= nil then return true end
    end
    return false
end

-- true / false when the item is something you collect (appearance, toy, mount, pet), nil otherwise.
function M.Collected(id, link)
    if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(id) then return PlayerHasToy(id) and true or false end
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountID = C_MountJournal.GetMountFromItem(id)
        if plain(mountID) and mountID then
            local collected = select(11, C_MountJournal.GetMountInfoByID(mountID))
            return plain(collected) and collected and true or false
        end
    end
    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local species = select(13, C_PetJournal.GetPetInfoByItemID(id))
        if plain(species) and type(species) == "number" then
            local owned = C_PetJournal.GetNumCollectedInfo(species)
            return plain(owned) and (owned or 0) > 0
        end
    end
    if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogByItemInfo and link then
        local _, sourceID = C_TransmogCollection.GetItemInfo(link)
        if plain(sourceID) and sourceID then
            local has = C_TransmogCollection.PlayerHasTransmogByItemInfo(link)
            if plain(has) then return has and true or false end
        end
    end
    return nil
end

function M:ItemExtras(tt, data)
    local db = self.db
    local id = data and data.id
    local link = data and data.hyperlink
    if not plain(link) then link = nil end
    if db.keystone and link and ns:Supports("mythicplus") then
        local mapID, level = M.ParseKeystone(link)
        if mapID then
            local _, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
            if plain(limit) and type(limit) == "number" and limit > 0 then
                GameTooltip_AddNormalLine(tt, L.TOOLTIP_KEY_TIMER:format(level, M.Clock(limit)))
            end
            local best = C_MythicPlus.GetSeasonBestForMap(mapID)
            if plain(best) and type(best) == "table" and best.level then
                GameTooltip_AddNormalLine(tt, L.TOOLTIP_KEY_BEST:format(best.level, M.Clock(best.durationSec)))
            end
        end
    end
    if not (plain(id) and type(id) == "number") then return end
    if db.collected then
        local has = M.Collected(id, link)
        if has ~= nil then
            GameTooltip_AddColoredLine(tt, has and L.TOOLTIP_COLLECTED or L.TOOLTIP_NOT_COLLECTED,
                has and GREEN_FONT_COLOR or GRAY_FONT_COLOR)
        end
    end
    if db.vendorPrice and not hasSellPrice(data) then
        local price = select(11, C_Item.GetItemInfo(id))
        if plain(price) and type(price) == "number" and price > 0 then
            GameTooltip_AddNormalLine(tt, L.TOOLTIP_VENDOR_PRICE:format(tostring(C_CurrencyInfo.GetCoinTextureString(price))))
        end
    end
end

---------------------------------------------------------------- name colours, guild rank, PvP line
local function colourName(tt, unit, isPlayer)
    local fs = lineFS(tt, 1)
    if not fs then return end
    if isPlayer then
        if not M.db.classNames then return end
        local _, classFile = UnitClass(unit)
        if plain(classFile) and classFile then fs:SetTextColor(ns.Util.ClassColor(classFile)) end
        return
    end
    if not M.db.reactionNames then return end
    local tapped = UnitIsTapDenied(unit)
    if plain(tapped) and tapped then
        fs:SetTextColor(Theme:Color("text.muted"))
        return
    end
    local reaction = UnitReaction(unit, "player")
    local c = plain(reaction) and reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if c then fs:SetTextColor(c.r, c.g, c.b) end
end

local function addRank(tt, unit)
    local guild, rank = GetGuildInfo(unit)
    if not (plain(guild, rank) and guild and rank) then return end
    for i = 2, math.min(tt:NumLines(), 4) do
        local fs = lineFS(tt, i)
        local text = fs and fs:GetText()
        if plain(text) and text and text:find(guild, 1, true) then
            fs:SetText(text .. " " .. Theme:Wrap("(" .. rank .. ")", "text.muted"))
            return
        end
    end
end

local function hidePvP(tt)
    for i = 2, tt:NumLines() do
        local fs = lineFS(tt, i)
        local text = fs and fs:GetText()
        if plain(text) and text == PVP then
            fs:SetText("")
            return
        end
    end
end

function M:UnitLines(tt, unit, isPlayer)
    colourName(tt, unit, isPlayer)
    if isPlayer and self.db.guildRank then addRank(tt, unit) end
    if self.db.hidePvP then hidePvP(tt) end
    if isPlayer and self.db.realm then
        local _, realm = UnitName(unit)
        if plain(realm) and realm and realm ~= "" then
            GameTooltip_AddNormalLine(tt, L.TOOLTIP_REALM_LINE:format(realm))
        end
    end
end

---------------------------------------------------------------- targeted by
local function groupUnits()
    local out = {}
    local n = GetNumGroupMembers()
    if not plain(n) or n == 0 then return out end
    local raid = IsInRaid()
    for i = 1, raid and n or n - 1 do out[#out + 1] = (raid and "raid" or "party") .. i end
    if not raid then out[#out + 1] = "player" end
    return out
end

local function addTargetedBy(tt, unit)
    local names = {}
    for _, member in ipairs(groupUnits()) do
        local same = UnitIsUnit(member .. "target", unit)
        if plain(same) and same then
            local name = UnitName(member)
            local _, classFile = UnitClass(member)
            if plain(name, classFile) and name then
                names[#names + 1] = classFile and ns.Util.WrapClass(classFile, name) or name
            end
        end
    end
    if #names > 0 then GameTooltip_AddNormalLine(tt, L.TOOLTIP_TARGETED_BY:format(#names, table.concat(names, ", "))) end
end

---------------------------------------------------------------- inspect: item level and specialization
local cache, pending, pendingAt = {}, nil, 0

local function specName(specID)
    if not (plain(specID) and type(specID) == "number" and specID > 0) then return nil end
    local _, name = GetSpecializationInfoByID(specID)
    return plain(name) and name or nil
end

local function ownInfo()
    local _, equipped = GetAverageItemLevel()
    local index = C_SpecializationInfo.GetSpecialization()
    local name = index and select(2, C_SpecializationInfo.GetSpecializationInfo(index))
    return plain(equipped) and equipped, plain(name) and name or nil
end

local function addInspectLines(tt, ilvl, spec)
    if type(ilvl) == "number" and ilvl > 0 then
        GameTooltip_AddNormalLine(tt, L.TOOLTIP_ILVL_LINE:format(("%.0f"):format(ilvl)))
    end
    if spec then GameTooltip_AddNormalLine(tt, L.TOOLTIP_SPEC_LINE:format(spec)) end
end

local function addInspect(tt, unit)
    local isMe = UnitIsUnit(unit, "player")
    if plain(isMe) and isMe then
        addInspectLines(tt, ownInfo())
        return
    end
    local guid = UnitGUID(unit)
    if not (plain(guid) and guid) then return end
    local c = cache[guid]
    if c and GetTime() - c.time < INSPECT_TTL then
        addInspectLines(tt, c.ilvl, c.spec)
        return
    end
    if InCombatLockdown() or (InspectFrame and InspectFrame:IsShown()) then return end
    if GetTime() - pendingAt < INSPECT_GAP then return end
    local can = CanInspect(unit)
    if not (plain(can) and can) then return end
    pending, pendingAt = guid, GetTime()
    NotifyInspect(unit)
end

function M:OnInspectReady(guid)
    if not (plain(guid) and guid and guid == pending) then return end
    pending = nil
    local unit = UnitTokenFromGUID(guid)
    if not (plain(unit) and unit) then return end
    local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
    local spec = specName(C_SpecializationInfo.GetInspectSpecialization(unit))
    cache[guid] = { time = GetTime(), ilvl = plain(ilvl) and ilvl or nil, spec = spec }
    -- Rebuild the open tooltip so the cached lines appear.
    if GameTooltip:IsShown() and not GameTooltip:IsForbidden() then
        local _, shown = GameTooltip:GetUnit()
        local shownGUID = plain(shown) and shown and UnitGUID(shown)
        if plain(shownGUID) and shownGUID == guid and GameTooltip.RefreshData then GameTooltip:RefreshData() end
    end
end

---------------------------------------------------------------- mount
local function addMount(tt, unit)
    if InCombatLockdown() then return end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not (plain(aura) and aura) then return end
        local spellID = aura.spellId
        if not plain(spellID) then return end
        local mountID = spellID and C_MountJournal.GetMountFromSpell(spellID)
        if plain(mountID) and mountID then
            local name, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(mountID)
            if plain(name, collected) and name then
                local mark = collected and (" " .. Theme:Wrap(L.TOOLTIP_MOUNT_OWNED, "state.success")) or ""
                GameTooltip_AddNormalLine(tt, L.TOOLTIP_MOUNT_LINE:format(name) .. mark)
            end
            return
        end
    end
end

---------------------------------------------------------------- health text on the bar
local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100
local healthFS

local function setHealth()
    if not (healthFS and M.db.healthText and M:IsEnabled()) then
        if healthFS then healthFS:SetText("") end
        return
    end
    local _, unit = GameTooltip:GetUnit()
    if not (plain(unit) and unit) then healthFS:SetText(""); return end
    local ok = pcall(healthFS.SetFormattedText, healthFS, "%.0f%%", UnitHealthPercent(unit, true, ScaleTo100))
    if not ok then healthFS:SetText("") end
end

local function ensureHealth()
    local bar = GameTooltip.StatusBar
    if healthFS or not bar then return end
    healthFS = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthFS:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar:HookScript("OnValueChanged", function() pcall(setHealth) end)
end

---------------------------------------------------------------- entry points
function M:UnitExtras(tt, unit, isPlayer, data)
    if isPlayer and self.db.targetedBy and IsInGroup() then addTargetedBy(tt, unit) end
    if isPlayer and self.db.inspect then addInspect(tt, unit) end
    if isPlayer and self.db.mount then addMount(tt, unit) end
    if tt == GameTooltip and self.db.healthText then setHealth() end
    if not isPlayer then self:AddID(tt, "unit", data, unit) end
end

---------------------------------------------------------------- gathering skill (herbs, ore, skins, fishing)
-- Skill lines of the gathering professions (game IDs): Herbalism, Mining, Skinning, Fishing.
local GATHER = { [182] = true, [186] = true, [393] = true, [356] = true }

-- Your gathering professions: { { name, rank, max }, … }.
function M.GatherSkills()
    local out = {}
    if type(GetProfessions) ~= "function" then return out end
    local list = { GetProfessions() }
    for i = 1, 6 do
        local index = list[i]
        if index then
            local name, _, rank, max, _, _, line = GetProfessionInfo(index)
            if GATHER[line] and plain(name) and type(name) == "string" then
                out[#out + 1] = { name = name, rank = rank, max = max }
            end
        end
    end
    return out
end

-- The line to add under a node's "Requires <skill> <n>" line: your rank, coloured by whether you can gather
-- it. nil when the text names none of your gathering skills.
function M.GatherLine(text, skills)
    if type(text) ~= "string" or not plain(text) then return nil end
    for _, sk in ipairs(skills) do
        if text:find(sk.name, 1, true) then
            local need = tonumber(text:match("(%d+)"))
            local ok = not need or (type(sk.rank) == "number" and sk.rank >= need)
            return L.TOOLTIP_GATHER:format(sk.name, sk.rank or 0, sk.max or 0), ok
        end
    end
    return nil
end

local function onGatherShow(tt)
    if not (M:IsEnabled() and M.db.gathering) or tt:GetUnit() then return end
    local skills = M.GatherSkills()
    if #skills == 0 then return end
    for i = 2, math.min(tt:NumLines() or 0, 6) do
        local fs = lineFS(tt, i)
        local line, ok = M.GatherLine(fs and fs:GetText(), skills)
        if line then
            tt:AddLine(line, Theme:Color(ok and "state.success" or "state.danger"))
            tt:Show()
            return line
        end
    end
end
M.OnGatherShow = onGatherShow

function M:EnableExtras()
    ensureHealth()
    GameTooltip:HookScript("OnShow", function(tt) pcall(onGatherShow, tt) end)
    ns.Events:On("INSPECT_READY", self, function(_, guid) M:OnInspectReady(guid) end)
end
