local _, ns = ...
local Opt = ns.Opt

local function flat(m) return not m.db.style end

ns:RegisterOptions("Auras", {
    { type = "preview", kind = "auras" },
    { type = "header", label = "AURAS_STYLE", icon = "theme" },
    { type = "toggle", key = "style", label = "AURAS_SKIN", desc = "AURAS_SKIN_DESC", reload = true, keywords = "buffs debuffs" },
    { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, disabled = flat },
    Opt.Border("border"),
    { type = "header", label = "AURAS_TEXT", icon = "fonts" },
    Opt.Text("duration", "AURAS_DURATION_FONT", { max = 18, row = { disabled = flat } }),
    Opt.Text("count", "AURAS_COUNT_FONT", { max = 20, row = { disabled = flat } }),
    { type = "description", text = "AURAS_NOTE" },
})
