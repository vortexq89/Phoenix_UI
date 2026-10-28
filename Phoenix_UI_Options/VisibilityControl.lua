local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- "Where to show" picker (plan 1.19, F7): the control for every schema key of
-- type "visibility". Chips, never code: Always / Only when... / Never, then
-- content, combat, group, specialization and "hide while" chips. A readout
-- under the chips says whether the element is shown right now and, if not,
-- exactly why (PUI.Visibility reasons). Every click commits live through
-- Model.Commit (validated, G26).
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Widgets = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Widgets
local V = PUI.Visibility
local Copy = Schema.Copy
local build = Widgets.build

local CHIP_H, GAP = 24, 6

local function chip(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(CHIP_H)
  b.bg = Theme:Slice(b, A.control, 20)
  b.bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  b.sel = Theme:Slice(b, A.control, 20, "ARTWORK")
  Theme:Paint(b.sel, "accent", 0.22, "vertex")
  b.text = Kit.Text(b, "label", "text.secondary")
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  b:SetWidth(math.max(44, (b.text:GetStringWidth() or 0) + 22))
  local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.05)
  b:SetScript("OnClick", onClick)
  function b:SetOn(on)
    self.on = on
    self.sel:SetShown(on)
    Theme:Paint(self.text, on and "text.primary" or "muted", 1, "text")
  end
  b:SetOn(false)
  return b
end

-- Pure helpers (unit-tested): flip a set member / set a field on a copy.
function Widgets.VisFlip(rule, field, id)
  local r = Copy(rule or { mode = "always" })
  r.mode = "when"
  r[field] = r[field] or {}
  if r[field][id] then r[field][id] = nil else r[field][id] = true end
  if next(r[field]) == nil then r[field] = nil end
  return r
end

function Widgets.VisSet(rule, field, value)
  local r = Copy(rule or { mode = "always" })
  r[field] = value
  if field ~= "mode" then r.mode = "when" end
  return r
end

-- Readout text for a rule: "Shown now" or "Hidden now: <reason>".
function Widgets.VisReadout(def, rule)
  local shown, why
  if def.watchId and V:Why(def.watchId) ~= nil then shown, why = V:Why(def.watchId)
  else shown, why = V.Explain(rule) end
  if shown then return "Shown right now  -  " .. V.Describe(rule), "ok" end
  return "Hidden right now: " .. (why or "rule") .. "  -  " .. V.Describe(rule), "warn"
end

local function specList()
  local n = rawget(_G, "GetNumSpecializations") and GetNumSpecializations() or 0
  local out = {}
  for i = 1, n do
    local _, name = C_SpecializationInfo.GetSpecializationInfo(i)
    out[#out + 1] = { id = i, label = name or ("Spec " .. i) }
  end
  return out
end

function build.visibility(row, def)
  row.stacked = true
  local f = CreateFrame("Frame", nil, row)
  f:SetPoint("TOPLEFT", 14, -50)
  f:SetPoint("RIGHT", -14, 0)
  local bg = Theme:Slice(f, A.card, 28)
  bg:SetVertexColor(1, 1, 1, 0.5)
  local function commit(v) Model.Commit(row.key, v) end
  local function get() return Schema:Get(row.key) end
  f.mode = Kit.Segmented(f, V.MODES, { "Always", "Only when...", "Never" }, function(m) commit(Widgets.VisSet(get(), "mode", m)) end)
  f.mode:SetPoint("TOPLEFT", 12, -10)
  f.lines = {}
  f.chips = {}
  local y = -10 - 30 - 8
  local function line(title, items, field, kind)
    local cap = Kit.Text(f, "caption", "muted")
    cap:SetPoint("TOPLEFT", 14, y - 6)
    cap:SetText(title:upper())
    local x = 120
    local group = { cap = cap, field = field, chips = {} }
    for _, it in ipairs(items) do
      local id, label = it.id, it.label
      local b = chip(f, label, function()
        if kind == "radio" then commit(Widgets.VisSet(get(), field, id))
        else commit(Widgets.VisFlip(get(), field, id)) end
      end)
      b:SetPoint("TOPLEFT", x, y)
      x = x + b:GetWidth() + GAP
      b.id, b.kind = id, kind
      group.chips[#group.chips + 1] = b
    end
    f.lines[#f.lines + 1] = group
    y = y - CHIP_H - GAP
  end
  local content = {}
  for _, c in ipairs(V.CONTENT) do content[#content + 1] = { id = c, label = V.CONTENT_LABELS[c] } end
  line("Content", content, "content")
  line("Combat", { { id = "any", label = "Any" }, { id = "in", label = "In combat" }, { id = "out", label = "Out of combat" } }, "combat", "radio")
  local groups = {}
  for _, g in ipairs(V.GROUPS) do groups[#groups + 1] = { id = g, label = V.GROUP_LABELS[g] } end
  line("Group", groups, "group")
  local specs = specList()
  if #specs > 0 then line("Specialization", specs, "specs") end
  local hide = {}
  for _, h in ipairs(V.HIDE) do hide[#hide + 1] = { id = h, label = V.HIDE_LABELS[h]:gsub("^While ", ""):gsub("^In a ", ""):gsub("^In ", "") } end
  line("Hide while", hide, "hide")
  f.readout = Kit.Text(f, "small", "muted")
  f.readout:SetPoint("TOPLEFT", 14, y - 4)
  f.readout:SetPoint("RIGHT", -14, 0)
  f.readout:SetJustifyH("LEFT")
  local h = -y + 26
  f:SetHeight(h)
  row:SetHeight(50 + h + 12)
  row.control = f
  function row:Show_(rule)
    f.mode:SetValue_(rule.mode)
    local active = rule.mode == "when"
    for _, g in ipairs(f.lines) do
      Theme:Paint(g.cap, active and "muted" or "line2", 1, "text")
      for _, b in ipairs(g.chips) do
        local on
        if b.kind == "radio" then on = (rule[g.field] or "any") == b.id
        else on = rule[g.field] ~= nil and rule[g.field][b.id] == true end
        b:SetOn(active and on)
        b:SetAlpha(active and 1 or 0.45)
      end
    end
    local text, kind = Widgets.VisReadout(def, rule)
    f.readout:SetText(text)
    Theme:Paint(f.readout, kind, 1, "text")
  end
end

PUI.Kernel:On("VISIBILITY_CHANGED", function()
  for key, row in pairs(Options.rows or {}) do
    local def = Schema:Def(key)
    if def and def.type == "visibility" and row:IsShown() then row:Refresh() end
  end
end)
