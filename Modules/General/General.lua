local _, ns = ...

--[[ General: the theme and typography shared by the config window and every skinned frame.
    Locked (always on). Its db.theme table *is* ns.Theme.settings.
    S16 adds the account-wide extras of Appearance & General: Blizzard's own fonts (font objects, never the
    STANDARD_TEXT_FONT global, which secure code reads) and the sound mute list. The floating damage font is
    the Combat Text page's, the chat font the Chat page's. ]]
-- false = the game's colour for that class
local CLASS_DEFAULTS = {}
for _, cf in ipairs(ns.Theme.CLASSES) do CLASS_DEFAULTS[cf] = false end

local M = ns:NewModule("General", {
    label = "GENERAL", desc = "GENERAL_DESC", category = "system", order = 1, icon = "general", locked = true,
    defaults = {
        theme = {
            preset = "ember", custom = { r = 1, g = 0.42, b = 0.1 }, fontScale = 1,
            uiFont = "", unitFont = "", barTexture = "Satin", reduceMotion = false,
            -- the style library defaults every module border set to "Follow Appearance" uses (Core/Style.lua)
            borderStyle = "solid", borderSize = 1, borderColor = false, shadowAlpha = 0.75, glowColor = false,
            surfaceAlpha = 1, outline = "NONE", soundChannel = "Master", classColors = CLASS_DEFAULTS,
        },
        blizzardFonts = false, mute = "",
    },
})

-- Blizzard font objects re-faced by "Replace Blizzard fonts" (size and flags kept). Chat is not here.
M.FONT_OBJECTS = {
    "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisableSmall", "GameFontNormalLarge", "GameFontHighlightLarge", "GameFontNormalMed3",
    "GameFontHighlightMedium", "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall",
    "SystemFont_Shadow_Small", "SystemFont_Shadow_Med1", "SystemFont_Shadow_Med2", "SystemFont_Shadow_Large",
    "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Small", "QuestFont", "NumberFontNormal",
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

function M:OnInitialize()
    ns.Theme:Apply(self.db.theme)
    if self.db.blizzardFonts then faceFonts(true) end
    applyMute(M.ParseMute(self.db.mute))
end

function M:Refresh()
    ns.Theme:Apply(self.db.theme)
    if self.db.blizzardFonts or next(originals) then faceFonts(self.db.blizzardFonts) end
    applyMute(M.ParseMute(self.db.mute))
end
