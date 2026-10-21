local _, ns = ...

--[[ CombatText: the combat-log driven scrolling text of 11.x cannot exist in 12.x (COMBAT_LOG_EVENT
    is unavailable to addons). Blizzard's floating combat text v2 is the native replacement; this
    page gathers its CVars in one place. Settings are account CVars, not profile data. ]]
ns:NewModule("CombatText", {
    label = "COMBATTEXT", desc = "COMBATTEXT_DESC", category = "combat", order = 20, locked = true,
})
