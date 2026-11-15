local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplate NPC rules (plan 5.3 "Rules engine", 13.4 colour rules): a list the
-- user edits in the options list editor, one rule per line:
--   <npc id or exact name>:<RRGGBB>[:<scale>][:glow]
--   e.g. 185680:B07CFF:1.1   or   Void Acolyte:B07CFF   or   212389:FF5468:1:glow
-- Rules are compiled once per edit into two plain lookup tables. Matching
-- reads UnitCreatureID / UnitName and uses them only when they are not secret;
-- a secret id or name never matches (it is never compared). Order in the
-- list is priority: the first rule for an id or name wins.
local _, ns = ...
local Secret = PUI.Secret

local R = { byID = {}, byName = {}, count = 0 }
ns.Rules = R

local function hexColor(h)
  if type(h) ~= "string" or not h:match("^%x%x%x%x%x%x$") then return nil end
  return { r = tonumber(h:sub(1, 2), 16) / 255, g = tonumber(h:sub(3, 4), 16) / 255, b = tonumber(h:sub(5, 6), 16) / 255 }
end

-- Parse(line) -> rule table or nil, reason.
function R.Parse(line)
  if type(line) ~= "string" then return nil, "not text" end
  local parts = {}
  for p in (line .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
  local who, hex = parts[1], parts[2]
  if not who or who == "" then return nil, "start with an NPC id or name" end
  local color = hexColor(hex and hex:upper())
  if not color then return nil, "colour must be six hex digits, e.g. B07CFF" end
  local rule = { color = color, scale = 1, glow = false }
  for i = 3, #parts do
    local p = parts[i]
    if p == "glow" then rule.glow = true
    elseif tonumber(p) then
      local sc = tonumber(p)
      if sc < 0.5 or sc > 2 then return nil, "scale must be between 0.5 and 2" end
      rule.scale = sc
    elseif p ~= "" then return nil, "unknown option '" .. p .. "'" end
  end
  local id = tonumber(who)
  if id then rule.id = id else rule.name = who end
  return rule
end

function R.Validate(line)
  local rule, why = R.Parse(line)
  if not rule then return false, why end
  return true
end

-- Readable label for the list editor row.
function R.Label(line)
  local rule = R.Parse(line)
  if not rule then return line end
  local who = rule.id and ("NPC " .. rule.id) or rule.name
  local extra = {}
  if rule.scale ~= 1 then extra[#extra + 1] = ("scale %.2g"):format(rule.scale) end
  if rule.glow then extra[#extra + 1] = "glow" end
  return who .. " - custom colour" .. (#extra > 0 and (", " .. table.concat(extra, ", ")) or "")
end

function R.Compile(list)
  local byID, byName, n = {}, {}, 0
  for i = 1, #(list or {}) do
    local rule = R.Parse(list[i])
    if rule then
      rule.index = i
      if rule.id and not byID[rule.id] then byID[rule.id] = rule; n = n + 1
      elseif rule.name and not byName[rule.name] then byName[rule.name] = rule; n = n + 1 end
    end
  end
  R.byID, R.byName, R.count = byID, byName, n
  return n
end

-- Match(unit) -> rule or nil. Never compares a secret value.
function R.Match(unit)
  if R.count == 0 then return nil end
  local id = UnitCreatureID and UnitCreatureID(unit)
  if id ~= nil and not Secret.IsSecret(id) then
    local rule = R.byID[id]
    if rule then return rule end
  end
  local name = UnitName(unit)
  if name ~= nil and not Secret.IsSecret(name) then return R.byName[name] end
  return nil
end

-- Starter examples offered by the "Add example" button (not applied by default).
R.EXAMPLES = { "Void Acolyte:B07CFF:1.1", "Explosive:FF5468:1.2:glow" }
