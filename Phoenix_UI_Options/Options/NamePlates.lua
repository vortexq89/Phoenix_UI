local _, ns = ...
local Opt = ns.Opt

local allGet, allSet = ns.Combat.CVarAccessors("nameplateShowAll")
local enemyGet, enemySet = ns.Combat.CVarAccessors("nameplateShowEnemies")

local function noHealthText(m) return not m.db.healthText end
local function nameUnstyled(m) return not m.db.name.styled end
local function noCast(m) return not m.db.castbar.style end
local function noThreat(m) return not m.db.threat.enabled end
local function noAuras(m) return not m.db.auras.style end

ns:RegisterOptions("NamePlates", {
    { type = "preview", kind = "nameplate" },
    { type = "tab", label = "TAB_APPEARANCE" },
    { type = "header", label = "NP_STYLE" },
    { type = "toggle", key = "texture", label = "NP_TEXTURE", desc = "NP_TEXTURE_DESC", reload = true },
    { type = "texture", key = "bar", label = "BAR_TEXTURE", allowDefault = true,
      disabled = function(m) return not m.db.texture end, keywords = "statusbar texture" },
    { type = "header", label = "NP_FRAME" },
    Opt.Border("border"),
    Opt.Background("background"),
    { type = "header", label = "NP_CASTBAR" },
    { type = "toggle", key = "castbar.style", label = "NP_CASTBAR_STYLE", desc = "NP_CASTBAR_STYLE_DESC", keywords = "cast bar plate" },
    { type = "texture", key = "castbar.texture", label = "BAR_TEXTURE", allowDefault = true, disabled = noCast },
    { type = "color", key = "castbar.color", label = "NP_CASTBAR_COLOR", desc = "NP_CASTBAR_COLOR_DESC", token = "accent.primary",
      reset = true, disabled = noCast },
    Opt.Text("castbar.text", "NP_CASTBAR_FONT", { max = 18, row = { disabled = noCast } }),
    { type = "header", label = "NP_AURAS" },
    { type = "toggle", key = "auras.style", label = "NP_AURAS_STYLE", desc = "NP_AURAS_STYLE_DESC",
      keywords = "debuff buff aura icons row dots",
      cog = { { type = "range", key = "auras.zoom", label = "ICON_ZOOM", min = 0, max = 0.3, step = 0.01 } } },
    Opt.With(Opt.Border("auras.border"), { disabled = noAuras }),
    { type = "tab", label = "TAB_COLORS" },
    { type = "header", label = "NP_HIGHLIGHT" },
    { type = "toggle", key = "highlight.target", label = "NP_TARGET_COLOR", desc = "NP_TARGET_COLOR_DESC", keywords = "target colour",
      cog = { { type = "color", key = "highlight.targetColor", label = "TEXT_COLOR", token = "accent.primary", reset = true } } },
    { type = "toggle", key = "highlight.focus", label = "NP_FOCUS_COLOR", desc = "NP_FOCUS_COLOR_DESC", keywords = "focus colour",
      cog = { { type = "color", key = "highlight.focusColor", label = "TEXT_COLOR", token = "state.info", reset = true } } },
    { type = "header", label = "NP_THREAT" },
    { type = "toggle", key = "threat.enabled", label = "NP_THREAT_COLORS", desc = "NP_THREAT_COLORS_DESC",
      keywords = "threat aggro tank colour" },
    { type = "colors", keys = { "threat.safe", "threat.warning", "threat.aggro" },
      tokens = { "state.success", "state.warning", "state.danger" },
      labels = { "NP_THREAT_SAFE", "NP_THREAT_WARNING", "NP_THREAT_AGGRO" }, label = "NP_THREAT_PICK", desc = "NP_THREAT_PICK_DESC",
      disabled = noThreat },
    { type = "tab", label = "TAB_TEXT" },
    { type = "header", label = "NP_TEXT", wide = true },
    { type = "toggle", key = "healthText", label = "NP_HEALTH_TEXT", desc = "NP_HEALTH_TEXT_DESC", keywords = "percent hp" },
    Opt.Text("health", "NP_HEALTH_FONT", { place = true, max = 20, row = { disabled = noHealthText } }),
    { type = "toggle", key = "name.styled", label = "NP_NAME_STYLED", desc = "NP_NAME_STYLED_DESC" },
    Opt.Text("name", "NP_NAME_FONT", { max = 20, row = { disabled = nameUnstyled } }),
    { type = "toggle", key = "forces", label = "NP_FORCES", desc = "NP_FORCES_DESC",
      keywords = "mythic plus enemy forces count percent trash" },
    Opt.Text("forcesText", "NP_FORCES_FONT", { max = 20, token = "accent.secondary",
      row = { disabled = function(m) return not m.db.forces end } }),
    { type = "header", label = "NP_AURAS" },
    Opt.Text("auras.count", "NP_AURA_COUNT_FONT", { max = 18, row = { disabled = noAuras } }),
    Opt.Text("auras.timer", "NP_AURA_TIMER_FONT", { max = 18, row = { disabled = noAuras } }),
    { type = "tab", label = "TAB_GAME" },
    { type = "header", label = "BLIZZARD_FEATURES" },
    { type = "toggle", label = "NP_SHOW_ALL", desc = "NP_SHOW_ALL_DESC", get = allGet, set = allSet, combat = true },
    { type = "toggle", label = "NP_SHOW_ENEMIES", desc = "NP_SHOW_ENEMIES_DESC", get = enemyGet, set = enemySet, combat = true },
})
