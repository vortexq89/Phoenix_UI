local _, ns = ...
local L, Theme, Skin, Style = ns.L, ns.Theme, ns.Skin, ns.Style

--[[ Bags: Phoenix look for Blizzard's bag windows (separate and combined) and their item buttons, plus an
    upgrade arrow on gear that beats what you wear. Item level numbers come from the ItemLevel module.
    When the Sim module has a recent result for an item, the sim decides: the arrow shows (in the accent
    colour) only when the sim found a DPS gain, and hides when it found a loss, whatever the item level says.

    Safety: bag windows and item buttons are dressed after Blizzard's own UpdateItems runs (post-hook only).
    Art is hidden with alpha, and every new region or frame is ours, kept in weak side tables keyed by the
    Blizzard button; no field is written on a Blizzard frame and nothing is re-anchored or resized, so
    using items from the bags stays untainted. Item levels are plain numbers (no secret values).
    The same dressing (slot border, count font, junk coin, new-item glow, bind label, cooldowns) is used by the
    Phoenix bag window (Bags/Window.lua) and on the bank's item buttons. Selling junk and repairing belong to
    Automation; the settings page only mirrors them. ]]
local M = ns:NewModule("Bags", {
    label = "BAGS", desc = "BAGS_DESC", icon = "items", category = "interface", order = 72, reloadOnToggle = true,
    defaults = {
        enabled = true, skin = true, quality = true, upgrade = true, simArrow = true,
        -- window: "categories" or "combined" (the Phoenix window, default) or "blizzard" (Blizzard's windows, restyled)
        view = "categories", columns = 12, slotSize = 36, spacing = 3, scale = 1, reagents = true,
        categories = "new,equipment,consumables,reagents,quest,junk,other", hiddenCats = "", catSort = "quality",
        emptySlots = true, search = true, sortButton = true, footer = true, currencies = true, freeCount = true,
        bagBar = false,                                    -- S17: the equipped bags beside the title
        backdrop = Style.Background({ alpha = 0.92 }), border = Style.Border(), title = Style.Text(13),
        slotBorder = Style.Border({ style = "solid" }),
        count = Style.Text(12, { outline = "OUTLINE", anchor = "BOTTOMRIGHT", x = -2, y = 2 }),
        junk = true, junkDim = false, newGlow = "phoenix", bind = true, cooldowns = true,
        bankSkin = true, openAuction = false, openTrade = false, process = true,
    },
})

local deco = setmetatable({}, { __mode = "k" }) -- [button] = { frame, arrow, bg }
local skinned = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------- upgrade check
-- Inventory type -> equipment slots it can go in. Weapons only compare against the main hand when
-- two-handed, so a dual-wield off-hand is never called an upgrade over a two-hander by mistake.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
}
M.SLOTS = SLOTS
-- The armour type each class wears from level 50 (cloaks are cloth for everyone and are exempt).
local ARMOR = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2, MAGE = 1, PRIEST = 1, WARLOCK = 1 }
M.ARMOR = ARMOR

local equipped = {} -- [slot] = item level (0 when empty)
local function readEquipped()
    for slot = INVSLOT_HEAD, INVSLOT_LAST_EQUIPPED do
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        equipped[slot] = C_Item.DoesItemExist(loc) and C_Item.GetCurrentItemLevel(loc) or 0
    end
end
M.equipped = equipped

-- level, equipLoc, classID, subclassID, itemID -> true when the item would raise an equipped slot.
function M:IsUpgrade(level, equipLoc, classID, subclassID, itemID, classFile)
    local slots = SLOTS[equipLoc]
    if not (slots and level and level > 1) then return false end
    if classID == Enum.ItemClass.Armor and equipLoc ~= "INVTYPE_CLOAK" and subclassID and subclassID >= 1 and subclassID <= 4 then
        if ARMOR[classFile] and subclassID ~= ARMOR[classFile] then return false end
    end
    if itemID and not C_PlayerInfo.CanUseItem(itemID) then return false end
    local lowest
    for _, slot in ipairs(slots) do
        local have = equipped[slot] or 0
        if not lowest or have < lowest then lowest = have end
    end
    return lowest ~= nil and level > lowest
end

---------------------------------------------------------------- dressing
local QUALITY_MIN = Enum.ItemQuality.Uncommon

local function decoFor(button)
    local d = deco[button]
    if d then return d end
    d = {}
    d.bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.bg:SetTexture(ns.Media.textures.WHITE)
    d.bg:SetAllPoints()
    d.over = CreateFrame("Frame", nil, button)
    d.over:SetAllPoints()
    d.over:SetFrameLevel(button:GetFrameLevel() + 3)
    d.arrow = ns.Icons:Create(d.over, "arrow-up", 14, "state.success")
    d.arrow:SetPoint("TOPLEFT", 1, -1)
    d.arrow:Hide()
    d.coin = ns.Icons:Create(d.over, "gold", 12, "state.warning")
    d.coin:SetPoint("TOPLEFT", 2, -2)
    d.coin:Hide()
    d.bind = d.over:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.bind:SetPoint("BOTTOMLEFT", 2, 2)
    d.glow = CreateFrame("Frame", nil, button)
    d.glow:SetAllPoints()
    d.glow:SetFrameLevel(button:GetFrameLevel() + 2)
    d.glow:Hide()
    deco[button] = d
    return d
end

-- What a slot holds, read once per update: quality, junk, new, bind label (all plain values).
local function slotInfo(location)
    local out = {}
    if not (location and C_Item.DoesItemExist(location)) then return out end
    out.exists = true
    out.quality = C_Item.GetItemQuality(location)
    local bag, slot
    if location.GetBagAndSlot then bag, slot = location:GetBagAndSlot() end
    if not slot then bag = nil end
    local info = bag and C_Container.GetContainerItemInfo(bag, slot)
    out.junk = out.quality == Enum.ItemQuality.Poor and not (info and info.hasNoValue)
    out.new = bag and C_NewItems.IsNewItem(bag, slot) or false
    if not C_Item.IsBound(location) then
        if C_Item.IsBoundToAccountUntilEquip(location) then
            out.bind = L.BAGS_WUE
        else
            local link = C_Item.GetItemLink(location)
            local bindType = link and select(14, C_Item.GetItemInfo(link))
            if bindType == Enum.ItemBind.OnEquip then out.bind = L.BAGS_BOE end
        end
    end
    return out
end
M.SlotInfo = slotInfo

-- Junk coin and dimming, new-item glow, bind label and (own buttons) cooldown visibility.
local function marks(button, d, s, own)
    local db = M.db
    d.coin:SetShown(db.junk and s.junk or false)
    if button.icon and db.junkDim and s.junk then button.icon:SetDesaturated(true) end
    -- new items: Blizzard's pulsing glow, the Phoenix accent glow, or nothing
    local phoenixNew = s.new and db.newGlow == "phoenix"
    if db.newGlow ~= "blizzard" then
        Skin:HideRegion(button.NewItemTexture)
        Skin:HideRegion(button.flash)
    end
    if phoenixNew then Skin:BorderSpec(d.glow, { style = "ember", size = 1 }) end
    d.glow:SetShown(phoenixNew or false)
    Skin:Text(d.bind, "small", "text.secondary", 9, "OUTLINE")
    d.bind:SetText(db.bind and s.bind or "")
    if own and button.Cooldown and not db.cooldowns then button.Cooldown:Hide() end
end

-- up, simmed: a sim result for this exact item decides (gain or not); otherwise item level does.
local function upgradeOf(location, exists)
    local db = M.db
    if not (db.upgrade and exists) then return false, false end
    local Sim = db.simArrow and ns.modules.Sim
    local r = Sim and Sim.active and Sim:ItemResult(C_Item.GetItemLink(location))
    if r then return r.pct > 0, true end
    local itemID = C_Item.GetItemID(location)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if not SLOTS[equipLoc] then return false, false end
    local _, classFile = UnitClass("player")
    return M:IsUpgrade(C_Item.GetCurrentItemLevel(location), equipLoc, classID, subclassID, itemID, classFile), false
end

-- own = true for the Phoenix window's buttons: their count may be placed and their cooldown hidden.
local function styleButton(button, location, own)
    local db = M.db
    local d = decoFor(button)
    local s = slotInfo(location)
    local exists, quality = s.exists, s.quality
    if db.skin then
        Skin:HideRegion(button:GetNormalTexture())
        Skin:HideRegion(button.IconBorder)
        d.bg:SetVertexColor(Theme:Color("bg.sunken"))
        d.bg:Show()
        local spec = {}
        for k, v in pairs(db.slotBorder) do spec[k] = v end
        local color = db.quality and type(quality) == "number" and quality >= QUALITY_MIN and ITEM_QUALITY_COLORS[quality]
        if color then spec.color = { r = color.r, g = color.g, b = color.b } end
        if button.icon then Skin:IconFrame(button, button.icon, spec, 0.08, "border.black") end
        if button.Count then
            Skin:TextSpec(button.Count, db.count, "number")
            if own then Skin:Place(button.Count, button, db.count) end
        end
    else
        -- switched off live: Blizzard's slot art, quality border, icon crop and count font back
        d.bg:Hide()
        Skin:Restore(button:GetNormalTexture())
        Skin:Restore(button.IconBorder)
        if button.icon then Skin:HideIconFrame(button.icon) end
        if button.Count then Skin:Restore(button.Count) end
    end
    marks(button, d, s, own)
    local up, simmed = upgradeOf(location, exists)
    if up then ns.Icons:Tint(d.arrow, simmed and "accent.primary" or "state.success") end
    d.arrow:SetShown(up)
    if up then d.coin:Hide() end
end
M.StyleButton = styleButton

local ART = { "Bg", "NineSlice", "TopTileStreaks" }
local function unskinWindow(frame)
    if not skinned[frame] then return end
    skinned[frame] = nil
    for _, key in ipairs(ART) do Skin:Restore(frame[key]) end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then Skin:Restore(title) end
    Skin:Restore(frame)
end
M.UnskinWindow = unskinWindow
function M.IsWindowSkinned(frame) return skinned[frame] and true or false end

local function skinWindow(frame, on)
    if on == nil then on = M.db.skin end
    if not on then unskinWindow(frame); return end
    if skinned[frame] then return end
    skinned[frame] = true
    for _, key in ipairs(ART) do Skin:HideRegion(frame[key]) end
    Skin:Register(frame, function(self)
        Skin:Backdrop(self, M.db.backdrop, "bg.base")
        Skin:BorderSpec(self, M.db.border, "border.strong")
        local title = self.TitleContainer and self.TitleContainer.TitleText
        if title then Skin:TextSpec(title, M.db.title, "heading", "accent.primary") end
    end)
end
M.SkinWindow = skinWindow

local function onUpdateItems(frame)
    if not M:IsEnabled() then return end
    skinWindow(frame)
    for _, button in frame:EnumerateValidItems() do
        styleButton(button, ItemLocation:CreateFromBagAndSlot(button:GetBagID(), button:GetID()))
        if M.DimSlot then M.DimSlot(button, button:GetBagID(), button:GetID()) end -- Chrome.lua chips
    end
end

local function eachBag(fn)
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.UpdateItems then fn(frame) end
    end
    if ContainerFrameCombinedBags then fn(ContainerFrameCombinedBags) end
end

---------------------------------------------------------------- bank (Blizzard's window, same slot look)
local function bankLocation(button)
    return ItemLocation:CreateFromBagAndSlot(button:GetBankTabID(), button:GetContainerSlotID())
end
local function onBankItems(panel)
    if not M:IsEnabled() then return end
    if not (M.db.bankSkin and M.db.skin) then
        -- switched off live: the bank window and its slots back to Blizzard's look
        if BankFrame then unskinWindow(BankFrame) end
        local saved = M.db.skin
        M.db.skin = false
        for button in panel:EnumerateValidItems() do styleButton(button, bankLocation(button)) end
        M.db.skin = saved
        return
    end
    if BankFrame then skinWindow(BankFrame) end
    local il = ns.modules.ItemLevel
    for button in panel:EnumerateValidItems() do
        local location = bankLocation(button)
        styleButton(button, location)
        if il and il.PaintButton then il.PaintButton(button, location) end
    end
end
M.OnBankItems = onBankItems

function M:Refresh()
    eachBag(function(frame) if frame:IsShown() then onUpdateItems(frame) end end)
    if BankPanel and BankPanel:IsShown() then onBankItems(BankPanel) end
    if self.RefreshWindow then self:RefreshWindow() end
    if self.DressAllChrome then self:DressAllChrome() end
    if self.PaintBankTabs and BankPanel then self.PaintBankTabs(BankPanel) end
end

local hooked
function M:OnEnable()
    readEquipped()
    ns.Events:On("PLAYER_EQUIPMENT_CHANGED", self, function() readEquipped(); M:Refresh() end)
    ns.Events:On("PLAYER_LEVEL_UP", self, function() M:Refresh() end)
    ns.Events:Listen("PUI_SIM_RESULTS", self, self.Refresh)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    ns.Events:On("AUCTION_HOUSE_SHOW", self, function() if M.db.openAuction then OpenAllBags() end end)
    ns.Events:On("TRADE_SHOW", self, function() if M.db.openTrade then OpenAllBags() end end)
    if self.EnableWindow then self:EnableWindow() end
    if self.SetupChrome then self:SetupChrome() end -- Chrome.lua
    if self.SetupProcess then self:SetupProcess() end -- Process.lua
    if hooked then self:Refresh(); return end
    hooked = true
    eachBag(function(frame) hooksecurefunc(frame, "UpdateItems", onUpdateItems) end)
    if BankPanel then
        hooksecurefunc(BankPanel, "GenerateItemSlotsForSelectedTab", onBankItems)
        hooksecurefunc(BankPanel, "RefreshAllItemsForSelectedTab", onBankItems)
    end
end

function M:OnDisable()
    for _, d in pairs(deco) do d.arrow:Hide(); d.bg:Hide(); d.coin:Hide(); d.glow:Hide(); d.bind:SetText("") end
end
