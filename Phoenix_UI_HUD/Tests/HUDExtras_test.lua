local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test cases for the deferred batch B HUD items.
local _, ns = ...
local H = rawget(_G, "HARNESS")
local Tests, Schema, CQ = PUI.Tests, PUI.Schema, PUI.CombatQueue
local TT, IDs = ns.TT, ns.IDs
local X = TT.Extras

local function enable(t, module, ...)
  local keys = { "module." .. module, ... }
  local saved = {}
  for i = 1, #keys do saved[i] = Schema:Get(keys[i]) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; CQ.Drain() end)
  Schema:Set("module." .. module, true)
  CQ.Drain()
end
ns.TestEnable = enable
local function strip(text) return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function has(tip, text)
  for _, l in ipairs(rawget(tip, "lines") or {}) do
    if type(l) ~= "table" and strip(l):find(text, 1, true) then return true end
  end
  return false
end

Tests:Add("HUD", "tooltip: players' item level and spec are inspected once, cached, never in combat", function(t)
  enable(t, "Tooltip")
  if not H then return end
  t:cleanup(function() H.ttUnit = nil; H.players.party1 = nil; H.inCombat = false; X.cache = {}; X.pending = nil; X.lastAsk = 0 end)
  X.cache, X.pending, X.lastAsk = {}, nil, -100
  H.players.party1, H.ttUnit = true, "party1"
  H.inspect.can.party1, H.inspect.ilvl.party1, H.inspect.spec.party1 = true, 678.4, 71
  H.inspected = {}
  local tip = CreateFrame("GameTooltip")
  H.inCombat = true
  TT.OnUnit(tip)
  t:eq(#H.inspected, 0, "no inspect in combat")
  H.inCombat = false
  TT.OnUnit(tip)
  t:eq(H.inspected[1], "party1", "inspect asked out of combat")
  TT.OnUnit(tip)
  t:eq(#H.inspected, 1, "asked only once while pending")
  rawset(GameTooltip, "lines", nil)
  GameTooltip:Show()
  H.fire("INSPECT_READY", UnitGUID("party1"))
  t:eq(X.cache[UnitGUID("party1")].spec, "Arms", "spec cached")
  t:ok(has(GameTooltip, "Item level 678  -  Arms"), "line added to the open tooltip")
  local tip2 = CreateFrame("GameTooltip")
  TT.OnUnit(tip2)
  t:ok(has(tip2, "Item level 678"), "cached line shown next time")
  t:eq(#H.inspected, 1, "no second inspect while cached")
  Schema:Set("tt.lines.inspect", false)
  t:cleanup(function() Schema:Set("tt.lines.inspect", true) end)
  local tip3 = CreateFrame("GameTooltip")
  TT.OnUnit(tip3)
  t:ok(not has(tip3, "Item level"), "off live")
end)

Tests:Add("HUD", "tooltip: appearance collected, upgrade track and set pieces on items; secrets skipped", function(t)
  enable(t, "Tooltip")
  if not H then return end
  H.transmogHas[4242] = true
  H.upgrade = {}
  H.itemSet[4242], H.itemSet[4243] = 1700, 1700
  H.inventory[1], H.inventory[3] = 4242, 4243
  t:cleanup(function() H.transmogHas[4242] = nil; H.itemSet[4242], H.itemSet[4243] = nil, nil; H.inventory[1], H.inventory[3] = nil, nil end)
  local lines = X.ItemLines(4242, nil)
  t:eq(lines[1][1], "Appearance collected", "transmog line")
  t:eq(lines[2][1], "Set pieces equipped: 2", "set count from equipped slots")
  H.upgrade["link42"] = { trackString = "Hero", currentLevel = 3, maxLevel = 6, maxItemLevel = 684 }
  lines = X.ItemLines(4242, "link42")
  t:eq(lines[2][1], "Track: Hero 3/6  (up to 684)", "upgrade track line")
  H.transmogHas[4242] = nil
  t:eq(X.ItemLines(4242, nil)[1][1], "Appearance not collected", "not collected")
  Schema:Set("tt.lines.transmog", false); Schema:Set("tt.lines.setPieces", false); Schema:Set("tt.lines.upgrade", false)
  t:cleanup(function() Schema:Set("tt.lines.transmog", true); Schema:Set("tt.lines.setPieces", true); Schema:Set("tt.lines.upgrade", true) end)
  t:eq(#X.ItemLines(4242, "link42"), 0, "all three off live")
  Schema:Set("tt.lines.transmog", true); Schema:Set("tt.lines.setPieces", true)
  H.secretMode = true
  t:cleanup(function() H.secretMode = false end)
  t:eq(#X.ItemLines(4242, nil), 0, "secret answers are never compared or shown")
end)

Tests:Add("HUD", "tooltip IDs: achievement criteria rows, artifact powers, follower and pet battle abilities", function(t)
  enable(t, "Tooltip")
  if not H then return end
  H.criteria[500] = { { id = 9001 }, { type = CRITERIA_TYPE_ACHIEVEMENT, asset = 12, id = 9002 }, { flags = 1, id = 9003 }, { id = 9004 } }
  t:cleanup(function() H.criteria[500] = nil end)
  local rows = {}
  local obj = { GetCriteria = function(_, i) rows[i] = rows[i] or CreateFrame("Frame"); return rows[i] end }
  X.OnCriteria(obj, 500)
  t:eq(X.criteriaOf[rows[1]], 9001, "first text row")
  t:eq(X.criteriaOf[rows[2]], 9004, "meta and progress-bar criteria are skipped like Blizzard's rows")
  t:eq(rows[3], nil, "only text rows touched")
  rawset(GameTooltip, "lines", nil)
  rows[2].scripts.OnEnter(rows[2])
  t:ok(has(GameTooltip, "9004"), "criteria ID on mouse-over")
  local f = CreateFrame("Frame")
  t:ok(X.FrameID(f, "garrisonAbility", 314), "follower ability ID on its own tooltip frame")
  t:ok(strip(X.idText[f].text):find("314", 1, true) ~= nil, "text set")
  Schema:Set("tt.ids.garrisonAbility", false)
  t:cleanup(function() Schema:Set("tt.ids.garrisonAbility", true) end)
  t:ok(not X.FrameID(f, "garrisonAbility", 314) and not X.idText[f]:IsShown(), "kind off live hides it")
  IDs.petBattle = true
  t:cleanup(function() IDs.petBattle = false end)
  t:ok(X.FrameID(CreateFrame("Frame"), "petAbility", 112), "pet battle ability IDs still show during pet battles")
  t:eq(X.FrameID(CreateFrame("Frame"), "petAbility", H.secret and H.secret(5) or "x"), false, "secret IDs skipped")
end)

Tests:Add("HUD", "minimap: Phoenix tracking, calendar and mail buttons replace Blizzard's live", function(t)
  if not H then return end
  local MM = ns.MM
  local B = MM.Buttons
  enable(t, "Minimap", "mm.buttons", "mm.buttons.grow", "mm.buttons.size")
  local trackingPart = MM.PARTS.tracking()
  t:eq(B.Phoenix(), false, "Blizzard's buttons by default")
  Schema:Set("mm.buttons", "phoenix")
  t:ok(MM.replaced.tracking and MM.replaced.calendar and MM.replaced.mail, "Blizzard parts marked replaced")
  if trackingPart then t:eq(trackingPart:GetAlpha(), 0, "Blizzard tracking faded (alpha only)") end
  t:ok(B.buttons.tracking:IsShown() and B.buttons.calendar:IsShown(), "Phoenix tracking and calendar shown")
  t:ok(not (B.buttons.mail and B.buttons.mail:IsShown()), "mail button only with new mail")
  H.mail, H.invites, H.mailSenders = true, 2, { "Thrall", "Jaina" }
  t:cleanup(function() H.mail, H.invites, H.mailSenders = false, 0, {} end)
  B.events:GetScript("OnEvent")(B.events, "UPDATE_PENDING_MAIL")
  t:ok(B.buttons.mail:IsShown(), "mail button appears on new mail")
  t:eq(B.buttons.calendar.badge:GetText(), "2", "pending invites badge")
  t:same(B.Tooltip("mail"), { "New mail", "  Thrall", "  Jaina" }, "latest senders listed")
  local x, y = B.Offset(2, 20, 4, "BOTTOMRIGHT", "left")
  t:same({ x, y }, { -28, 4 }, "second button steps left from the corner")
  Schema:Set("mm.buttons.grow", "up")
  t:same({ B.Offset(2, 20, 4, "BOTTOMRIGHT", "up") }, { -4, 28 }, "grow up")
  Schema:Set("mm.buttons.size", 26)
  t:eq(B.buttons.tracking:GetWidth(), 26, "size live")
  Schema:Set("mm.buttons", "blizzard")
  t:eq(MM.replaced.tracking, nil, "Blizzard's back")
  if trackingPart then t:ok(trackingPart:GetAlpha() > 0, "Blizzard tracking visible again") end
  t:eq(B.buttons.tracking:IsShown(), false, "Phoenix buttons hidden")
end)

Tests:Add("HUD", "data bars: LDB feeds, secure hearth and profession blocks, per-spec sets", function(t)
  if not H then return end
  local DB = ns.DataBars
  local X = DB.Extras
  enable(t, "DataBars", "db.bar1.blocks", "db.spec.on", "db.spec.sets")
  -- LDB host through another addon's LibStub
  local clicked
  local feed = { text = "42 kills", OnClick = function(_, button) clicked = button end }
  local ldb = { GetDataObjectByName = function(_, n) return n == "Kills" and feed or nil end,
    DataObjectIterator = function() return pairs({ Kills = feed }) end }
  rawset(_G, "LibStub", { GetLibrary = function(_, name) return name == "LibDataBroker-1.1" and ldb or nil end })
  t:cleanup(function() rawset(_G, "LibStub", nil) end)
  t:same(X.FeedNames(), { "Kills" }, "feeds listed")
  H.professions, H.professionInfo = { 7 }, { [7] = { "Blacksmithing", 87, 100 } }
  H.itemCounts[X.HEARTH] = 1
  t:cleanup(function() H.professions, H.professionInfo = {}, {}; H.itemCounts[X.HEARTH] = nil end)
  Schema:Set("db.bar1.blocks", "ldb:Kills,hearth,prof1,prof2")
  local b = DB.bars[1]
  t:eq(b.cells[1]:GetText(), "42 kills", "feed text")
  t:eq(b.cells[2]:GetText(), "Dornogal", "hearth bind location")
  t:eq(b.cells[3]:GetText(), "Blacksmithing 87/100", "profession")
  t:eq(b.cells[4]:GetText(), "", "no second profession")
  DB.BLOCKS.ldb.run("Kills", b, "RightButton")
  t:eq(clicked, "RightButton", "clicks passed to the feed")
  -- secure overlays: placed out of combat, on UIParent, never in combat
  b.GetLeft, b.GetBottom = function() return 100 end, function() return 10 end
  X.PlaceSecure(1)
  local o2, o3 = X.secure[1][2], X.secure[1][3]
  t:eq(o2:GetAttribute("type"), "item", "hearth uses the item")
  t:eq(o2:GetAttribute("item"), "item:6948", "hearthstone")
  t:eq(o3:GetAttribute("macrotext"), "/cast Blacksmithing", "profession opens by name")
  t:ok(o2:IsShown() and o3:IsShown() and not (X.secure[1][4] and X.secure[1][4]:IsShown()), "only cells with an action get one")
  H.inCombat = true
  t:cleanup(function() H.inCombat = false end)
  H.itemCounts[X.HEARTH] = nil
  X.PlaceSecure(1)
  t:eq(o2:IsShown(), true, "nothing touched in combat")
  H.inCombat = false
  CQ.Drain()
  t:eq(o2:IsShown(), false, "queued placement ran after combat: no hearthstone, no overlay")
  -- per-spec sets (retail: Forever has no specializations)
  if PUI.IS_FOREVER then t:eq(X.SaveSpec(), false, "no spec sets on Forever"); return end
  Schema:Set("db.bar1.blocks", "clock,fps")
  t:ok(X.SaveSpec(), "saved for this spec")
  t:eq(Schema:Get("db.spec.on"), true, "saving turns per-spec on")
  Schema:Set("db.bar1.blocks", "gold")
  t:eq(DB.bars[1].list[1].name, "clock", "this spec keeps its saved list")
  H.specID = 63
  t:cleanup(function() H.specID = nil end)
  X.events:GetScript("OnEvent")(X.events, "PLAYER_SPECIALIZATION_CHANGED", "player")
  t:eq(DB.bars[1].list[1].name, "gold", "another spec without a set uses the normal list")
  H.specID = nil
  t:ok(X.ClearSpec(), "cleared")
  DB.Refresh()
  t:eq(DB.bars[1].list[1].name, "gold", "cleared spec uses the normal list")
end)

Tests:Add("HUDExtras", "paragon progress on the reputation bar and block", function(t)
  if not H then return end
  local DB = PUI.DataBars
  if not (DB and DB.Paragon) then return end
  local saved = H.watched
  t:cleanup(function() H.watched = saved; H.paragon[2600] = nil end)
  H.watched = { name = "Council", factionID = 2600, currentStanding = 42000, currentReactionThreshold = 42000, nextReactionThreshold = 42000 }
  H.paragon[2600] = { 12500, 10000, true }
  local cur, max, reward = DB.Paragon(H.watched)
  t:eq(cur, 2500, "value within the cycle")
  t:eq(max, 10000, "cycle size")
  t:eq(reward, true, "chest waiting")
  local c2, m2 = DB.ProgressValues("rep")
  t:eq(c2 .. "/" .. m2, "2500/10000", "bar uses paragon values")
  H.paragon[2600] = nil
  t:eq(DB.Paragon(H.watched), nil, "not paragon: normal reputation")
end)

Tests:Add("HUDExtras", "focus key sets a secure focus click on unit frames, out of combat", function(t)
  local FK = PUI.FocusKey
  local keys = { "focuskey.modifier", "focuskey.button" }
  local saved = { Schema:Get(keys[1]), Schema:Get(keys[2]) }
  t:cleanup(function() Schema:Set(keys[1], saved[1]); Schema:Set(keys[2], saved[2]); PUI.CombatQueue.Drain() end)
  local b = CreateFrame("Button")
  Schema:Set("focuskey.modifier", "shift"); PUI.CombatQueue.Drain()
  FK.Apply(b, false)
  t:eq(b:GetAttribute("shift-type1"), "focus", "shift-click focuses")
  Schema:Set("focuskey.button", "2"); PUI.CombatQueue.Drain()
  FK.Apply(b, false)
  t:eq(b:GetAttribute("shift-type1"), nil, "old attribute cleared")
  t:eq(b:GetAttribute("shift-type2"), "focus", "right button")
  FK.Apply(b, true)
  t:eq(b:GetAttribute("shift-type2"), nil, "group frames only when asked")
end)

Tests:Add("HUDExtras", "rare and treasure alerts: once each, ignore list, secret names never compared", function(t)
  if not H then return end
  local VG = PUI.Vignettes
  local keys = { "module.Vignettes", "vignette.ignore", "vignette.chat" }
  local saved = {}
  for i, k in ipairs(keys) do saved[i] = Schema:Get(k) end
  t:cleanup(function() for i = #keys, 1, -1 do Schema:Set(keys[i], saved[i]) end; H.vignettes = nil; wipe(VG.seen); VG.last = nil end)
  Schema:Set("module.Vignettes", true)
  H.vignettes = { ["v1"] = { name = "Old Bones", atlasName = "VignetteKill" }, ["v2"] = { name = "Chest", atlasName = "VignetteLoot" },
    ["v3"] = { name = H.secret("Hidden"), atlasName = "VignetteKillElite" } }
  t:eq(VG.Kind(H.vignettes.v1), "rare", "rare from the atlas")
  t:eq(VG.Kind(H.vignettes.v2), "treasure", "treasure")
  H.fire("VIGNETTE_MINIMAP_UPDATED", "v1", true)
  t:eq(VG.last and VG.last.name, "Old Bones", "alerted")
  VG.last = nil
  H.fire("VIGNETTE_MINIMAP_UPDATED", "v1", true)
  t:eq(VG.last, nil, "once per vignette")
  Schema:Set("vignette.ignore", { "chest" })
  H.fire("VIGNETTE_MINIMAP_UPDATED", "v2", true)
  t:eq(VG.last, nil, "ignored by name")
  H.fire("VIGNETTE_MINIMAP_UPDATED", "v3", true)
  t:eq(VG.last and VG.last.kind, "rare", "secret name still alerts, never compared")
end)
