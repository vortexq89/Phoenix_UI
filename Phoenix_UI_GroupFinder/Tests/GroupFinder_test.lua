local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for Group Finder.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema
local GF = ns.GF

local function setup(t)
  local saved = { Schema:Get("module.GroupFinder"), Schema:Get("gf.declined"), Schema:Get("gf.minRating"), Schema:Get("gf.sound") }
  local fkeys = {}
  for k in pairs(GF.schema) do if k:match("^gf%.%a+%.") or k:match("^gf%.q%.") then fkeys[k] = Schema.Copy(Schema:Get(k)) end end
  t:cleanup(function()
    for k, v in pairs(fkeys) do Schema:Set(k, v) end
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
  t:ok(line:GetText():find("2,500", 1, true), "leader score shown (season colour source)")
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

local Expr, Filters, Q = GF.Expr, GF.Filters, GF.Queue

Tests:Add("GroupFinder", "filter expressions: maths, logic, plain-word errors and suggestions", function(t)
  local fn = Expr.Compile("mprating >= 2600 and (tanks = 1 or heals > 0) and not declined")
  t:ok(fn, "compiles")
  t:eq(fn({ mprating = 2700, tanks = 1, heals = 0, declined = false }), true, "match")
  t:eq(fn({ mprating = 2700, tanks = 0, heals = 0, declined = false }), false, "no tank or healer")
  t:eq(fn({ mprating = 2700, tanks = 1, declined = true }), false, "declined")
  t:eq(Expr.Compile("dps + tanks * 2 == 5")({ dps = 3, tanks = 1 }), true, "precedence")
  t:eq(Expr.Compile("partyfit")({ partyfit = true }), true, "booleans")
  t:eq(Expr.Compile("")({}), true, "empty matches everything")
  local bad, msg, at = Expr.Compile("mprating >= 2600 and tnks == 1")
  t:eq(bad, nil, "unknown word rejected")
  t:ok(msg:find("did you mean 'tanks'", 1, true), "suggests the closest word: " .. tostring(msg))
  t:eq(at, 22, "points at the word")
  t:eq((Expr.Validate("(age < 5")), false, "missing bracket reported")
  t:eq((Expr.Validate("age <")), false, "unfinished expression reported")
  t:eq((Expr.Validate("age $ 3")), false, "unknown character reported")
  t:ok(#Expr.Complete("m") >= 3, "autocomplete offers mprating, members, mythic...")
  t:ok(#Expr.Help("lust") >= 2, "help search finds the Bloodlust words")
end)

Tests:Add("GroupFinder", "filter chips: generated expression, why-hidden counts, count line, sort", function(t)
  local cfg = { dungeon = { enabled = true, minRating = 2000, partyFit = true, notDelisted = true, diffMplus = true, tanksMax = 10 } }
  local function get(cat, id) return cfg[cat][id] end
  t:eq(Filters.BuildExpression("dungeon", get), "mprating >= 2000 and partyfit and not delisted and mythicplus", "readable expression from chips")
  local rows = {
    { id = 1, vars = { mprating = 2500, partyfit = true, delisted = false, mythicplus = true, age = 3 } },
    { id = 2, vars = { mprating = 1500, partyfit = true, delisted = false, mythicplus = true, age = 9 } },
    { id = 3, vars = { mprating = 2600, partyfit = false, delisted = false, mythicplus = true, age = 1 } },
    { id = 4, vars = { mprating = 1200, partyfit = false, delisted = false, mythicplus = true, age = 2 } },
    { id = 5, vars = { mprating = 2900, partyfit = true, delisted = false, mythicplus = false, age = 4 } },
    { id = 6, vars = { mprating = 3100, partyfit = true, delisted = false, mythicplus = true, age = 7 } },
  }
  local shown, why, hidden = Filters.Evaluate("dungeon", rows, get)
  t:eq(#shown, 2, "two groups kept")
  t:eq(hidden, 4, "four hidden")
  t:eq(why.minRating, 2, "rating hides two (first failing chip counts)")
  t:eq(why.partyFit, 1, "role full hides one")
  t:eq(why.difficulty, 1, "difficulty hides one")
  t:eq(Filters.CountLine(#shown, #rows, why), "showing 2 of 6 - 4 hidden: score 2, role full 1, difficulty 1", "count line")
  cfg.dungeon.expr = "age < 5"
  Filters.ForgetCompiled()
  shown, why = Filters.Evaluate("dungeon", rows, get)
  t:eq(#shown, 1, "expression narrows further")
  t:eq(why.expression, 1, "expression counted separately")
  cfg.dungeon.enabled = false
  t:eq(#(Filters.Evaluate("dungeon", rows, get)), 6, "filter off keeps all")
  local sorted = Filters.Sort({ rows[1], rows[2], rows[3] }, "mprating desc")
  t:eq(sorted[1].id, 3, "sorted by score")
  t:eq((Filters.ParseSort("nonsense desc")), nil, "unknown sort word rejected")
end)

Tests:Add("GroupFinder", "live filter on Blizzard rows, panel list, relax and presets", function(t)
  if not H then return end
  setup(t)
  Schema:Set("module.GroupFinder", true)
  Schema:Set("gf.declined", {})
  H.activities[7] = { fullName = "Ara-Kara, City of Echoes (Mythic Keystone)", shortName = "Ara-Kara", categoryID = 2, isMythicPlusActivity = true, maxNumPlayers = 5 }
  H.lfg[21] = { leader = "A-R", score = 2800, roles = { "TANK", "HEALER" }, classes = { "WARRIOR", "SHAMAN" }, activity = 7, age = 120, best = 14 }
  H.lfg[22] = { leader = "B-R", score = 1500, roles = { "DAMAGER" }, classes = { "MAGE" }, activity = 7, age = 600 }
  Schema:Set("gf.dungeon.minRating", 2000)
  GF.OnResults()
  t:eq(#GF.shown, 1, "one group kept")
  t:ok(GF.countLine:find("showing 1 of 2", 1, true), "count line: " .. tostring(GF.countLine))
  t:ok(GF.Data.keywords.arakara, "season word learned from the activity")
  t:eq(Expr.Compile("arakara")(GF.shown[1].vars), true, "dungeon word true for that group")
  local entry = CreateFrame("Button", nil, UIParent)
  entry.resultID = 22
  LFGListSearchEntry_Update(entry)
  t:eq(entry:GetAlpha(), Schema:Get("gf.dimAlpha"), "filtered Blizzard row dimmed, not removed")
  entry.resultID = 21
  LFGListSearchEntry_Update(entry)
  t:eq(entry:GetAlpha(), 1, "kept row normal")
  t:eq(GF.lastMarks, 2, "role indicators for both members")
  t:ok(GF.lines[entry]:GetText():find("best +14", 1, true), "best key shown")
  t:ok(GF.TooltipLines(GF.Info(21))[1]:find("Tanks 1", 1, true), "tooltip section has fixed role order counts")
  t:ok(GF.SavePreset("push"), "preset saved")
  t:eq(GF.RelaxTop(), "minRating", "relax turns off the chip hiding the most")
  t:eq(Schema:Get("gf.dungeon.minRating"), 0, "rating chip off")
  t:eq(#GF.shown, 2, "both shown after relaxing")
  t:ok(GF.LoadPreset("push"), "preset loads")
  t:eq(Schema:Get("gf.dungeon.minRating"), 2000, "preset restored the chip")
  local l, r = GF.Panel.RowText(GF.shown[1])
  t:ok(l:find("Ara-Kara", 1, true) and r:find("1T 1H 0D", 1, true), "panel row text")
  H.lfg[21], H.lfg[22] = nil, nil
end)

Tests:Add("GroupFinder", "queue helper: sign-up helpers on by default, Shift bypass, never clicks Enter itself", function(t)
  t:eq(Schema:Def("gf.q.roleCheck").default, true, "role check accept on at first install (D-MOD-DEF2)")
  t:eq(Schema:Def("gf.q.autoConfirm").default, true, "sign-up confirm on")
  t:eq(Schema:Def("gf.q.doubleClick").default, true, "double-click sign-up on")
  t:ok(Schema:Def("gf.q.autoConfirm").tooltip:find("protected code", 1, true), "taint explanation shown as info")
  t:eq(Schema:Def("gf.q.rolePerSpec").default, "manual", "one role-per-spec setting, manual first")
  if not H then return end
  setup(t)
  Schema:Set("module.GroupFinder", true)
  wipe(H.calls)
  H.fire("LFG_ROLE_CHECK_SHOW")
  local accepted = false
  for _, c in ipairs(H.calls) do if c[1] == "CompleteLFGRoleCheck" then accepted = c[2] end end
  t:eq(accepted, true, "role check accepted")
  H.signUpClicked = 0
  LFGListApplicationDialog_Show(LFGListApplicationDialog, 21)
  t:eq(H.signUpClicked, 1, "sign-up confirmed")
  local shift = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  LFGListApplicationDialog_Show(LFGListApplicationDialog, 21)
  IsShiftKeyDown = shift
  t:eq(H.signUpClicked, 1, "Shift lets you choose yourself")
  Schema:Set("gf.q.rolePerSpec", "custom")
  Schema:Set("gf.q.specRoles", { "62 = HEALER, DPS" })
  local tk, hl, dp = Q.WantedRoles()
  t:same({ tk, hl, dp }, { false, true, true }, "own list per spec")
  wipe(H.calls)
  PUI.Queue.pop = { kind = "lfg", deadline = GetTime() + 40, total = 40 }
  Q.OnQueueChanged(PUI.Queue.pop)
  t:ok(Q.pop and Q.pop:IsShown(), "Enter button shown on queue pop")
  for _, c in ipairs(H.calls) do t:ok(c[1] ~= "AcceptProposal", "never accepts by itself") end
  local label, time = Q.PopText(12.2, 40, "lfg")
  t:eq(label .. " " .. time, "ENTER DUNGEON 13 s left", "countdown text from PUI.Queue")
  PUI.Queue.pop = nil
  Q.OnQueueChanged(nil)
  t:eq(Q.pop:IsShown(), false, "hidden when the invite ends")
  t:ok(Q.MatchesInvite(" INV "), "invite words trimmed and case-folded")
  t:eq(Q.MatchesInvite(H.secret("inv")), false, "secret text never matched")
  Schema:Set("gf.q.rolePerSpec", "manual"); Schema:Set("gf.q.specRoles", {})
end)

Tests:Add("GroupFinder", "live preview runs the real filter on sample rows", function(t)
  if not H then return end
  if not PUI.OptionsHost:Load() then return end
  setup(t)
  local P = PUI.Options.Previews
  local card = CreateFrame("Frame")
  P.GroupFinder(card)
  t:eq(P.State(card).gfShown, 6, "no chips: all six sample groups")
  Schema:Set("gf.dungeon.minRating", 2800)
  P.GroupFinder(card)
  t:eq(P.State(card).gfShown, 3, "rating chip applies live in the preview")
  t:ok(P.State(card).hud.gf.lines[1]:GetText():find("3 hidden", 1, true), "count line in the preview")
end)
