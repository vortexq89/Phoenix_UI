local _, ns = ...
local Theme, Skin = ns.Theme, ns.Skin

--[[ GroupFrames: Phoenix textures and fonts on Blizzard's party/raid CompactUnitFrames.
    Nameplates share CompactUnitFrame code, so anything forbidden or nameplate-driven is skipped. ]]
local M = ns:NewModule("GroupFrames", {
    label = "GROUPFRAMES", desc = "GROUPFRAMES_DESC", category = "interface", order = 30, reloadOnToggle = true,
    defaults = { texture = true, fonts = true, nameSize = 11 },
})

local styled = setmetatable({}, { __mode = "k" })

local function isGroupFrame(frame)
    if frame:IsForbidden() then return false end
    local unit = frame.unit
    if not unit or ns.Secret.IsSecret(unit) then return false end
    return not unit:find("nameplate", 1, true)
end

local function style(frame)
    if not (M:IsEnabled() and isGroupFrame(frame)) then return end
    local db = M.db
    if db.texture then
        local tex = Theme:Bar()
        if frame.healthBar then frame.healthBar:SetStatusBarTexture(tex) end
        if frame.powerBar then frame.powerBar:SetStatusBarTexture(tex) end
    end
    if db.fonts then
        if frame.name then Skin:Text(frame.name, "unit", nil, db.nameSize) end
        if frame.statusText then Skin:Text(frame.statusText, "number", nil, db.nameSize - 1) end
    end
    if not styled[frame] then
        styled[frame] = true
        Skin:Border(frame, "border.black")
    end
end

function M:OnEnable()
    hooksecurefunc("CompactUnitFrame_UpdateAll", style)
    hooksecurefunc("DefaultCompactUnitFrameSetup", style)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:Refresh()
    for frame in pairs(styled) do style(frame) end
end
