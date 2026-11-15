local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Controls: the shared widgets beyond toggle / slider / dropdown / text.
-- colour (swatch + Blizzard picker with alpha, Cancel restores, drag commits
-- once per frame through the Ticker), keybind (capture with conflict note),
-- anchor (3x3 point grid + typed X/Y), list editor (add / reorder / remove)
-- and the per-content grid. All of them write through Model.Commit, so every
-- change is validated and live. Modules and plugins get them by declaring a
-- schema key of that type; nothing else is needed.
local Options, Theme = PUI.Options, PUI.Theme
local Model, Schema, Kit, A, Widgets = Options.Model, PUI.Schema, Options.Kit, Options.Assets, Options.Widgets
local build = Widgets.build
local Copy = Schema.Copy

local function field(parent, w)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, 28)
  e:SetAutoFocus(false)
  e:SetFontObject(Kit.FontObject("mono"))
  e:SetJustifyH("CENTER")
  local bg = Theme:Slice(e, A.control, 20)
  bg:SetVertexColor(0.06, 0.07, 0.09, 1)
  return e
end

-- Colour --------------------------------------------------------------------------
local pending -- { key, value } committed on the next frame (debounced drag)
local function flush()
  PUI.Ticker:Unregister("options.colorCommit")
  if pending then local p = pending; pending = nil; Model.Commit(p.key, p.value) end
end
local function queue(key, value)
  pending = { key = key, value = value }
  if not PUI.Ticker:IsRegistered("options.colorCommit") then PUI.Ticker:Register("options.colorCommit", 0, flush, "Options") end
end
Widgets.FlushColor = flush

function Widgets.PickColor(key)
  local def = Schema:Def(key)
  local old = Schema:Get(key)
  local alpha = def.hasAlpha ~= false
  local function read()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local v = { r = r, g = g, b = b }
    if alpha then v.a = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or old.a or 1 end
    return v
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = old.r, g = old.g, b = old.b, opacity = old.a or 1, hasOpacity = alpha,
    swatchFunc = function() queue(key, read()) end,
    opacityFunc = function() queue(key, read()) end,
    cancelFunc = function() pending = nil; Model.Commit(key, old) end, -- G10: Cancel restores
  })
end

function build.color(row, def)
  local f = CreateFrame("Frame", nil, row)
  f:SetSize(170, 30)
  f:SetPoint("RIGHT", -14, 0)
  local sw = CreateFrame("Button", nil, f)
  sw:SetSize(46, 26)
  sw:SetPoint("LEFT")
  local frame = Theme:Slice(sw, A.control, 20)
  frame:SetVertexColor(0.06, 0.07, 0.09, 1)
  local check = sw:CreateTexture(nil, "ARTWORK", nil, 1) -- alpha backing: two-tone halves
  check:SetPoint("TOPLEFT", 4, -4)
  check:SetPoint("BOTTOMRIGHT", sw, "BOTTOM", 0, 4)
  check:SetColorTexture(0.85, 0.85, 0.85, 1)
  local check2 = sw:CreateTexture(nil, "ARTWORK", nil, 1)
  check2:SetPoint("TOPLEFT", sw, "TOP", 0, -4)
  check2:SetPoint("BOTTOMRIGHT", -4, 4)
  check2:SetColorTexture(0.45, 0.45, 0.45, 1)
  local fill = sw:CreateTexture(nil, "ARTWORK", nil, 2)
  fill:SetPoint("TOPLEFT", 4, -4)
  fill:SetPoint("BOTTOMRIGHT", -4, 4)
  local hl = sw:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  sw:SetScript("OnClick", function() Widgets.PickColor(row.key) end)
  local hex = Kit.Text(f, "mono", "text.secondary")
  hex:SetPoint("LEFT", sw, "RIGHT", 10, 0)
  -- quick swatches: class colour and accent
  local function quick(token, x, getter)
    local q = CreateFrame("Button", nil, f)
    q:SetSize(14, 14)
    q:SetPoint("RIGHT", x, 0)
    local t = q:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    if token then Theme:Paint(t, token) else local r, g, b = getter(); t:SetColorTexture(r, g, b, 1) end
    q:SetScript("OnClick", function()
      local r, g, b = getter()
      local cur = Schema:Get(row.key)
      Model.Commit(row.key, { r = r, g = g, b = b, a = cur.a })
    end)
    return q
  end
  quick("accent", -22, function() return Theme:Color("accent") end)
  local function classRGB()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
  end
  quick(nil, 0, classRGB)
  row.control = f
  function row:Show_(v)
    fill:SetColorTexture(v.r, v.g, v.b, v.a or 1)
    hex:SetText(Model.Format(def, v))
  end
end

-- Keybind -------------------------------------------------------------------------
local MODIFIER = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

function Widgets.KeyCombo(key)
  if MODIFIER[key] then return nil end
  local out = ""
  if IsAltKeyDown and IsAltKeyDown() then out = out .. "ALT-" end
  if IsControlKeyDown() then out = out .. "CTRL-" end
  if IsShiftKeyDown() then out = out .. "SHIFT-" end
  return out .. key
end

-- Text naming another action already on this key (Blizzard bindings), or nil.
function Widgets.KeyConflict(combo)
  if combo == "" or not GetBindingAction then return nil end
  local action = GetBindingAction(combo)
  if not action or action == "" or action:find("PhoenixUIOptionsToggleButton", 1, true) then return nil end
  return _G["BINDING_NAME_" .. action] or action
end

function build.keybind(row, def)
  local b = Kit.Button(row, "", 180, nil, "secondary")
  b:SetPoint("RIGHT", -14, 0)
  b.warn = Kit.Text(row, "small", "warn")
  b.warn:SetPoint("RIGHT", b, "LEFT", -10, 0)
  local function stop(self, commit)
    self.capturing = false
    self:EnableKeyboard(false)
    self:SetScript("OnKeyDown", nil)
    if commit ~= nil then Model.Commit(row.key, commit) end
    row:Refresh()
  end
  local function onKey(self, key)
    if key == "ESCAPE" then return stop(self) end
    if key == "BACKSPACE" or key == "DELETE" then return stop(self, "") end
    local combo = Widgets.KeyCombo(key)
    if combo then stop(self, combo) end
  end
  b:RegisterForClicks("AnyUp")
  b:SetScript("OnClick", function(self, button)
    if self.capturing then
      if MOUSE[button] then stop(self, Widgets.KeyCombo(MOUSE[button])) end
      return
    end
    if button == "RightButton" then return Model.Commit(row.key, "") end
    if InCombatLockdown() then return PUI.Slash.Print("Key capture waits until combat ends.") end
    self.capturing = true
    self:EnableKeyboard(true)
    if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
    self:SetScript("OnKeyDown", onKey)
    self:SetLabel("Press a key...  Esc cancels")
    Theme:Paint(self.bg, "accent", 0.6, "vertex")
  end)
  b:SetScript("OnHide", function(self) if self.capturing then stop(self) end end)
  row.control = b
  function row:Show_(v)
    if b.capturing then return end
    b.bg:SetVertexColor(1, 1, 1, 1)
    b:SetLabel(Model.Format(def, v))
    local other = Widgets.KeyConflict(v)
    b.warn:SetText(other and ("Also bound: " .. other) or "")
  end
end

-- Anchor --------------------------------------------------------------------------
local GRID = { { "TOPLEFT", "TOP", "TOPRIGHT" }, { "LEFT", "CENTER", "RIGHT" }, { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" } }

function build.anchor(row, def)
  local f = CreateFrame("Frame", nil, row)
  f:SetSize(250, 40)
  f:SetPoint("RIGHT", -14, 0)
  local pad = CreateFrame("Frame", nil, f)
  pad:SetSize(40, 40)
  pad:SetPoint("LEFT")
  local pbg = Theme:Slice(pad, A.control, 20)
  pbg:SetVertexColor(0.06, 0.07, 0.09, 1)
  f.dots = {}
  for r = 1, 3 do
    for c = 1, 3 do
      local d = CreateFrame("Button", nil, pad)
      d:SetSize(12, 12)
      d:SetPoint("TOPLEFT", 2 + (c - 1) * 12, -2 - (r - 1) * 12)
      d.t = d:CreateTexture(nil, "ARTWORK")
      d.t:SetSize(5, 5)
      d.t:SetPoint("CENTER")
      d.point = GRID[r][c]
      d:SetScript("OnClick", function(self)
        local v = Schema:Get(row.key)
        v.point, v.relPoint = self.point, self.point
        Model.Commit(row.key, v)
      end)
      d:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.point); GameTooltip:Show() end)
      d:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.dots[#f.dots + 1] = d
    end
  end
  local function axis(name, x)
    local lbl = Kit.Text(f, "caption", "muted")
    lbl:SetText(name)
    local e = field(f, 62)
    e:SetPoint("LEFT", x, 0)
    lbl:SetPoint("RIGHT", e, "LEFT", -6, 0)
    local function commit(self)
      local n = tonumber(self:GetText())
      self:ClearFocus()
      if not n then return row:Refresh() end
      local v = Schema:Get(row.key)
      v[name:lower()] = math.floor(n + 0.5)
      Model.Commit(row.key, v)
    end
    e:SetScript("OnEnterPressed", commit)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row:Refresh() end) -- G10: Escape reverts
    e:EnableMouseWheel(true)
    e:SetScript("OnMouseWheel", function(_, delta)
      local v = Schema:Get(row.key)
      v[name:lower()] = v[name:lower()] + delta * (IsShiftKeyDown() and 10 or 1)
      Model.Commit(row.key, v)
    end)
    return e
  end
  f.x = axis("X", 80)
  f.y = axis("Y", 180)
  row.control = f
  function row:Show_(v)
    for _, d in ipairs(f.dots) do
      local on = d.point == v.point
      d.t:SetSize(on and 7 or 4, on and 7 or 4)
      Theme:Paint(d.t, on and "accent" or "muted", on and 1 or 0.6)
    end
    if not f.x:HasFocus() then f.x:SetText(tostring(v.x)) end
    if not f.y:HasFocus() then f.y:SetText(tostring(v.y)) end
  end
end

-- List editor ---------------------------------------------------------------------
local LIST_ITEM = 30
local function itemLabel(def, v)
  if def.itemLabel then return def.itemLabel(v) end
  if Options.Nav and Options.Nav.Info then
    local _, label = Options.Nav.Info(v)
    if label then return label end
  end
  return v
end

function Widgets.ListMove(list, i, dir)
  local j = i + dir
  if j < 1 or j > #list then return list end
  list[i], list[j] = list[j], list[i]
  return list
end

-- Composers: a structured "add" row for list settings whose items have a
-- grammar (def.composer = name). The composer calls add(text); the list's
-- itemValidate decides, and a refusal is shown under the row.
Widgets.composers = Widgets.composers or {}

-- Click-cast composer: [modifiers] [mouse button or key] [action] [spell / macro / item] [Add].
local CC_MODS = { "none", "shift", "ctrl", "alt", "ctrl-shift", "alt-shift", "alt-ctrl" }
local CC_MOD_LABELS = { none = "No modifier", shift = "Shift", ctrl = "Ctrl", alt = "Alt", ["ctrl-shift"] = "Ctrl + Shift",
  ["alt-shift"] = "Alt + Shift", ["alt-ctrl"] = "Alt + Ctrl" }
local CC_TRIGGERS = { "1", "2", "3", "4", "5", "key" }
local CC_ACTIONS = { "spell", "target", "menu", "focus", "assist", "macro", "item" }
function Widgets.composers.clickcast(parent, def, add)
  local CC = PUI.ClickCast
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(28)
  local state = { mods = "none", trigger = "1", key = nil, action = "spell" }
  local function pick(label, width, choices, labelOf, field_)
    local b = Kit.Button(c, "", width, nil, "secondary")
    b:SetHeight(26)
    local function refresh() b:SetText(labelOf(state[field_])) end
    b:SetScript("OnClick", function(self)
      Widgets.OpenMenu(self, choices, labelOf, state[field_], function(v) state[field_] = v; refresh(); c:Refresh() end)
    end)
    refresh()
    b.refresh = refresh
    return b
  end
  c.mods = pick("Modifier", 112, CC_MODS, function(v) return CC_MOD_LABELS[v] end, "mods")
  c.mods:SetPoint("LEFT", 0, 0)
  c.trigger = pick("Button", 128, CC_TRIGGERS, function(v)
    if v == "key" then return state.key and ("Key " .. state.key) or "Press a key..." end
    return CC and CC.BUTTON_LABELS[v] or v
  end, "trigger")
  c.trigger:SetPoint("LEFT", c.mods, "RIGHT", 6, 0)
  -- Key capture when "key" is picked: the next key press is the binding.
  c.trigger:SetScript("OnKeyDown", function(self, key)
    if state.trigger ~= "key" then return end
    if key == "ESCAPE" then self:EnableKeyboard(false) return end
    if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
    state.key = key
    self:EnableKeyboard(false)
    self.refresh()
  end)
  c.action = pick("Action", 116, CC_ACTIONS, function(v) return CC and CC.ACTION_LABELS[v] or v end, "action")
  c.action:SetPoint("LEFT", c.trigger, "RIGHT", 6, 0)
  c.value = field(c, 150)
  c.value:SetJustifyH("LEFT")
  c.value:SetTextInsets(8, 8, 0, 0)
  c.value:SetHeight(26)
  c.value:SetPoint("LEFT", c.action, "RIGHT", 6, 0)
  c.add = Kit.Button(c, "+  Add", 80, nil, "primary")
  c.add:SetHeight(26)
  c.add:SetPoint("LEFT", c.value, "RIGHT", 6, 0)
  function c:Refresh()
    local needsValue = state.action == "spell" or state.action == "macro" or state.action == "item"
    c.value:SetShown(needsValue)
    c.trigger:EnableKeyboard(state.trigger == "key" and state.key == nil)
  end
  local function submit()
    if not CC then return end
    local button = state.trigger == "key" and state.key or state.trigger
    if not button then return end
    local mods = {}
    for part in string.gmatch(state.mods, "[^-]+") do if part ~= "none" then mods[part] = true end end
    if add(CC.Compose(mods, button, state.action, c.value:GetText())) then c.value:SetText("") end
  end
  c.add:SetScript("OnClick", submit)
  c.value:SetScript("OnEnterPressed", function(self) self:ClearFocus(); submit() end)
  c.value:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  c:Refresh()
  return c
end

function build.list(row, def)
  row.stacked = true
  local f = CreateFrame("Frame", nil, row)
  f:SetPoint("TOPLEFT", 14, -50)
  f:SetPoint("RIGHT", -14, 0)
  f.items = {}
  local function commit(list) Model.Commit(row.key, list) end
  local function item(i)
    local it = f.items[i]
    if it then return it end
    it = CreateFrame("Frame", nil, f)
    it:SetHeight(LIST_ITEM - 4)
    it:SetPoint("TOPLEFT", 0, -(i - 1) * LIST_ITEM)
    it:SetPoint("RIGHT")
    local bg = Theme:Slice(it, A.control, 20)
    bg:SetVertexColor(0.06, 0.07, 0.09, 1)
    it.num = Kit.Text(it, "mono", "muted")
    it.num:SetPoint("LEFT", 10, 0)
    it.text = Kit.Text(it, "label", "text.primary")
    it.text:SetPoint("LEFT", 34, 0)
    local function btn(label, x, fn)
      local b = Kit.Button(it, label, 26, fn, "ghost")
      b:SetHeight(22)
      b:SetPoint("RIGHT", x, 0)
      return b
    end
    it.del = btn("x", -4, function() local l = Schema:Get(row.key); table.remove(l, it.index); commit(l) end)
    it.down = btn("v", -32, function() commit(Widgets.ListMove(Schema:Get(row.key), it.index, 1)) end)
    it.up = btn("^", -60, function() commit(Widgets.ListMove(Schema:Get(row.key), it.index, -1)) end)
    f.items[i] = it
    return it
  end
  f.add = Kit.Button(f, "+  Add", 110, nil, "secondary")
  f.add:SetHeight(26)
  f.input = field(f, 220)
  f.input:SetJustifyH("LEFT")
  f.input:SetTextInsets(10, 10, 0, 0)
  local function addValue(v)
    if not v or v == "" then return end
    local l = Schema:Get(row.key)
    for i = 1, #l do if l[i] == v then return end end
    l[#l + 1] = v
    commit(l)
  end
  f.input:SetScript("OnEnterPressed", function(self) local v = self:GetText(); self:SetText(""); self:ClearFocus(); addValue(v) end)
  f.input:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  f.add:SetScript("OnClick", function(self)
    if def.itemChoices then
      local choices, have = {}, {}
      for _, v in ipairs(Schema:Get(row.key)) do have[v] = true end
      for _, v in ipairs(def.itemChoices()) do if not have[v] then choices[#choices + 1] = v end end
      Widgets.OpenMenu(self, choices, function(v) return itemLabel(def, v) end, nil, addValue)
    else
      addValue(f.input:GetText()); f.input:SetText("")
    end
  end)
  f.empty = Kit.Text(f, "small", "muted")
  f.empty:SetText("Nothing yet.")
  f.err = Kit.Text(f, "small", "err")
  local composer
  if def.composer and Widgets.composers[def.composer] then
    composer = Widgets.composers[def.composer](f, def, function(v)
      local okItem, why = true, nil
      if def.itemValidate then okItem, why = def.itemValidate(v) end
      f.err:SetText(okItem and "" or tostring(why))
      if okItem then addValue(v) end
      return okItem
    end)
  end
  row.control = f
  function row:Show_(list)
    for i = 1, math.max(#list, #f.items) do
      local it = item(i)
      if list[i] then
        it.index = i
        it.num:SetText(i)
        it.text:SetText(itemLabel(def, list[i]))
        it.up:SetEnabled(i > 1)
        it.down:SetEnabled(i < #list)
        it:Show()
      else
        it:Hide()
      end
    end
    local y = -#list * LIST_ITEM - 2
    f.empty:SetShown(#list == 0)
    f.empty:ClearAllPoints()
    f.empty:SetPoint("TOPLEFT", 2, -4)
    if #list == 0 then y = -24 end
    local full = def.maxItems and #list >= def.maxItems
    f.add:ClearAllPoints()
    f.input:ClearAllPoints()
    if composer then
      f.input:Hide()
      f.add:Hide()
      composer:ClearAllPoints()
      composer:SetPoint("TOPLEFT", 0, y)
      composer:SetPoint("RIGHT")
      composer:Show()
      f.err:ClearAllPoints()
      f.err:SetPoint("TOPLEFT", composer, "BOTTOMLEFT", 2, -4)
      y = y - 16
    elseif def.itemChoices then
      f.input:Hide()
      f.add:SetPoint("TOPLEFT", 0, y)
    else
      f.input:Show()
      f.input:SetPoint("TOPLEFT", 0, y)
      f.add:SetPoint("LEFT", f.input, "RIGHT", 8, 0)
    end
    f.add:SetEnabled(not full)
    f.add:SetAlpha(full and 0.4 or 1)
    local h = -y + 32
    f:SetHeight(h)
    self:SetHeight(50 + h + 10)
  end
end

-- Per-content grid ----------------------------------------------------------------
local COL_W, GRID_ROW = 92, 32
local function labelOf(e) return type(e) == "table" and (e.label or e.id) or e end
local function idOf(e) return type(e) == "table" and e.id or e end

-- Flip one cell, or a whole column / row when only one of r, c is given.
function Widgets.GridFlip(def, value, r, c)
  local rows, cols = Schema.Ids(def.rows), Schema.Ids(def.columns)
  local function get(rr, cc) local line = value[rr]; local v = line and line[cc]; if v == nil then v = def.cellDefault == true end; return v end
  local function set(rr, cc, on) value[rr] = value[rr] or {}; value[rr][cc] = on end
  if r and c then set(r, c, not get(r, c)); return value end
  local targets, on = {}, 0
  for _, rr in ipairs(r and { r } or rows) do
    for _, cc in ipairs(c and { c } or cols) do targets[#targets + 1] = { rr, cc }; if get(rr, cc) then on = on + 1 end end
  end
  local want = on * 2 < #targets -- mostly off -> all on, else all off
  for _, t in ipairs(targets) do set(t[1], t[2], want) end
  return value
end

function build.grid(row, def)
  row.stacked = true
  local f = CreateFrame("Frame", nil, row)
  f:SetPoint("TOPLEFT", 14, -50)
  f:SetPoint("RIGHT", -14, 0)
  local rowsL = type(def.rows) == "function" and def.rows() or def.rows
  local colsL = type(def.columns) == "function" and def.columns() or def.columns
  local LABEL_W = 150
  local bg = Theme:Slice(f, A.card, 28)
  bg:SetVertexColor(1, 1, 1, 0.5)
  f.cells = {}
  for ci, col in ipairs(colsL) do
    local h = CreateFrame("Button", nil, f)
    h:SetSize(COL_W, 26)
    h:SetPoint("TOPLEFT", LABEL_W + (ci - 1) * COL_W, -6)
    h.text = Kit.Text(h, "caption", "muted")
    h.text:SetPoint("CENTER")
    h.text:SetJustifyH("CENTER")
    h.text:SetText(labelOf(col):upper())
    local hl = h:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.04)
    h:SetScript("OnClick", function() Model.Commit(row.key, Widgets.GridFlip(def, Schema:Get(row.key), nil, idOf(col))) end)
  end
  for ri, r in ipairs(rowsL) do
    local y = -6 - ri * GRID_ROW
    local lb = CreateFrame("Button", nil, f)
    lb:SetSize(LABEL_W - 10, GRID_ROW)
    lb:SetPoint("TOPLEFT", 12, y)
    lb.text = Kit.Text(lb, "label", "text.primary")
    lb.text:SetPoint("LEFT")
    lb.text:SetText(labelOf(r))
    lb:SetScript("OnClick", function() Model.Commit(row.key, Widgets.GridFlip(def, Schema:Get(row.key), idOf(r), nil)) end)
    if ri > 1 then
      local line = Kit.Divider(f)
      line:SetPoint("TOPLEFT", 8, y + 1)
      line:SetPoint("RIGHT", f, "LEFT", LABEL_W + #colsL * COL_W, 0)
    end
    for ci, col in ipairs(colsL) do
      local rid, cid = idOf(r), idOf(col)
      local t = Kit.Toggle(f, function() Model.Commit(row.key, Widgets.GridFlip(def, Schema:Get(row.key), rid, cid)) end)
      t:SetPoint("TOP", f, "TOPLEFT", LABEL_W + (ci - 0.5) * COL_W, y - 5)
      f.cells[#f.cells + 1] = { t = t, r = rid, c = cid }
    end
  end
  local h = 6 + (#rowsL + 1) * GRID_ROW + 8
  f:SetHeight(h)
  row:SetHeight(50 + h + 12)
  row.control = f
  function row:Show_(v)
    for _, cell in ipairs(f.cells) do
      local line = v[cell.r]
      local on = line and line[cell.c]
      if on == nil then on = def.cellDefault == true end
      cell.t:SetValue_(on)
    end
  end
end

-- Snapshot copy helper for views that edit a value in steps.
Widgets.Copy = Copy
