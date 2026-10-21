local _, ns = ...
local Skin, Style = ns.Skin, ns.Style

--[[ ActionBars: cosmetic layer over Blizzard's secure action buttons. We only change textures,
    fonts, alpha and vertex colours (never attributes, anchors or scripts), so buttons stay secure.
    Positions, sizes and bar visibility remain Edit Mode's job. ]]
local M = ns:NewModule("ActionBars", {
    label = "ACTIONBARS", desc = "ACTIONBARS_DESC", category = "interface", order = 10, reloadOnToggle = true,
    defaults = {
        style = true, hotkeys = true, macroText = false, rangeTint = true,
        iconZoom = 0.08,
        border = Style.Border({ style = "shadow" }),
        rangeColor = false,                                -- false = the theme's danger colour
        hotkey = Style.Text(12, { outline = "OUTLINE", shadow = false, anchor = "TOPRIGHT", x = -1, y = -3 }),
        count = Style.Text(13, { outline = "OUTLINE", shadow = false, anchor = "BOTTOMRIGHT", x = -1, y = 3 }),
        macro = Style.Text(10, { outline = "OUTLINE", shadow = false, anchor = "BOTTOM", y = 3 }),
    },
})

local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7" }
local outOfRange = setmetatable({}, { __mode = "k" })
local buttons = {}
local RANGE_TOKEN = "state.danger"

---------------------------------------------------------------- style (shared with the options preview)
function M:RangeColor() return Skin:SpecColor(self.db.rangeColor, RANGE_TOKEN) end

-- frame: the button; icon, hotkey, count, name: its regions. place = false leaves Blizzard's anchors alone
-- (moving regions of a secure button is only done out of combat).
function M:StyleButton(frame, icon, hotkey, count, name, place)
    local db = self.db
    if db.style then
        Skin:IconZoom(icon, db.iconZoom)
        Skin:BorderSpec(frame, db.border, "border.black")
    end
    if hotkey then Skin:TextSpec(hotkey, db.hotkey, "number") end
    if count then Skin:TextSpec(count, db.count, "number") end
    if name then Skin:TextSpec(name, db.macro, "small") end
    if place then
        if hotkey then Skin:Place(hotkey, frame, db.hotkey) end
        if count then Skin:Place(count, frame, db.count) end
        if name then Skin:Place(name, frame, db.macro) end
    end
end

local function rangeTint(button)
    button.icon:SetVertexColor(M:RangeColor())
end

-- Blizzard's UpdateUsable sets the usable/no-mana/unusable tint; we only override it while out of range.
-- Restoring repeats Blizzard's own values (ActionBarActionButtonMixin:UpdateUsable) rather than calling
-- the secure button's method from addon code.
local function tint(button)
    if outOfRange[button] and M.db.rangeTint then
        rangeTint(button)
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
    if outOfRange[button] and M:IsEnabled() and M.db.rangeTint then rangeTint(button) end
end

local function style(button)
    local db = M.db
    if db.style then
        Skin:HideRegion(button.NormalTexture)
        Skin:HideRegion(button.SlotArt)
        if button.IconMask then button.icon:RemoveMaskTexture(button.IconMask) end
    end
    local place = not InCombatLockdown()
    if not place then M.placeAfterCombat = true end
    M:StyleButton(button, button.icon, button.HotKey, button.Count, button.Name, place)
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
    ns.Events:Listen("PUI_COMBAT_END", self, function()
        if self.placeAfterCombat then self.placeAfterCombat = nil; self:Refresh() end
    end)
end

function M:Refresh()
    for button in pairs(buttons) do
        style(button)
        if button.action then tint(button) end
    end
end

