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

-- Step 8c ------------------------------------------------------------------------
Tests:Add("Reminders", "my own list: id or id:label, click to cast when known", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t, "rm.customList", "rm.custom", "rm.click")
  local rows = RM.ParseCustom({ "1459", " 6673 : Shout ", "junk" })
  t:eq(#rows, 2, "bad lines skipped")
  t:eq(rows[2].label, "Shout", "label kept")
  Schema:Set("rm.custom", true)
  Schema:Set("rm.click", true)
  H.known[6673] = true
  Schema:Set("rm.customList", { "6673:Shout" })
  local out = RM.Evaluate()
  t:eq(out.custom[1].spell, 6673, "missing custom buff listed")
  RM.Show(out)
  local icon = RM.pools.custom.icons[1]
  t:eq(icon.frame:GetAttribute("spell"), 6673, "secure click casts it")
  H.auras[6673] = { spellId = 6673 }
  t:eq(#RM.Evaluate().custom, 0, "gone once the buff is up")
end)

Tests:Add("Reminders", "pet reminder by class and spec; where grid and key limit explain why", function(t)
  if not H or PUI.IS_FOREVER then return end
  enable(t, "rm.pet", "rm.where", "rm.keyBelow")
  local class, spec = H.class, H.specIndex
  t:cleanup(function() H.class = class; H.specIndex = spec; H.units.pet = nil; H.mplus = nil; H.content = nil end)
  Schema:Set("rm.pet", true)
  H.class, H.specIndex = "HUNTER", 1
  t:eq(RM.Evaluate().pet[1].key, "pet", "hunter without a pet reminded")
  H.units.pet = true
  t:eq(#RM.Evaluate().pet, 0, "pet out: nothing")
  H.units.pet = nil
  H.specIndex = 2
  RM.Evaluate()
  t:ok(RM.why.pet:find("without a pet", 1, true), "marksmanship explained")
  H.class = "MAGE"
  RM.Evaluate()
  t:ok(RM.why.pet:find("no pet", 1, true), "class without pets explained")
  local where = Schema:Get("rm.where")
  where.raid.world = false
  Schema:Set("rm.where", where)
  t:same({ RM.Allowed("raid", "world") }, { false, "turned off for " .. (PUI.Profiles.CONTENT_LABEL.world or "world") }, "grid turns a group off per content")
  t:eq(RM.Allowed("class", "world"), true, "other groups untouched")
  Schema:Set("rm.keyBelow", 10)
  H.mplus = { mapID = 501, level = 12, limit = 1800, elapsed = 0, deaths = 0, lost = 0 }
  local ok, why = RM.Allowed("class", "mythicplus")
  t:eq(ok, false, "high keys skipped")
  t:ok(why:find("12", 1, true), "with the level in the reason")
end)

Tests:Add("Reminders", "live preview follows icon settings", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  local saved = Schema:Get("rm.pet")
  t:cleanup(function() Schema:Set("rm.pet", saved) end)
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  Schema:Set("rm.pet", true)
  P.Reminders(card)
  local n = P.State(card).rmIcons
  Schema:Set("rm.pet", false)
  P.Reminders(card)
  t:eq(P.State(card).rmIcons, n - 1, "pet icon follows the setting")
end)
