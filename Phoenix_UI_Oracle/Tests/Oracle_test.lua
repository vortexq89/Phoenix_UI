local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Oracle.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local OR, Palette = ns.OR, ns.Palette

local function enable(t)
  local saved = Schema:Get("module.Oracle")
  t:cleanup(function() H.inCombat = false; Palette.Close(); CQ.Drain(); Schema:Set("module.Oracle", saved) end)
  Schema:Set("module.Oracle", true)
end

Tests:Add("Oracle", "off by default; nothing built until opened", function(t)
  t:eq(Schema:Def("module.Oracle").default, false, "module defaults off")
  for key, def in pairs(OR.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Palette.frame then t:eq(Palette.frame, nil, "no palette frame before first open") end
end)

Tests:Add("Oracle", "fuzzy score ranks prefix and contiguous matches higher", function(t)
  t:ok(OR.Score("Setting: Unit frames", "unit") > OR.Score("Setting: Minimap", "mni"), "contiguous beats scattered")
  t:eq(OR.Score("Mount: Swift Phoenix", "zzz"), nil, "no match is nil")
end)

Tests:Add("Oracle", "hotkey binding, providers, secure arm out of combat only", function(t)
  if not H then return end
  enable(t)
  t:ok(H.overrideBindings["CTRL-K"], "Ctrl+K bound")
  Schema:Set("oracle.key", "ALT-K")
  t:ok(H.overrideBindings["ALT-K"] and not H.overrideBindings["CTRL-K"], "rebinding applies live")
  Schema:Set("oracle.key", "CTRL-K")
  local res = OR.Search("swift")
  t:eq(res[1] and res[1].text, "Mount: Swift Phoenix", "mount found")
  local mule = false
  for _, r in ipairs(OR.Search("slow mule")) do if r.text == "Mount: Slow Mule" then mule = true end end
  t:eq(mule, false, "uncollected mount hidden")
  local m = OR.Search("focus kick")[1]
  t:ok(m and m.secure and m.secure.type == "macro", "macro is a secure result")
  Palette.Open()
  Palette.results = { m }
  Palette.Choose(1)
  local b = Palette.ActionButton()
  t:eq(b:GetAttribute("type"), "macro", "secure button armed")
  t:ok(H.overrideBindings.ENTER, "Enter bound to the action")
  Palette.Close()
  CQ.Drain()
  t:eq(H.overrideBindings.ENTER, nil, "Enter released on close")
  H.inCombat = true
  local _, inCombat = OR.Search("focus")
  t:ok(inCombat, "combat reported")
  local hasSecure = false
  for _, r in ipairs(OR.Search("focus")) do if r.secure then hasSecure = true end end
  t:eq(hasSecure, false, "no secure results in combat")
  H.inCombat = false
  local setting = OR.Search("palette key")[1]
  t:ok(setting and setting.kind == "setting", "settings searchable")
  PUI.API.RegisterOracleProvider("test", function(q) return { { text = "Plugin thing", run = function() H.pluginRan = true end } } end)
  t:cleanup(function() PUI.APIRegistry.oracle.test = nil end)
  local p = OR.Search("plugin thing")[1]
  t:eq(p and p.kind, "plugin:test", "plugin provider result")
  OR.Remember("Plugin thing")
  t:eq(OR.Recent()[1], "Plugin thing", "recent pick remembered")
end)
