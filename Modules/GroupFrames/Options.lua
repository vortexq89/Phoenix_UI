local _, ns = ...
local Opt = ns.Opt

local function noFonts(m) return not m.db.fonts end

ns:RegisterOptions("GroupFrames", {
    { type = "preview", kind = "groupframe" },
    { type = "header", label = "GF_STYLE" },
    { type = "toggle", key = "texture", label = "GF_TEXTURE", desc = "GF_TEXTURE_DESC", keywords = "raid party" },
    { type = "texture", key = "bar", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture raid party" },
    Opt.Border("border"),
    Opt.Background("background"),
    { type = "header", label = "GF_TEXT" },
    { type = "toggle", key = "fonts", label = "GF_FONTS", desc = "GF_FONTS_DESC" },
    Opt.Text("name", "GF_NAME_FONT", { min = 8, max = 18, row = { disabled = noFonts } }),
    Opt.Text("status", "GF_STATUS_FONT", { min = 8, max = 18, row = { disabled = noFonts } }),
    { type = "description", text = "GF_NOTE" },
})
