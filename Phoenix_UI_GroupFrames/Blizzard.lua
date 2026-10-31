local _, ns = ...
local Theme, Skin, Media = ns.Theme, ns.Skin, ns.Media
local M = ns.modules.GroupFrames

--[[ Blizzard mode (the 2.0 behaviour): Phoenix textures, border, background and fonts on Blizzard's party / raid
    CompactUnitFrames. Nameplates share CompactUnitFrame code, so anything forbidden or nameplate-driven is skipped.
    Layout, sorting and sizes stay with Edit Mode; values are never read (health may be secret). ]]

local styled = setmetatable({}, { __mode = "k" })

local function isGroupFrame(frame)
    if frame:IsForbidden() then return false end
    local unit = frame.unit
    if not unit or ns.Secret.IsSecret(unit) then return false end
    return not unit:find("nameplate", 1, true)
end

---------------------------------------------------------------- style (shared with the options preview)
function M:BarTexture()
    return self.db.bar ~= "" and Media:Bar(self.db.bar) or Theme:Bar()
end

-- frame: the unit button; health/power: its bars; name/status: its FontStrings (Blizzard keeps placing them)
function M:StyleFrame(frame, health, power, name, status)
    local db = self.db
    if db.texture then
        local tex = self:BarTexture()
        if health then health:SetStatusBarTexture(tex) end
        if power then power:SetStatusBarTexture(tex) end
    end
    Skin:BorderSpec(frame, db.border, "border.black")
    Skin:Backdrop(frame, db.background, "bg.sunken")
    if db.fonts then
        if name then Skin:TextSpec(name, db.name, "unit") end
        if status then Skin:TextSpec(status, db.status, "number") end
    end
end

---------------------------------------------------------------- Blizzard frames
local function style(frame)
    if not (M:IsEnabled() and not M:IsPhoenix() and isGroupFrame(frame)) then return end
    styled[frame] = true
    M:StyleFrame(frame, frame.healthBar, frame.powerBar, frame.name, frame.statusText)
end

local hooked
function M:EnableBlizzard()
    if hooked then return end
    hooked = true
    hooksecurefunc("CompactUnitFrame_UpdateAll", style)
    hooksecurefunc("DefaultCompactUnitFrameSetup", style)
end

function M:RefreshBlizzard()
    for frame in pairs(styled) do style(frame) end
end
