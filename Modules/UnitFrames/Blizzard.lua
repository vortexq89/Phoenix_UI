local _, ns = ...
local Theme, Skin, Secret, Media = ns.Theme, ns.Skin, ns.Secret, ns.Media

--[[ UnitFrames, Blizzard mode ("Frames owned by: Blizzard"): Phoenix bar textures, class-coloured health and themed text on Blizzard's
    Player/Target/Focus/Pet and Boss 1-5 frames, with per-frame texture, border, background and text styles,
    portraits (game, class icon or hidden), status icons (leader, raid marker, PvP), aura icon crop, border
    and stack font, and a range fade.
    Values are never read: health may be secret, colours are not. The range fade hands UnitInRange's
    (secret) answer straight to Region:SetAlphaFromBoolean. Arena enemies are CompactUnitFrames and take
    the Group Frames style. Test frames are plain (non-secure) Phoenix frames filled with sample data. ]]
local M = ns.modules.UnitFrames
local UNITS = { "player", "target", "focus", "pet", "boss" }
local FRAMES_OF = {
    player = { "PlayerFrame" }, target = { "TargetFrame" }, focus = { "FocusFrame" }, pet = { "PetFrame" },
    boss = { "Boss1TargetFrame", "Boss2TargetFrame", "Boss3TargetFrame", "Boss4TargetFrame", "Boss5TargetFrame" },
}
M.FRAMES_OF = FRAMES_OF

local healthBars, manaBars = {}, {}   -- bar -> unit key

local function plain(v) return not Secret.IsSecret(v) end

---------------------------------------------------------------- style (shared with the options preview)
local function barTexture(key)
    local u = M:Unit(key)
    return u.texture ~= "" and Media:Bar(u.texture) or Theme:Bar()
end

function M:StyleHealthBar(bar, key)
    if self.db.texture then bar:SetStatusBarTexture(barTexture(key)) end
    local u = self:Unit(key)
    Skin:BorderSpec(bar, u.border, "border.black")
    Skin:Backdrop(bar, u.background, "bg.sunken")
end

function M:StylePowerBar(bar, key)
    if self.db.texture then bar:SetStatusBarTexture(barTexture(key)) end
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
        local r, g, b
        if plain(token) then r, g, b = ns.Util.PowerColor(token) end
        if r then bar:SetStatusBarColor(r, g, b) end
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

---------------------------------------------------------------- portraits and status icons
local keyOfFrame = {} -- unit frame -> unit key

local function contextual(frame)
    local content = frame.PlayerFrameContent or frame.TargetFrameContent
    return content and (content.PlayerFrameContentContextual or content.TargetFrameContentContextual)
end

local function applyIcons(frame, key)
    local ctx = contextual(frame)
    if not ctx then return end
    local icons = M:Unit(key).icons
    local on = M:IsEnabled()
    local function set(region, show) if region then region:SetAlpha((not on or show) and 1 or 0) end end
    set(ctx.LeaderIcon, icons.leader); set(ctx.GuideIcon, icons.leader)
    set(ctx.RaidTargetIcon, icons.marker)
    set(ctx.PvpIcon, icons.pvp); set(ctx.PrestigePortrait, icons.pvp); set(ctx.PrestigeBadge, icons.pvp)
end

-- After Blizzard draws the portrait: class icon for players, or hidden.
local function onPortrait(frame)
    local key = keyOfFrame[frame]
    local tex = key and frame.portrait
    if not tex or not M:IsEnabled() then return end
    local mode = M:Unit(key).portrait
    tex:SetAlpha(mode == "hide" and 0 or 1)
    if mode ~= "class" then return end
    local unit = frame.unit
    if not unit or not plain(unit) then return end
    local isPlayer = UnitIsPlayer(unit)
    if not plain(isPlayer) or not isPlayer then return end
    local _, classFile = UnitClass(unit)
    local atlas = plain(classFile) and classFile and GetClassAtlas(classFile)
    if atlas then tex:SetAtlas(atlas) end
end

---------------------------------------------------------------- aura rows (target, focus, boss)
-- Blizzard's aura container lays out its buttons from secret aura data; after each ApplyLayout we only
-- dress the buttons it holds: icon crop, an optional border on a child frame of ours, the stack font.
local auraHosts = setmetatable({}, { __mode = "k" })
local styledAura = setmetatable({}, { __mode = "k" })
local auraGen = 1

function M:StyleAuraIcon(button, icon, count)
    local a = self.db.auras
    Skin:IconFrame(button, icon, a.border, a.zoom)
    if count then Skin:TextSpec(count, a.count, "number", "text.primary") end
end

local function afterAuraLayout(container)
    if not (M:IsEnabled() and M.db.auras.style) or not container.auraPools then return end
    for button in container.auraPools:EnumerateActive() do
        if styledAura[button] ~= auraGen and button.Icon and not button:IsForbidden() then
            styledAura[button] = auraGen
            ns.SafeCall(M.StyleAuraIcon, M, button, button.Icon, button.Count)
        end
    end
end

local function hookAuras(frame)
    local content = frame.TargetFrameContent
    local container = content and content.TargetFrameContentContextual and content.TargetFrameContentContextual.Auras
    if not container or auraHosts[container] or not container.ApplyLayout then return end
    auraHosts[container] = true
    hooksecurefunc(container, "ApplyLayout", afterAuraLayout)
end

---------------------------------------------------------------- range fade (friendly group members only)
local RANGED = { target = true, focus = true, pet = true }
local rangeDriver
local function rangeTick()
    for frame, key in pairs(keyOfFrame) do
        if RANGED[key] and frame:IsShown() then
            local unit = frame.unit
            local grouped = false
            if unit and plain(unit) then
                local party, raid = UnitInParty(unit), UnitInRaid(unit)
                grouped = (plain(party) and party) or (plain(raid) and raid ~= nil)
            end
            if grouped then
                frame:SetAlphaFromBoolean(UnitInRange(unit), 1, M.db.range.alpha)
            else
                frame:SetAlpha(1)
            end
        end
    end
end

function M:UpdateBlizzardRange()
    local on = self:IsEnabled() and self.db.range.enabled
    if on and not rangeDriver then
        rangeDriver = CreateFrame("Frame")
        local acc = 0
        rangeDriver:SetScript("OnUpdate", function(_, elapsed)
            acc = acc + elapsed
            if acc >= 0.2 then acc = 0; rangeTick() end
        end)
    end
    if rangeDriver then rangeDriver:SetShown(on) end
    if not on then
        for frame, key in pairs(keyOfFrame) do if RANGED[key] then frame:SetAlpha(1) end end
    end
end

local function eachFrame(fn)
    for _, key in ipairs(UNITS) do
        for _, name in ipairs(FRAMES_OF[key]) do
            local frame = _G[name]
            if frame then fn(frame, key) end
        end
    end
end

function M:EnableBlizzard()
    eachFrame(function(frame, key)
        keyOfFrame[frame] = key
        if frame.healthbar then healthBars[frame.healthbar] = key end
        if frame.manabar then manaBars[frame.manabar] = key end
        Skin:Register(frame, function(f) M:StyleTexts(textsOf(f), key) end)
        hookAuras(frame)
    end)
    hooksecurefunc("UnitFrameHealthBar_Update", onHealthUpdate)
    hooksecurefunc("UnitFrameManaBar_UpdateType", onManaType)
    hooksecurefunc("UnitFramePortrait_Update", onPortrait)
    self:RefreshBlizzard()
    ns.Events:Listen("PUI_THEME_CHANGED", self, self.Refresh)
end

function M:DisableBlizzard()
    self:UpdateBlizzardRange()
    eachFrame(applyIcons)
end

function M:RefreshBlizzard()
    for bar in pairs(healthBars) do onHealthUpdate(bar) end
    for bar in pairs(manaBars) do onManaType(bar) end
    eachFrame(function(frame, key)
        if healthBars[frame.healthbar] then self:StyleTexts(textsOf(frame), key) end
        applyIcons(frame, key)
        if frame.portrait and frame.unit and frame:IsShown() then
            if self:Unit(key).portrait ~= "class" then UnitFramePortrait_Update(frame) end
            onPortrait(frame)
        end
    end)
    self:UpdateBlizzardRange()
    auraGen = auraGen + 1
    for container in pairs(auraHosts) do afterAuraLayout(container) end
end

---------------------------------------------------------------- test frames
-- Plain Phoenix frames (Build.lua, no secure template) filled with sample data at the real frames' places.
local tests = {}
local TEST_UNITS = { { "target", "TargetFrame" }, { "focus", "FocusFrame" }, { "boss", "Boss1TargetFrame", 1 },
    { "boss", "Boss2TargetFrame", 2 }, { "boss", "Boss3TargetFrame", 3 } }

local function testFrame(i, key)
    local t = tests[i]
    if t then return t end
    t = M:Build(UIParent, key, { sample = {} })
    t:SetFrameStrata("HIGH")
    t:EnableMouse(false)
    t.tag = t.TextLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.tag:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", -2, 2)
    tests[i] = t
    return t
end

function M:ShowBlizzardTest(show)
    for i, spec in ipairs(TEST_UNITS) do
        local key, name, index = spec[1], spec[2], spec[3]
        local t = show and testFrame(i, key) or tests[i]
        if t then
            if show then
                local real = _G[name]
                t:ClearAllPoints()
                local x, y
                if real then x, y = real:GetCenter() end
                if x and y then
                    local k = real:GetEffectiveScale() / t:GetEffectiveScale()
                    t:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, y * k)
                else
                    t:SetPoint("RIGHT", UIParent, "RIGHT", -120, 160 - (index or 0) * 90)
                end
                t.sample = M.SampleData(key, index)
                if key == "focus" and self.db.range.enabled then t.sample.far = true end
                self:Layout(t)
                self:UpdateAll(t)
                Skin:Text(t.tag, "small", "accent.primary")
                t.tag:SetText(ns.L.UF_TEST_TAG:format(index and (ns.L.UF_BOSS .. " " .. index) or ns.L["UF_" .. key:upper()]))
                t:Show()
            else
                t:Hide()
            end
        end
    end
    return true
end
