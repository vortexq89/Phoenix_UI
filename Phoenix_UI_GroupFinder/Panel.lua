local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder docked panel (mockup 08, right side): Phoenix's own sorted
-- list of the groups your filter keeps, the "showing X of Y - why hidden"
-- line (click it to relax the filter that hides the most), the expression
-- the chips generate with plain-language validation, your applications, your
-- keystone (Ascent owns keystones; this only reads it) and a searchable word
-- list. Our own frames only: clicking a row selects it in Blizzard's list,
-- double-clicking opens Blizzard's sign-up (queue helper setting).
local _, ns = ...
local Schema, Media = PUI.Schema, PUI.Media
local GF, Filters, Expr = ns.GF, ns.Filters, ns.Expr
local OWNER = "GroupFinder"
local P = { rows = {} }
ns.Panel = P
GF.Panel = P
local s = { panel = true, dock = "right", panelScale = 1, density = "comfortable", compact = false, listRows = 10 }
P.settings = s
P.DENSITY = { comfortable = 22, compact = 18, ultra = 14 }

local function text(parent, role)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(Media:FontObject(role or "small"))
  fs:SetJustifyH("LEFT")
  return fs
end

function P.Build()
  if P.frame then return P.frame end
  local host = rawget(_G, "LFGListFrame")
  if not host then return nil end
  local f = PUI:CreateFrame("Frame", "PhoenixUIGroupFinderPanel", host, nil, OWNER)
  f:SetSize(300, 420)
  f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints(); f.bg:SetColorTexture(0.05, 0.06, 0.07, 0.94)
  f.accent = f:CreateTexture(nil, "BORDER"); f.accent:SetPoint("TOPLEFT"); f.accent:SetPoint("TOPRIGHT"); f.accent:SetHeight(2)
  f.accent:SetColorTexture(0.91, 0.64, 0.24, 1)
  f.title = text(f, "header"); f.title:SetPoint("TOPLEFT", 10, -8)
  f.count = CreateFrame("Button", nil, f); f.count:SetPoint("TOPLEFT", 10, -30); f.count:SetSize(280, 16)
  f.count.text = text(f.count); f.count.text:SetAllPoints()
  f.count:SetScript("OnClick", function() local id = GF.RelaxTop(); if id then PUI.Slash.Print("relaxed filter: " .. id) end end)
  f.expr = text(f); f.expr:SetPoint("TOPLEFT", 10, -50); f.expr:SetWidth(280)
  f.status = text(f); f.status:SetPoint("TOPLEFT", f.expr, "BOTTOMLEFT", 0, -2); f.status:SetWidth(280)
  f.apps = text(f); f.apps:SetPoint("BOTTOMLEFT", 10, 30)
  f.key = text(f); f.key:SetPoint("BOTTOMLEFT", 10, 12)
  f.edit = CreateFrame("Button", nil, f); f.edit:SetSize(70, 16); f.edit:SetPoint("BOTTOMRIGHT", -8, 10)
  f.edit.text = text(f.edit); f.edit.text:SetAllPoints(); f.edit.text:SetText("|cffe8a33dFilters...|r")
  f.edit:SetScript("OnClick", function() if PUI.Options and PUI.Options.Open then PUI.Options:Open("GroupFinder") end end)
  f.help = CreateFrame("Button", nil, f); f.help:SetSize(40, 16); f.help:SetPoint("RIGHT", f.edit, "LEFT", -6, 0)
  f.help.text = text(f.help); f.help.text:SetAllPoints(); f.help.text:SetText("|cffe8a33dWords|r")
  f.help:SetScript("OnClick", function() P.ShowHelp() end)
  P.frame = f
  P.Place()
  return f
end

function P.Place()
  local f = P.frame
  if not f then return end
  f:ClearAllPoints()
  f:SetScale(s.panelScale)
  local host = f:GetParent()
  if s.dock == "left" then f:SetPoint("TOPRIGHT", host, "TOPLEFT", -4, 0)
  elseif s.dock == "detached" then
    local a = Schema:Get("gf.panelPos")
    f:SetPoint(a.point or "CENTER", UIParent, a.relPoint or a.point or "CENTER", a.x or 0, a.y or 0)
  else f:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, 0) end
end

local function row(i)
  local r = P.rows[i]
  if r then return r end
  local f = P.frame
  r = CreateFrame("Button", nil, f)
  r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0.06)
  r.name = text(r); r.name:SetPoint("LEFT", 6, 0)
  r.info = text(r); r.info:SetPoint("RIGHT", -6, 0); r.info:SetJustifyH("RIGHT")
  r:SetScript("OnClick", function(self)
    local frame = rawget(_G, "LFGListFrame")
    local panel = frame and rawget(frame, "SearchPanel")
    if panel and self.resultID and rawget(_G, "LFGListSearchPanel_SelectResult") then LFGListSearchPanel_SelectResult(panel, self.resultID) end
  end)
  r:SetScript("OnDoubleClick", function(self) if ns.Queue.On("doubleClick") and self.resultID then ns.Queue.SignUp(self.resultID) end end)
  P.rows[i] = r
  return r
end

-- RowText(entry) -> left, right (pure; preview and tests use it).
function P.RowText(e)
  local v, act = e.vars, e.meta and e.meta.activity
  local name = (act and (act.name or act.full)) or "Group"
  if v.bestkey and v.bestkey > 0 and act and act.mplus then name = name .. " |cffb0b0b0(best +" .. v.bestkey .. ")|r" end
  local roles = string.format("%dT %dH %dD", v.tanks, v.heals, v.dps)
  local score = GF.ScoreText(v.mprating) or (v.pvprating > 0 and tostring(v.pvprating)) or ""
  return name, score .. "  " .. roles .. "  " .. v.age .. "m"
end

function P.Update()
  if not (GF.active and s.panel) then if P.frame then P.frame:Hide() end return end
  local f = P.Build()
  if not f then return end
  f:Show()
  local cat = GF.category or "dungeon"
  local on = GF.FilterGet(cat, "enabled")
  f.title:SetText("Phoenix Group Finder  |cffb0b0b0" .. Filters.CAT_LABEL[cat] .. (on and "" or " - filter off") .. "|r")
  f.count.text:SetText((GF.countLine or "no search yet") .. ((GF.hidden or 0) > 0 and "  |cffe8a33d(click to relax)|r" or ""))
  local built = Filters.BuildExpression(cat, GF.FilterGet)
  local custom = GF.FilterGet(cat, "expr") or ""
  local shown = built ~= "" and built or "no chips set"
  if custom ~= "" then shown = shown .. "  and  " .. custom end
  f.expr:SetText(s.compact and "" or ("|cff9ad0ff" .. shown .. "|r"))
  local ok, why = Expr.Validate(custom)
  f.status:SetText(s.compact and "" or (ok and "|cff40ff40expression valid|r" or ("|cffff6060" .. why .. "|r")))
  local h = P.DENSITY[s.density] or 22
  local top = s.compact and 50 or 86
  local n = math.min(s.listRows, #GF.shown)
  for i = 1, n do
    local e, r = GF.shown[i], row(i)
    r:SetSize(284, h)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -top - (i - 1) * (h + 1))
    local l, rt = P.RowText(e)
    r.name:SetText(l); r.info:SetText(rt)
    r.resultID = e.id
    local c = GF.RowColor({ status = e.meta.status, declined = e.vars.declined, vars = e.vars, new = e.vars.new })
    if c then r.name:SetTextColor(c.r, c.g, c.b) else r.name:SetTextColor(0.95, 0.95, 0.95) end
    r:Show()
  end
  for i = n + 1, #P.rows do P.rows[i]:Hide() end
  P.shownRows = n
  local apps = ns.Queue and ns.Queue.ApplicationCount() or 0
  f.apps:SetText(string.format("Applications %d/%d", apps, ns.Queue and ns.Queue.MAX_APPS or 5) .. (apps >= 5 and "  |cffff6060at the limit: cancel one in Blizzard's list|r" or ""))
  local Keys = PUI.Ascent and PUI.Ascent.Keys
  local own = Keys and Keys.Own and Keys.Own()
  f.key:SetText(own and ("My key: " .. Keys.Text(own) .. "  |cffb0b0b0(Mythic+ tracker)|r") or "")
  f:SetHeight(top + n * (h + 1) + 56)
end

function P.Hide() if P.frame then P.frame:Hide() end end

function P.HelpText(query)
  local lines = { "Phoenix filter words (" .. #Expr.order .. "). Combine with and, or, not, ( ), < <= > >= = ~=.", "" }
  for _, e in ipairs(Expr.Help(query)) do lines[#lines + 1] = string.format("%-12s %s", e.name, e.help) end
  return table.concat(lines, "\n")
end
function P.ShowHelp(query) PUI.Dialogs:Copy("Group Finder filter words", P.HelpText(query), "Ctrl+C copies; type the words into a category's expression.") end

local hooked = false
function P.Hook()
  if hooked then return end
  local host = rawget(_G, "LFGListFrame")
  if not host then return end
  hooked = true
  host:HookScript("OnShow", function() if GF.active then GF.Refresh() end end)
  host:HookScript("OnHide", function() P.Hide() end)
end

local schema = ns.schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.apply = function(v) s[name] = v; P.Place(); if GF.active then P.Update() end end
  schema["gf." .. name] = def
end
key("panel", { type = "toggle", default = true, label = "Phoenix panel", tooltip = "Docked panel with Phoenix's sorted list of the groups your filter keeps and the why-hidden line.", mode = "simple" })
key("dock", { type = "select", default = "right", choices = { "right", "left", "detached" }, choiceLabels = { right = "Attach right", left = "Attach left", detached = "Detached (move in Studio)" },
  label = "Panel position", tooltip = "Where the Phoenix panel sits next to the group finder.", mode = "simple" })
key("panelScale", { type = "range", default = 1, min = 0.6, max = 1.5, step = 0.05, label = "Panel scale", tooltip = "Size of the Phoenix panel." })
key("density", { type = "select", default = "comfortable", choices = { "comfortable", "compact", "ultra" }, label = "Row density", tooltip = "Row height of Phoenix's list.", mode = "simple" })
key("compact", { type = "toggle", default = false, label = "Compact panel", tooltip = "Hides the expression lines; the list, count and sort stay. Sorting and filters are shared with the full view." })
key("listRows", { type = "range", default = 10, min = 3, max = 25, step = 1, label = "Rows in Phoenix's list", tooltip = "How many matching groups the panel lists." })
schema["gf.panelPos"] = { type = "anchor", default = { point = "CENTER", relPoint = "CENTER", x = 420, y = 0 }, owner = OWNER, mode = "advanced",
  label = "Detached panel position", tooltip = "Where the detached panel sits.", apply = function() P.Place() end }
