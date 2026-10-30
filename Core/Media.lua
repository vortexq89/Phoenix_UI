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
-- Phoenix Font (OFL, tools/media/phoenix_font/build.py: a Modified Version of Barlow Semi Condensed): the default
-- face of every text role. Latin only; Russian clients draw it in PT Sans Narrow (DESIGN_SYSTEM_V3 §3a/§3b).
for _, w in ipairs({ { "PhoenixFont", "Phoenix Font", "PhoenixFont-Regular.ttf", "Regular" },
    { "PhoenixFontSemiBold", "Phoenix Font SemiBold", "PhoenixFont-SemiBold.ttf", "SemiBold" },
    { "PhoenixFontBold", "Phoenix Font Bold", "PhoenixFont-Bold.ttf", "Bold" } }) do
    local f = core(w[1], w[2], w[3], "Phoenix Font", w[4])
    f.category, f.cyrillic, f.phoenix = "core", false, true
    M.fonts[#M.fonts + 1] = f
end
for _, m in ipairs(ns.FontData) do M.fonts[#M.fonts + 1] = m end

M.bars = ns.TextureData.bars

-- CC0 sounds (Media/Sounds/SOUNDS.md). Keys are saved settings; names are the LibSharedMedia names.
local S = ns.C.MEDIA .. "Sounds\\"
M.sounds = {
    { key = "AlertOnYou", name = "Phoenix: Alert (on you)", label = "SOUND_ALERT_ON_YOU", path = S .. "AlertOnYou.ogg" },
    { key = "AlertUnderYou", name = "Phoenix: Alert (under you)", label = "SOUND_ALERT_UNDER_YOU", path = S .. "AlertUnderYou.ogg" },
}
-- Countdown voices: M:Voice(key, n) -> the file that says n (1-10).
M.voices = { { key = "Jim", name = "Jim" }, { key = "David", name = "David" } }
function M:Voice(key, n)
    if not (n and n >= 1 and n <= 10) then return nil end
    for _, v in ipairs(self.voices) do
        if v.key == key then return S .. "Countdown\\" .. key .. "\\" .. n .. ".ogg" end
    end
end

M.textures = {
    WHITE = "Interface\\Buttons\\WHITE8X8",
    SHADOW = T .. "Shadow",
    PILL = T .. "Pill",
    CIRCLE = T .. "Circle",
    ROUNDED = T .. "Rounded",
    FADE_V = T .. "FadeV",
    -- action button shapes: alpha masks for the icon and swipe, and the matching outline for the border
    MASK_ROUNDED = T .. "MaskRounded",
    MASK_CIRCLE = T .. "MaskCircle",
    MASK_HEX = T .. "MaskHex",
    RING_ROUNDED = T .. "RingRounded",
    RING_CIRCLE = T .. "RingCircle",
    RING_HEX = T .. "RingHex",
    -- minimap rectangle masks: the percent of the map's height that stays visible
    MINIMAP_RECT50 = T .. "MinimapRect50", MINIMAP_RECT60 = T .. "MinimapRect60", MINIMAP_RECT70 = T .. "MinimapRect70",
    MINIMAP_RECT80 = T .. "MinimapRect80", MINIMAP_RECT90 = T .. "MinimapRect90",
}

-- Keys saved by earlier builds, kept working.
local ALIASES = { Inter = "InterBold", Cinzel = "CinzelBold", PhoenixFontRegular = "PhoenixFont" }

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

for _, m in ipairs(M.sounds) do byKey[m.key] = m end

function M:Get(key) return byKey[key] end

-- Plays one of our sounds or any LibSharedMedia sound on the chosen channel; "" or unknown keys stay silent.
function M:Sound(key)
    local m = byKey[key]
    if m and m.path and m.path:find("%.ogg$") then return m.path end
    return key and key ~= "" and LSM:Fetch("sound", key, true) or nil
end

function M:PlaySound(key, channel)
    local path = self:Sound(key)
    if path then PlaySoundFile(path, channel or ns.Theme.settings.soundChannel or "Master") end
end

--[[ Expressway by reference (DESIGN_SYSTEM_V3 §3a). Its licence forbids redistribution, so Phoenix never ships or
    copies it: when another installed addon already provides it (LibSharedMedia "Expressway", or EllesmereUI's / ElvUI's
    media folder), the Phoenix Font keys draw with that file instead. M.external = { regular, bold, source } or nil.
    General > Text "Prefer Expressway when installed" (theme.expressway) turns this off. ]]
local function prefers() return not (ns.Theme and ns.Theme.settings and ns.Theme.settings.expressway == false) end
local EXTERNAL = {
    { addon = "EllesmereUI", regular = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
      bold = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway Bold.ttf" },
    { addon = "ElvUI", regular = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Expressway.ttf" },
    { addon = "ElvUI", regular = "Interface\\AddOns\\ElvUI\\Media\\Fonts\\Expressway.ttf" },
}
local probe
-- true when the client can draw text with the font file at path (a missing file fails SetFont)
local function loads(path)
    if type(path) ~= "string" or path == "" then return false end
    probe = probe or UIParent:CreateFontString(nil, "BACKGROUND")
    M._probe = probe
    local ok, set = pcall(probe.SetFont, probe, path, 12, "")
    if not ok or set == false then return false end
    local got = probe:GetFont()
    return got ~= nil and got:lower() == path:lower()
end
M.FontLoads = loads
local function installed(name)
    local info = C_AddOns and C_AddOns.GetAddOnInfo and select(1, C_AddOns.GetAddOnInfo(name))
    return info ~= nil
end
-- Finds Expressway; returns true when the result changed (callers re-skin).
function M:ResolveExternal()
    local found
    local reg = LSM:Fetch("font", "Expressway", true)
    if reg and loads(reg) then
        local bold = LSM:Fetch("font", "Expressway Bold", true)
        found = { regular = reg, bold = (bold and loads(bold)) and bold or reg, source = "LibSharedMedia" }
    else
        for _, c in ipairs(EXTERNAL) do
            if installed(c.addon) and loads(c.regular) then
                found = { regular = c.regular, bold = (c.bold and loads(c.bold)) and c.bold or c.regular, source = c.addon }
                break
            end
        end
    end
    local old = self.external
    self.external = found
    return (old and old.regular) ~= (found and found.regular)
end
-- What the Phoenix Font keys draw with now: "expressway", source | "phoenix" | "cyrillic" | "game".
function M:DefaultFontSource()
    if self.needsFallbackFont then return "game" end
    if self.needsCyrillic then return "cyrillic" end
    if prefers() and self.external then return "expressway", self.external.source end
    return "phoenix"
end

local BOLD = { Bold = true, SemiBold = true, ExtraBold = true, Black = true }
-- key may be one of ours or any LibSharedMedia name. latinOnly: the text is always Latin (the "PHOENIX" brand).
function M:Font(key, latinOnly)
    if self.needsFallbackFont then return STANDARD_TEXT_FONT end
    local m = byKey[key]
    if m then
        if self.needsCyrillic and not m.cyrillic and not latinOnly then
            return (BOLD[m.weight] and byKey.PTSansNarrowBold or byKey.PTSansNarrowRegular).path
        end
        if m.phoenix and self.external and prefers() then
            return BOLD[m.weight] and self.external.bold or self.external.regular
        end
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
    if kind == "sound" then
        for _, m in ipairs(self.sounds) do
            out[#out + 1] = { value = m.key, label = ns.L[m.label], sound = m.path, group = "Phoenix" }
            seen[m.name] = true
        end
        for _, name in ipairs(LSM:List("sound")) do
            if not seen[name] and name ~= "None" then
                out[#out + 1] = { value = name, label = name, sound = LSM:Fetch("sound", name, true), group = "LibSharedMedia" }
            end
        end
        return out
    end
    if kind == "font" then
        for _, m in ipairs(self.fonts) do
            if not (self.needsCyrillic and not m.cyrillic) then
                out[#out + 1] = { value = m.key, label = m.name:gsub("^Phoenix ", ""), font = m.path, group = m.family,
                    category = m.category }
            end
            seen[m.name] = true
        end
    else
        for _, m in ipairs(self.bars) do
            out[#out + 1] = { value = m.key, label = m.name:gsub("^Phoenix ", ""), texture = m.path, group = "Phoenix", style = m.style }
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
for _, m in ipairs(M.sounds) do LSM:Register("sound", m.name, m.path) end

-- Expressway can be registered or loaded after Phoenix: resolve at login and whenever a font is registered.
local function reresolve()
    if M:ResolveExternal() and ns.Theme and ns.Theme.Apply then ns.Theme:Apply() end
end
ns.Events:On("PLAYER_LOGIN", M, reresolve)
LSM.RegisterCallback(M, "LibSharedMedia_Registered", function(_, mediatype, key)
    if mediatype == "font" and (key == "Expressway" or key == "Expressway Bold") then reresolve() end
end)
