local _, ns = ...

ns:RegisterOptions("Tooltip", {
    { type = "header", label = "TOOLTIP_STYLE" },
    { type = "toggle", key = "skin", label = "TOOLTIP_SKIN", desc = "TOOLTIP_SKIN_DESC", reload = true },
    { type = "toggle", key = "healthBar", label = "TOOLTIP_HEALTHBAR", desc = "TOOLTIP_HEALTHBAR_DESC", reload = true },
    { type = "toggle", key = "classBorder", label = "TOOLTIP_CLASS_BORDER", desc = "TOOLTIP_CLASS_BORDER_DESC" },
    { type = "toggle", key = "qualityBorder", label = "TOOLTIP_QUALITY_BORDER", desc = "TOOLTIP_QUALITY_BORDER_DESC" },
    { type = "header", label = "TOOLTIP_BEHAVIOUR" },
    { type = "select", key = "anchor", label = "TOOLTIP_ANCHOR", desc = "TOOLTIP_ANCHOR_DESC", values = {
        { value = "DEFAULT", label = "TOOLTIP_ANCHOR_DEFAULT" }, { value = "CURSOR", label = "TOOLTIP_ANCHOR_CURSOR" },
    }, keywords = "mouse" },
    { type = "toggle", key = "hideInCombat", label = "TOOLTIP_HIDE_COMBAT", desc = "TOOLTIP_HIDE_COMBAT_DESC" },
    { type = "header", label = "TOOLTIP_LINES" },
    { type = "toggle", key = "target", label = "TOOLTIP_TARGET", desc = "TOOLTIP_TARGET_DESC" },
    { type = "toggle", key = "role", label = "TOOLTIP_ROLE", desc = "TOOLTIP_ROLE_DESC" },
    { type = "toggle", key = "ids", label = "TOOLTIP_IDS", desc = "TOOLTIP_IDS_DESC", keywords = "spellid itemid idtip" },
})
