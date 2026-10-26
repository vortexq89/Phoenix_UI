local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Options window (design mockups 01-04): glass window 1420x860, header
-- (mark, search with Ctrl K hint, Simple/Advanced, profile chip, close),
-- grouped sidebar with colour icons and status dots, and a content host that
-- shows the Dashboard, a module page (tabs, settings, live preview) or the
-- Theme & Media page. Every change applies live through the schema.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Nav = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Nav

local W, H, SIDEBAR, TOP = 1420, 860, 248, 72
local MIN_W, MIN_H, MAX_W, MAX_H = 1420, 700, 2400, 1500
Options.SIZE = { W = W, H = H, SIDEBAR = SIDEBAR, TOP = TOP }
Options.page = "Dashboard"
-- Pages drawn by their own view instead of settings rows.
Options.CUSTOM = {
  Theme = function() return Options.ThemePage end,
  Profiles = function() return Options.ProfilesPage end,
  Sentinel = function() return PUI.Sentinel and PUI.Sentinel.Viewer and Options.SentinelPage end,
}

local function buildHeader(f)
  local mark = Kit.Icon(f, A.logo, 36)
  mark:SetPoint("TOPLEFT", 22, -18)
  local title = Kit.Text(f, "title", "text.primary")
  title:SetPoint("TOPLEFT", mark, "TOPRIGHT", 10, -1)
  title:SetText("PHOENIX |cffff7a1aUI|r")
  local ver = Kit.Text(f, "small", "muted")
  ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  ver:SetText("v" .. (C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "?") .. "  |  " .. (PUI.IS_FOREVER and "Forever" or "Midnight"))
  f.versionText = ver

  local search = CreateFrame("EditBox", "PhoenixUIOptionsSearch", f)
  search:SetSize(420, 34)
  search:SetPoint("TOPLEFT", SIDEBAR + 24, -19)
  search:SetAutoFocus(false)
  search:SetFontObject(Kit.FontObject("label"))
  search:SetTextInsets(34, 70, 0, 0)
  local sbg = Theme:Slice(search, A.control, 20)
  sbg:SetVertexColor(0.06, 0.07, 0.09, 1)
  local hint = Kit.Text(search, "small", "muted")
  hint:SetPoint("LEFT", 34, 0)
  -- magnifier: a ring plus a rotated handle (no extra media)
  local lens = Kit.Icon(search, A.thumbRing, 13, "OVERLAY")
  lens:SetPoint("LEFT", 12, 2)
  Theme:Paint(lens, "muted", 1, "vertex")
  local handle = search:CreateTexture(nil, "OVERLAY")
  handle:SetSize(6, 2)
  handle:SetPoint("CENTER", lens, "BOTTOMRIGHT", 0, 1)
  handle:SetRotation(-math.pi / 4)
  Theme:Paint(handle, "muted")
  f.searchIcon = lens
  hint:SetText("Search " .. #Schema.keys .. " settings...")
  local kbd = Kit.Badge(search, "Ctrl K", "neutral")
  kbd:SetPoint("RIGHT", -8, 0)
  search:SetScript("OnTextChanged", function(self, user)
    hint:SetShown(self:GetText() == "")
    if user then Options:Render() end
  end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); Options:Render() end)
  f.search = search

  local close = CreateFrame("Button", nil, f)
  close:SetSize(30, 30)
  close:SetPoint("TOPRIGHT", -18, -21)
  close.x = Kit.Text(close, "title", "muted")
  close.x:SetPoint("CENTER")
  close.x:SetText("x")
  close:SetScript("OnClick", function() f:Hide() end)

  f.chip = Kit.Button(f, "", 190, function() Options:Open("Options") end, "secondary")
  f.chip:SetPoint("RIGHT", close, "LEFT", -12, 0)
  f.chip:SetHeight(34)
  f.chip.avatar = f.chip:CreateTexture(nil, "ARTWORK")
  f.chip.avatar:SetSize(20, 20)
  f.chip.avatar:SetPoint("LEFT", 8, 0)
  f.chip.label:ClearAllPoints()
  f.chip.label:SetPoint("LEFT", f.chip.avatar, "RIGHT", 8, 0)

  f.mode = Kit.Segmented(f, { "simple", "advanced" }, { "Simple", "Advanced" }, function(v) Model.Commit("options.mode", v) end)
  f.mode:SetPoint("RIGHT", f.chip, "LEFT", -12, 0)

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Options:SaveWindow() end)
  local line = Kit.Divider(f)
  line:SetPoint("TOPLEFT", 0, -TOP)
  line:SetPoint("TOPRIGHT", 0, -TOP)
end

local function buildSidebar(f)
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 0, -TOP)
  side:SetPoint("BOTTOMLEFT", 0, 0)
  side:SetWidth(SIDEBAR)
  local bg = side:CreateTexture(nil, "BACKGROUND", nil, 1)
  bg:SetPoint("TOPLEFT", 3, 0)
  bg:SetPoint("BOTTOMRIGHT", 0, 3)
  bg:SetColorTexture(0, 0, 0, 0.18)
  local line = Kit.Divider(side, true)
  line:SetPoint("TOPRIGHT")
  line:SetPoint("BOTTOMRIGHT")
  side.items, side.captions, side.collapsed = {}, {}, {}
  f.side = side
end

local function buildContent(f)
  local host = CreateFrame("Frame", nil, f)
  host:SetPoint("TOPLEFT", SIDEBAR, -TOP)
  host:SetPoint("BOTTOMRIGHT")
  f.host = host
  -- generic scrolling column used by module pages and search
  local scroll = CreateFrame("ScrollFrame", "PhoenixUIOptionsScroll", host)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, self:GetScrollChild():GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 60)))
  end)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(600, 10)
  scroll:SetScrollChild(child)
  f.scroll, f.child = scroll, child
  f.empty = Kit.Text(child, "body", "muted")
  f.empty:SetPoint("TOPLEFT", 14, -12)
end

function Options:Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUIOptions", UIParent, nil, "Options")
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetToplevel(true)
  Kit.Window(f)
  tinsert(UISpecialFrames, "PhoenixUIOptions")
  buildHeader(f)
  buildSidebar(f)
  buildContent(f)
  f:SetScript("OnHide", function()
    if Options.Widgets.popup then Options.Widgets.popup:Hide() end
    if Options.Widgets.FlushColor then Options.Widgets.FlushColor() end
  end)
  -- resizable from the bottom-right grip; size and place are settings
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) end
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(18, 18)
  grip:SetPoint("BOTTOMRIGHT", -6, 6)
  for i = 1, 3 do -- three diagonal dots, drawn (no extra media)
    local d = grip:CreateTexture(nil, "OVERLAY")
    d:SetSize(2, 2)
    d:SetPoint("BOTTOMRIGHT", -(i - 1) * 4, (3 - i) * 0)
    Theme:Paint(d, "muted", 0.8)
    local d2 = grip:CreateTexture(nil, "OVERLAY")
    d2:SetSize(2, 2)
    d2:SetPoint("BOTTOMRIGHT", 0, (i - 1) * 4)
    Theme:Paint(d2, "muted", 0.8)
  end
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); Options:SaveWindow() end)
  f.grip = grip
  -- open animation: C-side AnimationGroup (no OnUpdate), off with options.motion
  local intro = f:CreateAnimationGroup()
  local fade = intro:CreateAnimation("Alpha")
  fade:SetFromAlpha(0)
  fade:SetToAlpha(1)
  fade:SetDuration(0.14)
  fade:SetSmoothing("OUT")
  local rise = intro:CreateAnimation("Translation")
  rise:SetOffset(0, 8)
  rise:SetDuration(0.14)
  rise:SetSmoothing("OUT")
  f.intro = intro
  f:SetScript("OnShow", function(self) if Schema:Get("options.motion") then self.intro:Play() end end)
  f:Hide()
  self.frame = f
  self:OnWindowSettings()
  return f
end

-- Window settings: scale, tint, size and the opening anchor (live).
function Options:OnWindowSettings()
  local f = self.frame
  if not f then return end
  f:SetScale(Schema:Get("options.scale"))
  local t = Schema:Get("options.tint")
  if f.glassTint then f.glassTint:SetColorTexture(t.r, t.g, t.b, (t.a or 0) * 0.6) end
  local size = Schema:Get("options.window")
  f:SetSize(math.min(MAX_W, math.max(MIN_W, size.w or W)), math.min(MAX_H, math.max(MIN_H, size.h or H)))
  if not self.savingWindow then
    local a = Schema:Get("options.openAnchor")
    f:ClearAllPoints()
    f:SetPoint(a.point, UIParent, a.relPoint or a.point, a.x, a.y)
  end
  if f:IsShown() then self:Render() end
end

-- After a drag or resize: store size and the nearest anchor (integer px).
function Options:SaveWindow()
  local f = self.frame
  local w, h = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
  self.savingWindow = true
  Model.Commit("options.window", { w = w, h = h })
  local l, b = f:GetLeft(), f:GetBottom()
  if l and b then
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local cx = (l + w / 2) * s - UIParent:GetWidth() / 2
    local cy = (b + h / 2) * s - UIParent:GetHeight() / 2
    Model.Commit("options.openAnchor", { point = "CENTER", relPoint = "CENTER", x = math.floor(cx / s + 0.5), y = math.floor(cy / s + 0.5) })
  end
  self.savingWindow = nil
end

function Options:OnPinned()
  if self.frame and self.frame:IsShown() then self:RenderSidebar() end
end

-- Sidebar ------------------------------------------------------------------------
local ITEM_H = 34

local function sideItem(side, i)
  local b = side.items[i]
  if b then return b end
  b = CreateFrame("Button", nil, side)
  b:SetSize(SIDEBAR - 24, ITEM_H)
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  Theme:Paint(b.sel, "accent", 0.12)
  b.bar = Kit.AccentBar(b, 3, 20)
  b.bar:SetPoint("LEFT", -12, 0)
  b.icon = Kit.Icon(b, A.Icon("general"), 20)
  b.icon:SetPoint("LEFT", 8, 0)
  b.text = Kit.Text(b, "label", "text.secondary")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
  b.dot = b:CreateTexture(nil, "ARTWORK")
  b.dot:SetSize(6, 6)
  b.dot:SetPoint("RIGHT", -8, 0)
  Theme:Paint(b.dot, "ok")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.04)
  side.items[i] = b
  return b
end

local function caption(side, i)
  local c = side.captions[i]
  if c then return c end
  c = CreateFrame("Button", nil, side)
  c:SetSize(SIDEBAR - 24, 24)
  c.text = Kit.Text(c, "caption", "muted")
  c.text:SetPoint("LEFT", 10, 0)
  c.count = Kit.Text(c, "caption", "muted")
  c.count:SetPoint("RIGHT", -10, 0)
  side.captions[i] = c
  return c
end

function Options:RenderSidebar()
  local f, side = self.frame, self.frame.side
  local y, n = -14, 0
  local function item(name, icon, label, on)
    n = n + 1
    local b = sideItem(side, n)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 12, y)
    y = y - ITEM_H - 2
    b.icon:SetTexture(A.Icon(icon, on == false))
    b.text:SetText(label)
    local active = self.page == name and f.search:GetText() == ""
    b.sel:SetShown(active)
    b.bar:SetShown(active)
    Theme:Paint(b.text, active and "text.primary" or "text.secondary", 1, "text")
    b.dot:SetShown(on == true)
    b:SetScript("OnClick", function() Options:Open(name) end)
    b:Show()
  end
  item("Dashboard", "dashboard", "Dashboard", nil)
  y = y - 8
  local pinned = Schema:Get("options.pinned")
  if #pinned > 0 then
    local c = caption(side, 99)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 12, y)
    c.text:SetText("PINNED")
    c.count:SetText("")
    c:SetScript("OnClick", function() Options:Open("Options") end)
    c:Show()
    y = y - 26
    for _, name in ipairs(pinned) do
      if Model.Page("advanced", name) and Model.Page("advanced", name).name == name then
        local icon, label = Nav.Info(name)
        item(name, icon, label, Nav.ModuleOn(name))
      end
    end
    y = y - 8
  elseif side.captions[99] then
    side.captions[99]:Hide()
  end
  local groups = Nav.Layout(Model.Mode())
  for gi, g in ipairs(groups) do
    local c = caption(side, gi)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", 12, y)
    c.text:SetText(g.label:upper())
    c.count:SetText(#g.pages .. (side.collapsed[g.label] and "  >" or "  v"))
    c:SetScript("OnClick", function()
      side.collapsed[g.label] = not side.collapsed[g.label]
      Options:RenderSidebar()
    end)
    c:SetShown(#g.pages > 0)
    if #g.pages > 0 then y = y - 26 end
    if not side.collapsed[g.label] then
      for _, p in ipairs(g.pages) do
        local icon, label = Nav.Info(p.name)
        item(p.name, icon, label, Nav.ModuleOn(p.name))
      end
    end
    if #g.pages > 0 then y = y - 6 end
  end
  for i = n + 1, #side.items do side.items[i]:Hide() end
end

-- Content ------------------------------------------------------------------------
-- Which keys a page/search shows (used by module pages and the tests).
function Options:CurrentKeys()
  local f = self.frame
  local query = f and f.search:GetText() or ""
  if query ~= "" then return Model.Search(query), "Search: " .. query end
  local page = Model.Page(Model.Mode(), self.page)
  if not page then return {}, "" end
  return page.keys, page.label
end

function Options:HideViews()
  for _, view in pairs(self.views or {}) do view:Hide() end
  for _, row in pairs(self.rows) do row:Hide() end
  self.frame.scroll:Hide()
end

function Options:Render()
  local f = self.frame
  if not f then return end
  f.mode:SetValue_(Model.Mode())
  self:RefreshChip()
  self:HideViews()
  local query = f.search:GetText()
  if query == "" and self.page == "Dashboard" then
    self.Dashboard:Show(f.host)
  elseif query == "" and self.rawPage ~= self.page and self.CUSTOM[self.page] and self.CUSTOM[self.page]() then
    self.CUSTOM[self.page]():Show(f.host)
  else
    if query == "" and not Model.Page(Model.Mode(), self.page) then self.page = "Dashboard"; return self:Render() end
    self.PageView:Show(f.host, query)
  end
  self:RenderSidebar()
end

function Options:RefreshChip()
  local f = self.frame
  local name = UnitName("player") or "?"
  local specName = ""
  local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
  if spec and C_SpecializationInfo.GetSpecializationInfo then
    local _, sn = C_SpecializationInfo.GetSpecializationInfo(spec)
    specName = sn and (" - " .. sn) or ""
  end
  f.chip:SetLabel(name .. specName)
  local _, class = UnitClass("player")
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  f.chip.avatar:SetColorTexture(c and c.r or 0.24, c and c.g or 0.86, c and c.b or 0.59, 1)
end

-- target: a page name (e.g. "Theme"), "Dashboard", or a search string.
function Options:Open(target)
  local f = self.frame or self:Build()
  f.search:SetText("")
  self.rawPage = nil
  if target and target ~= "Dashboard" then
    local page = Model.Page("advanced", target)
    if page and page.name:lower() == target:lower() then self.page = page.name else f.search:SetText(target) end
  elseif target == "Dashboard" then
    self.page = "Dashboard"
  end
  f:Show()
  self:Render()
end

function Options:Toggle(target)
  local f = self.frame
  if f and f:IsShown() and not target then f:Hide(); return end
  self:Open(target)
end

function Options:OnModeChanged()
  if self.frame and self.frame:IsShown() then self:Render() end
end

PUI.Kernel:On("SETTING_CHANGED", function(key)
  local row = Options.rows[key]
  if row and row:IsShown() then
    local h = row:GetHeight()
    row:Refresh()
    if row:GetHeight() ~= h and Options.views.page and Options.views.page:IsShown() then Options:Render() end
  end
  local f = Options.frame
  if f and f:IsShown() then
    if key:find("^module%.") then Options:RenderSidebar() end
    for _, view in pairs(Options.views or {}) do
      if view:IsShown() and view.OnSetting then view:OnSetting(key) end
    end
  end
end)
