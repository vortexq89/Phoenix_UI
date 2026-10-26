local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Budget: CPU budgets per owner in milliseconds of addon CPU per second
-- (PUI_V2 Section 11). Sentinel's perf sampler compares samples against these.
local Budget = { limits = {}, DEFAULT_MS_PER_SEC = 0.3, STREAK = 3 }
PUI.Budget = Budget

function Budget:Set(owner, msPerSecond)
  assert(type(msPerSecond) == "number" and msPerSecond > 0, "budget must be a positive number")
  self.limits[owner] = msPerSecond
end

function Budget:Get(owner)
  return self.limits[owner] or self.DEFAULT_MS_PER_SEC
end

-- msPerTick: the profiler's average milliseconds per frame; fps: frames per second.
function Budget:IsOver(owner, msPerTick, fps)
  return msPerTick * fps > self:Get(owner)
end
