local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Deferred batch A (Options & Core): spec auto-switch and the layer key.
local Tests, DB, Schema, O, CQ = PUI.Tests, PUI.DB, PUI.Schema, PUI.Overrides, PUI.CombatQueue
local H = rawget(_G, "HARNESS")

local function sandbox(t)
  local saved = { sv = DB.sv, profile = DB.profile, name = DB.profileName, base = DB.base, baseName = DB.baseName }
  t:cleanup(function()
    CQ.Drain()
    O.keyLayer = false
    O.last = {}
    DB.sv, DB.profile, DB.profileName, DB.base, DB.baseName = saved.sv, saved.profile, saved.name, saved.base, saved.baseName
    O:Arm()
  end)
  DB:Init({})
end

Tests:Add("SpecProfiles", "off at first install; a mapped spec switches the profile out of combat", function(t)
  if not H then return end
  sandbox(t)
  t:eq(Schema:Def("core.specProfile").default, false, "off by default")
  PUI.Profiles:Create("Healer")
  t:ok(PUI.SpecProfiles:SetMap(1, "Healer"), "spec 1 mapped")
  t:eq(PUI.SpecProfiles:Evaluate(), nil, "nothing happens while the switch is off")
  Schema:Set("core.specProfile", true)
  CQ.Drain()
  t:eq(DB.profileName, "Healer", "switched to the spec's profile")
  t:eq(Schema:Get("core.specProfile.spec1"), "Healer", "the per-spec select reads the map")
  t:eq(select(2, PUI.SpecProfiles:SetMap(2, "Nope")), "no profile named Nope", "unknown profile refused")
  Schema:Set("core.specProfile.spec1", "")
  t:eq(PUI.SpecProfiles:Map(1), nil, "No change clears the map")
end)

Tests:Add("SpecProfiles", "the wizard toggle creates one profile per spec and turns the switch on", function(t)
  if not H then return end
  sandbox(t)
  local SU = PUI.Setup
  if not (SU and SU.ApplySpecProfiles) then return end
  local own = DB.sv.chars[DB:CharKey()]
  SU.ApplySpecProfiles(true)
  CQ.Drain()
  t:ok(PUI.Profiles:Exists(own .. " - Arcane"), "profile named after the spec")
  t:eq(PUI.SpecProfiles:Map(1), own .. " - Arcane", "spec 1 mapped")
  t:eq(Schema:Get("core.specProfile"), true, "switch on")
  t:eq(DB.profileName, own .. " - Arcane", "now on the spec's own profile")
  SU.ApplySpecProfiles(false)
  t:eq(Schema:Get("core.specProfile"), false, "off again; map kept")
  t:ok(PUI.SpecProfiles:Map(1) ~= nil, "map kept")
end)

Tests:Add("KeyLayer", "the keybind condition wins while the layer is on (hold and toggle)", function(t)
  sandbox(t)
  local applied = {}
  Schema:Register("puitest.kl", { type = "range", default = 10, min = 0, max = 100, label = "Test", tooltip = "Test key",
    mode = "advanced", owner = "PUITest_KL", overridable = true, apply = function(v) applied[#applied + 1] = v end })
  t:cleanup(function() Schema:UnregisterOwner("PUITest_KL") end)
  local mode = Schema:Get("core.keyLayer.mode")
  t:cleanup(function() Schema:Set("core.keyLayer.mode", mode) end)
  t:ok(O:Set("cond", "keybind", "puitest.kl", 55), "keybind override stored")
  t:eq(Schema:Get("puitest.kl"), 10, "inactive while the layer is off")
  Schema:Set("core.keyLayer.mode", "hold")
  PUI.KeyLayer:Press(true)
  t:eq(Schema:Get("puitest.kl"), 55, "held: layer value")
  t:eq(applied[#applied], 55, "applied live")
  t:eq(Schema:Source("puitest.kl"), "cond:keybind", "provenance")
  PUI.KeyLayer:Press(false)
  t:eq(Schema:Get("puitest.kl"), 10, "released: back")
  Schema:Set("core.keyLayer.mode", "toggle")
  PUI.KeyLayer:Press(true); PUI.KeyLayer:Press(false)
  t:eq(Schema:Get("puitest.kl"), 55, "toggle on stays on after key up")
  PUI.KeyLayer:Press(true)
  t:eq(Schema:Get("puitest.kl"), 10, "second press turns it off")
end)

Tests:Add("KeyLayer", "the key is claimed through the Binding ledger and released when cleared", function(t)
  local key = Schema:Get("core.keyLayer.key")
  t:cleanup(function() Schema:Set("core.keyLayer.key", key); CQ.Drain() end)
  Schema:Set("core.keyLayer.key", "CTRL-F9")
  local c = PUI.Bindings.claims["CTRL-F9"]
  t:ok(c and c.Overrides and c.Overrides.click == PUI.KeyLayer.BUTTON, "claimed as a click binding")
  Schema:Set("core.keyLayer.key", "")
  t:eq(PUI.Bindings.claims["CTRL-F9"], nil, "released")
end)
