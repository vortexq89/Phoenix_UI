local _, ns = ...

local cdGet, cdSet = ns.Combat.CVarAccessors("countdownForCooldowns")

ns:RegisterOptions("CooldownText", {
    { type = "preview", kind = "cooldowntext" },
    { type = "header", label = "BLIZZARD_FEATURES", icon = "general" },
    { type = "toggle", label = "CD_NUMBERS", desc = "CD_NUMBERS_DESC", get = cdGet, set = cdSet, combat = true,
      keywords = "countdown omnicc timer" },
    { type = "header", label = "CD_STYLE", icon = "theme" },
    { type = "range", key = "size", label = "FONT_SIZE", min = 10, max = 28, step = 1 },
    { type = "color", key = "color", label = "CD_COLOR" },
})
