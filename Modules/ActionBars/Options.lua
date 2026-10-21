local _, ns = ...

ns:RegisterOptions("ActionBars", {
    { type = "header", label = "AB_STYLE" },
    { type = "toggle", key = "style", label = "AB_SQUARE", desc = "AB_SQUARE_DESC", reload = true },
    { type = "range", key = "fontSize", label = "FONT_SIZE", min = 8, max = 18, step = 1 },
    { type = "header", label = "AB_TEXT" },
    { type = "toggle", key = "hotkeys", label = "AB_HOTKEYS", desc = "AB_HOTKEYS_DESC", keywords = "keybind" },
    { type = "toggle", key = "macroText", label = "AB_MACRO", desc = "AB_MACRO_DESC" },
    { type = "header", label = "AB_FEEDBACK" },
    { type = "toggle", key = "rangeTint", label = "AB_RANGE", desc = "AB_RANGE_DESC", keywords = "out of range red" },
    { type = "description", text = "AB_EDITMODE_NOTE" },
})
