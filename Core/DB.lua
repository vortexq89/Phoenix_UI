local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- DB: the single SavedVariable PhoenixUIDB.
--   profiles[name] = { [schemaKey] = value }   (only values that differ from defaults)
--   chars["Name-Realm"] = profileName
--   migrations[id] = true                      (stamped on success; genesis-stamped on fresh install)
-- No timestamps or metadata keys. Defaults are never copied in; values equal to
-- the default are stripped at logout.
local DB = { migrations = {}, migrationOrder = {} }
PUI.DB = DB

local DEFAULT_PROFILE = "Default"
local runMigration = securecallfunction

function DB:CharKey()
  if not self.charKey then
    self.charKey = (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
  end
  return self.charKey
end

-- Migrations: id sorts lexically (e.g. "0002_rename_x"); fn(db) must return true.
function DB:RegisterMigration(id, fn)
  assert(not self.migrations[id], "migration " .. id .. " registered twice")
  self.migrations[id] = fn
  self.migrationOrder[#self.migrationOrder + 1] = id
  table.sort(self.migrationOrder)
end

function DB:RunMigrations()
  local sv = self.sv
  local ran = 0
  for i = 1, #self.migrationOrder do
    local id = self.migrationOrder[i]
    if not sv.migrations[id] then
      if runMigration(self.migrations[id], sv) == true then
        sv.migrations[id] = true
        ran = ran + 1
        PUI:Log("db.migration", id)
      else
        PUI:Log("db.migration.failed", id)
      end
    end
  end
  return ran
end

function DB:Init(svOverride)
  local sv = svOverride or _G.PhoenixUIDB
  if type(sv) ~= "table" then sv = {} end
  local fresh = next(sv) == nil
  sv.profiles = sv.profiles or {}
  sv.chars = sv.chars or {}
  sv.migrations = sv.migrations or {}
  if fresh then
    for i = 1, #self.migrationOrder do sv.migrations[self.migrationOrder[i]] = true end -- genesis stamp
  end
  if not svOverride then _G.PhoenixUIDB = sv end
  self.sv = sv
  self.loadIssue = select(2, PUI.ClientGate.CheckSerializable(sv, "PhoenixUIDB"))
  if not fresh then self:RunMigrations() end
  local name = sv.chars[self:CharKey()] or DEFAULT_PROFILE
  sv.chars[self:CharKey()] = name
  sv.profiles[name] = sv.profiles[name] or {}
  self.profileName = name
  self.profile = sv.profiles[name]
  return fresh
end

function DB:GetRaw(key) return self.profile and self.profile[key] end

function DB:SetRaw(key, value)
  self.profile[key] = value
end

function DB:GetProfileName() return self.profileName end

function DB:ProfileNames()
  local list = {}
  for name in pairs(self.sv.profiles) do list[#list + 1] = name end
  table.sort(list)
  return list
end

-- Live profile switch: every schema entry re-applies its value.
function DB:SetProfile(name)
  assert(type(name) == "string" and name ~= "", "profile name required")
  local sv = self.sv
  sv.profiles[name] = sv.profiles[name] or {}
  sv.chars[self:CharKey()] = name
  self.profileName = name
  self.profile = sv.profiles[name]
  PUI:Log("profile.switch", name)
end

local function deepEqual(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
DB.DeepEqual = deepEqual

-- Remove every stored value equal to its schema default (all profiles).
function DB:StripDefaults()
  local defs = PUI.Schema.defs
  for _, profile in pairs(self.sv.profiles) do
    for key, value in pairs(profile) do
      local def = defs[key]
      if def and not def.get and deepEqual(value, def.default) then profile[key] = nil end
    end
  end
end

function DB:Shutdown()
  self:StripDefaults()
  local ok, where = PUI.ClientGate.CheckSerializable(self.sv, "PhoenixUIDB")
  if not ok then PUI:Log("db.unserializable", where) end
end

PUI.Schema:Register("core.profile", {
  type = "select",
  default = DEFAULT_PROFILE,
  label = "Profile",
  tooltip = "Settings profile used by this character. Switching applies every setting immediately.",
  mode = "simple",
  owner = "Core",
  get = function() return DB.profileName or DEFAULT_PROFILE end,
  set = function(name) DB:SetProfile(name) end,
  apply = function()
    if PUI.Kernel.dbReady then
      for i = 1, #PUI.Schema.keys do
        local key = PUI.Schema.keys[i]
        if key ~= "core.profile" then PUI.Schema.defs[key].apply(PUI.Schema:Get(key)) end
      end
      PUI.Kernel:EvaluateAll()
    end
  end,
})
