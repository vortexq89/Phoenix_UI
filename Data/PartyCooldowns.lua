local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.PartyCooldownData: curated party cooldowns for the party cooldown
-- tracker (Phoenix_UI_RaidFrames/PartyCD.lua). Phoenix's own table:
-- spell ID -> { class, cd seconds, category }. Categories: interrupt,
-- defensive, raid (group defensives), offensive, brez, lust. Durations are the
-- base cooldowns (talents that shorten them are not modelled).
local D = { spells = {}, byClass = {}, base = {} }
PUI.PartyCooldownData = D
D.CATEGORIES = { "interrupt", "defensive", "raid", "offensive", "brez", "lust" }

-- add(class, category, { id, cd, id, cd, ... }): separate spells.
local function add(class, cat, list)
  for i = 1, #list, 2 do
    local id, cd = list[i], list[i + 1]
    D.spells[id] = { class = class, cd = cd, cat = cat }
    D.base[id] = id
    D.byClass[class] = D.byClass[class] or {}
    table.insert(D.byClass[class], id)
  end
end
-- ranks(class, category, cd, { rank IDs }): one spell; every rank shares the first ID's icon slot.
local function ranks(class, cat, cd, ids)
  add(class, cat, { ids[1], cd })
  for i = 2, #ids do D.spells[ids[i]] = { class = class, cd = cd, cat = cat }; D.base[ids[i]] = ids[1] end
end

if PUI.IS_RETAIL then
  add("ROGUE", "interrupt", { 1766, 15 })
  add("WARRIOR", "interrupt", { 6552, 15 })
  add("DEATHKNIGHT", "interrupt", { 47528, 15 })
  add("PALADIN", "interrupt", { 96231, 15 })
  add("MAGE", "interrupt", { 2139, 24 })
  add("SHAMAN", "interrupt", { 57994, 12 })
  add("DRUID", "interrupt", { 106839, 15, 78675, 60 })
  add("HUNTER", "interrupt", { 147362, 24, 187707, 15 })
  add("MONK", "interrupt", { 116705, 15 })
  add("DEMONHUNTER", "interrupt", { 183752, 15 })
  add("EVOKER", "interrupt", { 351338, 40 })
  add("PRIEST", "interrupt", { 15487, 45 })
  add("MAGE", "defensive", { 45438, 240 })
  add("PALADIN", "defensive", { 642, 300, 498, 60 })
  add("ROGUE", "defensive", { 31224, 120, 5277, 120 })
  add("DEATHKNIGHT", "defensive", { 48792, 180, 48707, 60 })
  add("DRUID", "defensive", { 61336, 180, 22812, 60 })
  add("HUNTER", "defensive", { 186265, 180 })
  add("SHAMAN", "defensive", { 108271, 120 })
  add("MONK", "defensive", { 115203, 360 })
  add("DEMONHUNTER", "defensive", { 198589, 60 })
  add("EVOKER", "defensive", { 363916, 90 })
  add("WARRIOR", "defensive", { 871, 180 })
  add("PRIEST", "defensive", { 47585, 120 })
  add("WARLOCK", "defensive", { 104773, 180 })
  add("WARRIOR", "raid", { 97462, 180 })
  add("PALADIN", "raid", { 31821, 180 })
  add("SHAMAN", "raid", { 98008, 180 })
  add("PRIEST", "raid", { 62618, 180, 64843, 180 })
  add("DRUID", "raid", { 740, 180 })
  add("MONK", "raid", { 115310, 180 })
  add("DEMONHUNTER", "raid", { 196718, 300 })
  add("DEATHKNIGHT", "raid", { 51052, 120 })
  add("EVOKER", "raid", { 363534, 240 })
  add("PALADIN", "offensive", { 31884, 120 })
  add("MAGE", "offensive", { 190319, 120, 12472, 120, 365350, 90 })
  add("WARRIOR", "offensive", { 1719, 90, 107574, 90 })
  add("DEATHKNIGHT", "offensive", { 51271, 60, 63560, 45 })
  add("HUNTER", "offensive", { 288613, 120, 19574, 90 })
  add("DRUID", "offensive", { 194223, 180, 106951, 180 })
  add("SHAMAN", "offensive", { 114050, 180 })
  add("ROGUE", "offensive", { 121471, 90, 13750, 180 })
  add("DEMONHUNTER", "offensive", { 191427, 180 })
  add("EVOKER", "offensive", { 375087, 120 })
  add("WARLOCK", "offensive", { 1122, 180, 265187, 90 })
  add("PRIEST", "offensive", { 10060, 120, 228260, 120 })
  add("MONK", "offensive", { 137639, 90, 123904, 120 })
  add("DRUID", "brez", { 20484, 600 })
  add("DEATHKNIGHT", "brez", { 61999, 600 })
  add("WARLOCK", "brez", { 20707, 600 })
  add("PALADIN", "brez", { 391054, 600 })
  add("SHAMAN", "lust", { 2825, 300, 32182, 300 })
  add("MAGE", "lust", { 80353, 300 })
  add("EVOKER", "lust", { 390386, 300 })
else
  -- WoW Forever (1.x): ranked spells share one slot.
  ranks("ROGUE", "interrupt", 10, { 1766, 1767, 1768, 1769 })
  ranks("WARRIOR", "interrupt", 10, { 6552, 6554 })
  ranks("WARRIOR", "interrupt", 12, { 72, 1671, 1672 })
  add("MAGE", "interrupt", { 2139, 30 })
  ranks("SHAMAN", "interrupt", 6, { 8042, 8044, 8045, 8046, 10412, 10413, 10414 })
  add("MAGE", "defensive", { 11958, 300 })
  ranks("PALADIN", "defensive", 300, { 642, 1020 })
  ranks("PALADIN", "defensive", 300, { 1022, 5599, 10278 })
  ranks("PALADIN", "defensive", 3600, { 633, 2800, 10310 })
  add("ROGUE", "defensive", { 5277, 300 })
  ranks("ROGUE", "defensive", 300, { 1856, 1857 })
  add("WARRIOR", "defensive", { 871, 1800 })
  add("PRIEST", "defensive", { 6346, 30 })
  ranks("DRUID", "raid", 300, { 740, 8918, 9862, 9863 })
  add("DRUID", "offensive", { 29166, 360 })
  add("WARRIOR", "offensive", { 1719, 1800 })
  add("MAGE", "offensive", { 12042, 180, 11129, 180 })
  add("ROGUE", "offensive", { 13750, 300, 13877, 120 })
  ranks("DRUID", "brez", 1800, { 20484, 20739, 20742, 20747, 20748 })
end

-- Per class, the spells shown before they are first seen (one interrupt).
D.ALWAYS = {}
for class, list in pairs(D.byClass) do
  for _, id in ipairs(list) do
    if not D.ALWAYS[class] and D.spells[id].cat == "interrupt" then D.ALWAYS[class] = id end
  end
end
