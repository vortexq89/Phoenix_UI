-- PUI-GATE: Core/ClientGate.lua is the first file of Phoenix_UI.toc and the only file without the line-1 guard.
-- It decides whether this client may run Phoenix UI at all, flags WoW Forever,
-- and provides the SavedVariables round-trip check used by DB.lua.
local ADDON_NAME = ...

local MIN_RETAIL = 120100 -- WoW Midnight 12.1.0
local FOREVER_MIN, FOREVER_MAX = 16000, 19999 -- WoW Forever 1.6x

local _, buildNumber, _, tocVersion = GetBuildInfo()
local isForever = tocVersion >= FOREVER_MIN and tocVersion <= FOREVER_MAX
local isRetail = tocVersion >= MIN_RETAIL

local PUI = {
  ADDON_NAME = ADDON_NAME,
  TOC = tocVersion,
  BUILD = tonumber(buildNumber) or 0,
  IS_FOREVER = isForever,
  IS_RETAIL = isRetail and not isForever,
  gateOpen = isRetail or isForever,
}
_G.PhoenixUI = PUI

local Gate = {}
PUI.ClientGate = Gate

if not PUI.gateOpen then
  -- Unsupported client: every other Phoenix file returns at its line-1 guard.
  Gate.reason = "Phoenix UI needs WoW Midnight 12.1 or WoW Forever; this client reports interface " .. tocVersion .. "."
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    print("|cffff7d0aPhoenix UI|r: " .. Gate.reason)
  end)
  return
end

-- SavedVariables can only hold strings, finite numbers, booleans and tables
-- whose keys are strings or numbers, without cycles. CheckSerializable walks a
-- table and returns false plus the path of the first value that would not
-- survive a write/read cycle, so DB.lua can refuse to persist it.
local function badNumber(n)
  return n ~= n or n == math.huge or n == -math.huge
end

local isSecretValue = issecretvalue

local function walk(value, path, seen)
  if isSecretValue and isSecretValue(value) then return false, path .. " (secret value)" end
  local t = type(value)
  if t == "string" or t == "boolean" then return true end
  if t == "number" then
    if badNumber(value) then return false, path .. " (non-finite number)" end
    return true
  end
  if t ~= "table" then return false, path .. " (" .. t .. ")" end
  if seen[value] then return false, path .. " (cycle)" end
  seen[value] = true
  for k, v in pairs(value) do
    local kt = type(k)
    if kt ~= "string" and kt ~= "number" then return false, path .. " (key of type " .. kt .. ")" end
    if kt == "number" and badNumber(k) then return false, path .. " (non-finite key)" end
    local ok, where = walk(v, path .. "." .. tostring(k), seen)
    if not ok then return false, where end
  end
  seen[value] = nil
  return true
end

function Gate.CheckSerializable(tbl, rootName)
  return walk(tbl, rootName or "root", {})
end
