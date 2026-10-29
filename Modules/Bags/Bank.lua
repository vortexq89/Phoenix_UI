local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin

--[[ The Phoenix bank window: our own window for the character bank and the Warband bank, drawn from the bank
    API (C_Bank tab data, C_Container slots) in the Phoenix look: bank-type rail, tab strip with the tabs' own
    icons, a slot grid, search, sort, deposit reagents and the Warband gold. Tab settings (the cog: name and
    which items auto-deposit there, saved with the bank's own update call; the tab icon is kept) and gold
    deposit / withdraw where the bank type allows it (the game's own checks and calls, on your click).
    Bags > "Phoenix bank window" off brings back Blizzard's bank (reskinned), live; the arrow button opens
    Blizzard's bank for this visit only (buying tabs, the tab icon picker).

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
    self:LayoutBankExtras()
end

function M:LayoutBankExtras()
    local transfer = C_Bank.DoesBankTypeSupportMoneyTransfer and C_Bank.DoesBankTypeSupportMoneyTransfer(bankType) or false
    win.gold:SetShown(transfer)
    win.goldIn:SetShown(transfer and C_Bank.CanDepositMoney(bankType) or false)
    win.goldOut:SetShown(transfer and C_Bank.CanWithdrawMoney(bankType) or false)
    win.cog:SetShown(tabID ~= nil)
    if win.settings:IsShown() then M:LayoutBankSettings() end
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
    win.cog = M.IconButton(win, "cog", L.BAGS_BANK_SETTINGS, function()
        if win.settings:IsShown() then win.settings:Hide() else win.settings:Show(); M:LayoutBankSettings() end
    end)
    win.cog:SetPoint("RIGHT", win.deposit, "LEFT", -4, 0)
    M:BuildBankExtras()
    win.search = CreateFrame("EditBox", nil, win, "BagSearchBoxTemplate")
    win.search:SetSize(130, 18)
    win.search:SetPoint("RIGHT", win.cog, "LEFT", -8, 0)
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

---------------------------------------------------------------- tab settings and gold
-- Deposit filters a tab can take (Enum.BagSlotFlags names; missing ones are skipped).
M.BANK_FLAGS = { { "ExpansionCurrent", L.BAGS_FLAG_CURRENT }, { "ExpansionLegacy", L.BAGS_FLAG_LEGACY },
    { "ClassEquipment", L.BAGS_CAT_EQUIPMENT }, { "ClassConsumables", L.BAGS_CAT_CONSUMABLES },
    { "ClassProfessionGoods", L.BAGS_FLAG_PROFESSION }, { "ClassReagents", L.BAGS_CAT_REAGENTS },
    { "ClassJunk", L.BAGS_CAT_JUNK }, { "ClassQuestItems", L.BAGS_CAT_QUEST } }

function M.BankFlagOn(flags, bitValue) return bit.band(tonumber(flags) or 0, bitValue) ~= 0 end

local function tabData()
    for _, t in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do
        if type(t) == "table" and t.ID == tabID then return t end
    end
end

function M:BuildBankExtras()
    local s = CreateFrame("Frame", nil, win)
    s:SetSize(220, 60 + #M.BANK_FLAGS * 24)
    s:SetPoint("TOPLEFT", win, "TOPRIGHT", 6, 0)
    s:SetFrameLevel(win:GetFrameLevel() + 10)
    s:EnableMouse(true)
    s:Hide()
    win.settings = s
    s.name = W:Input(s, 196, L.BAGS_BANK_TAB_NAME)
    s.name:SetPoint("TOPLEFT", 12, -12)
    s.checks = {}
    local E = Enum.BagSlotFlags or {}
    local y = -46
    for _, def in ipairs(M.BANK_FLAGS) do
        local value = E[def[1]]
        if type(value) == "number" then
            local c = CreateFrame("Button", nil, s)
            c:SetSize(196, 20)
            c:SetPoint("TOPLEFT", 12, y)
            c.box = W.Texture(c, "ARTWORK", 1); c.box:SetSize(14, 14); c.box:SetPoint("LEFT")
            c.label = W.Text(c, "small", "text.secondary"); c.label:SetPoint("LEFT", 22, 0); c.label:SetText(def[2])
            c.value = value
            c:SetScript("OnClick", function(self) self.on = not self.on; M.PaintBankCheck(self) end)
            s.checks[#s.checks + 1] = c
            y = y - 24
        end
    end
    s.save = W:Button(s, SAVE or "Save", "primary", nil, 90)
    s.save:SetHeight(22)
    s.save:SetPoint("BOTTOMLEFT", 12, 10)
    s.save.onClick = function() M:SaveBankTab() end
    Skin:Register(s, function(self) Skin:Panel(self, "base", { border = "border.strong" }) end)
    -- gold transfer (bank types that allow it)
    win.gold = W:Input(win, 90, L.BAGS_BANK_GOLD)
    win.gold:SetNumeric(true)
    win.gold:SetPoint("BOTTOMLEFT", PAD, PAD - 4)
    win.goldIn = M.IconButton(win, "import", L.BAGS_BANK_DEPOSIT_GOLD, function() M:BankMoney(true) end)
    win.goldIn:SetPoint("LEFT", win.gold, "RIGHT", 4, 0)
    win.goldOut = M.IconButton(win, "export", L.BAGS_BANK_WITHDRAW_GOLD, function() M:BankMoney(false) end)
    win.goldOut:SetPoint("LEFT", win.goldIn, "RIGHT", 4, 0)
end

function M.PaintBankCheck(c)
    W.Color(c.box, c.on and "accent.primary" or "bg.sunken", 1)
end

function M:LayoutBankSettings()
    local t = tabData()
    local s = win.settings
    if not t then s:Hide(); return end
    s.name:SetValue(t.name or "")
    for _, c in ipairs(s.checks) do c.on = M.BankFlagOn(t.depositFlags, c.value); M.PaintBankCheck(c) end
end

function M:SaveBankTab()
    local t = tabData()
    if not t then return end
    local flags = tonumber(t.depositFlags) or 0
    for _, c in ipairs(win.settings.checks) do
        if c.on then flags = bit.bor(flags, c.value) elseif M.BankFlagOn(flags, c.value) then flags = flags - c.value end
    end
    local name = win.settings.name:GetText()
    C_Bank.UpdateBankTabSettings(bankType, tabID, (name ~= nil and name ~= "") and name or t.name, t.icon, flags)
    win.settings:Hide()
end

function M:BankMoney(deposit)
    local copper = (tonumber(win.gold:GetText()) or 0) * 10000
    if copper <= 0 then return end
    if deposit then C_Bank.DepositMoney(bankType, copper) else C_Bank.WithdrawMoney(bankType, copper) end
    win.gold:SetValue("")
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
        "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "ACCOUNT_MONEY", "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE",
        "PLAYER_MONEY", "BAG_UPDATE_COOLDOWN" }) do
        ns.Events:On(event, owner, soon)
    end
    self:SyncBank()
end

function M:GetBankWindow() return win end
