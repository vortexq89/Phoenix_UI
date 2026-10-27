local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Privacy kit (plan 5.17a): applied to every report before it is shared
-- in game or saved for the Companion, and shown as-is by Preview, so the
-- preview is exactly what leaves this PC.
--  * your character name -> [player] as a whole word (never part of a word);
--  * GUIDs keep only their kind: Player-1234-0ABCDEF0 -> Player-GUID;
--  * chat text, other players' names and addon messages are never captured.
-- Text here was stored as plain text by Capture, so these gsubs never touch
-- a secret value.
local S = PUI.Sentinel
local P = {}
S.Privacy = P

local GUID_KINDS = { Player = true, Creature = true, Pet = true, GameObject = true, Vehicle = true, Vignette = true, Item = true, BattlePet = true }
function P.EscapePattern(text) return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

function P.Redact(text, name)
  if type(text) ~= "string" or text == "" then return text end
  text = text:gsub("(%a+)%-[%x%-]+%-%x%x%x%x%x%x%x%x", function(kind)
    if GUID_KINDS[kind] then return kind .. "-GUID" end
  end)
  if name and name ~= "" then
    -- Whole word: the characters on both sides must not be letters or digits.
    local out, pos, pat = {}, 1, P.EscapePattern(name)
    while true do
      local s, e = text:find(pat, pos)
      if not s then break end
      local before, after = text:sub(s - 1, s - 1), text:sub(e + 1, e + 1)
      local whole = not before:find("^[%w]$") and not after:find("^[%w]$")
      out[#out + 1] = text:sub(pos, s - 1) .. (whole and "[player]" or text:sub(s, e))
      pos = e + 1
    end
    out[#out + 1] = text:sub(pos)
    text = table.concat(out)
  end
  return text
end

local FIELDS = { "message", "stack", "locals" }
function P.Report(report, name)
  for _, f in ipairs(FIELDS) do report[f] = P.Redact(report[f], name) end
  return report
end
function P.Name()
  if not PUI.Schema:Get("sentinel.redactNames") then return nil end
  local n = UnitName("player")
  if n == nil or PUI.Secret.IsSecret(n) then return nil end
  return n
end
