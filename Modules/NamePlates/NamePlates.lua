local _, ns = ...
local Theme, Skin, Secret = ns.Theme, ns.Skin, ns.Secret

--[[ NamePlates: cosmetic touches on Blizzard nameplates (bar texture, health percent text).
    Forbidden plates are never requested. Health percent is secret in restricted content and is
    handed straight to FontString:SetFormattedText through a curve (display-only sink). ]]
local M = ns:NewModule("NamePlates", {
    label = "NAMEPLATES", desc = "NAMEPLATES_DESC", category = "interface", order = 55, reloadOnToggle = true,
    defaults = { texture = true, healthText = true, textSize = 10 },
})

local plates = {}      -- unit -> healthBar
local texts = setmetatable({}, { __mode = "k" })

local function healthBarOf(plate)
    local uf = plate and plate.UnitFrame
    if not uf or uf:IsForbidden() then return nil end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
end

local function textFor(bar)
    local fs = texts[bar]
    if not fs then
        fs = bar:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
        texts[bar] = fs
    end
    Skin:Text(fs, "number", "text.primary", M.db.textSize, "OUTLINE")
    return fs
end

local function updateHealth(unit)
    local bar = plates[unit]
    if not bar or not M.db.healthText then return end
    local value = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    textFor(bar):SetFormattedText("%.0f%%", value)
end

local function onAdded(_, _, unit)
    if Secret.IsSecret(unit) then return end
    local bar = healthBarOf(C_NamePlate.GetNamePlateForUnit(unit))
    if not bar then return end
    plates[unit] = bar
    if M.db.texture then bar:SetStatusBarTexture(Theme:Bar()) end
    local fs = texts[bar]
    if fs then fs:SetShown(M.db.healthText) end
    if M.db.healthText then textFor(bar):Show(); updateHealth(unit) end
end

local function onRemoved(_, _, unit)
    if Secret.IsSecret(unit) then return end
    local bar = plates[unit]
    if bar and texts[bar] then texts[bar]:SetText("") end
    plates[unit] = nil
end

function M:OnEnable()
    ns.Events:On("NAME_PLATE_UNIT_ADDED", self, onAdded)
    ns.Events:On("NAME_PLATE_UNIT_REMOVED", self, onRemoved)
    ns.Events:On("UNIT_HEALTH", self, function(_, _, unit)
        if not Secret.IsSecret(unit) and plates[unit] then updateHealth(unit) end
    end)
end

function M:Refresh()
    for unit in pairs(plates) do onAdded(nil, nil, unit) end
    for bar, fs in pairs(texts) do
        local shown = false
        for _, b in pairs(plates) do if b == bar then shown = true end end
        fs:SetShown(shown and self.db.healthText)
    end
end
