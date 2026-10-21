local _, ns = ...

local cdGet, cdSet = ns.Combat.CVarAccessors("countdownForCooldowns")

ns:RegisterOptions("CooldownText", {
    { type = "header", label = "BLIZZARD_FEATURES" },
    { type = "toggle", label = "CD_NUMBERS", desc = "CD_NUMBERS_DESC", get = cdGet, set = cdSet, combat = true,
      keywords = "countdown omnicc timer" },
    { type = "header", label = "CD_STYLE" },
    { type = "range", key = "size", label = "FONT_SIZE", min = 10, max = 28, step = 1 },
    { type = "color", key = "color", label = "CD_COLOR" },
})
