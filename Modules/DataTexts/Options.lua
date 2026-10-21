local _, ns = ...

ns:RegisterOptions("DataTexts", {
    { type = "header", label = "DT_SEGMENTS" },
    { type = "toggle", key = "fps", label = "DT_FPS", keywords = "framerate" },
    { type = "toggle", key = "latency", label = "DT_LATENCY", keywords = "ping ms" },
    { type = "toggle", key = "speed", label = "DT_SPEED", keywords = "movement" },
    { type = "toggle", key = "durability", label = "DT_DURABILITY", keywords = "repair armor" },
    { type = "toggle", key = "gold", label = "DT_GOLD", keywords = "money" },
    { type = "toggle", key = "clock", label = "DT_CLOCK", keywords = "time" },
    { type = "toggle", key = "clock24", label = "DT_CLOCK24", disabled = function(m) return not m.db.clock end },
    { type = "header", label = "DT_STYLE" },
    { type = "toggle", key = "background", label = "DT_BACKGROUND", desc = "DT_BACKGROUND_DESC" },
    { type = "range", key = "scale", label = "SCALE", min = 0.6, max = 2, step = 0.05, percent = true },
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
