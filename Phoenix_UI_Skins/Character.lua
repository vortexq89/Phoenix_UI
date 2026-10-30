local _, ns = ...
local Skin, W = ns.Skin, ns.Widgets
local M = ns:GetModule("Skins")

--[[ Character sheet, skins plan window 6 (the window itself uses the shared window skin, the stat column is
    styled by ItemLevel, item levels on slots come from ItemLevel too): the paper-doll slots become square
    1 px item slots on a sunken Phoenix tile, the border in the item's quality colour (empty slots in the
    subtle border), and the slot frame art of Blizzard faded. Game item icons are never changed; only their
    border. A post-hook of PaperDollItemSlotButton_Update repaints a slot when its item changes. Live both ways
    with Skins > Character, repainted on theme change. ]]

M.PAPERDOLL_SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
    "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand" }
local tiles = setmetatable({}, { __mode = "k" })

-- Border colour for a slot from the item quality (nil = empty or common: the theme's subtle border).
function M.SlotQualityColor(quality)
    if type(quality) ~= "number" or quality < 2 then return nil end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return c and { r = c.r, g = c.g, b = c.b } or nil
end

local function slotQuality(button, unit)
    local id = button.GetID and button:GetID()
    if not id then return nil end
    return GetInventoryItemQuality and GetInventoryItemQuality(unit or "player", id) or nil
end

-- key: the Skins switch that owns these slots ("character", or "inspect" for the inspect window); unit: whose gear.
function M.StyleSlot(button, key, unit)
    if type(button) ~= "table" or not button.GetObjectType then return end
    local on = M:IsEnabled() and M.db[key or "character"]
    local name = button.GetName and button:GetName()
    local art = name and _G[name .. "Frame"]
    local t = tiles[button]
    if not on then
        if t then
            t:Hide()
            if art then Skin:Restore(art) end
            Skin:Restore(button.IconBorder)
            if button.icon then Skin:HideIconFrame(button.icon) end
        end
        return
    end
    if not t then
        t = CreateFrame("Frame", nil, button)
        t:SetPoint("TOPLEFT", -1, 1); t:SetPoint("BOTTOMRIGHT", 1, -1)
        t:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
        t.bg = W.Texture(t, "BACKGROUND", 0)
        t.bg:SetAllPoints()
        tiles[button] = t
    end
    if art then Skin:HideRegion(art) end
    Skin:HideRegion(button.IconBorder)
    t:Show()
    W.Color(t.bg, "bg.sunken", 1)
    local color = M.SlotQualityColor(slotQuality(button, unit))
    local icon = button.icon or button.Icon
    if icon then
        Skin:IconFrame(button, icon, { style = "solid", size = 1, color = color }, 0.08, color and nil or "border.subtle")
    end
end

function M:SkinCharacterSlots()
    for _, slot in ipairs(self.PAPERDOLL_SLOTS) do M.StyleSlot(_G["Character" .. slot .. "Slot"]) end
end

local slotsHooked
function M:SetupCharacter()
    self:SkinCharacterSlots()
    if slotsHooked then return end
    slotsHooked = true
    if _G.PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button) M.StyleSlot(button) end)
    end
    ns.Events:Listen("PUI_THEME_CHANGED", M.PAPERDOLL_SLOTS, function() M:SkinCharacterSlots() end)
end
