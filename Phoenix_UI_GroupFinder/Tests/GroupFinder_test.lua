local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Group Finder.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local GF = ns.GF

local function setup(t)
  local saved = { Schema:Get("module.GroupFinder"), Schema:Get("gf.declined"), Schema:Get("gf.minRating"), Schema:Get("gf.sound") }
  t:cleanup(function()
    Schema:Set("gf.sound", saved[4]); Schema:Set("gf.minRating", saved[3]); Schema:Set("gf.declined", saved[2]); Schema:Set("module.GroupFinder", saved[1])
    wipe(H.lfg); H.lfgFilter = nil; H.addonLoaded.PremadeGroupsFilter = nil; wipe(H.sounds)
  end)
end

Tests:Add("GroupFinder", "on by default (display only); stands down for PGF", function(t)
  t:eq(Schema:Def("module.GroupFinder").default, true, "on by default per spec 6.6")
  t:eq(Schema:Def("gf.sound").default, false, "sound off by default")
  t:eq(Schema:Def("gf.minRating").default, 0, "no filter by default")
  for key, def in pairs(GF.schema) do t:eq(type(def.apply), "function", key .. " apply") end
  if not H then return end
  setup(t)
  H.addonLoaded.PremadeGroupsFilter = true
  PUI.Kernel:Evaluate("GroupFinder")
  t:eq(GF.module.enabled, false, "stands down when Premade Groups Filter is loaded")
  H.addonLoaded.PremadeGroupsFilter = nil
  PUI.Kernel:Evaluate("GroupFinder")
  t:ok(GF.module.enabled, "back when it is gone")
end)

Tests:Add("GroupFinder", "entry line, missing roles, declined memory, dimming, filter ownership", function(t)
  if not H then return end
  setup(t)
  Schema:Set("module.GroupFinder", true)
  Schema:Set("gf.declined", {})
  H.lfg[11] = { leader = "Lead-Realm", score = 2500, roles = { "TANK", "DAMAGER" } }
  local entry = CreateFrame("Button", nil, UIParent)
  entry.resultID = 11
  LFGListSearchEntry_Update(entry)
  local line = GF.lines[entry]
  t:ok(line and line:GetText():find("needs Healer, 2 Damager", 1, true), "missing roles listed")
  t:ok(line:GetText():find("2500", 1, true), "leader score shown")
  t:eq(entry:GetAlpha(), 1, "not dimmed")
  t:eq(H.lfgFilter, nil, "Blizzard filter untouched by default")
  GF.OnStatus(nil, nil, 11, "declined")
  t:ok(GF.WasDeclined("Lead-Realm"), "decline remembered")
  LFGListSearchEntry_Update(entry)
  t:eq(entry:GetAlpha(), 0.45, "declining leader dimmed")
  Schema:Set("gf.minRating", 3000)
  t:eq(H.lfgFilter and H.lfgFilter.minimumRating, 3000, "server-side minimum rating set")
  Schema:Set("gf.minRating", 0)
  t:eq(H.lfgFilter.minimumRating, 0, "cleared once when turned off")
  H.lfgFilter.minimumRating = 1234
  Schema:Set("gf.dim", true)
  t:eq(H.lfgFilter.minimumRating, 1234, "player's own filter left alone afterwards")
  Schema:Set("module.GroupFinder", false)
  t:eq(entry:GetAlpha(), 1, "off: alpha restored")
  t:eq(line:IsShown(), false, "off: line hidden")
end)
