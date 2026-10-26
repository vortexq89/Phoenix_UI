local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Heartbeat: one compact health record per session, written at logout.
local S = PUI.Sentinel
local Heartbeat = {}
S.Heartbeat = Heartbeat

local MAX_KEPT = 20
local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Sentinel")

function Heartbeat:Build()
  local enabled = {}
  for i = 1, #PUI.Kernel.order do
    local name = PUI.Kernel.order[i]
    if PUI.Modules[name].enabled then enabled[#enabled + 1] = name end
  end
  local errors = 0
  for _, n in pairs(S.db.sessionErrors[S.db.session] or {}) do errors = errors + n end
  return {
    version = S:Version(), build = PUI.BUILD, interface = PUI.TOC, track = S:Track(),
    forever = PUI.IS_FOREVER, modules = enabled, errors = errors, zeroError = errors == 0,
    cpu = S.Perf:Averages(), sessionSeconds = math.floor(GetTime() - S.startTime),
    session = S.db.session, at = time(),
  }
end

function Heartbeat:Write()
  local list = S.db.heartbeats
  list[#list + 1] = self:Build()
  while #list > MAX_KEPT do table.remove(list, 1) end
end

function Heartbeat:Start()
  frame:RegisterEvent("PLAYER_LOGOUT")
end

frame:SetScript("OnEvent", function() Heartbeat:Write() end)
