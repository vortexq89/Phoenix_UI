local _, ns = ...
local L = ns.L
local W = ns.Widgets
local M = ns:GetModule("Automation")

--[[ Merchant bulk buy: Alt+click an item at a vendor to buy any amount. The game sells at most one stack per
    BuyMerchantItem call, so the amount is bought in stack-sized chunks, capped by what you can afford.
    Off with Automation > Bulk buy at merchants. ]]

-- Chunks of at most `stack` that add up to `total`: BulkChunks(45, 20) -> { 20, 20, 5 }.
function M.BulkChunks(total, stack)
    total, stack = math.floor(tonumber(total) or 0), math.max(1, math.floor(tonumber(stack) or 1))
    local out = {}
    while total > 0 do
        local n = math.min(total, stack)
        out[#out + 1] = n
        total = total - n
    end
    return out
end

local function itemInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then return info.name, info.price, info.stackCount, info.isPurchasable ~= false end
    end
    local legacy = _G.GetMerchantItemInfo -- older clients (Forever flavor)
    if legacy then
        local name, _, price, quantity, _, usable = legacy(index)
        return name, price, quantity, usable ~= false
    end
end

-- Most you can afford of an item sold `per` at a time for `price` copper (0 = free / currency: no money cap).
function M.BulkAffordable(want, price, per, money)
    want = math.floor(tonumber(want) or 0)
    if not price or price <= 0 then return want end
    local unit = price / math.max(1, per or 1)
    return math.min(want, math.floor((money or 0) / unit))
end

function M:BulkBuy(index, amount)
    local name, price, per = itemInfo(index)
    if not name then return 0 end
    local n = M.BulkAffordable(amount, price, per, GetMoney())
    local stack = GetMerchantItemMaxStack and GetMerchantItemMaxStack(index) or 1
    local bought = 0
    for _, chunk in ipairs(M.BulkChunks(n, stack)) do
        BuyMerchantItem(index, chunk)
        bought = bought + chunk
    end
    if bought < (tonumber(amount) or 0) then ns:Print(L.AUTO_BULK_CAPPED:format(bought)) end
    return bought
end

local popup
function M:OpenBulkBuy(index)
    local name = itemInfo(index)
    if not name then return end
    if not popup then
        popup = W:Popup(L.AUTO_BULK, 320, 120, "gold")
        popup.input = W:Input(popup, 120)
        popup.input:SetPoint("BOTTOMLEFT", 16, 16)
        popup.buy = W:Button(popup, L.AUTO_BULK_BUY, "primary", "check", 120)
        popup.buy:SetPoint("BOTTOMRIGHT", -16, 14)
        popup.label = W.Text(popup, "body", "text.primary")
        popup.label:SetPoint("TOPLEFT", 16, -42); popup.label:SetPoint("RIGHT", -16, 0)
        popup.buy.onClick = function()
            local n = tonumber(popup.input:GetValue())
            if n and n > 0 then M:BulkBuy(popup.index, math.min(n, 10000)) end
            popup:Hide()
        end
        popup.input:HookScript("OnEnterPressed", function() popup.buy.onClick() end)
        popup.input:HookScript("OnEscapePressed", function() popup:Hide() end)
        if MerchantFrame then MerchantFrame:HookScript("OnHide", function() popup:Hide() end) end
    end
    popup.index = index
    popup.label:SetText(name)
    popup.input:SetText("")
    popup:Show()
    popup.input:SetFocus()
    return popup
end

function M:SetupBulkBuy()
    if self.bulkHooked or type(MerchantItemButton_OnModifiedClick) ~= "function" then return end
    self.bulkHooked = true
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(button)
        if not (M:IsEnabled() and M.db.bulkBuy and IsAltKeyDown()) then return end
        if MerchantFrame and MerchantFrame.selectedTab ~= 1 then return end -- buy tab only, not buyback
        local id = button and button.GetID and button:GetID()
        if id and id > 0 then M:OpenBulkBuy(id) end
    end)
end
