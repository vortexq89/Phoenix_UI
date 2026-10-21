local _, ns = ...

ns:RegisterOptions("UnitFrames", {
    { type = "header", label = "UF_BARS" },
    { type = "toggle", key = "texture", label = "UF_TEXTURE", desc = "UF_TEXTURE_DESC", reload = true },
    { type = "toggle", key = "classColor", label = "UF_CLASSCOLOR", desc = "UF_CLASSCOLOR_DESC", keywords = "class colour health" },
    { type = "toggle", key = "powerColor", label = "UF_POWERCOLOR", desc = "UF_POWERCOLOR_DESC" },
    { type = "header", label = "UF_TEXT" },
    { type = "toggle", key = "fonts", label = "UF_FONTS", desc = "UF_FONTS_DESC", reload = true },
    { type = "description", text = "UF_EDITMODE_NOTE" },
})
