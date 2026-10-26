local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Studio, Schema, Layout, CQ = PUI.Tests, PUI.Studio, PUI.Schema, PUI.Layout, PUI.CombatQueue

-- Registers throwaway elements (sizes in UI pixels) and removes them afterwards.
local function elements(t, list)
  local saved, bz = Schema:Get("layout.positions"), Schema:Get("studio.blizzard.positions")
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
  end)
end

local function session(t, recs)
  local s = Studio.Session.New({ blizzard = false, W = 1000, H = 800 })
  for id, r in pairs(recs or {}) do s.pos[id] = r end
  s.start = Schema.Copy(s.pos)
  return s
end

Tests:Add("Studio2", "rects follow scale and edge-to-edge attach with matched sizes", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  local pos = { ["t.a"] = { point = "CENTER", x = 0, y = 0 }, ["t.b"] = { point = "CENTER", x = 0, y = 0, scale = 2 } }
  local a, b = Layout:Rect("t.a", pos, 1000, 800), Layout:Rect("t.b", pos, 1000, 800)
  t:same(a, { l = 450, b = 380, w = 100, h = 40 }, "centred rect")
  t:same(b, { l = 450, b = 380, w = 100, h = 40 }, "scale doubles size")
  pos["t.b"] = { point = "CENTER", x = 0, y = 0, attach = { to = "t.a", side = "RIGHT", gap = 4, matchH = true } }
  t:same(Layout:Rect("t.b", pos, 1000, 800), { l = 554, b = 380, w = 50, h = 40 }, "attached right of a, height matched")
  pos["t.b"].attach = { to = "t.a", side = "BOTTOM", gap = 2, align = "START", matchW = true }
  t:same(Layout:Rect("t.b", pos, 1000, 800), { l = 450, b = 358, w = 100, h = 20 }, "attached below, left aligned, width matched")
  t:ok(Layout.WouldCycle({ ["t.a"] = { attach = { to = "t.b" } } }, "t.b", "t.a"), "cycle detected")
  t:ok(not Layout.WouldCycle(pos, "t.a", "t.c"), "no cycle")
  t:ok(Layout.ValidRecord({ point = "TOP", x = 1, y = 2, scale = 1.5, strata = "HIGH", fade = { combat = 1, hover = true } }), "valid record")
  t:ok(not Layout.ValidRecord({ point = "TOP", x = 1, y = 2, scale = 9 }), "scale out of range refused")
  t:ok(not Layout.ValidRecord({ point = "TOP", x = 1, y = 2, attach = { to = "x", side = "UP" } }), "bad side refused")
  t:ok(not Layout.ValidRecord({ point = "TOP", x = 1, y = 2, strata = "TOOLTIP" }), "strata above DIALOG refused")
end)

Tests:Add("Studio2", "placing: attach anchors to the target frame; look applied; cycles reported", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  local function probe()
    local f = { calls = {} }
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetScale(v) self.scale = v end
    function f:SetAlpha(v) self.alpha = v end
    function f:SetFrameStrata(v) self.strata = v end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetHeight(v) self.h = v end
    function f:GetHeight() return 40 end
    function f:IsProtected() return false end
    return f
  end
  local fa, fb = probe(), probe()
  Layout:Place(fa, "t.a")
  Layout:Place(fb, "t.b")
  Schema:Set("layout.positions", { ["t.b"] = { point = "CENTER", x = 0, y = 0, scale = 1.2, alpha = 0.5, strata = "HIGH", clickThrough = true,
    attach = { to = "t.a", side = "RIGHT", gap = 6, matchH = true } } })
  t:eq(fb.point[1], "LEFT", "own point"); t:eq(fb.point[2], fa, "relative to the target frame"); t:eq(fb.point[3], "RIGHT", "target edge")
  t:eq(fb.point[4], 6, "gap")
  t:eq(fb.h, 40, "height matched to the target")
  t:eq(fb.scale, 1.2, "scale"); t:eq(fb.alpha, 0.5, "alpha"); t:eq(fb.strata, "HIGH", "strata"); t:eq(fb.mouse, false, "click-through")
  Schema:Set("layout.positions", { ["t.a"] = { point = "CENTER", x = 0, y = 0, attach = { to = "t.b", side = "LEFT" } },
    ["t.b"] = { point = "TOP", x = 5, y = -5, attach = { to = "t.a", side = "RIGHT" } } })
  t:ok(Layout.cycles["t.a"] and Layout.cycles["t.b"], "both ends of the cycle reported")
  t:eq(fb.point[1], "TOP", "a cycle falls back to the own anchor")
  t:same(Layout.Order({ ["t.b"] = { attach = { to = "t.a" } } }, { "t.b", "t.a" }), { "t.a", "t.b" }, "targets placed before dependents")
end)

Tests:Add("Studio2", "alpha by state follows the documented priority", function(t)
  local F = Layout.FadeAlpha
  local fade = { combat = 1, ooc = 0.3, mounted = 0.1, resting = 0.2, petBattle = 0, hover = true }
  t:eq(F(fade, { combat = true, mounted = true }, false), 1, "combat beats mounted")
  t:eq(F(fade, { combat = false, mounted = true }, false), 0.1, "mounted beats out of combat")
  t:eq(F(fade, { combat = false, resting = true }, false), 0.2, "resting")
  t:eq(F(fade, { combat = false }, false), 0.3, "out of combat")
  t:eq(F(fade, { combat = false }, true), 1, "mouse-over shows it")
  t:eq(F(fade, { petBattle = true }, true), 0, "pet battle beats mouse-over")
  t:eq(F({ combat = 0.8 }, { combat = false }, false), nil, "unset states leave the alpha alone")
end)

Tests:Add("Studio2", "multi-select, align, distribute, group move: one undo step each", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } }, ["t.c"] = { size = { 30, 30 } } })
  local s = session(t, { ["t.a"] = { point = "CENTER", x = -200, y = 100 }, ["t.b"] = { point = "CENTER", x = 0, y = 0 },
    ["t.c"] = { point = "CENTER", x = 300, y = -50 } })
  s:Select("t.a"); s:Select("t.b", true); s:Select("t.c", true)
  t:same(s:Selection(), { "t.a", "t.b", "t.c" }, "three selected")
  s:Select("t.c", true)
  t:same(s:Selection(), { "t.a", "t.b" }, "shift-click toggles off")
  s:Select("t.c", true)
  t:ok(s:Align(s:Selection(), "left"), "aligned")
  t:eq(s:Rect("t.b").l, s:Rect("t.a").l, "left edges match"); t:eq(s:Rect("t.c").l, s:Rect("t.a").l, "left edges match (c)")
  t:eq(#s.undo, 1, "one undo step")
  s:Undo()
  t:eq(s:Get("t.b").x, 0, "align undone")
  t:ok(s:Distribute({ "t.a", "t.b", "t.c" }, "h"), "distributed")
  local a, b, c = s:Rect("t.a"), s:Rect("t.b"), s:Rect("t.c")
  t:ok(math.abs((b.l - (a.l + a.w)) - (c.l - (b.l + b.w))) <= 1, "equal gaps")
  s:MoveGroup({ "t.a", "t.b" }, 10, -10)
  t:eq(#s.undo, 2, "group move is one step")
  t:ok(s:SelectBox(0, 0, 1000, 800, false, { ["t.a"] = true, ["t.b"] = true, ["t.c"] = true }) == 3, "box select picks everything inside")
end)

Tests:Add("Studio2", "attach, cycles refused, detach keeps the place, nudge edits the gap", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  local s = session(t)
  t:ok(s:Attach("t.b", "t.a", "RIGHT", 4, "CENTER", nil, true), "attached")
  local ok, why = s:Attach("t.a", "t.b", "LEFT")
  t:ok(not ok and why:find("itself"), "cycle refused with a reason")
  local r = s:Rect("t.b")
  s:Nudge("t.b", 1, 0, 10)
  t:eq(s:Get("t.b").attach.gap, 14, "nudge widens the gap of an attached element")
  r = s:Rect("t.b")
  t:ok(s:Detach("t.b"), "detached")
  t:eq(s:Get("t.b").attach, nil, "no attach")
  local r2 = s:Rect("t.b")
  t:eq(math.floor(r2.l + r2.w / 2 + 0.5), math.floor(r.l + r.w / 2 + 0.5), "same centre x after detach")
  t:eq(math.floor(r2.b + r2.h / 2 + 0.5), math.floor(r.b + r.h / 2 + 0.5), "same centre y after detach")
end)

Tests:Add("Studio2", "snap to elements and grid; distance labels; overlap picking", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  local s = session(t, { ["t.a"] = { point = "CENTER", x = 0, y = 0 }, ["t.b"] = { point = "CENTER", x = 200, y = 0 } })
  -- t.b's left edge (x - 25) near t.a's right edge (550 - 500 = 50) -> centre 75
  local vis = { ["t.a"] = true, ["t.b"] = true }
  local x, y, guides = s:SnapCenter("t.b", 79, 3, { mode = "elements", distance = 8, visible = vis })
  t:eq(x, 75, "snapped to the neighbour's edge"); t:eq(y, 0, "centre lines snap too")
  t:eq(guides[1].to, "t.a", "guide names the element")
  x, y = s:SnapCenter("t.b", 203, 37, { mode = "grid", grid = 16 })
  t:eq(x, 208, "grid x"); t:eq(y, 32, "grid y")
  x = s:SnapCenter("t.b", 300, 0, { mode = "elements", distance = 4, visible = vis })
  t:eq(x, 300, "nothing close: unchanged")
  local d = s:Distances("t.b", vis)
  t:eq(d.left.gap, 125, "gap to the element on the left"); t:eq(d.left.to, "t.a", "named")
  t:eq(d.right.to, "screen", "screen edge on the right")
  s.pos["t.b"] = { point = "CENTER", x = 0, y = 0 }
  t:same(s:ElementsAt(500, 400, vis), { "t.b", "t.a" }, "stacked: smallest first")
end)

Tests:Add("Studio2", "layout strings: export, preview, scale conversion, apply as one undo step", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } } })
  local s = session(t)
  s:Move("t.a", 100, 50, "CENTER")
  s:Set("t.a", "scale", 1.5)
  local str = Studio.Export(s, "Mine")
  t:eq(str:sub(1, #Studio.PREFIX), Studio.PREFIX, "prefixed")
  local other = Studio.Session.New({ blizzard = false, W = 2000, H = 1600 })
  local plan = Studio.Decode(str, other)
  t:ok(plan and plan.known == 1 and plan.changed == 1, "previewed")
  t:ok(plan.scaled, "scaled to the bigger screen")
  t:eq(plan.positions["t.a"].x, 200, "x scaled"); t:eq(plan.positions["t.a"].scale, 1.5, "scale kept")
  t:ok(Studio.ApplyPlan(other, plan), "applied")
  t:eq(#other.undo, 1, "one undo step")
  local bad, why = Studio.Decode("!PUI1:nope")
  t:ok(not bad and why:find("layout string"), "wrong prefix explained")
  t:ok(not Studio.Decode(Studio.PREFIX .. "garbage"), "damaged string refused")
end)

Tests:Add("Studio2", "templates save, apply and delete; explain lists what drives an element", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 }, keys = "studio" } })
  local before = Schema:Get("studio.templates")
  t:cleanup(function() Schema:Set("studio.templates", before) end)
  local s = session(t)
  s:Move("t.a", 30, 40)
  t:ok(Studio.SaveTemplate(s, "Arena"), "saved")
  t:ok(not Studio.SaveTemplate(s, "  "), "needs a name")
  local s2 = session(t)
  t:ok(Studio.ApplyTemplate(s2, "Arena"), "applied")
  t:eq(s2:Get("t.a").x, 30, "template position")
  t:ok(Studio.DeleteTemplate("Arena"), "deleted")
  t:eq(#Studio.Templates(), 0, "gone")
  s:Set("t.a", "hide", true)
  local e = Studio.ExplainElement("t.a", s)
  t:ok(e.keys > 5, "explain finds the element's settings")
  local hidden = false
  for _, l in ipairs(e.lines) do if l:find("Hidden by Studio") then hidden = true end end
  t:ok(hidden, "explain names the Studio look")
end)

Tests:Add("Studio2", "Edit Mode elements are locked; Blizzard list starts off", function(t)
  t:eq(Schema:Def("studio.blizzard.enabled").default, false, "Blizzard elements off by default")
  t:eq(Schema:Def("studio.windows.enabled").default, false, "moving Blizzard windows off by default")
  local s = Studio.Session.New({ blizzard = true, W = 1000, H = 800 })
  t:ok(s:Has("bz.PlayerFrame") and s:Locked("bz.PlayerFrame"), "Edit Mode owns the player frame")
  t:ok(not s:Move("bz.PlayerFrame", 10, 10), "Edit Mode element cannot be moved")
  t:ok(s:Move("bz.UIErrorsFrame", 10, 10), "a non Edit Mode element can")
  local phoenix, bz = s:Saved()
  t:ok(bz["bz.UIErrorsFrame"] and not bz["bz.PlayerFrame"], "only changed Blizzard elements are stored")
  t:eq(phoenix["bz.UIErrorsFrame"], nil, "Blizzard records never go into the Phoenix layout")
  local off = Studio.Session.New({ blizzard = false })
  t:ok(not off:Has("bz.UIErrorsFrame"), "no Blizzard movers while the list is off")
end)

Tests:Add("Studio2", "per-spec layout: Studio saves into the spec layer", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } } })
  local O = PUI.Overrides
  local ctx = O.Context
  t:cleanup(function() O.Context = ctx; O:EditAs(nil); O:Clear("spec", 2, "layout.positions") end)
  O.Context = function() return 2, "solo" end
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; if Studio:IsOpen() then Studio:Exit(true) end end)
  CQ.InCombat = function() return false end
  Studio:Open()
  Studio:SetLayer("spec")
  Studio.session:Move("t.a", 77, 0)
  Studio:Save()
  t:eq(O:Get("spec", 2, "layout.positions")["t.a"].x, 77, "stored as a spec override")
  t:eq(Layout:Position("t.a").x, 77, "active for this spec")
  O.Context = function() return 1, "solo" end
  t:eq(Layout:Position("t.a").x, 0, "another spec keeps the profile layout")
  O:EditAs(nil)
end)

Tests:Add("Studio2", "Studio UI: multi-select align bar, box select, wheel cycle, explain, layouts", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } }, ["t.b"] = { size = { 50, 20 } } })
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; if Studio:IsOpen() then Studio:Exit(true) end end)
  CQ.InCombat = function() return false end
  t:ok(Studio:Open(), "open")
  Studio:Select("t.a")
  t:ok(not Studio.alignBar:IsShown(), "align bar hidden for one")
  Studio:Select("t.b", true)
  t:ok(Studio.alignBar:IsShown(), "align bar for two")
  t:ok(Studio:CycleAt("t.b") ~= false, "wheel picks the stacked element")
  local e = Studio:Explain("t.a")
  t:ok(e and Studio.explain:IsShown(), "explain panel")
  Studio:ToggleLayouts()
  t:ok(Studio.layouts:IsShown() and not Studio.explain:IsShown(), "layouts panel replaces explain")
  Studio:Select("t.a")
  Studio.inspector.scale:SetText("150")
  Studio.inspector.scale:GetScript("OnEnterPressed")(Studio.inspector.scale)
  t:eq(Studio.session:Get("t.a").scale, 1.5, "scale field edits the session")
  t:ok(Studio.session:Dirty(), "dirty")
  t:ok(Studio.ticksClean == nil and not PUI.Ticker:IsRegistered("studio.drag"), "no drag ticker while idle")
end)

Tests:Add("Studio2", "MoveAny import: read-only preview, Edit Mode frames left alone", function(t)
  local ma = {
    PROFILES = { DEFAULT = { ELES = {
      POINTS = { UIErrorsFrame = { "TOP", "UIParent", "TOP", 10, -120 }, PlayerFrame = { "CENTER", "UIParent", "CENTER", 1, 2 },
        SomeAddonFrame = { "CENTER", "UIParent", "CENTER", 0, 0 } },
      OPTIONS = { UIErrorsFrame = { SCALE = 0.8, ALPHAINCOMBAT = 0.5 } } } } } }
  local copy = Schema.Copy(ma)
  local plan = PUI.Movers.Import.MoveAny(ma)
  t:eq(plan.count, 1, "one element imported")
  t:same(plan.blizzard["bz.UIErrorsFrame"], { point = "TOP", x = 10, y = -120, scale = 0.8, fade = { combat = 0.5 } }, "point, scale, combat alpha")
  t:same(plan.editMode, { "Player frame" }, "Edit Mode frame listed, not imported")
  t:same(plan.skipped, { "SomeAddonFrame" }, "unknown frames skipped")
  t:same(ma, copy, "MoveAny settings untouched")
  local none, why = PUI.Movers.Import.MoveAny({})
  t:ok(not none and why:find("not found"), "missing MoveAny explained")
end)

Tests:Add("Studio2", "clearing a look field puts the module's own look back live", function(t)
  elements(t, { ["t.a"] = { size = { 100, 40 } } })
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetAlpha(0.8); f:SetScale(1)
  function f:IsMouseEnabled() return true end
  Layout:Place(f, "t.a")
  Schema:Set("layout.positions", { ["t.a"] = { point = "CENTER", x = 0, y = 0, hide = true, scale = 2 } })
  t:eq(f:GetAlpha(), 0, "hidden"); t:eq(f:GetScale(), 2, "scaled")
  Schema:Set("layout.positions", { ["t.a"] = { point = "CENTER", x = 0, y = 0 } })
  t:eq(f:GetAlpha(), 0.8, "module alpha back"); t:eq(f:GetScale(), 1, "module scale back")
end)
