local _, ns = ...
local L, W = ns.L, ns.Widgets
local M = ns.modules.Automation

--[[ Junk window (EllesmereUI Forever Essentials reference; both clients). A Phoenix popup listing the poor-quality
    (grey) items in your bags with their real icons, counts and vendor value, and the total. At a vendor it opens
    by itself when you have junk (unless "Sell junk" already sold it) with Sell all and per-row Sell; away from a
    vendor a row's Destroy needs a second click on the same row within five seconds. Every sale or deletion is your
    own click, out of combat. /pui automation junk opens it anywhere. ]]

local function coin(v) return tostring(C_CurrencyInfo.GetCoinTextureString(v) or "") end

local ROWS, ROW_H = 10, 26
local win, armed, armedAt

-- Grey items in your bags: { bag, slot, link, icon, count, value }, dearest first, and the total value.
function M.JunkItems(getInfo, getPrice, bags)
    local out, total = {}, 0
    for bag = 0, bags or 4 do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local info = getInfo(bag, slot)
            if type(info) == "table" and info.quality == 0 and not info.hasNoValue and info.hyperlink then
                local price = (tonumber(getPrice(info.hyperlink)) or 0) * (tonumber(info.stackCount) or 1)
                out[#out + 1] = { bag = bag, slot = slot, link = info.hyperlink, icon = info.iconFileID,
                                  count = tonumber(info.stackCount) or 1, value = price }
                total = total + price
            end
        end
    end
    table.sort(out, function(a, b) return a.value > b.value end)
    return out, total
end

local function priceOf(link) return select(11, C_Item.GetItemInfo(link)) end
local function atVendor() return MerchantFrame and MerchantFrame:IsShown() end

local function act(e)
    if InCombatLockdown() or not e then return end
    if atVendor() then
        C_Container.UseContainerItem(e.bag, e.slot) -- sells at an open vendor
    else
        local key = e.bag .. ":" .. e.slot
        if armed ~= key or GetTime() - (armedAt or 0) > 5 then
            armed, armedAt = key, GetTime()
            ns:Print(L.JUNK_CONFIRM:format(e.link))
            return
        end
        armed = nil
        ClearCursor()
        C_Container.PickupContainerItem(e.bag, e.slot)
        DeleteCursorItem()
    end
end

local function build()
    win = W:Popup(L.JUNK, 340, 72 + ROWS * ROW_H, "gold")
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", MerchantFrame or UIParent, "TOPRIGHT", 12, 0)
    win.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, win)
        r:SetSize(308, ROW_H - 2)
        r:SetPoint("TOPLEFT", 16, -40 - (i - 1) * ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ROW_H - 4, ROW_H - 4)
        r.icon:SetPoint("LEFT")
        r.name = W.Text(r, "small", "text.primary", "LEFT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.value = W.Text(r, "small", "text.secondary", "RIGHT")
        r.value:SetPoint("RIGHT", -2, 0)
        r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
        r:SetScript("OnClick", function(self) act(self.entry); M:UpdateJunk() end)
        r:SetScript("OnEnter", function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.entry.link)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        win.rows[i] = r
    end
    win.total = W.Text(win, "body", "text.primary", "LEFT")
    win.total:SetPoint("BOTTOMLEFT", 16, 14)
    win.sell = W:Button(win, L.JUNK_SELL_ALL, "primary")
    win.sell:SetPoint("BOTTOMRIGHT", -16, 10)
    win.sell.onClick = function()
        if not InCombatLockdown() and atVendor() then C_MerchantFrame.SellAllJunkItems() end
    end
    win:HookScript("OnHide", function() armed = nil end)
end

function M:UpdateJunk()
    if not (win and win:IsShown()) then return end
    local items, total = M.JunkItems(C_Container.GetContainerItemInfo, priceOf)
    for i, r in ipairs(win.rows) do
        local e = items[i]
        r.entry = e
        r:SetShown(e ~= nil)
        if e then
            r.icon:SetTexture(e.icon)
            r.name:SetText(e.count > 1 and (e.link .. " x" .. e.count) or e.link)
            r.value:SetText(coin(e.value))
        end
    end
    win.total:SetText(L.JUNK_TOTAL:format(#items, coin(total)))
    W.SetEnabledState(win.sell, atVendor() and #items > 0)
    return #items
end

function M:ShowJunk()
    if not win then build() end
    win:Show()
    return self:UpdateJunk()
end

function M:SetupJunk()
    if self.junkHooked then return end
    self.junkHooked = true
    local owner = {}
    ns.Events:On("MERCHANT_SHOW", owner, function()
        if not (M:IsEnabled() and M.db.junkWindow) then return end
        -- after "Sell junk" has had its turn
        C_Timer.After(0.3, function()
            local items = M.JunkItems(C_Container.GetContainerItemInfo, priceOf)
            if #items > 0 then M:ShowJunk() end
        end)
    end)
    ns.Events:On("MERCHANT_CLOSED", owner, function() if win then win:Hide() end end)
    ns.Events:On("BAG_UPDATE_DELAYED", owner, function() M:UpdateJunk() end)
end

-- /pui automation junk
function M:OnSlash(rest)
    if rest == "junk" then return self:ShowJunk() end
    ns.Config:Show(self.key)
end
