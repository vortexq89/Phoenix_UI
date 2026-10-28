local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Auction House, skins plan window 10 (window chrome and tabs: shared skin): the category rail and every
    results list (browse, item and commodity results, your auctions and bids) as Phoenix rows with the
    selected one outlined in the accent, the search bar on a sunken card, and the buy / post dialogs as
    Phoenix dialogs with the buy button primary. Buying, bidding and posting stay Blizzard's clicks.
    Live with Skins > Auction House. ]]

local function on() return M:IsEnabled() and M.db.auction and true or false end

-- ScrollBoxes of the AH, found by path from AuctionHouseFrame (missing pieces are skipped).
M.AUCTION_LISTS = {
    { "CategoriesList", "ScrollBox" }, { "BrowseResultsFrame", "ItemList", "ScrollBox" },
    { "ItemBuyFrame", "ItemList", "ScrollBox" }, { "CommoditiesBuyFrame", "ItemList", "ScrollBox" },
    { "AuctionsFrame", "AllAuctionsList", "ScrollBox" }, { "AuctionsFrame", "BidsList", "ScrollBox" },
    { "ItemSellList", "ScrollBox" }, { "CommoditiesSellList", "ScrollBox" },
}

function M.FramePath(root, path)
    local f = root
    for _, k in ipairs(path) do
        if type(f) ~= "table" then return nil end
        f = f[k]
    end
    return f
end

function M:SkinAuction()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    local isOn = on()
    for _, path in ipairs(self.AUCTION_LISTS) do
        M.KitScrollBox(M.FramePath(ah, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.45 }) end)
    end
    M.KitCard(ah.SearchBar, isOn, "sunken", false)
    local dialogs = { ah.BuyDialog, ah.CommoditiesBuyFrame and ah.CommoditiesBuyFrame.BuyDisplay }
    for _, d in ipairs(dialogs) do if d then M.KitCard(d, isOn, "raised", true) end end
    if ah.BuyDialog then
        M.SkinPopupButton(ah.BuyDialog.BuyNowButton, "primary", isOn)
        M.SkinPopupButton(ah.BuyDialog.CancelButton, "secondary", isOn)
    end
end

local ahHooked
function M:SetupAuction()
    self:SkinAuction()
    local ah = _G.AuctionHouseFrame
    if ahHooked or not ah then return end
    ahHooked = true
    ah:HookScript("OnShow", function() M:SkinAuction() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupAuction"
M.RESKINS[#M.RESKINS + 1] = "SkinAuction"
