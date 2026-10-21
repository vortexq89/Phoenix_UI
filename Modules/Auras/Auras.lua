local _, ns = ...
local Skin = ns.Skin

--[[ Auras: cropped icons, crisp borders and themed timers on Blizzard's BuffFrame/DebuffFrame.
    Layout (size, rows, direction) stays in Edit Mode; aura data is never read here. ]]
local M = ns:NewModule("Auras", {
    label = "AURAS", desc = "AURAS_DESC", category = "interface", order = 50, reloadOnToggle = true,
    defaults = { style = true, durationSize = 11, countSize = 12 },
})

local function styleButton(button)
    if button.isAuraAnchor or not button.Icon then return end
    local db = M.db
    if not Skin:IsSkinned(button.Icon) then
        Skin:Icon(button.Icon)
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button.Icon)
        Skin:Border(holder, "border.black")
        Skin:Shadow(holder, 4, nil, 0.5)
    end
    if button.Duration then Skin:Text(button.Duration, "number", nil, db.durationSize, "OUTLINE") end
    if button.Count then Skin:Text(button.Count, "number", nil, db.countSize, "OUTLINE") end
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
end

function M:Refresh()
    onUpdate(BuffFrame)
    onUpdate(DebuffFrame)
end
