local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui sentinel [export|copy [all]|send|clear|induce|enable <module>]
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
  elseif word == "copy" then
    if S.Panel.frame == nil then S.Panel:Build() end
    if arg == "all" or arg == "session" then S.Panel:CopySession() else S.Panel:CopySelected() end
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
  elseif word == "fixed" then
    S.FixedSync.Prompt()
  elseif word == "panel" then
    S.Panel:Toggle()
  elseif word == "preview" then
    PUI.Dialogs:Copy("What leaves this PC", S.Upload:PreviewText())
  elseif word == "settings" and PUI.OptionsHost:Load() then
    PUI.Options:Open("Sentinel")
  else
    S.Reporter:Toggle()
  end
end, "open the error reporter (settings, preview, panel, export, copy [all], send, clear, induce, fixed)")
PUI.Slash:Register("bugs", function() S.Reporter:Toggle() end, "open the error reporter")
-- /sentinel (BugSack's /bugsack habit): opens the same viewer.
SLASH_PHOENIXSENTINEL1 = "/sentinel"
SlashCmdList.PHOENIXSENTINEL = function() S.Reporter:Toggle() end
