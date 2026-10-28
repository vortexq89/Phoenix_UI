local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Nameplate colour data packs (deferred: "NPC colour data packs").
-- A pack is a named list of NPC rule lines (same syntax as Custom NPC colours)
-- with an optional instance: an instance pack is used only inside that
-- dungeon or raid (GetInstanceInfo's instance id), so lists for different
-- places never collide. Packs travel as one-line strings:
--   PUIPACK1|<label>|<instance id or 0>|<rule>;<rule>;...
-- "Imported packs" holds the strings you paste (list editor, live); the
-- in-use list ("Rule packs in use") turns a pack on. Built-in packs are
-- generic Phoenix data (conditions only, no NPC lists); per-dungeon lists
-- come from players and the test phase as imports.
local _, ns = ...
local NP, R = ns.NP, ns.Rules
local Schema, Kernel = PUI.Schema, PUI.Kernel
local OWNER = "Nameplates"
local s = NP.settings
local D = { HEAD = "PUIPACK1", imported = {} }
NP.DataPacks = D

-- Built-in, original Phoenix data: condition rules that work in any instance.
R.RegisterPack("phoenix.casters", "Phoenix: casting elites stand out",
  { "*:FF7D1A:1.1:elite:hostile:casting" })
R.RegisterPack("phoenix.rares", "Phoenix: rares in purple",
  { "*:B07CFF:1.15:rare:hostile", "*:B07CFF:1.15:rareelite:hostile" })

local function clean(text) return (tostring(text or ""):gsub("[|;\n\r]", " ")) end
-- Export(id) -> string or nil.
function D.Export(id)
  local p = R.packs[id]
  if not p then return nil end
  local lines = {}
  for i, l in ipairs(p.lines) do lines[i] = clean(l) end
  return table.concat({ D.HEAD, clean(p.label), tostring(p.instance or 0), table.concat(lines, ";") }, "|")
end
-- Parse(str) -> pack { id, label, instance, lines } or nil, reason.
function D.Parse(str)
  if type(str) ~= "string" then return nil, "not text" end
  local head, label, inst, body = str:match("^%s*([^|]+)|([^|]*)|(%d+)|(.*)$")
  if head ~= D.HEAD then return nil, "not a Phoenix pack string (starts with " .. D.HEAD .. "|)" end
  label = label:match("^%s*(.-)%s*$")
  if label == "" then return nil, "the pack needs a name" end
  local lines = {}
  for l in (body .. ";"):gmatch("([^;]*);") do
    l = l:match("^%s*(.-)%s*$")
    if l ~= "" then
      local ok, why = R.Validate(l)
      if not ok then return nil, "rule '" .. l .. "': " .. tostring(why) end
      lines[#lines + 1] = l
    end
  end
  if #lines == 0 then return nil, "the pack has no rules" end
  if #lines > 200 then return nil, "a pack holds at most 200 rules" end
  local instance = tonumber(inst)
  return { id = "user." .. label, label = label, instance = instance ~= 0 and instance or nil, lines = lines }
end
function D.Validate(str) local p, why = D.Parse(str); if p then return true end return false, why end
function D.Label(str)
  local p = D.Parse(str)
  if not p then return str end
  return p.label .. " (" .. #p.lines .. " rules" .. (p.instance and (", instance " .. p.instance) or ", everywhere") .. ") - use it as '" .. p.id .. "'"
end
-- Import(list): (re)registers every imported pack.
function D.Import(list)
  for id in pairs(D.imported) do R.packs[id] = nil end
  D.imported = {}
  for _, str in ipairs(list or {}) do
    local p = D.Parse(str)
    if p then
      R.RegisterPack(p.id, p.label, p.lines)
      R.packs[p.id].instance = p.instance
      D.imported[p.id] = true
    end
  end
end

-- Instance filter: a pack with an instance is compiled in only there.
function D.Instance()
  local id = select(8, GetInstanceInfo())
  if type(id) == "number" and not PUI.Secret.IsSecret(id) then return id end
  return nil
end
local enabledAll
function D.Filter(ids, here)
  local out = {}
  for _, id in ipairs(ids or {}) do
    local p = R.packs[id]
    if p and (not p.instance or p.instance == here) then out[#out + 1] = id end
  end
  return out
end
function D.Recompile()
  enabledAll = enabledAll or R.enabledPacks
  R.enabledPacks = D.Filter(enabledAll, D.Instance())
  R.Compile(s.rules.list)
  if NP.active then NP.RefreshAll() end
end
-- The in-use list setting stores every chosen id; keep the full list here.
local inUse = Schema.defs["np.rules.packs"]
local baseApply = inUse.apply
inUse.apply = function(v)
  enabledAll = v
  baseApply(v)
  D.Recompile()
end
D.here = nil
Kernel:On("LOGIN", function() D.Recompile() end)
function D.OnZone()
  local here = D.Instance()
  if here ~= D.here then D.here = here; D.Recompile() end
end

Schema:Register("np.rules.imported", {
  type = "list", default = {}, maxItems = 30, owner = OWNER, mode = "advanced",
  label = "Imported NPC colour packs",
  tooltip = "Paste a Phoenix pack string (PUIPACK1|name|instance|rules). Then add its name, shown on the row, to Rule packs in use. A pack with an instance id works only inside that dungeon or raid.",
  itemValidate = D.Validate, itemLabel = D.Label, searchTags = { "pack", "import", "npc", "dungeon", "raid" },
  apply = function(v) D.Import(v); D.Recompile() end,
})
NP.schema["np.rules.imported"] = Schema.defs["np.rules.imported"]
Schema.defs["np.rules.imported"].apply(Schema:Get("np.rules.imported"))

PUI.Slash:Register("packexport", function(arg)
  local str = D.Export(arg and arg:match("^%s*(.-)%s*$") or "")
  if not str then PUI.Slash.Print("usage: /pui packexport <pack id> (ids: " .. table.concat((function() local t = {} for id in pairs(R.packs) do t[#t + 1] = id end table.sort(t) return t end)(), ", ") .. ")") return end
  PUI.Dialogs:Copy("Nameplate pack", str)
end, "copy a nameplate colour pack as a string")
