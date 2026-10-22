local _, ns = ...
local Opt = ns.Opt

local L = ns.L
local scaleGet = ns.Combat.CVarAccessors("uiScale", "number")
local _, rawScaleSet = ns.Combat.CVarAccessors("uiScale", "number")
local _, useScaleSet = ns.Combat.CVarAccessors("useUiScale")
-- uiScale only applies while useUiScale is on; the client keeps it between 0.64 and 1
local function scaleSet(m, v) useScaleSet(m, true); rawScaleSet(m, math.max(0.64, math.min(1, v))) end
-- 768 / physical height: one UI unit per screen pixel (as close as the client allows)
local function pixelPerfect(m)
    local _, h = GetPhysicalScreenSize()
    if not h or h <= 0 then return end
    local v = math.max(0.64, math.min(1, 768 / h))
    scaleSet(m, v)
    ns.Config:SetStatus(L.GEN_PIXEL_DONE:format(v), "state.success")
end
local CHANNELS = {
    { value = "Master", label = "GEN_CHANNEL_MASTER" }, { value = "SFX", label = "GEN_CHANNEL_SFX" },
    { value = "Music", label = "GEN_CHANNEL_MUSIC" }, { value = "Ambience", label = "GEN_CHANNEL_AMBIENCE" },
    { value = "Dialog", label = "GEN_CHANNEL_DIALOG" },
}

local presets = {}
for _, p in ipairs(ns.Theme.presets) do presets[#presets + 1] = { value = p.key, label = p.label } end

-- Class colour overrides: two swatch rows; right-click a swatch to return to the game's colour.
local function classColors(first, last)
    local keys, tokens, labels = {}, {}, {}
    for i = first, last do
        local cf = ns.Theme.CLASSES[i]
        keys[#keys + 1] = "theme.classColors." .. cf
        tokens[#tokens + 1] = "class." .. cf
        labels[#labels + 1] = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf] or cf
    end
    return { type = "colors", keys = keys, tokens = tokens, labels = labels, keywords = "class colour color override custom" }
end

ns:RegisterOptions("General", {
    { type = "preview", kind = "theme" },
    { type = "header", label = "APPEARANCE", icon = "theme" },
    { type = "select", key = "theme.preset", label = "THEME", desc = "THEME_DESC", values = presets, keywords = "color colour accent" },
    { type = "color", key = "theme.custom", label = "THEME_CUSTOM_COLOR",
      hidden = function(m) return m.db.theme.preset ~= "custom" end },
    { type = "texture", key = "theme.barTexture", label = "BAR_TEXTURE", desc = "BAR_TEXTURE_DESC" },
    { type = "range", key = "theme.surfaceAlpha", label = "GEN_SURFACE", desc = "GEN_SURFACE_DESC", min = 0.3, max = 1,
      step = 0.05, percent = true, keywords = "window panel background opacity transparency glass" },
    { type = "header", label = "GEN_SCALE", icon = "layout" },
    { type = "range", label = "GEN_UI_SCALE", desc = "GEN_UI_SCALE_DESC", min = 0.64, max = 1, step = 0.01, combat = true,
      get = scaleGet, set = scaleSet, keywords = "ui scale size pixel perfect resolution uiscale" },
    { type = "button", label = "GEN_PIXEL", desc = "GEN_PIXEL_DESC", button = "GEN_PIXEL_BUTTON", icon = "layout", combat = true,
      func = pixelPerfect, keywords = "pixel perfect crisp borders 768" },
    -- the style library every module border set to "Follow Appearance" inherits (Core/Style.lua, Skin:ResolveBorder)
    { type = "header", label = "BORDERS_SHADOWS", icon = "border", desc = "BORDERS_SHADOWS_DESC" },
    { type = "style", kind = "border", key = "theme.borderStyle", label = "GLOBAL_BORDER", desc = "GLOBAL_BORDER_DESC",
      values = Opt.BORDER_GLOBAL, keywords = "edge frame outline style" },
    { type = "range", key = "theme.borderSize", label = "BORDER_SIZE", min = 1, max = 4, step = 1,
      disabled = function(m) return m.db.theme.borderStyle == "none" end },
    { type = "color", key = "theme.borderColor", label = "GLOBAL_BORDER_COLOR", desc = "GLOBAL_BORDER_COLOR_DESC",
      classToken = true, reset = true, token = "border.black",
      disabled = function(m) return m.db.theme.borderStyle == "none" end },
    { type = "range", key = "theme.shadowAlpha", label = "SHADOW_DEPTH", desc = "SHADOW_DEPTH_DESC", min = 0, max = 1,
      step = 0.05, percent = true, keywords = "drop shadow opacity" },
    { type = "color", key = "theme.glowColor", label = "GLOW_COLOR", desc = "GLOW_COLOR_DESC", classToken = true,
      reset = true, token = "accent.glow", keywords = "ember highlight" },
    { type = "header", label = "TYPOGRAPHY", icon = "fonts" },
    { type = "font", key = "theme.uiFont", label = "UI_FONT", desc = "UI_FONT_DESC", allowDefault = true },
    { type = "font", key = "theme.unitFont", label = "UNIT_FONT", desc = "UNIT_FONT_DESC", allowDefault = true },
    { type = "range", key = "theme.fontScale", label = "FONT_SCALE", desc = "FONT_SCALE_DESC", min = 0.8, max = 1.4, step = 0.05,
      percent = true, keywords = "size accessibility" },
    { type = "select", key = "theme.outline", label = "GEN_OUTLINE", desc = "GEN_OUTLINE_DESC", values = ns.Opt.OUTLINE,
      keywords = "font outline thick monochrome global" },
    { type = "toggle", key = "blizzardFonts", label = "GEN_BLIZZARD_FONTS", desc = "GEN_BLIZZARD_FONTS_DESC", reload = true,
      keywords = "replace blizzard game fonts names world" },
    { type = "header", label = "GEN_CLASS_COLORS", icon = "palette", desc = "GEN_CLASS_COLORS_DESC" },
    Opt.With(classColors(1, 7), { label = "GEN_CLASS_COLORS_A" }),
    Opt.With(classColors(8, 13), { label = "GEN_CLASS_COLORS_B" }),
    { type = "header", label = "GEN_SOUND", icon = "sound" },
    { type = "select", key = "theme.soundChannel", label = "GEN_CHANNEL", desc = "GEN_CHANNEL_DESC", values = CHANNELS,
      keywords = "sound channel master sfx volume" },
    { type = "input", key = "mute", label = "GEN_MUTE", desc = "GEN_MUTE_DESC", wide = true,
      keywords = "mute sound file id silence annoying" },
    { type = "header", label = "ACCESSIBILITY", icon = "user" },
    { type = "toggle", key = "theme.reduceMotion", label = "REDUCE_MOTION", desc = "REDUCE_MOTION_DESC", keywords = "animation" },
})
