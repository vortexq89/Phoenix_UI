local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Layout, Schema, CQ = PUI.Tests, PUI.Layout, PUI.Schema, PUI.CombatQueue

-- Registers a throwaway element and removes it (and any saved position) afterwards.
local function element(t, id)
  Layout:RegisterElement(id, { label = "Test box", owner = "Tests", size = { 50, 20 }, default = { point = "TOP", x = 0, y = -50 } })
  local saved = Schema:Get("layout.positions")
  t:cleanup(function()
    Layout.elements[id] = nil
    Layout.frames[id] = nil
    for i = #Layout.order, 1, -1 do if Layout.order[i] == id then table.remove(Layout.order, i) end end
    Schema:Set("layout.positions", saved)
  end)
end
Tests.LayoutElement = element

-- A frame-like probe that records SetPoint.
local function frame(protected)
  local f = {}
  function f:ClearAllPoints() self.point = nil end
  function f:SetPoint(p, _, _, x, y) self.point = { p, x, y } end
  function f:IsProtected() return protected end
  return f
end
Tests.PointProbe = frame

Tests:Add("Layout", "default position, saved position and live apply", function(t)
  element(t, "tests.box")
  t:same(Layout:Position("tests.box"), { point = "TOP", x = 0, y = -50 }, "default")
  local f = frame(false)
  Layout:Place(f, "tests.box")
  t:same(f.point, { "TOP", 0, -50 }, "placed at default")
  local pos = Schema:Get("layout.positions")
  pos["tests.box"] = { point = "CENTER", x = 12, y = 34 }
  Schema:Set("layout.positions", pos)
  t:same(f.point, { "CENTER", 12, 34 }, "saving re-places registered frames live")
  local copy = Schema:Get("layout.positions")
  copy["tests.box"].x = 999
  t:eq(Schema:Get("layout.positions")["tests.box"].x, 12, "Get returns a copy")
  t:eq(Schema:Def("layout.positions").hidden, true, "layout keys are hidden")
end)

Tests:Add("Layout", "a protected frame is placed after combat", function(t)
  element(t, "tests.box")
  local probe = CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe end)
  CQ.InCombat = function() return true end
  local f = frame(true)
  Layout:Place(f, "tests.box")
  t:eq(f.point, nil, "not moved in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:same(f.point, { "TOP", 0, -50 }, "moved once combat ended")
end)
