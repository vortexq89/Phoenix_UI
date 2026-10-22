local _, ns = ...
local Opt = ns.Opt

local presets = {}
for _, p in ipairs(ns.Theme.presets) do presets[#presets + 1] = { value = p.key, label = p.label } end

ns:RegisterOptions("General", {
    { type = "preview", kind = "theme" },
    { type = "header", label = "APPEARANCE", icon = "theme" },
    { type = "select", key = "theme.preset", label = "THEME", desc = "THEME_DESC", values = presets, keywords = "color colour accent" },
    { type = "color", key = "theme.custom", label = "THEME_CUSTOM_COLOR",
      hidden = function(m) return m.db.theme.preset ~= "custom" end },
    { type = "texture", key = "theme.barTexture", label = "BAR_TEXTURE", desc = "BAR_TEXTURE_DESC" },
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
    { type = "header", label = "ACCESSIBILITY", icon = "user" },
    { type = "toggle", key = "theme.reduceMotion", label = "REDUCE_MOTION", desc = "REDUCE_MOTION_DESC", keywords = "animation" },
})
