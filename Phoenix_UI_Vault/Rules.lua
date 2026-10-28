local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Vault category engine (plan 5.11: rules engine and categories). Pure: no
-- frames, no API calls; Vault.lua hands in item facts. Items are keyed on
-- item ID / link; names fill in later (never required for a rule to run).
--   facts = { id, link, name, quality, ilvl, classID, subclassID, equipLoc,
--             count, bound, expansion, keystone, quest, new, sets = { "PvP" } }
-- A rule is "Name|expression"; expressions use fields, operators and/or/not:
--   type = Armor and ilvl >= 640      set ~ "PvP"      quality >= epic
--   name ~ potion or id = 191383      not bound and expansion = 11
local _, ns = ...
local R = {}
ns.Rules = R

-- Enum.ItemClass by name (constants are stable; read from Enum when present).
local IC = (Enum and Enum.ItemClass) or {}
R.CLASS = {
  consumable = IC.Consumable or 0, container = IC.Container or 1, weapon = IC.Weapon or 2, gem = IC.Gem or 3,
  armor = IC.Armor or 4, reagent = IC.Reagent or 5, projectile = IC.Projectile or 6, tradeskill = IC.Tradegoods or 7,
  tradegoods = IC.Tradegoods or 7, enhancement = IC.ItemEnhancement or 8, recipe = IC.Recipe or 9, questitem = IC.Questitem or 12,
  quest = IC.Questitem or 12, key = IC.Key or 13, miscellaneous = IC.Miscellaneous or 15, misc = IC.Miscellaneous or 15,
  glyph = IC.Glyph or 16, battlepet = IC.Battlepet or 17, profession = IC.Profession or 19, housing = IC.Housing or 20,
}
R.QUALITY = { poor = 0, junk = 0, grey = 0, common = 1, white = 1, uncommon = 2, green = 2, rare = 3, blue = 3, epic = 4, purple = 4,
  legendary = 5, orange = 5, artifact = 6, heirloom = 7, token = 8 }

-- Built-in categories in default order; user rules come first.
R.BUILTIN = {
  { id = "pinned", label = "Pinned" },
  { id = "new", label = "New" },
  { id = "keystone", label = "Keystone" },
  { id = "sets", label = "Equipment sets" },
  { id = "equipment", label = "Equipment" },
  { id = "consumables", label = "Consumables" },
  { id = "reagents", label = "Reagents" },
  { id = "quest", label = "Quest" },
  { id = "other", label = "Other" },
  { id = "junk", label = "Junk" },
}
R.LABEL = {}
for _, c in ipairs(R.BUILTIN) do R.LABEL[c.id] = c.label end

-- Tokeniser ------------------------------------------------------------------
local function tokens(src)
  local out, i = {}, 1
  while i <= #src do
    local ch = src:sub(i, i)
    if ch:match("%s") then i = i + 1
    elseif ch == "(" or ch == ")" then out[#out + 1] = { k = ch }; i = i + 1
    elseif ch == "\"" or ch == "'" then
      local j = src:find(ch, i + 1, true)
      if not j then return nil, "missing closing quote" end
      out[#out + 1] = { k = "val", v = src:sub(i + 1, j - 1) }; i = j + 1
    else
      local op = src:match("^[<>~!]=", i) or src:match("^[=<>~:]", i)
      if op then
        if op == ":" then op = "~" end
        if op == "!=" then op = "~=" end
        out[#out + 1] = { k = "op", v = op }; i = i + #op
      else
        local word = src:match("^[^%s%(%)=<>~!:\"']+", i)
        if not word then return nil, "unexpected '" .. ch .. "'" end
        local lw = word:lower()
        if lw == "and" or lw == "or" or lw == "not" then out[#out + 1] = { k = lw } else out[#out + 1] = { k = "val", v = word } end
        i = i + #word
      end
    end
  end
  return out
end

R.FIELDS = { type = true, subtype = true, ilvl = true, quality = true, name = true, id = true, bound = true, expansion = true,
  slot = true, count = true, set = true, keystone = true, quest = true, new = true }

local function value(field, raw)
  local lw = raw:lower()
  if field == "type" then return R.CLASS[lw] or tonumber(raw) end
  if field == "quality" then return R.QUALITY[lw] or tonumber(raw) end
  if field == "bound" or field == "keystone" or field == "quest" or field == "new" then
    if lw == "true" or lw == "yes" or lw == "1" then return true end
    if lw == "false" or lw == "no" or lw == "0" then return false end
    return nil
  end
  if field == "ilvl" or field == "id" or field == "expansion" or field == "count" or field == "subtype" then return tonumber(raw) end
  return lw
end

local function fact(f, field)
  if field == "type" then return f.classID end
  if field == "subtype" then return f.subclassID end
  if field == "slot" then return (f.equipLoc or ""):lower():gsub("^invtype_", "") end
  if field == "name" then return (f.name or ""):lower() end
  return f[field]
end

local function compare(field, op, want)
  return function(f)
    local have = fact(f, field)
    if field == "set" then
      for _, n in ipairs(f.sets or {}) do
        local ln = n:lower()
        if (op == "~" and ln:find(want, 1, true)) or (op == "=" and ln == want) then return true end
      end
      return op == "~=" and #(f.sets or {}) == 0
    end
    if op == "~" then return type(have) == "string" and have:find(want, 1, true) ~= nil end
    if op == "=" then return have == want end
    if op == "~=" then return have ~= want end
    if type(have) ~= "number" or type(want) ~= "number" then return false end
    if op == ">" then return have > want elseif op == "<" then return have < want
    elseif op == ">=" then return have >= want elseif op == "<=" then return have <= want end
    return false
  end
end

-- Recursive descent: or-expr := and-expr {or and-expr}; and-expr := unary
-- {[and] unary}; unary := not unary | ( or-expr ) | field op value | word
-- (a bare word searches the name).
function R.Compile(src)
  if type(src) ~= "string" or src:match("^%s*$") then return nil, "empty rule" end
  local toks, err = tokens(src)
  if not toks then return nil, err end
  local pos = 1
  local orExpr
  local function peek() return toks[pos] end
  local function unary()
    local t = peek()
    if not t then return nil, "rule ends too early" end
    if t.k == "not" then pos = pos + 1; local e, e2 = unary(); if not e then return nil, e2 end; return function(f) return not e(f) end end
    if t.k == "(" then
      pos = pos + 1
      local e, e2 = orExpr()
      if not e then return nil, e2 end
      if not peek() or peek().k ~= ")" then return nil, "missing )" end
      pos = pos + 1
      return e
    end
    if t.k ~= "val" then return nil, "unexpected '" .. t.k .. "'" end
    local nxt = toks[pos + 1]
    if nxt and nxt.k == "op" then
      local field = t.v:lower()
      if not R.FIELDS[field] then return nil, "unknown field '" .. t.v .. "'" end
      local vt = toks[pos + 2]
      if not vt or vt.k ~= "val" then return nil, "missing value after " .. nxt.v end
      local want = value(field, vt.v)
      if want == nil then return nil, "bad value '" .. vt.v .. "' for " .. field end
      pos = pos + 3
      return compare(field, nxt.v, want)
    end
    pos = pos + 1
    local word = t.v:lower()
    return function(f) return (f.name or ""):lower():find(word, 1, true) ~= nil end
  end
  local function andExpr()
    local left, e2 = unary()
    if not left then return nil, e2 end
    while peek() and (peek().k == "and" or peek().k == "val" or peek().k == "not" or peek().k == "(") do
      if peek().k == "and" then pos = pos + 1 end
      local right, e3 = unary()
      if not right then return nil, e3 end
      local l = left
      left = function(f) return l(f) and right(f) end
    end
    return left
  end
  orExpr = function()
    local left, e2 = andExpr()
    if not left then return nil, e2 end
    while peek() and peek().k == "or" do
      pos = pos + 1
      local right, e3 = andExpr()
      if not right then return nil, e3 end
      local l = left
      left = function(f) return l(f) or right(f) end
    end
    return left
  end
  local fn, e = orExpr()
  if not fn then return nil, e end
  if pos <= #toks then return nil, "unexpected text near '" .. tostring(toks[pos].v or toks[pos].k) .. "'" end
  return fn
end

-- "Name|expression" list item.
function R.ParseRule(item)
  if type(item) ~= "string" then return nil, "not text" end
  local name, expr = item:match("^%s*([^|]-)%s*|%s*(.-)%s*$")
  if not name or name == "" then return nil, "write it as Name|expression" end
  local fn, err = R.Compile(expr)
  if not fn then return nil, err end
  return { id = "rule:" .. name, label = name, match = fn, src = expr }
end
function R.Validate(item) local r, err = R.ParseRule(item); return r ~= nil, err end

-- Built-in classification (after pins, assignments and user rules).
function R.Builtin(f, opts)
  opts = opts or {}
  if f.quality == 0 and not f.noValue then return "junk" end
  if opts.junk and opts.junk[f.id] then return "junk" end
  if f.keystone then return "keystone" end
  if f.new and opts.showNew ~= false then return "new" end
  if f.sets and #f.sets > 0 then return "sets" end
  local c = f.classID
  if c == R.CLASS.armor or c == R.CLASS.weapon then return "equipment" end
  if c == R.CLASS.consumable then return "consumables" end
  if c == R.CLASS.tradeskill or c == R.CLASS.reagent or c == R.CLASS.gem or c == R.CLASS.enhancement or c == R.CLASS.profession then return "reagents" end
  if c == R.CLASS.questitem or f.quest then return "quest" end
  return "other"
end

-- Category for one item: pin > manual assignment > first matching user rule > built-in.
function R.Classify(f, ctx)
  if ctx.pins and ctx.pins[f.id] then return "pinned" end
  if ctx.assign and ctx.assign[f.id] then return ctx.assign[f.id] end
  for _, rule in ipairs(ctx.rules or {}) do if rule.match(f) then return rule.id end end
  return R.Builtin(f, ctx)
end

-- Ordered sections for a list of (facts, payload) entries:
-- { { id, label, items = { payload... } } } skipping hidden and empty ones.
function R.Group(entries, ctx)
  local buckets, order = {}, {}
  for _, rule in ipairs(ctx.rules or {}) do order[#order + 1] = { id = rule.id, label = rule.label } end
  for _, c in ipairs(R.BUILTIN) do order[#order + 1] = c end
  for _, e in ipairs(entries) do
    local id = R.Classify(e.facts, ctx)
    buckets[id] = buckets[id] or {}
    table.insert(buckets[id], e)
  end
  local out = {}
  for _, c in ipairs(order) do
    local list = buckets[c.id]
    if list and #list > 0 and not (ctx.hidden and ctx.hidden[c.id]) then
      if ctx.sortWithin then table.sort(list, ctx.sortWithin) end
      out[#out + 1] = { id = c.id, label = c.label, items = list }
    end
  end
  return out
end

-- Search box: plain words use the game's search; text with an operator or
-- "field:value" is a Phoenix rule expression.
function R.SearchMode(text)
  if type(text) ~= "string" or text == "" then return "none" end
  if text:find("[<>=~]") or text:match("^%a+:%S") or text:find("%s:%S") then return "rule" end
  return "plain"
end
