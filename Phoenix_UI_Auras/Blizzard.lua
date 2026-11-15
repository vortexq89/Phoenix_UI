local _, ns = ...
local Skin = ns.Skin

--[[ Auras, Blizzard mode (the 2.0 behaviour, kept as the fallback): cropped icons, crisp borders and themed timers
    on Blizzard's BuffFrame/DebuffFrame. Layout (size, rows, direction) stays in Edit Mode; aura data is never read
    here. Shares the look keys (iconZoom, border, duration, count) with Phoenix mode. ]]
local M = ns.modules.Auras

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
    if not (M:IsEnabled() and not M:IsPhoenix() and M.db.style) or not frame.auraFrames then return end
    for _, button in ipairs(frame.auraFrames) do styleButton(button) end
end

function M:EnableBlizzard()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        hooksecurefunc(frame, "UpdateAuraButtons", onUpdate)
        onUpdate(frame)
    end
end

function M:RefreshBlizzard()
    onUpdate(BuffFrame)
    onUpdate(DebuffFrame)
end
