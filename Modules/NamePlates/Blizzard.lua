local _, ns = ...
local Theme, Skin, Secret, Media = ns.Theme, ns.Skin, ns.Secret, ns.Media

--[[ NamePlates, Blizzard mode (the 2.0 behaviour): cosmetic touches on Blizzard nameplates (bar texture, health percent text, Mythic+
    enemy forces). Forbidden plates are never requested. Health percent is secret in restricted
    content and is handed straight to FontString:SetFormattedText through a curve (display-only sink).
    The forces count (C_ScenarioInfo.GetUnitCriteriaProgressValues, 12.0.5) is secret while unit
    identity is restricted; it only flows through C_StringUtil.TruncateWhenZero / WrapString into
    FontString:SetText, so mobs that give nothing show nothing without the value being tested.
    Target, focus and threat colours run after Blizzard's own health colour (CompactUnitFrame_UpdateHealthColor);
    target and focus are found by plate frame (M:IsPlateOf), threat only when UnitThreatSituation is plain.
    The plate cast bar gets the Phoenix texture and font after every UpdateBarFillTexture, and the aura rows
    (debuffs, buffs, crowd control) get icon zoom, a border and fonts after every RefreshList. ]]
local M = ns.modules.NamePlates
local owner = {} -- event owner of this mode (Phoenix mode listens as the module itself)
M.BlizzardOwner = owner

local plates = {}                                    -- unit -> health bar
local texts = setmetatable({}, { __mode = "k" })     -- health bar -> our FontString
local forcesTexts = setmetatable({}, { __mode = "k" }) -- health bar -> forces FontString
local nameOf = setmetatable({}, { __mode = "k" })      -- health bar -> Blizzard's name FontString
local ScaleTo100 = CurveConstants.ScaleTo100

local function healthBarOf(plate)
    local uf = plate and plate.UnitFrame
    if not uf or uf:IsForbidden() then return nil end
    return uf.healthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
end

---------------------------------------------------------------- style (shared with the options preview)
function M:StyleBar(bar)
    if self.db.texture then bar:SetStatusBarTexture(self:BarTexture()) end
    Skin:BorderSpec(bar, self.db.border, "border.black")
    Skin:Backdrop(bar, self.db.background, "bg.sunken")
end

function M:StyleHealthText(fs, bar)
    Skin:TextSpec(fs, self.db.health, "number", "text.primary")
    Skin:Place(fs, bar, self.db.health)
end

-- Blizzard's own name text: face, size, outline and shadow only (its colour and place stay Blizzard's).
function M:StyleName(fs)
    if self.db.name.styled then Skin:TextSpec(fs, self.db.name, "unit") end
end

local function styleText(fs) M:StyleHealthText(fs, fs:GetParent()) end

local function textFor(bar)
    local fs = texts[bar]
    if not fs then
        fs = bar:CreateFontString(nil, "OVERLAY")
        styleText(fs)
        texts[bar] = fs
    end
    return fs
end

local function styleForces(fs) M:StyleForces(fs) end

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
local function updateForces(unit, bar) M:ShowForces(forcesFor(bar), unit) end

-- Hot path (UNIT_HEALTH): no styling, no allocation.
local function updateHealth(unit)
    local bar = plates[unit]
    if bar then texts[bar]:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, ScaleTo100)) end
end

local function apply(unit, bar)
    M:StyleBar(bar)
    if nameOf[bar] then M:StyleName(nameOf[bar]) end
    local fs = textFor(bar)
    fs:SetShown(M.db.healthText)
    if M.db.healthText then updateHealth(unit) end
    updateForces(unit, bar)
end

---------------------------------------------------------------- colours: target, focus, threat
local blizzColor = setmetatable({}, { __mode = "k" }) -- health bar -> { r, g, b } Blizzard last set

local plain = M.plain

local function recolor(unit, bar)
    local r, g, b = M:PlateColor(unit)
    if r then
        bar:SetStatusBarColor(r, g, b)
    elseif blizzColor[bar] then
        local c = blizzColor[bar]
        bar:SetStatusBarColor(c[1], c[2], c[3])
    end
end

local function onHealthColor(frame)
    if not M:IsEnabled() or frame:IsForbidden() then return end
    local unit = frame.unit
    if not unit or not plain(unit) then return end
    local bar = plates[unit]
    if not bar or bar ~= frame.healthBar then return end
    local r, g, b = bar:GetStatusBarColor()
    if plain(r) and plain(g) and plain(b) then blizzColor[bar] = { r, g, b } end
    recolor(unit, bar)
end

local function recolorAll()
    for unit, bar in pairs(plates) do recolor(unit, bar) end
end

local function onThreat(_, _, unit)
    if unit and plain(unit) and plates[unit] then recolor(unit, plates[unit]) end
end

---------------------------------------------------------------- plate cast bar
local castBars = setmetatable({}, { __mode = "k" })

function M:CastTexture()
    local c = self.db.castbar
    return c.texture ~= "" and Media:Bar(c.texture) or Theme:Bar()
end

function M:StyleCastBar(bar, text)
    local c = self.db.castbar
    bar:SetStatusBarTexture(self:CastTexture())
    if type(c.color) == "table" then bar:SetStatusBarColor(Skin:SpecColor(c.color)) end
    if text then Skin:TextSpec(text, c.text, "body", "text.primary") end
end

local function castFill(bar)
    if M:IsEnabled() and M.db.castbar.style and castBars[bar] then M:StyleCastBar(bar, bar.Text) end
end

local function hookCastBar(plate)
    local uf = plate.UnitFrame
    local bar = uf and (uf.castBar or (uf.CastBarsContainer and uf.CastBarsContainer.castBar))
    if not bar or castBars[bar] or not bar.UpdateBarFillTexture then return end
    castBars[bar] = true
    hooksecurefunc(bar, "UpdateBarFillTexture", castFill)
    castFill(bar)
end

---------------------------------------------------------------- plate auras (debuff row, buffs, crowd control)
-- Blizzard fills the rows from secret aura data; we only dress the item frames after each RefreshList:
-- icon zoom, a border on our own child frame, and the stack and timer fonts. Sizes and layout stay Blizzard's.
local auraHosts = setmetatable({}, { __mode = "k" })
local styledAura = setmetatable({}, { __mode = "k" }) -- item frame -> generation it was styled for
local auraGen = 1

function M:StyleAuraIcon(item, icon, count, timer)
    local a = self.db.auras
    Skin:IconFrame(item, icon, a.border, a.zoom)
    if count then Skin:TextSpec(count, a.count, "number", "text.primary") end
    if timer then Skin:TextSpec(timer, a.timer, "number", "text.primary") end
end

local function styleAuraItem(item)
    if styledAura[item] == auraGen or item:IsForbidden() or not item.Icon then return end
    styledAura[item] = auraGen
    local cd = item.Cooldown
    local timer = cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
    M:StyleAuraIcon(item, item.Icon, item.CountFrame and item.CountFrame.Count, timer)
end

local function afterRefreshList(auras)
    if not (M:IsEnabled() and M.db.auras.style) or not auras.auraItemFramePool then return end
    for item in auras.auraItemFramePool:EnumerateActive() do ns.SafeCall(styleAuraItem, item) end
end

local function hookAuras(plate)
    local auras = plate.UnitFrame and plate.UnitFrame.AurasFrame
    if not auras or auraHosts[auras] or not auras.RefreshList then return end
    auraHosts[auras] = true
    hooksecurefunc(auras, "RefreshList", afterRefreshList)
    afterRefreshList(auras)
end

local function onAdded(_, _, unit)
    if Secret.IsSecret(unit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    local bar = healthBarOf(plate)
    if not bar then return end
    plates[unit] = bar
    nameOf[bar] = plate.UnitFrame.name
    apply(unit, bar)
    hookCastBar(plate)
    hookAuras(plate)
    recolor(unit, bar)
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

-- UNIT_HEALTH fires for every unit many times a second; listen only while the health text is on.
local function syncHealthEvent()
    if M.db.healthText then ns.Events:On("UNIT_HEALTH", owner, onHealth) else ns.Events:Off("UNIT_HEALTH", owner) end
end

function M:EnableBlizzard()
    if self.blizzardOn then return end
    self.blizzardOn = true
    ns.Events:On("NAME_PLATE_UNIT_ADDED", owner, onAdded)
    ns.Events:On("NAME_PLATE_UNIT_REMOVED", owner, onRemoved)
    syncHealthEvent()
    ns.Events:On("PLAYER_TARGET_CHANGED", owner, recolorAll)
    ns.Events:On("PLAYER_FOCUS_CHANGED", owner, recolorAll)
    ns.Events:On("UNIT_THREAT_SITUATION_UPDATE", owner, onThreat)
    ns.Events:On("UNIT_THREAT_LIST_UPDATE", owner, onThreat)
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", onHealthColor)
end

function M:RefreshBlizzard()
    if not self.blizzardOn then return end
    syncHealthEvent()
    for _, fs in pairs(texts) do
        styleText(fs)
        fs:Hide()
    end
    for _, fs in pairs(forcesTexts) do styleForces(fs) end
    for unit, bar in pairs(plates) do apply(unit, bar) end
    for bar in pairs(castBars) do castFill(bar) end
    auraGen = auraGen + 1
    for auras in pairs(auraHosts) do afterRefreshList(auras) end
    recolorAll()
end
