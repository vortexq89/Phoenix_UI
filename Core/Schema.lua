local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Settings schema registry. Every user-facing setting is one entry with
-- default, label, tooltip, mode and a live apply(value). The options renderer
-- (later phase) and Sentinel's integrity check both read this registry.
local Schema = { defs = {}, keys = {} }
PUI.Schema = Schema

local MODES = { simple = true, advanced = true }
local TYPES = { toggle = "boolean", range = "number", select = "string", text = "string" }

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
  if v == nil then return def.default end
  return v
end

-- Live set: validate, store, apply in place, log for Sentinel.
function Schema:Set(key, value)
  local def = self.defs[key]
  if not def then error("unknown setting '" .. tostring(key) .. "'", 2) end
  local ok, why = self:Validate(def, value)
  if not ok then error("invalid value for '" .. key .. "': " .. why, 2) end
  if def.set then
    def.set(value)
  elseif value == def.default then
    PUI.DB:SetRaw(key, nil)
  else
    PUI.DB:SetRaw(key, value)
  end
  def.apply(value)
  PUI:Log("setting", key, value)
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
    if owner == nil or def.owner == owner then out[def.key] = self:Get(def.key) end
  end
  return out
end
