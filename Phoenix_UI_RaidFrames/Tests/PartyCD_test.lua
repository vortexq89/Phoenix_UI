local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the party cooldown tracker (PartyCD.lua).
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local PCD, D = PUI.PartyCD, PUI.PartyCooldownData

local function enable(t, ...)
  local keys = { "module.PartyCD", ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  local units, group = H.units.party1, H.group
  t:cleanup(function()
    for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end
    H.units.party1, H.group = units, group
    wipe(PCD.state)
  end)
  H.units.party1 = true
  H.group = { [1] = PUI.IS_RETAIL and "SHAMAN" or "ROGUE" }
  Schema:Set("module.PartyCD", true)
end

Tests:Add("PartyCD", "settings: labels, tooltips, live apply; data table is consistent", function(t)
  for k, def in pairs(PCD.schema) do
    local d = Schema:Def(k)
    t:ok(d and type(d.apply) == "function" and d.label and d.tooltip, k)
    local _ = def
  end
  local bad = 0
  for id, info in pairs(D.spells) do
    if type(info.cd) ~= "number" or info.cd <= 0 or not D.base[id] then bad = bad + 1 end
  end
  t:eq(bad, 0, "every spell has a cooldown and a slot")
  t:ok(next(D.ALWAYS) ~= nil, "class interrupts")
end)

Tests:Add("PartyCD", "a party cast starts that spell's cooldown; secret spell IDs are ignored", function(t)
  if not H then return end
  enable(t, "pcd.attach")
  Schema:Set("pcd.attach", "list")
  local class = PUI.IS_RETAIL and "SHAMAN" or "ROGUE"
  local kick = D.ALWAYS[class]
  local slots = PCD.Slots("party1")
  t:eq(slots[1], kick, "interrupt shown before first use")
  t:eq(PCD.rows[1].unit, "party1", "row for party1")
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast", kick)
  local st = PCD.state[UnitGUID("party1")]
  t:ok(st and st.cds[kick] and st.cds[kick].duration == D.spells[kick].cd, "cooldown started")
  local before = st.cds[kick].start
  H.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast", H.secret(kick))
  t:eq(st.cds[kick].start, before, "secret spell ID never looked up")
  t:eq(PCD.Lookup(H.secret(kick)), nil, "lookup refuses secrets")
end)

Tests:Add("PartyCD", "categories and size apply live; ranks share one slot on Forever", function(t)
  if not H then return end
  enable(t, "pcd.cat.interrupt", "pcd.size", "pcd.attach")
  Schema:Set("pcd.attach", "list")
  Schema:Set("pcd.size", 30)
  local r = PCD.rows[1]
  t:eq(r.icons[1]:GetWidth(), 30, "size live")
  Schema:Set("pcd.cat.interrupt", false)
  t:eq(#PCD.Slots("party1"), 0, "interrupts off")
  if not PUI.IS_RETAIL then t:eq(D.base[1769], 1766, "Kick rank 4 uses the Kick slot") end
end)
