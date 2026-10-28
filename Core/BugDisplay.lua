local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- BugGrabber display shim (deferred batch D). BugGrabber picks its display
-- from the "X-BugGrabber-Display" TOC field when it loads; Sentinel is
-- load-on-demand, so the display object lives here in Core and exists from
-- the first frame. FormatError gives BugGrabber's own print path Phoenix's
-- short format. At login, when BugGrabber is loaded and Phoenix is the
-- chosen error display (no BugSack, or the Coexist choice is Phoenix), the
-- shim tells BugGrabber a display is registered so it stops printing its own
-- chat line: Sentinel's popup/badge already announce the error. BugGrabber
-- cannot be told to unregister; switching the choice to BugSack later is
-- still correct because BugSack registers itself the same way.
local D = {}
PUI.BugDisplay = D
_G.PhoenixUIBugDisplay = D

function D:FormatError(err)
  if type(err) ~= "table" then return tostring(err) end
  local msg = type(err.message) == "string" and err.message or "?"
  local count = tonumber(err.counter) or 1
  local first = type(err.stack) == "string" and err.stack:match("^[^\n]+") or nil
  return string.format("|cffff7a1aPhoenix|r error%s: %s%s", count > 1 and (" x" .. count) or "", msg, first and ("\n  " .. first) or "")
end

function D.ShouldRegister()
  if type(rawget(_G, "BugGrabber")) ~= "table" then return false end
  local Coexist = PUI.Coexist
  return not (Coexist and Coexist:Yields("sentinel.display"))
end

function D.Register()
  if D.registered or not D.ShouldRegister() then return false end
  local reg = rawget(_G, "EventRegistry")
  if not (reg and reg.TriggerEvent) then return false end
  reg:TriggerEvent("BugGrabber.DisplayRegistered")
  D.registered = true
  return true
end

PUI.Kernel:On("LOGIN", function() D.Register() end)
