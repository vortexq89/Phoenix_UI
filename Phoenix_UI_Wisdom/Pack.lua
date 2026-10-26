local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Wisdom data pack (PUI_V2 9). Stat names Phoenix understands and the item
-- stat keys the game returns for them. Community weights per spec belong in
-- `specs` as { [specID] = { source = "", date = "", weights = { Stat = n } } };
-- this pack ships none rather than invent numbers: until a dated community
-- set is added or imported, Wisdom compares item level and the user's own
-- weights only.
local _, ns = ...
ns.PACK = PUI.Packs:Register("wisdom", {
  packVersion = "2026-10-26", gameBuild = "12.1.5", flavor = "any",
  data = {
    stats = {
      Strength = "ITEM_MOD_STRENGTH_SHORT", Agility = "ITEM_MOD_AGILITY_SHORT", Intellect = "ITEM_MOD_INTELLECT_SHORT",
      Stamina = "ITEM_MOD_STAMINA_SHORT", CritRating = "ITEM_MOD_CRIT_RATING_SHORT", HasteRating = "ITEM_MOD_HASTE_RATING_SHORT",
      MasteryRating = "ITEM_MOD_MASTERY_RATING_SHORT", Versatility = "ITEM_MOD_VERSATILITY",
      Avoidance = "ITEM_MOD_CR_AVOIDANCE_SHORT", Leech = "ITEM_MOD_CR_LIFESTEAL_SHORT", MovementSpeed = "ITEM_MOD_CR_SPEED_SHORT",
    },
    -- Equip location -> inventory slots it can go in (two for rings/trinkets/one-hand).
    slots = {
      INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
      INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
      INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
      INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
      INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
    },
    specs = {},
  },
})
