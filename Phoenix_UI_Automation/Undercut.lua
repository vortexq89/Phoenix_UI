local _, ns = ...
local M = ns:GetModule("Automation")
local L, W = ns.L, ns.Widgets

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

M.lowestForeign = {} -- [itemID] = lowest unit/buyout price from someone else (this AH visit)

-- Lowest price among results that are not yours; `get(i)` returns the i-th result info.
function M.LowestForeign(get, n, field)
    for i = 1, math.min(n or 0, 50) do
        local ok, info = pcall(get, i)
        if not (ok and info) then break end
        if not info.containsOwnerItem and not info.containsAccountItem then return info[field] end
    end
end

local refreshCancel
local function onCommodity(_, _, itemID)
    if not (M:IsEnabled() and M.db.undercut) then return end
    local n = C_AuctionHouse.GetNumCommoditySearchResults and C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    local low = M.LowestForeign(function(i) return C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i) end, n, "unitPrice")
    if itemID then M.lowestForeign[itemID] = low or false; refreshCancel() end
    local f = sellFrame("CommoditiesSellFrame")
    if not f then return end
    local ok, info = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, 1)
    if ok and info and not info.containsOwnerItem then setPrice(f, M.UndercutPrice(info.unitPrice, "commodity")) end
end

local function onItem(_, _, itemKey)
    if not (M:IsEnabled() and M.db.undercut) then return end
    local n = C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetNumItemSearchResults(itemKey)
    local low = M.LowestForeign(function(i) return C_AuctionHouse.GetItemSearchResultInfo(itemKey, i) end, n, "buyoutAmount")
    if itemKey and itemKey.itemID then M.lowestForeign[itemKey.itemID] = low or false; refreshCancel() end
    local f = sellFrame("ItemSellFrame")
    if not f then return end
    local ok, info = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, 1)
    if ok and info and not info.containsOwnerItem then setPrice(f, M.UndercutPrice(info.buyoutAmount, "item")) end
end

--[[ Cancel helper: a button on the Auction House lists how many of your active auctions are undercut.
    Each click of YOURS does one step: it either asks the AH for the price of the next auction not yet checked
    (one search per click) or cancels the next undercut one (C_AuctionHouse.CancelAuction, which the game only
    allows from a hardware click). Nothing runs on its own; the deposit is lost as with a normal cancel. ]]

-- owned: { { auctionID, itemID, price, active } }; lowest: [itemID] = price | false (checked, none).
-- Returns the undercut auction IDs and the owned rows still to check.
function M.CancelPlan(owned, lowest)
    local cancel, check, seen = {}, {}, {}
    for _, a in ipairs(owned or {}) do
        if a.active and a.itemID and a.price then
            local low = lowest[a.itemID]
            if low == nil then
                if not seen[a.itemID] then seen[a.itemID] = true; check[#check + 1] = a end
            elseif low and low < a.price then
                cancel[#cancel + 1] = a.auctionID
            end
        end
    end
    return cancel, check
end

function M:OwnedRows()
    local rows = {}
    local n = C_AuctionHouse.GetNumOwnedAuctions and C_AuctionHouse.GetNumOwnedAuctions() or 0
    for i = 1, n do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info and info.itemKey then
            rows[#rows + 1] = { auctionID = info.auctionID, itemID = info.itemKey.itemID, itemKey = info.itemKey,
                price = info.buyoutAmount or info.bidAmount, active = info.status == 0 }
        end
    end
    return rows
end

local button, plan
function refreshCancel()
    if not button then return end
    local on = M:IsEnabled() and M.db.undercut
    button:SetShown(on and true or false)
    if not on then return end
    local cancel, check = M.CancelPlan(M:OwnedRows(), M.lowestForeign)
    plan = { cancel = cancel, check = check }
    if #cancel > 0 then
        button.label:SetText(L.AUTO_UNDERCUT_CANCEL:format(#cancel))
    elseif #check > 0 then
        button.label:SetText(L.AUTO_UNDERCUT_CHECK:format(#check))
    else
        button.label:SetText(L.AUTO_UNDERCUT_NONE)
    end
end
M.RefreshCancel = function() refreshCancel() end

-- One step per hardware click of the user.
function M.CancelStep()
    if not plan then return end
    local id = plan.cancel[1]
    if id then
        C_AuctionHouse.CancelAuction(id)
        table.remove(plan.cancel, 1)
        return "cancel", id
    end
    local row = plan.check[1]
    if row then
        C_AuctionHouse.SendSearchQuery(row.itemKey, {}, true)
        return "check", row.itemID
    end
end

local function buildButton()
    local ah = _G.AuctionHouseFrame
    if button or not ah then return end
    button = W:Button(ah, "", "secondary", "search", 190)
    button:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", 0, 4)
    button:SetScript("OnClick", function() M.CancelStep(); refreshCancel() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L.AUTO_UNDERCUT_CANCEL_TIP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function M:SetupUndercut()
    if self.undercutHooked or not C_AuctionHouse then return end
    self.undercutHooked = true
    ns.Events:On("AUCTION_HOUSE_SHOW", self, function()
        wipe(M.lowestForeign); buildButton()
        if C_AuctionHouse.QueryOwnedAuctions then C_AuctionHouse.QueryOwnedAuctions({}) end
        refreshCancel()
    end)
    ns.Events:On("OWNED_AUCTIONS_UPDATED", self, function() refreshCancel() end)
    ns.Events:On("AUCTION_CANCELED", self, function() refreshCancel() end)
    ns.Events:On("COMMODITY_SEARCH_RESULTS_UPDATED", self, onCommodity)
    ns.Events:On("ITEM_SEARCH_RESULTS_UPDATED", self, onItem)
end

-- Settings apply live: the Auction undercut switch shows or hides the cancel button at once.
function M:Refresh() refreshCancel() end
