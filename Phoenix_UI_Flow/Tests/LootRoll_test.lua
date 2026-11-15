local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the loot roll list (LootRoll.lua).
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local LR = PUI.LootRoll

Tests:Add("LootRoll", "settings have labels, tooltips and live apply", function(t)
  for k in pairs(LR.schema) do
    local d = Schema:Def(k)
    t:ok(d and type(d.apply) == "function" and d.label and d.tooltip, k)
  end
  t:ok(PUI.Layout:Element("loot.rolls") ~= nil, "movable in Studio")
end)

Tests:Add("LootRoll", "a roll shows item level, only allowed choices, rolls on click and leaves on cancel", function(t)
  if not H then return end
  local saved = Schema:Get("module.LootRoll")
  t:cleanup(function() wipe(H.lootRolls); wipe(H.rolled); Schema:Set("module.LootRoll", saved) end)
  Schema:Set("module.LootRoll", true)
  H.lootRolls[7] = { tex = 1, name = "Helm", quality = 4, need = true, greed = true, transmog = false, link = "item:7", left = 30000 }
  H.itemStats["item:7"] = { ilvl = 639 }
  t:cleanup(function() H.itemStats["item:7"] = nil end)
  H.fire("START_LOOT_ROLL", 7, 60000)
  local r = LR.rows[1]
  t:eq(r.rollID, 7, "row for the roll")
  t:eq(r.ilvl:GetText(), "639", "item level")
  t:eq(r.btn[1]:IsShown(), true, "need allowed")
  t:eq(r.btn[3]:IsShown(), false, "transmog not offered")
  t:ok(PUI.Ticker:IsRegistered("loot.timer"), "timer on one Ticker entry while a roll is open")
  t:eq(r.bar:GetValue(), 0.5, "timer half drained")
  r.btn[1]:GetScript("OnClick")(r.btn[1])
  t:eq(H.rolled[1] and H.rolled[1][2], 1, "need rolled")
  H.fire("CANCEL_LOOT_ROLL", 7)
  t:eq(#LR.order, 0, "roll removed")
  t:eq(PUI.Ticker:IsRegistered("loot.timer"), false, "timer gone with the last roll")
end)

Tests:Add("LootRoll", "Blizzard roll frames are parked unless kept; sample rolls for testing", function(t)
  if not H then return end
  local c = CreateFrame("Frame", "GroupLootContainer", UIParent)
  rawset(_G, "GroupLootContainer", c)
  local keys = { "module.LootRoll", "loot.keepBlizzard" }
  local saved = { Schema:Get(keys[1]), Schema:Get(keys[2]) }
  t:cleanup(function() LR.ClearTest(); Schema:Set(keys[2], saved[2]); Schema:Set(keys[1], saved[1]); rawset(_G, "GroupLootContainer", nil) end)
  Schema:Set("module.LootRoll", false)
  Schema:Set("module.LootRoll", true)
  t:eq(c:GetParent(), LR.hider, "parked")
  Schema:Set("loot.keepBlizzard", true)
  t:eq(c:GetParent(), UIParent, "kept on request")
  LR.Test()
  t:eq(#LR.order, 3, "three sample rolls")
  LR.ClearTest()
  t:eq(#LR.order, 0, "samples cleared")
end)
