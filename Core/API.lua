local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Public API surface (PUI_V2 Section 10). Versioned and additive only: a
-- function, once published, keeps its name and arguments. Every registry is a
-- plain list that the owning module reads when it loads, so a plugin may
-- register before or after that module (load order never matters).
--   v1  RegisterSkin (Phase 5)
--   v2  RegisterPlugin, RegisterDataBlock, RegisterOracleProvider,
--       RegisterVaultRule, RegisterNicknameProvider (Phase 6)
PUI.API = PUI.API or {}
PUI.API_VERSION = 2
PUI.API.VERSION = PUI.API_VERSION

local API = PUI.API
local Reg = { plugins = {}, pluginOrder = {}, skins = {}, dataBlocks = {}, oracle = {}, vaultRules = {}, nicknames = {}, listeners = {} }
PUI.APIRegistry = Reg

-- Sidebar labels a plugin may not take (they belong to Phoenix pages).
local RESERVED = { phoenix = true, core = true, general = true, profiles = true, studio = true, sentinel = true, options = true }
Reg.RESERVED = RESERVED

local function id(value, what)
  if type(value) ~= "string" or not value:match("^[%w_%-%.]+$") then
    error("Phoenix API: " .. what .. " needs an id made of letters, digits, '_', '-' or '.'", 3)
  end
  return value
end

local function notify(kind, key)
  local list = Reg.listeners[kind]
  if list then for i = 1, #list do securecallfunction(list[i], key) end end
end

-- Modules call this to hear about registrations that arrive after they load.
function Reg.Listen(kind, fn)
  Reg.listeners[kind] = Reg.listeners[kind] or {}
  table.insert(Reg.listeners[kind], fn)
end

-- RegisterPlugin(id, { label = "Name", schema = { [key] = def, ... } })
-- Adds a sidebar section built from the plugin's own schema entries. Keys must
-- start with "plugin.<id>." so they never collide with Phoenix keys.
function API.RegisterPlugin(pluginId, spec)
  id(pluginId, "RegisterPlugin")
  assert(type(spec) == "table" and type(spec.label) == "string", "RegisterPlugin needs spec.label")
  if RESERVED[spec.label:lower()] or RESERVED[pluginId:lower()] then return false, "reserved label" end
  if Reg.plugins[pluginId] then return false, "already registered" end
  local prefix = "plugin." .. pluginId .. "."
  for key, def in pairs(spec.schema or {}) do
    if key:sub(1, #prefix) ~= prefix then return false, "keys must start with " .. prefix end
    def.owner = "plugin:" .. pluginId
    def.mode = def.mode or "advanced"
    PUI.Schema:Register(key, def)
  end
  Reg.plugins[pluginId] = { id = pluginId, label = spec.label, prefix = prefix }
  Reg.pluginOrder[#Reg.pluginOrder + 1] = pluginId
  notify("plugin", pluginId)
  return true
end

-- RegisterSkin(id, pack): pack = { frames = { "GlobalFrameName", ... }, parts = {...}, extra = fn }.
-- Idempotent; per-addon toggle lives in the Skins module.
function API.RegisterSkin(skinId, pack)
  id(skinId, "RegisterSkin")
  assert(type(pack) == "table" and type(pack.frames) == "table", "RegisterSkin needs pack.frames")
  Reg.skins[skinId] = pack
  notify("skin", skinId)
  return true
end

-- RegisterDataBlock(id, { label = "", text = fn() -> string }) for data bars.
function API.RegisterDataBlock(blockId, spec)
  id(blockId, "RegisterDataBlock")
  assert(type(spec) == "table" and type(spec.text) == "function", "RegisterDataBlock needs spec.text")
  spec.label = spec.label or blockId
  Reg.dataBlocks[blockId] = spec
  notify("dataBlock", blockId)
  return true
end

-- RegisterOracleProvider(id, fn(query) -> { { text = "", run = fn, icon = n }, ... })
-- Results from providers are never secure actions; they run insecure code.
function API.RegisterOracleProvider(providerId, fn)
  id(providerId, "RegisterOracleProvider")
  assert(type(fn) == "function", "RegisterOracleProvider needs a function")
  Reg.oracle[providerId] = fn
  notify("oracle", providerId)
  return true
end

-- RegisterVaultRule(id, { label = "", match = fn(itemInfo) -> bool }) for bag categories.
function API.RegisterVaultRule(ruleId, spec)
  id(ruleId, "RegisterVaultRule")
  assert(type(spec) == "table" and type(spec.match) == "function", "RegisterVaultRule needs spec.match")
  spec.label = spec.label or ruleId
  Reg.vaultRules[ruleId] = spec
  notify("vaultRule", ruleId)
  return true
end

-- RegisterNicknameProvider(id, fn(unitName) -> nickname or nil).
function API.RegisterNicknameProvider(providerId, fn)
  id(providerId, "RegisterNicknameProvider")
  assert(type(fn) == "function", "RegisterNicknameProvider needs a function")
  Reg.nicknames[providerId] = fn
  notify("nickname", providerId)
  return true
end

-- First provider that answers wins; providers run isolated.
function API.Nickname(name)
  if type(name) ~= "string" or PUI.Secret.IsSecret(name) then return nil end
  for _, fn in pairs(Reg.nicknames) do
    local out
    securecallfunction(function() out = fn(name) end)
    if type(out) == "string" and out ~= "" then return out end
  end
  return nil
end
