local _, ns = ...
local CVar = ns.Combat.CVarAccessors

-- item = { label, desc, keywords? } for a boolean FCT CVar
local function toggle(cvar, item)
    item.type, item.combat = "toggle", true
    item.get, item.set = CVar(cvar)
    return item
end

local Opt = ns.Opt
local scaleGet, scaleSet = CVar("WorldTextScale_v2", "number")
local function noScroll(m) return not m.db.scroll.enabled end
local function scroll(row) return Opt.With(row, { disabled = row.disabled or noScroll }) end
local AREAS = {
    { value = "incoming", label = "FCT_AREA_INCOMING" }, { value = "target", label = "FCT_AREA_TARGET" },
    { value = "notify", label = "FCT_AREA_NOTIFY" },
}
local DIRS = { { value = "UP", label = "GROW_UP" }, { value = "DOWN", label = "GROW_DOWN" } }
local CRIT = { { value = "grow", label = "FCT_CRIT_GROW" }, { value = "flash", label = "FCT_CRIT_FLASH" },
    { value = "none", label = "FCT_CRIT_NONE" } }
local modeGet, modeSet = CVar("floatingCombatTextFloatMode_v2", "number")

ns:RegisterOptions("CombatText", {
    { type = "scope", key = "scroll.areas", label = "FCT_AREA", values = AREAS },
    { type = "preview", kind = "combattext" },
    { type = "tab", label = "FCT_TAB_BLIZZARD" },
    { type = "description", text = "FCT_INTRO" },
    { type = "font", key = "damageFont", label = "FCT_DAMAGE_FONT", desc = "FCT_DAMAGE_FONT_DESC", allowDefault = true, reload = true,
      keywords = "damage font numbers floating relog" },
    { type = "header", label = "FCT_OUTGOING", icon = "arrow-up" },
    toggle("floatingCombatTextCombatDamage_v2", { label = "FCT_DAMAGE", desc = "FCT_DAMAGE_DESC", keywords = "numbers sct msbt" }),
    toggle("floatingCombatTextCombatLogPeriodicSpells_v2", { label = "FCT_PERIODIC", desc = "FCT_PERIODIC_DESC", keywords = "dot" }),
    toggle("floatingCombatTextPetMeleeDamage_v2", { label = "FCT_PET", desc = "FCT_PET_DESC" }),
    toggle("floatingCombatTextCombatHealing_v2", { label = "FCT_HEALING", desc = "FCT_HEALING_DESC" }),
    { type = "range", label = "FCT_SCALE", desc = "FCT_SCALE_DESC", min = 0.5, max = 2.5, step = 0.1,
      get = scaleGet, set = scaleSet, combat = true },
    { type = "header", label = "FCT_INCOMING", icon = "arrow-down" },
    toggle("enableFloatingCombatText", { label = "FCT_SELF", desc = "FCT_SELF_DESC", keywords = "msbt incoming" }),
    { type = "select", label = "FCT_MODE", desc = "FCT_MODE_DESC", get = modeGet, set = modeSet, combat = true, values = {
        { value = 1, label = "FCT_MODE_UP" }, { value = 2, label = "FCT_MODE_DOWN" }, { value = 3, label = "FCT_MODE_ARC" },
    } },
    toggle("floatingCombatTextDodgeParryMiss_v2", { label = "FCT_AVOIDANCE", desc = "FCT_AVOIDANCE_DESC" }),
    toggle("floatingCombatTextDamageReduction_v2", { label = "FCT_RESISTANCES", desc = "FCT_RESISTANCES_DESC" }),
    toggle("floatingCombatTextCombatState_v2", { label = "FCT_COMBAT_STATE", desc = "FCT_COMBAT_STATE_DESC" }),
    toggle("floatingCombatTextReactives_v2", { label = "FCT_REACTIVES", desc = "FCT_REACTIVES_DESC" }),
    toggle("floatingCombatTextLowManaHealth_v2", { label = "FCT_LOW", desc = "FCT_LOW_DESC" }),
    toggle("floatingCombatTextAuras_v2", { label = "FCT_AURAS", desc = "FCT_AURAS_DESC" }),
    toggle("floatingCombatTextEnergyGains_v2", { label = "FCT_ENERGY", desc = "FCT_ENERGY_DESC" }),
    toggle("floatingCombatTextHonorGains_v2", { label = "FCT_HONOR", desc = "FCT_HONOR_DESC" }),
    toggle("floatingCombatTextRepChanges_v2", { label = "FCT_REP", desc = "FCT_REP_DESC" }),
    ------------------------------------------------------------ Phoenix scroll areas
    { type = "tab", label = "FCT_TAB_SCROLL" },
    { type = "header", label = "FCT_SCROLL", icon = "combattext" },
    { type = "toggle", gate = true, key = "scroll.enabled", label = "FCT_SCROLL_ENABLE", desc = "FCT_SCROLL_ENABLE_DESC",
      keywords = "scrolling combat text sct msbt parrot areas" },
    { type = "description", text = "FCT_SCROLL_TEXT" },
    scroll({ type = "button", label = "FCT_SCROLL_TEST", desc = "FCT_SCROLL_TEST_DESC", button = "CB_TEST_BUTTON", icon = "test",
      func = function(m) ns.Config.frame:Hide(); m:TestScroll() end, keywords = "test sample" }),
    scroll(Opt.Text("scroll.font", "FCT_SCROLL_FONT", { min = 10, max = 40 })),
    scroll({ type = "toggle", key = "scroll.merge", label = "FCT_MERGE", desc = "FCT_MERGE_DESC", keywords = "merge spam combine hits" }),
    scroll({ type = "select", key = "scroll.crit", label = "FCT_CRIT", desc = "FCT_CRIT_DESC", values = CRIT, keywords = "critical crit" }),
    { type = "header", label = "FCT_AREA_HEADER", icon = "layout" },
    scroll({ type = "toggle", key = "scroll.areas.@.show", label = "FCT_AREA_SHOW", desc = "FCT_AREA_SHOW_DESC" }),
    scroll({ type = "range", key = "scroll.areas.@.x", label = "OFFSET_X", min = -800, max = 800, step = 10 }),
    scroll({ type = "range", key = "scroll.areas.@.y", label = "OFFSET_Y", min = -500, max = 500, step = 10 }),
    scroll({ type = "range", key = "scroll.areas.@.height", label = "FCT_AREA_HEIGHT", min = 60, max = 500, step = 10 }),
    scroll({ type = "select", key = "scroll.areas.@.dir", label = "FCT_AREA_DIR", values = DIRS, keywords = "direction up down" }),
})
