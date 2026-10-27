local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Scoreboard column registry (mockup 18 "scoreboard columns (registry)").
-- Phoenix's own columns and any other addon's register here:
--   PhoenixUI.PvP.Columns:Register(id, { label, value = function(score) end,
--     width, format = "number" | "short" | "signed" | "text", order })
-- You choose which columns show and their order (pvp.columns), sort by any
-- column and highlight yourself and your team. Scores are secret while a
-- match runs, so rows are read only after the game says the match is over.
local _, ns = ...
local Secret = PUI.Secret
local C = { defs = {}, order = {} }
ns.Columns = C

function C:Register(id, spec)
  assert(type(id) == "string" and id:match("^[%w_]+$"), "column id must be a word")
  assert(type(spec) == "table" and type(spec.value) == "function", "column needs a value function")
  if not self.defs[id] then self.order[#self.order + 1] = id end
  spec.id, spec.label = id, spec.label or id
  spec.width, spec.format = spec.width or 60, spec.format or "number"
  spec.external = spec.external == true
  self.defs[id] = spec
  PUI.Kernel:Fire("PVP_COLUMNS", id)
  return spec
end
function C:Get(id) return self.defs[id] end
-- Every column you can add, Phoenix's first then other addons'.
function C:All()
  local out = {}
  for _, id in ipairs(self.order) do out[#out + 1] = self.defs[id] end
  return out
end

local function field(name) return function(sc) return sc[name] end end
C:Register("name", { label = "Player", value = field("name"), width = 130, format = "text" })
C:Register("spec", { label = "Spec", value = field("talentSpec"), width = 80, format = "text" })
C:Register("damage", { label = "Damage", value = field("damageDone"), format = "short" })
C:Register("healing", { label = "Healing", value = field("healingDone"), format = "short" })
C:Register("kb", { label = "KB", value = field("killingBlows"), width = 36 })
C:Register("deaths", { label = "Deaths", value = field("deaths"), width = 44 })
C:Register("hk", { label = "HK", value = field("honorableKills"), width = 36 })
C:Register("rating", { label = "Rating", value = field("rating"), width = 54 })
C:Register("ratingChange", { label = "Rating +/-", value = field("ratingChange"), width = 64, format = "signed" })
C:Register("mmrBefore", { label = "MMR before", value = field("prematchMMR"), width = 70 })
C:Register("mmrAfter", { label = "MMR after", value = field("postmatchMMR"), width = 70 })
C:Register("honor", { label = "Honor", value = field("honorGained"), width = 50 })
C.DEFAULT = { "name", "spec", "damage", "healing", "kb", "deaths", "ratingChange" }

function C.Format(v, fmt)
  if v == nil then return "" end
  if Secret.IsSecret(v) then return nil end -- caller passes the secret to the widget
  if fmt == "text" or type(v) ~= "number" then return tostring(v) end
  if fmt == "signed" then return string.format("%+d", v) end
  if fmt == "short" then
    if v >= 1e6 then return string.format("%.1fM", v / 1e6) end
    if v >= 1e3 then return string.format("%.0fK", v / 1e3) end
  end
  return string.format("%d", v)
end

-- Columns(list) -> the defs you picked, in your order (unknown ids skipped).
function C:Pick(list)
  local out = {}
  for _, id in ipairs(list or C.DEFAULT) do if self.defs[id] then out[#out + 1] = self.defs[id] end end
  return out
end

-- Rows: only once the match is over. Each row keeps raw values for sorting.
function C.Ready()
  if C_PvP.IsMatchComplete then return C_PvP.IsMatchComplete() == true end
  return false
end
function C.Rows()
  local out = {}
  local n = rawget(_G, "GetNumBattlefieldScores") and GetNumBattlefieldScores() or 0
  for i = 1, n do
    local sc = C_PvP.GetScoreInfo(i)
    if sc then out[#out + 1] = sc end
  end
  return out
end
function C.Sort(rows, colId, desc)
  local def = C.defs[colId]
  if not def then return rows end
  table.sort(rows, function(a, b)
    local x, y = def.value(a), def.value(b)
    if Secret.IsSecret(x) or Secret.IsSecret(y) or x == nil or y == nil then return false end
    if type(x) ~= type(y) then return tostring(x) < tostring(y) end
    if desc then return x > y end
    return x < y
  end)
  return rows
end
-- Is this row you, or on your team (faction index matches yours)?
function C.Mine(row, myGuid, myFaction)
  if row.guid ~= nil and not Secret.IsSecret(row.guid) and row.guid == myGuid then return "me" end
  if row.faction ~= nil and not Secret.IsSecret(row.faction) and myFaction ~= nil and row.faction == myFaction then return "team" end
  return nil
end
