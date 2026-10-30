local _, ns = ...

--[[ General: the theme and typography shared by the config window and every skinned frame.
    Locked (always on). Its db.theme table *is* ns.Theme.settings.
    S16 adds the account-wide extras of Appearance & General: Blizzard's own fonts (font objects, never the
    STANDARD_TEXT_FONT global, which secure code reads) and the sound mute list. The floating damage font is
    the Combat Text page's, the chat font the Chat page's. S17 adds power and dispel colour overrides. ]]
-- false = the game's colour for that class
local CLASS_DEFAULTS = {}
for _, cf in ipairs(ns.Theme.CLASSES) do CLASS_DEFAULTS[cf] = false end
-- false = the game's colour for that power type / dispel type (S17)
local POWER_DEFAULTS, DISPEL_DEFAULTS = {}, {}
for _, p in ipairs(ns.Theme.POWERS) do POWER_DEFAULTS[p] = false end
-- t146: Blizzard's mana is pure blue (0, 0, 1), the harshest bar on screen; Phoenix's default is a softer azure
-- (any power colour can still be picked, and Reset comes back here)
POWER_DEFAULTS.MANA = { r = 0.16, g = 0.50, b = 0.98 }
for _, d in ipairs(ns.Theme.DISPELS) do DISPEL_DEFAULTS[d] = false end

local M = ns:NewModule("General", {
    label = "GENERAL", desc = "GENERAL_DESC", category = "system", order = 1, icon = "general", locked = true,
    defaults = {
        theme = {
            preset = "ember", custom = { r = 1, g = 0.42, b = 0.1 }, fontScale = 1,
            uiFont = "", unitFont = "", expressway = true, barTexture = "Satin", reduceMotion = false, emblemFX = true,
            -- the style library defaults every module border set to "Follow Appearance" uses (Core/Style.lua)
            borderStyle = "solid", borderSize = 1, borderColor = false, shadowAlpha = 0.75, glowColor = false,
            surfaceAlpha = 1, outline = "NONE", soundChannel = "Master", classColors = CLASS_DEFAULTS,
            powerColors = POWER_DEFAULTS, dispelColors = DISPEL_DEFAULTS,
        },
        blizzardFonts = true, mute = "",
        -- Phoenix's UI scale (UIParent), below the game's 64 % floor too. Off: the game's own setting rules.
        scale = { enabled = false, auto = true, value = 0.71 },
    },
})

-- Blizzard font objects re-faced by "Replace Blizzard fonts" (size and flags kept). Chat is not here.
M.FONT_OBJECTS = {
    "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisableSmall", "GameFontNormalLarge", "GameFontHighlightLarge", "GameFontNormalMed3",
    "GameFontHighlightMedium", "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall",
    "SystemFont_Shadow_Small", "SystemFont_Shadow_Med1", "SystemFont_Shadow_Med2", "SystemFont_Shadow_Large",
    "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Small", "QuestFont", "NumberFontNormal",
    -- the faces the skinned windows use (Collections, Achievements, Group Finder, Character, Game Menu)
    "GameFontNormalLeft", "GameFontHighlightLeft", "GameFontHighlightSmallLeft", "GameFontNormalSmall2",
    "GameFontHighlightSmall2", "GameFontNormalHuge", "GameFontNormalMed1", "GameFontNormalMed2", "GameFontHighlightMed2",
    "GameFontNormalLarge2", "GameFontDisableLarge", "SystemFont_Large", "SystemFont_Huge1", "SystemFont_Shadow_Med3",
    "QuestFont_Large", "QuestFont_Huge", "Game12Font", "Game13Font", "Game15Font", "Game18Font", "Game20Font",
}

local originals = {}

local function faceFonts(on)
    local path = on and ns.Theme:Font("body")
    for _, name in ipairs(M.FONT_OBJECTS) do
        local obj = _G[name]
        if type(obj) == "table" and obj.GetFont then
            local p, size, flags = obj:GetFont()
            if not originals[name] and p then originals[name] = p end
            if on and size then obj:SetFont(path, size, flags or "")
            elseif originals[name] and size then obj:SetFont(originals[name], size, flags or "") end
        end
    end
    -- world names are drawn by the client from this global (read by C only, at login: "needs relog")
    if on and ns.Theme.settings.unitFont ~= "" then UNIT_NAME_FONT = ns.Media:Font(ns.Theme.settings.unitFont) end -- luacheck: ignore 121
end

-- "123, 456 789": sound file IDs from the mute list.
function M.ParseMute(text)
    local out, seen = {}, {}
    for id in tostring(text or ""):gmatch("%d+") do
        local n = tonumber(id)
        if n and n > 0 and not seen[n] then seen[n] = true; out[#out + 1] = n end
    end
    return out
end

local muted = {}
local function applyMute(list)
    local want = {}
    for _, id in ipairs(list) do want[id] = true end
    for id in pairs(muted) do
        if not want[id] then UnmuteSoundFile(id); muted[id] = nil end
    end
    for id in pairs(want) do
        if not muted[id] then MuteSoundFile(id); muted[id] = true end
    end
end

---------------------------------------------------------------- UI scale
M.SCALE_MIN, M.SCALE_MAX = 0.4, 1.15
local gameScale -- UIParent's scale before Phoenix first changed it (restored when the setting is turned off)

-- 768 / physical screen height: one UI unit per screen pixel.
function M.PixelPerfectScale()
    local _, h = GetPhysicalScreenSize()
    h = tonumber(h)
    if not h or h <= 0 then return nil end
    return 768 / h
end

-- The scale Phoenix wants, or nil when the game's own setting applies.
function M:WantedScale()
    local s = self.db.scale
    if not s.enabled then return nil end
    local v = s.auto and M.PixelPerfectScale() or tonumber(s.value)
    if not v then return nil end
    return math.max(M.SCALE_MIN, math.min(M.SCALE_MAX, v))
end

-- UIParent is the parent of protected frames: scaled out of combat only (deferred until combat ends).
local function applyScale()
    local v = M:WantedScale()
    if v then
        gameScale = gameScale or UIParent:GetScale()
        if math.abs(UIParent:GetScale() - v) > 0.0005 then UIParent:SetScale(v) end
    elseif gameScale then
        UIParent:SetScale(gameScale)
        gameScale = nil
    end
end
function M:ApplyScale() ns.Combat:Run("general.scale", applyScale) end

function M:OnInitialize()
    ns.Theme:Apply(self.db.theme)
    if self.db.blizzardFonts then faceFonts(true) end
    applyMute(M.ParseMute(self.db.mute))
    -- the client resets UIParent's scale on these; Phoenix's setting is put back each time
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        ns.Events:On(ev, self, function() if self.db.scale.enabled then self:ApplyScale() end end)
    end
end

function M:Refresh()
    self:ApplyScale()
    ns.Theme:Apply(self.db.theme)
    if self.db.blizzardFonts or next(originals) then faceFonts(self.db.blizzardFonts) end
    applyMute(M.ParseMute(self.db.mute))
end
