local _, ns = ...
local L = ns.L
local Skin, Secret = ns.Skin, ns.Secret

--[[ Tooltip: Phoenix skin, cursor anchoring, class/quality borders and extra lines.
    All data comes from TooltipDataProcessor post-calls; anything secret is skipped, never compared. ]]
local M = ns:NewModule("Tooltip", {
    label = "TOOLTIP", desc = "TOOLTIP_DESC", category = "interface", order = 60, reloadOnToggle = true,
    defaults = {
        skin = true, anchor = "DEFAULT", hideInCombat = false, target = true, role = true, ids = false,
        classBorder = true, qualityBorder = true, healthBar = true,
    },
})

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }
local isOurs = {}
local skinned = setmetatable({}, { __mode = "k" })
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

local function border(tt, r, g, b)
    if not skinned[tt] then return end
    if r then Skin:SetBorderColor(tt, r, g, b, 1) else Skin:SetBorderColor(tt, "border.strong") end
end

local function skin(tt)
    if not M.db.skin or tt.IsEmbedded then return end
    Skin:HideRegion(tt.NineSlice)
    if not skinned[tt] then
        skinned[tt] = true
        Skin:Register(tt, function(self)
            Skin:Panel(self, "raised", { border = "border.strong", shadow = 8, sheen = 20 })
        end)
        tt:HookScript("OnTooltipCleared", function(self) border(self) end)
    end
end

local function onBackdrop(tt)
    if not (M:IsEnabled() and M.db.skin) then return end
    if isOurs[tt] then skin(tt) end
end

local function plain(...)
    for i = 1, select("#", ...) do
        if Secret.IsSecret((select(i, ...))) then return false end
    end
    return true
end

local function onUnit(tt, data)
    if not M:IsEnabled() or tt:IsForbidden() then return end
    local _, unit = tt:GetUnit()
    if not plain(unit) or not unit then return end
    if M.db.hideInCombat and InCombatLockdown() and not IsModifierKeyDown() and tt == GameTooltip then
        tt:Hide()
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) then return end
    if isPlayer and M.db.classBorder then
        local _, classFile = UnitClass(unit)
        if plain(classFile) then border(tt, ns.Util.ClassColor(classFile)) end
    end
    if M.db.role then
        local role = UnitGroupRolesAssigned(unit)
        if plain(role) and ROLE_ATLAS[role] then
            GameTooltip_AddNormalLine(tt, CreateAtlasMarkup(ROLE_ATLAS[role], 14, 14) .. " " .. _G[role])
        end
    end
    if M.db.target then
        local target = unit .. "target"
        local name = UnitExists(target) and UnitName(target)
        if plain(name) and name then
            local _, classFile = UnitClass(target)
            local color = (plain(classFile) and classFile) and C_ClassColor.GetClassColor(classFile)
            local text = color and color:WrapTextInColorCode(name) or name
            GameTooltip_AddNormalLine(tt, L.TOOLTIP_TARGET_LINE:format(text))
        end
    end
    if M.db.ids and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_ID:format(data.id), GRAY_FONT_COLOR)
    end
end

local function onItem(tt, data)
    if not M:IsEnabled() or tt:IsForbidden() then return end
    if M.db.qualityBorder then
        local _, link = tt:GetItem()
        local quality = plain(link) and link and C_Item.GetItemQualityByID(link)
        local color = quality and ITEM_QUALITY_COLORS[quality]
        if color and quality > 1 then border(tt, color.r, color.g, color.b) end
    end
    if M.db.ids and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_ID:format(data.id), GRAY_FONT_COLOR)
    end
end

local function onSpell(tt, data)
    if M:IsEnabled() and M.db.ids and not tt:IsForbidden() and data and plain(data.id) and data.id then
        GameTooltip_AddColoredLine(tt, L.TOOLTIP_SPELL_ID:format(data.id), GRAY_FONT_COLOR)
    end
end

local function onAnchor(tt, parent)
    if M:IsEnabled() and M.db.anchor == "CURSOR" and not tt:IsForbidden() then
        tt:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 16, 16)
    end
end

-- reloadOnToggle: OnEnable runs at most once per session, so the hooks are installed once.
function M:OnEnable()
    hooksecurefunc("SharedTooltip_SetBackdropStyle", onBackdrop)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", onAnchor)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, onSpell)
    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt then
            isOurs[tt] = true
            skin(tt)
        end
    end
    if self.db.healthBar and GameTooltip.StatusBar then
        GameTooltip.StatusBar:SetHeight(4)
        Skin:Register(GameTooltip.StatusBar, function(bar) Skin:StatusBar(bar, { border = true }) end)
    end
end
