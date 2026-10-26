local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Settings schema registry. Every user-facing setting is one entry with
-- default, label, tooltip, mode and a live apply(value). The options renderer
-- (Phoenix_UI_Options) and Sentinel's integrity check both read this registry.
-- type "layout" holds a table (Studio positions); it is always hidden from the
-- renderer and from /pui list, and is stored as a copy.
local Schema = { defs = {}, keys = {} }
PUI.Schema = Schema

local MODES = { simple = true, advanced = true }
-- Widget types (one schema for every module and plugin):
--   toggle, range (slider + typed input), select (dropdown / segmented / media
--   picker via def.preview), text, keybind ("" or "CTRL-SHIFT-K"), color
--   ({ r, g, b, a } 0..1), anchor ({ point, relPoint, x, y }), list (array of
--   strings, def.maxItems), grid ({ [row] = { [column] = bool } } over
--   def.rows / def.columns, e.g. per-content switches), layout (hidden table).
local TYPES = { toggle = "boolean", range = "number", select = "string", text = "string", layout = "table",
  keybind = "string", color = "table", anchor = "table", list = "table", grid = "table" }
local TABLE_TYPES = { layout = true, color = true, anchor = true, list = true, grid = true }
Schema.TYPES, Schema.TABLE_TYPES = TYPES, TABLE_TYPES
local POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }
Schema.POINTS = POINTS
local function unit(v) return type(v) == "number" and v == v and v >= 0 and v <= 1 end
local function ids(list)
  if type(list) == "function" then list = list() end
  local out = {}
  for i = 1, #(list or {}) do local e = list[i]; out[i] = type(e) == "table" and e.id or e end
  return out
end
Schema.Ids = ids

local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end
Schema.Copy = copy

local function sortKeys()
  local list = {}
  for k in pairs(Schema.defs) do list[#list + 1] = k end
  table.sort(list)
  Schema.keys = list
end

function Schema:Register(key, def)
  assert(type(key) == "string" and key ~= "", "schema key required")
  assert(not self.defs[key], "schema key '" .. key .. "' registered twice")
  assert(TYPES[def.type], key .. ": unknown type " .. tostring(def.type))
  assert(def.default ~= nil, key .. ": default required")
  assert(type(def.label) == "string", key .. ": label required")
  assert(type(def.tooltip) == "string", key .. ": tooltip required")
  assert(MODES[def.mode], key .. ": mode must be simple or advanced")
  assert(type(def.apply) == "function", key .. ": apply(value) required")
  assert(self:Validate(def, def.default), key .. ": default fails validation")
  def.key = key
  if def.type == "layout" then def.hidden = true end
  self.defs[key] = def
  sortKeys()
end

function Schema:UnregisterOwner(owner)
  for k, def in pairs(self.defs) do
    if def.owner == owner then self.defs[k] = nil end
  end
  sortKeys()
end

function Schema:Def(key) return self.defs[key] end

-- Returns true, or false plus a reason.
function Schema:Validate(def, value)
  if type(value) ~= TYPES[def.type] then return false, "expected " .. TYPES[def.type] end
  if def.type == "range" then
    if value ~= value then return false, "not a number" end
    if def.min and value < def.min then return false, "below " .. def.min end
    if def.max and value > def.max then return false, "above " .. def.max end
  elseif def.type == "keybind" then
    if value ~= "" and not value:match("^[%u%d%-]+$") then return false, "not a key name" end
  elseif def.type == "color" then
    if not (unit(value.r) and unit(value.g) and unit(value.b)) then return false, "r, g and b must be 0..1" end
    if value.a ~= nil and not unit(value.a) then return false, "alpha must be 0..1" end
  elseif def.type == "anchor" then
    if not (POINTS[value.point] and POINTS[value.relPoint or value.point]) then return false, "unknown anchor point" end
    if type(value.x) ~= "number" or type(value.y) ~= "number" then return false, "x and y must be numbers" end
  elseif def.type == "list" then
    local n = 0
    for k in pairs(value) do n = n + 1; if type(k) ~= "number" then return false, "list keys must be 1..n" end end
    for i = 1, n do if type(value[i]) ~= "string" then return false, "list items must be text" end end
    if def.maxItems and n > def.maxItems then return false, "more than " .. def.maxItems .. " items" end
  elseif def.type == "grid" then
    local rows, cols = {}, {}
    for _, r in ipairs(ids(def.rows)) do rows[r] = true end
    for _, c in ipairs(ids(def.columns)) do cols[c] = true end
    for r, line in pairs(value) do
      if not rows[r] or type(line) ~= "table" then return false, "unknown row " .. tostring(r) end
      for c, on in pairs(line) do
        if not cols[c] or type(on) ~= "boolean" then return false, "bad cell " .. tostring(r) .. "/" .. tostring(c) end
      end
    end
  elseif def.type == "select" then
    local choices = type(def.choices) == "function" and def.choices() or def.choices
    if choices then
      local found = false
      for i = 1, #choices do if choices[i] == value then found = true end end
      if not found then return false, "not one of the choices" end
    end
  end
  return true
end

function Schema:Get(key)
  local def = self.defs[key]
  if not def then error("unknown setting '" .. tostring(key) .. "'", 2) end
  if def.get then return def.get() end
  local v = PUI.DB:GetRaw(key)
  if v == nil then v = def.default end
  if TABLE_TYPES[def.type] then return copy(v) end
  return v
end

-- Live set: validate, store, apply in place, log for Sentinel.
function Schema:Set(key, value)
  local def = self.defs[key]
  if not def then error("unknown setting '" .. tostring(key) .. "'", 2) end
  local ok, why = self:Validate(def, value)
  if not ok then error("invalid value for '" .. key .. "': " .. why, 2) end
  if TABLE_TYPES[def.type] then value = copy(value) end
  if def.set then
    def.set(value)
  elseif PUI.DB.DeepEqual(value, def.default) and not (PUI.DB.base and PUI.DB.base[key] ~= nil) then
    PUI.DB:SetRaw(key, nil)
  else
    PUI.DB:SetRaw(key, value)
  end
  def.apply(TABLE_TYPES[def.type] and copy(value) or value)
  PUI:Log("setting", key, TABLE_TYPES[def.type] and ("<" .. def.type .. ">") or value)
  PUI.Kernel:Fire("SETTING_CHANGED", key, value)
end

function Schema:ApplyAll()
  for i = 1, #self.keys do
    local def = self.defs[self.keys[i]]
    if not def.get then def.apply(self:Get(def.key)) end -- char-scoped keys (core.profile) apply on change only
  end
end

-- Values of all keys owned by a module (incident context).
function Schema:Snapshot(owner)
  local out = {}
  for i = 1, #self.keys do
    local def = self.defs[self.keys[i]]
    if (owner == nil or def.owner == owner) and def.type ~= "layout" then out[def.key] = self:Get(def.key) end
  end
  return out
end

-- Resets one key to its default (live). Returns false for unknown keys.
function Schema:Reset(key)
  local def = self.defs[key]
  if not def or def.get then return false end
  self:Set(key, copy(def.default))
  return true
end

function Schema:IsDefault(key)
  local def = self.defs[key]
  return def ~= nil and PUI.DB.DeepEqual(self:Get(key), def.default)
end

-- Grid helper: is cell (row, column) on? Missing cells read as def.cellDefault (false).
function Schema:Cell(key, row, column)
  local v = self:Get(key)
  local line = v[row]
  local on = line and line[column]
  if on == nil then return self.defs[key].cellDefault == true end
  return on
end
