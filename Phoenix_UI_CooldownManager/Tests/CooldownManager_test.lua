local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the Cooldown Manager.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local CDM = ns.CDM

local function enable(t, ...)
  local keys = { "module.CooldownManager", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end end)
  Schema:Set("module.CooldownManager", true)
end

Tests:Add("CooldownManager", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.CooldownManager").default, false, "module defaults off")
  local n = 0
  for key, def in pairs(CDM.schema) do n = n + 1; t:eq(type(def.apply), "function", key .. " apply") end
  t:ok(n >= 21, "keys registered (" .. n .. ")")
  if not Schema:Get("module.CooldownManager") then t:eq(CDM.active, false, "inactive") end
end)

Tests:Add("CooldownManager", "grid offsets wrap rows and mirror for left growth", function(t)
  local c = { size = 40, perRow = 2, spacing = 2, growth = "right" }
  t:same({ CDM.Offset(c, 3) }, { 0, -42 }, "third icon starts row 2")
  c.growth = "left"
  t:same({ CDM.Offset(c, 2) }, { -42, 0 }, "left growth mirrors x")
  t:same({ CDM.Offset({ size = 200, perRow = 1, spacing = 2 }, 2, true) }, { 0, -22 }, "bars stack by bar height")
end)

Tests:Add("CooldownManager", "Blizzard viewer frames are re-anchored after Blizzard's layout", function(t)
  if not H then return end
  enable(t, "cdm.essential.perRow")
  local items = H.cdItems.EssentialCooldownViewer
  t:eq(items[3].point[2], CDM.anchors.essential, "anchored to the Phoenix row")
  t:same({ items[3].point[4], items[3].point[5] }, { 0, 0 }, "lowest layoutIndex first")
  Schema:Set("cdm.essential.perRow", 1)
  t:same({ items[1].point[4], items[1].point[5] }, { 0, -84 }, "per-row applies live")
  EssentialCooldownViewer:RefreshLayout()
  t:eq(items[1].point[2], CDM.anchors.essential, "post-hook re-places after a Blizzard refresh")
  local before = H.cdRefreshed or 0
  Schema:Set("module.CooldownManager", false)
  t:ok((H.cdRefreshed or 0) > before, "disable hands layout back to Blizzard")
end)

Tests:Add("CooldownManager", "presets and the !PUI_CDM share string", function(t)
  enable(t, "cdm.preset", "cdm.utility.enabled", "cdm.buffBar.enabled", "cdm.essential.size")
  Schema:Set("cdm.preset", "minimal")
  t:eq(Schema:Get("cdm.utility.enabled"), false, "minimal turns utility off")
  Schema:Set("cdm.preset", "everything")
  t:eq(Schema:Get("cdm.buffBar.enabled"), true, "everything turns buff bars on")
  Schema:Set("cdm.essential.size", 50)
  local str = CDM.Export()
  t:eq(str:sub(1, 8), "!PUI_CDM", "prefix")
  Schema:Set("cdm.essential.size", 30)
  local n = CDM.Import(str)
  t:ok(n and n >= 20, "settings imported (" .. tostring(n) .. ")")
  t:eq(Schema:Get("cdm.essential.size"), 50, "value restored from the string")
  t:eq(CDM.Import("!PUI_UF" .. str), nil, "foreign strings refused")
end)
