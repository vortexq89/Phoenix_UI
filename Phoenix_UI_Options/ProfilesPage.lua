local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Profiles page (mockup 07): your profiles (new / copy / rename / delete /
-- reset / use), content profiles (Raid, Mythic+, Arena ... each a layer over
-- your own profile; auto-switch on by default) and Share (export a whole
-- profile or one module, import with a checked preview: new, merge or
-- replace). Destructive buttons confirm inline (click again within 4 s);
-- no StaticPopup (G5).
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Widgets, Nav = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Widgets, Options.Nav
local Profiles = PUI.Profiles
local PP = { selected = nil }
Options.ProfilesPage = PP
Options.views = Options.views or {}

local LIST_ROW, PAD = 34, 30

local function status(v, text, kind)
  v.status:SetText(text or "")
  Theme:Paint(v.status, kind == "err" and "err" or (kind == "ok" and "ok" or "muted"), 1, "text")
end

-- Inline confirm: first click arms (label changes), second within 4 s acts.
local function confirmButton(parent, label, width, kind, act)
  local b = Kit.Button(parent, label, width, nil, kind)
  b:SetScript("OnClick", function(self)
    local now = GetTime()
    if self.armed and now - self.armed < 4 then
      self.armed = nil; self:SetLabel(label); act()
    else
      self.armed = now; self:SetLabel("Sure?")
    end
  end)
  b:SetScript("OnHide", function(self) self.armed = nil; self:SetLabel(label) end)
  return b
end

local function editBox(parent, w, h, multi)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, h)
  e:SetAutoFocus(false)
  e:SetMultiLine(multi and true or false)
  e:SetFontObject(Kit.FontObject(multi and "mono" or "label"))
  e:SetTextInsets(10, 10, multi and 8 or 0, multi and 8 or 0)
  local bg = Theme:Slice(e, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  return e
end

local function build(host)
  local v = CreateFrame("Frame", nil, host)
  v:SetAllPoints()
  v.icon = Kit.Icon(v, A.Icon("profiles"), 44)
  v.icon:SetPoint("TOPLEFT", PAD, -40)
  v.title = Kit.Text(v, "display", "text.primary")
  v.title:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", 14, 2)
  v.title:SetText("Profiles")
  v.desc = Kit.Text(v, "text", "muted")
  v.desc:SetPoint("TOPLEFT", v.title, "BOTTOMLEFT", 0, -4)
  v.desc:SetText("Every profile applies live. Content profiles only store what differs from your own profile.")
  v.more = Kit.Button(v, "Where to switch", 140, function() Options.rawPage = "Profiles"; Options:Render() end, "ghost")
  v.more:SetPoint("TOPRIGHT", -PAD, -52)
  v.status = Kit.Text(v, "small", "muted")
  v.status:SetPoint("RIGHT", v.more, "LEFT", -12, 0)

  -- Your profiles
  local list = Kit.Card(v)
  list:SetPoint("TOPLEFT", PAD, -112)
  list:SetSize(440, 360)
  Kit.Section(list, "Your profiles"):SetPoint("TOPLEFT", 18, -16)
  list.rows = {}
  v.list = list
  v.name = editBox(list, 250, 30)
  v.name:SetPoint("BOTTOMLEFT", 18, 58)
  v.nameHint = Kit.Text(v.name, "small", "muted")
  v.nameHint:SetPoint("LEFT", 10, 0)
  v.nameHint:SetText("Profile name")
  v.name:SetScript("OnTextChanged", function(self) v.nameHint:SetShown(self:GetText() == "") end)
  local function named() return v.name:GetText() end
  local function done(ok, why, msg)
    if ok then status(v, msg, "ok"); v.name:SetText(""); v.name:ClearFocus() else status(v, why, "err") end
    PP:Refresh(v)
  end
  v.new = Kit.Button(list, "New", 70, function() local n, why = Profiles:Create(named()); if n then PP.selected = n end; done(n, why, "Created " .. tostring(n)) end, "primary")
  v.new:SetPoint("LEFT", v.name, "RIGHT", 8, 0)
  v.copy = Kit.Button(list, "Copy", 70, function()
    local n, why = Profiles:Create(named() ~= "" and named() or (PP.selected .. " copy"), PP.selected)
    if n then PP.selected = n end
    done(n, why, "Copied to " .. tostring(n))
  end, "secondary")
  v.copy:SetPoint("LEFT", v.new, "RIGHT", 6, 0)
  v.use = Kit.Button(list, "Use", 80, function() local ok, why = Profiles:Switch(PP.selected); done(ok, why, "Using " .. PP.selected) end, "primary")
  v.use:SetPoint("BOTTOMLEFT", 18, 18)
  v.rename = Kit.Button(list, "Rename", 90, function() local n, why = Profiles:Rename(PP.selected, named()); if n then PP.selected = n end; done(n, why, "Renamed to " .. tostring(n)) end, "secondary")
  v.rename:SetPoint("LEFT", v.use, "RIGHT", 6, 0)
  v.reset = confirmButton(list, "Reset", 80, "ghost", function() local ok, why = Profiles:Reset(PP.selected); done(ok, why, PP.selected .. " reset to defaults") end)
  v.reset:SetPoint("LEFT", v.rename, "RIGHT", 6, 0)
  v.delete = confirmButton(list, "Delete", 80, "danger", function()
    local old = PP.selected
    local ok, why = Profiles:Delete(old)
    if ok then PP.selected = nil end
    done(ok, why, "Deleted " .. old)
  end)
  v.delete:SetPoint("LEFT", v.reset, "RIGHT", 6, 0)

  -- Content profiles
  local content = Kit.Card(v)
  content:SetPoint("TOPLEFT", list, "TOPRIGHT", 16, 0)
  content:SetPoint("RIGHT", -PAD, 0)
  content:SetHeight(360)
  Kit.Section(content, "Content profiles"):SetPoint("TOPLEFT", 18, -16)
  v.autoRow = Widgets.Row(content, "core.autoProfile")
  v.autoRow:SetPoint("TOPLEFT", 6, -36)
  v.autoRow:SetPoint("RIGHT", -6, 0)
  v.content = {}
  for i, c in ipairs(Profiles.CONTENT) do
    local r = CreateFrame("Frame", nil, content)
    r:SetHeight(32)
    r:SetPoint("TOPLEFT", 20, -92 - (i - 1) * 36)
    r:SetPoint("RIGHT", -18, 0)
    r.label = Kit.Text(r, "body", "text.primary")
    r.label:SetPoint("LEFT")
    r.label:SetText(Profiles.CONTENT_LABEL[c])
    r.here = Kit.Badge(r, "You are here", "accent")
    r.here:SetPoint("LEFT", r.label, "RIGHT", 10, 0)
    r.pick = Kit.Button(r, "", 220, function(self)
      local names = { "" }
      for _, n in ipairs(Profiles:List()) do names[#names + 1] = n end
      Widgets.OpenMenu(self, names, function(n) return n == "" and "Your own profile" or n end, Profiles:Mapped(c) or "",
        function(n) Profiles:MapContent(c, n ~= "" and n or nil); PP:Refresh(v) end)
    end, "secondary")
    r.pick:SetPoint("RIGHT")
    r.content = c
    v.content[i] = r
  end

  -- Share
  local share = Kit.Card(v)
  share:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -16)
  share:SetPoint("BOTTOMRIGHT", -PAD, 20)
  Kit.Section(share, "Share"):SetPoint("TOPLEFT", 18, -16)
  v.scope = Kit.Button(share, "", 200, function(self)
    local owners = { "" }
    for _, p in ipairs(Model.Pages("advanced")) do if not p.virtual then owners[#owners + 1] = p.name end end
    Widgets.OpenMenu(self, owners, function(o) return o == "" and "Whole profile" or select(2, Nav.Info(o)) end, PP.scope or "",
      function(o) PP.scope = o ~= "" and o or nil; PP:Refresh(v) end)
  end, "secondary")
  v.scope:SetPoint("TOPLEFT", 18, -40)
  v.export = Kit.Button(share, "Export", 90, function()
    local s, why = Profiles:Export(PP.selected, PP.scope)
    if not s then return status(v, why, "err") end
    v.box:SetText(s); v.box:SetFocus(); v.box:HighlightText()
    status(v, "Copy with Ctrl C. " .. #s .. " characters.", "ok")
  end, "primary")
  v.export:SetPoint("LEFT", v.scope, "RIGHT", 8, 0)
  v.check = Kit.Button(share, "Check import", 120, function() PP:Check(v) end, "secondary")
  v.check:SetPoint("LEFT", v.export, "RIGHT", 8, 0)
  local scroll = CreateFrame("ScrollFrame", nil, share)
  scroll:SetPoint("TOPLEFT", 18, -78)
  scroll:SetPoint("BOTTOMRIGHT", -380, 16)
  v.box = editBox(scroll, 400, 100, true)
  v.box:SetMaxBytes(512 * 1024)
  scroll:SetScrollChild(v.box)
  scroll:SetScript("OnSizeChanged", function(self, w) v.box:SetWidth(w) end)
  v.box:SetScript("OnTextChanged", function(_, user) if user then PP.plan = nil; PP:Refresh(v) end end)
  v.preview = Kit.Text(share, "text", "text.secondary")
  v.preview:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 16, 0)
  v.preview:SetWidth(340)
  v.preview:SetJustifyV("TOP")
  local function apply(mode)
    local target = mode == "new" and (named() ~= "" and named() or PP.plan.name) or PP.selected
    local ok, why = Profiles:Apply(PP.plan, mode, target)
    if ok then PP.selected = ok; PP.plan = nil; v.box:SetText("") end
    done(ok, why, "Imported into " .. tostring(ok))
  end
  v.asNew = Kit.Button(share, "Import as new", 120, function() apply("new") end, "primary")
  v.asNew:SetPoint("BOTTOMRIGHT", -250, 16)
  v.merge = Kit.Button(share, "Merge", 100, function() apply("merge") end, "secondary")
  v.merge:SetPoint("LEFT", v.asNew, "RIGHT", 6, 0)
  v.replace = confirmButton(share, "Replace", 110, "danger", function() apply("replace") end)
  v.replace:SetPoint("LEFT", v.merge, "RIGHT", 6, 0)

  function v:OnSetting(key) if key == "core.profile" or key:find("^core%.autoProfile") then PP:Refresh(self) end end
  PUI.Kernel:On("PROFILES_CHANGED", function() if v:IsShown() then PP:Refresh(v) end end)
  Options.views.profiles = v
  return v
end

function PP:Check(v)
  local plan, why = Profiles:Decode(v.box:GetText())
  self.plan = plan
  if not plan then status(v, why, "err") else status(v, "String checked.", "ok") end
  self:Refresh(v)
end

local function listRow(list, i)
  local r = list.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, list)
  r:SetHeight(LIST_ROW - 4)
  r:SetPoint("TOPLEFT", 12, -40 - (i - 1) * LIST_ROW)
  r:SetPoint("RIGHT", -12, 0)
  r.sel = Theme:Slice(r, A.control, 20)
  r.bar = Kit.AccentBar(r, 3, 18)
  r.bar:SetPoint("LEFT", 0, 0)
  r.text = Kit.Text(r, "body", "text.primary")
  r.text:SetPoint("LEFT", 14, 0)
  r.badge = Kit.Badge(r, "", "accent")
  r.badge:SetPoint("RIGHT", -8, 0)
  local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.04)
  list.rows[i] = r
  return r
end

function PP:Refresh(v)
  v = v or Options.views.profiles
  if not v then return end
  local names = Profiles:List()
  local active, base = Profiles:Active()
  if not (self.selected and Profiles:Exists(self.selected)) then self.selected = base or active end
  local uses = {}
  for _, c in ipairs(Profiles.CONTENT) do
    local m = Profiles:Mapped(c)
    if m then uses[m] = (uses[m] and (uses[m] .. ", ") or "") .. Profiles.CONTENT_LABEL[c] end
  end
  local maxRows = 6
  for i = 1, math.max(#names, #v.list.rows) do
    local r = listRow(v.list, i)
    local n = names[i]
    if n and i <= maxRows then
      r.text:SetText(n)
      local sel = n == self.selected
      r.sel:SetVertexColor(1, 1, 1, sel and 0.10 or 0)
      r.bar:SetShown(sel)
      local tag = (n == active and "Active") or (n == base and "Yours") or uses[n]
      r.badge:SetShown(tag ~= nil)
      if tag then r.badge:SetText(tag) end
      r:SetScript("OnClick", function() PP.selected = n; PP:Refresh(v) end)
      r:Show()
    else
      r:Hide()
    end
  end
  local inUse = self.selected == active or self.selected == base
  v.use:SetEnabled(not inUse); v.use:SetAlpha(inUse and 0.4 or 1)
  v.delete:SetEnabled(not inUse); v.delete:SetAlpha(inUse and 0.4 or 1)
  local here = Profiles:Content()
  local auto = Schema:Get("core.autoProfile")
  v.autoRow:Refresh()
  v.autoRow:Show()
  for _, r in ipairs(v.content) do
    local m = Profiles:Mapped(r.content)
    r.pick:SetLabel(m or "Your own profile")
    r.here:SetShown(r.content == here)
    r:SetAlpha((auto and Schema:Cell("core.autoProfile.where", "switch", r.content)) and 1 or 0.45)
  end
  v.scope:SetLabel(self.scope and select(2, Nav.Info(self.scope)) or "Whole profile")
  local plan = self.plan
  if plan then
    local lines = { string.format("|cffffffff%s|r  %d setting(s)%s", plan.name, plan.count, plan.owner and (" - " .. plan.owner) or "") }
    if plan.unknown > 0 then lines[#lines + 1] = plan.unknown .. " from modules you do not have (skipped)" end
    if #plan.invalid > 0 then
      lines[#lines + 1] = "|cffff6060" .. #plan.invalid .. " invalid - nothing will be imported:|r"
      for i = 1, math.min(4, #plan.invalid) do lines[#lines + 1] = "  " .. plan.invalid[i] end
    else
      lines[#lines + 1] = "Merge or replace targets: " .. tostring(self.selected)
    end
    v.preview:SetText(table.concat(lines, "\n"))
  else
    v.preview:SetText("Paste a !PUI1! string and press Check import to see what it changes before anything is applied.")
  end
  local ready = plan ~= nil and #plan.invalid == 0
  for _, b in ipairs({ v.asNew, v.merge, v.replace }) do b:SetEnabled(ready); b:SetAlpha(ready and 1 or 0.4) end
end

function PP:Show(host)
  local v = Options.views.profiles or build(host)
  v:Show()
  self:Refresh(v)
end
