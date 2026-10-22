local _, ns = ...

ns:RegisterOptions("SpellHistory", {
    { type = "preview", kind = "spellhistory" },
    { type = "header", label = "SH_LAYOUT" },
    { type = "range", key = "count", label = "SH_COUNT", min = 2, max = 12, step = 1 },
    { type = "range", key = "size", label = "SH_SIZE", min = 18, max = 64, step = 1 },
    { type = "range", key = "spacing", label = "SH_SPACING", min = 0, max = 16, step = 1 },
    { type = "select", key = "grow", label = "SH_GROW", values = {
        { value = "RIGHT", label = "DIR_RIGHT" }, { value = "LEFT", label = "DIR_LEFT" },
        { value = "UP", label = "DIR_UP" }, { value = "DOWN", label = "DIR_DOWN" },
    } },
    { type = "header", label = "SH_BEHAVIOUR" },
    { type = "range", key = "fade", label = "SH_FADE", desc = "SH_FADE_DESC", min = 0, max = 30, step = 1 },
    { type = "toggle", key = "inCombatOnly", label = "SH_COMBAT_ONLY", desc = "SH_COMBAT_ONLY_DESC" },
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
