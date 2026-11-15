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

-- Mythic+ teleports (Hero's Path spells) -> Mythic+ map ID, retail only.
-- Shown when the player knows the spell; "current season only" keeps the
-- ones whose map is in C_ChallengeMode.GetMapTable().
D.TELEPORTS = PUI.IS_RETAIL and {
  [445417] = 503, [445416] = 502, [445414] = 505, [445269] = 501, [445424] = 507, [445444] = 499, [445443] = 500,
  [445441] = 504, [445440] = 506, [1216786] = 525, [445418] = 353, [464256] = 353, [467553] = 247, [467555] = 247,
  [373274] = 370, [354464] = 375, [354462] = 376, [354465] = 378, [354467] = 382, [367416] = 391, [410071] = 245,
  [393764] = 200, [393222] = 403, [424197] = 463, [1237215] = 542,
} or {}
-- Hearthstones: bag items (both flavors) and toys (retail).
D.HEARTH_ITEMS = { 6948, 140192, 110560 }
D.HEARTH_TOYS = PUI.IS_RETAIL and { 54452, 64488, 93672, 142542, 162973, 163045, 165669, 165670, 165802, 166746, 166747, 168907,
  172179, 180290, 182773, 183716, 184353, 188952, 190237, 193588, 200630, 206195, 208704, 209035, 212337, 228940 } or {}

-- Sample items for the Options preview (icons only).
D.SAMPLE = { flask = 13510, food = 2287, combat = 5634, healing = 5512, rune = 224572, oil = 20749, trinket = 19950,
  gear = 10587, quest = 6948, custom = 6948, brez = 20484, teleport = 445417, hearth = 6948 }
