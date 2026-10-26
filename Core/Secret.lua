local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Secret-value helpers (12.x). Rule: a value that may be secret is never
-- compared, indexed, concatenated or used in arithmetic by Phoenix code. These
-- helpers either hand it straight to a widget or replace it with a marker.
local Secret = {}
PUI.Secret = Secret

local isSecretValue = issecretvalue -- 12.0.0; also present on Forever 1.60
local PLACEHOLDER = "<secret>"
Secret.PLACEHOLDER = PLACEHOLDER

function Secret.IsSecret(value)
  if isSecretValue == nil then return false end
  return isSecretValue(value) == true
end
local function IsSecret(value) return Secret.IsSecret(value) end -- late-bound so tests can probe it

-- Plain-text form of any value for diagnostics. Secrets become "<secret>";
-- strings are truncated to maxLen (default 512) characters.
function Secret.ToText(value, maxLen)
  if IsSecret(value) then return PLACEHOLDER end
  local t = type(value)
  local s
  if t == "string" then
    s = value
  elseif t == "number" or t == "boolean" or t == "nil" then
    s = tostring(value)
  else
    s = "<" .. t .. ">"
  end
  maxLen = maxLen or 512
  if #s > maxLen then s = s:sub(1, maxLen) .. "..." end
  return s
end

-- Value safe to store in SavedVariables: secrets become the placeholder,
-- functions/userdata/threads become a type tag, strings are truncated.
function Secret.Storable(value, maxLen)
  if IsSecret(value) then return PLACEHOLDER end
  local t = type(value)
  if t == "number" then
    if value ~= value or value == math.huge or value == -math.huge then return tostring(value) end
    return value
  end
  if t == "boolean" or t == "nil" then return value end
  return Secret.ToText(value, maxLen)
end

-- Widget pass-through: the engine formats secrets itself, Lua never sees them.
function Secret.SafeFormat(fontString, fmt, ...)
  fontString:SetFormattedText(fmt, ...)
end

-- Alpha from a possibly secret boolean (Frame API, not Texture).
function Secret.SafeAlpha(frame, flag, alphaTrue, alphaFalse)
  frame:SetAlphaFromBoolean(flag, alphaTrue or 1, alphaFalse or 0)
end
