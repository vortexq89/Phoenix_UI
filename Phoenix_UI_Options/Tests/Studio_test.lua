local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Studio, Schema, CQ = PUI.Tests, PUI.Studio, PUI.Schema, PUI.CombatQueue

Tests:Add("Studio", "nudge, snap, undo and redo", function(t)
  Tests.LayoutElement(t, "tests.box")
  local s = Studio.Session.New()
  t:same(s:Get("tests.box"), { point = "TOP", x = 0, y = -50 }, "starts at the saved/default position")
  s:Nudge("tests.box", 1, 0, 1)
  s:Nudge("tests.box", 0, -1, 10)
  s:Nudge("tests.box", 1, 0, 100)
  t:same(s:Get("tests.box"), { point = "TOP", x = 101, y = -60 }, "1/10/100 nudges")
  t:eq(Studio.Snap(37, 16), 32, "snap down"); t:eq(Studio.Snap(41, 16), 48, "snap up"); t:eq(Studio.Snap(-9, 16), -16, "snap negative")
  t:eq(s:Undo(), "tests.box", "undo")
  t:same(s:Get("tests.box"), { point = "TOP", x = 1, y = -60 }, "after undo")
  s:Redo()
  t:eq(s:Get("tests.box").x, 101, "after redo")
  s:Undo(); s:Undo(); s:Undo()
  t:ok(not s:Dirty(), "back to start")
  t:eq(s:Undo(), nil, "nothing left to undo")
  s:Move("tests.box", 5, 5, "CENTER")
  t:eq(#s.redo, 0, "a new move clears redo")
  local x, y = Studio.CenterOffset(1000, 600, 1920, 1080)
  t:eq(x, 40, "centre offset x"); t:eq(y, 60, "centre offset y")
end)

Tests:Add("Studio", "refused in combat; save writes only moved elements; exit discards", function(t)
  Tests.LayoutElement(t, "tests.box")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; if Studio:IsOpen() then Studio:Exit(true) end end)
  CQ.InCombat = function() return true end
  t:eq(Studio:Open(), false, "refused in combat")
  CQ.InCombat = function() return false end
  t:ok(Studio:Open(), "opens out of combat")
  local f = Tests.PointProbe(false)
  PUI.Layout:Place(f, "tests.box")
  Studio.session:Nudge("tests.box", 0, 1, 10)
  Studio:PlaceMover("tests.box")
  t:same(f.point, { "TOP", 0, -40 }, "live preview of the element")
  t:eq(Studio:Exit(), false, "dirty exit asks first")
  t:ok(Studio:Exit(), "second exit discards")
  t:same(f.point, { "TOP", 0, -50 }, "element back at the saved position")
  Studio:Open()
  Studio.session:Nudge("tests.box", 1, 0, 100)
  Studio:Save()
  t:ok(not Studio:IsOpen(), "closed after save")
  local saved = Schema:Get("layout.positions")
  t:same(saved["tests.box"], { point = "TOP", x = 100, y = -50 }, "moved element saved")
  t:eq(saved["sentinel.toast"], nil, "untouched elements not stored")
  t:same(f.point, { "TOP", 100, -50 }, "element at the saved position")
end)

Tests:Add("Studio", "toolbar filter, grid cycle, inspector fields and mirror", function(t)
  Tests.LayoutElement(t, "tests.box")
  local probe = CQ.InCombat
  local grid, show = Schema:Get("studio.gridSize"), Schema:Get("studio.showGrid")
  t:cleanup(function()
    CQ.InCombat = probe
    if Studio:IsOpen() then Studio:Exit(true) end
    Schema:Set("studio.gridSize", grid); Schema:Set("studio.showGrid", show)
  end)
  CQ.InCombat = function() return false end
  Studio:Open()
  t:eq(Studio.Category("tests.box"), "info", "unknown owners file under Info")
  Studio.filter = "bars"; Studio:ApplyFilter()
  t:ok(not Studio.movers["tests.box"]:IsShown(), "filter hides other categories")
  Studio.filter = "all"; Studio:ApplyFilter()
  t:ok(Studio.movers["tests.box"]:IsShown(), "All shows every element")
  Schema:Set("studio.gridSize", 64); Schema:Set("studio.showGrid", true)
  Studio:CycleGrid()
  t:eq(Schema:Get("studio.showGrid"), false, "64 cycles to off")
  Studio:CycleGrid()
  t:eq(Schema:Get("studio.gridSize"), 8, "off cycles to 8")
  Studio:Select("tests.box")
  t:ok(Studio.inspector:IsShown(), "inspector opens on select")
  t:eq(Studio.inspector.x:GetText(), "0", "x field")
  Studio.session:Move("tests.box", 40, -50, "LEFT")
  Studio:PlaceMover("tests.box")
  t:same(Studio.session:Get("tests.box"), { point = "LEFT", x = 40, y = -50 }, "moved")
end)

Tests:Add("Studio", "combat suspends and resumes the session", function(t)
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; if Studio.overlay then Studio:Exit(true) end end)
  CQ.InCombat = function() return false end
  Studio:Open()
  local session = Studio.session
  Studio:Suspend()
  t:ok(not Studio.overlay:IsShown(), "hidden in combat")
  CQ.InCombat = function() return true end
  return function()
    t:ok(not Studio.overlay:IsShown(), "still hidden while in combat")
    CQ.InCombat = function() return false end
    CQ.Drain()
    t:ok(Studio.overlay:IsShown(), "back after combat")
    t:eq(Studio.session, session, "same session")
  end
end)
