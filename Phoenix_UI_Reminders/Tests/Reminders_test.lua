local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Reminders.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local RM = ns.RM

local function enable(t, ...)
  local keys = { "module.Reminders", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    H.group = nil; wipe(H.auras); wipe(H.known); H.inCombat = false; H.secretMode = false
  end)
  Schema:Set("module.Reminders", true)
end

Tests:Add("Reminders", "off by default; every setting has apply", function(t)
  t:eq(Schema:Def("module.Reminders").default, false, "module defaults off")
  for key, def in pairs(RM.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not Schema:Get("module.Reminders") then t:eq(next(RM.pools), nil, "no icon pools while off") end
end)

Tests:Add("Reminders", "raid buffs from group classes; out of combat only; secrets skipped", function(t)
  if not H or PUI.IS_FOREVER then return end
  H.group = { "PRIEST" }
  enable(t)
  local function has(list, spell) for _, r in ipairs(list) do if r.spell == spell then return true end end return false end
  local out = RM.Evaluate()
  t:ok(has(out.raid, 21562), "stamina missing with a priest in the group")
  t:eq(has(out.raid, 6673), false, "no warrior, no shout reminder")
  local shown = #out.raid
  t:ok(RM.pools.raid.icons[shown].frame:IsShown(), "icons from the pool shown")
  H.auras[21562] = { spellId = 21562 }
  RM.Update()
  t:eq(RM.pools.raid.icons[shown].frame:IsShown(), false, "one icon fewer once buffed")
  H.inCombat = true
  t:eq(RM.Evaluate(), nil, "no evaluation in combat")
  H.inCombat = false
  H.secretMode = true
  t:eq(RM.HasAura(21562), nil, "secret aura answers unknown")
end)

Tests:Add("Reminders", "class buffs need a known spell", function(t)
  if not H or PUI.IS_FOREVER then return end
  local saved = H.class
  H.class = "ROGUE"
  t:cleanup(function() H.class = saved end)
  enable(t)
  t:eq(#RM.Evaluate().class, 0, "nothing when no poison is known")
  H.known[2823] = true
  H.known[3408] = true
  t:eq(#RM.Evaluate().class, 2, "both poisons missing")
  H.auras[2823] = { spellId = 2823 }
  t:eq(#RM.Evaluate().class, 1, "lethal applied")
end)
