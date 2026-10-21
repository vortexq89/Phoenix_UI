local _, ns = ...
local Opt = ns.Opt

local allGet, allSet = ns.Combat.CVarAccessors("nameplateShowAll")
local enemyGet, enemySet = ns.Combat.CVarAccessors("nameplateShowEnemies")

local function noHealthText(m) return not m.db.healthText end
local function nameUnstyled(m) return not m.db.name.styled end

ns:RegisterOptions("NamePlates", {
    { type = "preview", kind = "nameplate" },
    { type = "header", label = "NP_STYLE" },
    { type = "toggle", key = "texture", label = "NP_TEXTURE", desc = "NP_TEXTURE_DESC", reload = true },
    { type = "texture", key = "bar", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture" },
    Opt.Border("border"),
    Opt.Background("background"),
    { type = "header", label = "NP_TEXT" },
    { type = "toggle", key = "healthText", label = "NP_HEALTH_TEXT", desc = "NP_HEALTH_TEXT_DESC", keywords = "percent hp" },
    Opt.Text("health", "NP_HEALTH_FONT", { place = true, max = 20, row = { disabled = noHealthText } }),
    { type = "toggle", key = "name.styled", label = "NP_NAME_STYLED", desc = "NP_NAME_STYLED_DESC" },
    Opt.Text("name", "NP_NAME_FONT", { max = 20, row = { disabled = nameUnstyled } }),
    { type = "toggle", key = "forces", label = "NP_FORCES", desc = "NP_FORCES_DESC",
      keywords = "mythic plus enemy forces count percent trash" },
    Opt.Text("forcesText", "NP_FORCES_FONT", { max = 20, token = "accent.secondary",
      row = { disabled = function(m) return not m.db.forces end } }),
    { type = "header", label = "BLIZZARD_FEATURES" },
    { type = "toggle", label = "NP_SHOW_ALL", desc = "NP_SHOW_ALL_DESC", get = allGet, set = allSet, combat = true },
    { type = "toggle", label = "NP_SHOW_ENEMIES", desc = "NP_SHOW_ENEMIES_DESC", get = enemyGet, set = enemySet, combat = true },
})
