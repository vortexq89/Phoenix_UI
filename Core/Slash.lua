local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- /pui command router. Phase 1 has no options renderer: /pui prints the
-- available commands; /pui set|get|list give live access to every schema key.
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
    out(key .. " = " .. tostring(PUI.Schema:Get(key)) .. "  (" .. PUI.Schema.defs[key].mode .. ")")
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
  if not def then return out("usage: /pui set <key> <value>") end
  local value = parseValue(def, raw)
  local ok, why = value ~= nil, "unreadable value"
  if ok then ok, why = PUI.Schema:Validate(def, value) end
  if not ok then return out("not set: " .. why) end
  PUI.Schema:Set(key, value)
  out(key .. " = " .. tostring(PUI.Schema:Get(key)) .. " (applied)")
end, "<key> <value>: change a setting live")

local function help()
  out("v" .. (C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "?") .. " - the options window arrives in a later phase. Commands:")
  local words = {}
  for word in pairs(Slash.commands) do words[#words + 1] = word end
  table.sort(words)
  for i = 1, #words do out("/pui " .. words[i] .. " - " .. (Slash.commands[words[i]].help or "")) end
end

SLASH_PHOENIXUI1 = "/pui"
SlashCmdList.PHOENIXUI = function(msg)
  local word, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local cmd = Slash.commands[(word or ""):lower()]
  if cmd then cmd.fn(rest or "") else help() end
end
