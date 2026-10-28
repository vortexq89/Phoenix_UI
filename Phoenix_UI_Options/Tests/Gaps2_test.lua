local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test: review gaps batch 2 (2026-10-27): every new setting, its preview
-- and its behaviour, with sample data only.
local H = rawget(_G, "HARNESS")
local Tests, Schema, Options = PUI.Tests, PUI.Schema, PUI.Options
local G = PUI.Gaps
local CQ = PUI.CombatQueue

local NEW = { "np.los.", "gf.bossesDown", "gf.ownLockout", "gf.oldestAge", "gf.cancelOldest", "gf.popAlert", "gf.popSound",
  "tt.lines.crestCalc", "tt.crestCost", "core.combatToast", "cursor.", "celebrate.", "studio.editMode", "wisdom.simc",
  "rt.council", "pulse.auraSound", "friends.wowOnly", "friends.sameGame", "cdm.skinOnly", "embers.fade", "embers.wheel",
  "embers.scrollLine", "embers.dock", "embers.typeMenu", "embers.queueReport", "embers.reportCopy", "colors.healthGradient",
  "colors.gradientMid", "theme.border", "uf.player.textSlots", "uf.boss.textSlots" }

Tests:Add("Gaps2", "every new key has a label, tooltip, mode, owner and live apply; each feature has a Simple key", function(t)
  local n, simple = 0, {}
  for k, d in pairs(Schema.defs) do
    for _, p in ipairs(NEW) do
      if k:sub(1, #p) == p then
        n = n + 1
        t:ok(type(d.apply) == "function" and d.label and d.tooltip and d.owner and (d.mode == "simple" or d.mode == "advanced"), k .. " complete")
        if d.mode == "simple" then simple[p] = true end
      end
    end
  end
  t:ok(n >= 50, "new keys found: " .. n)
  for _, p in ipairs({ "np.los.", "gf.bossesDown", "tt.lines.crestCalc", "core.combatToast", "cursor.", "celebrate.", "studio.editMode",
    "wisdom.simc", "rt.council", "pulse.auraSound", "friends.wowOnly", "cdm.skinOnly", "embers.fade", "embers.dock", "colors.healthGradient", "theme.border", "uf.player.textSlots" }) do
    t:ok(simple[p], p .. " has a Simple key")
  end
  t:ok(Options.Nav.INFO.Cursor and Options.Nav.INFO.Celebrations, "new pages in the sidebar")
end)

Tests:Add("Gaps2", "previews draw for every page that gained settings and follow them live", function(t)
  local bag = Options.PreviewsExtras.Bag
  Tests.Keep(t, "cursor.ring", "embers.dock", "cdm.skinOnly")
  local ids = { Core = "cq", Cursor = "cu", Celebrations = "ce", Nameplates = "los", GroupFinder = "gfx", Tooltip = "cr", Studio = "em",
    Wisdom = "sc", RaidTools = "co", Pulse = "as", Friends = "ig", CooldownManager = "so", Embers = "dk", UnitFrames = "ts", Colors = "hg", Theme = "bd" }
  for owner, id in pairs(ids) do
    local card = CreateFrame("Frame")
    Options.Previews[owner](card)
    local fs = bag(card)[id .. "G1"]
    t:ok(fs and fs:IsShown(), owner .. " preview drawn")
  end
  local card = CreateFrame("Frame")
  Schema:Set("cursor.ring", true)
  Options.Previews.Cursor(card)
  t:ok(bag(card).cuG2:GetText():find("on", 1, true), "cursor preview live")
  Schema:Set("embers.dock", "row")
  Options.Previews.Embers(card)
  t:ok(bag(card).dkG1:GetText():find("row", 1, true) and bag(card).dkW1:IsShown(), "dock preview live")
  Schema:Set("cdm.skinOnly", true)
  Options.Previews.CooldownManager(card)
  t:ok(bag(card).soG1:GetText():find("on", 1, true), "skin only preview live")
end)

Tests:Add("Gaps2", "combat notice: a setting change that waits says so once per fight; housekeeping stays quiet", function(t)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; CQ.Drain(); G.changing = nil end)
  Tests.Keep(t, "core.combatToast")
  CQ.InCombat = function() return true end
  PUI.Toast.last = nil
  CQ.Defer("gaps.quiet", function() end)
  t:eq(PUI.Toast.last, nil, "unlabelled housekeeping: no notice")
  G.changing = "cursor.size"
  CQ.Defer("gaps.loud", function() end)
  t:ok(PUI.Toast.last and PUI.Toast.last:find("Ring size", 1, true), "setting label in the notice")
  PUI.Toast.last = nil
  CQ.Defer("gaps.loud2", function() end)
  t:eq(PUI.Toast.last, nil, "once per fight")
  G.changing = nil
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(next(G.told), nil, "reset when combat ends")
  Schema:Set("core.combatToast", false)
  t:eq(PUI.Toast:Show("x"), nil, "off: no combat notice")
  t:ok(PUI.Toast:Show("pop", "ok", true), "always-notices still show")
end)

Tests:Add("Gaps2", "cursor ring follows the mouse only while wanted; celebrations honour reduced motion", function(t)
  Tests.Keep(t, "cursor.ring", "cursor.combatOnly", "cursor.size", "glows.reducedMotion", "celebrate.enabled", "celebrate.keys")
  Schema:Set("cursor.ring", true)
  t:ok(PUI.Mouse.subs["cursor.ring"] ~= nil and G.Ring.frame:IsShown(), "ring on: subscribed and shown")
  Schema:Set("cursor.size", 64)
  t:eq(G.Ring.frame:GetWidth(), 64, "size live")
  Schema:Set("cursor.combatOnly", true)
  t:eq(PUI.Mouse.subs["cursor.ring"], nil, "combat only, out of combat: no poll")
  H.combatUnits.player = true
  H.fire("PLAYER_REGEN_DISABLED")
  t:ok(PUI.Mouse.subs["cursor.ring"] ~= nil, "shown when combat starts")
  H.combatUnits.player = nil
  PUI.Mouse.subs["cursor.ring"](10, 10)
  t:eq(PUI.Mouse.subs["cursor.ring"], nil, "the poll hides it when combat ends")
  Schema:Set("cursor.ring", false)
  Schema:Set("celebrate.enabled", true)
  H.completion = { onTime = true, level = 12 }
  t:cleanup(function() H.completion = nil end)
  H.fire("CHALLENGE_MODE_COMPLETED")
  t:eq(G.Celebrate.last, "Key timed", "timed key celebrated")
  t:ok(G.Celebrate.embers[1].tex:IsShown(), "embers rise")
  Schema:Set("glows.reducedMotion", true)
  G.Celebrate.Show("Test")
  t:ok(G.Celebrate.frame:IsShown() and not G.Celebrate.embers[1].tex:IsShown(), "reduced motion: banner only")
  Schema:Set("celebrate.enabled", false)
  G.Celebrate.last = nil
  H.fire("CHALLENGE_MODE_COMPLETED")
  t:eq(G.Celebrate.last, nil, "off: nothing")
end)

Tests:Add("Gaps2", "frame provider API and Edit Mode layout save and restore", function(t)
  local f = CreateFrame("Frame")
  PUI.API.RegisterFrameProvider("test.gaps", function(unit) if unit == "player" then return f end end)
  t:cleanup(function() G.providers["test.gaps"] = function() end end)
  local list = PUI.API.GetUnitFrames("player")
  local found = false
  for _, x in ipairs(list) do if x == f then found = true end end
  t:ok(found, "plugin frame returned")
  t:eq(#PUI.API.GetUnitFrames(nil), 0, "bad unit: empty list")
  Tests.Keep(t, "studio.editModeLayout", "studio.editModeActivate")
  local before = H.editMode
  t:cleanup(function() H.editMode = before end)
  H.editMode = { activeLayout = 1, layouts = {} }
  t:eq(G.EditMode.Save(), false, "a preset layout cannot be saved")
  H.editMode = { activeLayout = 3, layouts = { { layoutName = "Mine", layoutType = 1, systems = {} } } }
  t:ok(G.EditMode.Save(), "saved")
  t:eq(Schema:Get("studio.editModeLayout").data, "EM:Mine", "stored as the game's export string")
  t:ok(G.EditMode.Restore(), "restore runs")
  t:eq(H.editModeSaved.layouts[2].layoutName, "Phoenix", "added as Phoenix")
  t:eq(H.editModeActive, 4, "made active (presets counted)")
  G.EditMode.Restore()
  t:eq(#H.editModeSaved.layouts, 2, "a second restore replaces it")
end)

Tests:Add("Gaps2", "SimC export, crest calculator and Council", function(t)
  local X = PUI.Tooltip.Extras
  Tests.Keep(t, "tt.crestCost", "tt.lines.crestCalc", "rt.council")
  Schema:Set("tt.crestCost", 20)
  t:eq(select(2, X.CrestsToMax(2, 6)), 80, "4 ranks x 20")
  t:eq(X.CrestLine(6, 6, "Hero"), "Fully upgraded", "maxed")
  Schema:Set("tt.lines.crestCalc", false)
  t:eq(X.CrestLine(1, 6, "Hero"), nil, "off")
  local C = PUI.RaidTools.Council
  Schema:Set("rt.council", true)
  local ok, why = C.Start("|Hitem:1234::::|h[Sword]|h")
  t:eq(ok, false, "not in a group")
  t:ok(why:find("group", 1, true), "says why")
  C.OnMessage(nil, C.PREFIX, "ASK\t[Sword]", "PARTY", "Lead-Realm")
  t:ok(C.prompt:IsShown() and C.asked == "[Sword]", "prompt shown")
  C.item = "[Sword]"
  C.OnMessage(nil, C.PREFIX, "ANS\tPass\t650", "PARTY", "A")
  C.OnMessage(nil, C.PREFIX, "ANS\tNeed\t640", "PARTY", "B")
  C.OnMessage(nil, C.PREFIX, "ANS\tNeed\t630", "PARTY", "C")
  local rows = C.Rows()
  t:eq(rows[1].name, "C", "need first, lowest item level first")
  t:eq(rows[3].choice, "Pass", "pass last")
  C.OnMessage(nil, C.PREFIX, "ANS\tNeed\t1", "PARTY", H.secret("D"))
  t:eq(C.answers[H.secret("D")], nil, "secret sender ignored")
  C.prompt:Hide(); if C.results then C.results:Hide() end
  C.asked, C.item = nil, nil
  wipe(C.answers)
end)

Tests:Add("Gaps2", "SimC profile text: items with bonus IDs, enchant and gems, spec and talents", function(t)
  local S = PUI.Wisdom.SimC
  local link = "|cffa335ee|Hitem:212081:7364:213746::::::80:262::6:3:10356:1540:10255::::|h[Helm]|h|r"
  t:eq(S.ItemString(link), ",id=212081,bonus_id=10356/1540/10255,enchant_id=7364,gem_id=213746", "item line")
  t:eq(S.ItemString("garbage"), nil, "bad link")
  t:eq(S.ItemString(H.secret(link)), nil, "secret link skipped")
  local before, cfgBefore = H.equipped[1], H.config
  t:cleanup(function() H.equipped[1] = before; H.config = cfgBefore end)
  H.equipped[1] = link
  H.config = 77
  local text = S.Build()
  t:ok(text:find("head=,id=212081", 1, true), "equipped head")
  t:ok(text:find("talents=TALENTS77", 1, true), "talents import string")
  t:ok(text:find("region=eu", 1, true) and text:find("server=silvermoon", 1, true), "region and realm")
  Tests.Keep(t, "wisdom.simcBags")
  Schema:Set("wisdom.simcBags", true)
  t:ok(S.Build():find("### Gear from bags", 1, true), "bag section")
end)

Tests:Add("Gaps2", "aura sounds register through the game and clear when Pulse is off", function(t)
  local A = PUI.Pulse.Sounds
  t:eq(A.Parse("1234: Alarm").trigger, "added", "default trigger")
  t:eq(A.Parse("1234: Alarm, removed").trigger, "removed", "removed trigger")
  t:eq(A.Parse("Alarm"), nil, "needs a spell ID")
  t:eq(A.Parse("1234: Alarm, sometimes"), nil, "bad trigger")
  Tests.Keep(t, "module.Pulse", "pulse.auraSounds", "pulse.auraSoundChannel")
  Schema:Set("module.Pulse", true)
  local sound = PUI.Media:List("sound")[1]
  Schema:Set("pulse.auraSounds", { "1234: " .. sound, "5678: " .. sound .. ", stacks", "bad line" })
  t:eq(#A.ids, 2, "two sounds registered")
  local info = H.auraSounds[A.ids[1]][2]
  t:eq(info.spellID, 1234, "spell")
  t:eq(info.unitToken, "player", "unit")
  t:eq(info.outputChannel, "Master", "channel")
  t:eq(H.auraSounds[A.ids[2]][1], Enum.UnitAuraSoundTrigger.ApplicationsIncreased, "stacks trigger")
  local first = A.ids[1]
  Schema:Set("module.Pulse", false)
  t:eq(#A.ids, 0, "cleared when off")
  t:eq(H.auraSounds[first], nil, "removed from the game")
end)

Tests:Add("Gaps2", "Group Finder: hidden functions only when present, own lockout, cancel oldest, queue pop", function(t)
  local X = PUI.GroupFinder.Gaps
  local lib = C_LFGList
  t:cleanup(function() rawset(lib, "GetSearchResultEncounterInfo", nil); rawset(lib, "CancelApplication", nil); H.flashed = nil end)
  t:eq(X.BossesDown(5), nil, "missing function: off")
  rawset(lib, "GetSearchResultEncounterInfo", function(id) return id == 5 and { "A", "B", "C" } or nil end)
  t:eq(X.BossesDown(5), 3, "three bosses down")
  t:eq(X.BossesDown(6), 0, "none known")
  H.activities[901] = { mapID = 2769, difficultyID = 15, categoryID = 3 }
  H.ejMaps[2769] = 1296
  H.ejBosses[1296] = { 3009, 3010, 3011 }
  H.kills["2769:3010:15"] = true
  t:cleanup(function() H.activities[901] = nil; H.ejMaps[2769] = nil; H.ejBosses[1296] = nil; H.kills["2769:3010:15"] = nil end)
  local k, total = X.OwnLockout(901)
  t:eq(k, 1, "one kill"); t:eq(total, 3, "three bosses")
  t:eq(X.OwnLockout(nil), nil, "no activity")
  Tests.Keep(t, "gf.cancelOldest", "gf.popAlert")
  t:eq(X.CanCancel(), false, "no cancel function: no button")
  local cancelled
  rawset(lib, "CancelApplication", function(id) cancelled = id end)
  t:ok(X.CanCancel(), "button when the function exists")
  t:ok(X.Pop("LFG_PROPOSAL_SHOW"), "queue pop alert")
  t:ok(H.flashed, "taskbar flash")
  t:eq(X.Pop("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined"), false, "only invites")
  Schema:Set("gf.popAlert", false)
  t:eq(X.Pop("LFG_PROPOSAL_SHOW"), false, "off")
  t:eq(cancelled, nil, "nothing cancelled without a click")
end)

Tests:Add("Gaps2", "Friends in-game filter, CDM skin only, text slots, borders and health colours", function(t)
  local D = PUI.Friends and PUI.Friends.Data
  if D then
    local list = { { source = "friends", online = true, inWoW = true, sameGame = false }, { source = "friends", online = true, appOnly = true },
      { source = "guild", online = true } }
    t:eq(#D.Filter(list, { wowOnly = true }), 2, "app friend left out, guild kept")
    t:eq(#D.Filter(list, { wowOnly = true, sameGame = true }), 1, "other game version left out")
  end
  local T = PUI.UnitFrames.TextSlots
  local e = T.Parse("health:percent @ TOPRIGHT 0 10 14")
  t:eq(e.point, "TOPRIGHT"); t:eq(e.y, 10); t:eq(e.size, 14)
  t:eq(T.Parse("name").point, "CENTER", "point optional")
  t:eq(T.Parse("bogus @ TOP"), nil, "unknown tag")
  t:eq(T.Parse("name @ NOWHERE"), nil, "unknown point")
  Tests.Keep(t, "theme.borderStyle", "theme.borderSize", "colors.healthGradient")
  local f = CreateFrame("Frame")
  local edges = PUI.Theme:Outline(f, "line")
  Schema:Set("theme.borderSize", 3)
  t:eq(edges[1]:GetHeight(), 3, "size live")
  Schema:Set("theme.borderStyle", "none")
  t:eq(edges[1]:GetAlpha(), 0, "none hides")
  Schema:Set("theme.borderStyle", "soft")
  t:ok(rawget(edges, "soft") and rawget(edges, "soft"):IsShown(), "soft border art")
  PUI.Bars:HealthCurve()
  Schema:Set("colors.healthGradient", "theme")
  t:eq(PUI.Bars.healthCurve, nil, "curve rebuilt on change")
  t:ok(PUI.Bars:HealthCurve(), "theme curve")
end)

Tests:Add("Gaps2", "reset scopes: this module and everything", function(t)
  local Model = Options.Model
  Tests.Keep(t, "cursor.size", "cursor.dot", "celebrate.sound")
  Schema:Set("cursor.size", 80); Schema:Set("cursor.dot", true); Schema:Set("celebrate.sound", false)
  t:eq(#Model.ChangedKeys("Cursor"), 2, "two changed on Cursor")
  t:eq(Model.ResetModule("Cursor"), 2, "module reset")
  t:eq(Schema:Get("cursor.size"), 48, "back to default")
  t:eq(Schema:Get("celebrate.sound"), false, "other modules untouched")
  local asked
  local confirm = PUI.Dialogs.Confirm
  t:cleanup(function() PUI.Dialogs.Confirm = confirm end)
  PUI.Dialogs.Confirm = function(_, spec) asked = spec end
  Options.page = "Celebrations"
  Options.PageView.AskReset(false)
  t:ok(asked and asked.text:find("1 changed", 1, true), "asks with the count")
  asked.onAccept()
  t:eq(Schema:Get("celebrate.sound"), true, "accepted: reset")
  Schema:Set("cursor.dot", true)
  Options.PageView.AskReset(true)
  t:ok(asked.danger and asked.title == "Reset everything", "shift: everything, marked dangerous")
end)

Tests:Add("Gaps2", "Embers: scroll, docking, type menu, header fade and queued reports", function(t)
  local EM, D = PUI.Embers, PUI.Embers.Dock
  local W = EM.Window
  local data = {}
  for i = 1, 12 do data[i] = { name = "P" .. i } end
  D.offset = 3
  t:eq(W.Visible(data, 4, false)[1].name, "P4", "scrolled rows")
  D.offset = 0
  t:eq(W.Visible(data, 4, false)[1].name, "P1", "top rows")
  Tests.Keep(t, "module.Embers", "embers.windows", "embers.dock", "embers.fade", "embers.typeMenu", "embers.queueReport", "embers.reportCopy", "embers.segments")
  Schema:Set("module.Embers", true)
  Schema:Set("embers.windows", 2)
  local w = EM.windows[1]
  w.data = data
  t:eq(D.Scroll(w, -100), math.max(0, 12 - math.min(EM.settings.rows, 25)), "scroll clamps at the end")
  t:eq(D.Scroll(w, 100), 0, "and at the top")
  Schema:Set("embers.dock", "row")
  t:ok(D.frame and D.frame:IsShown(), "dock container")
  t:ok(EM.windows[2].docked, "second window docked")
  Schema:Set("embers.dock", "free")
  t:ok(not EM.windows[2].docked, "free again")
  W.Cycle(w, "meter")
  t:ok(D.menu and D.menu:IsShown(), "type list opens")
  D.Pick(w, "meter", "HealingDone")
  t:eq(Schema:Get("embers.w1.meter"), "HealingDone", "picked")
  Schema:Set("embers.fade", true)
  D.Hover(w, false)
  t:ok(w.title:GetAlpha() < 0.5, "header faded")
  D.Hover(w, true)
  t:eq(w.title:GetAlpha(), 1, "back on hover")
  Schema:Set("embers.segments", { { name = "Boss", meter = "DamageDone", duration = 30, total = 10, rows = { { name = "A", amount = 10, aps = 1 } } } })
  Schema:Set("embers.reportCopy", false)
  local locked = H.chatLocked
  t:cleanup(function() H.chatLocked = locked; D.queued = nil end)
  H.chatLocked = true
  local ok, why = EM.Report(1, "PARTY")
  t:eq(why, "queued", "blocked report queued")
  local sent = #H.chat
  H.chatLocked = false
  H.fire("ENCOUNTER_END", 1, "Boss", 16, 20, 1)
  t:eq(#H.chat, sent + 2, "posted after the boss")
  t:eq(D.queued, nil, "queue empty")
end)

Tests:Add("Gaps2", "nameplates: line-of-sight flash only for the line-of-sight error", function(t)
  local X = PUI.Nameplates.Gaps
  local f = CreateFrame("Frame")
  f.health = CreateFrame("StatusBar", nil, f)
  local o = X.Flash(f)
  t:ok(o:IsShown() and o.tag:GetText() == "Out of sight", "flash and tag")
end)

Tests:Add("Options", "Skins page preview follows the control switches live", function(t)
  if not rawget(_G, "HARNESS") then return end
  local Previews = PUI.Options.Previews
  local card = CreateFrame("Frame", nil, UIParent)
  local saved = Schema:Get("skins.controls.checks")
  t:cleanup(function() Schema:Set("skins.controls.checks", saved) end)
  Schema:Set("skins.controls.checks", true)
  Previews.Skins(card)
  local bag = PUI.Options.PreviewsExtras.Bag(card)
  t:ok(bag.skWin:IsShown(), "sample window")
  t:ok(bag.skCheck:IsShown(), "checkbox shown")
  Schema:Set("skins.controls.checks", false)
  Previews.Skins(card)
  t:eq(bag.skCheck:IsShown(), false, "checkbox family off")
end)
