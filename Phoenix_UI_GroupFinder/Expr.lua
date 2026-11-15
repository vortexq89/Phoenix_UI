local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Group Finder filter expressions (plan 5.16, PGF parity built better). A
-- small, original expression language over plain numbers and booleans that
-- Phoenix derives from each search result:
--   mprating >= 2600 and tanks == 1 and not declined
--   (arakara or priory) and partyfit and age <= 15
-- Grammar: or -> and ('or' and)* ; and -> not ('and' not)* ;
--   not -> 'not' not | cmp ; cmp -> sum (op sum)? ; sum -> term (('+'|'-') term)* ;
--   term -> atom (('*'|'/') atom)* ; atom -> number | name | true | false | '(' or ')'
-- Operators: < <= > >= == = ~= != . Booleans count as 1/0 in maths.
-- Compile(text) -> fn(vars) or nil, message, position. Unknown names are
-- reported (with a suggestion) instead of silently matching nothing. Pure:
-- no game calls, so the whole language is covered by offline tests.
local _, ns = ...
local Expr = { names = {}, order = {} }
ns.Expr = Expr

-- Keyword registry: every name the language knows, with a help line. The
-- help panel, autocomplete and validation all read this one table.
function Expr.Define(name, help, group)
  if not Expr.names[name] then Expr.order[#Expr.order + 1] = name end
  Expr.names[name] = { name = name, help = help or "", group = group or "group" }
end
function Expr.Undefine(name)
  if not Expr.names[name] then return end
  Expr.names[name] = nil
  for i = #Expr.order, 1, -1 do if Expr.order[i] == name then table.remove(Expr.order, i) end end
end

local function lex(text)
  local toks, i, n = {}, 1, #text
  while i <= n do
    local c = text:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("%d") then
      local num = text:match("^%d+%.?%d*", i)
      toks[#toks + 1] = { k = "num", v = tonumber(num), p = i }
      i = i + #num
    elseif c:match("[%a_]") then
      local word = text:match("^[%w_]+", i)
      local lower = word:lower()
      if lower == "and" or lower == "or" or lower == "not" then toks[#toks + 1] = { k = lower, p = i }
      elseif lower == "true" or lower == "false" then toks[#toks + 1] = { k = "bool", v = lower == "true", p = i }
      else toks[#toks + 1] = { k = "name", v = lower, p = i } end
      i = i + #word
    else
      local two = text:sub(i, i + 1)
      if two == "<=" or two == ">=" or two == "==" or two == "~=" or two == "!=" then
        toks[#toks + 1] = { k = "op", v = two == "!=" and "~=" or two, p = i }; i = i + 2
      elseif c == "<" or c == ">" then toks[#toks + 1] = { k = "op", v = c, p = i }; i = i + 1
      elseif c == "=" then toks[#toks + 1] = { k = "op", v = "==", p = i }; i = i + 1
      elseif c == "+" or c == "-" or c == "*" or c == "/" or c == "(" or c == ")" then toks[#toks + 1] = { k = c, p = i }; i = i + 1
      else return nil, "unexpected '" .. c .. "'", i end
    end
  end
  toks[#toks + 1] = { k = "eof", p = n + 1 }
  return toks
end

local function num(v) if v == true then return 1 elseif v == false or v == nil then return 0 end return v end
local function truthy(v) return v ~= nil and v ~= false and v ~= 0 end

local CMP = {
  ["<"] = function(a, b) return num(a) < num(b) end, ["<="] = function(a, b) return num(a) <= num(b) end,
  [">"] = function(a, b) return num(a) > num(b) end, [">="] = function(a, b) return num(a) >= num(b) end,
  ["=="] = function(a, b) return num(a) == num(b) end, ["~="] = function(a, b) return num(a) ~= num(b) end,
}

-- Closest known name (edit distance) for "did you mean".
local function distance(a, b)
  local prev = {}
  for j = 0, #b do prev[j] = j end
  for i = 1, #a do
    local cur = { [0] = i }
    for j = 1, #b do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[#b]
end
function Expr.Suggest(word)
  local best, bestD
  for _, name in ipairs(Expr.order) do
    local d = distance(word, name)
    if not bestD or d < bestD then best, bestD = name, d end
  end
  if bestD and bestD <= math.max(2, math.floor(#word / 3)) then return best end
end

function Expr.Compile(text)
  if type(text) ~= "string" or text:match("^%s*$") then return function() return true end end
  local toks, err, at = lex(text)
  if not toks then return nil, err, at end
  local pos = 1
  local function peek() return toks[pos] end
  local function take() pos = pos + 1; return toks[pos - 1] end
  local parseOr
  -- First error wins; parsing continues on a dummy node so no error() is needed.
  local perr
  local function nothing() return nil end
  local function fail(msg, t) if not perr then perr = { msg = msg, p = (t or peek()).p } end return nothing end
  local function atom()
    local t = take()
    if t.k == "num" or t.k == "bool" then local v = t.v; return function() return v end end
    if t.k == "name" then
      if not Expr.names[t.v] then
        local s = Expr.Suggest(t.v)
        return fail("unknown word '" .. t.v .. "'" .. (s and (", did you mean '" .. s .. "'?") or ""), t)
      end
      local name = t.v
      return function(vars) return vars[name] end
    end
    if t.k == "(" then
      local e = parseOr()
      if peek().k ~= ")" then return fail("missing ')'") end
      take()
      return e
    end
    if t.k == "-" then local a = atom(); return function(v) return -num(a(v)) end end
    if t.k == "eof" then pos = pos - 1 end
    return fail(t.k == "eof" and "expression ends too early" or "unexpected '" .. tostring(t.v or t.k) .. "'", t)
  end
  local function term()
    local left = atom()
    while peek().k == "*" or peek().k == "/" do
      local op, a, b = take().k, left, atom()
      if op == "*" then left = function(v) return num(a(v)) * num(b(v)) end
      else left = function(v) local d = num(b(v)); if d == 0 then return 0 end return num(a(v)) / d end end
    end
    return left
  end
  local function sum()
    local left = term()
    while peek().k == "+" or peek().k == "-" do
      local op, a, b = take().k, left, term()
      if op == "+" then left = function(v) return num(a(v)) + num(b(v)) end
      else left = function(v) return num(a(v)) - num(b(v)) end end
    end
    return left
  end
  local function cmp()
    local left = sum()
    if peek().k == "op" then
      local f, a, b = CMP[take().v], left, sum()
      return function(v) return f(a(v), b(v)) end
    end
    return left
  end
  local function parseNot()
    if peek().k == "not" then take(); local a = parseNot(); return function(v) return not truthy(a(v)) end end
    return cmp()
  end
  local function parseAnd()
    local left = parseNot()
    while peek().k == "and" do
      take()
      local a, b = left, parseNot()
      left = function(v) return truthy(a(v)) and truthy(b(v)) end
    end
    return left
  end
  parseOr = function()
    local left = parseAnd()
    while peek().k == "or" do
      take()
      local a, b = left, parseAnd()
      left = function(v) return truthy(a(v)) or truthy(b(v)) end
    end
    return left
  end
  local res = parseOr()
  if peek().k ~= "eof" then fail("unexpected '" .. tostring(peek().v or peek().k) .. "'") end
  if perr then return nil, perr.msg, perr.p end
  return function(vars) return truthy(res(vars)) end
end

-- Validate(text) -> true or false, plain-language message (for the field).
function Expr.Validate(text)
  local fn, msg, at = Expr.Compile(text)
  if fn then return true end
  return false, string.format("%s (at character %d)", msg, at or 1)
end

-- Autocomplete: known names starting with the last word typed.
function Expr.Complete(text, max)
  local word = (text or ""):match("([%w_]*)$"):lower()
  local out = {}
  if word == "" then return out end
  for _, name in ipairs(Expr.order) do
    if name:sub(1, #word) == word and name ~= word then
      out[#out + 1] = name
      if #out >= (max or 8) then break end
    end
  end
  return out
end

-- Help rows, searchable (help panel).
function Expr.Help(query)
  local q = (query or ""):lower()
  local out = {}
  for _, name in ipairs(Expr.order) do
    local e = Expr.names[name]
    if q == "" or name:find(q, 1, true) or e.help:lower():find(q, 1, true) then out[#out + 1] = e end
  end
  return out
end
