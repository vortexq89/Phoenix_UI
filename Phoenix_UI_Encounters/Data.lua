-- © 2026 VortexQ8 / ABDULRAHMAN ALYOUSEF. Phoenix UI. All rights reserved.
local _, ns = ...

--[[ Phoenix boss knowledge: our own, structured, per encounter, for every expansion. The encounter list,
    bosses and ability spell IDs come live from the game's Encounter Journal (Journal.lua), so this file only
    adds what the journal lacks: a default treatment per ability. It is plain data on purpose, so a daily sync
    can add abilities without touching code.

    encounters[journalEncounterID][spellID] = {
        default = "emph" | "sound" | "count" | "hide",   -- applied when you have not chosen one yourself
        role = "all" | "tank" | "healer" | "dps",         -- who it matters for (shown on the Boss modules tab)
    }
    Your own choice (Encounters > Boss modules) always wins over a default here. ]]
ns.EncounterData = {
    schema = 1,
    updated = "2026-10-31",
    encounters = {},
}
