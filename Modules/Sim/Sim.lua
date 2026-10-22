local _, ns = ...
local L, Secret = ns.L, ns.Secret

--[[ Sim: SimulationCraft for Phoenix, run by the Phoenix app on your PC.

    WoW addons cannot start programs or use the network, so a sim takes two reloads:
      1. On the Sim page you tick bag items and press Prepare: Phoenix writes a request (your SimC profile, the
         ticked items, the fight) into PhoenixUISimDB. Reload, and WoW saves it to disk.
      2. The Phoenix app sees the saved file within seconds, checks every line, runs SimulationCraft (downloaded
         once, only after you agree in the app) and writes the answer into Phoenix_UI\Sim\Results.lua.
      3. On the next reload Phoenix reads that file, keeps the result in PhoenixUISimDB (so a reinstall loses
         nothing) and shows it on the Sim page, on item tooltips and on the bag upgrade arrows.

    Contract with the app (uploader/sim.go): PhoenixUISimDB = { schema = 1, requests = { [id] = { id, created,
    char, mode, fight = { style, length, targets }, profile, equipped = { item… }, items = { item… } } } } with
    item = { key, slot, line, name, level, itemID, twoHand }. Results arrive as PhoenixUISimResults (schema 1).
    Item keys are "itemID:bonusIDs…" (sorted), the same on both sides and on tooltips. ]]
local M = ns:NewModule("Sim", {
    label = "SIM", desc = "SIM_DESC", category = "utility", order = 74, icon = "sim", feature = "sim",
    defaults = {
        mode = "compare",
        fight = { style = "Patchwerk", length = 300, targets = 1 },
        tooltip = true,
        maxAge = 14,
        bank = false, vault = false,
    },
})

local SCHEMA = 1
local HISTORY = 10
local IMPORT_DAYS = 30 -- results and import marks older than this are ignored
M.MODES = { "gear", "compare", "best", "weights" }
M.STYLES = { "Patchwerk", "CastingPatchwerk", "LightMovement", "HeavyMovement", "HecticAddCleave", "DungeonSlice",
    "DungeonRoute" }
M.MAX_COMBOS = 400
M.MAX_ITEMS = 60

---------------------------------------------------------------- saved data
local db -- PhoenixUISimDB

local function bind()
    if db then return db end
    local sv = type(PhoenixUISimDB) == "table" and PhoenixUISimDB or {}
    if sv.schema ~= SCHEMA then sv = { schema = SCHEMA } end
    for _, k in ipairs({ "requests", "results", "imported", "bank" }) do
        if type(sv[k]) ~= "table" then sv[k] = {} end
    end
    PhoenixUISimDB = sv
    db = sv
    return sv
end
M.Data = function() return bind() end

-- "Name-Realm" (the realm without spaces, as the game writes it in names).
function M:CharKey()
    local name, realm = UnitName("player"), GetNormalizedRealmName()
    if type(realm) ~= "string" or realm == "" then realm = tostring(GetRealmName() or ""):gsub("[%s%-]", "") end
    return ("%s-%s"):format(tostring(name or "?"), realm)
end

---------------------------------------------------------------- results from the app
-- Plain values only: the file is ours, but it is still read defensively.
local function num(v) return type(v) == "number" and v == v and v or 0 end
local function str(v, max) return type(v) == "string" and v:sub(1, max or 200) or "" end

local function cleanSet(s)
    if type(s) ~= "table" then return nil end
    local keys = {}
    for _, k in ipairs(type(s.keys) == "table" and s.keys or {}) do
        if type(k) == "string" then keys[#keys + 1] = k end
    end
    return { label = str(s.label, 200), dps = num(s.dps), delta = num(s.delta), pct = num(s.pct), keys = keys }
end

local function cleanResult(r)
    if type(r) ~= "table" or type(r.id) ~= "string" then return nil end
    local out = { id = r.id, state = str(r.state, 16), error = str(r.error, 300), finished = num(r.finished),
        seconds = num(r.seconds), mode = str(r.mode, 16), char = str(r.char, 64), spec = str(r.spec, 40),
        simc = str(r.simc, 20), dps = num(r.dps), dpsError = num(r.dpsError), sets = {}, items = {}, weights = {} }
    local f = type(r.fight) == "table" and r.fight or {}
    out.fight = { style = str(f.style, 24), length = num(f.length), targets = num(f.targets) }
    for _, s in ipairs(type(r.sets) == "table" and r.sets or {}) do out.sets[#out.sets + 1] = cleanSet(s) end
    for k, s in pairs(type(r.items) == "table" and r.items or {}) do
        if type(k) == "string" then out.items[k] = cleanSet(s) end
    end
    for k, v in pairs(type(r.weights) == "table" and r.weights or {}) do
        if type(k) == "string" and type(v) == "number" then out.weights[k] = v end
    end
    return out
end
M.CleanResult = cleanResult

-- Takes what the app wrote (PhoenixUISimResults, loaded from Sim\Results.lua) into the saved data.
function M:Import()
    local sv = bind()
    local file = PhoenixUISimResults
    PhoenixUISimResults = nil
    if type(file) ~= "table" or file.schema ~= SCHEMA or type(file.results) ~= "table" then return 0 end
    local n, cut = 0, time() - IMPORT_DAYS * 86400
    for _, raw in pairs(file.results) do
        local r = cleanResult(raw)
        -- older than the import marks: it was seen (or deleted) before, so it must not come back
        if r and r.finished >= cut and sv.imported[r.id] ~= r.finished then
            sv.imported[r.id] = r.finished
            if r.state ~= "waiting" then
                sv.requests[r.id] = nil
            end
            sv.results[r.id] = r
            n = n + 1
        end
    end
    self:Prune()
    return n
end

-- Keeps the last HISTORY results per character (and forgets old import marks).
function M:Prune()
    local sv = bind()
    local byChar = {}
    for id, r in pairs(sv.results) do
        byChar[r.char] = byChar[r.char] or {}
        table.insert(byChar[r.char], r)
        if r.state ~= "waiting" and sv.requests[id] then sv.requests[id] = nil end
    end
    for _, list in pairs(byChar) do
        table.sort(list, function(a, b) return a.finished > b.finished end)
        for i = HISTORY + 1, #list do sv.results[list[i].id] = nil end
    end
    local cut = time() - IMPORT_DAYS * 86400
    for id, at in pairs(sv.imported) do
        if type(at) ~= "number" or at < cut then sv.imported[id] = nil end
    end
    self.index = nil
end

-- This character's results, newest first.
function M:History()
    local me, out = self:CharKey(), {}
    for _, r in pairs(bind().results) do
        if r.char == me and r.state ~= "waiting" then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return a.finished > b.finished end)
    return out
end

function M:Latest()
    return self:History()[1]
end

function M:Delete(id)
    local sv = bind()
    sv.results[id] = nil
    self.index = nil
    if self.shown == id then self.shown = nil end
    ns.Events:Fire("PUI_SIM_RESULTS")
    ns.Events:Fire("PUI_SIM_CHANGED")
end

---------------------------------------------------------------- per item results (tooltips, bag arrows)
-- [item key] = { pct, delta, dps, finished } from this character's newest done result that sims that item.
function M:Index()
    if self.index then return self.index end
    local index, cut = {}, time() - self.db.maxAge * 86400
    for _, r in ipairs(self:History()) do
        if r.state == "done" and r.finished >= cut then
            for key, s in pairs(r.items) do
                if not index[key] then
                    index[key] = { pct = s.pct, delta = s.delta, dps = s.dps, finished = r.finished, mode = r.mode }
                end
            end
        end
    end
    self.index = index
    return index
end

-- The sim result for an item link (nil when it was never simmed); safe for secret links.
function M:ItemResult(link)
    if not (self.active and link) or Secret.IsSecret(link) then return nil end
    local key = ns.SimExport.Key(link)
    return key and self:Index()[key]
end

-- "+1.8% DPS (+4,120)" with colour, for tooltips.
function M:Describe(r)
    local up = r.pct > 0
    local color = up and "ff3fcf6f" or (r.pct < 0 and "ffe0574f" or "ffb0b0b0")
    local delta = BreakUpLargeNumbers(math.floor(math.abs(r.delta) + 0.5))
    return ("|c%s%s%.1f%% (%s%s)|r"):format(color, up and "+" or (r.pct < 0 and "-" or "±"), math.abs(r.pct),
        r.delta < 0 and "-" or "+", delta)
end

function M:Age(finished)
    local s = math.max(0, time() - finished)
    if s < 3600 then return L.SIM_AGE_MIN:format(math.max(1, math.floor(s / 60))) end
    if s < 86400 then return L.SIM_AGE_HOURS:format(math.floor(s / 3600)) end
    return L.SIM_AGE_DAYS:format(math.floor(s / 86400))
end

---------------------------------------------------------------- gear
local X = ns.SimExport
local GROUP_ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet", "finger",
    "trinket", "main_hand", "off_hand", "weapon" }
M.GROUP_ORDER = GROUP_ORDER
local EQUIP_GROUP = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_CLOAK = "back",
    INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
    INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket", INVTYPE_WEAPONMAINHAND = "main_hand", INVTYPE_2HWEAPON = "main_hand",
    INVTYPE_RANGED = "main_hand", INVTYPE_RANGEDRIGHT = "main_hand", INVTYPE_WEAPON = "main_hand",
    INVTYPE_WEAPONOFFHAND = "off_hand", INVTYPE_SHIELD = "off_hand", INVTYPE_HOLDABLE = "off_hand",
}
-- Equipped slot -> group (where the item sits now).
local SLOT_GROUP = { [1] = "head", [2] = "neck", [3] = "shoulder", [15] = "back", [5] = "chest", [9] = "wrist",
    [10] = "hands", [6] = "waist", [7] = "legs", [8] = "feet", [11] = "finger", [12] = "finger", [13] = "trinket",
    [14] = "trinket", [16] = "main_hand", [17] = "off_hand" }
M.SLOT_GROUP = SLOT_GROUP
M.PAPERDOLL = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }
local WAND = 19 -- Enum.ItemWeaponSubclass.Wand

-- group, twoHand for an item (nil when it is not gear SimC can compare).
local function groupOf(equipLoc, subclassID)
    local g = EQUIP_GROUP[equipLoc]
    if not g then return nil end
    local twoHand = equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED"
        or (equipLoc == "INVTYPE_RANGEDRIGHT" and subclassID ~= WAND)
    if twoHand and X.SpecID() == X.FURY and equipLoc == "INVTYPE_2HWEAPON" then
        return "weapon", false
    end
    if equipLoc == "INVTYPE_WEAPON" and CanDualWield() then
        return "weapon", false
    end
    return g, twoHand and true or false
end

local function itemName(link)
    local name = link:match("|h%[(.-)%]|h")
    return name and name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", "") or "?"
end

local function describeItem(link, level, extra)
    local itemID, _, _, equipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if not itemID then return nil end
    local group, twoHand = groupOf(equipLoc, subclassID)
    local key, line = X.Key(link), X.ItemLine(link)
    if not (group and key and line) then return nil end
    local item = { key = key, slot = group, line = line, name = itemName(link):sub(1, 80), level = level or 0,
        itemID = itemID, twoHand = twoHand, link = link, icon = icon, equipLoc = equipLoc, classID = classID,
        subclassID = subclassID, quality = C_Item.GetItemQualityByID(link) or 1 }
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
end

-- What you wear, by equipment slot.
function M:Equipped()
    local out = {}
    for _, slot in ipairs(self.PAPERDOLL) do
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        local link = C_Item.DoesItemExist(loc) and C_Item.GetItemLink(loc)
        if link and not Secret.IsSecret(link) then
            local it = describeItem(link, C_Item.GetCurrentItemLevel(loc), { equipSlot = slot })
            if it then
                it.slot = SLOT_GROUP[slot]
                out[slot] = it
            end
        end
    end
    return out
end

local ARMOR_CLASS = Enum.ItemClass.Armor
-- Gear in the bags you could wear (your armour type, usable).
function M:BagItems()
    local out = {}
    local _, classFile = UnitClass("player")
    local armor = ns.modules.Bags and ns.modules.Bags.ARMOR or {}
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and not Secret.IsSecret(link) and info.itemID and C_PlayerInfo.CanUseItem(info.itemID) then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local it = describeItem(link, C_Item.GetCurrentItemLevel(loc), { bag = bag, bagSlot = slot })
                local wrongArmor = it and it.classID == ARMOR_CLASS and it.equipLoc ~= "INVTYPE_CLOAK"
                    and it.subclassID and it.subclassID >= 1 and it.subclassID <= 4 and armor[classFile]
                    and it.subclassID ~= armor[classFile]
                if it and not wrongArmor then out[#out + 1] = it end
            end
        end
    end
    for _, it in ipairs(self:ExtraItems()) do out[#out + 1] = it end
    table.sort(out, function(a, b)
        if a.slot ~= b.slot then return (tIndexOf(GROUP_ORDER, a.slot) or 99) < (tIndexOf(GROUP_ORDER, b.slot) or 99) end
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    return out
end

---------------------------------------------------------------- bank and Great Vault (S16)
-- The bank is only readable while it is open: its wearable gear is remembered per character (links and item
-- levels; saved with the sim data) and offered when "Include bank" is on. Vault picks are read live from
-- C_WeeklyRewards once rewards are ready to claim.
local function bankBags()
    local ids = C_Bank and C_Bank.FetchPurchasedBankTabIDs and Enum.BankType
        and C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
    return type(ids) == "table" and ids or {}
end

function M:ScanBank()
    local list = {}
    for _, bag in ipairs(bankBags()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and not Secret.IsSecret(link) and info.itemID and C_Item.IsEquippableItem(link) then
                local level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
                list[#list + 1] = { link = link, level = level or 0 }
            end
        end
    end
    bind().bank[self:CharKey()] = { scanned = time(), items = list }
    ns.Events:Fire("PUI_SIM_CHANGED")
end

-- Cached entries -> picker items (same shape as bag items, plus source = "bank" | "vault").
function M.FromLinks(entries, source)
    local out = {}
    for _, e in ipairs(entries or {}) do
        local it = describeItem(e.link, e.level, { source = source })
        if it then out[#out + 1] = it end
    end
    return out
end

function M:VaultLinks()
    local out = {}
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards()) then
        return out
    end
    for _, a in ipairs(C_WeeklyRewards.GetActivities() or {}) do
        for _, r in ipairs(a.rewards or {}) do
            local link = r.itemDBID and C_WeeklyRewards.GetItemHyperlink(r.itemDBID)
            if type(link) == "string" and not Secret.IsSecret(link) and C_Item.IsEquippableItem(link) then
                out[#out + 1] = { link = link, level = C_Item.GetDetailedItemLevelInfo(link) or 0 }
            end
        end
    end
    return out
end

function M:ExtraItems()
    local out = {}
    if self.db.bank then
        local cache = bind().bank[self:CharKey()]
        for _, it in ipairs(M.FromLinks(cache and cache.items, "bank")) do out[#out + 1] = it end
    end
    if self.db.vault then
        for _, it in ipairs(M.FromLinks(self:VaultLinks(), "vault")) do out[#out + 1] = it end
    end
    return out
end

-- Does an item of `group` compete with the equipped `slotGroup`?
function M.Fits(group, slotGroup)
    if group == slotGroup then return true end
    return group == "weapon" and (slotGroup == "main_hand" or slotGroup == "off_hand")
end

---------------------------------------------------------------- selection and requests
M.selected = {} -- [item key] = true, this session

function M:Toggle(key, on)
    self.selected[key] = on or nil
    ns.Events:Fire("PUI_SIM_CHANGED")
end

function M:SelectedItems(bagItems)
    local out, seen = {}, {}
    for _, it in ipairs(bagItems or self:BagItems()) do
        if self.selected[it.key] and not seen[it.key] then
            seen[it.key] = true
            out[#out + 1] = it
        end
    end
    return out
end

-- Number of gear sets a "best" sim would run (the app enumerates the same combinations).
function M:Combos(items, equipped)
    local count = {}
    for _, it in ipairs(items) do
        local g = it.slot == "weapon" and "main_hand" or it.slot
        count[g] = (count[g] or 0) + 1
    end
    local total = 1
    for g, n in pairs(count) do
        for _, e in pairs(equipped) do if e.slot == g then n = n + 1 end end
        total = total * ((g == "finger" or g == "trinket") and math.max(1, n * (n - 1) / 2) or n)
    end
    return total - 1
end

-- Sets a sim of this mode would run: 1 for gear / weights, one per item and slot for compare.
function M:SetCount(mode, items, equipped)
    if mode == "best" then return self:Combos(items, equipped) end
    if mode ~= "compare" then return 0 end
    local n = 0
    for _, it in ipairs(items) do n = n + ((it.slot == "finger" or it.slot == "trinket" or it.slot == "weapon") and 2 or 1) end
    return n
end

local function newID()
    return ("%08x%06x"):format(time(), math.random(0, 0xffffff))
end

local function pack(it)
    return { key = it.key, slot = it.slot, line = it.line, name = it.name, level = it.level, itemID = it.itemID,
        twoHand = it.twoHand or nil }
end

-- Writes a request for the app. Returns id or nil, error key.
function M:Prepare()
    if InCombatLockdown() then return nil, "SIM_ERR_COMBAT" end
    local mode = self.db.mode
    local bag, equipped = self:BagItems(), self:Equipped()
    local items = self:SelectedItems(bag)
    if (mode == "compare" or mode == "best") and #items == 0 then return nil, "SIM_ERR_NOTHING" end
    if #items > self.MAX_ITEMS then return nil, "SIM_ERR_TOO_MANY" end
    if mode == "best" and self:Combos(items, equipped) > self.MAX_COMBOS then return nil, "SIM_ERR_COMBOS" end
    local profile, err = X.Profile()
    if not profile then return nil, err end
    local sv, me = bind(), self:CharKey()
    for id, r in pairs(sv.requests) do
        if r.char == me then sv.requests[id] = nil end -- one open request per character
    end
    local req = { id = newID(), created = time(), char = me, mode = mode,
        fight = { style = self.db.fight.style, length = self.db.fight.length, targets = self.db.fight.targets },
        profile = profile, equipped = {}, items = {} }
    for _, slot in ipairs(self.PAPERDOLL) do
        if equipped[slot] then req.equipped[#req.equipped + 1] = pack(equipped[slot]) end
    end
    if mode == "compare" or mode == "best" then
        for _, it in ipairs(items) do req.items[#req.items + 1] = pack(it) end
    end
    sv.requests[req.id] = req
    self.prepared = req.id
    ns.Events:Fire("PUI_SIM_CHANGED")
    return req.id
end

function M:Cancel()
    local sv, me = bind(), self:CharKey()
    for id, r in pairs(sv.requests) do
        if r.char == me then sv.requests[id] = nil end
    end
    self.prepared = nil
    ns.Events:Fire("PUI_SIM_CHANGED")
end

function M:Pending()
    local me = self:CharKey()
    for _, r in pairs(bind().requests) do
        if r.char == me then return r end
    end
end

-- state, text: what the page says about the current request.
--   ready   prepared this session: reload so WoW writes it to disk
--   sent    on disk: the app picks it up within seconds; the answer shows after the next reload
--   waiting the app answered that it cannot run yet (SimulationCraft download not allowed)
--   idle    nothing open
function M:Status()
    local r = self:Pending()
    if r then
        if self.prepared == r.id then return "ready", L.SIM_STATUS_READY end
        local result = bind().results[r.id]
        if result and result.state == "waiting" then return "waiting", L.SIM_STATUS_WAITING end
        local mins = math.floor((time() - (r.created or time())) / 60)
        if mins >= 10 then return "sent", L.SIM_STATUS_SENT_LONG end
        return "sent", L.SIM_STATUS_SENT
    end
    return "idle", L.SIM_STATUS_IDLE
end

---------------------------------------------------------------- sample data (page test mode, preview)
M.SAMPLE = {
    id = "sample", state = "done", finished = 0, seconds = 2.4, mode = "compare", spec = "Fire Mage",
    simc = "1210-01", dps = 229040, dpsError = 182, fight = { style = "Patchwerk", length = 300, targets = 1 },
    sets = {
        { label = "SIM_SAMPLE_ITEM1", dps = 233702, delta = 4662, pct = 2.04 },
        { label = "SIM_SAMPLE_ITEM2", dps = 231130, delta = 2090, pct = 0.91 },
        { label = "SIM_SAMPLE_ITEM3", dps = 229655, delta = 615, pct = 0.27 },
        { label = "SIM_SAMPLE_ITEM4", dps = 227390, delta = -1650, pct = -0.72 },
    },
    weights = { Int = 1, Haste = 0.504, Vers = 0.558, Mastery = 0.549, Crit = 0.223 },
}

-- A copy of the sample with translated labels.
function M:Sample()
    local s = CopyTable(self.SAMPLE)
    s.sets = {}
    for i, set in ipairs(self.SAMPLE.sets) do
        s.sets[i] = { label = L[set.label], dps = set.dps, delta = set.delta, pct = set.pct }
    end
    s.weights = CopyTable(self.SAMPLE.weights)
    s.finished = time() - 720
    return s
end

---------------------------------------------------------------- lifecycle
function M:OnInitialize()
    bind()
end

function M:OnEnable()
    self.active = true
    if self:Import() > 0 then
        local latest = self:Latest()
        if latest then ns:Print(L.SIM_ARRIVED, latest.state == "done" and L.SIM_DONE or L.SIM_FAILED) end
    end
    ns.Events:On("PLAYER_EQUIPMENT_CHANGED", self, function() ns.Events:Fire("PUI_SIM_CHANGED") end)
    ns.Events:On("BAG_UPDATE_DELAYED", self, function()
        if self.bankOpen then self:ScanBank() else ns.Events:Fire("PUI_SIM_CHANGED") end
    end)
    ns.Events:On("BANKFRAME_OPENED", self, function() self.bankOpen = true; self:ScanBank() end)
    ns.Events:On("BANKFRAME_CLOSED", self, function() self.bankOpen = false end)
    ns.Events:On("WEEKLY_REWARDS_UPDATE", self, function() ns.Events:Fire("PUI_SIM_CHANGED") end)
end

-- Settings changed (the age limit): tooltips and bag arrows read the index again.
function M:Refresh()
    self.index = nil
    ns.Events:Fire("PUI_SIM_RESULTS")
end

function M:OnDisable()
    self.active = false
    self.index = nil
    ns.Events:OffAll(self)
end
