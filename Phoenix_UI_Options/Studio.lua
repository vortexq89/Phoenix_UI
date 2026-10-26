local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio v1 (PUI_V2 7, 18.3): dark overlay, pixel grid, one mover per Layout
-- element, drag (engine StartMoving, no OnUpdate), arrow nudges 1/10/100
-- (none/Shift/Ctrl), snap to grid, undo/redo, Save & Exit, Exit. Refused in
-- combat; entering combat suspends it and it resumes after combat.
local Studio, Theme, Widgets = PUI.Studio, PUI.Theme, PUI.Options.Widgets
local Schema, Layout, CQ = PUI.Schema, PUI.Layout, PUI.CombatQueue
Studio.movers = {}
Studio.gridLines = {}

local function parentSize()
  return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
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
    self.hud:SetText(string.format("%s   %s  x %d  y %d", Layout:Element(id).label, pos.point, pos.x, pos.y))
  end
  preview(id)
end

function Studio:Select(id)
  self.session.selected = id
  for mid, m in pairs(self.movers) do
    if mid == id then m.fill:Show() else m.fill:Hide() end
  end
  if id then self:PlaceMover(id) else self.hud:SetText("Drag an element; arrows nudge (Shift 10, Ctrl 100).") end
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
  m.fill = m:CreateTexture(nil, "BACKGROUND")
  m.fill:SetAllPoints()
  Theme:Paint(m.fill, "accent.soft")
  m.fill:Hide()
  Theme:Outline(m, "accent")
  m.chip = Widgets.Font(m:CreateFontString(nil, "OVERLAY"), "small")
  m.chip:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 2)
  m.chip:SetText(el.label)
  Theme:Paint(m.chip, "accent", 1, "text")
  m:EnableMouse(true)
  m:SetMovable(true)
  m:RegisterForDrag("LeftButton")
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
    Theme:Paint(t, offset == 0 and "accent" or "line", offset == 0 and 0.6 or 0.5)
    t:Show()
  end
  for x = 0, w / 2, g do line(true, x); if x > 0 then line(true, -x) end end
  for y = 0, h / 2, g do line(false, y); if y > 0 then line(false, -y) end end
end

function Studio:RefreshButtons()
  local s = self.session
  self.undoBtn:SetLabel("Undo (" .. #s.undo .. ")")
  self.redoBtn:SetLabel("Redo (" .. #s.redo .. ")")
  self.gridBtn:SetLabel(Schema:Get("studio.showGrid") and "Grid: on" or "Grid: off")
  self.snapBtn:SetLabel(Schema:Get("studio.snap") and "Snap: on" or "Snap: off")
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

function Studio:Build()
  local o = PUI:CreateFrame("Frame", "PhoenixUIStudio", UIParent, nil, "Studio")
  o:SetAllPoints(UIParent)
  o:SetFrameStrata("FULLSCREEN_DIALOG")
  local shade = o:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  shade:SetColorTexture(0, 0, 0, 0.6)
  o:EnableKeyboard(true)
  o:SetScript("OnKeyDown", handleKey)
  o:RegisterEvent("PLAYER_REGEN_DISABLED")
  o:SetScript("OnEvent", function() Studio:Suspend() end)
  local bar = CreateFrame("Frame", nil, o)
  bar:SetSize(720, 34)
  bar:SetPoint("TOP", 0, -12)
  Theme:Backdrop(bar, "surface.0")
  Theme:Outline(bar, "line")
  local x = 8
  local function add(label, width, fn)
    local b = Widgets.Button(bar, label, width, fn)
    b:SetPoint("LEFT", x, 0)
    x = x + width + 6
    return b
  end
  self.gridBtn = add("Grid", 80, function() Schema:Set("studio.showGrid", not Schema:Get("studio.showGrid")) end)
  self.snapBtn = add("Snap", 80, function() Schema:Set("studio.snap", not Schema:Get("studio.snap")) end)
  self.undoBtn = add("Undo", 80, function() Studio:UndoRedo("Undo") end)
  self.redoBtn = add("Redo", 80, function() Studio:UndoRedo("Redo") end)
  add("Reset element", 100, function()
    local id = Studio.session.selected
    if id and Studio.session:ResetElement(id) then Studio:PlaceMover(id) end
    Studio:RefreshButtons()
  end)
  add("Save & Exit", 110, function() Studio:Save() end)
  add("Exit", 70, function() Studio:Exit(true) end)
  self.hud = Widgets.Font(o:CreateFontString(nil, "OVERLAY"), "number")
  self.hud:SetPoint("TOP", bar, "BOTTOM", 0, -6)
  o:Hide()
  self.overlay = o
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
  if PUI.Options.frame then PUI.Options.frame:Hide() end
  o:Show()
  self:DrawGrid()
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

-- Exit without saving. A dirty session needs a second Esc (or the Exit button).
function Studio:Exit(force)
  if self.session:Dirty() and not force and not self.confirmExit then
    self.confirmExit = true
    self.hud:SetText("Unsaved changes: press Esc again to discard, or Save & Exit.")
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
