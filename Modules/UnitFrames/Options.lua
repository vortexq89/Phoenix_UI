local _, ns = ...
local Opt = ns.Opt

local function noFonts(m) return not m.db.fonts end

ns:RegisterOptions("UnitFrames", {
    { type = "scope", key = "units", label = "UF_FRAME", values = {
        { value = "player", label = "UF_PLAYER" }, { value = "target", label = "UF_TARGET" },
        { value = "focus", label = "UF_FOCUS" }, { value = "pet", label = "UF_PET" },
    } },
    { type = "preview", kind = "unitframe" },
    { type = "header", label = "UF_BARS" },
    { type = "toggle", key = "texture", label = "UF_TEXTURE", desc = "UF_TEXTURE_DESC", reload = true },
    { type = "texture", key = "units.@.texture", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture" },
    Opt.Border("units.@.border", "UF_HEALTH_BORDER"),
    Opt.Background("units.@.background"),
    { type = "header", label = "UF_COLORS" },
    { type = "toggle", key = "classColor", label = "UF_CLASSCOLOR", desc = "UF_CLASSCOLOR_DESC", keywords = "class colour health" },
    { type = "toggle", key = "powerColor", label = "UF_POWERCOLOR", desc = "UF_POWERCOLOR_DESC" },
    { type = "header", label = "UF_TEXT" },
    { type = "toggle", key = "fonts", label = "UF_FONTS", desc = "UF_FONTS_DESC", reload = true },
    Opt.Text("units.@.name", "UF_NAME_FONT", { row = { disabled = noFonts } }),
    Opt.Text("units.@.health", "UF_HEALTH_FONT", { row = { disabled = noFonts } }),
    Opt.Text("units.@.power", "UF_POWER_FONT", { row = { disabled = noFonts } }),
    { type = "description", text = "UF_EDITMODE_NOTE" },
})
