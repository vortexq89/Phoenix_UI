local _, ns = ...
local Skin, Style = ns.Skin, ns.Style

--[[ Auras: cropped icons, crisp borders and themed timers on Blizzard's BuffFrame/DebuffFrame.
    Layout (size, rows, direction) stays in Edit Mode; aura data is never read here. ]]
local M = ns:NewModule("Auras", {
    label = "AURAS", desc = "AURAS_DESC", category = "interface", order = 50, reloadOnToggle = true,
    defaults = {
        style = true,
        iconZoom = 0.08,
        border = Style.Border({ style = "shadow" }),
        duration = Style.Text(11, { outline = "OUTLINE", shadow = false }),
        count = Style.Text(12, { outline = "OUTLINE", shadow = false }),
    },
})

local holders = setmetatable({}, { __mode = "k" })  -- aura button -> our border frame

---------------------------------------------------------------- style (shared with the options preview)
-- holder: a frame covering the icon that carries the border; Blizzard keeps placing the texts.
function M:StyleAura(icon, holder, duration, count)
    local db = self.db
    Skin:IconZoom(icon, db.iconZoom)
    Skin:BorderSpec(holder, db.border, "border.black")
    if duration then Skin:TextSpec(duration, db.duration, "number") end
    if count then Skin:TextSpec(count, db.count, "number") end
end

local function styleButton(button)
    if button.isAuraAnchor or not button.Icon then return end
    local holder = holders[button]
    if not holder then
        holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button.Icon)
        holders[button] = holder
    end
    M:StyleAura(button.Icon, holder, button.Duration, button.Count)
end

local function onUpdate(frame)
    if not (M:IsEnabled() and M.db.style) or not frame.auraFrames then return end
    for _, button in ipairs(frame.auraFrames) do styleButton(button) end
end

function M:OnEnable()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        hooksecurefunc(frame, "UpdateAuraButtons", onUpdate)
        onUpdate(frame)
    end
    -- borders that follow Appearance & General restyle with it
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:Refresh()
    onUpdate(BuffFrame)
    onUpdate(DebuffFrame)
end
