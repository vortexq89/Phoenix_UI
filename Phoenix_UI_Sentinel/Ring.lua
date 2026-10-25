local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Ring: copies of the hook's event ring attached to incidents, plus the last
-- API family each module touched (used by SecretTag).
local S = PUI.Sentinel
local Ring = {}
S.Ring = Ring

function Ring:Snapshot()
  local events = PUI.SentinelHook.RingSnapshot()
  local limit = S.testerMode and 200 or 50
  if #events > limit then
    local trimmed = {}
    for i = #events - limit + 1, #events do trimmed[#trimmed + 1] = events[i] end
    events = trimmed
  end
  return events
end

-- Modules call PUI:Log("api", "C_UnitAuras") before touching a secret-capable family.
function Ring:LastApiFamily(events)
  for i = #events, 1, -1 do
    if events[i].kind == "api" then return events[i].key end
  end
  return nil
end

-- Last few setting keys changed (repro hints / perf hot keys).
function Ring:RecentSettings(events, n)
  local out, seen = {}, {}
  for i = #events, 1, -1 do
    local e = events[i]
    if e.kind == "setting" and not seen[e.key] then
      seen[e.key] = true
      out[#out + 1] = e.key
      if #out >= (n or 5) then break end
    end
  end
  return out
end
