local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio (mockup 12): dark overlay with pixel grid and centre guides, one
-- mover per Layout element (module icon, hover name, selected chip with live
-- coordinates and corner handles), a top toolbar (category filter, snap,
-- grid size, undo, reset, Save & exit) and an inspector (X/Y, anchor grid,
-- nudge, mirror, settings). Drag uses the engine's StartMoving (no
-- OnUpdate); arrows nudge 1/10/100. Refused in combat; combat suspends it.
local Studio, Theme = PUI.Studio, PUI.Theme
local Schema, Layout, CQ = PUI.Schema, PUI.Layout, PUI.CombatQueue
local Options = PUI.Options
local Kit, A, Nav = Options.Kit, Options.Assets, Options.Nav
Studio.movers = {}
Studio.gridLines = {}
Studio.filter = "all"

local CATEGORY = {
  UnitFrames = "frames", Nameplates = "frames",
  ActionBars = "bars", ResourceBars = "bars", CooldownManager = "bars", DataBars = "bars",
  RaidFrames = "group", Ascent = "group", GroupFinder = "group",
  Reminders = "hud", QuestTracker = "hud", Vault = "hud", Embers = "hud", Minimap = "hud", Chat = "hud",
}
Studio.CATEGORY = CATEGORY
local GRID_STEPS = { 8, 16, 32, 64 }
local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local FX = { TOPLEFT = 0, TOP = 0.5, TOPRIGHT = 1, LEFT = 0, CENTER = 0.5, RIGHT = 1, BOTTOMLEFT = 0, BOTTOM = 0.5, BOTTOMRIGHT = 1 }
local FY = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0 }

local function parentSize()
  return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
end

function Studio.Category(id)
  local el = Layout:Element(id)
  return CATEGORY[el and el.owner or ""] or "info"
end

-- Preview: move the real element frame (if built) with the session.
local function preview(id)
  local frame = Layout:Frame(id)
  if frame then Layout:Place(frame, id, Studio.session:Get(id)) end
end

function Studio:PlaceMover(id)
  local m, pos = self.movers[id], self.session:Get(id)
  m:ClearAllPoints()
  m:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  if id == self.session.selected then
    m.coords:SetText(string.format("%d, %d", pos.x, pos.y))
    self:RefreshInspector()
  end
  preview(id)
end

function Studio:Select(id)
  self.session.selected = id
  for mid, m in pairs(self.movers) do m:SetSelected(mid == id) end
  if id then
    self:PlaceMover(id)
  else
    self.hud:SetText("Hover to see names  -  Click to select  -  Drag to move  -  Arrows nudge (Shift 10, Ctrl 100)")
  end
  self.inspector:SetShown(id ~= nil)
end

local function onDragStop(m)
  m:StopMovingOrSizing()
  local cx, cy = m:GetCenter()
  if not cx then return end
  local w, h = parentSize()
  local x, y = Studio.CenterOffset(cx, cy, w, h)
  if Schema:Get("studio.snap") then
    local g = Schema:Get("studio.gridSize")
    x, y = Studio.Snap(x, g), Studio.Snap(y, g)
  end
  Studio.session:Move(m.id, x, y, "CENTER")
  Studio:PlaceMover(m.id)
  Studio:RefreshButtons()
end

local function corner(m, point)
  local t = m:CreateTexture(nil, "OVERLAY")
  t:SetSize(6, 6)
  t:SetPoint("CENTER", m, point)
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

function Studio:Mover(id)
  local m = self.movers[id]
  if m then return m end
  local el = Layout:Element(id)
  local frame = Layout:Frame(id)
  m = CreateFrame("Frame", nil, self.overlay)
  m.id = id
  local w = frame and frame:GetWidth() or (el.size and el.size[1]) or 120
  local h = frame and frame:GetHeight() or (el.size and el.size[2]) or 40
  m:SetSize(w > 0 and w or 120, h > 0 and h or 40)
  m:SetFrameLevel(self.overlay:GetFrameLevel() + 5)
  m.bg = Theme:Slice(m, A.control, 20, "BACKGROUND")
  m.bg:SetVertexColor(1, 1, 1, 0.06)
  m.edge = Theme:Slice(m, A.border1, 4, "BORDER")
  m.edge:SetVertexColor(1, 1, 1, 0.16)
  m.fill = m:CreateTexture(nil, "ARTWORK")
  m.fill:SetAllPoints()
  Theme:Paint(m.fill, "accent", 0.12)
  m.sel = Theme:Slice(m, A.border1, 4, "OVERLAY")
  Theme:Paint(m.sel, "accent", 1, "vertex")
  m.icon = Kit.Icon(m, A.Icon((Nav.Info(el.owner))), 16)
  m.icon:SetPoint("CENTER")
  m.icon:SetAlpha(0.55)
  m.handles = { corner(m, "TOPLEFT"), corner(m, "TOPRIGHT"), corner(m, "BOTTOMLEFT"), corner(m, "BOTTOMRIGHT") }
  for _, t in ipairs(m.handles) do Theme:Paint(t, "accent") end
  -- name chip: shown on hover, and with coordinates when selected
  m.chipFrame = CreateFrame("Frame", nil, m)
  m.chipFrame:SetHeight(20)
  m.chipFrame:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 4)
  m.chipBg = Theme:Slice(m.chipFrame, A.control, 20, "BACKGROUND")
  m.chipIcon = Kit.Icon(m.chipFrame, A.Icon((Nav.Info(el.owner))), 12)
  m.chipIcon:SetPoint("LEFT", 6, 0)
  m.chip = Kit.Text(m.chipFrame, "label", "text.primary")
  m.chip:SetPoint("LEFT", m.chipIcon, "RIGHT", 5, 0)
  m.chip:SetText(PUI.L[el.label])
  m.coords = Kit.Text(m.chipFrame, "mono", "text.primary")
  m.coords:SetPoint("LEFT", m.chip, "RIGHT", 8, 0)
  m.chipFrame:SetWidth(220)
  function m:SetSelected(on)
    self.selected = on
    self.fill:SetShown(on)
    self.sel:SetShown(on)
    for _, t in ipairs(self.handles) do t:SetShown(on) end
    self.coords:SetShown(on)
    self.chipFrame:SetShown(on)
    if on then Theme:Paint(self.chipBg, "accent", 1, "vertex") else self.chipBg:SetVertexColor(0.11, 0.12, 0.16, 0.95) end
    Theme:Paint(self.chip, on and "bg0" or "text.primary", 1, "text")
    Theme:Paint(self.coords, on and "bg0" or "text.primary", 1, "text")
    self.icon:SetAlpha(on and 0.9 or 0.55)
  end
  m:SetSelected(false)
  m:EnableMouse(true)
  m:SetMovable(true)
  m:RegisterForDrag("LeftButton")
  m:SetScript("OnEnter", function(self) if not self.selected then self.chipFrame:Show() end end)
  m:SetScript("OnLeave", function(self) if not self.selected then self.chipFrame:Hide() end end)
  m:SetScript("OnMouseDown", function() Studio:Select(id) end)
  m:SetScript("OnDragStart", function(self) Studio:Select(id); self:StartMoving() end)
  m:SetScript("OnDragStop", onDragStop)
  self.movers[id] = m
  return m
end

function Studio:DrawGrid()
  for i = 1, #self.gridLines do self.gridLines[i]:Hide() end
  if not (self.overlay and Schema:Get("studio.showGrid")) then return end
  local g = Schema:Get("studio.gridSize")
  local w, h = parentSize()
  local n = 0
  local function line(vertical, offset)
    n = n + 1
    local t = self.gridLines[n]
    if not t then
      t = self.overlay:CreateTexture(nil, "BORDER")
      self.gridLines[n] = t
    end
    t:ClearAllPoints()
    if vertical then
      t:SetPoint("TOP", self.overlay, "CENTER", offset, h / 2)
      t:SetSize(1, h)
    else
      t:SetPoint("LEFT", self.overlay, "CENTER", -w / 2, offset)
      t:SetSize(w, 1)
    end
    if offset == 0 then Theme:Paint(t, "info", 0.55) else t:SetColorTexture(1, 1, 1, 0.035) end
    t:Show()
  end
  for x = 0, w / 2, g do line(true, x); if x > 0 then line(true, -x) end end
  for y = 0, h / 2, g do line(false, y); if y > 0 then line(false, -y) end end
end

function Studio:ApplyFilter()
  for id, m in pairs(self.movers) do
    if Layout:Element(id) then m:SetShown(self.filter == "all" or Studio.Category(id) == self.filter) end
  end
end

function Studio:RefreshButtons()
  local s = self.session
  self.undoBtn:SetLabel(#s.undo > 0 and ("Undo (" .. #s.undo .. ")") or "Undo")
  self.redoBtn:SetLabel(#s.redo > 0 and ("Redo (" .. #s.redo .. ")") or "Redo")
  self.snapToggle:SetValue_(Schema:Get("studio.snap") and true or false)
  self.gridBtn:SetLabel(Schema:Get("studio.showGrid") and ("Grid " .. Schema:Get("studio.gridSize")) or "Grid off")
  self.filterSeg:SetValue_(self.filter)
end

local function handleKey(_, key)
  local s = Studio.session
  local step = IsControlKeyDown() and 100 or IsShiftKeyDown() and 10 or 1
  local dirs = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
  local handled = true
  if dirs[key] and s.selected then
    s:Nudge(s.selected, dirs[key][1], dirs[key][2], step)
    Studio:PlaceMover(s.selected)
  elseif key == "Z" and IsControlKeyDown() then
    Studio:UndoRedo("Undo")
  elseif key == "Y" and IsControlKeyDown() then
    Studio:UndoRedo("Redo")
  elseif key == "ESCAPE" then
    Studio:Exit()
  else
    handled = false
  end
  if not InCombatLockdown() then Studio.overlay:SetPropagateKeyboardInput(not handled) end
  Studio:RefreshButtons()
end

function Studio:UndoRedo(which)
  local id = self.session[which](self.session)
  if id then self:PlaceMover(id) end
  self:RefreshButtons()
end

-- Grid button cycles 8 / 16 / 32 / 64 / off.
function Studio:CycleGrid()
  if not Schema:Get("studio.showGrid") then
    Schema:Set("studio.showGrid", true)
    Schema:Set("studio.gridSize", GRID_STEPS[1])
    return
  end
  local cur = Schema:Get("studio.gridSize")
  for i, g in ipairs(GRID_STEPS) do
    if g == cur then
      if i == #GRID_STEPS then Schema:Set("studio.showGrid", false) else Schema:Set("studio.gridSize", GRID_STEPS[i + 1]) end
      return
    end
  end
  Schema:Set("studio.gridSize", 32)
end

local function buildToolbar(o)
  local bar = CreateFrame("Frame", nil, o)
  bar:SetSize(10, 44)
  bar:SetPoint("TOP", 0, -14)
  Kit.Window(bar)
  local logo = Kit.Icon(bar, A.logo, 22)
  logo:SetPoint("LEFT", 14, 0)
  local name = Kit.Text(bar, "title", "text.primary")
  name:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  name:SetText("STUDIO")
  local x = 110
  local function place(w, gap)
    w:SetPoint("LEFT", x, 0)
    x = x + w:GetWidth() + (gap or 8)
    return w
  end
  Studio.filterSeg = place(Kit.Segmented(bar, { "all", "frames", "bars", "group", "hud", "info" },
    { "All", "Frames", "Bars", "Group", "HUD", "Info" }, function(v) Studio.filter = v; Studio:ApplyFilter(); Studio:RefreshButtons() end), 16)
  Studio.snapToggle = place(Kit.Toggle(bar, function(on) Schema:Set("studio.snap", on) end), 6)
  local snapText = Kit.Text(bar, "label", "text.secondary")
  snapText:SetText("Snap")
  snapText:SetPoint("LEFT", x, 0)
  x = x + 40
  Studio.gridBtn = place(Kit.Button(bar, "Grid 32", 84, function() Studio:CycleGrid() end, "secondary"), 16)
  Studio.undoBtn = place(Kit.Button(bar, "Undo", 84, function() Studio:UndoRedo("Undo") end, "ghost"), 2)
  Studio.redoBtn = place(Kit.Button(bar, "Redo", 84, function() Studio:UndoRedo("Redo") end, "ghost"))
  place(Kit.Button(bar, "Reset", 70, function()
    local id = Studio.session.selected
    if id and Studio.session:ResetElement(id) then Studio:PlaceMover(id) end
    Studio:RefreshButtons()
  end, "secondary"))
  place(Kit.Button(bar, "Save & exit", 110, function() Studio:Save() end, "primary"), 14)
  bar:SetWidth(x)
  Studio.toolbar = bar
end

local function field(parent, label, w)
  local f = CreateFrame("EditBox", nil, parent)
  f:SetSize(w, 30)
  f:SetAutoFocus(false)
  f:SetFontObject(Kit.FontObject("mono"))
  f:SetJustifyH("RIGHT")
  f:SetTextInsets(26, 10, 0, 0)
  local bg = Theme:Slice(f, A.control, 20, "BACKGROUND")
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  local l = Kit.Text(f, "small", "muted")
  l:SetPoint("LEFT", 10, 0)
  l:SetText(label)
  f:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Studio:RefreshInspector() end)
  return f
end

-- Re-anchor the selected element to a new point without moving it on screen.
function Studio:Reanchor(point)
  local id = self.session.selected
  local m = id and self.movers[id]
  if not m then return end
  local l, b, w, h = m:GetRect()
  if not l then return end
  local W, H = parentSize()
  local x = (l + FX[point] * w) - FX[point] * W
  local y = (b + FY[point] * h) - FY[point] * H
  self.session:Move(id, x, y, point)
  self:PlaceMover(id)
  self:RefreshButtons()
end

local function buildInspector(o)
  local p = CreateFrame("Frame", nil, o)
  p:SetSize(320, 330)
  p:SetPoint("TOPLEFT", 24, -70)
  Kit.Window(p)
  p.icon = Kit.Icon(p, A.Icon("unitframes"), 30)
  p.icon:SetPoint("TOPLEFT", 18, -18)
  p.title = Kit.Text(p, "body", "text.primary")
  p.title:SetPoint("TOPLEFT", p.icon, "TOPRIGHT", 10, 0)
  p.sub = Kit.Text(p, "small", "muted")
  p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -3)
  local close = Kit.Button(p, "x", 26, function() Studio:Select(nil) end, "ghost")
  close:SetPoint("TOPRIGHT", -10, -14)
  local s1 = Kit.Section(p, "Position")
  s1:SetPoint("TOPLEFT", 18, -66)
  p.x = field(p, "X", 136)
  p.x:SetPoint("TOPLEFT", 18, -86)
  p.y = field(p, "Y", 136)
  p.y:SetPoint("LEFT", p.x, "RIGHT", 12, 0)
  local function commit()
    local id = Studio.session.selected
    if not id then return end
    local pos = Studio.session:Get(id)
    local x, y = tonumber(p.x:GetText()), tonumber(p.y:GetText())
    Studio.session:Move(id, x or pos.x, y or pos.y, pos.point)
    p.x:ClearFocus(); p.y:ClearFocus()
    Studio:PlaceMover(id)
    Studio:RefreshButtons()
  end
  p.x:SetScript("OnEnterPressed", commit)
  p.y:SetScript("OnEnterPressed", commit)
  p.size = Kit.Text(p, "small", "muted")
  p.size:SetPoint("TOPLEFT", p.x, "BOTTOMLEFT", 2, -8)
  local s2 = Kit.Section(p, "Anchor")
  s2:SetPoint("TOPLEFT", 18, -160)
  p.anchors = {}
  for i, point in ipairs(POINTS) do
    local b = CreateFrame("Button", nil, p)
    b:SetSize(20, 20)
    b:SetPoint("TOPLEFT", 18 + ((i - 1) % 3) * 23, -180 - math.floor((i - 1) / 3) * 23)
    b.bg = Theme:Slice(b, A.control, 20, "BACKGROUND")
    b.point = point
    b:SetScript("OnClick", function() Studio:Reanchor(point) end)
    p.anchors[i] = b
  end
  p.anchorText = Kit.Text(p, "small", "text.secondary")
  p.anchorText:SetPoint("TOPLEFT", 100, -194)
  local nudge = Kit.Text(p, "label", "text.secondary")
  nudge:SetPoint("TOPLEFT", 18, -264)
  nudge:SetText("Nudge")
  local arrows = { { "<", -1, 0 }, { "^", 0, 1 }, { "v", 0, -1 }, { ">", 1, 0 } }
  for i, a in ipairs(arrows) do
    local b = Kit.Button(p, a[1], 26, function()
      local id = Studio.session.selected
      if not id then return end
      Studio.session:Nudge(id, a[2], a[3], IsShiftKeyDown() and 10 or 1)
      Studio:PlaceMover(id)
      Studio:RefreshButtons()
    end, "secondary")
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", 90 + (i - 1) * 30, -260)
  end
  local shift = Kit.Text(p, "small", "muted")
  shift:SetPoint("TOPLEFT", 216, -264)
  shift:SetText("Shift x10")
  local mirror = Kit.Button(p, "Mirror", 136, function()
    local id = Studio.session.selected
    if not id then return end
    local pos = Studio.session:Get(id)
    local flip = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" }
    Studio.session:Move(id, -pos.x, pos.y, flip[pos.point] or pos.point)
    Studio:PlaceMover(id)
    Studio:RefreshButtons()
  end, "secondary")
  mirror:SetPoint("BOTTOMLEFT", 18, 16)
  local settings = Kit.Button(p, "Settings", 136, function()
    local id = Studio.session.selected
    local owner = id and Layout:Element(id).owner
    Studio:Exit(true)
    if owner then Options:Open(owner) end
  end, "secondary")
  settings:SetPoint("LEFT", mirror, "RIGHT", 12, 0)
  p:Hide()
  Studio.inspector = p
end

function Studio:RefreshInspector()
  local p, id = self.inspector, self.session and self.session.selected
  if not (p and id) then return end
  local el, pos = Layout:Element(id), self.session:Get(id)
  local icon, label = Nav.Info(el.owner)
  p.icon:SetTexture(A.Icon(icon))
  p.title:SetText(PUI.L[el.label])
  p.sub:SetText(label .. "  -  " .. Studio.Category(id):gsub("^%l", string.upper))
  if not p.x:HasFocus() then p.x:SetText(tostring(pos.x)) end
  if not p.y:HasFocus() then p.y:SetText(tostring(pos.y)) end
  local m = self.movers[id]
  p.size:SetText(string.format("Size %d x %d", math.floor((m:GetWidth() or 0) + 0.5), math.floor((m:GetHeight() or 0) + 0.5)))
  for _, b in ipairs(p.anchors) do
    if b.point == pos.point then Theme:Paint(b.bg, "accent", 1, "vertex") else Theme:Paint(b.bg, "bg3", 1, "vertex") end
  end
  p.anchorText:SetText("Point |cffece8e2" .. pos.point .. "|r\nto UIParent |cffece8e2" .. pos.point .. "|r")
end

function Studio:Build()
  local o = PUI:CreateFrame("Frame", "PhoenixUIStudio", UIParent, nil, "Studio")
  o:SetAllPoints(UIParent)
  o:SetFrameStrata("FULLSCREEN_DIALOG")
  local shade = o:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  shade:SetColorTexture(0.02, 0.025, 0.03, 0.72)
  o:EnableKeyboard(true)
  o:SetScript("OnKeyDown", handleKey)
  o:RegisterEvent("PLAYER_REGEN_DISABLED")
  o:SetScript("OnEvent", function() Studio:Suspend() end)
  self.overlay = o
  buildToolbar(o)
  buildInspector(o)
  local hint = CreateFrame("Frame", nil, o)
  hint:SetSize(10, 30)
  hint:SetPoint("TOPLEFT", 24, -20)
  Kit.Window(hint)
  self.hud = Kit.Text(hint, "small", "text.secondary")
  self.hud:SetPoint("LEFT", 14, 0)
  hint:SetWidth(460)
  self.hint = hint
  o:Hide()
  return o
end

function Studio:Open()
  if CQ.InCombat() then
    PUI.Slash.Print("Studio cannot open in combat.")
    return false
  end
  if self.overlay and self.overlay:IsShown() then return true end
  local o = self.overlay or self:Build()
  self.session = Studio.Session.New()
  self.confirmExit = false
  for _, m in pairs(self.movers) do m:Hide() end -- elements may have gone since the last session
  for i = 1, #Layout.order do
    local id = Layout.order[i]
    self:Mover(id):Show()
    self:PlaceMover(id)
  end
  if Options.frame then Options.frame:Hide() end
  o:Show()
  self:DrawGrid()
  self:ApplyFilter()
  self:Select(nil)
  self:RefreshButtons()
  PUI:Log("studio", "open")
  return true
end

function Studio:IsOpen() return self.overlay ~= nil and self.overlay:IsShown() end

function Studio:Close()
  self.overlay:Hide()
  self.suspended = false
  Layout:ApplyAll() -- element frames go back to the saved positions
end

function Studio:Save()
  Schema:Set("layout.positions", self.session:Saved())
  PUI:Log("studio", "save")
  self:Close()
end

-- Exit without saving. A dirty session needs a second Esc.
function Studio:Exit(force)
  if self.session:Dirty() and not force and not self.confirmExit then
    self.confirmExit = true
    self.hud:SetText("|cffffc24bUnsaved changes:|r press Esc again to discard, or Save & exit.")
    return false
  end
  PUI:Log("studio", "exit")
  self:Close()
  return true
end

-- Combat started: hide, keep the session, resume after combat.
function Studio:Suspend()
  if not self:IsOpen() then return end
  self.overlay:Hide()
  self.suspended = true
  PUI.Slash.Print("Studio paused for combat; it reopens when combat ends.")
  -- lockdown begins just after PLAYER_REGEN_DISABLED, so queue on the next frame
  C_Timer.After(0, function()
    CQ.Defer("studio.resume", function() Studio:Resume() end)
  end)
end

function Studio:Resume()
  if not self.suspended or CQ.InCombat() then return end
  self.suspended = false
  self.overlay:Show()
  self:DrawGrid()
end

function Studio:OnGridChanged()
  if self:IsOpen() then self:DrawGrid(); self:RefreshButtons() end
end

function Studio:OnSnapChanged()
  if self:IsOpen() then self:RefreshButtons() end
end
