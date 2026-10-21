local _, ns = ...

local Opt = ns.Opt

ns:RegisterOptions("DataTexts", {
    { type = "preview", kind = "datatexts" },
    { type = "header", label = "DT_SEGMENTS" },
    { type = "toggle", key = "fps", label = "DT_FPS", keywords = "framerate" },
    { type = "toggle", key = "latency", label = "DT_LATENCY", keywords = "ping ms" },
    { type = "toggle", key = "speed", label = "DT_SPEED", keywords = "movement" },
    { type = "toggle", key = "durability", label = "DT_DURABILITY", keywords = "repair armor" },
    { type = "toggle", key = "gold", label = "DT_GOLD", keywords = "money" },
    { type = "toggle", key = "clock", label = "DT_CLOCK", keywords = "time" },
    { type = "toggle", key = "clock24", label = "DT_CLOCK24", disabled = function(m) return not m.db.clock end },
    { type = "toggle", key = "bugs", label = "DT_BUGS", desc = "DT_BUGS_DESC", keywords = "errors lua",
      disabled = function() local b = ns:GetModule("Bugs"); return not (b and b:IsEnabled()) end },
    { type = "header", label = "DT_STYLE" },
    { type = "toggle", key = "background", label = "DT_BACKGROUND", desc = "DT_BACKGROUND_DESC",
      cog = Opt.Flat(Opt.Background("backdrop", nil, "bg.base"), Opt.Border("border", nil, "border.subtle")) },
    { type = "range", key = "scale", label = "SCALE", min = 0.6, max = 2, step = 0.05, percent = true },
    { type = "range", key = "height", label = "DT_HEIGHT", min = 18, max = 40, step = 1 },
    { type = "range", key = "spacing", label = "DT_SPACING", min = 4, max = 40, step = 1 },
    { type = "select", key = "strata", label = "FRAME_STRATA", values = Opt.STRATA, keywords = "layer above below" },
    { type = "header", label = "DT_TEXT" },
    Opt.Text("value", "DT_VALUE_FONT", { max = 20 }),
    Opt.Text("unitText", "DT_UNIT_FONT", { max = 18, token = "text.muted" }),
    { type = "toggle", key = "colorValues", label = "DT_COLOR_VALUES", desc = "DT_COLOR_VALUES_DESC" },
    { type = "toggle", key = "icons", label = "DT_ICONS" },
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
