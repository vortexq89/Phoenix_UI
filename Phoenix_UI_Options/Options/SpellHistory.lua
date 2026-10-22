local _, ns = ...

ns:RegisterOptions("SpellHistory", {
    { type = "preview", kind = "spellhistory" },
    { type = "header", label = "SH_LAYOUT", icon = "grid" },
    { type = "range", key = "count", label = "SH_COUNT", min = 2, max = 12, step = 1 },
    { type = "range", key = "size", label = "SH_SIZE", min = 18, max = 64, step = 1 },
    { type = "range", key = "spacing", label = "SH_SPACING", min = 0, max = 16, step = 1 },
    { type = "select", key = "grow", label = "SH_GROW", values = {
        { value = "RIGHT", label = "DIR_RIGHT" }, { value = "LEFT", label = "DIR_LEFT" },
        { value = "UP", label = "DIR_UP" }, { value = "DOWN", label = "DIR_DOWN" },
    } },
    { type = "header", label = "SH_ICONS", icon = "border" },
    ns.Opt.Border("border", "SH_BORDER"),
    { type = "range", key = "zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01, keywords = "crop trim icon" },
    { type = "header", label = "SH_BEHAVIOUR", icon = "cog" },
    { type = "toggle", key = "markFailed", label = "SH_FAILED", desc = "SH_FAILED_DESC", keywords = "interrupted failed kicked cancelled" },
    { type = "range", key = "fade", label = "SH_FADE", desc = "SH_FADE_DESC", min = 0, max = 30, step = 1 },
    { type = "toggle", key = "inCombatOnly", label = "SH_COMBAT_ONLY", desc = "SH_COMBAT_ONLY_DESC" },
    { type = "button", label = "DT_MOVE", desc = "DT_MOVE_DESC", button = "OPEN_EDIT_MODE", icon = "editmode",
      func = function() ns.Config.frame:Hide(); ns.EditMode:Open() end },
})
