local _, ns = ...
local Theme, Skin, Secret, Media, Style = ns.Theme, ns.Skin, ns.Secret, ns.Media, ns.Style

--[[ UnitFrames: Phoenix bar textures, class-coloured health and themed text on Blizzard's
    Player/Target/Focus/Pet frames, with per-frame texture, border, background and text styles.
    Values are never read: health may be secret, colours are not. ]]
local UNITS = { "player", "target", "focus", "pet" }
local FRAME_OF = { player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame", pet = "PetFrame" }

local function unitDefaults(nameSize)
    return {
        texture = "",                                   -- "" = the theme's bar texture
        border = Style.Border({ style = "none" }),
        background = Style.Background({ alpha = 0 }),
        name = Style.Text(nameSize),
        health = Style.Text(nameSize - 1),
        power = Style.Text(nameSize - 2),
    }
end

local M = ns:NewModule("UnitFrames", {
    label = "UNITFRAMES", desc = "UNITFRAMES_DESC", category = "interface", order = 20, reloadOnToggle = true,
    defaults = {
        texture = true, classColor = true, powerColor = true, fonts = true,
        units = { player = unitDefaults(12), target = unitDefaults(12), focus = unitDefaults(12), pet = unitDefaults(11) },
    },
})
M.UNITS = UNITS

local healthBars, manaBars = {}, {}   -- bar -> unit key

local function plain(v) return not Secret.IsSecret(v) end

---------------------------------------------------------------- style (shared with the options preview)
function M:Unit(key) return self.db.units[key] or self.db.units.player end

function M:BarTexture(key)
    local u = self:Unit(key)
    return u.texture ~= "" and Media:Bar(u.texture) or Theme:Bar()
end

function M:StyleHealthBar(bar, key)
    if self.db.texture then bar:SetStatusBarTexture(self:BarTexture(key)) end
    local u = self:Unit(key)
    Skin:BorderSpec(bar, u.border, "border.black")
    Skin:Backdrop(bar, u.background, "bg.sunken")
end

function M:StylePowerBar(bar, key)
    if self.db.texture then bar:SetStatusBarTexture(self:BarTexture(key)) end
end

-- texts: { name = fs, health = { fs, … }, power = { fs, … } }; Blizzard keeps placing them.
function M:StyleTexts(texts, key)
    if not self.db.fonts then return end
    local u = self:Unit(key)
    if texts.name then Skin:TextSpec(texts.name, u.name, "unit") end
    for _, fs in ipairs(texts.health or {}) do Skin:TextSpec(fs, u.health, "unit") end
    for _, fs in ipairs(texts.power or {}) do Skin:TextSpec(fs, u.power, "unit") end
end

---------------------------------------------------------------- Blizzard frames
local function colorHealth(bar, unit)
    if not (M:IsEnabled() and M.db.classColor) or not healthBars[bar] then return end
    unit = unit or bar.unit
    if not plain(unit) or not unit then return end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) or not isPlayer then return end
    local _, classFile = UnitClass(unit)
    if plain(classFile) and classFile then bar:SetStatusBarColor(ns.Util.ClassColor(classFile)) end
end

local function onHealthUpdate(bar, unit)
    local key = healthBars[bar]
    if not key then return end
    M:StyleHealthBar(bar, key)
    colorHealth(bar, unit)
end

local function onManaType(bar)
    local key = M:IsEnabled() and manaBars[bar]
    if not key then return end
    M:StylePowerBar(bar, key)
    if M.db.powerColor and bar.unit and plain(bar.unit) then
        local _, token = UnitPowerType(bar.unit)
        local info = plain(token) and token and PowerBarColor[token]
        if info and info.r then bar:SetStatusBarColor(info.r, info.g, info.b) end
    end
end

local function textsOf(frame)
    local hb, mb = frame.healthbar, frame.manabar
    return {
        name = frame.name,
        health = hb and { hb.TextString, hb.LeftText, hb.RightText } or {},
        power = mb and { mb.TextString, mb.LeftText, mb.RightText } or {},
    }
end

function M:OnEnable()
    for _, key in ipairs(UNITS) do
        local frame = _G[FRAME_OF[key]]
        if frame then
            if frame.healthbar then healthBars[frame.healthbar] = key end
            if frame.manabar then manaBars[frame.manabar] = key end
            Skin:Register(frame, function(f) M:StyleTexts(textsOf(f), key) end)
        end
    end
    hooksecurefunc("UnitFrameHealthBar_Update", onHealthUpdate)
    hooksecurefunc("UnitFrameManaBar_UpdateType", onManaType)
    self:Refresh()
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:Refresh()
    for bar in pairs(healthBars) do onHealthUpdate(bar) end
    for bar in pairs(manaBars) do onManaType(bar) end
    for _, key in ipairs(UNITS) do
        local frame = _G[FRAME_OF[key]]
        if frame and healthBars[frame.healthbar] then self:StyleTexts(textsOf(frame), key) end
    end
end
