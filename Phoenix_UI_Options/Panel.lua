local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Options window (PUI_V2 18.2): sidebar of pages, search, Simple/Advanced
-- switch, Studio button, rows rendered from the schema, footer with version,
-- reset-page and the Sentinel status dot. Every change applies live; the
-- window re-renders on SETTING_CHANGED and on the mode switch.
local Options, Theme, Widgets = PUI.Options, PUI.Theme, PUI.Options.Widgets
local Model, Schema = Options.Model, PUI.Schema

local W, H, SIDEBAR, TOP = 980, 640, 190, 52

local function buildSidebar(f)
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 0, -TOP)
  side:SetPoint("BOTTOMLEFT", 0, 34)
  side:SetWidth(SIDEBAR)
  Theme:Backdrop(side, "surface.1")
  side.buttons = {}
  f.side = side
end

local function buildTop(f)
  local title = Widgets.Font(f:CreateFontString(nil, "OVERLAY"), "header")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("PHOENIX UI")
  Theme:Paint(title, "accent", 1, "text")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  local search = CreateFrame("EditBox", "PhoenixUIOptionsSearch", f, "InputBoxTemplate")
  search:SetSize(260, 22)
  search:SetPoint("TOP", 0, -14)
  search:SetAutoFocus(false)
  search:SetScript("OnTextChanged", function(self, user) if user then Options:Render() end end)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); Options:Render() end)
  f.search = search

  f.mode = Widgets.Button(f, "", 110, function()
    Model.Commit("options.mode", Model.Mode() == "simple" and "advanced" or "simple")
  end)
  f.mode:SetPoint("TOPRIGHT", -150, -14)
  f.studio = Widgets.Button(f, "Studio", 80, function() PUI.OptionsHost:OpenStudio() end)
  f.studio:SetPoint("LEFT", f.mode, "RIGHT", 6, 0)
  local close = Widgets.Button(f, "Close", 50, function() f:Hide() end)
  close:SetPoint("TOPRIGHT", -12, -14)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 0, -TOP)
  line:SetPoint("TOPRIGHT", 0, -TOP)
  Theme:Paint(line, "line")
end

local function buildContent(f)
  local scroll = CreateFrame("ScrollFrame", "PhoenixUIOptionsScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", SIDEBAR + 12, -TOP - 10)
  scroll:SetPoint("BOTTOMRIGHT", -30, 44)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(W - SIDEBAR - 50, 10)
  scroll:SetScrollChild(child)
  f.scroll, f.child = scroll, child
  f.heading = Widgets.Font(child:CreateFontString(nil, "OVERLAY"), "header")
  f.heading:SetPoint("TOPLEFT", 6, -4)
  f.empty = Widgets.Font(child:CreateFontString(nil, "OVERLAY"), "body")
  f.empty:SetPoint("TOPLEFT", 6, -36)
  Theme:Paint(f.empty, "text.secondary", 1, "text")
end

local function buildFooter(f)
  local foot = CreateFrame("Frame", nil, f)
  foot:SetPoint("BOTTOMLEFT")
  foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(34)
  Theme:Backdrop(foot, "surface.1")
  f.dot = foot:CreateTexture(nil, "ARTWORK")
  f.dot:SetSize(8, 8)
  f.dot:SetPoint("LEFT", 14, 0)
  f.version = Widgets.Font(foot:CreateFontString(nil, "OVERLAY"), "small")
  f.version:SetPoint("LEFT", f.dot, "RIGHT", 8, 0)
  Theme:Paint(f.version, "text.secondary", 1, "text")
  f.reset = Widgets.Button(foot, "Reset page", 100, function()
    local n = Model.ResetPage(Model.Mode(), Options.page)
    PUI.Slash.Print(n .. " setting(s) reset to default.")
  end)
  f.reset:SetPoint("RIGHT", -12, 0)
end

function Options:Build()
  local f = PUI:CreateFrame("Frame", "PhoenixUIOptions", UIParent, nil, "Options")
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetToplevel(true)
  Theme:Backdrop(f, "surface.0")
  Theme:Outline(f, "line")
  tinsert(UISpecialFrames, "PhoenixUIOptions")
  buildTop(f)
  buildSidebar(f)
  buildContent(f)
  buildFooter(f)
  f:SetScript("OnHide", function() if Widgets.popup then Widgets.popup:Hide() end end)
  f:Hide()
  self.frame = f
  return f
end

local function sideButton(f, i)
  local b = f.side.buttons[i]
  if b then return b end
  b = Widgets.Button(f.side, "", SIDEBAR - 16, nil)
  b:SetPoint("TOPLEFT", 8, -10 - (i - 1) * 26)
  f.side.buttons[i] = b
  return b
end

-- Which keys the content area shows right now.
function Options:CurrentKeys()
  local f = self.frame
  local query = f and f.search:GetText() or ""
  if query ~= "" then return Model.Search(query), "Search: " .. query end
  local page = Model.Page(Model.Mode(), self.page)
  if not page then return {}, "" end
  self.page = page.name
  return page.keys, page.label
end

function Options:Render()
  local f = self.frame
  if not f then return end
  local mode = Model.Mode()
  f.mode:SetLabel(mode == "simple" and "Simple" or "Advanced")
  local pages = Model.Pages(mode)
  for i = 1, math.max(#pages, #f.side.buttons) do
    local b = sideButton(f, i)
    local page = pages[i]
    if page then
      b:SetLabel(page.label .. "  (" .. #page.keys .. ")")
      b:SetScript("OnClick", function() Options.page = page.name; f.search:SetText(""); Options:Render() end)
      b:Show()
    else
      b:Hide()
    end
  end
  for _, row in pairs(self.rows) do row:Hide() end
  local keys, heading = self:CurrentKeys()
  f.heading:SetText(heading)
  f.empty:SetText(#keys == 0 and "Nothing matches." or "")
  for i = 1, #keys do
    local key = keys[i]
    local row = self.rows[key] or Widgets.Row(f.child, key)
    self.rows[key] = row
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -30 - (i - 1) * Widgets.ROW_H)
    row:SetPoint("RIGHT", f.child, "RIGHT", 0, 0)
    row:Refresh()
    row:Show()
  end
  f.child:SetHeight(40 + #keys * Widgets.ROW_H)
  self:RefreshFooter()
end

function Options:RefreshFooter()
  local f = self.frame
  local S = PUI.Sentinel
  local errors = 0
  if S and S.db and S.db.sessionErrors then
    for _ in pairs(S.db.sessionErrors[S.db.session] or {}) do errors = errors + 1 end
  end
  Theme:Paint(f.dot, errors == 0 and "success" or "danger")
  f.version:SetText("v" .. (C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "?")
    .. "  |  Sentinel: " .. (errors == 0 and "no incidents this session" or errors .. " incident(s) this session"))
end

-- target: a page name (e.g. "Theme") or a search string.
function Options:Toggle(target)
  local f = self.frame or self:Build()
  if f:IsShown() and not target then f:Hide(); return end
  f.search:SetText("")
  if target then
    local page = Model.Page("advanced", target)
    if page and page.name:lower() == target:lower() then self.page = page.name else f.search:SetText(target) end
  end
  f:Show()
  self:Render()
end

function Options:OnModeChanged()
  if self.frame and self.frame:IsShown() then self:Render() end
end

PUI.Kernel:On("SETTING_CHANGED", function(key)
  local row = Options.rows[key]
  if row and row:IsShown() then row:Refresh() end
end)
