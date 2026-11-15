local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder filter builder (plan 5.16 / 15.7): one set of filter chips per
-- category (dungeon, raid, delve, arena, rated BG, custom). The chips are
-- normal settings; the builder turns them into an expression the player can
-- read and edit, and every result is checked chip by chip so the count line
-- can say exactly why a group is hidden ("rating < 2600: 11"). Pure logic
-- over Data.Vars output; tested offline.
local _, ns = ...
local Expr = ns.Expr
local F = { compiled = {} }
ns.Filters = F

F.CATS = { "dungeon", "raid", "delve", "arena", "rbg", "custom" }
F.CAT_LABEL = { dungeon = "Dungeons and Mythic+", raid = "Raids", delve = "Delves", arena = "Arena", rbg = "Rated battlegrounds", custom = "Custom groups" }
local ALL = { dungeon = true, raid = true, delve = true, arena = true, rbg = true, custom = true }
local PVE = { dungeon = true, raid = true, delve = true, custom = true }
local PVP = { arena = true, rbg = true }
local PARTY = { dungeon = true, delve = true, arena = true }

-- kind: "min" (0 = off), "max" (value >= def.max = off), "on" (toggle), "any" (one-of toggles)
F.FIELDS = {
  { id = "minRating", label = "Leader score at least", kind = "min", var = "mprating", max = 4000, step = 50, cats = { dungeon = true }, simple = true, short = "score" },
  { id = "maxRating", label = "Leader score at most", kind = "max", var = "mprating", max = 4000, step = 50, cats = { dungeon = true }, short = "score" },
  { id = "minPvp", label = "Leader rating at least", kind = "min", var = "pvprating", max = 3500, step = 50, cats = PVP, simple = true, short = "rating" },
  { id = "maxPvp", label = "Leader rating at most", kind = "max", var = "pvprating", max = 3500, step = 50, cats = PVP, short = "rating" },
  { id = "tanksMin", label = "Tanks at least", kind = "min", var = "tanks", max = 10, cats = ALL, short = "tanks" },
  { id = "tanksMax", label = "Tanks at most", kind = "max", var = "tanks", max = 10, cats = ALL, short = "tanks" },
  { id = "healsMin", label = "Healers at least", kind = "min", var = "heals", max = 10, cats = ALL, short = "heals" },
  { id = "healsMax", label = "Healers at most", kind = "max", var = "heals", max = 10, cats = ALL, short = "heals" },
  { id = "dpsMin", label = "Damage at least", kind = "min", var = "dps", max = 30, cats = ALL, short = "dps" },
  { id = "dpsMax", label = "Damage at most", kind = "max", var = "dps", max = 30, cats = ALL, short = "dps" },
  { id = "membersMin", label = "Members at least", kind = "min", var = "members", max = 40, cats = ALL, short = "members" },
  { id = "membersMax", label = "Members at most", kind = "max", var = "members", max = 40, cats = ALL, short = "members" },
  { id = "ageMax", label = "Listed at most (minutes)", kind = "maxz", var = "age", max = 120, cats = ALL, short = "age" },
  { id = "ilvlMax", label = "Required item level at most", kind = "maxz", var = "ilvl", max = 800, step = 5, cats = PVE, short = "ilvl" },
  { id = "tierMin", label = "Delve tier at least", kind = "min", var = "tier", max = 11, cats = { delve = true }, simple = true, short = "tier" },
  { id = "tierMax", label = "Delve tier at most", kind = "max", var = "tier", max = 11, cats = { delve = true }, short = "tier" },
  { id = "partyFit", label = "My role fits", kind = "on", var = "partyfit", cats = ALL, simple = true, short = "role full" },
  { id = "notDeclined", label = "Not declined before", kind = "on", var = "declined", negate = true, cats = ALL, simple = true, short = "declined" },
  { id = "needBL", label = "Needs Bloodlust (I bring it)", kind = "on", var = "needbl", cats = PARTY, short = "has lust" },
  { id = "hasBL", label = "Has Bloodlust", kind = "on", var = "hasbl", cats = PARTY, short = "no lust" },
  { id = "hasBR", label = "Has battle res", kind = "on", var = "hasbr", cats = { dungeon = true, raid = true }, short = "no res" },
  { id = "hasHealer", label = "Has a healer", kind = "on", var = "hashealer", cats = PVP, short = "no healer" },
  { id = "friendsOnly", label = "Friends or guild inside", kind = "on", var = "friends", cats = ALL, short = "no friends" },
  { id = "voice", label = "Lists voice chat", kind = "on", var = "voice", cats = ALL, short = "no voice" },
  { id = "notDelisted", label = "Hide delisted groups", kind = "on", var = "delisted", negate = true, cats = ALL, default = true, short = "delisted" },
  { id = "diffNormal", label = "Normal", kind = "any", var = "normal", cats = { dungeon = true, raid = true }, group = "difficulty" },
  { id = "diffHeroic", label = "Heroic", kind = "any", var = "heroic", cats = { dungeon = true, raid = true }, group = "difficulty" },
  { id = "diffMythic", label = "Mythic", kind = "any", var = "mythic", cats = { dungeon = true, raid = true }, group = "difficulty" },
  { id = "diffMplus", label = "Mythic+", kind = "any", var = "mythicplus", cats = { dungeon = true }, group = "difficulty", simple = true },
  { id = "br2v2", label = "2v2", kind = "any", var = "arena2v2", cats = { arena = true }, group = "bracket", simple = true },
  { id = "br3v3", label = "3v3", kind = "any", var = "arena3v3", cats = { arena = true }, group = "bracket", simple = true },
}
F.BY_ID = {}
for _, f in ipairs(F.FIELDS) do F.BY_ID[f.id] = f end
F.GROUP_LABEL = { difficulty = "difficulty", bracket = "bracket" }

function F.Applies(field, cat) return field.cats[cat] == true end

function F.Off(field, value)
  if field.kind == "min" or field.kind == "maxz" then return (value or 0) <= 0 end
  if field.kind == "max" then return value == nil or value >= field.max end
  return not value
end

-- Chips(cat, get) -> active chips, in field order; get(cat, fieldId) reads the setting.
function F.Chips(cat, get)
  local out, groups = {}, {}
  for _, f in ipairs(F.FIELDS) do
    if F.Applies(f, cat) then
      local value = get(cat, f.id)
      if not F.Off(f, value) then
        if f.kind == "any" then
          local g = groups[f.group]
          if not g then
            g = { id = f.group, vars = {}, label = F.GROUP_LABEL[f.group], short = F.GROUP_LABEL[f.group] }
            groups[f.group] = g
            out[#out + 1] = g
          end
          g.vars[#g.vars + 1] = f.var
        else
          out[#out + 1] = { id = f.id, field = f, value = value, short = f.short }
        end
      end
    end
  end
  local list = get(cat, "dungeons")
  if type(list) == "table" and #list > 0 then out[#out + 1] = { id = "dungeons", vars = list, short = "other dungeon" } end
  for _, c in ipairs(out) do c.expr = F.ChipExpr(c) end
  return out
end

function F.ChipExpr(c)
  if c.vars then return #c.vars == 1 and c.vars[1] or ("(" .. table.concat(c.vars, " or ") .. ")") end
  local f = c.field
  if f.kind == "min" then return f.var .. " >= " .. c.value end
  if f.kind == "max" or f.kind == "maxz" then return f.var .. " <= " .. c.value end
  return (f.negate and "not " or "") .. f.var
end

local function check(c, v)
  if c.vars then
    for _, name in ipairs(c.vars) do if v[name] then return true end end
    return false
  end
  local f, x = c.field, v[c.field.var]
  if f.kind == "min" then return (tonumber(x) or (x and 1 or 0)) >= c.value end
  if f.kind == "max" or f.kind == "maxz" then return (tonumber(x) or (x and 1 or 0)) <= c.value end
  local on = x ~= nil and x ~= false and x ~= 0
  if f.negate then return not on end
  return on
end
F.Check = check

-- The expression the chips generate (shown in the builder, editable).
function F.BuildExpression(cat, get)
  local parts = {}
  for _, c in ipairs(F.Chips(cat, get)) do parts[#parts + 1] = c.expr end
  return table.concat(parts, " and ")
end

local function compiled(text)
  local c = F.compiled[text or ""]
  if c == nil then
    local fn, msg, at = Expr.Compile(text)
    c = fn and { fn = fn } or { err = msg, at = at }
    F.compiled[text or ""] = c
  end
  return c
end
function F.ForgetCompiled() wipe(F.compiled) end

-- Evaluate(cat, rows, get) -> shown, why, hidden
--   rows: { { id, vars, meta } }; why: { [chipId|"expression"] = count }, plus why.order
function F.Evaluate(cat, rows, get)
  local shown, why, hidden = {}, { order = {} }, 0
  if not get(cat, "enabled") then
    for i = 1, #rows do shown[i] = rows[i] end
    return shown, why, 0
  end
  local chips = F.Chips(cat, get)
  local ex = compiled(get(cat, "expr"))
  local function count(id, label)
    if not why[id] then why[id] = 0; why.order[#why.order + 1] = { id = id, label = label } end
    why[id] = why[id] + 1
  end
  for _, r in ipairs(rows) do
    local failed
    for _, c in ipairs(chips) do
      if not check(c, r.vars) then failed = c; break end
    end
    if failed then
      count(failed.id, failed.short or failed.id); hidden = hidden + 1; r.hiddenBy = failed.id
    elseif ex.fn and not ex.fn(r.vars) then
      count("expression", "your expression"); hidden = hidden + 1; r.hiddenBy = "expression"
    else
      r.hiddenBy = nil
      shown[#shown + 1] = r
    end
  end
  return shown, why, hidden
end

-- "showing 12 of 87 - 75 hidden: score 40, role full 30, declined 5"
function F.CountLine(shown, total, why)
  local parts = {}
  for _, e in ipairs(why.order or {}) do parts[#parts + 1] = e.label .. " " .. why[e.id] end
  local hidden = total - shown
  local line = string.format("showing %d of %d", shown, total)
  if hidden > 0 then line = line .. string.format(" - %d hidden", hidden) .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or "") end
  return line
end

-- Sort spec "mprating desc, age asc" -> comparator (stable: result ID breaks ties).
function F.ParseSort(text)
  local keys = {}
  for part in (text or ""):gmatch("[^,]+") do
    local name, dir = part:match("^%s*([%w_]+)%s*(%a*)%s*$")
    if name then
      name = name:lower()
      if not Expr.names[name] then return nil, "unknown sort word '" .. name .. "'" end
      keys[#keys + 1] = { name = name, desc = dir:lower() == "desc" }
    elseif not part:match("^%s*$") then
      return nil, "write sort as 'word asc' or 'word desc', comma separated"
    end
  end
  return keys
end

local function sortNum(x) if x == true then return 1 elseif not x then return 0 end return tonumber(x) or 0 end
function F.Sort(rows, text)
  local keys = F.ParseSort(text)
  if not keys or #keys == 0 then return rows end
  table.sort(rows, function(a, b)
    for _, k in ipairs(keys) do
      local x, y = sortNum(a.vars[k.name]), sortNum(b.vars[k.name])
      if x ~= y then if k.desc then return x > y end return x < y end
    end
    return a.id < b.id
  end)
  return rows
end
