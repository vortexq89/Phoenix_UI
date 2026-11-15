local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Overrides (plan 1.8, 1.9, F2, G9): per-specialization and per-condition
-- values for any schema key declared `overridable = true`, stored inside the
-- active profile and resolved at read time:
--     condition  >  specialization  >  profile (and its base)  >  default
-- Nothing is swapped in or harvested from live values, so a failed transition
-- can never lose data. "Editing as" sessions route Schema:Set into one layer;
-- the options page shows provenance (Schema:Source) and a promote button.
--   profile["@spec"][specIndex][key] = value
--   profile["@cond"][condition][key]  = value
local Overrides = { editing = nil, last = {} }
PUI.Overrides = Overrides
local DB, Schema = PUI.DB, PUI.Schema

-- "keybind" is the layer key (Core/KeyLayer.lua): while it is held or toggled
-- on, its values win over every other layer.
Overrides.CONDITIONS = { "arena", "bg", "raid", "party", "solo", "keybind" } -- priority order (keybind is checked first)
Overrides.CONDITION_LABELS = { arena = "Arena", bg = "Battleground", raid = "Raid group", party = "Party", solo = "Solo",
  keybind = "While my layer key is active" }
Overrides.keyLayer = false
local LAYER = { spec = "@spec", cond = "@cond" }
local VALID_COND = {}
for _, c in ipairs(Overrides.CONDITIONS) do VALID_COND[c] = true end

-- Current context (overridable by tests).
function Overrides.Context()
  local _, instanceType = GetInstanceInfo()
  local cond
  if instanceType == "arena" then cond = "arena"
  elseif instanceType == "pvp" then cond = "bg"
  else
    local n = GetNumGroupMembers() or 0
    cond = n > 5 and "raid" or (n > 0 and "party" or "solo")
  end
  return C_SpecializationInfo.GetSpecialization() or 0, cond
end

local function layerTable(profile, layer, id, create)
  if not profile then return nil end
  local root = profile[LAYER[layer]]
  if not root then
    if not create then return nil end
    root = {}
    profile[LAYER[layer]] = root
  end
  local t = root[id]
  if not t and create then t = {}; root[id] = t end
  return t
end

local function checkLayer(layer, id)
  assert(LAYER[layer], "override layer must be 'spec' or 'cond'")
  if layer == "cond" then assert(VALID_COND[id], "unknown condition " .. tostring(id))
  else assert(type(id) == "number" and id >= 1, "spec override needs a specialization index") end
end

-- Lookup(key) -> value, source  (nil when no override applies). Pure (G18).
function Overrides:Lookup(key)
  local spec, cond = self.Context()
  if self.keyLayer then
    for _, prof in ipairs({ DB.profile, DB.base }) do
      local t = layerTable(prof, "cond", "keybind")
      if t and t[key] ~= nil then return t[key], "cond:keybind" end
    end
  end
  for _, prof in ipairs({ DB.profile, DB.base }) do
    local t = layerTable(prof, "cond", cond)
    if t and t[key] ~= nil then return t[key], "cond:" .. cond end
  end
  for _, prof in ipairs({ DB.profile, DB.base }) do
    local t = layerTable(prof, "spec", spec)
    if t and t[key] ~= nil then return t[key], "spec:" .. spec end
  end
  return nil
end

function Overrides:Get(layer, id, key)
  checkLayer(layer, id)
  local t = layerTable(DB.profile, layer, id)
  local v = t and t[key]
  return type(v) == "table" and Schema.Copy(v) or v
end

-- Validate, then publish (G26). Applies live when the layer is active now.
function Overrides:Set(layer, id, key, value)
  checkLayer(layer, id)
  local def = Schema:Def(key)
  if not (def and def.overridable) then return false, "setting cannot be overridden" end
  local ok, why = Schema:Validate(def, value)
  if not ok then return false, why end
  layerTable(DB.profile, layer, id, true)[key] = Schema.TABLE_TYPES[def.type] and Schema.Copy(value) or value
  self:Arm()
  self:Recompose(key)
  PUI:Log("override.set", layer .. ":" .. tostring(id), key)
  return true
end

function Overrides:Clear(layer, id, key)
  checkLayer(layer, id)
  local t = layerTable(DB.profile, layer, id)
  if not (t and t[key] ~= nil) then return false end
  t[key] = nil
  if next(t) == nil then DB.profile[LAYER[layer]][id] = nil end
  if next(DB.profile[LAYER[layer]]) == nil then DB.profile[LAYER[layer]] = nil end
  self:Recompose(key)
  return true
end

-- Promote: the override becomes the profile value and the override goes away.
function Overrides:Promote(layer, id, key)
  local v = self:Get(layer, id, key)
  if v == nil then return false end
  local editing = self.editing
  self.editing = nil
  self:Clear(layer, id, key)
  Schema:Set(key, v)
  self.editing = editing
  return true
end

-- List() -> { { layer, id, key, value } ... } sorted, for the overrides page.
function Overrides:List()
  local out = {}
  for layer, field in pairs(LAYER) do
    for id, t in pairs(DB.profile and DB.profile[field] or {}) do
      for key, value in pairs(t) do out[#out + 1] = { layer = layer, id = id, key = key, value = value } end
    end
  end
  table.sort(out, function(a, b)
    if a.layer ~= b.layer then return a.layer < b.layer end
    if a.id ~= b.id then return tostring(a.id) < tostring(b.id) end
    return a.key < b.key
  end)
  return out
end

function Overrides:HasAny()
  local p = DB.profile
  return p ~= nil and (p["@spec"] ~= nil or p["@cond"] ~= nil) or (DB.base ~= nil and (DB.base["@spec"] ~= nil or DB.base["@cond"] ~= nil))
end

------------------------------------------------------------------------------
-- "Editing as": Schema:Set on an overridable key writes into this layer.
function Overrides:EditAs(layer, id)
  if layer == nil then self.editing = nil; PUI.Kernel:Fire("OVERRIDES_EDITING", nil); return end
  checkLayer(layer, id)
  self.editing = { layer = layer, id = id }
  PUI.Kernel:Fire("OVERRIDES_EDITING", layer, id)
end

function Overrides:Editing() local e = self.editing; return e and e.layer, e and e.id end

------------------------------------------------------------------------------
-- Recompose: re-apply keys whose effective value changed. Protected keys
-- (def.protected) are applied out of combat through the CombatQueue.
function Overrides:Recompose(onlyKey)
  local keys = {}
  if onlyKey then keys[1] = onlyKey
  else
    for k in pairs(self.last) do keys[#keys + 1] = k end
    for _, e in ipairs(self:List()) do if not self.last[e.key] then keys[#keys + 1] = e.key end end
  end
  local n = 0
  for _, key in ipairs(keys) do
    local def = Schema:Def(key)
    if def then
      local v = Schema:Get(key)
      if not DB.DeepEqual(v, self.last[key]) then
        self.last[key] = v
        n = n + 1
        if def.protected then PUI.CombatQueue.Defer("override." .. key, function() def.apply(Schema:Get(key)) end)
        else securecallfunction(def.apply, v) end
      end
    end
  end
  return n
end

local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
local EVENTS = { "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }
frame:SetScript("OnEvent", function()
  PUI.Ticker:Register("overrides.recompose", 0, function()
    PUI.Ticker:Unregister("overrides.recompose")
    Overrides:Recompose()
  end, "Core")
end)

-- Events only while overrides exist (G21).
function Overrides:Arm()
  local want = self:HasAny()
  if want == self.armed then return end
  self.armed = want
  for i = 1, #EVENTS do
    if want then frame:RegisterEvent(EVENTS[i]) else frame:UnregisterEvent(EVENTS[i]) end
  end
end

PUI.Kernel:On("DB_READY", function() Overrides:Arm() end)
PUI.Kernel:On("SETTING_CHANGED", function(key) if key == "core.profile" then Overrides.last = {}; Overrides:Arm() end end)
