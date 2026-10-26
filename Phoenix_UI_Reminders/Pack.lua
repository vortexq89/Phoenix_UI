local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Reminders data pack (PUI_V2 9): spell IDs only, no code. Retail IDs were
-- checked against the 12.1.5 client spell data; the Forever list stays empty
-- until its IDs are verified on that client.
local _, ns = ...
ns.PACK = {
  version = 1,
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
    },
  },
  forever = { raid = {}, class = {} },
}
