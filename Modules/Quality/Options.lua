local _, ns = ...

local cdmGet, cdmSet = ns.Combat.CVarAccessors("cooldownViewerEnabled")

ns:RegisterOptions("Quality", {
    { type = "header", label = "QUALITY_INTERFACE" },
    { type = "toggle", key = "hideTalkingHead", label = "HIDE_TALKING_HEAD", desc = "HIDE_TALKING_HEAD_DESC" },
    { type = "toggle", key = "filterErrors", label = "FILTER_ERRORS", desc = "FILTER_ERRORS_DESC", keywords = "red text spam" },
    { type = "toggle", key = "achievementScreenshot", label = "ACHIEVEMENT_SCREENSHOT", desc = "ACHIEVEMENT_SCREENSHOT_DESC" },
    { type = "header", label = "BLIZZARD_FEATURES" },
    { type = "toggle", label = "COOLDOWN_MANAGER", desc = "COOLDOWN_MANAGER_DESC", get = cdmGet, set = cdmSet, combat = true,
      keywords = "cooldown viewer tracker" },
})
