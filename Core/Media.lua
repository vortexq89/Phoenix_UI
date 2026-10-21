local _, ns = ...

--[[ ns.Media — fonts, textures and icons shipped with Phoenix_UI, registered with LibSharedMedia so
    other addons can use them and users can pick third-party media in our config. ]]
local LSM = LibStub("LibSharedMedia-3.0")
local M = {}
ns.Media = M

local F, T = ns.C.FONTS, ns.C.TEXTURES

M.fonts = {
    { key = "Roboto",            name = "Phoenix Roboto",           file = F .. "Roboto-Regular.ttf" },
    { key = "RobotoMedium",      name = "Phoenix Roboto Medium",    file = F .. "Roboto-Medium.ttf" },
    { key = "RobotoBold",        name = "Phoenix Roboto Bold",      file = F .. "Roboto-Bold.ttf" },
    { key = "Condensed",         name = "Phoenix Condensed",        file = F .. "Roboto_Condensed-Regular.ttf" },
    { key = "CondensedMedium",   name = "Phoenix Condensed Medium", file = F .. "Roboto_Condensed-Medium.ttf" },
    { key = "CondensedSemiBold", name = "Phoenix Condensed SemiBold", file = F .. "Roboto_Condensed-SemiBold.ttf" },
    { key = "CondensedBold",     name = "Phoenix Condensed Bold",   file = F .. "Roboto_Condensed-Bold.ttf" },
    { key = "Inter",             name = "Phoenix Inter Bold",       file = F .. "InterBold.ttf" },
    { key = "Cinzel",            name = "Phoenix Cinzel",           file = F .. "Cinzel-Bold.ttf" },
}

M.bars = {
    { key = "Satin", name = "Phoenix Satin", file = T .. "BarSatin" },
    { key = "Ember", name = "Phoenix Ember", file = T .. "BarEmber" },
    { key = "Flat",  name = "Phoenix Flat",  file = T .. "BarFlat" },
}

M.textures = {
    WHITE = "Interface\\Buttons\\WHITE8X8",
    SHADOW = T .. "Shadow",
    SPARK = T .. "Spark",
    PILL = T .. "Pill",
    CIRCLE = T .. "Circle",
    ROUNDED = T .. "Rounded",
    ROUNDED_BORDER = T .. "RoundedBorder",
    FADE_V = T .. "FadeV",
    FADE_H = T .. "FadeH",
    LOGO = T .. "Logo",
    EMBLEM = T .. "Emblem",
}

local byKey = {}
for _, list in ipairs({ M.fonts, M.bars }) do
    for _, m in ipairs(list) do byKey[m.key] = m end
end

-- Locales whose glyphs our bundled Latin/Cyrillic fonts don't cover.
local CJK = { koKR = true, zhCN = true, zhTW = true }
M.needsFallbackFont = CJK[GetLocale()] == true

function M:Icon(name)
    return ns.C.ICONS .. name
end

-- key may be one of ours or any LibSharedMedia name.
function M:Font(key)
    if self.needsFallbackFont then return STANDARD_TEXT_FONT end
    local m = byKey[key]
    if m then return m.file end
    return LSM:Fetch("font", key, true) or STANDARD_TEXT_FONT
end

function M:Bar(key)
    local m = byKey[key]
    if m then return m.file end
    return LSM:Fetch("statusbar", key, true) or self.textures.WHITE
end

-- Lists for config dropdowns: our media first, then everything other addons registered.
function M:List(kind)
    local own = kind == "font" and self.fonts or self.bars
    local out, seen = {}, {}
    for _, m in ipairs(own) do
        out[#out + 1] = { value = m.key, label = m.name }
        seen[m.name] = true
    end
    for _, name in ipairs(LSM:List(kind == "font" and "font" or "statusbar")) do
        if not seen[name] then out[#out + 1] = { value = name, label = name } end
    end
    return out
end

for _, m in ipairs(M.fonts) do LSM:Register("font", m.name, m.file, LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU) end
for _, m in ipairs(M.bars) do LSM:Register("statusbar", m.name, m.file) end
LSM:Register("background", "Phoenix Base", M.textures.WHITE)
