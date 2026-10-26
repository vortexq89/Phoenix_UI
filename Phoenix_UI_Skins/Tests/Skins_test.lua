local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Skins engine.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local SK = ns.SK

local function enable(t, ...)
  local keys = { "module.Skins", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module.Skins", true)
  CQ.Drain()
end

Tests:Add("Skins", "25 window packs, each with a live toggle; module off by default", function(t)
  t:eq(#SK.WINDOWS, 25, "25 windows")
  t:eq(Schema:Def("module.Skins").default, false, "module defaults off")
  for key, def in pairs(SK.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.Skins") then t:eq(next(SK.applied), nil, "nothing skinned while off") end
end)

Tests:Add("Skins", "apply fades Blizzard art, reverts exactly; per-window toggle", function(t)
  if not H then return end
  CharacterFrame.NineSlice:SetAlpha(0.9)
  enable(t, "skins.character")
  t:ok(SK.applied.character, "character skinned")
  t:eq(CharacterFrame.NineSlice:GetAlpha(), 0, "border art faded")
  t:eq(CharacterFrame.Inset.Bg:GetAlpha(), 0, "inset art faded")
  t:eq(CharacterFrameTab1.Left:GetAlpha(), 0, "tab art faded")
  t:ok(SK.backdrops[CharacterFrame]:IsShown(), "Phoenix backdrop shown")
  Schema:Set("skins.character", false)
  CQ.Drain()
  t:eq(CharacterFrame.NineSlice:GetAlpha(), 0.9, "original alpha restored")
  t:eq(SK.backdrops[CharacterFrame]:IsShown(), false, "backdrop hidden")
  t:ok(not SK.applied.InspectFrame, "absent windows are skipped")
end)

Tests:Add("Skins", "a failing pack is isolated and reverted; RegisterSkin API", function(t)
  if not H then return end
  enable(t)
  local prev = geterrorhandler()
  local caught
  seterrorhandler(function(msg) caught = msg end)
  t:cleanup(function() seterrorhandler(prev) end)
  PUI.API.RegisterSkin("broken", { frames = { "CharacterFrame" }, parts = {}, extra = function() error("boom") end })
  t:cleanup(function() SK.packs["addon.broken"] = nil; PUI.APIRegistry.skins.broken = nil; table.remove(SK.order) end)
  CQ.Drain()
  t:ok(not SK.applied["addon.broken"], "broken pack not applied")
  t:ok(SK.errors["addon.broken"] ~= nil, "error recorded")
  t:ok(caught and tostring(caught):find("boom", 1, true), "error reached the error handler")
  t:ok(SK.applied.character, "other packs unaffected")
end)

Tests:Add("Skins", "third-party addon packs: skipped when absent, applied when present", function(t)
  if not H then return end
  enable(t)
  CQ.Drain()
  t:ok(not SK.applied.pawn, "Pawn not installed: nothing applied")
  local f = CreateFrame("Frame", "PawnUIFrame", UIParent)
  f.NineSlice = CreateFrame("Frame", nil, f)
  rawset(_G, "PawnUIFrame", f)
  t:cleanup(function() SK.Revert("pawn"); rawset(_G, "PawnUIFrame", nil) end)
  H.fire("ADDON_LOADED", "Pawn")
  CQ.Drain()
  t:ok(SK.applied.pawn, "Pawn skinned after it loads")
  t:eq(f.NineSlice:GetAlpha(), 0, "border faded")
  Schema:Set("skins.pawn", false)
  CQ.Drain()
  t:eq(f.NineSlice:GetAlpha(), 1, "turned off live: reverted")
  Schema:Set("skins.pawn", true)
end)
