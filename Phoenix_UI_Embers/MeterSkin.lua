local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers: Phoenix look for Blizzard's own damage meter (Blizzard_DamageMeter).
-- Taint-safe by design:
--  * only post-hooks (hooksecurefunc on DamageMeter:SetupSessionWindow and on
--    each window's InitEntry and each row's UpdateStatusBarColor) and HookScript;
--  * no field is ever written on a Blizzard frame or table: Phoenix keeps its
--    own textures and state in weak tables keyed by the Blizzard frame;
--  * values (names, amounts, class tokens) stay where Blizzard put them; Phoenix
--    restyles widgets (textures, fonts, colours) and never reads a value to compare.
-- Parts: Phoenix backdrop, border and header; theme fonts; Phoenix bar texture
-- and class colours (secret-safe through Look.ClassRGB); header and backdrop
-- fade until hovered; a hidden scroll bar (the wheel still scrolls); a Phoenix
-- skin on the meter-type and fight dropdowns; and an optional dock that puts
-- every meter window side by side or in a column under one Studio mover.
local _, ns = ...
local EM = ns.EM
local Schema, Theme, Media, Layout, Look = PUI.Schema, PUI.Theme, PUI.Media, PUI.Layout, PUI.Look
local OWNER = EM.OWNER
local s = { enabled = true, classColors = true, fade = false, fadeAlpha = 0.2, hideScrollBar = true, dropdowns = true,
  fontSize = 12, dock = "off", dockGap = 2, dockWidth = 240, dockHeight = 200 }
local B = { s = s, windows = setmetatable({}, { __mode = "k" }), entries = setmetatable({}, { __mode = "k" }),
  hooked = setmetatable({}, { __mode = "k" }), saved = setmetatable({}, { __mode = "k" }) }
EM.BlizzSkin = B

local function on() return s.enabled end
-- K(f, key): a Blizzard parentKey child, read raw (never a method of the same name)
local function K(f, key) local v = f and rawget(f, key) if type(v) == "table" then return v end end
local function meter() return rawget(_G, "DamageMeter") end
-- Windows() -> shown Blizzard session windows in index order
function B.Windows()
  local out = {}
  for i = 1, 8 do
    local w = rawget(_G, "DamageMeterSessionWindow" .. i)
    if w and w:IsShown() then out[#out + 1] = w end
  end
  return out
end

-- Rows ------------------------------------------------------------------------------------------------------
function B.Color(entry)
  local st = B.entries[entry]
  local bar = K(entry, "StatusBar")
  if not (bar and on() and s.classColors) then return false end
  local class = entry.classFilename
  if class == nil or class == "" then return false end
  local r, g, b = Look.ClassRGB(class) -- a secret token goes to the game's own colour lookup
  if r == nil then return false end
  bar:GetStatusBarTexture():SetVertexColor(r, g, b)
  return st ~= nil
end
function B.SkinEntry(entry)
  local bar = entry and K(entry, "StatusBar")
  if not bar then return false end
  local st = B.entries[entry]
  if not st then
    st = { bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7) }
    st.bg:SetAllPoints()
    B.entries[entry] = st
    -- Blizzard recolours rows on every update: repaint after it (post-hook, once per row)
    hooksecurefunc(entry, "UpdateStatusBarColor", function(self) if on() then B.Color(self) end end)
  end
  if not on() then st.bg:Hide() return false end
  bar:SetStatusBarTexture(PUI.Bars and PUI.Bars:TexturePath() or Media:Texture("flat"))
  st.bg:SetColorTexture(0, 0, 0, 0.35); st.bg:Show()
  for _, region in ipairs({ K(bar, "Background"), K(bar, "BackgroundEdge") }) do if region then region:SetAlpha(0) end end
  local path = Look.FontFor("meter") or Media:Font(Schema:Get("media.uiFont"))
  for _, fs in ipairs({ K(bar, "Name"), K(bar, "Value") }) do
    if fs and fs.SetFont and path then fs:SetFont(path, s.fontSize, Look.Flags()) end
  end
  B.Color(entry)
  return true
end
-- Unskin(entry): Blizzard's own style comes back through its own update.
function B.UnskinEntry(entry)
  local st = B.entries[entry]
  if st then st.bg:Hide() end
  local bar = K(entry, "StatusBar")
  for _, region in ipairs({ bar and K(bar, "Background"), bar and K(bar, "BackgroundEdge") }) do if region then region:SetAlpha(1) end end
  if entry.UpdateStyle then entry:UpdateStyle() end
  if entry.UpdateStatusBarColor then entry:UpdateStatusBarColor() end
end

-- Window chrome ---------------------------------------------------------------------------------------------
local function chrome(w)
  local c = B.windows[w]
  if c then return c end
  c = {}
  c.bg = Theme:Backdrop(w, "surface.1")
  c.edges = Theme:Outline(w, "accent", 0.5)
  c.head = w:CreateTexture(nil, "BORDER")
  c.head:SetPoint("TOPLEFT"); c.head:SetPoint("TOPRIGHT"); c.head:SetHeight(24)
  c.line = w:CreateTexture(nil, "ARTWORK")
  c.line:SetPoint("TOPLEFT", c.head, "BOTTOMLEFT"); c.line:SetPoint("TOPRIGHT", c.head, "BOTTOMRIGHT"); c.line:SetHeight(1)
  c.dd = {}
  B.windows[w] = c
  w:HookScript("OnEnter", function() B.Hover(w, true) end)
  w:HookScript("OnLeave", function() if not w:IsMouseOver() then B.Hover(w, false) end end)
  local bar = K(w, "ScrollBar")
  if bar then bar:HookScript("OnShow", function(self) if on() and s.hideScrollBar then self:Hide() end end) end
  local box = K(w, "ScrollBox")
  if box then
    -- rows are pooled: style each one after Blizzard initialises it
    hooksecurefunc(w, "InitEntry", function(_, frame) B.SkinEntry(frame) end)
  end
  return c
end
local function skinDropdown(w, dd, label)
  local c = B.windows[w]
  if not dd then return end
  local d = c.dd[dd]
  if not d then
    d = { bg = dd:CreateTexture(nil, "BACKGROUND", nil, -6), arrow = dd:CreateFontString(nil, "OVERLAY") }
    d.bg:SetAllPoints()
    d.arrow:SetFontObject(Media:FontObject("small")); d.arrow:SetPoint("RIGHT", -4, 0); d.arrow:SetText("v")
    d.regions = {}
    if dd.GetRegions then for _, r in ipairs({ dd:GetRegions() }) do if r ~= label and r.GetObjectType and r:GetObjectType() == "Texture" and r ~= d.bg then d.regions[#d.regions + 1] = r end end end
    c.dd[dd] = d
  end
  local skin = on() and s.dropdowns
  for _, r in ipairs(d.regions) do r:SetAlpha(skin and 0 or 1) end
  d.bg:SetColorTexture(Theme:Color("bg2")); d.bg:SetShown(skin)
  d.arrow:SetTextColor(Theme:Color("accent")); d.arrow:SetShown(skin)
  if label and label.SetFont then
    local path = Look.FontFor("meter") or Media:Font(Schema:Get("media.uiFont"))
    if path and skin then label:SetFont(path, s.fontSize, Look.Flags()) end
    if skin then label:SetTextColor(0.95, 0.95, 0.95) end
  end
end

function B.Hover(w, over)
  local c = B.windows[w]
  if not c then return end
  local alpha = (not s.fade or over) and 1 or s.fadeAlpha
  c.head:SetAlpha(alpha); c.bg:SetAlpha(alpha * 0.9); c.line:SetAlpha(alpha)
  for _, e in ipairs(c.edges) do e:SetAlpha((Look.s.borderStyle == "pixel") and alpha or 0) end
  for _, part in ipairs({ K(w, "DamageMeterTypeDropdown"), K(w, "SessionDropdown"), K(w, "SettingsDropdown"), K(w, "MinimizeButton"), K(w, "SessionTimer") }) do
    if part then part:SetAlpha(alpha) end
  end
  c.hover = over
end

-- SkinWindow(w): Phoenix chrome on one session window (on/off live).
function B.SkinWindow(w)
  if not w then return false end
  local c = chrome(w)
  local active = on()
  c.bg:SetShown(active); c.head:SetShown(active); c.line:SetShown(active)
  for _, e in ipairs(c.edges) do e:SetShown(active) end
  local ar, ag, ab = Theme:Color("accent")
  c.head:SetColorTexture(ar * 0.22, ag * 0.22, ab * 0.22, 0.95)
  c.line:SetColorTexture(ar, ag, ab, 0.8)
  if K(w, "Header") then K(w, "Header"):SetAlpha(active and 0 or 1) end
  local bg = K(w, "MinimizeContainer") and K(K(w, "MinimizeContainer"), "Background")
  if bg then bg:SetAlpha(active and 0 or 1) end
  if K(w, "ScrollBar") then K(w, "ScrollBar"):SetShown(not (active and s.hideScrollBar)) end
  skinDropdown(w, K(w, "DamageMeterTypeDropdown"), K(K(w, "DamageMeterTypeDropdown"), "TypeName"))
  skinDropdown(w, K(w, "SessionDropdown"), K(K(w, "SessionDropdown"), "SessionName"))
  if K(w, "SessionTimer") and active then
    local path = Look.FontFor("meter") or Media:Font(Schema:Get("media.uiFont"))
    if path then K(w, "SessionTimer"):SetFont(path, s.fontSize, Look.Flags()) end
  end
  B.Hover(w, c.hover == true)
  local box = K(w, "ScrollBox")
  if box and box.ForEachFrame then
    box:ForEachFrame(function(entry) if active then B.SkinEntry(entry) else B.UnskinEntry(entry) end end)
  end
  return true
end

-- Dock --------------------------------------------------------------------------------------------------------
PUI.Layout:RegisterElement("embers.blizzDock", { label = "Blizzard meter dock", owner = OWNER, size = { 240, 200 },
  default = { point = "BOTTOMRIGHT", x = -19, y = 260 } })
function B.Container()
  if B.dock then return B.dock end
  B.dock = PUI:CreateFrame("Frame", "PhoenixUI_BlizzMeterDock", UIParent, nil, OWNER)
  B.dock:SetSize(s.dockWidth, s.dockHeight)
  return B.dock
end
local function remember(w)
  if B.saved[w] then return end
  local pts = {}
  for i = 1, w:GetNumPoints() do pts[i] = { w:GetPoint(i) } end
  B.saved[w] = { points = pts, w = w:GetWidth(), h = w:GetHeight() }
end
local function restore(w)
  local sv = B.saved[w]
  if not sv then return end
  w:ClearAllPoints()
  for _, p in ipairs(sv.points) do w:SetPoint(unpack(p)) end
  if #sv.points < 2 and sv.w then w:SetSize(sv.w, sv.h) end
  B.saved[w] = nil
end
-- Arrange() -> number of docked windows (0 when off)
function B.Arrange()
  local list = B.Windows()
  if not (on() and s.dock ~= "off") then
    for _, w in ipairs(list) do restore(w) end
    for w in pairs(B.saved) do restore(w) end
    if B.dock then B.dock:Hide() end
    return 0
  end
  local c = B.Container()
  c:Show()
  Layout:Place(c, "embers.blizzDock")
  for i, w in ipairs(list) do
    remember(w)
    w:ClearAllPoints()
    w:SetSize(s.dockWidth, s.dockHeight)
    if i == 1 then w:SetPoint("TOPLEFT", c, "TOPLEFT")
    elseif s.dock == "row" then w:SetPoint("TOPLEFT", list[i - 1], "TOPRIGHT", s.dockGap, 0)
    else w:SetPoint("TOPLEFT", list[i - 1], "BOTTOMLEFT", 0, -s.dockGap) end
  end
  local n = math.max(1, #list)
  if s.dock == "row" then c:SetSize(n * s.dockWidth + (n - 1) * s.dockGap, s.dockHeight)
  else c:SetSize(s.dockWidth, n * s.dockHeight + (n - 1) * s.dockGap) end
  return #list
end

-- Wiring ------------------------------------------------------------------------------------------------------
function B.Refresh()
  for _, w in ipairs(B.Windows()) do B.SkinWindow(w) end
  for w in pairs(B.windows) do if not w:IsShown() then B.SkinWindow(w) end end
  B.Arrange()
end
-- Hook() -> true once Blizzard's meter is loaded and hooked
function B.Hook()
  local dm = meter()
  if not dm or B.hooked[dm] then return B.hooked[dm] == true end
  if type(dm.SetupSessionWindow) ~= "function" then return false end
  hooksecurefunc(dm, "SetupSessionWindow", function(_, _, windowData)
    local w = type(windowData) == "table" and windowData.sessionWindow
    if w then B.SkinWindow(w); B.Arrange() end
  end)
  if type(dm.HideSessionWindow) == "function" then hooksecurefunc(dm, "HideSessionWindow", function() B.Arrange() end) end
  B.hooked[dm] = true
  B.Refresh()
  return true
end
B.events = PUI:CreateFrame("Frame", nil, UIParent, nil, OWNER)
B.events:RegisterEvent("ADDON_LOADED")
B.events:SetScript("OnEvent", function(_, _, name) if name == "Blizzard_DamageMeter" then B.Hook() end end)
B.Hook()
PUI.Kernel:On("LOOK_CHANGED", function() if next(B.windows) then B.Refresh() end end)

local function key(name, def)
  def.owner = OWNER
  def.apply = function(v) s[name] = v; B.Refresh() end
  def.searchTags = def.searchTags or { "blizzard meter", "damage meter", "skin" }
  EM.schema["embers.blizz." .. name] = def
  Schema:Register("embers.blizz." .. name, def)
  s[name] = Schema:Get("embers.blizz." .. name)
end
key("enabled", { type = "toggle", default = true, mode = "simple", label = "Phoenix look on Blizzard's meter",
  tooltip = "Blizzard's own damage meter windows get Phoenix's backdrop, header, fonts and bar texture (post-hooks only; turning it off gives Blizzard's look back)." })
key("classColors", { type = "toggle", default = true, mode = "simple", label = "Blizzard meter: Phoenix class colours",
  tooltip = "Bars in Blizzard's meter use your class colours from the Colours page." })
key("fade", { type = "toggle", default = false, mode = "simple", label = "Blizzard meter: fade the header until hovered",
  tooltip = "The header, dropdowns and backdrop of Blizzard's meter windows fade out and come back while the mouse is over them." })
key("fadeAlpha", { type = "range", default = 0.2, min = 0, max = 0.9, step = 0.05, mode = "advanced", label = "Blizzard meter: faded opacity",
  tooltip = "How visible the faded header and backdrop are." })
key("hideScrollBar", { type = "toggle", default = true, mode = "advanced", label = "Blizzard meter: hide the scroll bar",
  tooltip = "Hides the scroll bar of Blizzard's meter windows; the mouse wheel still scrolls." })
key("dropdowns", { type = "toggle", default = true, mode = "advanced", label = "Blizzard meter: Phoenix dropdowns",
  tooltip = "The meter type and fight dropdowns in the header get the Phoenix look." })
key("fontSize", { type = "range", default = 12, min = 8, max = 20, step = 1, mode = "advanced", label = "Blizzard meter: text size",
  tooltip = "Size of names, numbers and header text in Blizzard's meter windows." })
key("dock", { type = "select", default = "off", choices = { "off", "row", "column" },
  choiceLabels = { off = "Off (Blizzard places them)", row = "Docked side by side", column = "Docked in a column" }, mode = "simple",
  label = "Blizzard meter: dock windows", tooltip = "Puts every Blizzard meter window together under one Studio mover (Blizzard meter dock). Off gives Blizzard's places back." })
key("dockGap", { type = "range", default = 2, min = 0, max = 20, step = 1, mode = "advanced", label = "Blizzard meter: dock gap",
  tooltip = "Space between docked Blizzard meter windows." })
key("dockWidth", { type = "range", default = 240, min = 140, max = 500, step = 10, mode = "advanced", label = "Blizzard meter: docked width",
  tooltip = "Width of each docked Blizzard meter window." })
key("dockHeight", { type = "range", default = 200, min = 80, max = 600, step = 10, mode = "advanced", label = "Blizzard meter: docked height",
  tooltip = "Height of each docked Blizzard meter window." })
