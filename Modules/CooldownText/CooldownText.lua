local _, ns = ...
local Skin = ns.Skin

--[[ CooldownText: Blizzard draws the countdown numbers (they handle secret durations natively);
    we switch them on through the CVar and give them the Phoenix font. ]]
local M = ns:NewModule("CooldownText", {
    label = "COOLDOWNTEXT", desc = "COOLDOWNTEXT_DESC", category = "combat", order = 10,
    defaults = { size = 16, color = { r = 1, g = 0.82, b = 0.35 } },
})

local styled = setmetatable({}, { __mode = "k" }) -- cooldown -> countdown FontString

local function paint(fs)
    local c = M.db.color
    Skin:Text(fs, "combat", nil, M.db.size, "OUTLINE")
    fs:SetTextColor(c.r, c.g, c.b)
end

-- ActionButton_ApplyCooldown runs on every cooldown update of every button; only the first call per
-- cooldown frame does any work.
local function onApply(cooldown)
    if not cooldown or styled[cooldown] or not M:IsEnabled() or cooldown:IsForbidden() then return end
    local fs = cooldown:GetCountdownFontString()
    if not fs then return end
    styled[cooldown] = fs
    paint(fs)
end

local hooked
function M:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("ActionButton_ApplyCooldown", onApply)
    end
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:OnDisable()
    for cooldown, fs in pairs(styled) do
        Skin:Restore(fs)
        styled[cooldown] = nil
    end
end

function M:Refresh()
    for _, fs in pairs(styled) do paint(fs) end
end
