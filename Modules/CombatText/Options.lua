local _, ns = ...
local CVar = ns.Combat.CVarAccessors

-- item = { label, desc, keywords? } for a boolean FCT CVar
local function toggle(cvar, item)
    item.type, item.combat = "toggle", true
    item.get, item.set = CVar(cvar)
    return item
end

local scaleGet, scaleSet = CVar("WorldTextScale_v2", "number")
local modeGet, modeSet = CVar("floatingCombatTextFloatMode_v2", "number")

ns:RegisterOptions("CombatText", {
    { type = "description", text = "FCT_INTRO" },
    { type = "header", label = "FCT_OUTGOING" },
    toggle("floatingCombatTextCombatDamage_v2", { label = "FCT_DAMAGE", desc = "FCT_DAMAGE_DESC", keywords = "numbers sct msbt" }),
    toggle("floatingCombatTextCombatLogPeriodicSpells_v2", { label = "FCT_PERIODIC", desc = "FCT_PERIODIC_DESC", keywords = "dot" }),
    toggle("floatingCombatTextPetMeleeDamage_v2", { label = "FCT_PET", desc = "FCT_PET_DESC" }),
    toggle("floatingCombatTextCombatHealing_v2", { label = "FCT_HEALING", desc = "FCT_HEALING_DESC" }),
    { type = "range", label = "FCT_SCALE", desc = "FCT_SCALE_DESC", min = 0.5, max = 2.5, step = 0.1,
      get = scaleGet, set = scaleSet, combat = true },
    { type = "header", label = "FCT_INCOMING" },
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
})
