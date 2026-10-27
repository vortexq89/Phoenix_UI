local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio deferred batch B: connectors, resize, grow keys, thumbnails, ElvUI
-- import, Blizzard element page and faded Blizzard elements on state events.
local H = rawget(_G, "HARNESS")
local Tests, Studio, Schema, Layout, CQ = PUI.Tests, PUI.Studio, PUI.Schema, PUI.Layout, PUI.CombatQueue
local Options = PUI.Options

local function elements(t, list)
  local saved, bz, tpl = Schema:Get("layout.positions"), Schema:Get("studio.blizzard.positions"), Schema:Get("studio.templates")
  for id, spec in pairs(list) do
    spec.label = spec.label or id
    spec.owner = spec.owner or "Tests"
    spec.default = spec.default or { point = "CENTER", x = 0, y = 0 }
    Layout:RegisterElement(id, spec)
  end
  t:cleanup(function()
    for id in pairs(list) do
      Layout.elements[id] = nil
      Layout.frames[id] = nil
      for i = #Layout.order, 1, -1 do if Layout.order[i] == id then table.remove(Layout.order, i) end end
    end
    Schema:Set("layout.positions", saved)
    Schema:Set("studio.blizzard.positions", bz)
    Schema:Set("studio.templates", tpl)
  end)
end
local function open(t)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; if Studio:IsOpen() then Studio:Exit(true) end end)
  CQ.InCombat = function() return false end
  return Studio:Open()
end

Tests:Add("StudioB", "connector lines join attached movers at their facing edges", function(t)
  local a, tg = { l = 200, b = 100, w = 50, h = 20 }, { l = 100, b = 100, w = 96, h = 20 }
  t:same({ Studio.ConnectorPoints(a, tg, "RIGHT") }, { 200, 110, 196, 110 }, "right side: left edge to target's right edge")
  t:same({ Studio.ConnectorPoints(a, tg, "BOTTOM") }, { 225, 120, 148, 100 }, "below: top edge to target's bottom")
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  t:ok(open(t), "open")
  Studio.session:Attach("t.b", "t.a", "RIGHT", 4)
  Studio:PlaceAll()
  t:eq(Studio:DrawConnectors(), 1, "one connector")
  t:ok(Studio.connectors[1]:IsShown(), "drawn")
  Tests.Keep(t, "studio.connectors")
  Schema:Set("studio.connectors", false)
  t:eq(Studio:DrawConnectors(), 0, "off: none")
  t:eq(Studio.connectors[1]:IsShown(), false, "hidden live")
end)

Tests:Add("StudioB", "resize grip: width and height for resizable elements, scale for the rest", function(t)
  elements(t, { ["t.r"] = { size = { 100, 40 }, resizable = true }, ["t.f"] = { size = { 100, 40 } } })
  t:same(Studio.ResizeResult("t.r", { point = "CENTER", x = 0, y = 0 }, 150, 60), { w = 150, h = 60 }, "resizable: w/h")
  t:same(Studio.ResizeResult("t.f", { point = "CENTER", x = 0, y = 0 }, 150, 60), { scale = 1.5 }, "fixed size: scale")
  t:same(Studio.ResizeResult("t.f", { point = "CENTER", x = 0, y = 0 }, 1, 1), { scale = 0.25 }, "clamped")
  t:ok(open(t), "open")
  Studio:Select("t.f")
  local m = Studio.movers["t.f"]
  t:ok(m.grip:IsShown(), "grip on the selected mover")
  m:SetSize(200, 80)
  Studio:FinishResize(m)
  t:eq(Studio.session:Get("t.f").scale, 2, "committed to the session")
  Studio.session:Undo()
  t:eq(Studio.session:Get("t.f").scale, nil, "one undo step")
end)

Tests:Add("StudioB", "grow direction keys per element, cycled live from the inspector", function(t)
  t:same(Studio.GrowKeys("ab.bar1"), { "ab.bar1.growX", "ab.bar1.growY" }, "action bar")
  t:same(Studio.GrowKeys("cdm.essential"), { "cdm.essential.growth" }, "cooldown row")
  t:same(Studio.GrowKeys("rf.party"), { "rf.party.growLeft", "rf.party.growUp" }, "party")
  t:same(Studio.GrowKeys("arena.frames"), { "arena.grow", "arena.drGrow" }, "arena")
  t:same(Studio.GrowKeys("uf.player"), {}, "nothing for a single frame")
  Tests.Keep(t, "cdm.essential.growth")
  Schema:Set("cdm.essential.growth", "right")
  t:eq(Studio.NextGrow("cdm.essential.growth"), "left", "cycles")
  t:eq(Studio.NextGrow("rf.party.growUp"), not Schema:Get("rf.party.growUp"), "toggles flip")
  t:ok(open(t), "open")
  Studio:Select("cdm.essential")
  local b = Studio.inspector.grow[1]
  t:ok(b:IsShown(), "grow button in the inspector")
  b:GetScript("OnClick")(b)
  t:eq(Schema:Get("cdm.essential.growth"), "left", "applied now")
end)

Tests:Add("StudioB", "template thumbnails draw the saved layout and apply on click", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } } })
  local rects = Studio.ThumbRects({ W = 1000, H = 800, positions = { ["t.a"] = { point = "BOTTOMLEFT", x = 0, y = 0 } } })
  t:same(rects[1], { id = "t.a", l = 0, b = 0, w = 0.1, h = 0.05 }, "rect in screen fractions")
  t:ok(open(t), "open")
  Studio.session:Move("t.a", 33, 0)
  t:ok(Studio.SaveTemplate(Studio.session, "Healer"), "saved")
  Studio:ToggleLayouts()
  t:eq(Studio:DrawThumbnails(), 1, "one thumbnail")
  local f = Studio.layouts.thumbs[1]
  t:eq(f.template, "Healer", "named")
  Studio.session:Move("t.a", 0, 0)
  f:GetScript("OnClick")(f)
  t:eq(Studio.session:Get("t.a").x, 33, "click applies it")
end)

Tests:Add("StudioB", "ElvUI import: read-only plan of the movers Phoenix has", function(t)
  local Import = PUI.Movers.Import
  t:same(Import.ParseElvPoint("BOTTOM,ElvUIParent,BOTTOM,-278.4,110"), { point = "BOTTOM", x = -278, y = 110 }, "parsed")
  t:eq(Import.ParseElvPoint("TOPLEFT,ElvUF_Player,BOTTOMLEFT,0,0"), nil, "anchored to another frame: skipped")
  local db = { profiles = { Default = { movers = { ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-278,110",
    ElvAB_2 = "BOTTOM,ElvUIParent,BOTTOM,0,40", WeirdMover = "CENTER,UIParent,CENTER,0,0" } } } }
  local plan = Import.ElvUI(db, "Default")
  t:eq(plan.count, 2, "two Phoenix elements")
  t:same(plan.positions["uf.player"], { point = "BOTTOM", x = -278, y = 110 }, "player frame")
  t:same(plan.positions["ab.bar2"], { point = "BOTTOM", x = 0, y = 40 }, "bar 2")
  t:same(plan.skipped, { "WeirdMover" }, "unknown mover listed")
  t:eq(db.profiles.Default.movers.ElvAB_2, "BOTTOM,ElvUIParent,BOTTOM,0,40", "ElvUI's settings untouched")
  t:eq(select(2, Import.ElvUI({}, nil)), "ElvUI settings were not found (is ElvUI enabled?)", "no ElvUI")
end)

Tests:Add("StudioB", "Blizzard elements page: list, hide, show and reset live", function(t)
  Tests.Keep(t, "studio.blizzard.enabled")
  Tests.Keep(t, "studio.blizzard.positions")
  Schema:Set("studio.blizzard.enabled", true)
  local P = Options.BlizzardPage
  local list = P.Entries()
  t:eq(#list, PUI.Movers:Count(), "every catalogued element")
  local function state(id) for _, e in ipairs(P.Entries()) do if e.id == id then return e.state end end end
  t:eq(state("bz.PlayerFrame"), "Edit Mode", "Edit Mode frames marked")
  P.SetHidden("bz.UIErrorsFrame", true)
  t:eq(state("bz.UIErrorsFrame"), "Hidden", "hidden")
  t:eq(UIErrorsFrame:GetAlpha(), 0, "applied live")
  P.SetHidden("bz.UIErrorsFrame", false)
  t:eq(state("bz.UIErrorsFrame"), "Moved", "shown, position kept")
  P.Reset("bz.UIErrorsFrame")
  t:eq(state("bz.UIErrorsFrame"), "Default", "reset")
  t:ok(#P.Entries("error") >= 1, "search filter")
  Options:Open("Blizzard")
  t:ok(Options.views.blizzard and Options.views.blizzard:IsShown() and Options.views.blizzard.count > 0, "page renders")
  Options.frame:Hide()
end)

Tests:Add("StudioB", "faded Blizzard elements follow combat and other state events", function(t)
  if not H then return end
  Tests.Keep(t, "studio.blizzard.enabled")
  Tests.Keep(t, "studio.blizzard.positions")
  local V = PUI.Visibility
  local probe = V.Probe
  t:cleanup(function() V.Probe = probe; V.state = probe() end)
  local combat = false
  V.Probe = function() local s = probe(); s.combat = combat; return s end
  Schema:Set("studio.blizzard.enabled", true)
  Schema:Set("studio.blizzard.positions", { ["bz.UIErrorsFrame"] = { point = "TOP", x = 0, y = -100, fade = { combat = 0.3, ooc = 0.8 } } })
  t:ok(Layout.fadeArmed, "state events armed for a Blizzard fade")
  combat = true
  Layout.Refade()
  t:eq(UIErrorsFrame:GetAlpha(), 0.3, "in combat")
  combat = false
  Layout.Refade()
  t:eq(UIErrorsFrame:GetAlpha(), 0.8, "out of combat")
end)
