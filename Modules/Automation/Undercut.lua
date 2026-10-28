local _, ns = ...
local M = ns:GetModule("Automation")

--[[ Auction undercut: when you put an item in the Auction House sell frame and the game's own search comes back,
    the price is set just under the lowest offer that is not yours (commodities by 1 copper, items by 1 silver,
    the smallest step each allows). You still press Post yourself. Off with Automation > Auction undercut. ]]

-- Price under `lowest` for a kind ("commodity" | "item"); nil when there is nothing to undercut.
function M.UndercutPrice(lowest, kind)
    lowest = tonumber(lowest)
    if not lowest or lowest <= 0 then return nil end
    if kind == "item" then
        local p = math.floor((lowest - 100) / 100) * 100
        return p >= 100 and p or nil
    end
    return lowest > 1 and lowest - 1 or nil
end

local function setPrice(frame, copper)
    local input = frame and frame.PriceInput
    if copper and input and input.SetAmount then input:SetAmount(copper) end
end

local function sellFrame(name)
    local ah = _G.AuctionHouseFrame
    local f = ah and ah[name]
    return f and f:IsShown() and f or nil
end

local function onCommodity(_, _, itemID)
    if not (M:IsEnabled() and M.db.undercut) then return end
    local f = sellFrame("CommoditiesSellFrame")
    if not f then return end
    local ok, info = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, 1)
    if ok and info and not info.containsOwnerItem then setPrice(f, M.UndercutPrice(info.unitPrice, "commodity")) end
end

local function onItem(_, _, itemKey)
    if not (M:IsEnabled() and M.db.undercut) then return end
    local f = sellFrame("ItemSellFrame")
    if not f then return end
    local ok, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, 1)
    if ok and info and not info.containsOwnerItem then setPrice(f, M.UndercutPrice(info.buyoutAmount, "item")) end
end

function M:SetupUndercut()
    if self.undercutHooked or not C_AuctionHouse then return end
    self.undercutHooked = true
    ns.Events:On("COMMODITY_SEARCH_RESULTS_UPDATED", self, onCommodity)
    ns.Events:On("ITEM_SEARCH_RESULTS_UPDATED", self, onItem)
end
