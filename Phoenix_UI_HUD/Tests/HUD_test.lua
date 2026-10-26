local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Minimap, Tooltip and Data Bars.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ, Ticker = PUI.Tests, PUI.Schema, PUI.CombatQueue, PUI.Ticker
local MM, TT, DB = ns.MM, ns.TT, ns.DataBars

local function enable(t, module, ...)
  local keys = { "module." .. module, ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module." .. module, true)
end

Tests:Add("HUD", "all three modules off by default and silent", function(t)
  for _, m in ipairs({ "Minimap", "Tooltip", "DataBars" }) do t:eq(Schema:Def("module." .. m).default, false, m .. " defaults off") end
  if not Schema:Get("module.Minimap") then t:eq(Ticker:IsRegistered("mm.texts"), false, "no minimap ticker") end
  if not Schema:Get("module.DataBars") then
    t:eq(Ticker:IsRegistered("db.update"), false, "no data bar ticker")
    t:eq(next(DB.bars), nil, "no data bar frames while off")
  end
  for _, sc in ipairs({ MM.schema, TT.schema, DB.schema }) do
    for key, def in pairs(sc) do t:eq(type(def.apply), "function", key .. " apply") end
  end
end)

Tests:Add("HUD", "minimap shape, size and cluster apply live and restore", function(t)
  if not H then return end
  local w = Minimap:GetWidth()
  enable(t, "Minimap", "mm.shape", "mm.size", "mm.coords")
  t:eq(Minimap.mask, MM.MASKS.square, "square mask")
  t:eq(Minimap:GetWidth(), 200, "size applied")
  t:eq(MinimapCluster.BorderTop:GetAlpha(), 0, "cluster border alpha-zeroed")
  t:ok(Ticker:IsRegistered("mm.texts"), "text ticker while texts shown")
  Schema:Set("mm.shape", "circle")
  t:eq(Minimap.mask, MM.MASKS.circle, "circle live")
  Schema:Set("mm.coords", true)
  t:eq(MM.texts.coords:GetText(), "50.0, 25.0", "coordinates text")
  Schema:Set("module.Minimap", false)
  t:eq(Minimap:GetWidth(), w, "size restored")
  t:eq(MinimapCluster.BorderTop:GetAlpha(), 1, "cluster restored")
  t:eq(Ticker:IsRegistered("mm.texts"), false, "ticker gone")
end)

Tests:Add("HUD", "tooltip anchor, IDs and player lines; secrets skipped", function(t)
  if not H then return end
  enable(t, "Tooltip", "tt.anchor")
  Schema:Set("tt.anchor", "cursor")
  local tip = CreateFrame("GameTooltip")
  GameTooltip_SetDefaultAnchor(tip, UIParent)
  t:eq(tip.anchor, "ANCHOR_CURSOR", "cursor anchor")
  H.tooltipCalls[Enum.TooltipDataType.Spell](tip, { id = 133 })
  t:eq(tip.lines[1], "Spell ID: 133", "spell ID line")
  H.tooltipCalls[Enum.TooltipDataType.Unit](tip)
  t:eq(tip.lines[2], "<Phoenix> Officer", "guild line")
  t:eq(tip.lines[3], "Mythic+ score: 2500", "M+ score line")
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  local tip2 = CreateFrame("GameTooltip")
  H.tooltipCalls[Enum.TooltipDataType.Unit](tip2)
  H.tooltipCalls[Enum.TooltipDataType.Spell](tip2, { id = H.secret(5) })
  t:eq(rawget(tip2, "lines"), nil, "no line built from a secret")
end)

Tests:Add("HUD", "data bars: blocks, solver and live settings", function(t)
  t:same(DB.Parse("clock, fps,nope,gold"), { "clock", "fps", "gold" }, "unknown blocks dropped")
  local slots = DB.Solve(300, 3)
  t:same({ slots[2].x, slots[2].w }, { 100, 100 }, "equal-width solver")
  if not H then return end
  enable(t, "DataBars", "db.bar1.blocks", "db.bar2.blocks")
  Schema:Set("db.bar1.blocks", "gold,durability,xp,bags")
  local b = DB.bars[1]
  t:eq(b.cells[1]:GetText(), "123g", "gold")
  t:eq(b.cells[2]:GetText(), "Dur 30%", "lowest durability")
  t:eq(b.cells[3]:GetText(), "XP 25%", "xp")
  t:ok(Ticker:IsRegistered("db.update"), "ticker while shown")
  Schema:Set("db.bar2.blocks", "clock")
  t:ok(DB.bars[2]:IsShown(), "second bar appears live")
  Schema:Set("module.DataBars", false)
  t:eq(Ticker:IsRegistered("db.update"), false, "ticker gone when off")
  t:eq(DB.bars[1]:IsShown(), false, "bars hidden when off")
end)
