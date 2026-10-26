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

-- Step 6 ---------------------------------------------------------------------------
Tests:Add("CooldownManager", "restyle: border in a side table, zoom, numbers; centred rows", function(t)
  if not H then return end
  enable(t, "cdm.border", "cdm.essential.growth", "cdm.cdText")
  local f = H.cdItems.EssentialCooldownViewer[1]
  local sk = CDM.skins[f]
  t:ok(sk and #sk == 4, "four border edges kept outside the Blizzard frame")
  t:eq(rawget(f, "phoenixBorder"), nil, "no fields written on the Blizzard frame")
  Schema:Set("cdm.border", 0)
  t:eq(sk[1]:IsShown(), false, "border 0 hides it live")
  Schema:Set("cdm.essential.growth", "center")
  local x = H.cdItems.EssentialCooldownViewer[3].point[4]
  t:ok(x < 0, "first icon of a centred row starts left of the anchor")
  t:eq(H.cdItems.EssentialCooldownViewer[3].point[1], "TOP", "centred rows anchor at TOP")
  t:eq(Schema:Def("cdm.essential.size").overridable, true, "layout can differ per specialization")
end)

Tests:Add("CooldownManager", "dedupe with action bars, missing-from-bars and tracked buffs", function(t)
  if not H then return end
  enable(t, "cdm.hideOnBars")
  local items = H.cdItems.EssentialCooldownViewer
  rawset(items[1], "GetSpellID", function() return 133 end) -- on slot 62 in the harness
  rawset(items[2], "GetSpellID", function() return 999 end) -- on no bar
  local buff = H.cdItems.BuffIconCooldownViewer[1]
  rawset(buff, "GetSpellID", function() return 4242 end)
  t:cleanup(function() rawset(items[1], "GetSpellID", nil); rawset(items[2], "GetSpellID", nil); rawset(buff, "GetSpellID", nil) end)
  local missing = CDM.MissingFromBars()
  t:eq(#missing, 1, "one tracked cooldown is on no bar")
  t:eq(missing[1], 999, "the right one")
  t:eq(#CDM.Items(EssentialCooldownViewer), 3, "dedupe off keeps every icon")
  Schema:Set("cdm.hideOnBars", true)
  t:eq(#CDM.Items(EssentialCooldownViewer), 2, "icon already on a bar left out")
  t:eq(items[1]:GetAlpha(), 0, "left-out icon is alpha 0 (never hidden or reparented)")
  Schema:Set("cdm.hideOnBars", false)
  t:eq(items[1]:GetAlpha(), 1, "restored when the setting is off")
  local tracked = CDM.TrackedBuffSpellIDs()
  t:eq(tracked[1], 4242, "tracked buff ids for the Player Aura Bars dedupe")
  H.secretMode = true
  rawset(items[2], "GetSpellID", function() return H.secret(999) end)
  t:eq(#CDM.MissingFromBars(), 0, "a secret spell id is never compared")
  H.secretMode = false
end)

Tests:Add("CooldownManager", "custom bar shows the shared item list (display only)", function(t)
  if not H then return end
  enable(t, "cdm.custom.enabled", "items.list")
  Schema:Set("cdm.custom.enabled", true)
  t:ok(CDM.customFrame and CDM.customFrame:IsShown(), "custom bar shown")
  t:eq(CDM.custom[1].icon.texture, 1000 + 5512, "first item from PUI.ItemList")
  t:eq(CDM.custom[1].count:GetText(), "2", "count")
  t:eq(rawget(CDM.custom[1], "secure"), nil, "not a secure (clickable) frame")
  Schema:Set("items.list", { "211880" })
  t:eq(CDM.custom[1]:IsShown(), false, "list change applies live (missing item hidden)")
end)
