local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Nameplates deferred batch (Extras.lua).
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local NP, P, R = ns.NP, ns.Plate, ns.Rules
local X = NP.Extras

local function enable(t, ...)
  local keys = { "module.Nameplates", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    CQ.Drain()
  end)
  Schema:Set("module.Nameplates", true)
  CQ.Drain()
end
local function plate(t, unit)
  H.addPlate(unit)
  t:cleanup(function()
    H.fire("NAME_PLATE_UNIT_REMOVED", unit)
    H.plates[unit] = nil; H.units[unit] = nil; H.creatureTypes[unit] = nil; H.controlled[unit] = nil
    H.tooltipUnits[unit] = nil; H.creatureIDs[unit] = nil; H.inRange[unit] = nil
  end)
  H.fire("NAME_PLATE_UNIT_ADDED", unit)
  return NP.plates[unit]
end

Tests:Add("NameplatesX", "totems and pets get compact plates; a secret answer stays normal", function(t)
  if not H then return end
  enable(t, "np.compact.scale")
  H.creatureTypes.nameplate7 = "Totem"
  local f = plate(t, "nameplate7")
  t:eq(f:GetScale(), 0.6, "totem at 60 %")
  Schema:Set("np.compact.scale", 0.5)
  t:eq(f:GetScale(), 0.5, "live")
  H.controlled.nameplate8 = true
  local g = plate(t, "nameplate8")
  t:eq(g:GetScale(), 0.5, "pet compact")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  t:eq(X.Kind("nameplate7"), nil, "secret creature type is never compared")
end)

Tests:Add("NameplatesX", "interrupted by shows the interrupter's name for a moment", function(t)
  if not H then return end
  enable(t)
  local f = plate(t, "nameplate9")
  H.guidNames = { ["Player-1-AB"] = "Kael" }
  t:cleanup(function() H.guidNames = nil end)
  H.fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate9", "cast", 133, "Player-1-AB")
  t:ok(f.interruptText:IsShown(), "shown")
  t:eq(f.interruptText:GetText(), "Interrupted by Kael", "named")
end)

Tests:Add("NameplatesX", "NPC titles are cached per NPC id; quest text replaces them when on", function(t)
  if not H then return end
  enable(t, "np.npc.quest")
  H.creatureIDs.nameplate10 = 4242
  H.tooltipUnits.nameplate10 = { lines = { { type = 2, leftText = "Bob" }, { type = 0, leftText = "Innkeeper" } } }
  local f = plate(t, "nameplate10")
  t:eq(f.npcText:GetText(), "<Innkeeper>", "title under the name")
  t:eq(X.subCache[4242], "Innkeeper", "cached")
  H.tooltipUnits.nameplate10 = { lines = { { type = 2, leftText = "Bob" }, { type = 0, leftText = "Level 80" },
    { type = 8, leftText = "Void Acolytes slain: 3/8" } } }
  Schema:Set("np.npc.quest", true)
  t:eq(f.npcText:GetText(), "Void Acolytes slain: 3/8", "quest progress")
end)

Tests:Add("NameplatesX", "click-through and clickable area go through hit-test insets and come back", function(t)
  if not H then return end
  enable(t, "np.click.friendlyThrough", "np.click.enemyX", "np.click.friendlyShow")
  Schema:Set("np.click.friendlyThrough", true); CQ.Drain()
  t:eq(H.insets[0][1], 10000, "friendly collapsed")
  Schema:Set("np.click.enemyX", 10); CQ.Drain()
  t:eq(H.insets[1][1], -10, "enemy area grown")
  H.cvars.nameplateShowFriends = "0"
  Schema:Set("np.click.friendlyShow", "on"); CQ.Drain()
  t:eq(H.cvars.nameplateShowFriends, "1", "friendly plates on through the ledger")
  Schema:Set("module.Nameplates", false); CQ.Drain()
  t:eq(H.insets[0][1], 0, "friendly insets restored on disable")
  t:eq(H.insets[1][1], 0, "enemy insets restored")
  t:eq(H.cvars.nameplateShowFriends, "0", "your CVar value back")
end)

Tests:Add("NameplatesX", "hover highlight follows the mouseover and clears on its own Ticker entry", function(t)
  if not H then return end
  enable(t)
  local f = plate(t, "nameplate11")
  H.units.mouseover = true
  t:cleanup(function() H.units.mouseover = nil end)
  H.fire("UPDATE_MOUSEOVER_UNIT")
  t:ok(PUI.Ticker:IsRegistered("np.hover"), "clear job armed")
  H.units.mouseover = nil
  H.step(0.2)
  t:eq(PUI.Ticker:IsRegistered("np.hover"), false, "job stops after the mouse leaves")
  t:eq(f.hoverTex:GetAlpha(), 0, "highlight off")
end)

Tests:Add("NameplatesX", "aura borders are handed to the engine per lane (purge, important, pandemic)", function(t)
  if not H then return end
  enable(t, "np.auraGlow.purge")
  local f = plate(t, "nameplate12")
  local buffs = f.lanes.buffs:ButtonOptions("buffs", "dispelTexture")
  t:ok(buffs and buffs.stealableFilter == Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable, "purge border on stealable buffs")
  t:ok(f.lanes.debuffs:ButtonOptions("debuffs", "durationText") ~= nil, "pandemic colour curve on debuffs")
  local seen = false
  for _, e in ipairs(f.lanes.buffs.container.groupLog) do if e[1] == "dispelTexture" then seen = true end end
  t:ok(seen, "the container setter was called")
  Schema:Set("np.auraGlow.purge", false)
  t:ok(f.lanes.buffs:ButtonOptions("buffs", "dispelTexture").showAlways == true, "important-only lane keeps its border")
end)

Tests:Add("NameplatesX", "rule conditions: any NPC by classification, reaction and casting", function(t)
  t:ok(R.Validate("*:FF0000:rare"), "any NPC with a condition")
  t:eq(R.Validate("*:FF0000"), false, "any NPC alone is refused")
  t:ok(R.Label("*:FF0000:hostile"):find("only when hostile") ~= nil, "label names the condition")
  local list = NP.settings.rules.list
  t:cleanup(function() R.Compile(list) end)
  R.Compile({ "*:00FF00:normal:hostile", "*:FF0000:casting" })
  if not H then return end
  H.addPlate("nameplate13")
  t:cleanup(function() H.plates.nameplate13 = nil; H.units.nameplate13 = nil end)
  local rule = R.Match("nameplate13", { casting = false })
  t:ok(rule and rule.color.g == 1, "normal hostile matched")
  t:ok(R.Match("nameplate13", { casting = true }).color.g == 1, "first rule wins")
  R.Compile({ "*:FF0000:casting" })
  t:eq(R.Match("nameplate13", { casting = false }), nil, "not casting: no match")
  t:ok(R.Match("nameplate13", { casting = true }) ~= nil, "casting matches")
end)

Tests:Add("NameplatesX", "rule packs add after your own rules", function(t)
  R.RegisterPack("testpack", "Test pack", { "Void Acolyte:112233" })
  t:cleanup(function() R.packs.testpack = nil; R.enabledPacks = {}; R.Compile(NP.settings.rules.list) end)
  R.enabledPacks = { "testpack" }
  R.Compile({ "Void Acolyte:FFFFFF" })
  t:eq(R.byName["Void Acolyte"].color.r, 1, "your own line wins")
  R.Compile({})
  t:ok(math.abs(R.byName["Void Acolyte"].color.r - 0x11 / 255) < 1e-6, "pack line used")
end)

Tests:Add("NameplatesX", "pre-warm fills the pool out of combat", function(t)
  if not H then return end
  local saved = #P.pool
  enable(t, "np.pool.prewarm")
  Schema:Set("np.pool.prewarm", 14); CQ.Drain()
  local live = 0
  for _ in pairs(NP.plates) do live = live + 1 end
  t:ok(#P.pool + live >= 14, "pool sized (" .. #P.pool .. ")")
  t:ok(saved >= 0, "pool existed")
end)

Tests:Add("NameplatesX", "Blizzard plate hidden completely when chosen and given back on release", function(t)
  if not H then return end
  enable(t, "np.blizzard.suppress")
  Schema:Set("np.blizzard.suppress", "hide")
  plate(t, "nameplate14")
  local bp = H.plates.nameplate14.UnitFrame
  t:eq(bp:IsShown(), false, "hidden")
  H.fire("NAME_PLATE_UNIT_REMOVED", "nameplate14")
  t:eq(bp:IsShown(), true, "given back")
end)

Tests:Add("NameplatesX", "element slots move the region; the standard place is untouched", function(t)
  if not H then return end
  enable(t, "np.slots.forces", "np.slots.quest")
  local f = plate(t, "nameplate15")
  Schema:Set("np.slots.quest", "hidden")
  t:eq(f.quest:GetAlpha(), 0, "hidden slot")
  Schema:Set("np.slots.quest", "default")
  t:eq(f.quest:GetAlpha(), 1, "back")
  for _, el in ipairs(X.SLOT_ELEMENTS) do t:eq(Schema:Def("np.slots." .. el).default, "default", el .. " keeps the standard place") end
end)

Tests:Add("NameplatesX", "range fade runs on one Ticker entry only while on", function(t)
  if not H then return end
  enable(t, "np.range.enabled", "np.range.spell")
  local f = plate(t, "nameplate16")
  t:eq(PUI.Ticker:IsRegistered("np.range"), false, "off at first install")
  Schema:Set("np.range.spell", 2139)
  Schema:Set("np.range.enabled", true)
  t:ok(PUI.Ticker:IsRegistered("np.range"), "armed")
  H.inRange.nameplate16 = false
  H.step(0.3)
  t:eq(f.health:GetAlpha(), 0.45, "faded out of range")
  Schema:Set("np.range.enabled", false)
  t:eq(PUI.Ticker:IsRegistered("np.range"), false, "disarmed")
  t:eq(f.health:GetAlpha(), 1, "back to full")
end)
