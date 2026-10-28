local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Overrides in the options window (plan 1.8, 1.9, F2): the "Editing as"
-- banner on every module page that has overridable settings, a gold marker
-- and "Overridden for ..." line on each row whose value comes from a spec or
-- content override, and the Overrides page listing every override with
-- "Make it the profile value" and "Remove". Nothing here stores data: it all
-- goes through PUI.Overrides (read-time layering, G9; validate then publish, G26).
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Widgets, PageView = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Widgets, Options.PageView
local Ov = PUI.Overrides
local OUI = {}
Options.OverridesUI = OUI
Options.views = Options.views or {}

local GOLD = { 0.96, 0.77, 0.42 }
local BANNER_H = 40

local function specIndex()
  return C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization() or 0
end
local function specName(i)
  if not (i and i > 0) then return "this specialization" end
  local _, name = C_SpecializationInfo.GetSpecializationInfo(i)
  return name or ("Specialization " .. i)
end
OUI.SpecName = specName

-- "spec:2" / "cond:arena" -> "Arcane" / "Arena".
function OUI.SourceLabel(src)
  if type(src) ~= "string" then return nil end
  local layer, id = src:match("^(%a+):(.+)$")
  if layer == "spec" then return specName(tonumber(id)) end
  if layer == "cond" then return Ov.CONDITION_LABELS[id] or id end
  return nil
end

-- Banner choices: profile, the current spec, then every content condition.
function OUI.Choices()
  local ids, labels = { "profile", "spec" }, { "Profile", specName(specIndex()) }
  for _, c in ipairs(Ov.CONDITIONS) do ids[#ids + 1] = "cond:" .. c; labels[#labels + 1] = Ov.CONDITION_LABELS[c] end
  return ids, labels
end

function OUI.Current()
  local layer, id = Ov:Editing()
  if not layer then return "profile" end
  if layer == "spec" then return "spec" end
  return "cond:" .. id
end

function OUI.Pick(choice)
  if choice == "profile" then Ov:EditAs(nil)
  elseif choice == "spec" then
    local i = specIndex()
    if i > 0 then Ov:EditAs("spec", i) end
  else Ov:EditAs("cond", choice:match("^cond:(.+)$")) end
end

local function countOverrides(keys)
  local set, n = {}, 0
  for _, k in ipairs(keys or {}) do set[k] = true end
  for _, e in ipairs(Ov:List()) do if set[e.key] then n = n + 1 end end
  return n
end
OUI.Count = countOverrides

local function anyOverridable(keys)
  for _, k in ipairs(keys or {}) do local d = Schema:Def(k); if d and d.overridable then return true end end
  return false
end
OUI.AnyOverridable = anyOverridable

-- Banner ------------------------------------------------------------------------
local function banner(v)
  local existing = rawget(v, "ovBanner")
  if existing then return existing end
  local b = CreateFrame("Frame", nil, v)
  b:SetHeight(BANNER_H)
  b:SetPoint("TOPLEFT", 30, -150)
  b:SetPoint("TOPRIGHT", -30, -150)
  b.bg = Theme:Slice(b, A.control, 20)
  b.edge = b:CreateTexture(nil, "ARTWORK")
  b.edge:SetPoint("TOPLEFT"); b.edge:SetPoint("BOTTOMLEFT"); b.edge:SetWidth(3)
  b.label = Kit.Text(b, "label", "text.primary")
  b.label:SetPoint("LEFT", 14, 0)
  b.label:SetText("Editing as")
  local ids, labels = OUI.Choices()
  b.seg = Kit.Segmented(b, ids, labels, function(choice) OUI.Pick(choice) end)
  b.seg:SetPoint("LEFT", b.label, "RIGHT", 12, 0)
  b.count = Kit.Text(b, "small", "muted")
  b.count:SetPoint("RIGHT", -124, 0)
  b.all = Kit.Button(b, "All overrides", 108, function() Options:Open("Overrides") end, "ghost")
  b.all:SetPoint("RIGHT", -8, 0)
  b.all:SetHeight(26)
  v.ovBanner = b
  return b
end

function OUI.PaintBanner(v, keys)
  local b = banner(v)
  local _, labels = OUI.Choices()
  b.seg:SetLabels(labels)
  local cur = OUI.Current()
  b.seg:SetValue_(cur)
  local editing = cur ~= "profile"
  if editing then
    b.bg:SetVertexColor(GOLD[1] * 0.25, GOLD[2] * 0.25, GOLD[3] * 0.25, 1)
    b.edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  else
    b.bg:SetVertexColor(0.06, 0.07, 0.09, 1)
    b.edge:SetColorTexture(0, 0, 0, 0)
  end
  local n = countOverrides(keys)
  b.count:SetText(editing and "Changes here apply only there. Marked rows can be overridden."
    or (n == 0 and "No overrides on this page" or (n .. " override(s) on this page")))
  b:Show()
end

local baseShow = PageView.Show
function PageView:Show(host, query)
  baseShow(self, host, query)
  local v = Options.views.page
  local owner = (query == nil or query == "") and Options.page or nil
  local keys = owner and Model.Page(Model.Mode(), owner).keys or {}
  local want = owner ~= nil and (anyOverridable(keys) or OUI.Current() ~= "profile")
  if want then
    OUI.PaintBanner(v, keys)
    local f = Options.frame
    local right = v.previewCard:IsShown() and -(420 + 52) or -30
    f.scroll:ClearAllPoints()
    f.scroll:SetPoint("TOPLEFT", 30, -156 - BANNER_H - 8)
    f.scroll:SetPoint("BOTTOMRIGHT", right, 20)
    v.previewCard:ClearAllPoints()
    v.previewCard:SetPoint("TOPRIGHT", -30, -162 - BANNER_H - 8)
  else
    if rawget(v, "ovBanner") then v.ovBanner:Hide() end
    v.previewCard:ClearAllPoints()
    v.previewCard:SetPoint("TOPRIGHT", -30, -162)
  end
  v.ovKeys = keys
end

PUI.Kernel:On("OVERRIDES_EDITING", function()
  local v = Options.views.page
  if v and v:IsShown() then Options:Render() end
end)

-- Row markers ---------------------------------------------------------------------
local baseRow = Widgets.Row
function Widgets.Row(parent, key)
  local row = baseRow(parent, key)
  local def = Schema:Def(key)
  if not (def and def.overridable) then return row end
  row.ov = row:CreateTexture(nil, "OVERLAY")
  row.ov:SetSize(7, 7)
  row.ov:SetPoint("RIGHT", row.label, "LEFT", -4, 0)
  local baseRefresh = row.Refresh
  function row:Refresh()
    baseRefresh(self)
    local src = Schema:Source(self.key)
    local who = OUI.SourceLabel(src)
    if who then
      self.ov:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
      self.sub:SetText("Overridden for " .. who .. ". Right-click to remove the override.")
      Theme:Paint(self.sub, "gold", 1, "text")
    else
      self.ov:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], OUI.Current() ~= "profile" and 0.55 or 0.18)
      self.sub:SetText(PUI.L[def.tooltip])
      Theme:Paint(self.sub, "muted", 1, "text")
    end
    self.overriddenBy = who
  end
  row:SetScript("OnMouseUp", function(self, button)
    if button ~= "RightButton" then return end
    local src = Schema:Source(self.key)
    local layer, id = (src or ""):match("^(%a+):(.+)$")
    if layer == "spec" or layer == "cond" then
      Ov:Clear(layer, layer == "spec" and tonumber(id) or id, self.key)
      PUI.Kernel:Fire("SETTING_CHANGED", self.key, Schema:Get(self.key))
    else
      Schema:Reset(self.key)
    end
  end)
  row:Refresh()
  return row
end

-- Overrides page ---------------------------------------------------------------------
local Page = {}
Options.OverridesPage = Page
local ROW = 44

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.icon = Kit.Icon(v, A.Icon("loadouts"), 44)
  v.icon:SetPoint("TOPLEFT", 30, -40)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.title:SetText("Overrides")
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.desc:SetText("Values set only for one specialization or one kind of content, on top of your profile. Use \"Editing as\" on any page to add one.")
  v.card = Kit.Card(v)
  v.card:SetPoint("TOPLEFT", 30, -120)
  v.card:SetPoint("BOTTOMRIGHT", -30, 24)
  v.head = Kit.Section(v.card, "Active profile")
  v.head:SetPoint("TOPLEFT", 18, -16)
  v.empty = Kit.Text(v.card, "text", "muted")
  v.empty:SetPoint("CENTER")
  v.rows = {}
  Options.views.overrides = v
  return v
end

local function rowFrame(v, i)
  local r = v.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, v.card)
  r:SetHeight(ROW)
  r.badge = Kit.Badge(r, "", "accent")
  r.badge:SetPoint("LEFT", 4, 0)
  r.label = Kit.Text(r, "body", "text.primary")
  r.label:SetPoint("LEFT", 150, 7)
  r.value = Kit.Text(r, "small", "muted")
  r.value:SetPoint("LEFT", 150, -9)
  r.remove = Kit.Button(r, "Remove", 90, nil, "ghost")
  r.remove:SetPoint("RIGHT", -4, 0)
  r.promote = Kit.Button(r, "Make it the profile value", 200, nil, "secondary")
  r.promote:SetPoint("RIGHT", r.remove, "LEFT", -8, 0)
  local line = Kit.Divider(r)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
  v.rows[i] = r
  return r
end

function Page:Show(host)
  local v = Options.views.overrides or build(host)
  v:Show()
  local list = Ov:List()
  v.empty:SetText(#list == 0 and "No overrides yet. Open a module page and pick a specialization or content under \"Editing as\"." or "")
  for i, e in ipairs(list) do
    local r = rowFrame(v, i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 18, -44 - (i - 1) * ROW)
    r:SetPoint("RIGHT", v.card, "RIGHT", -18, 0)
    local who = e.layer == "spec" and specName(e.id) or (Ov.CONDITION_LABELS[e.id] or tostring(e.id))
    r.badge:SetText(who)
    local def = Schema:Def(e.key)
    r.label:SetText(def and PUI.L[def.label] or e.key)
    r.value:SetText((def and Model.Format(def, e.value) or tostring(e.value)) .. "   (profile: " .. (def and Model.Format(def, PUI.DB:GetRaw(e.key) == nil and def.default or PUI.DB:GetRaw(e.key)) or "?") .. ")")
    r.remove:SetScript("OnClick", function() Ov:Clear(e.layer, e.id, e.key); Page:Show(host) end)
    r.promote:SetScript("OnClick", function() Ov:Promote(e.layer, e.id, e.key); Page:Show(host) end)
    r:Show()
  end
  for i = #list + 1, #v.rows do v.rows[i]:Hide() end
  v.count = #list
end
