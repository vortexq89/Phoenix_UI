local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Taint: ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN for Phoenix addons, and
-- the opt-in "taint log for this session" switch (restored at logout).
local S = PUI.Sentinel
local Taint = {}
S.Taint = Taint

local frame = PUI:CreateFrame("Frame", nil, nil, nil, "Sentinel")

local function isPhoenix(addon)
  return type(addon) == "string" and not PUI.Secret.IsSecret(addon) and addon:find("^Phoenix_UI") ~= nil
end

function Taint:OnAction(event, addon, func)
  if not isPhoenix(addon) then
    -- Another addon's blocked action: kept with its other errors (BugGrabber parity).
    if not PUI.SentinelHook.captureOthers then return end
    local name = (type(addon) == "string" and not PUI.Secret.IsSecret(addon)) and addon or "Unknown"
    local inc = S.Store:OnOther({ addon = name, message = event .. ": " .. PUI.Secret.ToText(func, 200), stack = debugstack(2), combat = InCombatLockdown() and true or false })
    inc.kind = "taint"
    return inc
  end
  local fn = PUI.Secret.ToText(func, 200)
  return S.Capture:Report("taint", addon == PUI.ADDON_NAME and "Core" or (addon:match("^Phoenix_UI_(%w+)") or "Core"), {
    message = event .. ": " .. fn,
    stack = debugstack(2),
    extra = { event = event, func = fn, taintLog = C_CVar.GetCVar("taintLog"), readTaintLog = true },
  })
end

function Taint:Start()
  frame:RegisterEvent("ADDON_ACTION_BLOCKED")
  frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
end

-- Session taint logging: remember the user's value, set 1, restore at logout.
function Taint:SetSessionLogging(on)
  if on and not self.saved then
    self.saved = C_CVar.GetCVar("taintLog") or "0"
    C_CVar.SetCVar("taintLog", "1")
    frame:RegisterEvent("PLAYER_LOGOUT")
  elseif not on and self.saved then
    C_CVar.SetCVar("taintLog", self.saved)
    self.saved = nil
    frame:UnregisterEvent("PLAYER_LOGOUT")
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGOUT" then
    if Taint.saved then C_CVar.SetCVar("taintLog", Taint.saved) end
    PUI.DB:SetRaw("sentinel.taintLogSession", nil) -- the switch lasts one session
  else
    Taint:OnAction(event, ...)
  end
end)
