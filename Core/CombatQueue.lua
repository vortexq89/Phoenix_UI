local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- CombatQueue: the only place protected work waits for combat to end.
-- Defer(key, fn) runs fn now when out of combat; in combat it stores fn under
-- key (a newer fn replaces an older one with the same key) and drains the
-- queue in first-queued order at PLAYER_REGEN_ENABLED. The event is registered
-- only while something is queued.
local CQ = { queue = {}, order = {} }
PUI.CombatQueue = CQ

local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Core")
local run = securecallfunction

-- Overridable by tests; defaults to the engine's lockdown flag.
CQ.InCombat = InCombatLockdown

function CQ.Defer(key, fn)
  assert(type(key) == "string" and key ~= "", "CombatQueue.Defer needs a key")
  assert(type(fn) == "function", "CombatQueue.Defer needs a function")
  if not CQ.InCombat() then
    run(fn)
    return true
  end
  if CQ.queue[key] == nil then CQ.order[#CQ.order + 1] = key end
  CQ.queue[key] = fn
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  return false
end

function CQ.Pending()
  return #CQ.order
end

function CQ.Drain()
  local order, queue = CQ.order, CQ.queue
  CQ.order, CQ.queue = {}, {}
  frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for i = 1, #order do run(queue[order[i]]) end
  return #order
end

frame:SetScript("OnEvent", function()
  if not CQ.InCombat() then CQ.Drain() end
end)
