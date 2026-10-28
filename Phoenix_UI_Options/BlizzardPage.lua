local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Blizzard elements page (deferred batch B, Studio): every Blizzard HUD
-- element Studio knows, grouped by category, with what Phoenix does to it now
-- (default / moved / hidden / faded / Edit Mode's), and per row: Hide or
-- Show, Reset, and Open in Studio. Changes apply live through the same
-- studio.blizzard.positions setting Studio writes.
local Options, Theme = PUI.Options, PUI.Theme
local Kit, A = Options.Kit, Options.Assets
local Schema, Movers = PUI.Schema, PUI.Movers
local Page = {}
Options.BlizzardPage = Page
Options.views = Options.views or {}
Options.CUSTOM.Blizzard = function() return Options.BlizzardPage end
local Model = Options.Model
Model.VIRTUAL[#Model.VIRTUAL + 1] = "Blizzard"
Model.PAGE_LABEL.Blizzard = "Blizzard elements"
local NavInfo = Options.Nav.INFO
NavInfo.Blizzard = { "studio", "Blizzard elements", "Every Blizzard HUD element: hide, show, reset or open it in Studio." }
for _, g in ipairs(Options.Nav.GROUPS) do
  if g[1] == "Interface" then
    local list = g[2]
    for i, v in ipairs(list) do if v == "Studio" then table.insert(list, i + 1, "Blizzard"); break end end
  end
end

local ROW, PAD = 40, 30
local CAT_ORDER = { "frames", "bars", "auras", "hud", "alerts", "group", "minimap", "misc" }

-- Plain rows (unit-tested): { id, cat, label, state, editMode }.
function Page.Entries(filter)
  local saved = Schema:Get("studio.blizzard.positions")
  local out = {}
  for _, c in ipairs(Movers.CATALOG) do
    local id = "bz." .. c[1]
    local e = Movers.byId[id]
    local r = saved[id]
    local state = e.editMode and "Edit Mode" or not r and "Default" or r.hide and "Hidden" or r.fade and "Faded" or "Moved"
    if not filter or filter == "" or e.label:lower():find(filter:lower(), 1, true) then
      out[#out + 1] = { id = id, cat = e.cat, label = e.label, state = state, editMode = e.editMode }
    end
  end
  local rank = {}
  for i, c in ipairs(CAT_ORDER) do rank[c] = i end
  table.sort(out, function(a, b)
    if a.cat ~= b.cat then return (rank[a.cat] or 99) < (rank[b.cat] or 99) end
    return a.label < b.label
  end)
  return out
end

-- Hide or show one element (keeps its position record).
function Page.SetHidden(id, hide)
  local saved = Schema:Get("studio.blizzard.positions")
  local r = saved[id] or Movers:Current(id) or { point = "CENTER", x = 0, y = 0 }
  local copy = {}
  for k, v in pairs(r) do copy[k] = v end
  copy.hide = hide or nil
  saved[id] = copy
  Schema:Set("studio.blizzard.positions", saved)
end
function Page.Reset(id)
  local saved = Schema:Get("studio.blizzard.positions")
  saved[id] = nil
  Schema:Set("studio.blizzard.positions", saved)
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.icon = Kit.Icon(v, A.Icon("studio"), 44)
  v.icon:SetPoint("TOPLEFT", PAD, -40)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.title:SetText("Blizzard elements")
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.desc:SetText("Hide, show or reset Blizzard's own HUD pieces. Move, scale and fade them in Studio. Edit Mode's frames stay with Edit Mode.")
  v.enable = Kit.Toggle(v, function(on) Schema:Set("studio.blizzard.enabled", on); Page:Show(host) end)
  v.enable:SetPoint("TOPLEFT", PAD, -110)
  v.enableText = Kit.Text(v, "body", "text.primary")
  v.enableText:SetPoint("LEFT", v.enable, "RIGHT", 10, 0)
  v.enableText:SetText("Let Phoenix change Blizzard elements (off gives every one back)")
  v.card = Kit.Card(v)
  v.card:SetPoint("TOPLEFT", PAD, -150)
  v.card:SetPoint("BOTTOMRIGHT", -PAD, 24)
  local scroll = CreateFrame("ScrollFrame", nil, v.card)
  scroll:SetPoint("TOPLEFT", 16, -12)
  scroll:SetPoint("BOTTOMRIGHT", -16, 12)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(10, 10)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ROW * 2)))
  end)
  v.scroll, v.child, v.rows, v.heads = scroll, child, {}, {}
  Options.views.blizzard = v
  return v
end

local function row(v, i)
  local r = v.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, v.child)
  r:SetHeight(ROW)
  r.title = Kit.Text(r, "body", "text.primary")
  r.title:SetPoint("LEFT", 4, 0)
  r.badge = Kit.Badge(r, "", "neutral")
  r.badge:SetPoint("RIGHT", -330, 0)
  r.hide = Kit.Button(r, "Hide", 92, nil, "secondary")
  r.hide:SetPoint("RIGHT", -216, 0)
  r.reset = Kit.Button(r, "Reset", 92, nil, "ghost")
  r.reset:SetPoint("RIGHT", -116, 0)
  r.studio = Kit.Button(r, "In Studio", 104, nil, "ghost")
  r.studio:SetPoint("RIGHT", -4, 0)
  local line = Kit.Divider(r)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
  v.rows[i] = r
  return r
end

function Page:Show(host)
  local v = Options.views.blizzard or build(host)
  v:Show()
  local on = Schema:Get("studio.blizzard.enabled")
  v.enable:SetValue_(on)
  local list = Page.Entries()
  v.child:SetWidth((v.scroll:GetRight() and v.scroll:GetLeft()) and (v.scroll:GetRight() - v.scroll:GetLeft()) or 900)
  local y, cat, hi = 0, nil, 0
  for i, e in ipairs(list) do
    if e.cat ~= cat then
      cat = e.cat
      hi = hi + 1
      local h = v.heads[hi] or Kit.Section(v.child, "")
      v.heads[hi] = h
      h:SetText((Movers.CATEGORY_LABELS[cat] or cat):upper())
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y - 6); h:Show()
      y = y + 28
    end
    local r = row(v, i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", v.child, "RIGHT", 0, 0)
    r.title:SetText(PUI.L[e.label])
    r.badge:SetText(e.state)
    local editable = on and not e.editMode
    r.hide:SetLabel(e.state == "Hidden" and "Show" or "Hide")
    r.hide:SetShown(editable)
    r.reset:SetShown(editable and e.state ~= "Default")
    r.hide:SetScript("OnClick", function() Page.SetHidden(e.id, e.state ~= "Hidden"); Page:Show(host) end)
    r.reset:SetScript("OnClick", function() Page.Reset(e.id); Page:Show(host) end)
    r.studio:SetScript("OnClick", function()
      if PUI.Studio:Open() then PUI.Studio:Select(e.id) end
    end)
    r:SetAlpha(on and 1 or 0.55)
    r:Show()
    y = y + ROW
  end
  for i = #list + 1, #v.rows do v.rows[i]:Hide() end
  for i = hi + 1, #v.heads do v.heads[i]:Hide() end
  v.child:SetHeight(math.max(10, y))
  v.count = #list
end
