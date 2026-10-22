local _, ns = ...
local L = ns.L
local Theme, Skin, Style = ns.Theme, ns.Skin, ns.Style

--[[ Item level badges on item buttons: the character sheet, inspect, bags (Blizzard's and Phoenix's, through
    M.PaintButton), the equipment flyout, loot and group rolls, and the merchant. Text lives in a weak side
    table keyed by the Blizzard button, never as a field on it; every hook is a post-hook and every
    frame read (button.location, frame.rollID) is a plain field read. Item data is never secret.
    Extra lines under the number (S16): the upgrade track ("Hero 4/6", C_Item.GetItemUpgradeInfo), the
    enchant (tooltip data line ItemEnchantmentPermanent) and a warning for empty gem sockets. ]]
local M = ns:NewModule("ItemLevel", {
    label = "ITEMLEVEL", desc = "ITEMLEVEL_DESC", category = "interface", order = 70,
    defaults = {
        enabled = true, character = true, bags = true, inspect = true, flyout = true, loot = true, merchant = true,
        qualityColor = true, size = 12,
        text = Style.Text(12, { anchor = "TOPRIGHT", x = -1, y = -2, outline = "OUTLINE", shadow = false }),
        track = false, enchant = false, gems = true, decimals = 1, statsPanel = false,
    },
})

local labels = setmetatable({}, { __mode = "k" })
local extras = setmetatable({}, { __mode = "k" })
local NO_ILVL_SLOTS = { [INVSLOT_BODY] = true, [INVSLOT_TABARD] = true }
local ENCHANT_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent

-- One badge in the module's text spec; db.size is the old single size and stays the size source.
function M:StyleLabel(fs, parent)
    local spec = self.db.text
    spec.size = self.db.size
    Skin:TextSpec(fs, spec, "number")
    Skin:Place(fs, parent, spec)
end

local function label(button)
    local fs = labels[button]
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY")
        labels[button] = fs
    end
    M:StyleLabel(fs, button)
    return fs
end

-- Second line (track, enchant, gem warning) under the badge, only for the gear slots that ask for it.
local function extra(button)
    local fs = extras[button]
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("BOTTOMLEFT", 1, 1)
        fs:SetPoint("BOTTOMRIGHT", -1, 1)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        extras[button] = fs
    end
    Skin:Text(fs, "small", "text.secondary", math.max(8, M.db.size - 3), "OUTLINE")
    return fs
end

function M.ColorFor(quality)
    local color = M.db.qualityColor and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    if type(M.db.text.color) == "table" then return Skin:SpecColor(M.db.text.color) end
    return Theme:Color("text.primary")
end

local function show(button, level, quality)
    local fs = label(button)
    if not level or level <= 1 then fs:SetText(""); return end
    fs:SetText(level)
    fs:SetTextColor(M.ColorFor(quality))
end

local function clear(button)
    if labels[button] then labels[button]:SetText("") end
    if extras[button] then extras[button]:SetText("") end
end

---------------------------------------------------------------- details (track, enchant, sockets)
local function emptySockets(link)
    local n = tonumber(C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(link)) or 0
    local empty = 0
    for i = 1, n do
        if not C_Item.GetItemGem(link, i) then empty = empty + 1 end
    end
    return empty
end

local function enchantOf(slot, unit)
    if not (ENCHANT_LINE and C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local data = C_TooltipInfo.GetInventoryItem(unit or "player", slot)
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == ENCHANT_LINE and line.leftText then
            -- "Enchanted: +20 Agility" -> "+20 Agility"
            return (line.leftText:gsub("^[^:]+:%s*", ""))
        end
    end
end

function M.DetailsText(db, link, slot, unit)
    local parts = {}
    if db.track and C_Item.GetItemUpgradeInfo then
        local info = C_Item.GetItemUpgradeInfo(link)
        if info and info.trackString and info.maxLevel and info.maxLevel > 0 then
            parts[#parts + 1] = ("%s %d/%d"):format(info.trackString, info.currentLevel, info.maxLevel)
        end
    end
    if db.enchant and slot then
        local e = enchantOf(slot, unit)
        if e then parts[#parts + 1] = "|cff3ddc97" .. e .. "|r" end
    end
    if db.gems and emptySockets(link) > 0 then parts[#parts + 1] = "|cffff4d5e" .. L.ITEMLEVEL_NO_GEM .. "|r" end
    return table.concat(parts, " · ")
end

local function paintDetails(button, link, slot, unit)
    local db = M.db
    if not (db.track or db.enchant or db.gems) or not link then
        if extras[button] then extras[button]:SetText("") end
        return
    end
    extra(button):SetText(M.DetailsText(db, link, slot, unit))
end

---------------------------------------------------------------- where
local function paint(button, location)
    if not (M:IsEnabled() and location and C_Item.DoesItemExist(location)) then clear(button); return end
    show(button, C_Item.GetCurrentItemLevel(location), C_Item.GetItemQuality(location))
end

local function paintLink(button, link)
    if not (M:IsEnabled() and link) then clear(button); return end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    local _, _, quality = C_Item.GetItemInfo(link)
    show(button, level, quality)
end

local function gearSlot(slot) return not NO_ILVL_SLOTS[slot] and slot >= INVSLOT_HEAD and slot <= INVSLOT_LAST_EQUIPPED end

local function onSlotUpdate(button)
    if not M.db.character then return end
    local slot = button:GetID()
    if not gearSlot(slot) then return end
    paint(button, ItemLocation:CreateFromEquipmentSlot(slot))
    if M:IsEnabled() then paintDetails(button, GetInventoryItemLink("player", slot), slot, "player") end
end

local function onInspectSlot(button)
    if not (M:IsEnabled() and M.db.inspect and InspectFrame) then return end
    local slot, unit = button:GetID(), InspectFrame.unit
    if not (unit and gearSlot(slot)) then return end
    local link = GetInventoryItemLink(unit, slot)
    paintLink(button, link)
    paintDetails(button, link)
end

local EQUIPPABLE_SKIP = { [""] = true, INVTYPE_BAG = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_QUIVER = true }
-- link when it is gear worth a badge, else nil
local function gearLink(link)
    if not link then return nil end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    return (equipLoc and not EQUIPPABLE_SKIP[equipLoc]) and link or nil
end
-- One bag-style button (Blizzard's bags and bank, the Phoenix bag window): gear only.
local function paintBagButton(button, location)
    if not M:IsEnabled() then return end
    local wanted = false
    if M.db.bags and C_Item.DoesItemExist(location) then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(C_Item.GetItemID(location))
        wanted = equipLoc ~= nil and not EQUIPPABLE_SKIP[equipLoc]
    end
    paint(button, wanted and location or nil)
end
M.PaintButton = paintBagButton

local function onBagUpdate(frame)
    if not M:IsEnabled() then return end
    for _, button in frame:EnumerateValidItems() do
        paintBagButton(button, ItemLocation:CreateFromBagAndSlot(button:GetBagID(), button:GetID()))
    end
end

local function eachBag(fn)
    for i = 1, NUM_CONTAINER_FRAMES or 0 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.UpdateItems then fn(frame) end
    end
    if ContainerFrameCombinedBags then fn(ContainerFrameCombinedBags) end
end

-- The flyout's button.location packs player slot or bag/slot (EquipmentManager_GetLocationData).
local function onFlyout(button)
    if not (M:IsEnabled() and M.db.flyout) then return end
    local location = button.location
    if not location or location >= (EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION or math.huge) then clear(button); return end
    local data = EquipmentManager_GetLocationData(location)
    if data.isBags and data.bag then
        paint(button, ItemLocation:CreateFromBagAndSlot(data.bag, data.slot))
    elseif data.isPlayer and data.slot then
        paint(button, ItemLocation:CreateFromEquipmentSlot(data.slot))
    else
        clear(button)
    end
end

local function onMerchant()
    if not (M:IsEnabled() and M.db.merchant and MerchantFrame) then return end
    for i = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        if button then
            local index = ((MerchantFrame.page or 1) - 1) * (MERCHANT_ITEMS_PER_PAGE or 10) + i
            paintLink(button, gearLink(GetMerchantItemLink(index)))
        end
    end
end

local function onLoot()
    if not (M:IsEnabled() and M.db.loot and LootFrame and LootFrame.ScrollBox) then return end
    LootFrame.ScrollBox:ForEachFrame(function(frame)
        local item = frame.Item
        if item and frame.GetSlotIndex then
            paintLink(item, gearLink(GetLootSlotLink(frame:GetSlotIndex())))
        end
    end)
end

local function onRoll(frame)
    if not (M:IsEnabled() and M.db.loot and frame.rollID and frame.IconFrame) then return end
    paintLink(frame.IconFrame, GetLootRollItemLink(frame.rollID))
end

-- Character sheet average: Blizzard rounds down; show the decimals asked for.
local function onAverage(statFrame, unit)
    if not (M:IsEnabled() and M.db.character and M.db.decimals > 0 and unit == "player" and statFrame.Value) then return end
    local _, equipped = GetAverageItemLevel()
    local floor_ = C_PaperDollInfo and C_PaperDollInfo.GetMinItemLevel and C_PaperDollInfo.GetMinItemLevel() or 0
    statFrame.Value:SetText(("%." .. M.db.decimals .. "f"):format(math.max(floor_, equipped or 0)))
end

---------------------------------------------------------------- stats panel (S17)
--[[ The character sheet's stat list: a post-hook of PaperDollFrame_UpdateStats fades Blizzard's row and
    category art, lays a theme stripe of ours behind every row Blizzard would stripe, and sets theme fonts and
    colours on the labels. The pane is not secure; nothing is moved or resized. ]]
M.STAT_CATEGORIES = { "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }
local stripes = setmetatable({}, { __mode = "k" })

function M.StyleStatRow(row)
    if not row then return end
    local bg = row.Background
    local stripe = stripes[row]
    if not stripe then
        stripe = row:CreateTexture(nil, "BACKGROUND", nil, -7)
        stripe:SetTexture(ns.Media.textures.WHITE)
        stripe:SetAllPoints()
        stripes[row] = stripe
    end
    if bg then Skin:HideRegion(bg) end
    stripe:SetVertexColor(Theme:Color("bg.raised"))
    stripe:SetShown(bg == nil or bg:IsShown())
    if row.Label then Skin:Text(row.Label, "body", "text.secondary", 11) end
    if row.Value and row ~= (CharacterStatsPane and CharacterStatsPane.ItemLevelFrame) then
        Skin:Text(row.Value, "number", "text.primary", 11)
    end
end

function M.StyleStatCategory(cat)
    if not cat then return end
    if cat.Background then Skin:HideRegion(cat.Background) end
    if cat.Title then Skin:Text(cat.Title, "heading", "accent.primary", 12) end
end

function M.StyleStats()
    local pane = CharacterStatsPane
    if not (pane and M:IsEnabled() and M.db.statsPanel) then return end
    for _, key in ipairs(M.STAT_CATEGORIES) do M.StyleStatCategory(pane[key]) end
    M.StyleStatRow(pane.ItemLevelFrame)
    local pool = pane.statsFramePool
    if pool and pool.EnumerateActive then
        for row in pool:EnumerateActive() do M.StyleStatRow(row) end
    end
end

local hookedInspect
local function hookInspect()
    if hookedInspect or type(InspectPaperDollItemSlotButton_Update) ~= "function" then return end
    hookedInspect = true
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", onInspectSlot)
end

local function hookOptional()
    if type(EquipmentFlyout_DisplayButton) == "function" then hooksecurefunc("EquipmentFlyout_DisplayButton", onFlyout) end
    if type(MerchantFrame_UpdateMerchantInfo) == "function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", onMerchant)
    end
    if LootFrame and LootFrame.Open then hooksecurefunc(LootFrame, "Open", onLoot) end
    for i = 1, 4 do
        local f = _G["GroupLootFrame" .. i]
        if f and f.HookScript then f:HookScript("OnShow", onRoll) end
    end
    if type(PaperDollFrame_SetItemLevel) == "function" then hooksecurefunc("PaperDollFrame_SetItemLevel", onAverage) end
    if type(PaperDollFrame_UpdateStats) == "function" then hooksecurefunc("PaperDollFrame_UpdateStats", M.StyleStats) end
    hookInspect()
end

local hooked
function M:OnEnable()
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    ns.Events:On("ADDON_LOADED", self, hookInspect) -- Blizzard_InspectUI loads on demand
    if hooked then self:Refresh(); return end
    hooked = true
    hooksecurefunc("PaperDollItemSlotButton_Update", onSlotUpdate)
    eachBag(function(frame) hooksecurefunc(frame, "UpdateItems", onBagUpdate) end)
    hookOptional()
end

function M:OnDisable()
    for _, fs in pairs(labels) do fs:SetText("") end
    for _, fs in pairs(extras) do fs:SetText("") end
end

-- Re-paints what is on screen: character slots directly, bags through the same path as UpdateItems.
function M:Refresh()
    for button in pairs(labels) do
        if button:IsVisible() and button.GetBagID == nil and button.location == nil then onSlotUpdate(button) end
    end
    eachBag(function(frame) if frame:IsShown() then onBagUpdate(frame) end end)
    if MerchantFrame and MerchantFrame:IsShown() then onMerchant() end
end
