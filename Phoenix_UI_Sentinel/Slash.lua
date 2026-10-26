local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui sentinel [export|send|clear|induce|enable <module>]
local S = PUI.Sentinel
local out = PUI.Slash.Print

-- Deliberate error for the in-game check of the capture path (runs next frame
-- so it surfaces through the error handler like any real Phoenix error).
function S:InduceError()
  C_Timer.After(0, function()
    error("Phoenix Sentinel induced test error (safe to ignore)")
  end)
end

PUI.Slash:Register("sentinel", function(rest)
  local word, arg = rest:match("^(%S*)%s*(.-)$")
  if word == "export" then
    S.Panel:Open()
    S.Panel:ShowExport()
  elseif word == "send" then
    S.Panel:SendNow()
  elseif word == "clear" then
    S.Capture:Clear()
    out("Sentinel incidents cleared.")
  elseif word == "induce" then
    out("Raising a test error now.")
    S:InduceError()
  elseif word == "enable" and arg ~= "" then
    S.SafeMode:Release(arg)
    out(arg .. " re-enabled.")
  else
    S.Panel:Toggle()
  end
end, "open the Sentinel panel (export, send, clear, induce, enable <module>)")
