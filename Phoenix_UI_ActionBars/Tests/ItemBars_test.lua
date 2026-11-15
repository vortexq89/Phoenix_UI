local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the auto item bars (ItemBars.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local IB = ns.ItemBars

local function enable(t, ...)
  local keys = { "module.ActionBars", "ab.ibars.categories", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.ActionBars", true)
  CQ.Drain()
end

-- Bag fixture: slot -> item ID, with item classes, counts and spells.
local function bags(t, list)
  local saved = { bags = H.bags, items = H.items, counts = {}, spells = {} }
  for _, e in ipairs(list) do saved.counts[e.id] = H.itemCounts[e.id]; saved.spells[e.id] = H.itemSpells[e.id] end
  H.bags, H.items, H.itemClass = { [0] = #list, 0, 0, 0, 0, 0 }, {}, H.itemClass or {}
  for slot, e in ipairs(list) do
    H.items["0:" .. slot] = { itemID = e.id }
    if e.class then H.itemClass[e.id] = { class = e.class, sub = e.sub } end
    H.itemCounts[e.id] = e.n or 1
    if e.spell then H.itemSpells[e.id] = 1 end
  end
  t:cleanup(function()
    for _, e in ipairs(list) do H.itemClass[e.id] = nil; H.itemCounts[e.id] = saved.counts[e.id]; H.itemSpells[e.id] = saved.spells[e.id] end
    H.bags, H.items = saved.bags, saved.items
  end)
end

local function only(bar, cats)
  local g = {}
  for _, c in ipairs(IB.Categories()) do
    g[c.id] = {}
    for i = 1, IB.NUM do g[c.id]["bar" .. i] = i == bar and cats[c.id] == true end
  end
  Schema:Set("ab.ibars.categories", g)
end

Tests:Add("ItemBars", "every auto item bar setting is in the schema with a label, tooltip and live apply", function(t)
  local n = 0
  for k, def in pairs(IB.schema) do
    n = n + 1
    local d = Schema:Def(k)
    t:ok(d and type(d.apply) == "function" and d.label and d.tooltip and (d.mode == "simple" or d.mode == "advanced"), k)
  end
  t:ok(n >= 3 + 12 * IB.NUM, "keys (" .. n .. ")")
  t:ok(PUI.Layout:Element("ab.ibar1") ~= nil, "bars can be moved in Studio")
end)

Tests:Add("ItemBars", "categories follow the game flavor (no augment runes on WoW Forever)", function(t)
  local hasRune = false
  for _, c in ipairs(IB.Categories()) do if c.id == "rune" then hasRune = true end end
  t:eq(hasRune, PUI.IS_RETAIL == true, "augment runes only on retail")
  t:ok(Schema:Validate(Schema:Def("ab.ibars.categories"), IB.DEFAULT_GRID()), "default grid is valid on this flavor")
end)

Tests:Add("ItemBars", "classifies by curated ID first, then item class and subclass", function(t)
  if not H then return end
  H.itemClass = H.itemClass or {}
  H.itemClass[90001] = { class = 0, sub = 3 }
  H.itemClass[90002] = { class = 0, sub = 5 }
  H.itemClass[90003] = { class = 0, sub = 1 }
  H.itemClass[90004] = { class = 0, sub = 6 }
  H.itemClass[90005] = { class = 12, sub = 0 }
  H.itemClass[90006] = { class = 15, sub = 0 }
  H.itemSpells[90005] = 1
  t:cleanup(function() for id = 90001, 90006 do H.itemClass[id] = nil end; H.itemSpells[90005] = nil end)
  t:eq(IB.Classify(5512), "healing", "healthstone from the curated table")
  t:eq(IB.Classify(90001), "flask", "flask subclass")
  t:eq(IB.Classify(90002), "food", "food subclass")
  t:eq(IB.Classify(90003), "combat", "other potions are combat potions")
  t:eq(IB.Classify(90004), "oil", "item enhancement")
  t:eq(IB.Classify(90005), "quest", "usable quest item")
  t:eq(IB.Classify(90006), nil, "everything else stays off")
end)

Tests:Add("ItemBars", "a bar fills itself from bags and gear with secure item buttons", function(t)
  if not H then return end
  enable(t, "ab.ibar1.enabled", "ab.ibar2.enabled", "ab.ibar3.enabled", "ab.ibar1.sort")
  bags(t, { { id = 90011, class = 0, sub = 3, n = 3 }, { id = 90012, class = 0, sub = 5, n = 20 }, { id = 5512, n = 1 },
    { id = 90013, class = 15, sub = 0 } })
  H.inventory[13], H.itemSpells[777] = 777, 1
  t:cleanup(function() H.inventory[13] = nil; H.itemSpells[777] = nil end)
  Schema:Set("ab.ibar2.enabled", false); Schema:Set("ab.ibar3.enabled", false)
  only(1, { flask = true, food = true, trinket = true })
  Schema:Set("ab.ibar1.enabled", true)
  CQ.Drain()
  local bar = IB.bars[1]
  t:eq(bar.n, 3, "flask + food + trinket (healthstone and junk left out)")
  t:eq(bar.buttons[1]:GetAttribute("type"), "item", "secure item button")
  t:eq(bar.buttons[1]:GetAttribute("item"), "item:90011", "flask first (category order)")
  t:eq(bar.buttons[2]:GetAttribute("item"), "item:90012", "then food")
  t:eq(bar.buttons[3]:GetAttribute("item"), "13", "trinket by inventory slot")
  t:eq(bar.buttons[1].count:GetText(), "3", "count shown")
  Schema:Set("ab.ibar1.sort", "count"); CQ.Drain()
  t:eq(bar.buttons[1]:GetAttribute("item"), "item:90012", "most carried first")
  t:ok(H.stateDrivers[bar.header].visibility:find("[petbattle]", 1, true), "secure visibility driver")
end)

Tests:Add("ItemBars", "bag changes in combat wait for combat to end", function(t)
  if not H then return end
  enable(t, "ab.ibar1.enabled", "ab.ibar2.enabled", "ab.ibar3.enabled")
  bags(t, { { id = 90021, class = 0, sub = 5, n = 2 } })
  Schema:Set("ab.ibar2.enabled", false); Schema:Set("ab.ibar3.enabled", false)
  only(1, { food = true })
  Schema:Set("ab.ibar1.enabled", true)
  CQ.Drain()
  t:eq(IB.bars[1].n, 1, "one food")
  H.inCombat = true
  t:cleanup(function() H.inCombat = false end)
  H.items["0:2"] = { itemID = 90022 }; H.bags[0] = 2
  H.itemClass[90022] = { class = 0, sub = 5 }; H.itemCounts[90022] = 1
  t:cleanup(function() H.itemClass[90022] = nil; H.itemCounts[90022] = nil end)
  IB.ApplyAll()
  t:eq(IB.bars[1].n, 1, "not rebuilt in combat")
  H.inCombat = false
  CQ.Drain()
  t:eq(IB.bars[1].n, 2, "rebuilt after combat")
end)

Tests:Add("ItemBars", "battle res button only for classes that have one, with shared charges", function(t)
  if not H then return end
  enable(t, "ab.ibar1.enabled", "ab.ibar2.enabled", "ab.ibar3.enabled", "ab.ibars.brezCharges")
  bags(t, {})
  Schema:Set("ab.ibar2.enabled", false); Schema:Set("ab.ibar3.enabled", false)
  only(1, { brez = true })
  local class = H.class
  t:cleanup(function() H.class = class; H.known[20484] = nil; H.charges = nil end)
  H.class = "MAGE"
  Schema:Set("ab.ibar1.enabled", true); CQ.Drain()
  t:eq(IB.bars[1].n, 0, "mage: no battle res")
  t:eq(H.stateDrivers[IB.bars[1].header].visibility, "hide", "empty bar hidden")
  if not PUI.IS_RETAIL then return end
  H.class, H.known[20484], H.charges = "DRUID", true, { 2, 5 }
  IB.ApplyAll(); CQ.Drain()
  local b = IB.bars[1].buttons[1]
  t:eq(IB.bars[1].n, 1, "druid: Rebirth")
  t:eq(b:GetAttribute("type"), "spell", "secure spell button")
  t:eq(b:GetAttribute("spell"), 20484, "Rebirth")
  t:eq(b.count:GetText(), "2", "shared charges")
end)

Tests:Add("ItemBars", "grow direction, size and visibility rules apply live", function(t)
  local p, x, y = IB.Offset(3, 2, 30, 2, "RIGHT")
  t:eq(p .. x .. "," .. y, "TOPLEFT0,-32", "right: wraps to a new row")
  p, x, y = IB.Offset(2, 4, 30, 2, "LEFT")
  t:eq(p .. x .. "," .. y, "TOPRIGHT-32,0", "left")
  p, x, y = IB.Offset(2, 4, 30, 2, "UP")
  t:eq(p .. x .. "," .. y, "BOTTOMLEFT0,32", "up")
  if not H then return end
  enable(t, "ab.ibar1.enabled", "ab.ibar1.size", "ab.ibar1.show", "ab.ibar1.mouseover")
  bags(t, { { id = 90031, class = 0, sub = 5, n = 2 } })
  only(1, { food = true })
  Schema:Set("ab.ibar1.enabled", true); CQ.Drain()
  Schema:Set("ab.ibar1.size", 40); CQ.Drain()
  t:eq(IB.bars[1].buttons[1]:GetWidth(), 40, "size live")
  Schema:Set("ab.ibar1.show", { mode = "when", combat = "in" }); CQ.Drain()
  t:ok(H.stateDrivers[IB.bars[1].header].visibility:find("[nocombat] hide", 1, true), "combat-only rule in the secure driver")
  Schema:Set("ab.ibar1.mouseover", true); CQ.Drain()
  t:eq(IB.bars[1].header:GetAlpha(), 0.3, "faded until mouse-over")
end)

Tests:Add("ItemBars", "Mythic+ teleports the player knows and hearthstones (items and toys)", function(t)
  if not H then return end
  enable(t, "ab.ibar1.enabled", "ab.ibar2.enabled", "ab.ibar3.enabled", "ab.ibars.seasonOnly", "ab.ibars.hearthToys")
  bags(t, { { id = 6948, n = 1 } })
  Schema:Set("ab.ibar2.enabled", false); Schema:Set("ab.ibar3.enabled", false)
  only(1, { teleport = true, hearth = true })
  local toy = rawget(_G, "PlayerHasToy")
  t:cleanup(function() H.known[445417] = nil; rawset(_G, "PlayerHasToy", toy) end)
  rawset(_G, "PlayerHasToy", function(id) return id == 54452 end)
  if PUI.IS_RETAIL then H.known[445417] = true end
  Schema:Set("ab.ibar1.enabled", true); CQ.Drain()
  local bar = IB.bars[1]
  if PUI.IS_RETAIL then
    t:eq(bar.n, 3, "teleport + hearthstone + toy")
    t:eq(bar.buttons[1]:GetAttribute("spell"), 445417, "known teleport as a secure spell")
    t:eq(bar.buttons[3]:GetAttribute("type"), "toy", "hearthstone toy")
    t:eq(bar.buttons[3]:GetAttribute("toy"), 54452, "toy item ID")
    Schema:Set("ab.ibars.seasonOnly", true); CQ.Drain()
    t:eq(bar.n, 2, "teleport outside this season's maps left off")
  else
    t:eq(bar.n, 1, "Forever: the hearthstone only")
  end
  t:eq(bar.buttons[PUI.IS_RETAIL and 1 or 1]:GetAttribute("type") ~= nil, true, "secure type set")
end)
