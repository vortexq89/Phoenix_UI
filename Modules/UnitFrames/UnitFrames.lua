local _, ns = ...
local Theme, Skin, Secret = ns.Theme, ns.Skin, ns.Secret

--[[ UnitFrames: Phoenix bar textures, class-coloured health and themed text on Blizzard's
    Player/Target/Focus/Pet frames. Values are never read: health may be secret, colours are not. ]]
local M = ns:NewModule("UnitFrames", {
    label = "UNITFRAMES", desc = "UNITFRAMES_DESC", category = "interface", order = 20, reloadOnToggle = true,
    defaults = { texture = true, classColor = true, powerColor = true, fonts = true },
})

local FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
local healthBars, manaBars = {}, {}

local function plain(v) return not Secret.IsSecret(v) end

local function colorHealth(bar, unit)
    if not (M:IsEnabled() and M.db.classColor) or not healthBars[bar] then return end
    unit = unit or bar.unit
    if not unit or not plain(unit) then return end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) or not isPlayer then return end
    local _, classFile = UnitClass(unit)
    if plain(classFile) and classFile then bar:SetStatusBarColor(ns.Util.ClassColor(classFile)) end
end

local function onHealthUpdate(bar, unit)
    if not healthBars[bar] then return end
    if M.db.texture then bar:SetStatusBarTexture(Theme:Bar()) end
    colorHealth(bar, unit)
end

local function onManaType(bar)
    if not (M:IsEnabled() and manaBars[bar]) then return end
    if M.db.texture then bar:SetStatusBarTexture(Theme:Bar()) end
    if M.db.powerColor and bar.unit and plain(bar.unit) then
        local _, token = UnitPowerType(bar.unit)
        local info = plain(token) and token and PowerBarColor[token]
        if info and info.r then bar:SetStatusBarColor(info.r, info.g, info.b) end
    end
end

local function texts(frame)
    if not M.db.fonts then return end
    local function set(fs, size) if fs then Skin:Text(fs, "unit", nil, size) end end
    set(frame.name, 12)
    local hb, mb = frame.healthbar, frame.manabar
    if hb then set(hb.TextString, 11); set(hb.LeftText, 11); set(hb.RightText, 11) end
    if mb then set(mb.TextString, 10); set(mb.LeftText, 10); set(mb.RightText, 10) end
end

function M:OnEnable()
    for _, name in ipairs(FRAMES) do
        local frame = _G[name]
        if frame then
            if frame.healthbar then healthBars[frame.healthbar] = true end
            if frame.manabar then manaBars[frame.manabar] = true end
            Skin:Register(frame, texts)
        end
    end
    hooksecurefunc("UnitFrameHealthBar_Update", onHealthUpdate)
    hooksecurefunc("UnitFrameManaBar_UpdateType", onManaType)
    for bar in pairs(healthBars) do onHealthUpdate(bar) end
    for bar in pairs(manaBars) do onManaType(bar) end
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:Refresh()
    for bar in pairs(healthBars) do onHealthUpdate(bar) end
    for bar in pairs(manaBars) do onManaType(bar) end
end
