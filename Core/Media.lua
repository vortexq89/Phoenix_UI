local _, ns = ...

--[[ ns.Media — fonts, textures and icons shipped with Phoenix_UI, registered with LibSharedMedia under
    "Phoenix …" so other addons can use them, and users can pick third-party media in our options.
    The bundled sets are generated: Core/FontData.lua (tools/media/gen_fonts.py, OFL / UFL fonts subset to
    Latin, Greek and Cyrillic) and Core/TextureData.lua (tools/media/gen_textures.py, original art). ]]
local LSM = LibStub("LibSharedMedia-3.0")
local M = {}
ns.Media = M

local F, T = ns.C.FONTS, ns.C.TEXTURES

-- Roboto and Roboto Condensed (Apache 2.0) predate the generated set and keep their names and keys.
local function core(key, name, file, family, weight)
    return { key = key, name = name, file = file, family = family, weight = weight }
end
M.fonts = {
    core("Roboto", "Phoenix Roboto", "Roboto-Regular.ttf", "Roboto", "Regular"),
    core("RobotoMedium", "Phoenix Roboto Medium", "Roboto-Medium.ttf", "Roboto", "Medium"),
    core("RobotoBold", "Phoenix Roboto Bold", "Roboto-Bold.ttf", "Roboto", "Bold"),
    core("Condensed", "Phoenix Condensed", "Roboto_Condensed-Regular.ttf", "Roboto Condensed", "Regular"),
    core("CondensedMedium", "Phoenix Condensed Medium", "Roboto_Condensed-Medium.ttf", "Roboto Condensed", "Medium"),
    core("CondensedSemiBold", "Phoenix Condensed SemiBold", "Roboto_Condensed-SemiBold.ttf", "Roboto Condensed", "SemiBold"),
    core("CondensedBold", "Phoenix Condensed Bold", "Roboto_Condensed-Bold.ttf", "Roboto Condensed", "Bold"),
}
for _, m in ipairs(M.fonts) do m.category, m.cyrillic = "core", true end
for _, m in ipairs(ns.FontData) do M.fonts[#M.fonts + 1] = m end

M.bars = ns.TextureData.bars

M.textures = {
    WHITE = "Interface\\Buttons\\WHITE8X8",
    SHADOW = T .. "Shadow",
    PILL = T .. "Pill",
    CIRCLE = T .. "Circle",
    ROUNDED = T .. "Rounded",
    FADE_V = T .. "FadeV",
}

-- Keys saved by earlier builds, kept working.
local ALIASES = { Inter = "InterBold", Cinzel = "CinzelBold" }

local byKey, glows = {}, {}
for _, m in ipairs(M.fonts) do m.path = F .. m.file; byKey[m.key] = m end
for _, m in ipairs(M.bars) do m.path = T .. m.file; byKey[m.key] = m end
for _, g in ipairs(ns.TextureData.glows) do glows[g.key] = T .. g.file end
for alias, key in pairs(ALIASES) do byKey[alias] = byKey[key] end

-- Locales whose glyphs our bundled Latin/Greek/Cyrillic fonts don't cover use the game font.
local CJK = { koKR = true, zhCN = true, zhTW = true }
M.needsFallbackFont = CJK[GetLocale()] == true
-- On Russian clients a font without Cyrillic would draw boxes: it is hidden from the pickers and replaced.
M.needsCyrillic = GetLocale() == "ruRU"

function M:Get(key) return byKey[key] end

-- key may be one of ours or any LibSharedMedia name. latinOnly: the text is always Latin (the "PHOENIX" brand).
function M:Font(key, latinOnly)
    if self.needsFallbackFont then return STANDARD_TEXT_FONT end
    local m = byKey[key]
    if m then
        if self.needsCyrillic and not m.cyrillic and not latinOnly then return byKey.Roboto.path end
        return m.path
    end
    return LSM:Fetch("font", key, true) or STANDARD_TEXT_FONT
end

function M:Bar(key)
    local m = byKey[key]
    if m then return m.path end
    return LSM:Fetch("statusbar", key, true) or self.textures.WHITE
end

-- Soft 9-slice glow source: "Soft" (the shadow), "Tight" or "Wide".
function M:Glow(key) return glows[key] or glows.Soft end

--[[ Lists for the font and texture pickers: our media first, then everything other addons registered.
    Items carry what the picker needs to draw a live sample: font = path, texture = path, group = heading. ]]
function M:List(kind)
    local out, seen = {}, {}
    if kind == "font" then
        for _, m in ipairs(self.fonts) do
            if not (self.needsCyrillic and not m.cyrillic) then
                out[#out + 1] = { value = m.key, label = m.name:gsub("^Phoenix ", ""), font = m.path, group = m.family }
            end
            seen[m.name] = true
        end
    else
        for _, m in ipairs(self.bars) do
            out[#out + 1] = { value = m.key, label = m.name:gsub("^Phoenix ", ""), texture = m.path, group = "Phoenix" }
            seen[m.name] = true
        end
    end
    local lsmKind = kind == "font" and "font" or "statusbar"
    for _, name in ipairs(LSM:List(lsmKind)) do
        if not seen[name] then
            local path = LSM:Fetch(lsmKind, name, true)
            out[#out + 1] = { value = name, label = name, font = kind == "font" and path or nil,
                texture = kind ~= "font" and path or nil, group = "LibSharedMedia" }
        end
    end
    return out
end

local WESTERN, RUSSIAN = LSM.LOCALE_BIT_western, LSM.LOCALE_BIT_ruRU
for _, m in ipairs(M.fonts) do LSM:Register("font", m.name, m.path, m.cyrillic and WESTERN + RUSSIAN or WESTERN) end
for _, m in ipairs(M.bars) do LSM:Register("statusbar", m.name, m.path) end
for _, b in ipairs(ns.TextureData.borders) do LSM:Register("border", b.name, T .. b.file) end
LSM:Register("background", "Phoenix Base", M.textures.WHITE)
