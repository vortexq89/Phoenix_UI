local _, ns = ...
local Theme, Skin = ns.Theme, ns.Skin

--[[ Bags: Phoenix look for Blizzard's bag windows (separate and combined) and their item buttons, plus an
    upgrade arrow on gear that beats what you wear. Item level numbers come from the ItemLevel module.
    When the Sim module has a recent result for an item, the sim decides: the arrow shows (in the accent
    colour) only when the sim found a DPS gain, and hides when it found a loss, whatever the item level says.

    Safety: bag windows and item buttons are dressed after Blizzard's own UpdateItems runs (post-hook only).
    Art is hidden with alpha, and every new region or frame is ours, kept in weak side tables keyed by the
    Blizzard button; no field is written on a Blizzard frame and nothing is re-anchored or resized, so
    using items from the bags stays untainted. Item levels are plain numbers (no secret values). ]]
local M = ns:NewModule("Bags", {
    label = "BAGS", desc = "BAGS_DESC", icon = "items", category = "interface", order = 72, reloadOnToggle = true,
    defaults = { enabled = true, skin = true, quality = true, upgrade = true, simArrow = true, countSize = 12 },
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
    deco[button] = d
    return d
end

local function styleButton(button, location)
    local db = M.db
    local d = decoFor(button)
    local exists = location and C_Item.DoesItemExist(location)
    local quality = exists and C_Item.GetItemQuality(location)
    if db.skin then
        Skin:HideRegion(button:GetNormalTexture())
        Skin:HideRegion(button.IconBorder)
        d.bg:SetVertexColor(Theme:Color("bg.sunken"))
        d.bg:Show()
        local spec = { style = "solid", size = 1 }
        local color = db.quality and type(quality) == "number" and quality >= QUALITY_MIN and ITEM_QUALITY_COLORS[quality]
        if color then spec.color = { r = color.r, g = color.g, b = color.b } end
        if button.icon then Skin:IconFrame(button, button.icon, spec, 0.08, "border.black") end
        if button.Count then Skin:Text(button.Count, "number", nil, db.countSize, "OUTLINE") end
    else
        d.bg:Hide()
    end
    local up, simmed = false, false
    if db.upgrade and exists then
        -- a sim result for this exact item decides (gain or not); otherwise item level does
        local Sim = db.simArrow and ns.modules.Sim
        local r = Sim and Sim.active and Sim:ItemResult(C_Item.GetItemLink(location))
        if r then
            up, simmed = r.pct > 0, true
        else
            local itemID = C_Item.GetItemID(location)
            local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
            if SLOTS[equipLoc] then
                local _, classFile = UnitClass("player")
                up = M:IsUpgrade(C_Item.GetCurrentItemLevel(location), equipLoc, classID, subclassID, itemID, classFile)
            end
        end
    end
    if up then ns.Icons:Tint(d.arrow, simmed and "accent.primary" or "state.success") end
    d.arrow:SetShown(up)
end
M.StyleButton = styleButton

local ART = { "Bg", "NineSlice" }
local function skinWindow(frame)
    if skinned[frame] or not M.db.skin then return end
    skinned[frame] = true
    for _, key in ipairs(ART) do Skin:HideRegion(frame[key]) end
    Skin:Register(frame, function(self)
        Skin:Panel(self, "base", { border = "border.strong", shadow = 12, sheen = 26 })
        local title = self.TitleContainer and self.TitleContainer.TitleText
        if title then Skin:Text(title, "heading", "accent.primary", 12) end
    end)
end

local function onUpdateItems(frame)
    if not M:IsEnabled() then return end
    skinWindow(frame)
    for _, button in frame:EnumerateValidItems() do
        styleButton(button, ItemLocation:CreateFromBagAndSlot(button:GetBagID(), button:GetID()))
    end
end

local function eachBag(fn)
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.UpdateItems then fn(frame) end
    end
    if ContainerFrameCombinedBags then fn(ContainerFrameCombinedBags) end
end

function M:Refresh()
    eachBag(function(frame) if frame:IsShown() then onUpdateItems(frame) end end)
end

local hooked
function M:OnEnable()
    readEquipped()
    ns.Events:On("PLAYER_EQUIPMENT_CHANGED", self, function() readEquipped(); M:Refresh() end)
    ns.Events:On("PLAYER_LEVEL_UP", self, function() M:Refresh() end)
    ns.Events:Listen("PUI_SIM_RESULTS", self, self.Refresh)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
    if hooked then self:Refresh(); return end
    hooked = true
    eachBag(function(frame) hooksecurefunc(frame, "UpdateItems", onUpdateItems) end)
end

function M:OnDisable()
    for _, d in pairs(deco) do d.arrow:Hide(); d.bg:Hide() end
end
