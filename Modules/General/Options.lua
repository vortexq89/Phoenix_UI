local _, ns = ...

local presets = {}
for _, p in ipairs(ns.Theme.presets) do presets[#presets + 1] = { value = p.key, label = p.label } end

ns:RegisterOptions("General", {
    { type = "preview", kind = "theme" },
    { type = "header", label = "APPEARANCE" },
    { type = "select", key = "theme.preset", label = "THEME", desc = "THEME_DESC", values = presets, keywords = "color colour accent" },
    { type = "color", key = "theme.custom", label = "THEME_CUSTOM_COLOR",
      hidden = function(m) return m.db.theme.preset ~= "custom" end },
    { type = "texture", key = "theme.barTexture", label = "BAR_TEXTURE", desc = "BAR_TEXTURE_DESC" },
    { type = "header", label = "TYPOGRAPHY" },
    { type = "font", key = "theme.uiFont", label = "UI_FONT", desc = "UI_FONT_DESC", allowDefault = true },
    { type = "font", key = "theme.unitFont", label = "UNIT_FONT", desc = "UNIT_FONT_DESC", allowDefault = true },
    { type = "range", key = "theme.fontScale", label = "FONT_SCALE", desc = "FONT_SCALE_DESC", min = 0.8, max = 1.4, step = 0.05,
      percent = true, keywords = "size accessibility" },
    { type = "header", label = "ACCESSIBILITY" },
    { type = "toggle", key = "theme.reduceMotion", label = "REDUCE_MOTION", desc = "REDUCE_MOTION_DESC", keywords = "animation" },
})
