local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Vault.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local VA = ns.VA

local function enable(t, ...)
  local keys = { "module.Vault", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; wipe(H.items) end)
  Schema:Set("module.Vault", true)
end

Tests:Add("Vault", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.Vault").default, false, "module defaults off")
  for key, def in pairs(VA.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.Vault") then t:eq(VA.frame, nil, "no window while off") end
end)

Tests:Add("Vault", "real container buttons per bag, grid, item level, free slots", function(t)
  if not H then return end
  H.items["0:1"] = { iconFileID = 1, stackCount = 1, quality = 4, hyperlink = "x", itemID = 900 }
  H.items["1:2"] = { iconFileID = 2, stackCount = 5, quality = 0, itemID = 1 }
  enable(t, "vault.columns")
  t:eq(#VA.buttons[0], 4, "backpack slots")
  t:eq(VA.buttons[0][1].template, "ContainerFrameItemButtonTemplate", "Blizzard's secure slot template")
  t:eq(VA.holders[1]:GetID(), 1, "holder ID is the bag ID")
  VA.Open()
  t:same({ VA.count, VA.free }, { 2, 4 }, "used and free slots")
  t:eq(VA.ilvlText[VA.buttons[0][1]]:GetText(), "645", "item level on gear")
  t:eq(VA.Junk(), 1, "junk counted")
  Schema:Set("vault.columns", 6)
  t:eq(VA.frame:GetWidth(), 16 + 6 * 39, "columns apply live")
  Schema:Set("module.Vault", false)
  t:eq(VA.frame:IsShown(), false, "closed when turned off")
end)

Tests:Add("Vault", "bag keys toggle the Vault and hide Blizzard bags", function(t)
  if not H then return end
  enable(t)
  ContainerFrameCombinedBags:Show()
  ToggleAllBags()
  H.step()
  t:eq(VA.open, true, "opened")
  t:eq(ContainerFrameCombinedBags:IsShown(), false, "Blizzard bags hidden")
  ToggleBackpack(); CloseAllBags()
  H.step()
  t:eq(VA.open, false, "toggle closes even when Blizzard calls CloseAllBags inside")
  OpenAllBags()
  H.step()
  t:eq(VA.open, true, "merchant open")
  CloseAllBags()
  H.step()
  t:eq(VA.open, false, "close")
end)
