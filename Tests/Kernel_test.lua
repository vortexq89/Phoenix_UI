local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
local Tests, Kernel = PUI.Tests, PUI.Kernel

local function tempModule(t, name, spec)
  local mod = PUI:RegisterModule(name, spec)
  t:cleanup(function()
    Kernel:Unregister(name)
    PUI.DB:SetRaw(Kernel.ModuleSettingKey(name), nil)
  end)
  return mod
end

Tests:Add("Kernel", "modules enable in registration order at login", function(t)
  local order = {}
  local wasLoggedIn = Kernel.loggedIn
  Kernel.loggedIn = false
  t:cleanup(function() Kernel.loggedIn = wasLoggedIn end)
  for _, n in ipairs({ "PUITest_A", "PUITest_B", "PUITest_C" }) do
    tempModule(t, n, { enabledByDefault = true, onEnable = function(m) order[#order + 1] = m.name end })
  end
  t:eq(#order, 0, "nothing enables before login")
  Kernel.loggedIn = true
  Kernel:EvaluateAll()
  t:eq(table.concat(order, ","), "PUITest_A,PUITest_B,PUITest_C", "order")
end)

Tests:Add("Kernel", "a module registered after login is deferred one frame", function(t)
  t:ok(Kernel.loggedIn, "suite runs after login")
  local mod = tempModule(t, "PUITest_Late", { enabledByDefault = true })
  t:eq(mod.enabled, false, "not enabled in the same frame")
  return function(t2) t2:eq(mod.enabled, true, "enabled one frame later") end
end)

Tests:Add("Kernel", "a disabled module registers nothing", function(t)
  local mod = tempModule(t, "PUITest_Off", {
    enabledByDefault = false,
    onEnable = function(m)
      m:RegisterEvent("PLAYER_TARGET_CHANGED", function() end)
      PUI.Ticker:Register("test.off", 1, function() end, m.name)
    end,
  })
  Kernel:Evaluate("PUITest_Off")
  t:eq(mod.enabled, false, "stays disabled")
  t:eq(mod:RegisteredEventCount(), 0, "no handlers")
  t:eq(mod.frame:IsEventRegistered("PLAYER_TARGET_CHANGED"), false, "no events on its frame")
  t:eq(PUI.Ticker:IsRegistered("test.off"), false, "no tickers")
  t:throws(function() mod:RegisterEvent("PLAYER_TARGET_CHANGED", function() end) end, "RegisterEvent refused while disabled")
end)

Tests:Add("Kernel", "disabling a module live removes its events and tickers", function(t)
  local mod = tempModule(t, "PUITest_Live", {
    enabledByDefault = true,
    onEnable = function(m)
      m:RegisterEvent("PLAYER_TARGET_CHANGED", function() end)
      PUI.Ticker:Register("test.live", 1, function() end, m.name)
    end,
  })
  Kernel:Evaluate("PUITest_Live")
  t:eq(mod.enabled, true, "enabled")
  PUI.Schema:Set(Kernel.ModuleSettingKey("PUITest_Live"), false)
  t:eq(mod.enabled, false, "disabled by the setting without reload")
  t:eq(mod:RegisteredEventCount(), 0, "handlers gone")
  t:eq(PUI.Ticker:IsRegistered("test.live"), false, "ticker gone")
end)

Tests:Add("Kernel", "loadCondition gates enabling", function(t)
  local allow = false
  local mod = tempModule(t, "PUITest_Cond", { enabledByDefault = true, loadCondition = function() return allow end })
  Kernel:Evaluate("PUITest_Cond")
  t:eq(mod.enabled, false, "condition false")
  allow = true
  Kernel:EvaluateAll()
  t:eq(mod.enabled, true, "condition true")
end)
