local _, ns = ...
local Theme, Skin, Secret = ns.Theme, ns.Skin, ns.Secret

--[[ NamePlates: cosmetic touches on Blizzard nameplates (bar texture, health percent text, Mythic+
    enemy forces). Forbidden plates are never requested. Health percent is secret in restricted
    content and is handed straight to FontString:SetFormattedText through a curve (display-only sink).
    The forces count (C_ScenarioInfo.GetUnitCriteriaProgressValues, 12.0.5) is secret while unit
    identity is restricted; it only flows through C_StringUtil.TruncateWhenZero / WrapString into
    FontString:SetText, so mobs that give nothing show nothing without the value being tested. ]]
local M = ns:NewModule("NamePlates", {
    label = "NAMEPLATES", desc = "NAMEPLATES_DESC", category = "interface", order = 55, reloadOnToggle = true,
    defaults = { texture = true, healthText = true, textSize = 10, forces = true },
})

local plates = {}                                    -- unit -> health bar
local texts = setmetatable({}, { __mode = "k" })     -- health bar -> our FontString
local forcesTexts = setmetatable({}, { __mode = "k" }) -- health bar -> forces FontString
local ScaleTo100 = CurveConstants.ScaleTo100

local function healthBarOf(plate)
    local uf = plate and plate.UnitFrame
    if not uf or uf:IsForbidden() then return nil end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
end

local function styleText(fs)
    Skin:Text(fs, "number", "text.primary", M.db.textSize, "OUTLINE")
end

local function textFor(bar)
    local fs = texts[bar]
    if not fs then
        fs = bar:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        styleText(fs)
        texts[bar] = fs
    end
    return fs
end

local function styleForces(fs)
    Skin:Text(fs, "number", "accent.secondary", M.db.textSize, "OUTLINE")
end

local function forcesFor(bar)
    local fs = forcesTexts[bar]
    if not fs then
        fs = bar:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("LEFT", bar, "RIGHT", 4, 0)
        styleForces(fs)
        forcesTexts[bar] = fs
    end
    return fs
end

-- "+4" for a mob worth 4 enemy forces, empty for mobs worth nothing or outside Mythic+.
local function updateForces(unit, bar)
    local fs = forcesFor(bar)
    fs:SetText("")
    if not (M.db.forces and C_ChallengeMode.IsChallengeModeActive()) then return end
    local count = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
    if Secret.IsSecret(count) or count then
        fs:SetText(C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(count), "+"))
    end
end

-- Hot path (UNIT_HEALTH): no styling, no allocation.
local function updateHealth(unit)
    local bar = plates[unit]
    if bar then texts[bar]:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, ScaleTo100)) end
end

local function apply(unit, bar)
    if M.db.texture then bar:SetStatusBarTexture(Theme:Bar()) end
    local fs = textFor(bar)
    fs:SetShown(M.db.healthText)
    if M.db.healthText then updateHealth(unit) end
    updateForces(unit, bar)
end

local function onAdded(_, _, unit)
    if Secret.IsSecret(unit) then return end
    local bar = healthBarOf(C_NamePlate.GetNamePlateForUnit(unit))
    if not bar then return end
    plates[unit] = bar
    apply(unit, bar)
end

local function onRemoved(_, _, unit)
    if Secret.IsSecret(unit) then return end
    local bar = plates[unit]
    if bar then
        texts[bar]:SetText("")
        if forcesTexts[bar] then forcesTexts[bar]:SetText("") end
    end
    plates[unit] = nil
end

local function onHealth(_, _, unit)
    if M.db.healthText and not Secret.IsSecret(unit) then updateHealth(unit) end
end

function M:OnEnable()
    ns.Events:On("NAME_PLATE_UNIT_ADDED", self, onAdded)
    ns.Events:On("NAME_PLATE_UNIT_REMOVED", self, onRemoved)
    ns.Events:On("UNIT_HEALTH", self, onHealth)
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:Refresh()
    for _, fs in pairs(texts) do
        styleText(fs)
        fs:Hide()
    end
    for _, fs in pairs(forcesTexts) do styleForces(fs) end
    for unit, bar in pairs(plates) do apply(unit, bar) end
end
