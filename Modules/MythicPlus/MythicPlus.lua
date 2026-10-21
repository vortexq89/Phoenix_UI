local _, ns = ...
local L = ns.L

--[[ MythicPlus: a run timer overlay (Timer.lua), slots your keystone as soon as the Font of Power
    opens and reports the new key after a run. Bag and run data are plain (not secret); nothing here
    touches combat data. ]]
local M = ns:NewModule("MythicPlus", {
    label = "MYTHICPLUS", desc = "MYTHICPLUS_DESC", category = "utility", order = 30,
    defaults = {
        autoInsert = true, reportKey = true,
        timer = true, timerForces = true, timerBosses = true, timerDeaths = true, timerBest = true,
        timerSplits = true, timerPull = true,
    },
    -- run: splits of the key in progress (survives /reload); best: fastest timed run per "mapID:level";
    -- bestSplits: that run's boss and forces splits, compared live on the timer.
    globalDefaults = { run = { splits = {} }, best = {}, bestSplits = {} },
})

local function findKeystone()
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and C_Item.IsItemKeystoneByID(info.itemID) then return bag, slot end
        end
    end
end

local function insert()
    -- Never pick up the key while the cursor holds something: PickupContainerItem would swap them.
    if not M.db.autoInsert or C_ChallengeMode.HasSlottedKeystone() or CursorHasItem() then return end
    local bag, slot = findKeystone()
    if not bag then return end
    C_Container.PickupContainerItem(bag, slot)
    if CursorHasItem() then
        C_ChallengeMode.SlotKeystone()
        ns:Print(L.MPLUS_INSERTED)
    end
end

local function describeKey()
    local mapID, level = C_MythicPlus.GetOwnedKeystoneChallengeMapID(), C_MythicPlus.GetOwnedKeystoneLevel()
    if not (mapID and level) then return nil end
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    return name and ("%s +%d"):format(name, level)
end

function M:OnEnable()
    self:EnableTimer()
    ns.Events:On("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN", self, insert)
    ns.Events:On("CHALLENGE_MODE_COMPLETED", self, function()
        if not M.db.reportKey then return end
        -- the new keystone is granted a moment after completion
        C_Timer.After(3, function()
            local key = describeKey()
            if key then ns:Print(L.MPLUS_NEW_KEY, key) end
        end)
    end)
end

function M:OnDisable()
    self:DisableTimer()
end

function M:Refresh()
    self:RefreshTimer()
end
