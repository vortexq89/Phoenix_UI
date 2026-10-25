local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Perf: CPU sampler on the Ticker registry (5 s, 1 s in tester mode), only
-- while sentinel.perfSampler is on. Three consecutive samples over budget
-- raise a perf incident with the most recently changed setting keys.
local S = PUI.Sentinel
local Perf = { streak = {}, sums = {}, samples = 0 }
S.Perf = Perf

local KEY = "sentinel.perf"
local ADDONS = { Core = PUI.ADDON_NAME, Sentinel = "Phoenix_UI_Sentinel" }

function Perf:Refresh()
  local want = S.perfEnabled and C_AddOnProfiler ~= nil and C_AddOnProfiler.IsEnabled()
  PUI.Ticker:Unregister(KEY)
  if want then
    PUI.Ticker:Register(KEY, S.testerMode and 1 or 5, function() Perf:Sample() end, "Sentinel")
  end
end

-- readings: optional { owner = msPerTick } for tests; fps optional.
function Perf:Sample(readings, fps)
  fps = fps or GetFramerate()
  local metric = not readings and Enum.AddOnProfilerMetric.RecentAverageTime
  self.samples = self.samples + 1
  local raised = {}
  for owner, addon in pairs(ADDONS) do
    local ms = readings and readings[owner] or (not readings and C_AddOnProfiler.GetAddOnMetric(addon, metric))
    if type(ms) == "number" and not PUI.Secret.IsSecret(ms) then
      self.sums[owner] = (self.sums[owner] or 0) + ms
      if PUI.Budget:IsOver(owner, ms, fps) then
        self.streak[owner] = (self.streak[owner] or 0) + 1
        if self.streak[owner] == PUI.Budget.STREAK then
          local hot = S.Ring:RecentSettings(S.Ring:Snapshot(), 5)
          raised[#raised + 1] = S.Capture:Report("perf", owner, {
            message = owner .. " over CPU budget for " .. PUI.Budget.STREAK .. " samples",
            extra = { msPerSecond = ms * fps, budget = PUI.Budget:Get(owner), hotKeys = hot },
          })
        end
      else
        self.streak[owner] = 0
      end
    end
  end
  return raised
end

function Perf:Averages()
  if self.samples == 0 then return nil end
  local out = {}
  for owner, sum in pairs(self.sums) do out[owner] = sum / self.samples end
  return out
end
