local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui test: Phoenix look on Blizzard's own damage meter (Embers MeterSkin).
-- Harness only: builds a sample Blizzard_DamageMeter (DamageMeter plus
-- DamageMeterSessionWindow1/2) and checks the skin hooks after Blizzard's code.
local H = rawget(_G, "HARNESS")
local Tests, Schema = PUI.Tests, PUI.Schema

local function fakeEntry(parent, class)
  local e = CreateFrame("Frame", nil, parent)
  e.StatusBar = CreateFrame("StatusBar", nil, e)
  e.StatusBar:SetStatusBarTexture("blizzard")
  e.StatusBar.Background = e.StatusBar:CreateTexture()
  e.StatusBar.BackgroundEdge = e.StatusBar:CreateTexture()
  e.StatusBar.Name = e.StatusBar:CreateFontString(); e.StatusBar.Value = e.StatusBar:CreateFontString()
  e.classFilename = class
  function e.UpdateStatusBarColor(self) self.StatusBar:GetStatusBarTexture():SetVertexColor(0.5, 0.5, 0.5) end
  function e.UpdateStyle(self) self.StatusBar:SetStatusBarTexture("blizzard") end
  return e
end
local function fakeWindow(i)
  local w = CreateFrame("Frame", "DamageMeterSessionWindow" .. i, UIParent)
  w.Header = w:CreateTexture()
  w.ScrollBar = CreateFrame("Frame", nil, w)
  w.DamageMeterTypeDropdown = CreateFrame("Button", nil, w)
  w.DamageMeterTypeDropdown.TypeName = w.DamageMeterTypeDropdown:CreateFontString()
  w.SessionDropdown = CreateFrame("Button", nil, w)
  w.SessionDropdown.SessionName = w.SessionDropdown:CreateFontString()
  w.MinimizeContainer = CreateFrame("Frame", nil, w); w.MinimizeContainer.Background = w:CreateTexture()
  local rows = { fakeEntry(w, "MAGE"), fakeEntry(w, H.secret("PRIEST")), fakeEntry(w, "") }
  w.rows = rows
  w.ScrollBox = CreateFrame("Frame", nil, w)
  function w.ScrollBox.ForEachFrame(_, fn) for _, r in ipairs(rows) do fn(r) end end
  function w.InitEntry() end
  w:SetSize(200, 150)
  return w
end
local function setup()
  local dm = CreateFrame("Frame", "DamageMeter", UIParent)
  local wins = {}
  function dm.SetupSessionWindow(_, index, data) data.sessionWindow:Show() end
  function dm.HideSessionWindow() end
  for i = 1, 2 do wins[i] = fakeWindow(i) end
  return dm, wins
end
local function cleanup()
  for _, n in ipairs({ "DamageMeter", "DamageMeterSessionWindow1", "DamageMeterSessionWindow2" }) do rawset(_G, n, nil) end
  for k in pairs(Schema.defs) do if k:sub(1, 13) == "embers.blizz." then Schema:Set(k, Schema.defs[k].default) end end
end

Tests:Add("MeterSkin", "every key has label, tooltip, mode, owner and live apply; simple + advanced keys", function(t)
  local n, simple, adv = 0, 0, 0
  for k, d in pairs(Schema.defs) do
    if k:sub(1, 13) == "embers.blizz." then
      n = n + 1
      t:ok(type(d.apply) == "function" and d.label and d.tooltip and d.owner == "Embers", k .. " complete")
      if d.mode == "simple" then simple = simple + 1 elseif d.mode == "advanced" then adv = adv + 1 end
    end
  end
  t:ok(n >= 11, "keys: " .. n); t:ok(simple >= 3 and adv >= 5, "simple " .. simple .. ", advanced " .. adv)
  t:ok(PUI.Layout.elements["embers.blizzDock"] ~= nil, "Studio mover registered")
end)

Tests:Add("MeterSkin", "hooks on ADDON_LOADED and skins windows, rows, dropdowns and scroll bar", function(t)
  if not H then return t:ok(true, "harness only") end
  t:cleanup(cleanup)
  local B = PUI.Embers.BlizzSkin
  local dm, wins = setup()
  H.fire("ADDON_LOADED", "Blizzard_DamageMeter")
  t:ok(B.hooked[dm], "hooked once loaded")
  t:eq(rawget(dm, "phoenix"), nil, "no field written on DamageMeter")
  dm:SetupSessionWindow(1, { sessionWindow = wins[1] })
  local w = wins[1]
  t:ok(B.windows[w] and B.windows[w].bg:IsShown(), "Phoenix backdrop on window 1")
  t:eq(w.Header:GetAlpha(), 0, "Blizzard header art hidden")
  t:ok(not w.ScrollBar:IsShown(), "scroll bar hidden")
  t:ok(B.windows[w].dd[w.DamageMeterTypeDropdown].bg:IsShown(), "type dropdown skinned")
  local row = w.rows[1]
  t:ok(B.entries[row], "row skinned")
  t:eq(row.StatusBar.Background:GetAlpha(), 0, "Blizzard row background hidden")
  t:ok(row.StatusBar:GetStatusBarTexture() ~= nil, "Phoenix bar texture")
  row:UpdateStatusBarColor()
  local v = rawget(row.StatusBar:GetStatusBarTexture(), "vertex") or {}
  local r, g, b = v[1], v[2], v[3]
  t:ok(r ~= nil and not (r == 0.5 and g == 0.5 and b == 0.5), "class colour repainted after Blizzard's update")
  w.rows[2]:UpdateStatusBarColor() -- secret class: goes to the colour lookup, never compared
  t:ok(B.Color(w.rows[3]) == false, "no class: Blizzard's colour kept")
  Schema:Set("embers.blizz.classColors", false)
  row:UpdateStatusBarColor()
  t:eq(rawget(row.StatusBar:GetStatusBarTexture(), "vertex")[1], 0.5, "class colours off: Blizzard colour")
  Schema:Set("embers.blizz.enabled", false)
  t:ok(not B.windows[w].bg:IsShown() and w.Header:GetAlpha() == 1 and w.ScrollBar:IsShown(), "off gives Blizzard's look back live")
  t:eq(row.StatusBar.Background:GetAlpha(), 1, "row background back")
end)

Tests:Add("MeterSkin", "header fade on hover and docked layout with mover", function(t)
  if not H then return t:ok(true, "harness only") end
  t:cleanup(cleanup)
  local B = PUI.Embers.BlizzSkin
  local dm, wins = setup()
  H.fire("ADDON_LOADED", "Blizzard_DamageMeter")
  for i = 1, 2 do dm:SetupSessionWindow(i, { sessionWindow = wins[i] }) end
  Schema:Set("embers.blizz.fade", true)
  Schema:Set("embers.blizz.fadeAlpha", 0.2)
  local c = B.windows[wins[1]]
  t:eq(c.head:GetAlpha(), 0.2, "faded at rest")
  B.Hover(wins[1], true)
  t:eq(c.head:GetAlpha(), 1, "full on hover")
  t:eq(wins[1].DamageMeterTypeDropdown:GetAlpha(), 1, "dropdown follows hover")
  B.Hover(wins[1], false)
  t:eq(wins[1].DamageMeterTypeDropdown:GetAlpha(), 0.2, "dropdown fades")
  Schema:Set("embers.blizz.dock", "row")
  t:eq(B.Arrange(), 2, "two windows docked")
  t:eq(math.floor(B.dock:GetWidth()), 2 * 240 + 2, "row width")
  t:eq(math.floor(wins[2]:GetWidth()), 240, "docked width applied")
  Schema:Set("embers.blizz.dock", "column")
  t:eq(math.floor(B.dock:GetHeight()), 2 * 200 + 2, "column height")
  Schema:Set("embers.blizz.dock", "off")
  t:ok(not B.dock:IsShown(), "dock off hides the mover")
  t:eq(next(B.saved), nil, "Blizzard places given back")
end)
