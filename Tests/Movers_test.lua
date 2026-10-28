local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Schema, Movers, Windows, FL, CQ = PUI.Tests, PUI.Schema, PUI.Movers, PUI.Windows, PUI.FrameLedger, PUI.CombatQueue

-- A stand-in Blizzard frame; whatever the harness had under that name comes back afterwards.
local function blizzardFrame(t, name)
  local prev = rawget(_G, name)
  local f = CreateFrame("Frame", name, UIParent)
  f.secure = false
  t:cleanup(function() rawset(_G, name, prev) end)
  return f
end

Tests:Add("Movers", "catalog of about 130 Blizzard elements, Edit Mode owners marked", function(t)
  t:ok(Movers:Count() >= 125, "about 130 elements (" .. Movers:Count() .. ")")
  local seen, em = {}, 0
  for _, c in ipairs(Movers.CATALOG) do
    t:ok(not seen[c[1]], "listed once: " .. c[1])
    seen[c[1]] = true
    if c[4] then em = em + 1 end
    t:ok(Movers.CATEGORY_LABELS[c[3]] ~= nil, "category " .. c[3])
  end
  t:ok(em >= 30, "Edit Mode owned frames marked (" .. em .. ")")
  t:ok(Movers:IsEditMode("bz.MinimapCluster") and not Movers:IsEditMode("bz.UIErrorsFrame"), "minimap is Edit Mode's; UI errors are not")
end)

Tests:Add("Movers", "changes go through the FrameLedger and are restored when turned off", function(t)
  local f = blizzardFrame(t, "UIErrorsFrame")
  local em = blizzardFrame(t, "PlayerFrame")
  local on, saved = Schema:Get("studio.blizzard.enabled"), Schema:Get("studio.blizzard.positions")
  t:cleanup(function() Schema:Set("studio.blizzard.positions", saved); Schema:Set("studio.blizzard.enabled", on) end)
  local function track(fr) fr.points = {}; function fr:SetPoint(...) self.points[#self.points + 1] = { ... } end end
  track(f); track(em)
  Schema:Set("studio.blizzard.positions", { ["bz.UIErrorsFrame"] = { point = "TOP", x = 0, y = -90, scale = 0.9, hide = true },
    ["bz.PlayerFrame"] = { point = "CENTER", x = 1, y = 1 } })
  t:eq(FL:Owner("bz.UIErrorsFrame"), nil, "nothing touched while the list is off")
  Schema:Set("studio.blizzard.enabled", true)
  t:eq(FL:Owner("bz.UIErrorsFrame"), "Studio", "taken through the ledger")
  t:eq(f.points[#f.points][1], "TOP", "placed")
  t:eq(f:GetScale(), 0.9, "scaled")
  t:eq(FL:Owner("bz.PlayerFrame"), nil, "Edit Mode frame never taken")
  t:eq(#em.points, 0, "Edit Mode frame never moved")
  Schema:Set("studio.blizzard.enabled", false)
  t:eq(FL:Owner("bz.UIErrorsFrame"), nil, "released when turned off")
  t:eq(f:GetScale(), 1, "scale restored")
end)

Tests:Add("Movers", "protected Blizzard frames wait for combat to end", function(t)
  local f = blizzardFrame(t, "ExtraActionBarFrame")
  f.secure = true
  local on, saved, probe = Schema:Get("studio.blizzard.enabled"), Schema:Get("studio.blizzard.positions"), CQ.InCombat
  t:cleanup(function() CQ.InCombat = probe; Schema:Set("studio.blizzard.positions", saved); Schema:Set("studio.blizzard.enabled", on) end)
  CQ.InCombat = function() return true end
  Schema:Set("studio.blizzard.enabled", true)
  Schema:Set("studio.blizzard.positions", { ["bz.ExtraActionBarFrame"] = { point = "BOTTOM", x = 0, y = 200, scale = 1.3 } })
  t:eq(f:GetScale(), 1, "not changed in combat")
  CQ.InCombat = function() return false end
  CQ.Drain()
  t:eq(f:GetScale(), 1.3, "applied after combat")
end)

Tests:Add("Movers", "Blizzard windows: off by default, clamped on screen, released when off", function(t)
  local x, y, moved = Windows.Clamp(5000, 0, 400, 300, 1920, 1080, 40)
  t:eq(x, 960 + 200 - 40, "kept on screen"); t:ok(moved, "reported")
  x, y, moved = Windows.Clamp(10, -20, 400, 300, 1920, 1080)
  t:ok(x == 10 and y == -20 and not moved, "on-screen positions untouched")
  t:ok(#Windows.CATALOG >= 45, "about 50 windows")
  local f = blizzardFrame(t, "CharacterFrame")
  local on, pos = Schema:Get("studio.windows.enabled"), Schema:Get("studio.windows.positions")
  t:cleanup(function() Schema:Set("studio.windows.positions", pos); Schema:Set("studio.windows.enabled", on); Windows.handles.CharacterFrame = nil end)
  t:eq(Windows.handles.CharacterFrame, nil, "no drag strip while off")
  Schema:Set("studio.windows.enabled", true)
  local h = Windows.handles.CharacterFrame
  t:ok(h ~= nil and h:IsShown(), "drag strip added")
  function f:GetCenter() return 1060, 640 end
  h:GetScript("OnDragStart")(h)
  t:eq(FL:Owner("win.CharacterFrame"), "Studio", "window taken through the ledger on first drag")
  h:GetScript("OnDragStop")(h)
  t:same(Schema:Get("studio.windows.positions").CharacterFrame, { point = "CENTER", x = 100, y = 100 }, "position remembered")
  Schema:Set("studio.windows.enabled", false)
  t:ok(not h:IsShown(), "strip hidden when off")
  t:eq(FL:Owner("win.CharacterFrame"), nil, "window released when off")
end)

Tests:Add("Movers", "Studio key goes through the binding ledger", function(t)
  local key = Schema:Get("studio.toggleKey")
  t:cleanup(function() Schema:Set("studio.toggleKey", key) end)
  Schema:Set("studio.toggleKey", "CTRL-SHIFT-L")
  local found
  for _, b in ipairs(PUI.Bindings:List()) do if b.owner == "Studio" then found = b end end
  t:ok(found and found.key == "CTRL-SHIFT-L" and found.action == "PhoenixUIStudioToggleButton", "claimed for Studio")
  Schema:Set("studio.toggleKey", "")
  found = nil
  for _, b in ipairs(PUI.Bindings:List()) do if b.owner == "Studio" then found = b end end
  t:eq(found, nil, "released when emptied")
end)

Tests:Add("Movers", "every Phoenix module frame registers a Studio mover", function(t)
  local want = { "uf.player", "uf.target", "rf.party", "rf.raid", "ab.bar1", "cdm.essential", "rb.stack", "qt.tracker", "vault.window",
    "embers.window1", "ascent.timer", "sentinel.toast", "db.bar1", "oracle.palette" }
  for _, id in ipairs(want) do t:ok(PUI.Layout:Element(id) ~= nil, "mover registered: " .. id) end
end)
