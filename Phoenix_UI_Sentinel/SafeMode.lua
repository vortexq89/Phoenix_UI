local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- SafeMode: a module that threw more than sentinel.safeModeThreshold errors in
-- the previous session is disabled at this load (when sentinel.safeMode is on)
-- and stays off until the player re-enables it from the notice or the panel.
local S = PUI.Sentinel
local SafeMode = {}
S.SafeMode = SafeMode

local NEVER = { Core = true, Sentinel = true, Tests = true }

-- Decide from the previous session's counts; returns the newly safe-moded names.
function SafeMode:Evaluate(counts, threshold)
  local hit = {}
  for module, n in pairs(counts or {}) do
    if not NEVER[module] and n > threshold then hit[#hit + 1] = module end
  end
  table.sort(hit)
  return hit
end

-- Phoenix has no safe mode (decision 2026-10-26: errors are never hidden and
-- modules are never turned off for you). Anything an older build put in safe
-- mode is released at load; Evaluate stays for the diagnostics readout.
function SafeMode:ApplyAtLoad()
  local db = S.db
  if not S.safeModeEnabled then
    for module in pairs(db.safeModed) do db.safeModed[module] = nil; PUI.Kernel:SetSafeMode(module, false) end
    return
  end
  if S.safeModeEnabled then
    local hit = self:Evaluate(db.sessionErrors[db.session - 1], S.safeModeThreshold or 5)
    for i = 1, #hit do db.safeModed[hit[i]] = (db.sessionErrors[db.session - 1] or {})[hit[i]] or true end
  end
  for module in pairs(db.safeModed) do
    PUI.Kernel:SetSafeMode(module, true, "errors in previous session")
  end
  if next(db.safeModed) then
    PUI.Kernel:On("LOGIN", function() if S.Toast then S.Toast:SafeModeNotice(db.safeModed) end end)
  end
end

function SafeMode:Release(module)
  S.db.safeModed[module] = nil
  PUI.Kernel:SetSafeMode(module, false)
end
