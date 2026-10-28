local _, ns = ...
local M = ns:GetModule("Skins")

--[[ Merchant and buyback, skins plan window 19: every item slot on a raised Phoenix card with its name in the
    theme font, the buyback slot and the money footer on sunken cards. Item icons, prices and the repair
    buttons are the game's own; buying, selling and repairing stay Blizzard's clicks.
    Live both ways with its Skins switch, repainted on theme change (kit rows / cards). ]]

local function on() return M:IsEnabled() and M.db.merchant and true or false end

function M:SkinMerchant()
    if not _G.MerchantFrame then return end
    local isOn = on()
    for i = 1, 12 do
        local item = _G["MerchantItem" .. i]
        local card = M.KitCard(item, isOn, "raised", false)
        local name = _G["MerchantItem" .. i .. "Name"]
        if name then
            if isOn then ns.Skin:Text(name, "body", "text.primary") else ns.Skin:Restore(name) end
        end
        if card and isOn then ns.Skin:SetBorderColor(card, "border.subtle") end
    end
    M.KitCard(_G.MerchantBuyBackItem, isOn, "sunken", false)
    M.KitCard(_G.MerchantMoneyFrame, isOn, "sunken", false)
end

local merchantHooked
function M:SetupMerchant()
    self:SkinMerchant()
    local root = _G.MerchantFrame
    if merchantHooked or not root then return end
    merchantHooked = true
    root:HookScript("OnShow", function() M:SkinMerchant() end)
    -- page turns and buyback refill the same rows: repaint after Blizzard's own update
    if _G.MerchantFrame_Update then hooksecurefunc("MerchantFrame_Update", function() M:SkinMerchant() end) end
end
M.SETUPS[#M.SETUPS + 1] = "SetupMerchant"
M.RESKINS[#M.RESKINS + 1] = "SkinMerchant"
