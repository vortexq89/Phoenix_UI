local _, ns = ...

local allGet, allSet = ns.Combat.CVarAccessors("nameplateShowAll")
local enemyGet, enemySet = ns.Combat.CVarAccessors("nameplateShowEnemies")

ns:RegisterOptions("NamePlates", {
    { type = "header", label = "NP_STYLE" },
    { type = "toggle", key = "texture", label = "NP_TEXTURE", desc = "NP_TEXTURE_DESC", reload = true },
    { type = "toggle", key = "healthText", label = "NP_HEALTH_TEXT", desc = "NP_HEALTH_TEXT_DESC", keywords = "percent hp" },
    { type = "range", key = "textSize", label = "FONT_SIZE", min = 7, max = 16, step = 1,
      disabled = function(m) return not m.db.healthText end },
    { type = "toggle", key = "forces", label = "NP_FORCES", desc = "NP_FORCES_DESC",
      keywords = "mythic plus enemy forces count percent trash" },
    { type = "header", label = "BLIZZARD_FEATURES" },
    { type = "toggle", label = "NP_SHOW_ALL", desc = "NP_SHOW_ALL_DESC", get = allGet, set = allSet, combat = true },
    { type = "toggle", label = "NP_SHOW_ENEMIES", desc = "NP_SHOW_ENEMIES_DESC", get = enemyGet, set = enemySet, combat = true },
})
