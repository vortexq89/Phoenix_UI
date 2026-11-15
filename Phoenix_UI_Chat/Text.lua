local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Chat text helpers (pure; no frames, no state beyond their arguments) so
-- every rule is unit-tested offline. Callers only hand plain strings here:
-- the chat filter returns early for secret arguments before any of these run.
local _, ns = ...
local T = {}
ns.Text = T

-- Escapes every Lua pattern magic character (WAPI: every text-built pattern).
function T.Escape(text) return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- Turns a Blizzard format string ("%s has joined the battle.") into a
-- capture pattern; nil when the string is missing.
function T.FormatToPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local p = T.Escape(fmt)
  p = p:gsub("%%%%%d?%$?s", "(.+)"):gsub("%%%%%d?%$?d", "(%%d+)")
  return "^" .. p .. "$"
end

-- UTF-8 safe truncation: never cuts a multi-byte character in half.
function T.Truncate(text, maxBytes)
  if #text <= maxBytes then return text end
  local cut = maxBytes
  while cut > 0 do
    local b = text:byte(cut + 1)
    if not b or b < 0x80 or b >= 0xC0 then break end
    cut = cut - 1
  end
  return text:sub(1, cut)
end

-- Links and colour codes are left alone: URL and keyword passes only touch
-- text outside |H...|h...|h and |c...|r runs.
local function eachPlainRun(msg, fn)
  local out, pos = {}, 1
  while pos <= #msg do
    local a = msg:find("|[Hc]", pos)
    if not a then out[#out + 1] = fn(msg:sub(pos)); break end
    if a > pos then out[#out + 1] = fn(msg:sub(pos, a - 1)) end
    local kind = msg:sub(a + 1, a + 1)
    local b
    if kind == "H" then
      local _, e = msg:find("|h.-|h", a)
      b = e
    else
      local _, e = msg:find("|r", a, true)
      b = e
    end
    b = b or #msg
    out[#out + 1] = msg:sub(a, b)
    pos = b + 1
  end
  return table.concat(out)
end
T.EachPlainRun = eachPlainRun

-- URLs: scheme links, www. hosts and bare domains with a path or a common TLD.
local URL_PATTERNS = {
  "%f[%S]https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
  "%f[%S]www%.[%w%-]+%.[%w%-%._~:/%?#@!%$&%*%+,;=%%]+",
  "%f[%S][%w%-]+%.[%w%-]+%.?[%w%-]*/[%w%-%._~:/%?#@!%$&%*%+,;=%%]*",
  "%f[%S][%w%-]+%.com%f[%A]", "%f[%S][%w%-]+%.io%f[%A]", "%f[%S][%w%-]+%.gg%f[%A]", "%f[%S][%w%-]+%.net%f[%A]",
  "%f[%S][%w%-]+%.org%f[%A]", "%f[%S]%d+%.%d+%.%d+%.%d+:?%d*/?[%w%-%._~:/%?#@%%]*",
}
T.LINK_PREFIX = "addon:PhoenixUI:"

function T.FindURLs(text)
  local found, seen = {}, {}
  for _, p in ipairs(URL_PATTERNS) do
    local init = 1
    while true do
      local a, b = text:find(p, init)
      if not a then break end
      local url = text:sub(a, b):gsub("[%.,;:!%?%)]+$", "")
      local covered = false
      for _, f in ipairs(found) do if a >= f.a and a <= f.b then covered = true end end
      if not covered and not seen[url] and #url > 4 then
        seen[url] = true
        found[#found + 1] = { a = a, b = a + #url - 1, url = url }
      end
      init = b + 1
    end
  end
  table.sort(found, function(x, y) return x.a < y.a end)
  return found
end

function T.LinkURLs(msg, color)
  return eachPlainRun(msg, function(run)
    local list = T.FindURLs(run)
    if #list == 0 then return run end
    local out, pos = {}, 1
    for _, f in ipairs(list) do
      out[#out + 1] = run:sub(pos, f.a - 1)
      out[#out + 1] = "|cff" .. color .. "|H" .. T.LINK_PREFIX .. "url:" .. f.url:gsub("|", "") .. "|h[" .. f.url .. "]|h|r"
      pos = f.b + 1
    end
    out[#out + 1] = run:sub(pos)
    return table.concat(out)
  end)
end

-- Keywords: comma separated, case-insensitive, plain text. Returns the
-- highlighted message and whether anything matched.
function T.ParseKeywords(text)
  local list = {}
  for w in (text or ""):gmatch("[^,]+") do
    w = w:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if w ~= "" then list[#list + 1] = w end
  end
  return list
end

function T.Highlight(msg, keywords, color)
  if #keywords == 0 then return msg, false end
  local hit = false
  local out = eachPlainRun(msg, function(run)
    local lower = run:lower()
    for _, k in ipairs(keywords) do
      local a, b = lower:find(k, 1, true)
      if a then
        hit = true
        if color then
          run = run:sub(1, a - 1) .. "|cff" .. color .. run:sub(a, b) .. "|r" .. run:sub(b + 1)
          lower = run:lower()
        end
      end
    end
    return run
  end)
  return out, hit
end

-- Channel names: "2. Trade - City" -> by style.
T.CHANNEL_SHORT = { General = "G", Trade = "T", LocalDefense = "LD", ["Local Defense"] = "LD", LookingForGroup = "LFG",
  ["Looking For Group"] = "LFG", Services = "S", ["Trade (Services)"] = "S", NewcomerChat = "N", ["Newcomer Chat"] = "N",
  WorldDefense = "WD", ["World Defense"] = "WD" }
function T.ShortChannel(channelString, style)
  if style == "full" or type(channelString) ~= "string" then return channelString end
  local num, name = channelString:match("^(%d+)%.%s*(.+)$")
  if not num then return channelString end
  if style == "number" then return num end
  local base = name:match("^(.-)%s+%-%s+.+$") or name
  local short = T.CHANNEL_SHORT[base] or base:gsub("[^%u%d]", ""):sub(1, 3)
  if short == "" then short = base:sub(1, 3) end
  return num .. ". " .. short
end

-- Emoji: :name: codes. Art comes from textures that ship with the game (raid
-- markers and role icons); Phoenix's own set joins from the media library.
T.EMOJI = {
  { name = "star", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
  { name = "circle", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
  { name = "diamond", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
  { name = "triangle", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
  { name = "moon", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
  { name = "square", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
  { name = "cross", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
  { name = "skull", tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
  { name = "tank", atlas = "groupfinder-icon-role-large-tank" },
  { name = "healer", atlas = "groupfinder-icon-role-large-heal" },
  { name = "dps", atlas = "groupfinder-icon-role-large-dps" },
  { name = "gold", tex = "Interface\\MoneyFrame\\UI-GoldIcon" },
  { name = "check", tex = "Interface\\RaidFrame\\ReadyCheck-Ready" },
  { name = "wait", tex = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
  { name = "no", tex = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}
T.EMOJI_BY = {}
for _, e in ipairs(T.EMOJI) do T.EMOJI_BY[e.name] = e end
T.BASE_EMOJI = #T.EMOJI

-- Phoenix emoji art (review gaps): original faces and objects from Phoenix_UI_Media,
-- added after the game-texture set when chat.phoenixEmoji is on.
function T.SetPhoenixEmoji(on)
  for i = #T.EMOJI, T.BASE_EMOJI + 1, -1 do T.EMOJI_BY[T.EMOJI[i].name] = nil; T.EMOJI[i] = nil end
  if on and PUI.Look and C_AddOns.IsAddOnLoaded("Phoenix_UI_Media") then
    for _, name in ipairs(PUI.Look.EMOJI) do
      local e = { name = name, tex = PUI.Look.EmojiPath(name), phoenix = true }
      T.EMOJI[#T.EMOJI + 1] = e
      T.EMOJI_BY[name] = e
    end
  end
  return #T.EMOJI - T.BASE_EMOJI
end

function T.EmojiMarkup(e, size)
  if e.atlas then return "|A:" .. e.atlas .. ":" .. size .. ":" .. size .. "|a" end
  return "|T" .. e.tex .. ":" .. size .. "|t"
end

function T.ReplaceEmoji(msg, size)
  return eachPlainRun(msg, function(run)
    return (run:gsub(":(%a+):", function(name)
      local e = T.EMOJI_BY[name:lower()]
      return e and T.EmojiMarkup(e, size) or nil
    end))
  end)
end

-- Autocomplete: the open ":abc" at the end of what is being typed.
function T.EmojiPrefix(text)
  if type(text) ~= "string" then return nil end
  local p = text:match(":(%a+)$")
  if p and #p >= 1 then return p:lower() end
  return nil
end
function T.CompleteEmoji(prefix, max)
  local out = {}
  if not prefix then return out end
  for _, e in ipairs(T.EMOJI) do
    if e.name:sub(1, #prefix) == prefix then out[#out + 1] = e.name end
    if #out >= (max or 6) then break end
  end
  return out
end
function T.InsertEmoji(text, name)
  return (text:gsub(":%a+$", ":" .. name .. ": "))
end

-- Spam: the same author repeating the same text inside `window` seconds.
function T.IsRepeat(seen, author, msg, now, window)
  local k = author .. "\0" .. msg
  local last = seen[k]
  seen[k] = now
  return last ~= nil and now - last < window
end

-- Battleground join/leave summary line.
function T.BGSummary(joined, left)
  local parts = {}
  if #joined > 0 then parts[#parts + 1] = #joined .. " joined" end
  if #left > 0 then parts[#parts + 1] = #left .. " left" end
  if #parts == 0 then return nil end
  return "Battleground: " .. table.concat(parts, ", ")
end

-- History search: every filter optional. q matches text or author (plain,
-- case-insensitive); channel matches the stored channel id; player the author;
-- from/to are unix times.
function T.Match(e, f)
  if f.channel and f.channel ~= "" and e.ch ~= f.channel then return false end
  if f.player and f.player ~= "" and not (e.author or ""):lower():find(f.player:lower(), 1, true) then return false end
  if f.from and e.t < f.from then return false end
  if f.to and e.t > f.to then return false end
  if f.q and f.q ~= "" then
    local q = f.q:lower()
    if not (e.text:lower():find(q, 1, true) or (e.author or ""):lower():find(q, 1, true)) then return false end
  end
  return true
end
function T.Search(list, f, limit)
  local out = {}
  for i = #list, 1, -1 do
    local e = list[i]
    if T.Match(e, f) then out[#out + 1] = e; if limit and #out >= limit then break end end
  end
  return out
end
