local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for nameplate colour data packs (DataPacks.lua).
local _, ns = ...
local Tests, Schema = PUI.Tests, PUI.Schema
local D, R = ns.NP.DataPacks, ns.Rules

Tests:Add("Nameplates", "pack strings: export, parse, validate and round trip", function(t)
  local str = "PUIPACK1|Test Keep|1234|185680:B07CFF:1.1;Void Acolyte:FF5468"
  local p = D.Parse(str)
  t:eq(p.label, "Test Keep", "name")
  t:eq(p.instance, 1234, "instance")
  t:eq(#p.lines, 2, "rules")
  t:eq(select(1, D.Parse("nope")), nil, "not a pack")
  t:eq(select(1, D.Parse("PUIPACK1|X|0|185680:nothex")), nil, "bad rule refused")
  t:eq(select(1, D.Parse("PUIPACK1||0|185680:B07CFF")), nil, "needs a name")
  t:ok(D.Export("phoenix.casters"):find("^PUIPACK1|"), "built-in exports")
  local back = D.Parse(D.Export("phoenix.rares"))
  t:eq(#back.lines, 2, "round trip keeps the rules")
end)

Tests:Add("Nameplates", "imported packs register live and instance packs apply only there", function(t)
  Tests.Keep(t, "np.rules.imported")
  Tests.Keep(t, "np.rules.packs")
  Schema:Set("np.rules.imported", { "PUIPACK1|Test Keep|1234|185680:B07CFF", "PUIPACK1|Test Any|0|185681:FF5468" })
  t:ok(R.packs["user.Test Keep"] ~= nil and R.packs["user.Test Any"] ~= nil, "registered")
  t:eq(#D.Filter({ "user.Test Keep", "user.Test Any" }, nil), 1, "outside the instance only the general pack")
  t:eq(#D.Filter({ "user.Test Keep", "user.Test Any" }, 1234), 2, "inside both")
  Schema:Set("np.rules.imported", {})
  t:eq(R.packs["user.Test Keep"], nil, "removed live")
end)
