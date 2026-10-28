local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.ItemBarData: curated item IDs for the auto-filled item bars
-- (Phoenix_UI_ActionBars/ItemBars.lua). The bars first sort bag items by the
-- game's own item class (consumable subclasses); this table settles what the
-- class alone cannot tell apart (healing vs combat potions, healthstones,
-- augment runes) and pins well-known items. Plain data, Phoenix's own list.
local D = {}
PUI.ItemBarData = D

-- Consumable subclass -> category (C_Item.GetItemInfoInstant classID 0).
D.CONSUMABLE = { [1] = "combat", [2] = "flask", [3] = "flask", [5] = "food", [6] = "oil" }
D.CLASS_CONSUMABLE, D.CLASS_QUEST = 0, 12

local function add(cat, flavor, ids)
  for _, id in ipairs(ids) do
    if flavor == "any" or (flavor == "retail") == (PUI.IS_RETAIL == true) then D.byId[id] = cat end
  end
end
D.byId = {}

-- Healthstones and healing potions (both flavors share the classic potion IDs).
add("healing", "any", { 5512, 5511, 5509, 5510, 9421, 19004, 19005, 19006, 19007, 19008, 19009, 19010, 19011, 19012, 19013,
  118, 858, 929, 1710, 3928, 13446, 4596, 18839 })
add("healing", "retail", { 224464, 211878, 211879, 211880, 212242, 212243, 212244, 191378, 191379, 191380, 207023, 207021, 207022 })
-- Augment runes (retail only; WoW Forever has none).
add("rune", "retail", { 224572, 201325, 190384, 181468 })
-- Weapon oils and sharpening/weight stones that the item class misses.
add("oil", "any", { 20744, 20745, 20746, 20747, 20748, 20749, 20750, 2862, 2863, 2871, 3239, 3240, 3241, 7964, 7965, 12404, 12643, 18262 })
-- Flasks (classic) pinned in case the client files them under elixirs.
add("flask", "any", { 13510, 13511, 13512, 13513, 13506 })

-- Battle-res spells by class. Retail: one spell; Forever: Rebirth ranks (druid only).
D.BREZ = PUI.IS_RETAIL and { DRUID = { 20484 }, DEATHKNIGHT = { 61999 }, WARLOCK = { 20707 }, PALADIN = { 391054 } }
  or { DRUID = { 20748, 20747, 20742, 20739, 20484 } }
D.BREZ_SHARED = 20484 -- the spell the game reports pooled charges on

-- Sample items for the Options preview (icons only).
D.SAMPLE = { flask = 13510, food = 2287, combat = 5634, healing = 5512, rune = 224572, oil = 20749, trinket = 19950,
  gear = 10587, quest = 6948, custom = 6948, brez = 20484 }
