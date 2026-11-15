local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Trade, skins plan window 27 (card: shared window skin): your side and the other player's side as two
    Phoenix columns (sunken cards), every trade slot on a cell, Trade as the primary button. Item icons are the
    game's own; trading stays Blizzard's click. Live with Skins > Trade. ]]

local function on() return M:IsEnabled() and M.db.trade and true or false end

function M:SkinTrade()
    if not _G.TradeFrame then return end
    local isOn = on()
    M.KitCard(_G.TradePlayerItemsInset, isOn, "sunken", false)
    M.KitCard(_G.TradeRecipientItemsInset, isOn, "sunken", false)
    for i = 1, 7 do
        M.KitCard(_G["TradePlayerItem" .. i], isOn, "raised", false)
        M.KitCard(_G["TradeRecipientItem" .. i], isOn, "raised", false)
    end
    M.SkinPopupButton(_G.TradeFrameTradeButton, "primary", isOn)
    M.SkinPopupButton(_G.TradeFrameCancelButton, "secondary", isOn)
end

local tradeHooked
function M:SetupTrade()
    self:SkinTrade()
    local root = _G.TradeFrame
    if tradeHooked or not root then return end
    tradeHooked = true
    root:HookScript("OnShow", function() M:SkinTrade() end)
end
M.SETUPS[#M.SETUPS + 1] = "SetupTrade"
M.RESKINS[#M.RESKINS + 1] = "SkinTrade"
