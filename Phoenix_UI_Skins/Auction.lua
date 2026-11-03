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

function M:SkinAuction()
    local ah = _G.AuctionHouseFrame
    if not ah then return end
    local isOn = on()
    for _, path in ipairs(self.AUCTION_LISTS) do
        M.KitScrollBox(M.FramePath(ah, path), on, function(row, o) M.KitRow(row, o, { alpha = 0.45 }) end)
    end
    M.KitCard(ah.SearchBar, isOn, "sunken", false)
    self:AuctionHeaders(ah, isOn)
    local dialogs = { ah.BuyDialog, ah.CommoditiesBuyFrame and ah.CommoditiesBuyFrame.BuyDisplay }
    for _, d in ipairs(dialogs) do if d then M.KitCard(d, isOn, "raised", true) end end
    if ah.BuyDialog then
        M.SkinPopupButton(ah.BuyDialog.BuyNowButton, "primary", isOn)
        M.SkinPopupButton(ah.BuyDialog.CancelButton, "secondary", isOn)
    end
end

-- Column headers of the results tables (Blizzard sorts on click): each header on a sunken cell, the one you
-- sorted by last outlined in the accent. Only our cells change; sorting stays Blizzard's.
M.AUCTION_TABLES = { { "BrowseResultsFrame", "ItemList" }, { "ItemBuyFrame", "ItemList" },
    { "CommoditiesBuyFrame", "ItemList" }, { "AuctionsFrame", "AllAuctionsList" }, { "AuctionsFrame", "BidsList" } }
local sortedBy = setmetatable({}, { __mode = "k" }) -- [header container] = header button
local hookedHeaders = setmetatable({}, { __mode = "k" })
function M:AuctionHeaders(ah, isOn)
    for _, path in ipairs(self.AUCTION_TABLES) do
        local list = M.FramePath(ah, path)
        local hc = type(list) == "table" and rawget(list, "HeaderContainer")
        if type(hc) == "table" and hc.GetChildren then
            for _, h in ipairs({ hc:GetChildren() }) do
                local card = M.KitCard(h, isOn, "sunken", false)
                if card and isOn then
                    ns.Skin:SetBorderColor(card, sortedBy[hc] == h and "accent.primary" or "border.subtle")
                end
                -- t156: only Buttons have OnClick; HookScript("OnClick") on a Frame child raises an error (§24)
                if not hookedHeaders[h] and h.HookScript and h.GetObjectType and h:GetObjectType() == "Button" then
                    hookedHeaders[h] = true
                    h:HookScript("OnClick", function(self) sortedBy[hc] = self; M:AuctionHeaders(ah, M.db.auction) end)
                end
            end
        end
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
