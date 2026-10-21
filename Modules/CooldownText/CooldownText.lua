local _, ns = ...
local Skin = ns.Skin

--[[ CooldownText: Blizzard draws the countdown numbers (they handle secret durations natively);
    we switch them on through the CVar and give them the Phoenix font. ]]
local M = ns:NewModule("CooldownText", {
    label = "COOLDOWNTEXT", desc = "COOLDOWNTEXT_DESC", category = "combat", order = 10, icon = "cooldowntext",
    defaults = { size = 16, color = { r = 1, g = 0.82, b = 0.35 } },
})

local styled = setmetatable({}, { __mode = "k" })

local function style(cooldown)
    if not (cooldown and M:IsEnabled()) or cooldown:IsForbidden() then return end
    local fs = cooldown:GetCountdownFontString()
    if not fs then return end
    styled[cooldown] = fs
    Skin:Text(fs, "combat", nil, M.db.size, "OUTLINE")
    local c = M.db.color
    fs:SetTextColor(c.r, c.g, c.b)
end

local hooked
function M:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("ActionButton_ApplyCooldown", style)
    end
end

function M:OnDisable()
    for cooldown, fs in pairs(styled) do
        Skin:Restore(fs)
        styled[cooldown] = nil
    end
end

function M:Refresh()
    for cooldown in pairs(styled) do style(cooldown) end
end
