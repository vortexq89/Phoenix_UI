local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui command router. /pui alone opens the options window (Core/OptionsHost);
-- /pui help prints the commands; /pui set|get|list give live access to every
-- visible schema key.
local Slash = { commands = {} }
PUI.Slash = Slash

local function out(msg) print("|cffff7d0aPhoenix UI|r " .. msg) end
Slash.Print = out

function Slash:Register(word, fn, help)
  self.commands[word] = { fn = fn, help = help }
end

local function parseValue(def, raw)
  if def.type == "toggle" then
    if raw == "on" or raw == "true" or raw == "1" then return true end
    if raw == "off" or raw == "false" or raw == "0" then return false end
    return nil
  elseif def.type == "range" then
    return tonumber(raw)
  end
  return raw
end

Slash:Register("list", function()
  for i = 1, #PUI.Schema.keys do
    local key = PUI.Schema.keys[i]
    if not PUI.Schema.defs[key].hidden then out(key .. " = " .. tostring(PUI.Schema:Get(key)) .. "  (" .. PUI.Schema.defs[key].mode .. ")") end
  end
end, "list every setting and its value")

Slash:Register("get", function(rest)
  local def = PUI.Schema:Def(rest)
  if not def then return out("unknown setting: " .. tostring(rest)) end
  out(rest .. " = " .. tostring(PUI.Schema:Get(rest)) .. " - " .. def.tooltip)
end, "<key>: show one setting")

Slash:Register("set", function(rest)
  local key, raw = rest:match("^(%S+)%s+(.+)$")
  local def = key and PUI.Schema:Def(key)
  if not def or def.hidden then return out("usage: /pui set <key> <value>") end
  local value = parseValue(def, raw)
  local ok, why = value ~= nil, "unreadable value"
  if ok then ok, why = PUI.Schema:Validate(def, value) end
  if not ok then return out("not set: " .. why) end
  PUI.Schema:Set(key, value)
  out(key .. " = " .. tostring(PUI.Schema:Get(key)) .. " (applied)")
end, "<key> <value>: change a setting live")

local function help()
  out("v" .. (C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "?") .. " - commands:")
  local words = {}
  for word in pairs(Slash.commands) do words[#words + 1] = word end
  table.sort(words)
  for i = 1, #words do out("/pui " .. words[i] .. " - " .. (Slash.commands[words[i]].help or "")) end
end

Slash:Register("help", help, "list the commands")

SLASH_PHOENIXUI1 = "/pui"
SlashCmdList.PHOENIXUI = function(msg)
  local word, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local cmd = Slash.commands[(word or ""):lower()]
  if cmd then cmd.fn(rest or "")
  elseif word == "" and Slash.default then Slash.default()
  else help() end
end

-- /pui loc: translation coverage for the active language (PUI_V2 5.17).
Slash:Register("loc", function()
  local L = PUI.Locale
  local keys = L:Harvest()
  local have, total = L:Coverage(keys)
  if L.active == "enUS" then return out("language enUS: " .. total .. " strings (English is the source).") end
  local miss = 0
  for _ in pairs(L.missing) do miss = miss + 1 end
  out(string.format("language %s: %d of %d strings translated; %d missing ones seen so far fall back to English.", L.active, have, total, miss))
end, "translation coverage for the current language")
