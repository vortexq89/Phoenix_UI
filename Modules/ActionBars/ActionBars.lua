local _, ns = ...
local Skin = ns.Skin

--[[ ActionBars: cosmetic layer over Blizzard's secure action buttons. We only change textures,
    fonts, alpha and vertex colours (never attributes, anchors or scripts), so buttons stay secure.
    Positions, sizes and bar visibility remain Edit Mode's job. ]]
local M = ns:NewModule("ActionBars", {
    label = "ACTIONBARS", desc = "ACTIONBARS_DESC", category = "interface", order = 10, reloadOnToggle = true,
    defaults = { style = true, hotkeys = true, macroText = false, rangeTint = true, fontSize = 12 },
})

local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7" }
local outOfRange = setmetatable({}, { __mode = "k" })
local buttons = {}
local RANGE = { 0.95, 0.25, 0.25 }

local function usableColor(button)
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(button.action)
    if isUsable then return 1, 1, 1 elseif notEnoughMana then return 0.5, 0.5, 1 end
    return 0.4, 0.4, 0.4
end

local function tint(button)
    if not (M:IsEnabled() and M.db.rangeTint) or not button.action then return end
    if outOfRange[button] then
        button.icon:SetVertexColor(RANGE[1], RANGE[2], RANGE[3])
    else
        button.icon:SetVertexColor(usableColor(button))
    end
end

local function style(button)
    local db = M.db
    if db.style then
        Skin:HideRegion(button.NormalTexture)
        Skin:HideRegion(button.SlotArt)
        Skin:Icon(button.icon)
        if button.IconMask then button.icon:RemoveMaskTexture(button.IconMask) end
        Skin:Border(button, "border.black")
        Skin:Shadow(button, 4, nil, 0.5)
    end
    Skin:Text(button.HotKey, "number", nil, db.fontSize, "OUTLINE")
    Skin:Text(button.Count, "number", nil, db.fontSize + 1, "OUTLINE")
    Skin:Text(button.Name, "small", nil, db.fontSize - 2, "OUTLINE")
    button.HotKey:SetAlpha(db.hotkeys and 1 or 0)
    button.Name:SetAlpha(db.macroText and 1 or 0)
end

local function onRange(button, checksRange, inRange)
    if not buttons[button] then return end
    outOfRange[button] = (checksRange and not inRange) or nil
    tint(button)
end

local function collect()
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        if bar and bar.actionButtons then
            for _, button in pairs(bar.actionButtons) do buttons[button] = true end
        end
    end
end

function M:OnEnable()
    collect()
    for button in pairs(buttons) do
        Skin:Register(button, style)
        hooksecurefunc(button, "UpdateUsable", tint)
    end
    hooksecurefunc("ActionButton_UpdateRangeIndicator", onRange)
end

function M:Refresh()
    for button in pairs(buttons) do
        style(button)
        tint(button)
    end
end

