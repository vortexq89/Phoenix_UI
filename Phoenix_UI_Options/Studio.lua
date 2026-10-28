local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio v2 (mockup 12): layout mode for every Phoenix element and, when
-- turned on, about 130 Blizzard elements. Dark overlay with grid, centre and
-- safe-zone guides; one mover per element (module icon, name, Edit Mode badge,
-- attach link); live snap guides and distance labels while dragging; Shift-click
-- and box select; mouse wheel picks stacked movers; arrows nudge (Shift/Ctrl
-- steps are settings). Drag uses the engine's StartMoving; the live guides run
-- on one Ticker entry that exists only while dragging (no OnUpdate). Refused in
-- combat; combat suspends it and it comes back afterwards. Panels (inspector,
-- align bar, layouts, explain) are in StudioPanels.lua.
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
  Blizzard = "blizzard",
}
Studio.CATEGORY = CATEGORY
Studio.FILTERS = { "all", "frames", "bars", "group", "hud", "blizzard", "info" }
Studio.FILTER_LABELS = { "All", "Frames", "Bars", "Group", "HUD", "Blizzard", "Info" }
local GRID_STEPS = { 8, 16, 32, 64 }

local function parentSize() return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0 end

function Studio.Category(id)
  local el = Layout:Element(id)
  return CATEGORY[el and el.owner or ""] or "info"
end

function Studio:Visible()
  local out = {}
  for id, m in pairs(self.movers) do if m:IsShown() then out[id] = true end end
  return out
end

-- Preview: move the real element frame (if built) with the session.
local function preview(id)
  local s = Studio.session
  if Studio.IsBlizzard(id) then
    if s.touched[id] and PUI.Movers then PUI.Movers:ApplyOne(id, s:Get(id)) end
    return
  end
  local frame = Layout:Frame(id)
  if frame then Layout:Place(frame, id, s:Get(id), s.pos) end
  for did, r in pairs(s.pos) do
    if r.attach and r.attach.to == id then
      local f = Layout:Frame(did)
      if f then Layout:Place(f, did, r, s.pos) end
      local m = Studio.movers[did]
      if m then Studio:PlaceMover(did, true) end
    end
  end
end

function Studio:PlaceMover(id, noPreview)
  local m = self.movers[id]
  if not m then return end
  local r = self.session:Rect(id)
  m:ClearAllPoints()
  m:SetSize(math.max(8, r.w), math.max(8, r.h))
  m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.l, r.b)
  m:Refresh()
  if self.session.sel[id] then self:RefreshInspector() end
  if not noPreview then preview(id) end
  if id == self.session.selected then self:DrawDistances() end
end

function Studio:PlaceAll()
  for id, m in pairs(self.movers) do if m:IsShown() then self:PlaceMover(id) end end
end

function Studio:Select(id, add)
  self.session:Select(id, add)
  self:RefreshSelection()
end

-- Redraws selection state without changing it.
function Studio:RefreshSelection()
  local s = self.session
  if s.selected and not s.sel[s.selected] then s.selected = nil end
  if not s.selected then s.selected = next(s.sel) end
  for mid, m in pairs(self.movers) do if s:Has(mid) then m:SetSelected(s.sel[mid] == true, mid == s.selected) end end
  if s.selected then
    self:PlaceMover(s.selected, true)
  else
    self.hud:SetText("Click to select  -  Shift-click or drag a box for several  -  Drag to move  -  Arrows nudge  -  Wheel picks stacked frames  -  Right-click explains")
  end
  self.inspector:SetShown(s.selected ~= nil)
  self:RefreshAlignBar()
  self:DrawDistances()
end

-- Dragging ----------------------------------------------------------------
local function dragTick()
  local d = Studio.drag
  if not d then return PUI.Ticker:Unregister("studio.drag") end
  local m = Studio.movers[d.id]
  local cx, cy = m:GetCenter()
  if not cx then return end
  local W, H = parentSize()
  local x, y = Studio.CenterOffset(cx, cy, W, H)
  local guides = {}
  if Schema:Get("studio.snap") then
    local _, _, g = Studio.session:SnapCenter(d.id, x, y, { mode = Schema:Get("studio.snapMode"), distance = Schema:Get("studio.snapDistance"),
      grid = Schema:Get("studio.gridSize"), visible = Studio:Visible() })
    guides = g
  end
  Studio:DrawGuides(guides)
  -- the rest of the selection follows the dragged mover
  if d.group then
    local dx, dy = cx - d.cx, cy - d.cy
    for oid, o in pairs(d.group) do
      local om = Studio.movers[oid]
      om:ClearAllPoints()
      om:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", o.l + dx, o.b + dy)
    end
  end
end

local function onDragStart(m)
  local s = Studio.session
  if s:Locked(m.id) then return end
  if not s.sel[m.id] then Studio:Select(m.id, IsShiftKeyDown()) end
  local cx, cy = m:GetCenter()
  Studio.drag = { id = m.id, cx = cx or 0, cy = cy or 0 }
  if Schema:Get("studio.groupDrag") and #s:Selection() > 1 then
    Studio.drag.group = {}
    for _, oid in ipairs(s:Selection()) do
      if oid ~= m.id and not s:Locked(oid) and not s:Get(oid).attach then
        local r = s:Rect(oid)
        Studio.drag.group[oid] = { l = r.l, b = r.b }
      end
    end
  end
  m:StartMoving()
  PUI.Ticker:Register("studio.drag", 0, dragTick, "Studio")
end

local function onDragStop(m)
  m:StopMovingOrSizing()
  PUI.Ticker:Unregister("studio.drag")
  Studio:DrawGuides({})
  local d = Studio.drag
  Studio.drag = nil
  local cx, cy = m:GetCenter()
  if not cx then return end
  local s = Studio.session
  local W, H = parentSize()
  local x, y = Studio.CenterOffset(cx, cy, W, H)
  if Schema:Get("studio.snap") then
    x, y = s:SnapCenter(m.id, x, y, { mode = Schema:Get("studio.snapMode"), distance = Schema:Get("studio.snapDistance"),
      grid = Schema:Get("studio.gridSize"), visible = Studio:Visible() })
  end
  local ch = { [m.id] = s:CenterAt(m.id, x, y) }
  if d and d.group then
    local before = s:Rect(m.id)
    local after = Layout:Rect(m.id, setmetatable({ [m.id] = ch[m.id] }, { __index = s.pos }), W, H)
    local dx, dy = after.l - before.l, after.b - before.b
    for oid in pairs(d.group) do
      local cur = s:Get(oid)
      local sc = cur.scale or 1
      ch[oid] = Studio.With(cur, { x = math.floor(cur.x + dx / sc + 0.5), y = math.floor(cur.y + dy / sc + 0.5) })
    end
  end
  s:Commit(ch, "drag")
  for id in pairs(ch) do Studio:PlaceMover(id) end
  Studio:RefreshButtons()
end

-- Movers ------------------------------------------------------------------
local function corner(m, point)
  local t = m:CreateTexture(nil, "OVERLAY")
  t:SetSize(6, 6)
  t:SetPoint("CENTER", m, point)
  Theme:Paint(t, "accent")
  return t
end

local function moverRefresh(m)
  local s = Studio.session
  local rec = s and s:Get(m.id)
  local el = Layout:Element(m.id)
  if not (rec and el) then return end
  m.badge:SetShown(el.editMode == true and Schema:Get("studio.editModeBadge"))
  m.link:SetShown(rec.attach ~= nil)
  m.hiddenMark:SetShown(rec.hide == true)
  m.icon:SetAlpha(rec.hide and 0.25 or (m.selected and 0.9 or 0.55))
  local labels = Schema:Get("studio.labels")
  m.chipFrame:SetShown(m.selected or labels == "always" or (labels == "hover" and m.hover))
  if m.primary then
    m.coords:SetText(rec.attach and ("attached " .. rec.attach.side:lower()) or string.format("%d, %d", rec.x, rec.y))
  end
end

function Studio:Mover(id)
  local m = self.movers[id]
  if m then return m end
  local el = Layout:Element(id)
  m = CreateFrame("Frame", nil, self.overlay)
  m.id = id
  m:SetSize(120, 40)
  m:SetFrameLevel(self.overlay:GetFrameLevel() + 5)
  m.bg = Theme:Slice(m, A.control, 20, "BACKGROUND")
  m.bg:SetVertexColor(1, 1, 1, 0.06)
  m.edge = Theme:Slice(m, A.border1, 4, "BORDER")
  m.edge:SetVertexColor(1, 1, 1, el.editMode and 0.10 or 0.16)
  m.fill = m:CreateTexture(nil, "ARTWORK")
  m.fill:SetAllPoints()
  Theme:Paint(m.fill, el.editMode and "info" or "accent", 0.12)
  m.sel = Theme:Slice(m, A.border1, 4, "OVERLAY")
  Theme:Paint(m.sel, "accent", 1, "vertex")
  local icon = el.kind == "blizzard" and "studio" or (Nav.Info(el.owner))
  m.icon = Kit.Icon(m, A.Icon(icon), 16)
  m.icon:SetPoint("CENTER")
  m.handles = { corner(m, "TOPLEFT"), corner(m, "TOPRIGHT"), corner(m, "BOTTOMLEFT"), corner(m, "BOTTOMRIGHT") }
  m.badge = Kit.Badge(m, "Edit Mode", "accent")
  m.badge:SetPoint("TOPRIGHT", -2, -2)
  m.link = Kit.Badge(m, "linked", "ok")
  m.link:SetPoint("BOTTOMRIGHT", -2, 2)
  m.hiddenMark = Kit.Badge(m, "hidden", "neutral")
  m.hiddenMark:SetPoint("BOTTOMLEFT", 2, 2)
  -- name chip: hover / always / selected (setting), with coordinates when primary
  m.chipFrame = CreateFrame("Frame", nil, m)
  m.chipFrame:SetHeight(20)
  m.chipFrame:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 4)
  m.chipBg = Theme:Slice(m.chipFrame, A.control, 20, "BACKGROUND")
  m.chipIcon = Kit.Icon(m.chipFrame, A.Icon(icon), 12)
  m.chipIcon:SetPoint("LEFT", 6, 0)
  m.chip = Kit.Text(m.chipFrame, "label", "text.primary")
  m.chip:SetPoint("LEFT", m.chipIcon, "RIGHT", 5, 0)
  m.chip:SetText(PUI.L[el.label])
  m.coords = Kit.Text(m.chipFrame, "mono", "text.primary")
  m.coords:SetPoint("LEFT", m.chip, "RIGHT", 8, 0)
  m.chipFrame:SetWidth(240)
  m.Refresh = moverRefresh
  function m:SetSelected(on, primary)
    self.selected, self.primary = on, primary
    self.fill:SetShown(on)
    self.sel:SetShown(on)
    for _, t in ipairs(self.handles) do t:SetShown(primary) end
    self.coords:SetShown(primary)
    if on then Theme:Paint(self.chipBg, "accent", 1, "vertex") else self.chipBg:SetVertexColor(0.11, 0.12, 0.16, 0.95) end
    Theme:Paint(self.chip, on and "bg0" or "text.primary", 1, "text")
    Theme:Paint(self.coords, on and "bg0" or "text.primary", 1, "text")
    self:Refresh()
  end
  m.selected, m.primary = false, false
  m:EnableMouse(true)
  m:SetMovable(true)
  m:RegisterForDrag("LeftButton")
  m:EnableMouseWheel(true)
  m:SetScript("OnEnter", function(self) self.hover = true; self:Refresh() end)
  m:SetScript("OnLeave", function(self) self.hover = false; self:Refresh() end)
  m:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then return Studio:Explain(self.id) end
    Studio:Select(self.id, IsShiftKeyDown())
  end)
  m:SetScript("OnMouseWheel", function(self) Studio:CycleAt(self.id) end)
  m:SetScript("OnDragStart", onDragStart)
  m:SetScript("OnDragStop", onDragStop)
  self.movers[id] = m
  return m
end

-- Mouse wheel over stacked movers: select the next one under the same point.
function Studio:CycleAt(id)
  if not Schema:Get("studio.wheelCycle") then return false end
  local r = self.session:Rect(id)
  local list = self.session:ElementsAt(r.l + r.w / 2, r.b + r.h / 2, self:Visible())
  if #list < 2 then return false end
  local cur = self.session.selected
  local nextId = list[1]
  for i, oid in ipairs(list) do if oid == cur then nextId = list[i % #list + 1] end end
  self:Select(nextId)
  self.movers[nextId]:Raise()
  return nextId
end

-- Guides ------------------------------------------------------------------
local function lineTex(pool, n, parent)
  local t = pool[n]
  if not t then t = parent:CreateTexture(nil, "BORDER"); pool[n] = t end
  t:ClearAllPoints()
  t:Show()
  return t
end

function Studio:DrawGrid()
  for i = 1, #self.gridLines do self.gridLines[i]:Hide() end
  if not self.overlay then return end
  local W, H = parentSize()
  local n = 0
  local function line(vertical, offset, centre)
    n = n + 1
    local t = lineTex(self.gridLines, n, self.overlay)
    if vertical then t:SetPoint("TOP", self.overlay, "CENTER", offset, H / 2); t:SetSize(1, H)
    else t:SetPoint("LEFT", self.overlay, "CENTER", -W / 2, offset); t:SetSize(W, 1) end
    if centre then Theme:Paint(t, "info", 0.55) else t:SetColorTexture(1, 1, 1, 0.035) end
  end
  if Schema:Get("studio.showGrid") then
    local g = Schema:Get("studio.gridSize")
    for x = g, W / 2, g do line(true, x); line(true, -x) end
    for y = g, H / 2, g do line(false, y); line(false, -y) end
  end
  if Schema:Get("studio.centerGuides") then line(true, 0, true); line(false, 0, true) end
  self.safe = self.safe or {}
  for _, t in ipairs(self.safe) do t:Hide() end
  if Schema:Get("studio.safeZone") then
    local zones = { { "TOPLEFT", W, 40 }, { "BOTTOMLEFT", W, 40 }, { "CENTER", W * 0.22, H * 0.3 } }
    for i, z in ipairs(zones) do
      local t = lineTex(self.safe, i, self.overlay)
      t:SetPoint(z[1], self.overlay, z[1], 0, z[1] == "CENTER" and -H * 0.05 or 0)
      t:SetSize(z[2], z[3])
      Theme:Paint(t, "warn", 0.06)
    end
  end
end

function Studio:DrawGuides(guides)
  self.guideLines = self.guideLines or {}
  for _, t in ipairs(self.guideLines) do t:Hide() end
  local W, H = parentSize()
  for i, g in ipairs(guides) do
    local t = lineTex(self.guideLines, i, self.overlay)
    t:SetDrawLayer("OVERLAY")
    if g.axis == "x" then t:SetPoint("BOTTOMLEFT", self.overlay, "BOTTOMLEFT", g.at, 0); t:SetSize(1, H)
    else t:SetPoint("BOTTOMLEFT", self.overlay, "BOTTOMLEFT", 0, g.at); t:SetSize(W, 1) end
    Theme:Paint(t, "ok", 0.9)
  end
end

-- Distance labels for the primary selection.
function Studio:DrawDistances()
  self.distLines, self.distText = self.distLines or {}, self.distText or {}
  for _, t in ipairs(self.distLines) do t:Hide() end
  for _, t in ipairs(self.distText) do t:Hide() end
  local id = self.session and self.session.selected
  if not (id and self.overlay and Schema:Get("studio.distanceLabels")) then return end
  local d = self.session:Distances(id, self:Visible())
  local r = self.session:Rect(id)
  local spans = {
    left = { r.l - d.left.gap, r.b + r.h / 2, d.left.gap, true }, right = { r.l + r.w, r.b + r.h / 2, d.right.gap, true },
    down = { r.l + r.w / 2, r.b - d.down.gap, d.down.gap, false }, up = { r.l + r.w / 2, r.b + r.h, d.up.gap, false },
  }
  local i = 0
  for _, side in ipairs({ "left", "right", "up", "down" }) do
    local sp = spans[side]
    if d[side].to ~= "screen" and sp[3] > 0 then
      i = i + 1
      local t = lineTex(self.distLines, i, self.overlay)
      t:SetDrawLayer("OVERLAY")
      t:SetPoint("BOTTOMLEFT", self.overlay, "BOTTOMLEFT", sp[1], sp[2])
      if sp[4] then t:SetSize(sp[3], 1) else t:SetSize(1, sp[3]) end
      Theme:Paint(t, "ok", 0.8)
      local fs = self.distText[i]
      if not fs then fs = Kit.Text(self.overlay, "mono", "ok"); self.distText[i] = fs end
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", t, "CENTER", sp[4] and 0 or 14, sp[4] and 9 or 0)
      fs:SetText(sp[3] .. " px")
      fs:Show()
    end
  end
end

function Studio:ApplyFilter()
  local blizz = Schema:Get("studio.blizzard.enabled")
  for id, m in pairs(self.movers) do
    local el = Layout:Element(id)
    local cat = Studio.Category(id)
    local inSession = self.session and self.session:Has(id)
    local show = el ~= nil and inSession and (cat ~= "blizzard" or blizz)
    if show and self.filter ~= "all" then show = cat == self.filter end
    if show and self.filter == "all" and cat == "blizzard" then show = self.session.touched[id] or Schema:Get("studio.blizzard.showAll") end
    m:SetShown(show and true or false)
  end
end

function Studio:RefreshButtons()
  local s = self.session
  if not s then return end
  self.undoBtn:SetLabel(#s.undo > 0 and ("Undo (" .. #s.undo .. ")") or "Undo")
  self.redoBtn:SetLabel(#s.redo > 0 and ("Redo (" .. #s.redo .. ")") or "Redo")
  self.snapToggle:SetValue_(Schema:Get("studio.snap") and true or false)
  local modes = { grid = "Snap: grid", elements = "Snap: elements", both = "Snap: elements + grid" }
  self.snapModeBtn:SetLabel(modes[Schema:Get("studio.snapMode")])
  self.gridBtn:SetLabel(Schema:Get("studio.showGrid") and ("Grid " .. Schema:Get("studio.gridSize")) or "Grid off")
  self.guidesToggle:SetValue_(Schema:Get("studio.centerGuides") and true or false)
  self.filterSeg:SetValue_(self.filter)
  if self.RefreshLayer then self:RefreshLayer() end
end

local function selectionNudge(dx, dy, step)
  local s = Studio.session
  local ids = s:Selection()
  if #ids == 0 then return end
  if #ids == 1 then s:Nudge(ids[1], dx, dy, step)
  else s:MoveGroup(ids, dx * step, dy * step) end
  for _, id in ipairs(ids) do Studio:PlaceMover(id) end
end
Studio.SelectionNudge = selectionNudge

local DIRS = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local function handleKey(_, key)
  local s = Studio.session
  local step = IsControlKeyDown() and Schema:Get("studio.nudgeCtrl") or IsShiftKeyDown() and Schema:Get("studio.nudgeShift") or 1
  local handled = true
  if DIRS[key] and s.selected then
    selectionNudge(DIRS[key][1], DIRS[key][2], step)
  elseif key == "Z" and IsControlKeyDown() then Studio:UndoRedo("Undo")
  elseif key == "Y" and IsControlKeyDown() then Studio:UndoRedo("Redo")
  elseif key == "A" and IsControlKeyDown() then
    for id in pairs(Studio:Visible()) do s.sel[id] = true end
    Studio:RefreshSelection()
  elseif key == "ESCAPE" then
    if next(s.sel) then Studio:Select(nil) else Studio:Exit() end
  else
    handled = false
  end
  if not InCombatLockdown() then Studio.overlay:SetPropagateKeyboardInput(not handled) end
  Studio:RefreshButtons()
end

function Studio:UndoRedo(which)
  local _, op = self.session[which](self.session)
  if op then for id in pairs(op.before) do self:PlaceMover(id) end end
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

function Studio:CycleSnapMode()
  local order = { grid = "elements", elements = "both", both = "grid" }
  Schema:Set("studio.snapMode", order[Schema:Get("studio.snapMode")] or "both")
end

-- Box select on empty overlay space (one Ticker entry while the box is drawn).
local function boxTick()
  local b = Studio.box
  if not b then return PUI.Ticker:Unregister("studio.box") end
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale() or 1
  x, y = x / sc, y / sc
  local l, r = math.min(b.x, x), math.max(b.x, x)
  local bt, t = math.min(b.y, y), math.max(b.y, y)
  Studio.boxTex:ClearAllPoints()
  Studio.boxTex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, bt)
  Studio.boxTex:SetSize(math.max(1, r - l), math.max(1, t - bt))
  Studio.boxTex:Show()
  b.rect = { l, bt, r, t }
end

local function boxStart(_, button)
  if button ~= "LeftButton" then return end
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale() or 1
  Studio.box = { x = (x or 0) / sc, y = (y or 0) / sc, add = IsShiftKeyDown() }
  PUI.Ticker:Register("studio.box", 0, boxTick, "Studio")
end

local function boxStop()
  local b = Studio.box
  Studio.box = nil
  PUI.Ticker:Unregister("studio.box")
  Studio.boxTex:Hide()
  if not b then return end
  if not b.rect or (b.rect[3] - b.rect[1] < 4 and b.rect[4] - b.rect[2] < 4) then
    if not b.add then Studio:Select(nil) end
    return
  end
  local s = Studio.session
  if not b.add then s.sel = {} end
  for id in pairs(Studio:Visible()) do
    local r = s:Rect(id)
    if r.l < b.rect[3] and r.l + r.w > b.rect[1] and r.b < b.rect[4] and r.b + r.h > b.rect[2] then s.sel[id] = true end
  end
  Studio:RefreshSelection()
end

function Studio:Build()
  local o = PUI:CreateFrame("Frame", "PhoenixUIStudio", UIParent, nil, "Studio")
  o:SetAllPoints(UIParent)
  o:SetFrameStrata("FULLSCREEN_DIALOG")
  self.shade = o:CreateTexture(nil, "BACKGROUND")
  self.shade:SetAllPoints()
  self.shade:SetColorTexture(0.02, 0.025, 0.03, Schema:Get("studio.overlayAlpha"))
  o:EnableKeyboard(true)
  o:EnableMouse(true)
  o:SetScript("OnKeyDown", handleKey)
  o:SetScript("OnMouseDown", boxStart)
  o:SetScript("OnMouseUp", boxStop)
  o:RegisterEvent("PLAYER_REGEN_DISABLED")
  o:SetScript("OnEvent", function() Studio:Suspend() end)
  self.overlay = o
  self.boxTex = o:CreateTexture(nil, "OVERLAY")
  Theme:Paint(self.boxTex, "accent", 0.15)
  self.boxTex:Hide()
  self:BuildToolbar(o)
  self:BuildInspector(o)
  self:BuildAlignBar(o)
  self:BuildLayoutsPanel(o)
  self:BuildExplain(o)
  local hint = CreateFrame("Frame", nil, o)
  hint:SetSize(10, 30)
  hint:SetPoint("BOTTOM", 0, 20)
  Kit.Window(hint)
  self.hud = Kit.Text(hint, "small", "text.secondary")
  self.hud:SetPoint("CENTER")
  hint:SetWidth(760)
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
  for _, id in ipairs(self.session.ids) do self:Mover(id) end
  if Options.frame then Options.frame:Hide() end
  o:Show()
  self:ApplyFilter()
  self:PlaceAll()
  self:DrawGrid()
  self:Select(nil)
  self:RefreshButtons()
  PUI:Log("studio", "open")
  return true
end

function Studio:IsOpen() return self.overlay ~= nil and self.overlay:IsShown() end

function Studio:Close()
  PUI.Ticker:Unregister("studio.drag")
  PUI.Ticker:Unregister("studio.box")
  self.drag, self.box = nil, nil
  self.overlay:Hide()
  self.suspended = false
  if self.layouts then self.layouts:Hide() end
  if self.explain then self.explain:Hide() end
  Layout:ApplyAll() -- element frames go back to the saved positions
  if PUI.Movers then PUI.Movers:ApplyAll() end
end

function Studio:Save()
  local phoenix, bz = self.session:Saved()
  Schema:Set("layout.positions", phoenix)
  Schema:Set("studio.blizzard.positions", bz)
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
  if self.drag then local m = self.movers[self.drag.id]; if m then m:StopMovingOrSizing() end end
  PUI.Ticker:Unregister("studio.drag")
  PUI.Ticker:Unregister("studio.box")
  self.drag, self.box = nil, nil
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
  self:PlaceAll()
  self:DrawGrid()
end

function Studio:OnGridChanged()
  if self:IsOpen() then self:DrawGrid(); self:RefreshButtons() end
end

function Studio:OnSnapChanged()
  if self:IsOpen() then self:RefreshButtons() end
end

function Studio:OnSettingsChanged()
  if not self:IsOpen() then return end
  self.shade:SetColorTexture(0.02, 0.025, 0.03, Schema:Get("studio.overlayAlpha"))
  self:DrawGrid()
  self:ApplyFilter()
  for _, m in pairs(self.movers) do if m:IsShown() then m:Refresh() end end
  self:DrawDistances()
  self:RefreshButtons()
end
