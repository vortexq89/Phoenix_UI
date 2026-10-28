local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Reminders data pack (PUI_V2 9, plan 5.13): spell IDs only, no code. Version 1
-- IDs were checked against the 12.1.5 client spell data. Version 2 rows marked
-- "verify" still need an in-game check (listed in the step 8c report); season
-- consumables (flask, food, rune, oil) come with the season pack after their
-- IDs are read in game, until then they are custom reminders. The Forever list
-- stays empty until its IDs are verified on that client.
local _, ns = ...
ns.PACK = {
  version = 2,
  retail = {
    raid = {
      { key = "intellect", spell = 1459, class = "MAGE" },
      { key = "stamina", spell = 21562, class = "PRIEST" },
      { key = "attack", spell = 6673, class = "WARRIOR" },
      { key = "versatility", spell = 1126, class = "DRUID" },
      { key = "skyfury", spell = 462854, class = "SHAMAN" },
    },
    class = {
      ROGUE = {
        { key = "lethal", any = { 2823, 315584, 8679, 381664 }, label = "Lethal poison" },
        { key = "nonlethal", any = { 3408, 5761, 381637 }, label = "Non-lethal poison" },
      },
      PALADIN = { -- verify
        { key = "aura", any = { 465, 183435, 32223 }, label = "Paladin aura" },
      },
    },
    -- Classes (and specs that use no pet) for the missing-pet reminder.
    pets = { WARLOCK = { noPetSpecs = {} }, HUNTER = { noPetSpecs = { 2 } } }, -- verify: Marksmanship (2) plays without a pet
    consumables = {},
  },
  forever = { raid = {}, class = {}, pets = {}, consumables = {} },
}
