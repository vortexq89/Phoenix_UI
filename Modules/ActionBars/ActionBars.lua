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

-- Blizzard's UpdateUsable sets the usable/no-mana/unusable tint; we only override it while out of range.
-- Restoring repeats Blizzard's colours rather than calling the secure button's method from addon code.
local function tint(button)
    if outOfRange[button] and M.db.rangeTint then
        button.icon:SetVertexColor(RANGE[1], RANGE[2], RANGE[3])
        return
    end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(button.action)
    if isUsable then
        button.icon:SetVertexColor(1, 1, 1)
    elseif notEnoughMana then
        button.icon:SetVertexColor(0.5, 0.5, 1)
    else
        button.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function onUsable(button)
    if outOfRange[button] and M:IsEnabled() and M.db.rangeTint then
        button.icon:SetVertexColor(RANGE[1], RANGE[2], RANGE[3])
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

-- Fires on every range poll; only act when the state flips.
local function onRange(button, checksRange, inRange)
    if not buttons[button] or not M:IsEnabled() then return end
    local out = (checksRange and not inRange) or nil
    if out == outOfRange[button] then return end
    outOfRange[button] = out
    if button.action then tint(button) end
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
        hooksecurefunc(button, "UpdateUsable", onUsable)
    end
    hooksecurefunc("ActionButton_UpdateRangeIndicator", onRange)
end

function M:Refresh()
    for button in pairs(buttons) do
        style(button)
        if button.action then tint(button) end
    end
end

