local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Step 2: per-spec and per-condition overrides (plan 1.8, 1.9, F2, G9).
local Tests, DB, Schema, O = PUI.Tests, PUI.DB, PUI.Schema, PUI.Overrides

local function setup(t)
  local saved = { sv = DB.sv, profile = DB.profile, name = DB.profileName, base = DB.base, baseName = DB.baseName }
  local ctx = O.Context
  local spec, cond = 1, "solo"
  O.Context = function() return spec, cond end
  local applied = {}
  Schema:Register("puitest.ov", { type = "range", default = 10, min = 0, max = 100, label = "Test", tooltip = "Test key",
    mode = "advanced", owner = "PUITest_Ov", overridable = true, apply = function(v) applied[#applied + 1] = v end })
  Schema:Register("puitest.plain", { type = "range", default = 1, min = 0, max = 100, label = "Test", tooltip = "Test key",
    mode = "advanced", owner = "PUITest_Ov", apply = function() end })
  t:cleanup(function()
    O.editing = nil
    O.Context = ctx
    Schema:UnregisterOwner("PUITest_Ov")
    O.last = {}
    DB.sv, DB.profile, DB.profileName, DB.base, DB.baseName = saved.sv, saved.profile, saved.name, saved.base, saved.baseName
    O:Arm()
  end)
  DB:Init({})
  return applied, function(s, c) spec, cond = s, c end
end

Tests:Add("Overrides", "resolve order: condition > spec > profile > default, with provenance", function(t)
  local applied, ctx = setup(t)
  t:eq(Schema:Get("puitest.ov"), 10, "default")
  t:eq(Schema:Source("puitest.ov"), "default", "source default")
  Schema:Set("puitest.ov", 20)
  t:eq(Schema:Source("puitest.ov"), "profile", "source profile")
  t:ok(O:Set("spec", 2, "puitest.ov", 30), "spec override stored")
  t:eq(Schema:Get("puitest.ov"), 20, "inactive spec does not apply")
  ctx(2, "solo")
  O:Recompose()
  t:eq(Schema:Get("puitest.ov"), 30, "spec override applies")
  t:eq(applied[#applied], 30, "re-applied live on spec change")
  t:eq(Schema:Source("puitest.ov"), "spec:2", "source spec")
  O:Set("cond", "arena", "puitest.ov", 40)
  ctx(2, "arena")
  O:Recompose()
  t:eq(Schema:Get("puitest.ov"), 40, "condition beats spec")
  t:eq(Schema:Source("puitest.ov"), "cond:arena", "source condition")
  ctx(1, "solo")
  t:eq(O:Recompose(), 1, "one key recomposed")
  t:eq(Schema:Get("puitest.ov"), 20, "back to the profile value exactly")
  t:eq(DB.profile["puitest.ov"], 20, "profile value never touched (no swap-and-harvest)")
end)

Tests:Add("Overrides", "only overridable keys; validation before publish", function(t)
  setup(t)
  t:ok(not O:Set("spec", 1, "puitest.plain", 5), "non-overridable refused")
  local ok = O:Set("spec", 1, "puitest.ov", 500)
  t:ok(not ok, "out-of-range value refused")
  t:eq(O:Get("spec", 1, "puitest.ov"), nil, "nothing stored on refusal (G26)")
  t:throws(function() O:Set("cond", "moon", "puitest.ov", 5) end, "unknown condition")
  t:throws(function() O:Set("nope", 1, "puitest.ov", 5) end, "unknown layer")
end)

Tests:Add("Overrides", "editing-as routes writes; promote and clear; list and arming", function(t)
  local _, ctx = setup(t)
  O:EditAs("spec", 3)
  Schema:Set("puitest.ov", 55)
  t:eq(O:Get("spec", 3, "puitest.ov"), 55, "write went into the spec layer")
  t:eq(DB.profile["puitest.ov"], nil, "profile untouched while editing")
  Schema:Set("puitest.plain", 7)
  t:eq(DB.profile["puitest.plain"], 7, "non-overridable keys still write the profile")
  O:EditAs(nil)
  t:eq(#O:List(), 1, "listed")
  t:ok(O.armed, "events armed while overrides exist")
  ctx(3, "solo")
  t:ok(O:Promote("spec", 3, "puitest.ov"), "promoted")
  t:eq(DB.profile["puitest.ov"], 55, "profile holds the value")
  t:eq(O:Get("spec", 3, "puitest.ov"), nil, "override removed")
  t:eq(DB.profile["@spec"], nil, "empty layers cleaned up")
  O:Arm()
  t:ok(not O.armed, "events released when none remain (G21)")
  t:ok(not O:Clear("spec", 3, "puitest.ov"), "clearing nothing is false")
end)

Tests:Add("Overrides", "copying a profile deep-copies its overrides; defaults strip skips layers", function(t)
  setup(t)
  O:Set("cond", "raid", "puitest.ov", 33)
  PUI.Profiles:Create("Copy", DB.profileName)
  local copy = DB.sv.profiles.Copy
  t:ok(copy["@cond"] and copy["@cond"].raid["puitest.ov"] == 33, "copied")
  copy["@cond"].raid["puitest.ov"] = 1
  t:eq(O:Get("cond", "raid", "puitest.ov"), 33, "no alias (G19)")
  DB:StripDefaults()
  t:eq(O:Get("cond", "raid", "puitest.ov"), 33, "override survives the logout strip")
end)
