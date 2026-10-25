local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Kernel: namespaces, module registry and lifecycle (PUI_V2 5.1).
-- ADDON_LOADED -> DB + migrations; PLAYER_LOGIN -> modules enable in
-- registration order; a module registered after login is evaluated one frame
-- later. A disabled module owns only its inert event frame.
local ADDON_NAME = PUI.ADDON_NAME

PUI.Modules = {}
PUI.API = PUI.API or {}

local Kernel = { order = {}, loggedIn = false, dbReady = false, safe = {}, signals = {} }
PUI.Kernel = Kernel

local owned = setmetatable({}, { __mode = "k" }) -- frame -> owner tag
Kernel.owned = owned

local callModule = securecallfunction -- errors reach the error handler (Sentinel); the loop continues

-- Internal signals (DB_READY, MODULE_ENABLED, ...). Listeners are Phoenix code.
function Kernel:On(signal, fn)
  local list = self.signals[signal]
  if not list then list = {}; self.signals[signal] = list end
  list[#list + 1] = fn
end

function Kernel:Fire(signal, ...)
  local list = self.signals[signal]
  if not list then return end
  for i = 1, #list do callModule(list[i], ...) end
end

-- Event ring for Sentinel (module enable/disable, setting changes, ...).
function PUI:Log(kind, key, value)
  local hook = PUI.SentinelHook
  if hook then hook.RecordEvent(kind, key, value) end
end

-- Frame factory that tags the owner so CPU samples, errors and the stray
-- OnUpdate audit can attribute frames to a module.
function PUI:CreateFrame(frameType, name, parent, template, owner)
  local f = CreateFrame(frameType, name, parent, template)
  owned[f] = owner or "Core"
  return f
end

-- Module object ---------------------------------------------------------
local Module = {}
Module.__index = Module

local function moduleOnEvent(frame, event, ...)
  local mod = Kernel.byFrame[frame]
  local handler = mod and mod.handlers[event]
  if handler then handler(mod, event, ...) end
end
Kernel.byFrame = setmetatable({}, { __mode = "k" })

function Module:RegisterEvent(event, handler)
  if not self.enabled then
    error("Phoenix module '" .. self.name .. "' registered " .. event .. " while disabled (R-ZERO)", 2)
  end
  self.handlers[event] = handler
  self.frame:RegisterEvent(event)
end

function Module:RegisterUnitEvent(event, handler, unit1, unit2)
  if not self.enabled then
    error("Phoenix module '" .. self.name .. "' registered " .. event .. " while disabled (R-ZERO)", 2)
  end
  self.handlers[event] = handler
  self.frame:RegisterUnitEvent(event, unit1, unit2)
end

function Module:UnregisterEvent(event)
  self.handlers[event] = nil
  self.frame:UnregisterEvent(event)
end

function Module:IsEnabled() return self.enabled end

function Module:RegisteredEventCount()
  local n = 0
  for _ in pairs(self.handlers) do n = n + 1 end
  return n
end

local function settingKey(name) return "module." .. name end
Kernel.ModuleSettingKey = settingKey

-- Registration ------------------------------------------------------------
-- spec = { enabledByDefault = bool, loadCondition = fn():bool, onEnable = fn(mod),
--          onDisable = fn(mod), schema = { [key] = def, ... }, label = string }
function PUI:RegisterModule(name, spec)
  assert(type(name) == "string" and name ~= "", "module name required")
  assert(not PUI.Modules[name], "module '" .. name .. "' already registered")
  spec = spec or {}
  local mod = setmetatable({
    name = name,
    spec = spec,
    enabled = false,
    handlers = {},
    frame = PUI:CreateFrame("Frame", nil, nil, nil, name), -- inert until enabled
  }, Module)
  mod.frame:SetScript("OnEvent", moduleOnEvent)
  Kernel.byFrame[mod.frame] = mod
  PUI.Modules[name] = mod
  Kernel.order[#Kernel.order + 1] = name

  local Schema = PUI.Schema
  Schema:Register(settingKey(name), {
    type = "toggle",
    default = spec.enabledByDefault == true,
    label = spec.label or name,
    tooltip = spec.tooltip or ("Enable the " .. name .. " module."),
    mode = "simple",
    owner = name,
    apply = function() Kernel:Evaluate(name) end,
  })
  if spec.schema then
    for key, def in pairs(spec.schema) do
      def.owner = def.owner or name
      Schema:Register(key, def)
    end
  end
  if spec.loadCondition then Kernel:WatchConditions() end
  PUI:Log("module.register", name)
  if Kernel.loggedIn then
    C_Timer.After(0, function() Kernel:Evaluate(name) end) -- late load: defer one frame
  end
  return mod
end

-- Test support: remove a module and its schema keys entirely.
function Kernel:Unregister(name)
  local mod = PUI.Modules[name]
  if not mod then return end
  if mod.enabled then self:Disable(mod) end
  PUI.Modules[name] = nil
  for i = #self.order, 1, -1 do
    if self.order[i] == name then table.remove(self.order, i) end
  end
  PUI.Schema:UnregisterOwner(name)
end

function Kernel:WantsEnabled(mod)
  if self.safe[mod.name] then return false end
  if not PUI.Schema:Get(settingKey(mod.name)) then return false end
  local cond = mod.spec.loadCondition
  if cond and not cond(mod) then return false end
  return true
end

function Kernel:Enable(mod)
  mod.enabled = true
  PUI:Log("module.enable", mod.name)
  if mod.spec.onEnable then callModule(mod.spec.onEnable, mod) end
  self:Fire("MODULE_ENABLED", mod.name)
end

function Kernel:Disable(mod)
  if mod.spec.onDisable then callModule(mod.spec.onDisable, mod) end
  mod.frame:UnregisterAllEvents()
  wipe(mod.handlers)
  if PUI.Ticker then PUI.Ticker:UnregisterOwner(mod.name) end
  mod.enabled = false
  PUI:Log("module.disable", mod.name)
  self:Fire("MODULE_DISABLED", mod.name)
end

function Kernel:Evaluate(name)
  local mod = PUI.Modules[name]
  if not mod or not self.loggedIn then return end
  local want = self:WantsEnabled(mod)
  if want and not mod.enabled then
    self:Enable(mod)
  elseif mod.enabled and not want then
    self:Disable(mod)
  end
end

function Kernel:EvaluateAll()
  for i = 1, #self.order do self:Evaluate(self.order[i]) end
end

-- Safe mode (set by Sentinel before login, cleared from its notice).
function Kernel:SetSafeMode(name, flag, reason)
  self.safe[name] = flag and (reason or true) or nil
  PUI:Log("module.safemode", name, flag and true or false)
  self:Evaluate(name)
end

-- loadCondition re-evaluation, registered only once a module needs it.
local condEvents = { "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }
function Kernel:WatchConditions()
  if self.watching then return end
  self.watching = true
  for i = 1, #condEvents do self.frame:RegisterEvent(condEvents[i]) end
  if not PUI.IS_FOREVER then self.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") end
end

-- Kernel events -------------------------------------------------------------
local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
Kernel.frame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON_NAME then return end
    PUI.DB:Init()
    Kernel.dbReady = true
    Kernel:Fire("DB_READY")
    PUI.Schema:ApplyAll()
  elseif event == "PLAYER_LOGIN" then
    Kernel.loggedIn = true
    Kernel:Fire("LOGIN")
    Kernel:EvaluateAll()
  elseif event == "PLAYER_LOGOUT" then
    Kernel:Fire("LOGOUT")
    PUI.DB:Shutdown()
  else
    Kernel:EvaluateAll() -- loadCondition events
  end
end)
