local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Studio v2 panels (mockup 12): two-row toolbar (layout layer, filters, snap,
-- grid, guides, undo/redo, layouts, save), inspector (position, size, scale,
-- anchor, attach with width/height match, layer, look, alpha by state, Edit
-- Mode hand-off, explain), the align bar for multi-select, the Layouts panel
-- (export/import with preview, templates, one-time MoveAny import) and the
-- Explain panel. Every control edits the session (undoable) or a setting.
local Studio, Theme = PUI.Studio, PUI.Theme
local Schema, Layout = PUI.Schema, PUI.Layout
local Options = PUI.Options
local Kit, A, Nav, Widgets = Options.Kit, Options.Assets, Options.Nav, Options.Widgets
local POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local FX, FY = Layout.FX, Layout.FY

local function parentSize() return UIParent:GetWidth() or 0, UIParent:GetHeight() or 0 end

local function changed(ids)
  for _, id in ipairs(ids) do Studio:PlaceMover(id) end
  Studio:RefreshButtons()
  Studio:RefreshInspector()
end
Studio.Changed = changed

local function sel() return Studio.session and Studio.session.selected end

local function field(parent, label, w, onCommit)
  local f = CreateFrame("EditBox", nil, parent)
  f:SetSize(w, 26)
  f:SetAutoFocus(false)
  f:SetFontObject(Kit.FontObject("mono"))
  f:SetJustifyH("RIGHT")
  f:SetTextInsets(30, 8, 0, 0)
  local bg = Theme:Slice(f, A.control, 20, "BACKGROUND")
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  local l = Kit.Text(f, "small", "muted")
  l:SetPoint("LEFT", 8, 0)
  l:SetText(label)
  f:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Studio:RefreshInspector() end)
  f:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local v = tonumber((self:GetText() or ""):match("[-%d%.]+"))
    if sel() then onCommit(sel(), v) end
    Studio:RefreshInspector()
  end)
  return f
end

local function label(parent, text, x, y)
  local t = Kit.Text(parent, "small", "text.secondary")
  t:SetPoint("TOPLEFT", x, y)
  t:SetText(text)
  return t
end

-- Toolbar ---------------------------------------------------------------------
function Studio:BuildToolbar(o)
  local bar = CreateFrame("Frame", nil, o)
  bar:SetSize(10, 84)
  bar:SetPoint("TOP", 0, -12)
  Kit.Window(bar)
  local logo = Kit.Icon(bar, A.logo, 22)
  logo:SetPoint("TOPLEFT", 14, -10)
  local name = Kit.Text(bar, "title", "text.primary")
  name:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  name:SetText("STUDIO")
  self.layerText = Kit.Text(bar, "small", "muted")
  self.layerText:SetPoint("LEFT", name, "RIGHT", 12, 0)
  -- row 1: layout layer + filters
  local x = 330
  local function row1(w, gap) w:SetPoint("TOPLEFT", x, -7); x = x + w:GetWidth() + (gap or 8); return w end
  self.layerSeg = row1(Kit.Segmented(bar, { "profile", "spec", "cond" }, { "Profile", "This spec", "This content" },
    function(v) Studio:SetLayer(v) end), 16)
  self.filterSeg = row1(Kit.Segmented(bar, Studio.FILTERS, Studio.FILTER_LABELS,
    function(v) Studio.filter = v; Studio:ApplyFilter(); Studio:PlaceAll(); Studio:RefreshButtons() end))
  local w1 = x
  -- row 2: tools
  x = 14
  local function row2(w, gap) w:SetPoint("TOPLEFT", x, -46); x = x + w:GetWidth() + (gap or 8); return w end
  self.snapToggle = row2(Kit.Toggle(bar, function(on) Schema:Set("studio.snap", on) end), 6)
  local snapText = Kit.Text(bar, "label", "text.secondary")
  snapText:SetText("Snap")
  snapText:SetPoint("TOPLEFT", x, -50)
  x = x + 40
  self.snapModeBtn = row2(Kit.Button(bar, "Snap: elements + grid", 170, function() Studio:CycleSnapMode() end, "secondary"))
  self.gridBtn = row2(Kit.Button(bar, "Grid 16", 84, function() Studio:CycleGrid() end, "secondary"))
  self.guidesToggle = row2(Kit.Toggle(bar, function(on) Schema:Set("studio.centerGuides", on) end), 6)
  local gText = Kit.Text(bar, "label", "text.secondary")
  gText:SetText("Guides")
  gText:SetPoint("TOPLEFT", x, -50)
  x = x + 58
  self.undoBtn = row2(Kit.Button(bar, "Undo", 84, function() Studio:UndoRedo("Undo") end, "ghost"), 2)
  self.redoBtn = row2(Kit.Button(bar, "Redo", 84, function() Studio:UndoRedo("Redo") end, "ghost"))
  row2(Kit.Button(bar, "Reset", 70, function()
    local s = Studio.session
    local ids = s:Selection()
    for _, id in ipairs(ids) do s:ResetElement(id) end
    changed(ids)
  end, "secondary"))
  row2(Kit.Button(bar, "Layouts", 90, function() Studio:ToggleLayouts() end, "secondary"), 16)
  row2(Kit.Button(bar, "Cancel", 80, function() Studio:Exit() end, "ghost"), 4)
  row2(Kit.Button(bar, "Save & exit", 110, function() Studio:Save() end, "primary"))
  bar:SetWidth(math.max(w1, x) + 6)
  self.toolbar = bar
end

-- Layout layer: the profile, this specialization, or this content (Overrides).
function Studio:SetLayer(layer)
  if self.session:Dirty() then
    self.hud:SetText("|cffffc24bSave or undo your changes|r before switching which layout you edit.")
    return self:RefreshButtons()
  end
  local O = PUI.Overrides
  if layer == "profile" then O:EditAs(nil)
  else
    local spec, cond = O.Context()
    if layer == "spec" then O:EditAs("spec", spec) else O:EditAs("cond", cond) end
  end
  self.layer = layer
  self.session = Studio.Session.New()
  for _, id in ipairs(self.session.ids) do self:Mover(id) end
  self:ApplyFilter()
  self:PlaceAll()
  self:Select(nil)
  self:RefreshButtons()
end

function Studio:RefreshLayer()
  local O = PUI.Overrides
  local layer, id = O:Editing()
  local seg = layer == "spec" and "spec" or (layer == "cond" and "cond" or "profile")
  self.layerSeg:SetValue_(seg)
  local profile = PUI.Profiles and select(1, PUI.Profiles:Active()) or "?"
  local where = layer == "spec" and ("spec " .. tostring(id)) or (layer == "cond" and (O.CONDITION_LABELS[id] or tostring(id)) or "all specs and content")
  self.layerText:SetText("Profile " .. tostring(profile) .. "  -  editing " .. where)
end

-- Inspector ---------------------------------------------------------------------
local function seg(parent, x, y, choices, labels, onPick)
  local s = Kit.Segmented(parent, choices, labels, onPick)
  s:SetPoint("TOPLEFT", x, y)
  return s
end

local function toggleRow(parent, text, x, y, onChange)
  local t = Kit.Toggle(parent, onChange)
  t:SetPoint("TOPLEFT", x, y)
  local l = Kit.Text(parent, "label", "text.secondary")
  l:SetPoint("LEFT", t, "RIGHT", 8, 0)
  l:SetText(text)
  return t
end

local function buildPosition(p)
  local s = function() return Studio.session end
  Kit.Section(p, "Position and size"):SetPoint("TOPLEFT", 18, -66)
  p.x = field(p, "X", 92, function(id, v) local c = s():Get(id); if v then s():Move(id, v, c.y, c.point); changed({ id }) end end)
  p.x:SetPoint("TOPLEFT", 18, -86)
  p.y = field(p, "Y", 92, function(id, v) local c = s():Get(id); if v then s():Move(id, c.x, v, c.point); changed({ id }) end end)
  p.y:SetPoint("LEFT", p.x, "RIGHT", 6, 0)
  p.scale = field(p, "%", 92, function(id, v) if v then s():Set(id, "scale", math.max(25, math.min(400, v)) / 100); changed({ id }) end end)
  p.scale:SetPoint("LEFT", p.y, "RIGHT", 6, 0)
  p.w = field(p, "W", 92, function(id, v) if v and Layout:Element(id).resizable then s():Set(id, "w", math.max(4, v)); changed({ id }) end end)
  p.w:SetPoint("TOPLEFT", 18, -116)
  p.h = field(p, "H", 92, function(id, v) if v and Layout:Element(id).resizable then s():Set(id, "h", math.max(4, v)); changed({ id }) end end)
  p.h:SetPoint("LEFT", p.w, "RIGHT", 6, 0)
  p.size = Kit.Text(p, "small", "muted")
  p.size:SetPoint("LEFT", p.h, "RIGHT", 8, 0)
  label(p, "Anchor", 18, -152)
  p.anchors = {}
  for i, point in ipairs(POINTS) do
    local b = CreateFrame("Button", nil, p)
    b:SetSize(18, 18)
    b:SetPoint("TOPLEFT", 18 + ((i - 1) % 3) * 21, -168 - math.floor((i - 1) / 3) * 21)
    b.bg = Theme:Slice(b, A.control, 20, "BACKGROUND")
    b.point = point
    b:SetScript("OnClick", function() Studio:Reanchor(point) end)
    p.anchors[i] = b
  end
  p.anchorText = Kit.Text(p, "small", "text.secondary")
  p.anchorText:SetPoint("TOPLEFT", 92, -170)
  label(p, "Nudge", 92, -210)
  local arrows = { { "<", -1, 0 }, { "^", 0, 1 }, { "v", 0, -1 }, { ">", 1, 0 } }
  for i, a in ipairs(arrows) do
    local b = Kit.Button(p, a[1], 26, function()
      Studio.SelectionNudge(a[2], a[3], IsShiftKeyDown() and Schema:Get("studio.nudgeShift") or 1)
      Studio:RefreshButtons()
    end, "secondary")
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", 140 + (i - 1) * 28, -206)
  end
end

local function buildAttach(p)
  Kit.Section(p, "Attach"):SetPoint("TOPLEFT", 18, -240)
  p.attachTo = Kit.Button(p, "Attach to...", 170, function(self)
    local id = sel()
    if not id then return end
    local s = Studio.session
    local list = { "" }
    for oid in pairs(Studio:Visible()) do if oid ~= id and not Layout.WouldCycle(s.pos, id, oid) then list[#list + 1] = oid end end
    table.sort(list, function(a, b) if a == "" then return true elseif b == "" then return false end return Layout:Element(a).label < Layout:Element(b).label end)
    Widgets.OpenMenu(self, list, function(v) return v == "" and "Not attached (free)" or PUI.L[Layout:Element(v).label] end,
      s:Get(id).attach and s:Get(id).attach.to or "", function(v)
        if v == "" then s:Detach(id) else
          local a = s:Get(id).attach or {}
          local ok, why = s:Attach(id, v, a.side or "RIGHT", a.gap or 2, a.align, a.matchW, a.matchH)
          if not ok then Studio.hud:SetText("|cffff6b6b" .. why .. "|r") end
        end
        changed({ id })
      end)
  end, "secondary")
  p.attachTo:SetPoint("TOPLEFT", 18, -260)
  p.gap = field(p, "Gap", 110, function(id, v)
    local a = Studio.session:Get(id).attach
    if a and v then Studio.session:Attach(id, a.to, a.side, math.max(-200, math.min(200, v)), a.align, a.matchW, a.matchH); changed({ id }) end
  end)
  p.gap:SetPoint("LEFT", p.attachTo, "RIGHT", 8, 0)
  local function setA(k, v)
    local id = sel()
    local a = id and Studio.session:Get(id).attach
    if not a then return end
    local n = PUI.Schema.Copy(a)
    n[k] = v
    Studio.session:Attach(id, n.to, n.side, n.gap, n.align, n.matchW, n.matchH)
    changed({ id })
  end
  p.side = seg(p, 18, -292, Layout.SIDES, { "Left", "Right", "Top", "Bottom" }, function(v) setA("side", v) end)
  p.align = seg(p, 18, -324, Layout.ALIGNS, { "Start", "Centre", "End" }, function(v) setA("align", v) end)
  p.matchW = toggleRow(p, "Match width", 18, -360, function(on) setA("matchW", on or nil) end)
  p.matchH = toggleRow(p, "Match height", 160, -360, function(on) setA("matchH", on or nil) end)
end

local function buildLook(p)
  Kit.Section(p, "Layer and look"):SetPoint("TOPLEFT", 18, -392)
  p.strata = seg(p, 18, -412, { "", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }, { "Auto", "Back", "Low", "Med", "High", "Top" },
    function(v) local id = sel(); if id then Studio.session:Set(id, "strata", v ~= "" and v or nil); changed({ id }) end end)
  p.level = field(p, "Lvl", 92, function(id, v) Studio.session:Set(id, "level", v and math.max(0, math.min(100, math.floor(v))) or nil); changed({ id }) end)
  p.level:SetPoint("TOPLEFT", 18, -446)
  p.alpha = field(p, "Opa", 92, function(id, v) Studio.session:Set(id, "alpha", v and math.max(0, math.min(100, v)) / 100 or nil); changed({ id }) end)
  p.alpha:SetPoint("LEFT", p.level, "RIGHT", 6, 0)
  p.hide = toggleRow(p, "Hide", 18, -480, function(on) local id = sel(); if id then Studio.session:Set(id, "hide", on or nil); changed({ id }) end end)
  p.click = toggleRow(p, "Click-through", 120, -480, function(on) local id = sel(); if id then Studio.session:Set(id, "clickThrough", on or nil); changed({ id }) end end)
  Kit.Section(p, "Alpha by state (empty = unchanged)"):SetPoint("TOPLEFT", 18, -512)
  p.fade = {}
  for i, k in ipairs(Layout.FADE_ORDER) do
    local f = field(p, "", 64, function(id, v) Studio.session:SetFade(id, k, v and math.max(0, math.min(100, v)) / 100 or nil); changed({ id }) end)
    f:SetPoint("TOPLEFT", 18 + ((i - 1) % 4) * 72, -548 - math.floor((i - 1) / 4) * 46)
    local l = Kit.Text(p, "small", "muted")
    l:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 2)
    l:SetText(Layout.FADE_LABELS[k])
    p.fade[k] = f
  end
  p.hover = toggleRow(p, "Mouse-over shows it", 18, -640, function(on) local id = sel(); if id then Studio.session:SetFade(id, "hover", on or nil); changed({ id }) end end)
end

function Studio:BuildInspector(o)
  local p = CreateFrame("Frame", nil, o)
  p:SetSize(320, 730)
  p:SetPoint("TOPRIGHT", -24, -110)
  Kit.Window(p)
  p:EnableMouse(true)
  p.icon = Kit.Icon(p, A.Icon("unitframes"), 30)
  p.icon:SetPoint("TOPLEFT", 18, -18)
  p.title = Kit.Text(p, "body", "text.primary")
  p.title:SetPoint("TOPLEFT", p.icon, "TOPRIGHT", 10, 0)
  p.sub = Kit.Text(p, "small", "muted")
  p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -3)
  local close = Kit.Button(p, "x", 26, function() Studio:Select(nil) end, "ghost")
  close:SetPoint("TOPRIGHT", -10, -14)
  buildPosition(p)
  buildAttach(p)
  buildLook(p)
  -- Edit Mode hand-off (replaces the editable body for Edit Mode elements)
  p.em = CreateFrame("Frame", nil, p)
  p.em:SetPoint("TOPLEFT", 0, -60)
  p.em:SetPoint("BOTTOMRIGHT", 0, 60)
  p.emShade = p.em:CreateTexture(nil, "BACKGROUND")
  p.emShade:SetAllPoints()
  p.emShade:SetColorTexture(0.05, 0.06, 0.08, 0.97)
  p.emText = Kit.Text(p.em, "text", "text.secondary")
  p.emText:SetPoint("TOPLEFT", 18, -16)
  p.emText:SetWidth(284)
  p.emText:SetText("Blizzard's Edit Mode owns this element, so Phoenix leaves it alone to avoid fighting Edit Mode. Move it in Edit Mode; Phoenix keeps its own frames out of the way.")
  p.emButton = Kit.Button(p.em, "Open in Edit Mode", 180, function() Studio:OpenEditMode() end, "primary")
  p.emButton:SetPoint("TOPLEFT", 18, -96)
  p.em:EnableMouse(true)
  p.em:Hide()
  local explain = Kit.Button(p, "Explain", 90, function() Studio:Explain(sel()) end, "secondary")
  explain:SetPoint("BOTTOMLEFT", 18, 16)
  local mirror = Kit.Button(p, "Mirror", 90, function()
    local id = sel()
    if not id then return end
    local pos = Studio.session:Get(id)
    local flip = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" }
    Studio.session:Move(id, -pos.x, pos.y, flip[pos.point] or pos.point)
    changed({ id })
  end, "secondary")
  mirror:SetPoint("LEFT", explain, "RIGHT", 8, 0)
  local settings = Kit.Button(p, "Settings", 100, function()
    local id = sel()
    local owner = id and Layout:Element(id).owner
    if Studio:Exit() and owner and owner ~= "Blizzard" then Options:Open(owner) end
  end, "secondary")
  settings:SetPoint("LEFT", mirror, "RIGHT", 8, 0)
  p:Hide()
  self.inspector = p
end

function Studio:OpenEditMode()
  if self.session:Dirty() then
    self.hud:SetText("|cffffc24bSave or discard your Studio changes|r before opening Edit Mode.")
    return false
  end
  self:Exit(true)
  return PUI.Movers:OpenEditMode()
end

-- Re-anchor the selected element to a new point without moving it on screen.
function Studio:Reanchor(point)
  local id = sel()
  if not id then return end
  local s = self.session
  local r = s:Rect(id)
  local W, H = parentSize()
  local sc = s:Get(id).scale or 1
  local x = ((r.l + FX[point] * r.w) - FX[point] * W) / sc
  local y = ((r.b + FY[point] * r.h) - FY[point] * H) / sc
  s:Move(id, x, y, point)
  changed({ id })
end

local function pct(v) return v and tostring(math.floor(v * 100 + 0.5)) or "" end

function Studio:RefreshInspector()
  local p, id = self.inspector, self.session and self.session.selected
  if not (p and id) then return end
  local el, pos = Layout:Element(id), self.session:Get(id)
  local icon, owner = Nav.Info(el.owner)
  if el.kind == "blizzard" then icon, owner = "studio", "Blizzard - " .. (PUI.Movers.CATEGORY_LABELS[el.category] or "") end
  p.icon:SetTexture(A.Icon(icon))
  p.title:SetText(PUI.L[el.label])
  local n = #self.session:Selection()
  p.sub:SetText(owner .. (n > 1 and ("  -  " .. n .. " selected") or ""))
  p.em:SetShown(el.editMode == true)
  local function set(box, text) if not box:HasFocus() then box:SetText(text) end end
  set(p.x, tostring(pos.x)); set(p.y, tostring(pos.y)); set(p.scale, pct(pos.scale or 1))
  local w, h = Layout:BaseSize(id, pos)
  set(p.w, tostring(math.floor(w + 0.5))); set(p.h, tostring(math.floor(h + 0.5)))
  p.size:SetText(el.resizable and "resizable" or "size set by module")
  for _, b in ipairs(p.anchors) do
    if b.point == pos.point then Theme:Paint(b.bg, "accent", 1, "vertex") else Theme:Paint(b.bg, "bg3", 1, "vertex") end
  end
  p.anchorText:SetText("Point |cffece8e2" .. pos.point .. "|r\nto screen |cffece8e2" .. pos.point .. "|r")
  local a = pos.attach
  p.attachTo:SetLabel(a and ("To " .. PUI.L[(Layout:Element(a.to) or { label = a.to }).label]) or "Attach to...")
  set(p.gap, a and tostring(a.gap or 0) or "")
  p.side:SetValue_(a and a.side); p.align:SetValue_(a and (a.align or "CENTER"))
  p.matchW:SetValue_(a and a.matchW or false); p.matchH:SetValue_(a and a.matchH or false)
  p.strata:SetValue_(pos.strata or "")
  set(p.level, pos.level and tostring(pos.level) or ""); set(p.alpha, pct(pos.alpha))
  p.hide:SetValue_(pos.hide or false); p.click:SetValue_(pos.clickThrough or false)
  for k, f in pairs(p.fade) do set(f, pct(pos.fade and pos.fade[k])) end
  p.hover:SetValue_(pos.fade and pos.fade.hover or false)
end

-- Align bar (two or more selected) ---------------------------------------------
function Studio:BuildAlignBar(o)
  local bar = CreateFrame("Frame", nil, o)
  bar:SetSize(10, 44)
  bar:SetPoint("TOP", 0, -104)
  Kit.Window(bar)
  local t = Kit.Text(bar, "label", "text.secondary")
  t:SetPoint("LEFT", 14, 0)
  bar.count = t
  local x = 120
  local acts = { { "Left", "left" }, { "Centre", "hcenter" }, { "Right", "right" }, { "Top", "top" }, { "Middle", "vcenter" }, { "Bottom", "bottom" } }
  for _, a in ipairs(acts) do
    local b = Kit.Button(bar, a[1], 70, function()
      local ids = Studio.session:Selection()
      Studio.session:Align(ids, a[2]); changed(ids)
    end, "secondary")
    b:SetPoint("LEFT", x, 0)
    x = x + 74
  end
  for _, d in ipairs({ { "Space across", "h" }, { "Space down", "v" } }) do
    local b = Kit.Button(bar, d[1], 110, function()
      local ids = Studio.session:Selection()
      Studio.session:Distribute(ids, d[2]); changed(ids)
    end, "secondary")
    b:SetPoint("LEFT", x + 8, 0)
    x = x + 116
  end
  local chain = Kit.Button(bar, "Chain right", 110, function()
    -- attach each to the previous one (left to right), matching heights
    local s = Studio.session
    local ids = s:Selection()
    table.sort(ids, function(a, b) return s:Rect(a).l < s:Rect(b).l end)
    for i = 2, #ids do s:Attach(ids[i], ids[i - 1], "RIGHT", 2, "CENTER", nil, true) end
    changed(ids)
  end, "secondary")
  chain:SetPoint("LEFT", x + 8, 0)
  bar:SetWidth(x + 130)
  bar:Hide()
  self.alignBar = bar
end

function Studio:RefreshAlignBar()
  local n = self.session and #self.session:Selection() or 0
  self.alignBar:SetShown(n > 1)
  self.alignBar.count:SetText(n .. " selected")
end

-- Layouts panel: export/import with preview, templates, MoveAny import ---------
local function editBox(parent, w, h)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, h)
  e:SetAutoFocus(false)
  e:SetMultiLine(true)
  e:SetMaxBytes(256 * 1024)
  e:SetFontObject(Kit.FontObject("mono"))
  e:SetTextInsets(10, 10, 8, 8)
  local bg = Theme:Slice(e, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  return e
end

function Studio:BuildLayoutsPanel(o)
  local p = CreateFrame("Frame", nil, o)
  p:SetSize(520, 470)
  p:SetPoint("TOPLEFT", 24, -110)
  Kit.Window(p)
  p:EnableMouse(true)
  local title = Kit.Text(p, "body", "text.primary")
  title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Layouts")
  local close = Kit.Button(p, "x", 26, function() p:Hide() end, "ghost")
  close:SetPoint("TOPRIGHT", -10, -12)
  Kit.Section(p, "Share"):SetPoint("TOPLEFT", 18, -46)
  p.box = editBox(p, 484, 90)
  p.box:SetPoint("TOPLEFT", 18, -66)
  p.preview = Kit.Text(p, "small", "text.secondary")
  p.preview:SetPoint("TOPLEFT", 18, -196)
  p.preview:SetWidth(484)
  p.preview:SetJustifyH("LEFT")
  local function say(text, tone) p.preview:SetText((tone == "err" and "|cffff6b6b" or "") .. text .. (tone == "err" and "|r" or "")) end
  p.say = say
  local export = Kit.Button(p, "Export", 90, function()
    local s = Studio.Export(Studio.session)
    p.box:SetText(s); p.box:SetFocus(); p.box:HighlightText()
    say("Copy with Ctrl C. " .. #s .. " characters. Includes size, layer, look, attachments and Blizzard elements you changed.")
  end, "primary")
  export:SetPoint("TOPLEFT", 18, -164)
  local check = Kit.Button(p, "Check", 80, function()
    local plan, why = Studio.Decode(p.box:GetText(), Studio.session)
    Studio.plan = plan
    if not plan then return say(why, "err") end
    say(string.format("%s: %d elements (%d change, %d already match), %d not installed here%s%s. Apply previews it live; Save & exit keeps it.",
      plan.name, plan.known, plan.changed, plan.kept, plan.unknown, plan.scaled and ", scaled to your screen" or "",
      #plan.invalid > 0 and (", " .. #plan.invalid .. " invalid") or ""))
  end, "secondary")
  check:SetPoint("LEFT", export, "RIGHT", 8, 0)
  local apply = Kit.Button(p, "Apply", 80, function()
    if not Studio.plan then return say("Check a string first.", "err") end
    local ok, why = Studio.ApplyPlan(Studio.session, Studio.plan)
    if not ok then return say(why, "err") end
    Studio.plan = nil
    Studio:PlaceAll(); Studio:RefreshButtons()
    say("Applied to this session. Undo reverts it; Save & exit keeps it.")
  end, "secondary")
  apply:SetPoint("LEFT", check, "RIGHT", 8, 0)
  Kit.Section(p, "Templates"):SetPoint("TOPLEFT", 18, -250)
  p.name = CreateFrame("EditBox", nil, p)
  p.name:SetSize(220, 28)
  p.name:SetAutoFocus(false)
  p.name:SetFontObject(Kit.FontObject("label"))
  p.name:SetTextInsets(10, 10, 0, 0)
  Theme:Slice(p.name, A.control, 20):SetVertexColor(0.06, 0.07, 0.09, 1)
  p.name:SetPoint("TOPLEFT", 18, -272)
  p.name:SetScript("OnEscapePressed", p.name.ClearFocus)
  local saveT = Kit.Button(p, "Save as template", 140, function()
    local ok, why = Studio.SaveTemplate(Studio.session, p.name:GetText())
    if not ok then return say(why, "err") end
    say("Saved layout '" .. p.name:GetText() .. "'.")
  end, "secondary")
  saveT:SetPoint("LEFT", p.name, "RIGHT", 8, 0)
  local applyT = Kit.Button(p, "Apply template...", 150, function(self)
    local list = Studio.Templates()
    if #list == 0 then return say("No saved layouts yet.", "err") end
    Widgets.OpenMenu(self, list, function(v) return v end, nil, function(v)
      Studio.ApplyTemplate(Studio.session, v); Studio:PlaceAll(); Studio:RefreshButtons()
      say("Applied '" .. v .. "' (scaled to your screen). Undo reverts it.")
    end)
  end, "secondary")
  applyT:SetPoint("TOPLEFT", 18, -308)
  local delT = Kit.Button(p, "Delete template...", 150, function(self)
    local list = Studio.Templates()
    if #list == 0 then return say("No saved layouts yet.", "err") end
    Widgets.OpenMenu(self, list, function(v) return v end, nil, function(v)
      PUI.Dialogs:Confirm({ title = "Delete layout", text = "Delete the saved layout '" .. v .. "'?", accept = "Delete", danger = true,
        onAccept = function() Studio.DeleteTemplate(v); say("Deleted '" .. v .. "'.") end })
    end)
  end, "ghost")
  delT:SetPoint("LEFT", applyT, "RIGHT", 8, 0)
  local resetAll = Kit.Button(p, "Phoenix default", 140, function()
    Studio.session:ResetAll(); Studio:PlaceAll(); Studio:RefreshButtons()
    say("Every Phoenix element is back at its default (undo reverts it).")
  end, "ghost")
  resetAll:SetPoint("LEFT", delT, "RIGHT", 8, 0)
  Kit.Section(p, "From another addon"):SetPoint("TOPLEFT", 18, -356)
  p.moveany = Kit.Button(p, "Import from MoveAny", 180, function() Studio:ImportMoveAny() end, "secondary")
  p.moveany:SetPoint("TOPLEFT", 18, -378)
  p.maNote = Kit.Text(p, "small", "muted")
  p.maNote:SetPoint("LEFT", p.moveany, "RIGHT", 10, 0)
  p.maNote:SetWidth(290)
  p.maNote:SetJustifyH("LEFT")
  p.maNote:SetText("One-time, read-only: MoveAny's own settings are never changed.")
  p:Hide()
  self.layouts = p
end

function Studio:ToggleLayouts()
  self.layouts:SetShown(not self.layouts:IsShown())
  if self.layouts:IsShown() then self.explain:Hide() end
end

function Studio:ImportMoveAny()
  local p = self.layouts
  local plan, why = PUI.Movers.Import.MoveAny()
  if not plan then p.say(why, "err"); return false end
  if not Schema:Get("studio.blizzard.enabled") then
    p.say("Turn on 'Blizzard elements in Studio' first (Settings > Studio); MoveAny moves Blizzard frames.", "err")
    return false
  end
  local ok = Studio.ApplyPlan(self.session, { positions = {}, blizzard = plan.blizzard, invalid = {} })
  self:ApplyFilter(); self:PlaceAll(); self:RefreshButtons()
  p.say(string.format("MoveAny profile %s: %d elements previewed%s, %d left to Edit Mode (%s), %d not known. Save & exit keeps them.",
    plan.profile, plan.count, PUI.DB.sv.moveAnyImported and " (imported before)" or "", #plan.editMode,
    table.concat(plan.editMode, ", "):sub(1, 80), #plan.skipped))
  PUI.DB.sv.moveAnyImported = true
  return ok, plan
end

-- Explain panel -----------------------------------------------------------------
function Studio:BuildExplain(o)
  local p = CreateFrame("Frame", nil, o)
  p:SetSize(420, 360)
  p:SetPoint("TOPLEFT", 24, -110)
  Kit.Window(p)
  p:EnableMouse(true)
  p.title = Kit.Text(p, "body", "text.primary")
  p.title:SetPoint("TOPLEFT", 18, -16)
  local close = Kit.Button(p, "x", 26, function() p:Hide() end, "ghost")
  close:SetPoint("TOPRIGHT", -10, -12)
  p.text = Kit.Text(p, "small", "text.secondary")
  p.text:SetPoint("TOPLEFT", 18, -48)
  p.text:SetWidth(384)
  p.text:SetJustifyH("LEFT")
  p.text:SetJustifyV("TOP")
  p:Hide()
  self.explain = p
end

function Studio:Explain(id)
  if not id then return nil end
  local e = Studio.ExplainElement(id, self.session)
  if not e then return nil end
  local p = self.explain
  p.title:SetText("Explain: " .. PUI.L[e.label])
  local lines = {}
  for i = 1, math.min(#e.lines, 22) do lines[i] = e.lines[i] end
  if #e.lines > 22 then lines[#lines + 1] = "... and " .. (#e.lines - 22) .. " more" end
  p.text:SetText(table.concat(lines, "\n") .. "\n\n" .. e.keys .. " settings drive this element.")
  p:Show()
  self.layouts:Hide()
  return e
end
