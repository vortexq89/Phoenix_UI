local _, ns = ...
local Theme = ns.Theme

--[[ Item level badges on the character sheet and in bags. Text lives in a weak side table keyed by
    the Blizzard button, never as a field on it. ]]
local M = ns:NewModule("ItemLevel", {
    label = "ITEMLEVEL", desc = "ITEMLEVEL_DESC", category = "interface", order = 70,
    defaults = { enabled = true, character = true, bags = true, qualityColor = true, size = 12 },
})

local labels = setmetatable({}, { __mode = "k" })
local NO_ILVL_SLOTS = { [INVSLOT_BODY] = true, [INVSLOT_TABARD] = true }

local function label(button)
    local fs = labels[button]
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("TOPRIGHT", -1, -2)
        fs:SetJustifyH("RIGHT")
        labels[button] = fs
    end
    fs:SetFont(Theme:Font("number", M.db.size))
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    return fs
end

local function paint(button, location)
    if not (M:IsEnabled() and location and C_Item.DoesItemExist(location)) then
        if labels[button] then labels[button]:SetText("") end
        return
    end
    local level = C_Item.GetCurrentItemLevel(location)
    local fs = label(button)
    if not level or level <= 1 then fs:SetText(""); return end
    fs:SetText(level)
    local quality = C_Item.GetItemQuality(location)
    local color = M.db.qualityColor and quality and ITEM_QUALITY_COLORS[quality]
    if color then fs:SetTextColor(color.r, color.g, color.b) else fs:SetTextColor(Theme:Color("text.primary")) end
end

local function onSlotUpdate(button)
    if not M.db.character then return end
    local slot = button:GetID()
    if NO_ILVL_SLOTS[slot] or slot < INVSLOT_HEAD or slot > INVSLOT_LAST_EQUIPPED then return end
    paint(button, ItemLocation:CreateFromEquipmentSlot(slot))
end

local EQUIPPABLE_SKIP = { [""] = true, INVTYPE_BAG = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_QUIVER = true }
local function onBagUpdate(frame)
    if not M:IsEnabled() then return end
    for _, button in frame:EnumerateValidItems() do
        local location = ItemLocation:CreateFromBagAndSlot(button:GetBagID(), button:GetID())
        local show = false
        if M.db.bags and C_Item.DoesItemExist(location) then
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(C_Item.GetItemID(location))
            show = equipLoc ~= nil and not EQUIPPABLE_SKIP[equipLoc]
        end
        paint(button, show and location or nil)
    end
end

local hooked
function M:OnEnable()
    if hooked then return end
    hooked = true
    hooksecurefunc("PaperDollItemSlotButton_Update", onSlotUpdate)
    for i = 1, NUM_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame.UpdateItems then hooksecurefunc(frame, "UpdateItems", onBagUpdate) end
    end
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", onBagUpdate)
end

function M:OnDisable()
    for _, fs in pairs(labels) do fs:SetText("") end
end

function M:Refresh()
    for button, fs in pairs(labels) do
        fs:SetFont(Theme:Font("number", self.db.size))
        if button:IsVisible() and button.GetBagID == nil then onSlotUpdate(button) end
    end
end
