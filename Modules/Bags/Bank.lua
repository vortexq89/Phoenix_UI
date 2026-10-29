local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin

--[[ The Phoenix bank window: our own window for the character bank and the Warband bank, drawn from the bank
    API (C_Bank tab data, C_Container slots) in the Phoenix look: bank-type rail, tab strip with the tabs' own
    icons, a slot grid, search, sort, deposit reagents and the Warband gold. Bags > "Phoenix bank window" off
    brings back Blizzard's bank (reskinned), live; the arrow button opens Blizzard's bank for this visit only
    (buying tabs, tab settings, gold transfers).

    Safety: Blizzard's BankFrame stays open the whole visit (so Escape, right-click deposits from the bags and
    every "is the bank open" check behave as usual); Skin:Tuck only makes it see-through and parks its child
    frames on a hidden holder of ours. Item buttons are ours, built from ContainerFrameItemButtonTemplate on
    holders that carry the bank tab's container ID, so clicks, drags and tooltips run Blizzard's own item-button
    code. Sorting and depositing are the game's own calls on your click. ]]
local M = ns:GetModule("Bags")

local COLS, PAD, HEAD, RAIL, FOOT = 14, 10, 30, 30, 26
local win, holders, buttons = nil, {}, {}
local bankType, tabID

local function on() return M:IsEnabled() and M.db.bankWindow and true or false end
M.BankWindowOn = on

-- Purchased tabs for a bank type: { { ID, name, icon } } (empty when none is bought or the API is missing).
function M.BankTabs(kind)
    local out = {}
    if not (C_Bank and C_Bank.FetchPurchasedBankTabData) or kind == nil then return out end
    for _, t in ipairs(C_Bank.FetchPurchasedBankTabData(kind) or {}) do
        if type(t) == "table" and t.ID then out[#out + 1] = { ID = t.ID, name = t.name, icon = t.icon } end
    end
    return out
end

local function types()
    local E = Enum.BankType or {}
    return { { kind = E.Character, label = L.BAGS_BANK_CHARACTER, icon = "user" },
        { kind = E.Account, label = L.BAGS_BANK_WARBAND, icon = "guild" } }
end

local function holderFor(bag)
    local h = holders[bag]
    if h then return h end
    h = CreateFrame("Frame", nil, win.content)
    h:SetAllPoints()
    h:SetID(bag)
    function h.IsCombinedBagContainer() return false end
    holders[bag] = h
    return h
end

local function buttonFor(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local b = buttons[bag][slot]
    if b then return b end
    b = CreateFrame("ItemButton", nil, holderFor(bag), "ContainerFrameItemButtonTemplate")
    b:Initialize(bag, slot)
    buttons[bag][slot] = b
    return b
end

local function tabButton(i)
    local t = win.tabs[i]
    if t then return t end
    t = CreateFrame("Button", nil, win)
    t:SetSize(26, 26)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", 2, -2)
    t.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    t:SetScript("OnClick", function(self) tabID = self.id; M:LayoutBank() end)
    t:SetScript("OnEnter", function(self) W.ShowTooltip(self, self.label or "") end)
    t:SetScript("OnLeave", function() W.HideTooltip() end)
    win.tabs[i] = t
    return t
end

local function railButton(i, def)
    local r = win.rail[i]
    if not r then
        r = M.IconButton(win, def.icon, def.label, function(self)
            bankType, tabID = self.kind, nil
            if BankPanel and BankPanel.SetBankType then BankPanel:SetBankType(self.kind) end
            M:LayoutBank()
        end)
        r:SetSize(24, 24)
        r:SetPoint("TOPLEFT", PAD, -PAD - HEAD - (i - 1) * 28)
        win.rail[i] = r
    end
    r.kind = def.kind
    return r
end

function M:StyleBank()
    if not win then return end
    Skin:Backdrop(win, self.db.backdrop, "bg.base")
    Skin:BorderSpec(win, self.db.border, "border.strong")
    Skin:TextSpec(win.title, self.db.title, "heading", "accent.primary")
    Skin:Text(win.money, "small", "text.secondary", 11)
    Skin:Text(win.empty, "body", "text.muted", 12)
end

function M:LayoutBank()
    if not (win and win:IsShown()) then return end
    local list = types()
    if bankType == nil then bankType = list[1].kind end
    for i, def in ipairs(list) do
        local r = railButton(i, def)
        ns.Icons:Tint(r.icon, def.kind == bankType and "accent.primary" or "text.secondary")
    end
    local tabs = M.BankTabs(bankType)
    local found
    for _, t in ipairs(tabs) do if t.ID == tabID then found = true end end
    if not found then tabID = tabs[1] and tabs[1].ID end
    for i, t in ipairs(tabs) do
        local b = tabButton(i)
        b.id, b.label = t.ID, t.name
        b.icon:SetTexture(t.icon)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", PAD + RAIL + (i - 1) * 30, -PAD - HEAD)
        Skin:Border(b, t.ID == tabID and "accent.primary" or "border.subtle")
        b:Show()
    end
    for i = #tabs + 1, #win.tabs do win.tabs[i]:Hide() end
    local size, gap = self.db.slotSize, self.db.spacing
    local used = {}
    local n = tabID and C_Container.GetContainerNumSlots(tabID) or 0
    for slot = 1, n do
        local b = buttonFor(tabID, slot)
        used[b] = true
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", win.content, "TOPLEFT", ((slot - 1) % COLS) * (size + gap),
            -math.floor((slot - 1) / COLS) * (size + gap))
        b:Show()
        local info = C_Container.GetContainerItemInfo(tabID, slot)
        local loc = ItemLocation:CreateFromBagAndSlot(tabID, slot)
        M.UpdateItemButton(b, { bag = tabID, slot = slot, info = info, s = info and M.SlotInfo(loc) or {},
            quest = info and C_Container.GetContainerItemQuestInfo(tabID, slot) })
    end
    for _, l in pairs(buttons) do for _, b in pairs(l) do if not used[b] then b:Hide() end end end
    win.empty:SetShown(#tabs == 0)
    local rows = math.max(1, math.ceil(n / COLS))
    local width = COLS * (size + gap) - gap
    win.content:SetSize(width, rows * (size + gap))
    win:SetSize(width + RAIL + 2 * PAD, rows * (size + gap) + HEAD + 32 + FOOT + 2 * PAD)
    local E = Enum.BankType or {}
    local gold = bankType == E.Account and C_Bank.FetchDepositedMoney and C_Bank.FetchDepositedMoney(bankType)
    win.money:SetText(C_CurrencyInfo.GetCoinTextureString(gold or GetMoney()))
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_Bank", UIParent)
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
    win:Hide()
    win.tabs, win.rail = {}, {}
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.title:SetPoint("TOPLEFT", PAD, -PAD - 2)
    win.title:SetText(L.BAGS_BANK_TITLE)
    win.close = M.IconButton(win, "close", CLOSE, function()
        if C_Bank and C_Bank.CloseBankFrame then C_Bank.CloseBankFrame() end
    end)
    win.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 2)
    win.blizz = M.IconButton(win, "link", L.BAGS_BANK_BLIZZARD, function() M:ShowBlizzardBank() end)
    win.blizz:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
    win.sort = M.IconButton(win, "layout", L.BAGS_SORT, function()
        if InCombatLockdown() then return end
        local E = Enum.BankType or {}
        if bankType == E.Account then C_Container.SortAccountBankBags() else C_Container.SortBankBags() end
    end)
    win.sort:SetPoint("RIGHT", win.blizz, "LEFT", -4, 0)
    win.deposit = M.IconButton(win, "import", L.BAGS_BANK_DEPOSIT, function()
        if C_Bank and C_Bank.AutoDepositItemsIntoBank then C_Bank.AutoDepositItemsIntoBank(bankType) end
    end)
    win.deposit:SetPoint("RIGHT", win.sort, "LEFT", -4, 0)
    win.search = CreateFrame("EditBox", nil, win, "BagSearchBoxTemplate")
    win.search:SetSize(130, 18)
    win.search:SetPoint("RIGHT", win.deposit, "LEFT", -8, 0)
    win.content = CreateFrame("Frame", nil, win)
    win.content:SetPoint("TOPLEFT", PAD + RAIL, -PAD - HEAD - 32)
    win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.empty:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -4)
    win.empty:SetText(L.BAGS_BANK_NO_TABS)
    win.money = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.money:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    win:SetScript("OnShow", function() M:LayoutBank() end)
    Skin:Register(win, function() M:StyleBank() end)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("bank", win, L.BAGS_BANK_TITLE) end
end

local visitBlizzard -- the arrow button: Blizzard's bank for the rest of this visit
function M:ShowBlizzardBank()
    visitBlizzard = true
    self:SyncBank()
end

local function bankOpen() return BankFrame and BankFrame:IsShown() and true or false end

local pending
local function soon()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function() pending = nil; M:LayoutBank() end)
end

-- Follows the bank's open state and the switch: our window and a tucked BankFrame, or Blizzard's bank.
function M:SyncBank()
    local want = on() and not visitBlizzard and bankOpen()
    if want then
        if not win then build(); self:StyleBank() end
        if not Skin:Tuck(BankFrame) then want = false end
    end
    if not want then
        if win then win:Hide() end
        if BankFrame then Skin:Untuck(BankFrame) end
        return
    end
    win:Show()
    soon()
end

local listening
function M:SetupBank()
    if listening then self:SyncBank(); return end
    listening = true
    local owner = holders -- distinct owner table for the bank's listeners
    ns.Events:On("BANKFRAME_OPENED", owner, function()
        visitBlizzard, bankType, tabID = false, nil, nil
        C_Timer.After(0, function() M:SyncBank() end)
    end)
    ns.Events:On("BANKFRAME_CLOSED", owner, function() visitBlizzard = false; M:SyncBank() end)
    ns.Events:On("PLAYER_REGEN_ENABLED", owner, function() M:SyncBank() end)
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
        "BANK_TABS_CHANGED", "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE", "PLAYER_MONEY", "BAG_UPDATE_COOLDOWN" }) do
        ns.Events:On(event, owner, soon)
    end
    self:SyncBank()
end

function M:GetBankWindow() return win end
