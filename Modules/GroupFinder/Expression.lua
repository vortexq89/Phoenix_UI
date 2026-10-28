local _, ns = ...

--[[ The Phoenix filter language for the group list: a small expression grammar with its own tokenizer, parser
    and evaluator (no loadstring, AGENTS rule 4). It is a clean-room design: the idea of typing a filter such as
    `tanks == 0 and score >= 2000` is common to group-finder addons, the grammar, words and code are ours.

      expr   := or
      or     := and { ("or" | "||") and }
      and    := not { ("and" | "&&") not }
      not    := ("not" | "!") not | cmp
      cmp    := sum [ ("==" | "=" | "~=" | "!=" | "<" | "<=" | ">" | ">=") sum ]
      sum    := term { ("+" | "-") term }
      term   := unary { ("*" | "/") unary }
      unary  := "-" unary | atom
      atom   := number | word | "true" | "false" | "(" expr ")"

    Words name fields of a group record (GroupFinder.lua M.WORDS). Booleans count as 1/0 in arithmetic, so
    `tanks + heals >= 2` works. A field the game did not give us (missing, or secret during a chat lockdown)
    reads as unknown: any comparison with it passes, so a group is never hidden for data we could not see. ]]
local X = {}
ns.GroupFinderExpression = X

local UNKNOWN = {} -- sentinel: a value we could not read

local function num(v)
    if v == true then return 1 elseif v == false or v == nil then return 0 end
    return v
end

---------------------------------------------------------------- tokenizer
local OPS = { "==", "~=", "!=", "<=", ">=", "&&", "||", "<", ">", "=", "+", "-", "*", "/", "(", ")", "!" }
local ALIAS = { ["&&"] = "and", ["||"] = "or", ["!"] = "not", ["!="] = "~=", ["="] = "==" }

function X.Tokenize(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("%d") or (c == "." and text:sub(i + 1, i + 1):match("%d")) then
            local s, e = text:find("^%d*%.?%d+", i)
            out[#out + 1] = { kind = "num", value = tonumber((text:sub(s, e))), pos = i }
            i = e + 1
        elseif c:match("[%a_]") then
            local s, e = text:find("^[%a_][%w_]*", i)
            local word = text:sub(s, e):lower()
            if word == "and" or word == "or" or word == "not" then
                out[#out + 1] = { kind = "op", value = word, pos = i }
            elseif word == "true" or word == "false" then
                out[#out + 1] = { kind = "bool", value = word == "true", pos = i }
            else
                out[#out + 1] = { kind = "word", value = word, pos = i }
            end
            i = e + 1
        else
            local hit
            for _, op in ipairs(OPS) do
                if text:sub(i, i + #op - 1) == op then hit = op; break end
            end
            if not hit then return nil, { "char", c, i } end
            out[#out + 1] = { kind = "op", value = ALIAS[hit] or hit, pos = i }
            i = i + #hit
        end
    end
    return out
end

---------------------------------------------------------------- parser -> closures
local CMP = { ["=="] = true, ["~="] = true, ["<"] = true, ["<="] = true, [">"] = true, [">="] = true }

local function compare(op, a, b)
    if a == UNKNOWN or b == UNKNOWN then return true end
    if type(a) == "boolean" or type(b) == "boolean" then
        if op == "==" then return num(a) == num(b) elseif op == "~=" then return num(a) ~= num(b) end
        a, b = num(a), num(b)
    end
    if op == "==" then return a == b elseif op == "~=" then return a ~= b
    elseif op == "<" then return a < b elseif op == "<=" then return a <= b
    elseif op == ">" then return a > b else return a >= b end
end

local function arith(op, a, b)
    if a == UNKNOWN or b == UNKNOWN then return UNKNOWN end
    a, b = num(a), num(b)
    if op == "+" then return a + b elseif op == "-" then return a - b elseif op == "*" then return a * b end
    if b == 0 then return UNKNOWN end
    return a / b
end

local function truthy(v)
    if v == UNKNOWN then return true end
    if type(v) == "number" then return v ~= 0 end
    return v and true or false
end

-- words: set of known field names. Returns fn(record) -> bool, or nil + { reason, detail, position }.
function X.Compile(text, words)
    if type(text) ~= "string" or text:match("^%s*$") then return nil end
    local tokens, err = X.Tokenize(text)
    if not tokens then return nil, err end
    local pos = 1
    local function peek() return tokens[pos] end
    local function isOp(v) local t = tokens[pos]; return t and t.kind == "op" and t.value == v end
    local parseOr

    local function atom()
        local t = tokens[pos]
        if not t then error({ "end" }, 0) end
        pos = pos + 1
        if t.kind == "num" then local v = t.value; return function() return v end end
        if t.kind == "bool" then local v = t.value; return function() return v end end
        if t.kind == "word" then
            if words and not words[t.value] then error({ "word", t.value, t.pos }, 0) end
            local key = t.value
            return function(r)
                local v = r[key]
                if v == nil then return UNKNOWN end
                return v
            end
        end
        if t.kind == "op" and t.value == "(" then
            local inner = parseOr()
            if not isOp(")") then error({ "paren", nil, t.pos }, 0) end
            pos = pos + 1
            return inner
        end
        error({ "token", t.value, t.pos }, 0)
    end
    local function unary()
        if isOp("-") then
            pos = pos + 1
            local f = unary()
            return function(r) local v = f(r); if v == UNKNOWN then return v end return -num(v) end
        end
        return atom()
    end
    local function term()
        local left = unary()
        while isOp("*") or isOp("/") do
            local op = peek().value; pos = pos + 1
            local l, r2 = left, unary()
            left = function(r) return arith(op, l(r), r2(r)) end
        end
        return left
    end
    local function sum()
        local left = term()
        while isOp("+") or isOp("-") do
            local op = peek().value; pos = pos + 1
            local l, r2 = left, term()
            left = function(r) return arith(op, l(r), r2(r)) end
        end
        return left
    end
    local function cmp()
        local left = sum()
        local t = peek()
        if t and t.kind == "op" and CMP[t.value] then
            pos = pos + 1
            local op, l, r2 = t.value, left, sum()
            return function(r) return compare(op, l(r), r2(r)) end
        end
        return left
    end
    local function parseNot()
        if isOp("not") then
            pos = pos + 1
            local f = parseNot()
            return function(r) local v = f(r); if v == UNKNOWN then return true end return not truthy(v) end
        end
        return cmp()
    end
    local function parseAnd()
        local left = parseNot()
        while isOp("and") do
            pos = pos + 1
            local l, r2 = left, parseNot()
            left = function(r) return truthy(l(r)) and truthy(r2(r)) end
        end
        return left
    end
    parseOr = function()
        local left = parseAnd()
        while isOp("or") do
            pos = pos + 1
            local l, r2 = left, parseAnd()
            left = function(r) return truthy(l(r)) or truthy(r2(r)) end
        end
        return left
    end

    local ok, result = pcall(parseOr)
    if not ok then
        if type(result) == "table" then return nil, result end
        return nil, { "token", tostring(result) }
    end
    if pos <= #tokens then return nil, { "token", tokens[pos].value, tokens[pos].pos } end
    local fn = result
    return function(record) return truthy(fn(record)) end
end

X.UNKNOWN = UNKNOWN
