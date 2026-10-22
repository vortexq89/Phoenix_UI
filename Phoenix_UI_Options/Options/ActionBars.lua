local _, ns = ...
local Opt = ns.Opt

local function flat(m) return not m.db.style end

ns:RegisterOptions("ActionBars", {
    { type = "preview", kind = "actionbar" },
    { type = "header", label = "AB_STYLE", icon = "actionbars" },
    { type = "toggle", key = "style", label = "AB_SQUARE", desc = "AB_SQUARE_DESC", reload = true },
    { type = "range", key = "iconZoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, disabled = flat },
    Opt.Border("border", "AB_BORDER"),
    { type = "header", label = "AB_TEXT", icon = "fonts" },
    { type = "toggle", key = "hotkeys", label = "AB_HOTKEYS", desc = "AB_HOTKEYS_DESC", keywords = "keybind" },
    Opt.Text("hotkey", "AB_HOTKEY_FONT", { place = true, max = 20, row = { disabled = function(m) return not m.db.hotkeys end } }),
    Opt.Text("count", "AB_COUNT_FONT", { place = true, max = 20 }),
    { type = "toggle", key = "macroText", label = "AB_MACRO", desc = "AB_MACRO_DESC" },
    Opt.Text("macro", "AB_MACRO_FONT", { place = true, max = 16, row = { disabled = function(m) return not m.db.macroText end } }),
    { type = "header", label = "AB_FEEDBACK", icon = "preview" },
    { type = "toggle", key = "rangeTint", label = "AB_RANGE", desc = "AB_RANGE_DESC", keywords = "out of range red",
      cog = { { type = "color", key = "rangeColor", label = "AB_RANGE_COLOR", token = "state.danger", reset = true } } },
    { type = "description", text = "AB_EDITMODE_NOTE" },
})
