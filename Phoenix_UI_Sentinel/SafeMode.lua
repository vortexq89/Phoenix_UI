local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Legacy safe-mode cleanup. Phoenix has no safe mode (decision 2026-10-26:
-- errors are never hidden and modules are never turned off after errors).
-- Anything an older build put in safe mode is released at load, and Release
-- stays for `/pui sentinel enable <module>` (also lifts an API-drift stop).
local S = PUI.Sentinel
local SafeMode = {}
S.SafeMode = SafeMode

function SafeMode:ApplyAtLoad()
  local db = S.db
  for module in pairs(db.safeModed) do
    db.safeModed[module] = nil
    PUI.Kernel:SetSafeMode(module, false)
  end
end

function SafeMode:Release(module)
  S.db.safeModed[module] = nil
  PUI.Kernel:SetSafeMode(module, false)
end
