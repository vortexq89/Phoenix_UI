local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin
local M = ns:GetModule("Skins")

--[[ The Phoenix merchant window: our own vendor window fed by the merchant API. A grid of item cards (the
    item's own icon, name, price in gold or in its currencies, stock), a Buyback tab, Sell junk and Repair
    (own gold / guild). Click buys one; shift-click buys a full stack. An item paid in currencies or items
    asks for a second click that names the cost before anything is spent. Selling stays right-click in your
    bags (Blizzard's MerchantFrame is open the whole visit, tucked away by the shared Replacement shell).
    Skins > "Phoenix merchant window" off: Blizzard's vendor, reskinned, live. ]]

local COLS, ROWS, CARD_W, CARD_H, GAP = 2, 6, 230, 46, 6
local page, tab, armed = 1, "buy", nil
local r

-- One merchant item as plain values (retail C_MerchantFrame.GetItemInfo, or the older global).
function M.MerchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if type(info) == "table" and info.name then
            return { name = tostring(info.name), texture = info.texture, price = tonumber(info.price) or 0,
                stack = tonumber(info.stackCount) or 1, available = tonumber(info.numAvailable) or -1,
                usable = info.isUsable ~= false, extended = info.hasExtendedCost and true or false }
        end
    end
    local legacy = _G.GetMerchantItemInfo
    if legacy then
        local name, texture, price, stack, available, usable, extended = legacy(i)
        if name then
            return { name = tostring(name), texture = texture, price = tonumber(price) or 0, stack = tonumber(stack) or 1,
                available = tonumber(available) or -1, usable = usable ~= false, extended = extended and true or false }
        end
    end
    return nil
end

local function money(v)
    local s = C_CurrencyInfo.GetCoinTextureString(tonumber(v) or 0)
    return type(s) == "string" and s or tostring(tonumber(v) or 0)
end

-- The cost text: gold and/or each currency / item cost with its icon.
function M.MerchantCost(i, item)
    local parts = {}
    if item.price > 0 then parts[#parts + 1] = money(item.price) end
    if item.extended and GetMerchantItemCostInfo then
        for c = 1, (tonumber(GetMerchantItemCostInfo(i)) or 0) do
            local texture, value = GetMerchantItemCostItem(i, c)
            if texture then parts[#parts + 1] = ("%s |T%s:12:12|t"):format(BreakUpLargeNumbers(tonumber(value) or 0), texture) end
        end
    end
    return table.concat(parts, "  ")
end

function M:MerchantBuy(i, stack)
    local item = M.MerchantItem(i)
    if not item then return end
    if item.extended and armed ~= i then armed = i; r:Layout(); return end
    armed = nil
    local qty = 1
    if stack then qty = math.max(1, tonumber(GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or 1) end
    BuyMerchantItem(i, qty)
end

local function card(i)
    local c = r.cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, r.body)
    c:SetSize(CARD_W, CARD_H)
    c:SetPoint("TOPLEFT", ((i - 1) % COLS) * (CARD_W + GAP), -40 - math.floor((i - 1) / COLS) * (CARD_H + GAP))
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(36, 36)
    c.icon:SetPoint("LEFT", 5, 0)
    c.name = W.Text(c, "body", "text.primary")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, -1)
    c.name:SetPoint("RIGHT", -6, 0)
    c.name:SetJustifyH("LEFT")
    c.cost = W.Text(c, "small", "text.secondary")
    c.cost:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 8, 1)
    c.count = c:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    c.count:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", -1, 1)
    c:SetScript("OnClick", function(self)
        if M.MerchantModifiedClick(tab, self.index) then return end
        if tab == "buyback" then BuybackItem(self.index) else M:MerchantBuy(self.index, IsShiftKeyDown()) end
    end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if tab == "buyback" then GameTooltip:SetBuybackItem(self.index) else GameTooltip:SetMerchantItem(self.index) end
        GameTooltip:Show()
        Skin:SetBorderColor(self, "accent.primary")
    end)
    c:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        Skin:SetBorderColor(self, armed == self.index and "state.danger" or "border.subtle")
    end)
    r.cards[i] = c
    return c
end

-- t156: Blizzard's merchant buttons hand modified clicks to HandleModifiedItemClick first (MerchantFrame.lua):
-- shift with chat open links the item, ctrl previews it. Before, those clicks bought (shift: a full stack).
function M.MerchantModifiedClick(which, index)
    local handle = _G.HandleModifiedItemClick
    if not (index and handle and IsModifiedClick) then return false end
    if not (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP") or IsModifiedClick("EXPANDITEM")) then return false end
    local link = which == "buyback" and GetBuybackItemLink and GetBuybackItemLink(index)
        or which ~= "buyback" and GetMerchantItemLink and GetMerchantItemLink(index)
    return link and handle(link) and true or false
end

-- Name colour from the item's quality, as Blizzard's list shows it (nil = the theme's text colour).
function M.MerchantQualityColor(link)
    local CI = _G.C_Item
    local q = link and CI and CI.GetItemQualityByID and CI.GetItemQualityByID(link)
    local c = type(q) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    return c and c.r and c or nil
end

local function paintCard(c, index, name, texture, costText, stack, usable)
    c.index = index
    c.icon:SetTexture(texture)
    -- unusable: Blizzard's red icon tint rather than a grey one, so it reads as "can't use", not "sold out"
    c.icon:SetDesaturated(false)
    if usable then c.icon:SetVertexColor(1, 1, 1) else c.icon:SetVertexColor(0.9, 0, 0) end
    c.name:SetText(name)
    local link = tab == "buyback" and GetBuybackItemLink and GetBuybackItemLink(index)
        or tab ~= "buyback" and GetMerchantItemLink and GetMerchantItemLink(index)
    local qc = M.MerchantQualityColor(link)
    if qc then c.name:SetTextColor(qc.r, qc.g, qc.b) else W.Color(c.name, "text.primary") end
    c.cost:SetText(costText)
    c.count:SetText((stack or 1) > 1 and stack or "")
    Skin:Panel(c, "raised", { border = armed == index and tab == "buy" and "state.danger" or "border.subtle" })
    c:Show()
end

local function layout()
    local per = COLS * ROWS
    for key, t in pairs(r.tabs) do
        t.variant = key == tab and "primary" or "secondary"
        local idle = t:GetScript("OnLeave")
        if idle then idle(t) end
    end
    local n = tab == "buyback" and (tonumber(GetNumBuybackItems and GetNumBuybackItems()) or 0)
        or (tonumber(GetMerchantNumItems and GetMerchantNumItems()) or 0)
    local pages = math.max(1, math.ceil(n / per))
    page = math.max(1, math.min(page, pages))
    for slot = 1, per do
        local index = (page - 1) * per + slot
        local c = card(slot)
        if index > n then
            c:Hide()
        elseif tab == "buyback" then
            local name, texture, price, stack = GetBuybackItemInfo(index)
            paintCard(c, index, tostring(name or ""), texture, money(price), tonumber(stack), true)
        else
            local item = M.MerchantItem(index)
            if item then
                local costText = M.MerchantCost(index, item)
                if armed == index then costText = L.MERCHW_CONFIRM:format(costText) end
                if item.available >= 0 then costText = costText .. "  " .. L.MERCHW_STOCK:format(item.available) end
                paintCard(c, index, item.name, item.texture, costText, item.stack, item.usable)
            else
                c:Hide()
            end
        end
    end
    r.page:SetText(("%d / %d"):format(page, pages))
    r.prev:SetShown(pages > 1); r.next:SetShown(pages > 1); r.page:SetShown(pages > 1)
    local canRepair = CanMerchantRepair and CanMerchantRepair()
    local cost = canRepair and tonumber((GetRepairAllCost())) or 0
    r.repair:SetShown(canRepair and cost > 0)
    r.repair:SetText(L.MERCHW_REPAIR:format(money(cost)))
    r.guild:SetShown(canRepair and cost > 0 and CanGuildBankRepair and CanGuildBankRepair() or false)
    local junk = C_MerchantFrame and C_MerchantFrame.GetNumJunkItems and tonumber(C_MerchantFrame.GetNumJunkItems()) or 0
    r.junk:SetShown(junk > 0)
    r.money:SetText(money(GetMoney()))
end

local function build(rr)
    r = rr
    r.cards, r.tabs = {}, {}
    local prev
    for _, key in ipairs({ "buy", "buyback" }) do
        local b = W:Button(r.body, key == "buy" and L.MERCHW_BUY or L.MERCHW_BUYBACK, "secondary", nil, 100)
        b:SetHeight(24)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 0, 0) end
        b.onClick = function() tab, page, armed = key, 1, nil; r:Layout() end
        r.tabs[key], prev = b, b
    end
    r.junk = W:Button(r.body, L.MERCHW_JUNK, "secondary", "bin", 110)
    r.junk:SetHeight(24)
    r.junk:SetPoint("TOPRIGHT", 0, 0)
    r.junk.onClick = function() if C_MerchantFrame.SellAllJunkItems then C_MerchantFrame.SellAllJunkItems() end end
    local foot = -40 - ROWS * (CARD_H + GAP) - 6
    r.prev = W:IconButton(r.body, "reset", 22, PREV or "<")
    r.prev:SetPoint("TOPLEFT", 0, foot)
    r.prev.onClick = function() page = page - 1; r:Layout() end
    r.page = W.Text(r.body, "small", "text.secondary")
    r.page:SetPoint("LEFT", r.prev, "RIGHT", 8, 0)
    r.next = W:IconButton(r.body, "play", 22, NEXT or ">")
    r.next:SetPoint("LEFT", r.page, "RIGHT", 8, 0)
    r.next.onClick = function() page = page + 1; r:Layout() end
    r.repair = W:Button(r.body, "", "primary", "durability", 170)
    r.repair:SetHeight(24)
    r.repair:SetPoint("BOTTOMLEFT", 0, 0)
    r.repair.onClick = function() RepairAllItems(false) end
    r.guild = W:Button(r.body, L.MERCHW_GUILD, "secondary", "guild", 120)
    r.guild:SetHeight(24)
    r.guild:SetPoint("LEFT", r.repair, "RIGHT", 6, 0)
    r.guild.onClick = function() RepairAllItems(true) end
    r.money = W.Text(r.body, "small", "text.secondary")
    r.money:SetPoint("BOTTOMRIGHT", 0, 4)
end

local merchant = M.Replacement({ key = "ownMerchant", frame = "MerchantFrame", title = L.MERCHW_TITLE,
    width = COLS * (CARD_W + GAP) - GAP + 20, height = 34 + 40 + ROWS * (CARD_H + GAP) + 80,
    build = build, layout = layout, close = function() if CloseMerchant then CloseMerchant() end end })
M.MerchantReplacement = merchant

local listening
function M:SetupMerchantWindow()
    if listening then merchant:Sync(); return end
    listening = true
    local owner = merchant
    ns.Events:On("MERCHANT_SHOW", owner, function() page, tab, armed = 1, "buy", nil; merchant:Opened() end)
    ns.Events:On("MERCHANT_CLOSED", owner, function() merchant:Closed() end)
    ns.Events:On("PLAYER_REGEN_ENABLED", owner, function() merchant:Sync() end)
    for _, event in ipairs({ "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY",
        "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE" }) do
        ns.Events:On(event, owner, function() merchant:Soon() end)
    end
    merchant:Sync()
end
function M:SyncMerchant() merchant:Sync() end
M.SETUPS[#M.SETUPS + 1] = "SetupMerchantWindow"
M.RESKINS[#M.RESKINS + 1] = "SyncMerchant"
