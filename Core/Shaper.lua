local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Shaper: Arabic for a text engine that neither joins letters nor lays out
-- right-to-left. WoW draws code points one by one, left to right, so Arabic
-- text is converted before it reaches a FontString:
--  1. shaping: each letter becomes its Unicode presentation form (isolated,
--     final, initial or medial) from its neighbours' joining types, and
--     lam + alef become one ligature; harakat are transparent;
--  2. visual order: each line is laid out right to left. Runs of Latin,
--     digits, format tokens (%s, %d, %.1f) and escapes (|T..|t, |A..|a,
--     |H..|h..|h, |n) keep their own left-to-right order; colour spans
--     |c..|r are laid out on their own and stay balanced; brackets mirror.
-- Long lines are broken at spaces first (Shaper.WRAP characters), because the
-- engine would otherwise wrap a reversed line bottom-up.
-- Pure string code: no frames, no OnUpdate.
local Shaper = { WRAP = 64 }
PUI.Shaper = Shaper

-- UTF-8 ---------------------------------------------------------------------------------------------
local byte, char, floor = string.byte, string.char, math.floor
local function decode(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = byte(s, i)
    if c < 0x80 then out[#out + 1] = c; i = i + 1
    elseif c >= 0xF0 and i + 3 <= n then out[#out + 1] = (c - 0xF0) * 0x40000 + (byte(s, i + 1) - 0x80) * 0x1000 + (byte(s, i + 2) - 0x80) * 0x40 + byte(s, i + 3) - 0x80; i = i + 4
    elseif c >= 0xE0 and i + 2 <= n then out[#out + 1] = (c - 0xE0) * 0x1000 + (byte(s, i + 1) - 0x80) * 0x40 + byte(s, i + 2) - 0x80; i = i + 3
    elseif c >= 0xC0 and i + 1 <= n then out[#out + 1] = (c - 0xC0) * 0x40 + byte(s, i + 1) - 0x80; i = i + 2
    else out[#out + 1] = 0xFFFD; i = i + 1 end
  end
  return out
end
local function encode(cp)
  if cp < 0x80 then return char(cp) end
  if cp < 0x800 then return char(0xC0 + floor(cp / 0x40), 0x80 + cp % 0x40) end
  if cp < 0x10000 then return char(0xE0 + floor(cp / 0x1000), 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40) end
  return char(0xF0 + floor(cp / 0x40000), 0x80 + floor(cp / 0x1000) % 0x40, 0x80 + floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end
Shaper.decode, Shaper.encode = decode, encode

-- Forms ---------------------------------------------------------------------------------------------
-- [letter] = { isolated, final, initial, medial }; two entries = joins on the right only.
local FORMS = {
  [0x0621] = { 0xFE80 },
  [0x0622] = { 0xFE81, 0xFE82 }, [0x0623] = { 0xFE83, 0xFE84 }, [0x0624] = { 0xFE85, 0xFE86 },
  [0x0625] = { 0xFE87, 0xFE88 }, [0x0627] = { 0xFE8D, 0xFE8E }, [0x0629] = { 0xFE93, 0xFE94 },
  [0x062F] = { 0xFEA9, 0xFEAA }, [0x0630] = { 0xFEAB, 0xFEAC }, [0x0631] = { 0xFEAD, 0xFEAE },
  [0x0632] = { 0xFEAF, 0xFEB0 }, [0x0648] = { 0xFEED, 0xFEEE }, [0x0649] = { 0xFEEF, 0xFEF0 },
  [0x0698] = { 0xFB8A, 0xFB8B },
}
-- Dual-joining letters with four consecutive forms starting at the isolated one.
for cp, iso in pairs({ [0x0626] = 0xFE89, [0x0628] = 0xFE8F, [0x062A] = 0xFE95, [0x062B] = 0xFE99, [0x062C] = 0xFE9D,
  [0x062D] = 0xFEA1, [0x062E] = 0xFEA5, [0x0633] = 0xFEB1, [0x0634] = 0xFEB5, [0x0635] = 0xFEB9, [0x0636] = 0xFEBD,
  [0x0637] = 0xFEC1, [0x0638] = 0xFEC5, [0x0639] = 0xFEC9, [0x063A] = 0xFECD, [0x0641] = 0xFED1, [0x0642] = 0xFED5,
  [0x0643] = 0xFED9, [0x0644] = 0xFEDD, [0x0645] = 0xFEE1, [0x0646] = 0xFEE5, [0x0647] = 0xFEE9, [0x064A] = 0xFEF1 }) do
  FORMS[cp] = { iso, iso + 1, iso + 2, iso + 3 }
end
-- Persian/Urdu extras (presentation forms order: isolated, final, initial, medial).
for cp, iso in pairs({ [0x067E] = 0xFB56, [0x0686] = 0xFB7A, [0x06A9] = 0xFB8E, [0x06AF] = 0xFB92, [0x06CC] = 0xFBFC }) do
  FORMS[cp] = { iso, iso + 1, iso + 2, iso + 3 }
end
local TATWEEL = 0x0640
-- lam + alef variant -> { isolated, final } ligature.
local LAM, LAMALEF = 0x0644, { [0x0622] = { 0xFEF5, 0xFEF6 }, [0x0623] = { 0xFEF7, 0xFEF8 }, [0x0625] = { 0xFEF9, 0xFEFA }, [0x0627] = { 0xFEFB, 0xFEFC } }
local function transparent(cp) return (cp >= 0x064B and cp <= 0x065F) or cp == 0x0670 or (cp >= 0x06D6 and cp <= 0x06ED) end
local function dual(cp) return cp == TATWEEL or (FORMS[cp] and #FORMS[cp] == 4) end
local function joins(cp) return cp == TATWEEL or (FORMS[cp] and #FORMS[cp] >= 2) end
Shaper.FORMS = FORMS

-- Shapes a logical-order code point list in place of letters (returns a new list).
function Shaper.ShapeCodes(cps)
  local out, n, i = {}, #cps, 1
  local function neighbour(from, step)
    local j = from + step
    while j >= 1 and j <= n and transparent(cps[j]) do j = j + step end
    return cps[j], j
  end
  while i <= n do
    local cp = cps[i]
    local forms = FORMS[cp]
    if not forms then out[#out + 1] = cp; i = i + 1
    else
      local prev = neighbour(i, -1)
      local linkPrev = prev and dual(prev) and #forms >= 2
      local nxt, nj = neighbour(i, 1)
      local lig = cp == LAM and nxt and LAMALEF[nxt]
      if lig then
        out[#out + 1] = lig[linkPrev and 2 or 1]
        for k = i + 1, nj - 1 do out[#out + 1] = cps[k] end
        i = nj + 1
      else
        local linkNext = #forms == 4 and nxt and joins(nxt)
        local f = (linkPrev and linkNext and 4) or (linkNext and 3) or (linkPrev and 2) or 1
        out[#out + 1] = forms[f] or forms[1]
        i = i + 1
      end
    end
  end
  return out
end

function Shaper.Shape(s)
  local cps, buf = Shaper.ShapeCodes(decode(s)), {}
  for i = 1, #cps do buf[i] = encode(cps[i]) end
  return table.concat(buf)
end

-- Bidi (simplified, RTL paragraph) ------------------------------------------------------------------
local function isArabic(cp) return (cp >= 0x0600 and cp <= 0x06FF and not (cp >= 0x0660 and cp <= 0x0669) and not (cp >= 0x06F0 and cp <= 0x06F9))
  or (cp >= 0x0750 and cp <= 0x077F) or (cp >= 0xFB50 and cp <= 0xFDFF) or (cp >= 0xFE70 and cp <= 0xFEFF) end
local function isLTR(cp)
  return (cp >= 0x30 and cp <= 0x39) or (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A) or (cp >= 0xC0 and cp < 0x0600 and cp ~= 0xD7 and cp ~= 0xF7)
    or (cp >= 0x0660 and cp <= 0x0669) or (cp >= 0x06F0 and cp <= 0x06F9) or cp >= 0x0800 and not isArabic(cp) and cp ~= 0x2026 and not (cp >= 0x2000 and cp <= 0x206F)
end
-- Characters that sit inside a Latin/number run when it continues after them (12.4, 1,200, a-b, 50%).
local JOINERS = { [0x2E] = true, [0x2C] = true, [0x3A] = true, [0x2D] = true, [0x2F] = true, [0x5F] = true, [0x27] = true, [0x2B] = true, [0x25] = true }
local MIRROR = { [0x28] = 0x29, [0x29] = 0x28, [0x5B] = 0x5D, [0x5D] = 0x5B, [0x7B] = 0x7D, [0x7D] = 0x7B, [0x3C] = 0x3E, [0x3E] = 0x3C, [0xAB] = 0xBB, [0xBB] = 0xAB }

-- Splits one line into items { text, kind } with kind "R" (Arabic char), "L" (left-to-right char
-- or token), "N" (neutral char) or "S" (colour span, already laid out).
local tokenize
local function layout(items)
  -- Group L items with the neutrals/joiners between them into runs; everything else is single.
  local units, i, n = {}, 1, #items
  while i <= n do
    local it = items[i]
    -- a sign or slash glued to the front of a run (/pui, -5, +3) belongs to it
    if it.kind == "N" and it.join and items[i + 1] and items[i + 1].kind == "L" then it = { kind = "L", text = it.text }; items[i] = it end
    if it.kind == "L" then
      local j, last = i, i
      while j + 1 <= n do
        local nx = items[j + 1]
        if nx.kind == "L" then j = j + 1; last = j
        elseif nx.kind == "N" and (nx.join or nx.cp == 0x20) then
          local k = j + 1
          while k <= n and items[k].kind == "N" and (items[k].join or items[k].cp == 0x20) do k = k + 1 end
          if k <= n and items[k].kind == "L" then j = k; last = k else break end
        else break end
      end
      local buf = {}
      for k = i, last do buf[#buf + 1] = items[k].text end
      -- a trailing %/joiner glued to a number (50%) stays in the run
      while last + 1 <= n and items[last + 1].kind == "N" and items[last + 1].cp == 0x25 do last = last + 1; buf[#buf + 1] = "%" end
      units[#units + 1] = table.concat(buf)
      i = last + 1
    else
      local t = it.text
      if it.kind == "N" and it.cp and MIRROR[it.cp] then t = encode(MIRROR[it.cp]) end
      units[#units + 1] = t
      i = i + 1
    end
  end
  local out = {}
  for k = #units, 1, -1 do out[#out + 1] = units[k] end
  return table.concat(out)
end

tokenize = function(s)
  local items, i, n = {}, 1, #s
  local pending = {}
  local function flush()
    if #pending == 0 then return end
    local cps = Shaper.ShapeCodes(pending)
    for k = 1, #cps do
      local cp = cps[k]
      local kind = isArabic(cp) and "R" or isLTR(cp) and "L" or "N"
      items[#items + 1] = { text = encode(cp), kind = kind, cp = cp, join = JOINERS[cp] }
    end
    pending = {}
  end
  while i <= n do
    local c = s:sub(i, i)
    if c == "|" and i < n then
      local d = s:sub(i + 1, i + 1)
      local tok, e
      if d == "c" then
        local close = s:find("|r", i + 10, true)
        if close then
          flush()
          items[#items + 1] = { text = s:sub(i, i + 9) .. layout(tokenize(s:sub(i + 10, close - 1))) .. "|r", kind = "S" }
          i = close + 2
        else tok = s:sub(i, i + 9); e = i + 9 end
      elseif d == "T" or d == "A" then
        local close = s:find(d == "T" and "|t" or "|a", i + 2, true)
        e = close and close + 1 or n; tok = s:sub(i, e)
      elseif d == "H" then
        local a = s:find("|h", i + 2, true)
        local b = a and s:find("|h", a + 2, true)
        e = b and b + 1 or n; tok = s:sub(i, e)
      else
        e = i + 1; tok = s:sub(i, e)
      end
      if tok then flush(); items[#items + 1] = { text = tok, kind = "L" }; i = e + 1 end
    elseif c == "%" then
      local spec = s:match("^%%%d+%$[%-%+ #0]*%d*%.?%d*[sdifgxXcq]", i) or s:match("^%%[%-%+ #0]*%d*%.?%d*[sdifgxXcq%%]", i)
      if spec then flush(); items[#items + 1] = { text = spec, kind = spec == "%%" and "N" or "L", cp = spec == "%%" and 0x25 or nil }; i = i + #spec
      else pending[#pending + 1] = 0x25; i = i + 1 end
    else
      local b = byte(s, i)
      local len = b < 0x80 and 1 or b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
      local cps = decode(s:sub(i, i + len - 1))
      pending[#pending + 1] = cps[1]
      i = i + len
    end
  end
  flush()
  return items
end

-- Breaks a logical line at spaces so no piece is longer than width characters.
local function wrap(line, width)
  if not width or width <= 0 or #decode(line) <= width then return { line } end
  local out, cur, curLen = {}, {}, 0
  for word in line:gmatch("%S+") do
    local wl = #decode(word)
    if curLen > 0 and curLen + 1 + wl > width then out[#out + 1] = table.concat(cur, " "); cur, curLen = {}, 0 end
    cur[#cur + 1] = word; curLen = curLen + (curLen > 0 and 1 or 0) + wl
  end
  if #cur > 0 then out[#out + 1] = table.concat(cur, " ") end
  return out
end

-- Logical Arabic text -> what the engine must draw. width: wrap length (nil: Shaper.WRAP, 0: none).
function Shaper.Visual(s, width)
  if type(s) ~= "string" or s == "" then return s end
  if not s:find("[\216-\219\239]") then return s end -- no Arabic bytes: unchanged
  width = width == nil and Shaper.WRAP or width
  -- Right-to-left order reverses the format specs, so with two or more they
  -- become positional (%1$s, %2$d), which the game's string.format reads.
  local specs = 0
  for spec in s:gmatch("%%[%-%+ #0]*%d*%.?%d*[sdifgxXcq%%]") do if spec ~= "%%" then specs = specs + 1 end end
  if specs > 1 and not s:find("%%%d+%$") then
    local k = 0
    s = s:gsub("%%([%-%+ #0]*%d*%.?%d*[sdifgxXcq%%])", function(body)
      if body == "%" then return "%%" end
      k = k + 1
      return "%" .. k .. "$" .. body
    end)
  end
  local lines = {}
  for line in (s .. "\n"):gmatch("(.-)\n") do
    for _, piece in ipairs(wrap(line, width)) do lines[#lines + 1] = layout(tokenize(piece)) end
  end
  return table.concat(lines, "\n")
end

-- True when s holds Arabic letters.
function Shaper.HasArabic(s)
  for _, cp in ipairs(decode(s)) do if isArabic(cp) then return true end end
  return false
end
