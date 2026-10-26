local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Module page (mockups 02/03): breadcrumb, icon + title + description,
-- Move in Studio / Reset / module toggle, tabs derived from the key names
-- (uf.player.*, ab.bar1.* ...), settings rows on the left and a live
-- preview card on the right when the page has one. Search results reuse it.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, Nav, Widgets = Options.Model, PUI.Schema, Options.Kit, Options.Nav, Options.Widgets
local PageView = {}
Options.PageView = PageView
Options.views = Options.views or {}

local PREVIEW_W = 420
local TAB_LABEL = { player = "Player", target = "Target", targettarget = "Target of Target", focus = "Focus",
  focustarget = "Focus Target", pet = "Pet", boss = "Boss", arena = "Arena", party = "Party", raid = "Raid",
  general = "General", stance = "Stance", petbar = "Pet", vehicle = "Extra & vehicle" }

local function tabLabel(id)
  if TAB_LABEL[id] then return TAB_LABEL[id] end
  local word, num = id:match("^(%a+)(%d+)$")
  if word then return (word:gsub("^%l", string.upper)) .. " " .. num end
  return (id:gsub("^%l", string.upper))
end

-- Tabs: second key segment shared by >= 2 keys of a three-part key; the rest is General.
function PageView.Tabs(keys)
  local count, order = {}, {}
  for _, k in ipairs(keys) do
    local a, b, c = k:match("^([^.]+)%.([^.]+)%.(.+)$")
    if c then
      if not count[b] then order[#order + 1] = b end
      count[b] = (count[b] or 0) + 1
    end
  end
  local tabs, byTab = { { id = "general", keys = {} } }, { general = 1 }
  for _, id in ipairs(order) do
    if count[id] >= 2 then tabs[#tabs + 1] = { id = id, keys = {} }; byTab[id] = #tabs end
  end
  for _, k in ipairs(keys) do
    local _, b, c = k:match("^([^.]+)%.([^.]+)%.(.+)$")
    local idx = (c and byTab[b]) or 1
    table.insert(tabs[idx].keys, k)
  end
  if #tabs[1].keys == 0 then table.remove(tabs, 1) end
  for _, t in ipairs(tabs) do t.label = tabLabel(t.id) end
  return tabs
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.crumb = Kit.Text(v, "small", "muted")
  v.crumb:SetPoint("TOPLEFT", 30, -22)
  v.icon = Kit.Icon(v, Options.Assets.Icon("general"), 44)
  v.icon:SetPoint("TOPLEFT", 30, -44)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.toggle = Kit.Toggle(v, function(on) if v.moduleKey then Model.Commit(v.moduleKey, on) end end)
  v.toggle:SetPoint("TOPRIGHT", -30, -56)
  v.reset = Kit.Button(v, "Reset", 70, function()
    local n = Model.ResetPage(Model.Mode(), Options.page)
    PUI.Slash.Print(n .. " setting(s) reset to default.")
  end, "ghost")
  v.reset:SetPoint("RIGHT", v.toggle, "LEFT", -10, 0)
  v.studio = Kit.Button(v, "Move in Studio", 150, function() PUI.OptionsHost:OpenStudio() end, "secondary",
    Options.Assets.Icon("studio"))
  v.studio:SetPoint("RIGHT", v.reset, "LEFT", -8, 0)
  v.tabs = {}
  v.tabLine = Kit.Divider(v)
  v.tabLine:SetPoint("TOPLEFT", 30, -146)
  v.tabLine:SetPoint("TOPRIGHT", -30, -146)
  v.previewCard = Kit.Card(v)
  v.previewCard:SetPoint("TOPRIGHT", -30, -162)
  v.previewCard:SetSize(PREVIEW_W, 380)
  v.previewTitle = Kit.Section(v.previewCard, "Live preview")
  v.previewTitle:SetPoint("TOPLEFT", 18, -16)
  v.live = Kit.Badge(v.previewCard, "Live", "ok")
  v.live:SetPoint("TOPRIGHT", -14, -10)
  v.previewNote = Kit.Text(v.previewCard, "small", "muted")
  v.previewNote:SetPoint("BOTTOM", 0, 16)
  v.previewNote:SetText("Previews use test data. Every change applies instantly, no /reload.")
  Options.views.page = v
  return v
end

local function tabButton(v, i)
  local b = v.tabs[i]
  if b then return b end
  b = CreateFrame("Button", nil, v)
  b:SetHeight(30)
  b.text = Kit.Text(b, "label", "muted")
  b.text:SetPoint("CENTER", 0, 2)
  b.bar = Kit.AccentBar(b, 10, 2)
  b.bar:SetPoint("BOTTOMLEFT", 0, 0)
  b.bar:SetPoint("BOTTOMRIGHT", 0, 0)
  v.tabs[i] = b
  return b
end

function PageView:Show(host, query)
  local v = Options.views.page or build(host)
  local f = Options.frame
  v:Show()
  local keys, owner
  if query and query ~= "" then
    keys = Model.Search(query)
    owner = nil
    v.crumb:SetText("Search")
    v.icon:SetTexture(Options.Assets.Icon("oracle"))
    v.title:SetText("Results for \"" .. query .. "\"")
    v.desc:SetText(#keys .. " setting(s), both modes")
  else
    owner = Options.page
    keys = Model.Page(Model.Mode(), owner).keys
    local icon, label, desc = Nav.Info(owner)
    v.crumb:SetText(Nav.GroupOf(owner) .. "   >   " .. label)
    v.icon:SetTexture(Options.Assets.Icon(icon))
    v.title:SetText(label)
    v.desc:SetText(desc)
  end
  local on, mkey = nil, nil
  if owner then on, mkey = Nav.ModuleOn(owner) end
  v.moduleKey = mkey
  v.toggle:SetShown(on ~= nil)
  if on ~= nil then v.toggle:SetValue_(on) end
  v.reset:SetShown(owner ~= nil)
  v.studio:SetShown(owner ~= nil and on ~= nil)

  -- tabs
  local tabs = owner and PageView.Tabs(keys) or { { id = "results", label = "Results", keys = keys } }
  if v.owner ~= owner then v.tab = nil end
  v.owner = owner
  local current = tabs[1]
  for _, t in ipairs(tabs) do if t.id == v.tab then current = t end end
  v.tab = current.id
  local x = 30
  for i = 1, math.max(#tabs, #v.tabs) do
    local b = tabButton(v, i)
    local t = tabs[i]
    if t and #tabs > 1 then
      b.text:SetText(t.label)
      b:SetWidth((b.text:GetStringWidth() or 0) + 24)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x, -116)
      x = x + b:GetWidth() + 4
      local active = t.id == current.id
      b.bar:SetShown(active)
      Theme:Paint(b.text, active and "text.primary" or "muted", 1, "text")
      b:SetScript("OnClick", function() v.tab = t.id; PageView:Show(host, query) end)
      b:Show()
    else
      b:Hide()
    end
  end

  -- preview card
  local builder = owner and Options.Previews and Options.Previews[owner]
  v.previewCard:SetShown(builder ~= nil)
  if builder then builder(v.previewCard, current.id) end
  v.previewFor = builder and owner or nil

  -- rows in the scroll column
  local scroll, child = f.scroll, f.child
  scroll:SetParent(v)
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", 30, -156)
  scroll:SetPoint("BOTTOMRIGHT", builder and -(PREVIEW_W + 52) or -30, 20)
  scroll:Show()
  local width = scroll:GetRight() and (scroll:GetRight() - scroll:GetLeft()) or (Options.SIZE.W - Options.SIZE.SIDEBAR - 60 - (builder and PREVIEW_W + 22 or 0))
  child:SetWidth(width)
  local keep = v.lastView == (tostring(owner) .. "|" .. tostring(query) .. "|" .. current.id)
  v.lastView = tostring(owner) .. "|" .. tostring(query) .. "|" .. current.id
  local oldScroll = keep and scroll:GetVerticalScroll() or 0
  local show = current.keys
  f.empty:SetText(#show == 0 and "Nothing matches." or "")
  local y = 0
  for i = 1, #show do
    local key = show[i]
    local row = Options.rows[key] or Widgets.Row(child, key)
    Options.rows[key] = row
    row:SetParent(child)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
    row:Refresh()
    row:Show()
    y = y + math.max(Widgets.ROW_H, row:GetHeight())
  end
  child:SetHeight(y + 20)
  scroll:SetVerticalScroll(oldScroll)
  function v:OnSetting(key)
    if key == self.moduleKey then self.toggle:SetValue_(Schema:Get(key)) end
    if self.previewFor and Options.Previews.Update then Options.Previews.Update(self.previewFor, self.previewCard, key) end
  end
end
