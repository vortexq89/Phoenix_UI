local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Foundations (plan 1.19-1.29, F1): ledgers, visibility, services, season,
-- search, cast bar and aura engine. Engine-only behaviour is checked in game.
local Tests = PUI.Tests
local H = _G.HARNESS -- offline harness hooks; nil in game (those checks are skipped)

Tests:Add("Ledger", "CVar write remembers the prior value and restores only if still ours", function(t)
  local CVars = PUI.CVars
  if not H then return end -- uses a scratch CVar that only exists offline
  C_CVar.SetCVar("puiTestCVar", "0")
  t:cleanup(function() CVars:Restore("PUITest_A"); CVars:Restore("PUITest_B"); C_CVar.SetCVar("puiTestCVar", nil) end)
  t:ok(CVars:Set("PUITest_A", "puiTestCVar", 1), "set")
  t:eq(C_CVar.GetCVar("puiTestCVar"), "1", "written")
  CVars:Set("PUITest_B", "puiTestCVar", 1)
  t:eq(CVars:Restore("PUITest_A"), 0, "shared CVar stays while another owner holds it")
  t:eq(CVars:Restore("PUITest_B"), 1, "last owner restores")
  t:eq(C_CVar.GetCVar("puiTestCVar"), "0", "prior value back (not a hard-coded default)")
  CVars:Set("PUITest_A", "puiTestCVar", 1)
  C_CVar.SetCVar("puiTestCVar", "5") -- the user changed it afterwards
  CVars:Restore("PUITest_A")
  t:eq(C_CVar.GetCVar("puiTestCVar"), "5", "a user change is never overwritten")
  CVars:Exclude("puiTestCVar", "BigWigs")
  t:cleanup(function() CVars.excluded.puiTestCVar = nil end)
  t:ok(not CVars:Set("PUITest_A", "puiTestCVar", 1), "excluded CVar refused")
end)

Tests:Add("Ledger", "keybind claims, normalisation and the cross-module conflict check", function(t)
  local B = PUI.Bindings
  t:cleanup(function() B:Release("PUITest_Bars"); B:Release("PUITest_Click") end)
  t:eq(B.Normalise("shift-ctrl-k"), "CTRL-SHIFT-K", "canonical modifier order")
  t:eq(B.Normalise("  "), nil, "empty refused")
  t:ok(B:Claim("PUITest_Bars", "ctrl-shift-k", "ACTIONBUTTON1"), "claimed")
  local c = B:Conflicts("SHIFT-CTRL-K", "PUITest_Click")
  t:eq(#c >= 1 and c[1].owner, "PUITest_Bars", "other Phoenix owner reported")
  t:eq(#B:Conflicts("CTRL-SHIFT-K", "PUITest_Bars") - (H and (H.blizzBindings or {})["CTRL-SHIFT-K"] and 1 or 0), 0, "own claim is not a conflict")
  if H then
    t:eq(H.overrideBindings["CTRL-SHIFT-K"].command, "ACTIONBUTTON1", "override binding applied")
    H.blizzBindings = { ["ALT-Q"] = "TOGGLEWORLDMAP" }
    t:cleanup(function() H.blizzBindings = nil end)
    t:eq(B:Conflicts("alt-q")[1].kind, "blizzard", "Blizzard binding reported")
    B:Release("PUITest_Bars")
    t:eq(H.overrideBindings["CTRL-SHIFT-K"], nil, "released")
  end
end)

Tests:Add("Ledger", "FrameLedger records and restores a takeover, one owner per frame", function(t)
  local FL = PUI.FrameLedger
  local f = CreateFrame("Frame", nil, UIParent)
  f:Show()
  t:cleanup(function() FL:Release("PUITest_A"); FL:Release("PUITest_B") end)
  t:ok(FL:Take("PUITest_A", f, "test.frame"), "taken")
  t:ok(not FL:Take("PUITest_B", f, "test.frame"), "second owner refused")
  t:throws(function() FL:Take("PUITest_A", f) end, "stable id required")
  f:Hide()
  t:eq(FL:Release("PUITest_A"), 1, "released")
  t:ok(f:IsShown(), "shown state restored")
  t:eq(FL:Owner("test.frame"), nil, "entry gone")
end)

Tests:Add("Visibility", "rules: content, combat, group, spec and hide conditions with reasons", function(t)
  local V = PUI.Visibility
  local s = { content = "raid", group = "raid", combat = false, spec = 2, resting = false, vehicle = false, mounted = false,
    skyriding = false, petBattle = false }
  t:ok(V.Test(nil, s), "no rule shows")
  t:ok(not V.Test({ mode = "never" }, s), "never hides")
  local shown, why = V.Test({ mode = "when", content = { party = true } }, s)
  t:ok(not shown and why:find("Raids", 1, true), "content reason")
  t:ok(not V.Test({ mode = "when", combat = "in" }, s), "combat only")
  t:ok(V.Test({ mode = "when", combat = "out" }, s), "out of combat")
  t:ok(V.Test({ mode = "when", specs = { [2] = true } }, s), "spec match")
  t:ok(not V.Test({ mode = "when", specs = { [1] = true } }, s), "spec mismatch")
  s.skyriding = true
  shown, why = V.Test({ mode = "when", hide = { skyriding = true } }, s)
  t:ok(not shown and why:find("skyriding", 1, true), "hide while skyriding")
end)

Tests:Add("Visibility", "watchers are event-armed only while watched and coalesce to one pass", function(t)
  local V = PUI.Visibility
  local probe = V.Probe
  local state = { content = "world", group = "solo", combat = false, spec = 1 }
  V.Probe = function() local c = {}; for k, v in pairs(state) do c[k] = v end; return c end
  local calls, last = 0, nil
  t:cleanup(function() V.Probe = probe; V:Unwatch("test.vis") end)
  V:Watch("test.vis", { mode = "when", content = { world = true } }, function(shown) calls = calls + 1; last = shown end)
  t:eq(calls, 1, "initial call")
  t:eq(last, true, "shown in world")
  t:ok(V.armed, "events armed")
  state.content = "raid"
  V:Invalidate(); V:Invalidate(); V:Invalidate()
  t:ok(PUI.Ticker:IsRegistered("visibility.flush"), "one coalesced flush queued")
  V.Evaluate()
  t:eq(calls, 2, "one change, one call")
  t:eq(last, false, "hidden in raid")
  t:eq(select(2, V:Why("test.vis")), "not shown in Raids", "why-hidden readout")
  t:ok(not PUI.Ticker:IsRegistered("visibility.flush"), "flush disarmed")
  V:SetRule("test.vis", { mode = "always" })
  V.Evaluate()
  t:eq(last, true, "rule change applies live")
  V:Unwatch("test.vis")
  if V:Count() == 0 then t:ok(not V.armed, "events released when nothing is watched") end
end)

Tests:Add("Services", "Format: short, grouped, exact, durations; secrets go to the engine", function(t)
  local F = PUI.Format
  t:eq(F.Number(999, "short"), "999", "small")
  t:eq(F.Number(12345, "short", 1), "12.3K", "thousands")
  t:eq(F.Number(12000, "short", 1), "12K", "trailing zero trimmed")
  t:eq(F.Number(2500000, "short", 2), "2.5M", "millions")
  t:eq(F.Number(1234567, "full"), "1,234,567", "grouped")
  t:eq(F.Number(1234.6, "exact"), "1235", "exact rounds")
  t:eq(F.Duration(3909), "1:05:09", "hours")
  t:eq(F.Duration(247), "4:07", "minutes")
  t:eq(F.Duration(9.46, 10), "9.5", "tenths under threshold")
  t:eq(F.Percent(42.4), "42%", "percent")
  if H then
    local s = H.secret(5000)
    t:ok(H.secrets[F.Number(s)] ~= nil, "secret number formatted by the engine, still secret")
    t:eq(F.Duration(s), "", "secret duration never compared")
  end
  PUI.Schema:Set("format.numberStyle", "full")
  t:cleanup(function() PUI.Schema:Reset("format.numberStyle") end)
  t:eq(F.Number(12345), "12,345", "setting applies live")
end)

Tests:Add("Services", "Range and Mouse poll only while someone listens (refcounted)", function(t)
  local R, M, Ticker = PUI.Range, PUI.Mouse, PUI.Ticker
  t:cleanup(function() R:ReleaseOwner("PUITest"); M:Unsubscribe("test.mouse") end)
  local before = R.count
  local h1 = R:Acquire("PUITest", "party1", function() end)
  local h2 = R:Acquire("PUITest", "party2", function() end)
  t:ok(Ticker:IsRegistered("range.poll"), "range poll running")
  R:Release(h1)
  t:eq(R.count, before + 1, "refcount")
  R:Release(h2)
  if before == 0 then t:ok(not Ticker:IsRegistered("range.poll"), "poll stops at zero") end
  local got
  M:Subscribe("test.mouse", function(x, y) got = { x, y } end)
  t:ok(Ticker:IsRegistered("mouse.poll"), "one cursor poll")
  return function()
    if H then t:ok(got ~= nil, "subscriber fed by the shared poll") end
    M:Unsubscribe("test.mouse")
    if M.count == 0 then t:ok(not Ticker:IsRegistered("mouse.poll"), "cursor poll stops") end
  end
end)

Tests:Add("Services", "Glow uses an AnimationGroup and restyles in place", function(t)
  local G = PUI.Glow
  local f = CreateFrame("Frame", nil, UIParent)
  local g = G:Start(f, "pulse", { r = 0, g = 1, b = 0 })
  t:ok(G:IsGlowing(f), "glowing")
  t:ok(g.group:IsPlaying(), "C-side animation, no OnUpdate")
  t:eq(G:Start(f, "solid"), g, "same glow object reused")
  t:ok(not g.group:IsPlaying(), "solid style does not animate")
  G:Start(f, "none")
  t:ok(not G:IsGlowing(f), "none stops")
  t:eq(#PUI.Ticker:Audit(), 0, "no stray OnUpdate")
end)

Tests:Add("Season", "season data comes from the API and score colours follow the setting", function(t)
  local S = PUI.Season
  t:ok(S:Refresh(), "refreshed")
  if H then
    t:eq(S.id, 15, "season id")
    t:eq(#S.dungeons, 2, "dungeons")
    t:eq(S.dungeons[1].name, "Ara-Kara", "sorted by name")
    t:eq(S:Thresholds(501)[3], 1080, "+3 pace")
    t:eq(S.affixes[2], 152, "affixes")
    local r = S:ScoreColor(2600)
    t:eq(r, 1, "Blizzard colour")
  end
  PUI.Schema:Set("season.scoreColors", "custom")
  t:cleanup(function() PUI.Schema:Reset("season.scoreColors") end)
  local r0, g0 = S:ScoreColor(0)
  t:ok(math.abs(r0 - 0.62) < 0.001 and math.abs(g0 - 0.62) < 0.001, "custom gradient start")
  t:eq(S:ScoreColor(99999), 1, "custom gradient caps at end colour")
  PUI.Schema:Set("season.scoreColors", "raiderio")
  t:ok(S:ScoreColor(100) ~= nil, "Raider.IO falls back when absent")
  if H then t:eq(S:ScoreColor(H.secret(5)), 1, "secret score gets neutral colour") end
end)

Tests:Add("Search", "plain text, quoted exact, numeric ID then prefix; patterns are literal", function(t)
  local S = PUI.Search
  local q = S.Parse("fire bolt")
  t:eq(S.Match(q, "Fire Bolt", 1), 1, "starts with first word")
  t:eq(S.Match(q, "Big Fire Bolt", 1), 2, "contains all words")
  t:eq(S.Match(q, "Fireball", 1), nil, "missing word")
  t:eq(S.Match(S.Parse('"fire"'), "Fire Bolt"), nil, "quoted is exact")
  t:eq(S.Match(S.Parse('"fire bolt"'), "Fire Bolt"), 1, "quoted exact hit")
  t:eq(S.Match(S.Parse("133"), "x", 133), 1, "exact id")
  t:eq(S.Match(S.Parse("13"), "x", 133), 2, "id prefix")
  t:eq(S.Match(S.Parse("("), "a (b)"), 2, "'(' is literal, no pattern error")
  t:eq(S.Match(S.Parse("%a"), "100%a"), 2, "'%' is literal")
  t:eq(S.Match(S.Parse("shield"), "Wall", 1, "shield tank"), 2, "search tags")
end)

Tests:Add("Search", "runs as a budgeted Ticker job; a new query cancels the old one", function(t)
  local S = PUI.Search
  local items = {}
  for i = 1, 450 do items[i] = { name = "Item " .. i, id = i } end
  local first, second
  S.budget = 100
  t:cleanup(function() S.budget = 200; S:Cancel("PUITest") end)
  local g1 = S:Run("PUITest", "item 4", items, function(r) first = r end)
  local g2 = S:Run("PUITest", "12", items, function(r, gen) second = { r = r, gen = gen } end)
  t:ok(g2 == g1 + 1, "generation increments")
  t:ok(second == nil, "not finished in the same frame (budgeted)")
  return function()
    -- the harness steps several frames before continuations, but be lenient in game
    if second then
      t:eq(first, nil, "superseded query never reports")
      t:eq(second.gen, g2, "result carries its generation")
      t:eq(second.r[1].id, 12, "exact id first")
    end
  end
end)

Tests:Add("CastBar", "shared dispatcher armed only while bars exist; secrets reach widgets only", function(t)
  local CB = PUI.CastBar
  local before = CB.active
  local bar = CB:Create("PUITest", UIParent, "target", { width = 200.4, height = 16 })
  t:cleanup(function() bar:Release(); if H then H.casting = nil; H.secretMode = nil end end)
  t:ok(CB.armed, "events armed")
  t:eq(bar.frame:GetWidth(), 200, "whole pixels")
  if H then
    H.casting = true
    H.secretMode = true -- name and interruptible flag become secrets
    for _, f in ipairs(H.frames) do
      if f.scripts.OnEvent and f.events.UNIT_SPELLCAST_START then f.scripts.OnEvent(f, "UNIT_SPELLCAST_START", "target") end
    end
    t:ok(bar.casting, "cast started from the shared dispatcher")
    t:eq(bar.kind, "cast", "kind")
    H.casting = nil
    for _, f in ipairs(H.frames) do
      if f.scripts.OnEvent and f.events.UNIT_SPELLCAST_STOP then f.scripts.OnEvent(f, "UNIT_SPELLCAST_STOP", "target") end
    end
    t:ok(not bar.casting, "stopped")
  end
  bar:Release()
  t:eq(CB.active, before, "released")
  if before == 0 then t:ok(not CB.armed, "events released") end
  t:eq(#PUI.Ticker:Audit(), 0, "no per-frame Lua")
end)

Tests:Add("CastBar", "one own-kick state per class, from the spellbook", function(t)
  local K = PUI.CastBar.Kick
  if not H then return end
  local saved = H.known
  H.known = { [2139] = true }
  t:cleanup(function() H.known = saved; K:Refresh() end)
  t:eq(K:Refresh(), 2139, "mage counterspell")
  t:ok(K:Duration() ~= nil, "cooldown duration object for widgets")
  H.known = {}
  t:eq(K:Refresh(), nil, "no kick known")
  t:eq(K:Duration(), nil, "no duration without a kick")
end)

Tests:Add("Auras", "canonical filters: sorted, de-duplicated, validated, cached", function(t)
  local A = PUI.Auras
  t:eq(A.Filter("PLAYER", "harmful"), "HARMFUL|PLAYER", "sorted and upper-cased")
  t:eq(A.Filter("HARMFUL|PLAYER|PLAYER"), "HARMFUL|PLAYER", "de-duplicated")
  t:eq(A.Filter("HELPFUL !PLAYER"), "!PLAYER|HELPFUL", "negation kept")
  t:throws(function() A.Filter("HARMFUL", "NOPE") end, "unknown token")
  t:throws(function() A.Filter("HELPFUL", "HARMFUL") end, "contradiction")
  t:throws(function() A.Filter("PLAYER") end, "needs a direction")
  t:throws(function() A.Filter("HARMFUL", "!MAW") end, "non-negatable token")
end)

Tests:Add("Auras", "groups are add-only: removing caps at 0, changes are diffed", function(t)
  local A = PUI.Auras
  local h = A:Create("PUITest", UIParent, "target", { lineSize = 6 })
  t:cleanup(function() h:Release() end)
  h:Configure({ { key = "debuffs", filter = "PLAYER|HARMFUL", max = 8, sort = "expiration" }, { key = "buffs", filter = "HELPFUL", max = 4 } })
  t:eq(#h:Groups(), 2, "two groups")
  h:Configure({ { key = "debuffs", filter = "HARMFUL|PLAYER", max = 8, sort = "expiration" } })
  t:eq(h:GroupState("buffs").cap, 0, "removed group capped at 0, not destroyed")
  t:eq(#h:Groups(), 2, "group objects kept")
  h:Configure({ { key = "debuffs", filter = "HARMFUL", max = 12, sort = "expiration" }, { key = "buffs", filter = "HELPFUL", max = 4 } })
  t:eq(h:GroupState("debuffs").filter, "HARMFUL", "filter changed in place")
  t:eq(h:GroupState("buffs").cap, 4, "re-enabled")
  if H and h.container then
    local log = h.container.groupLog
    local adds = 0
    for _, e in ipairs(log) do if e[1] == "add" then adds = adds + 1 end end
    t:eq(adds, 2, "AddAuraGroup called once per key")
    t:eq(log[1][3], "HARMFUL|PLAYER", "engine receives canonical filter")
  end
end)

Tests:Add("Auras", "restyles wait while auras are secret; private anchors are owner-released", function(t)
  local A = PUI.Auras
  if not H then return end
  local h = A:Create("PUITest", UIParent, "player")
  local ran = 0
  t:cleanup(function() H.secretAuras = false; h:Release(); A:RemovePrivateAnchors("PUITest") end)
  H.secretAuras = true
  h:Restyle(function() ran = ran + 1 end)
  t:eq(ran, 0, "deferred while restricted")
  t:ok(PUI.Ticker:IsRegistered("auras.restyle"), "owned retry armed")
  H.secretAuras = false
  A:FlushRestyles()
  t:eq(ran, 1, "ran once restrictions lift")
  t:ok(not PUI.Ticker:IsRegistered("auras.restyle"), "retry disarmed")
  local id = A:AddPrivateAnchor("PUITest", CreateFrame("Frame"), "party1", { size = 20 })
  t:ok(H.privateAnchors[id] ~= nil, "anchor added")
  t:eq(A:RemovePrivateAnchors("PUITest"), 1, "removed by owner")
  t:eq(H.privateAnchors[id], nil, "engine anchor gone")
end)

Tests:Add("Dialogs", "chat links parse only Phoenix addon links and run the handler", function(t)
  local L = PUI.Links
  local got
  L:Register("test", function(arg) got = arg end)
  t:cleanup(function() L.handlers.test = nil end)
  local link = L.Make("test", "page:x|y", "Open")
  t:ok(link:find("|Haddon:PhoenixUI:test:pagexy|h[Open]|h", 1, true) ~= nil, "separators stripped from the argument")
  t:ok(L:Handle("addon:PhoenixUI:test:abc"), "handled")
  t:eq(got, "abc", "argument passed")
  t:ok(not L:Handle("addon:OtherAddon:test:abc"), "other addons ignored")
  t:ok(not L:Handle("item:123"), "other link types ignored")
end)
