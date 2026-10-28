local _, ns = ...
local L, W, Skin = ns.L, ns.Widgets, ns.Skin

--[[ The Phoenix bag window (Bags "view" = combined or categories): one window for the backpack, the bags and the
    reagent bag, with columns, slot size and spacing, category sections (new, equipment, consumables,
    reagents, quest, junk, other; reorder or merge them on the settings page), search, sort, gold and
    currencies. Opened and closed by Blizzard's own bag calls: we post-hook them and follow whether
    Blizzard's bag frames are open, so keybinds, the bag bar, vendors, mail and the bank all keep working.

    Safety: item buttons are ours, built from Blizzard's ContainerFrameItemButtonTemplate on frames that carry
    the bag ID, so clicks, drags, tooltips and item use run Blizzard's own item-button code. Blizzard's bag
    frames are tucked away by parenting ContainerFrameContainer (an unprotected holder) to a hidden frame
    of ours; they are never moved, hidden or written to, and the switch back to Blizzard's view is a reload.
    Sorting is C_Container.SortBags; categories only change where buttons are drawn, never where items sit.
    S17: an optional bag bar beside the title shows the equipped bags (icon, the game's item tooltip); hovering
    one dims every slot of the other bags. It only reads the bag slots, it never equips or moves a bag. ]]
local M = ns:GetModule("Bags")

local CATEGORIES = { "new", "equipment", "consumables", "reagents", "quest", "junk", "other" }
M.CATEGORIES = CATEGORIES
local CAT_LABEL = { new = L.BAGS_CAT_NEW, equipment = L.BAGS_CAT_EQUIPMENT, consumables = L.BAGS_CAT_CONSUMABLES,
    reagents = L.BAGS_CAT_REAGENTS, quest = L.BAGS_CAT_QUEST, junk = L.BAGS_CAT_JUNK, other = L.BAGS_CAT_OTHER,
    free = L.BAGS_CAT_FREE, bags = L.BAGS_SECTION_BAGS, reagentBag = L.BAGS_SECTION_REAGENTS }
M.CAT_LABEL = CAT_LABEL
local KNOWN = {}
for _, key in ipairs(CATEGORIES) do KNOWN[key] = true end

-- The saved category order with unknown names dropped and missing ones appended (like DataTexts:Order).
function M:CategoryOrder(list)
    local out, seen = {}, {}
    for key in tostring(list or self.db.categories or ""):gmatch("[^,%s]+") do
        if KNOWN[key] and not seen[key] then out[#out + 1] = key; seen[key] = true end
    end
    for _, key in ipairs(CATEGORIES) do if not seen[key] then out[#out + 1] = key end end
    return out
end

function M:CategoryHidden(key)
    if key == "other" then return false end
    for k in tostring(self.db.hiddenCats or ""):gmatch("[^,%s]+") do if k == key then return true end end
    return false
end

local EQUIP_CLASSES = { [Enum.ItemClass.Weapon] = true, [Enum.ItemClass.Armor] = true }
local REAGENT_CLASSES = { [Enum.ItemClass.Tradegoods] = true, [Enum.ItemClass.Reagent] = true }

-- Category of one slot from plain item data: info = C_Container.GetContainerItemInfo, quest = its quest info,
-- s = M.SlotInfo. Hidden categories fall through to the next match and finally to "other".
function M:Categorize(bag, info, quest, s)
    if not info then return "free" end
    local function on(key) return not self:CategoryHidden(key) end
    if s.new and on("new") then return "new" end
    if s.junk and on("junk") then return "junk" end
    if quest and (quest.isQuestItem or quest.questID) and on("quest") then return "quest" end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if EQUIP_CLASSES[classID] and equipLoc and equipLoc ~= "" and on("equipment") then return "equipment" end
    if classID == Enum.ItemClass.Consumable and on("consumables") then return "consumables" end
    if (REAGENT_CLASSES[classID] or bag > NUM_BAG_SLOTS) and on("reagents") then return "reagents" end
    return "other"
end

-- Display order inside a section; the items themselves stay where they are.
local SORTS = {
    bag = function(a, b) return a.order < b.order end,
    quality = function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.level ~= b.level then return a.level > b.level end
        return a.order < b.order
    end,
    ilvl = function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.order < b.order
    end,
    name = function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.order < b.order
    end,
}
M.SORTS = SORTS

local function bagList()
    local out = {}
    for bag = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do out[#out + 1] = bag end
    return out
end

-- Every slot as a plain record: { bag, slot, order, info, quest, s, cat, quality, level, name }.
function M:ReadSlots()
    local slots, order = {}, 0
    for _, bag in ipairs(bagList()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            order = order + 1
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            local s = info and M.SlotInfo(loc) or {}
            local quest = info and C_Container.GetContainerItemQuestInfo(bag, slot)
            local level = info and C_Item.DoesItemExist(loc) and C_Item.GetCurrentItemLevel(loc) or 0
            slots[#slots + 1] = { bag = bag, slot = slot, order = order, info = info, quest = quest, s = s,
                cat = self:Categorize(bag, info, quest, s), quality = info and info.quality or -1,
                level = level or 0, name = info and info.itemName or "" }
        end
    end
    return slots
end

-- Sections for the current view: { { key, label, slots = {...} } } in display order.
function M:Sections(slots)
    local db, out = self.db, {}
    if db.view == "categories" then
        local by, free = {}, {}
        for _, rec in ipairs(slots) do
            if rec.cat == "free" then free[#free + 1] = rec
            else by[rec.cat] = by[rec.cat] or {}; table.insert(by[rec.cat], rec) end
        end
        for _, key in ipairs(self:CategoryOrder()) do
            local list = by[key]
            if list then
                table.sort(list, SORTS[db.catSort] or SORTS.bag)
                out[#out + 1] = { key = key, label = CAT_LABEL[key], slots = list }
            end
        end
        if #free > 0 then
            if not db.emptySlots then free = { free[1] } end
            out[#out + 1] = { key = "free", label = CAT_LABEL.free, slots = free }
        end
    else
        local main, reagent = {}, {}
        for _, rec in ipairs(slots) do
            if db.reagents and rec.bag > NUM_BAG_SLOTS then reagent[#reagent + 1] = rec else main[#main + 1] = rec end
        end
        out[1] = { key = "bags", slots = main }
        if #reagent > 0 then out[2] = { key = "reagentBag", label = CAT_LABEL.reagentBag, slots = reagent } end
    end
    return out
end

---------------------------------------------------------------- frames
local win, holders, buttons, headers = nil, {}, {}, {}
local PAD, HEAD, FOOT, SECTION = 10, 30, 24, 18

local function holderFor(bag)
    local h = holders[bag]
    if h then return h end
    h = CreateFrame("Frame", nil, win.content)
    h:SetAllPoints()
    h:SetID(bag)
    -- ContainerFrameItemButtonMixin:Initialize asks its parent this; ours is never Blizzard's combined frame
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

local function header(i)
    local fs = headers[i]
    if not fs then
        fs = win.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        headers[i] = fs
    end
    return fs
end

-- Blizzard's item-button refresh for one of our buttons (the body of ContainerFrameMixin:UpdateItems).
local function updateButton(b, rec)
    local info = rec.info
    local texture = info and info.iconFileID
    b:SetHasItem(texture)
    b:SetItemButtonTexture(texture)
    b:SetItemButtonQuality(info and info.quality, info and info.hyperlink, false, info and info.isBound)
    if b.Count then
        local n = info and info.stackCount or 0
        b.Count:SetText(n > 1 and n or "")
        b.Count:SetShown(n > 1)
    end
    if b.icon then b.icon:SetDesaturated(info and info.isLocked or false) end
    b:UpdateExtended()
    local q = rec.quest or {}
    b:UpdateQuestItem(q.isQuestItem, q.questID, q.isActive)
    b:UpdateNewItem(info and info.quality)
    b:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    b:UpdateItemContextMatching()
    b:UpdateCooldown(texture)
    b:SetReadable(info and info.IsReadable)
    b:SetMatchesSearch(not (info and info.isFiltered))
    M.StyleButton(b, ItemLocation:CreateFromBagAndSlot(rec.bag, rec.slot), true)
    local il = ns.modules.ItemLevel
    if il and il.PaintButton then il.PaintButton(b, ItemLocation:CreateFromBagAndSlot(rec.bag, rec.slot)) end
end

local function freeCount()
    local free = 0
    for _, bag in ipairs(bagList()) do free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0) end
    return free
end

function M:UpdateFooter()
    if not win then return end
    local db = self.db
    local parts = {}
    if db.currencies then
        for i = 1, 3 do
            local c = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
            if c and c.iconFileID then
                parts[#parts + 1] = ("|T%d:12:12|t %s"):format(c.iconFileID, BreakUpLargeNumbers(c.quantity or 0))
            end
        end
    end
    win.currencies:SetText(table.concat(parts, "   "))
    win.money:SetText(db.footer and C_CurrencyInfo.GetCoinTextureString(GetMoney()) or "")
    win.free:SetText(db.freeCount and L.BAGS_FREE:format(freeCount()) or "")
end

-- Lays every button out for the current view; cheap enough for BAG_UPDATE_DELAYED (one pass, no new frames
-- once every slot has been seen).
function M:Layout()
    if not (win and win:IsShown()) then return end
    local db = self.db
    local size, gap, cols = db.slotSize, db.spacing, db.columns
    local used = {}
    local y, hi = 0, 0
    for i, sec in ipairs(self:Sections(self:ReadSlots())) do
        hi = i
        local fs = header(i)
        if sec.label then
            Skin:Text(fs, "small", "text.muted", 11)
            fs:SetText(("%s  %d"):format(sec.label, #sec.slots))
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 0, -y)
            fs:Show()
            y = y + SECTION
        else
            fs:Hide()
        end
        for n, rec in ipairs(sec.slots) do
            local b = buttonFor(rec.bag, rec.slot)
            used[b] = true
            b:SetSize(size, size)
            b:ClearAllPoints()
            local col, rowN = (n - 1) % cols, math.floor((n - 1) / cols)
            b:SetPoint("TOPLEFT", win.content, "TOPLEFT", col * (size + gap), -y - rowN * (size + gap))
            b:Show()
            updateButton(b, rec)
        end
        y = y + math.ceil(#sec.slots / cols) * (size + gap) + 4
    end
    for i = hi + 1, #headers do headers[i]:Hide() end
    for _, list in pairs(buttons) do
        for _, b in pairs(list) do if not used[b] then b:Hide() end end
    end
    local width = cols * (size + gap) - gap
    win.content:SetSize(width, math.max(size, y))
    win:SetSize(width + 2 * PAD, y + HEAD + FOOT + 2 * PAD)
    self:UpdateFooter()
    self:UpdateBagBar()
end

function M:StyleWindow()
    if not win then return end
    local db = self.db
    win:SetScale(db.scale)
    Skin:Backdrop(win, db.backdrop, "bg.base")
    Skin:BorderSpec(win, db.border, "border.strong")
    Skin:TextSpec(win.title, db.title, "heading", "accent.primary")
    win.search:SetShown(db.search)
    win.sort:SetShown(db.sortButton)
    for _, fs in ipairs({ win.money, win.currencies, win.free }) do Skin:Text(fs, "small", "text.secondary", 11) end
    self:UpdateBagBar()
end

local function iconButton(parent, icon, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b.icon = W.Icon(b, icon, 14, "text.secondary")
    b.icon:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) ns.Icons:Tint(self.icon, "accent.primary"); W.ShowTooltip(self, tip) end)
    b:SetScript("OnLeave", function(self) ns.Icons:Tint(self.icon, "text.secondary"); W.HideTooltip() end)
    b:SetScript("OnClick", onClick)
    return b
end

local function build()
    win = CreateFrame("Frame", "PhoenixUI_Bags", UIParent)
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110)
    win:Hide()
    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.title:SetPoint("TOPLEFT", PAD, -PAD - 2)
    win.title:SetText(L.BAGS)
    win.close = iconButton(win, "close", CLOSE, function() CloseAllBags() end)
    win.close:SetPoint("TOPRIGHT", -PAD + 4, -PAD + 2)
    win.sort = iconButton(win, "layout", L.BAGS_SORT, function()
        if not InCombatLockdown() then C_Container.SortBags() end
    end)
    win.sort:SetPoint("RIGHT", win.close, "LEFT", -4, 0)
    win.search = CreateFrame("EditBox", nil, win, "BagSearchBoxTemplate")
    win.search:SetSize(140, 18)
    win.search:SetPoint("RIGHT", win.sort, "LEFT", -8, 0)
    win.content = CreateFrame("Frame", nil, win)
    win.content:SetPoint("TOPLEFT", PAD, -PAD - HEAD)
    win.money = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.money:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    win.currencies = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.currencies:SetPoint("RIGHT", win.money, "LEFT", -12, 0)
    win.free = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    win.free:SetPoint("BOTTOMLEFT", PAD, PAD)
    win:SetScript("OnShow", function() M:Layout() end)
    Skin:Register(win, function() M:StyleWindow() end)
    local movers = ns:GetModule("Movers")
    if movers then movers:Register("bags", win, L.BAGS) end
end

---------------------------------------------------------------- bag bar (S17)
-- The equipped bag containers the bar shows (bags 1-4 and the reagent bag), without the backpack.
function M.BarBags()
    local out = {}
    for bag = 1, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4 do out[#out + 1] = bag end
    return out
end

-- Alpha of a slot of `bag` while `focus` is hovered (nil: no bag hovered; pure).
function M.FocusAlpha(bag, focus)
    if focus == nil or bag == focus then return 1 end
    return 0.25
end

-- Inventory slot holding the bag container (nil when the client cannot say).
function M.BagSlot(bag)
    local toInv = C_Container and C_Container.ContainerIDToInventoryID
    return toInv and toInv(bag) or nil
end

local function focusBag(bag)
    M.focusBag = bag
    for b, list in pairs(buttons) do
        for _, btn in pairs(list) do btn:SetAlpha(M.FocusAlpha(b, bag)) end
    end
end

local function buildBagBar()
    local bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("LEFT", win.title, "RIGHT", 10, 0)
    bar.buttons = {}
    for i, bag in ipairs(M.BarBags()) do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(16, 16)
        b:SetPoint("LEFT", (i - 1) * 19, 0)
        b.bag = bag
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b:SetScript("OnEnter", function(self)
            focusBag(self.bag)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local slot = M.BagSlot(self.bag)
            local link = slot and GetInventoryItemLink("player", slot)
            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(EQUIP_CONTAINER) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() focusBag(nil); GameTooltip:Hide() end)
        bar.buttons[i] = b
    end
    bar:SetSize(#bar.buttons * 19, 16)
    win.bagBar = bar
end

function M:UpdateBagBar()
    if not win then return end
    if not self.db.bagBar then
        if win.bagBar then win.bagBar:Hide() end
        return
    end
    if not win.bagBar then buildBagBar() end
    for _, b in ipairs(win.bagBar.buttons) do
        local slot = M.BagSlot(b.bag)
        local tex = slot and GetInventoryItemTexture("player", slot)
        -- item art is always the game's: the equipped bag's icon, or the game's empty bag-slot art
        if ns.Icons:Owns(b.icon) then ns.Icons:Release(b.icon) end
        b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        b.icon:SetAlpha(tex and 1 or 0.6)
        Skin:BorderSpec(b, self.db.slotBorder, "border.default")
    end
    win.bagBar:Show()
end

---------------------------------------------------------------- open / close follow Blizzard's bag frames
local function blizzardOpen()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end
    for i = 1, NUM_CONTAINER_FRAMES do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then return true end
    end
    return false
end
M.BlizzardBagsOpen = blizzardOpen

local syncPending
local function sync()
    syncPending = nil
    if not win then return end
    local open = blizzardOpen()
    if open and not win:IsShown() then win:Show() elseif not open and win:IsShown() then win:Hide() end
end
local function soonSync()
    if syncPending then return end
    syncPending = true
    C_Timer.After(0, sync)
end
M.SyncWindow = sync

local pending
local function soonLayout()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function() pending = nil; M:Layout() end)
end

local tuckParent
function M:UsesWindow() return self.db.view == "combined" or self.db.view == "categories" end

local hooked
function M:EnableWindow()
    if not self:UsesWindow() then return end
    if not win then build() end
    -- Blizzard's bag frames stay alive (they still open and close) but draw nowhere.
    if ContainerFrameContainer and not tuckParent then
        tuckParent = CreateFrame("Frame")
        tuckParent:Hide()
        ContainerFrameContainer:SetParent(tuckParent)
    end
    if not hooked then
        hooked = true
        for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "OpenBackpack", "CloseBackpack",
            "ToggleBackpack", "OpenBag", "CloseBag", "ToggleBag" }) do
            if _G[name] then hooksecurefunc(name, soonSync) end
        end
    end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED",
        "UNIT_QUEST_LOG_CHANGED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "INVENTORY_SEARCH_UPDATE", "ITEM_LOCK_CHANGED",
        "BAG_UPDATE_COOLDOWN" }) do
        ns.Events:On(event, win, soonLayout)
    end
    ns.Events:On("PLAYER_MONEY", win, function() M:UpdateFooter() end)
    ns.Events:On("CURRENCY_DISPLAY_UPDATE", win, function() M:UpdateFooter() end)
    sync()
end

function M:RefreshWindow()
    if not win then return end
    self:StyleWindow()
    self:Layout()
end

function M:GetWindow() return win end
