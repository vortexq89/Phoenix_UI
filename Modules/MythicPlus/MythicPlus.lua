local _, ns = ...
local L = ns.L

--[[ MythicPlus: slots your keystone as soon as the Font of Power opens and reports the new key
    after a run. Bag data is plain (not secret); nothing here touches combat. ]]
local M = ns:NewModule("MythicPlus", {
    label = "MYTHICPLUS", desc = "MYTHICPLUS_DESC", category = "utility", order = 30,
    defaults = { autoInsert = true, reportKey = true },
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
    if not M.db.autoInsert or C_ChallengeMode.HasSlottedKeystone() then return end
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

