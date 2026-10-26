local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Wisdom.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local WI = ns.WI

local function enable(t)
  local saved = { Schema:Get("module.Wisdom"), Schema:Get("wisdom.weights") }
  t:cleanup(function() Schema:Set("wisdom.weights", saved[2]); Schema:Set("module.Wisdom", saved[1]); wipe(H.itemStats); wipe(H.equipped) end)
  Schema:Set("module.Wisdom", true)
end

Tests:Add("Wisdom", "off by default; pack is dated and ships no invented weights", function(t)
  t:eq(Schema:Def("module.Wisdom").default, false, "module defaults off")
  for key, def in pairs(WI.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  local pack = PUI.Packs.list.wisdom
  t:ok(pack.packVersion and pack.gameBuild, "pack stamped")
  t:eq(next(ns.PACK.specs), nil, "no spec weights shipped")
end)

Tests:Add("Wisdom", "item level fallback, weights, import/export, tooltip line", function(t)
  if not H then return end
  enable(t)
  Schema:Set("wisdom.weights", {})
  H.itemStats["new"] = { ilvl = 650, ITEM_MOD_CRIT_RATING_SHORT = 100, ITEM_MOD_INTELLECT_SHORT = 50 }
  H.itemStats["old"] = { ilvl = 640, ITEM_MOD_CRIT_RATING_SHORT = 10, ITEM_MOD_INTELLECT_SHORT = 80 }
  H.equipped[1] = "old"
  local d, mode = WI.Compare("new")
  t:eq(mode, "ilvl", "no weights: item level")
  t:eq(d, 10, "ten levels up")
  t:ok(WI.IsUpgrade("new"), "upgrade")
  t:eq(WI.Import("( Pawn: v1: \"Mine\": CritRating=1, Intellect=2, Bogus=5 )"), 2, "two known stats imported")
  d, mode = WI.Compare("new")
  t:eq(mode, "weights", "weights used once set")
  t:eq(d, (100 + 100) - (10 + 160), "weighted delta")
  t:ok(WI.Export():find("CritRating=1", 1, true), "export lists weights")
  t:eq(WI.Import("nonsense"), nil, "bad scale string refused")
  local line = WI.TooltipLine("new")
  t:ok(line and line:find("Phoenix score", 1, true), "tooltip line")
  local tip = CreateFrame("GameTooltip")
  rawset(tip, "GetItem", function() return "x", "new" end)
  H.tooltipCalls[Enum.TooltipDataType.Item](tip)
  t:ok(tip.lines and tip.lines[#tip.lines]:find("Phoenix", 1, true), "tooltip hook adds the line")
end)
