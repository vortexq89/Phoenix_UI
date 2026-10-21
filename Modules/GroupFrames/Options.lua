local _, ns = ...

ns:RegisterOptions("GroupFrames", {
    { type = "header", label = "GF_STYLE" },
    { type = "toggle", key = "texture", label = "GF_TEXTURE", desc = "GF_TEXTURE_DESC", keywords = "raid party" },
    { type = "toggle", key = "fonts", label = "GF_FONTS", desc = "GF_FONTS_DESC" },
    { type = "range", key = "nameSize", label = "FONT_SIZE", min = 8, max = 16, step = 1,
      disabled = function(m) return not m.db.fonts end },
    { type = "description", text = "GF_NOTE" },
})
