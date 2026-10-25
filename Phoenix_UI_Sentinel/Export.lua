local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Export: contract v2 JSON (PUI_V2 17.3) and the "!PUI_SEN" string
-- (JSON -> Deflate -> Base64 via C_EncodingUtil). The JSON writer/reader below
-- is Phoenix's own, deterministic (sorted keys) so exports diff cleanly.
local S = PUI.Sentinel
local Export = { PREFIX = "!PUI_SEN", ARRAY = { __jsonArray = true } }
S.Export = Export

local CONTRACT = 2
local REPORT_KINDS = { error = true, taint = true, secret = true, perf = true, integrity = true, drift = true, heartbeat = true, test = true }

-- JSON writer ---------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function escapeString(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    return ESC[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end

local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true, n
end

local encode
function encode(value, buf)
  local t = type(value)
  if PUI.Secret.IsSecret(value) then
    buf[#buf + 1] = escapeString(PUI.Secret.PLACEHOLDER)
  elseif t == "nil" then
    buf[#buf + 1] = "null"
  elseif t == "boolean" then
    buf[#buf + 1] = value and "true" or "false"
  elseif t == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      buf[#buf + 1] = "null"
    elseif value % 1 == 0 and value > -1e15 and value < 1e15 then
      buf[#buf + 1] = string.format("%d", value)
    else
      buf[#buf + 1] = string.format("%.14g", value)
    end
  elseif t == "string" then
    buf[#buf + 1] = escapeString(value)
  elseif t == "table" then
    local arr, n = isArray(value)
    local mt = getmetatable(value)
    if arr and n == 0 and mt and mt.__jsonArray then
      buf[#buf + 1] = "[]"
    elseif arr and n > 0 then
      buf[#buf + 1] = "["
      for i = 1, n do
        if i > 1 then buf[#buf + 1] = "," end
        encode(value[i], buf)
      end
      buf[#buf + 1] = "]"
    else
      local keys = {}
      for k in pairs(value) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      buf[#buf + 1] = "{"
      for i = 1, #keys do
        if i > 1 then buf[#buf + 1] = "," end
        local k = keys[i]
        local v = value[k]
        if v == nil then v = value[tonumber(k)] end
        buf[#buf + 1] = escapeString(k)
        buf[#buf + 1] = ":"
        encode(v, buf)
      end
      buf[#buf + 1] = "}"
    end
  else
    buf[#buf + 1] = escapeString("<" .. t .. ">")
  end
end

function Export.ToJSON(value)
  local buf = {}
  encode(value, buf)
  return table.concat(buf)
end

-- JSON reader -----------------------------------------------------------------
local decodeValue
local function skip(s, i)
  local _, e = s:find("^[ \n\r\t]*", i)
  return e + 1
end

local UNESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
local function decodeString(s, i)
  local buf, j = {}, i + 1
  while true do
    local c = s:sub(j, j)
    if c == "" then error("unterminated string at " .. i) end
    if c == '"' then return table.concat(buf), j + 1 end
    if c == "\\" then
      local n = s:sub(j + 1, j + 1)
      if n == "u" then
        local code = tonumber(s:sub(j + 2, j + 5), 16)
        if not code then error("bad unicode escape at " .. j) end
        buf[#buf + 1] = code < 128 and string.char(code) or "?"
        j = j + 6
      else
        local r = UNESC[n]
        if not r then error("bad escape at " .. j) end
        buf[#buf + 1] = r
        j = j + 2
      end
    else
      buf[#buf + 1] = c
      j = j + 1
    end
  end
end

function decodeValue(s, i)
  i = skip(s, i)
  local c = s:sub(i, i)
  if c == "{" then
    local obj = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "}" then return obj, i + 1 end
    while true do
      local key
      key, i = decodeString(s, skip(s, i))
      i = skip(s, i)
      if s:sub(i, i) ~= ":" then error("expected ':' at " .. i) end
      obj[key], i = decodeValue(s, i + 1)
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == "}" then return obj, i + 1 end
      if d ~= "," then error("expected ',' or '}' at " .. i) end
      i = i + 1
    end
  elseif c == "[" then
    local arr = {}
    i = skip(s, i + 1)
    if s:sub(i, i) == "]" then return arr, i + 1 end
    while true do
      arr[#arr + 1], i = decodeValue(s, i)
      i = skip(s, i)
      local d = s:sub(i, i)
      if d == "]" then return arr, i + 1 end
      if d ~= "," then error("expected ',' or ']' at " .. i) end
      i = i + 1
    end
  elseif c == '"' then
    return decodeString(s, i)
  elseif s:sub(i, i + 3) == "true" then
    return true, i + 4
  elseif s:sub(i, i + 4) == "false" then
    return false, i + 5
  elseif s:sub(i, i + 3) == "null" then
    return nil, i + 4
  end
  local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
  if not num or num == "" then error("unexpected character at " .. i) end
  return tonumber(num), i + #num
end

function Export.FromJSON(s)
  local value, i = decodeValue(s, 1)
  if skip(s, i) <= #s then error("trailing data at " .. i) end
  return value
end

-- Contract v2 ---------------------------------------------------------------
local function report(inc, db, n)
  return {
    id = db.installId .. "-" .. inc.session .. "-" .. n,
    hash = inc.hash, kind = inc.kind, message = inc.message, stack = inc.stack, locals = inc.locals,
    count = inc.count, firstSeen = inc.firstSeen, lastSeen = inc.lastSeen, session = inc.lastSession or inc.session,
    addonVersion = inc.addonVersion, interface = inc.interface, build = inc.build, locale = inc.locale,
    source = "sentinel", module = inc.module, severity = inc.severity, track = inc.track,
    context = inc.context, extra = inc.extra, apiFamily = inc.apiFamily,
  }
end

function Export:Payload()
  local db = S.db
  local reports, n = setmetatable({}, Export.ARRAY), 0
  local hashes = {}
  for hash in pairs(db.incidents) do hashes[#hashes + 1] = hash end
  table.sort(hashes)
  for i = 1, #hashes do
    local inc = db.incidents[hashes[i]]
    if REPORT_KINDS[inc.kind] then
      n = n + 1
      reports[n] = report(inc, db, n)
    end
  end
  for i = 1, #db.heartbeats do
    local hb = db.heartbeats[i]
    n = n + 1
    reports[n] = { id = db.installId .. "-" .. hb.session .. "-" .. n, kind = "heartbeat", hash = "heartbeat-" .. hb.session,
      message = "session health", count = 1, firstSeen = hb.at, lastSeen = hb.at, session = hb.session,
      addonVersion = hb.version, interface = hb.interface, build = hb.build, source = "sentinel",
      module = "Core", track = hb.track, context = hb }
  end
  for i = 1, #db.tests do
    local t = db.tests[i]
    n = n + 1
    reports[n] = { id = db.installId .. "-" .. t.session .. "-" .. n, kind = "test", hash = "test-" .. t.session .. "-" .. i,
      message = t.summary, count = 1, firstSeen = t.at, lastSeen = t.at, session = t.session,
      addonVersion = t.version, build = t.build, source = "sentinel", module = "Tests", context = t }
  end
  return { schema = CONTRACT, installId = db.installId, uploader = "Phoenix_UI_Sentinel " .. S:Version(), reports = reports }
end

function Export.Encode(payload)
  local json = Export.ToJSON(payload)
  local packed = C_EncodingUtil.CompressString(json)
  return Export.PREFIX .. C_EncodingUtil.EncodeBase64(packed)
end

function Export.Decode(text)
  if type(text) ~= "string" or text:sub(1, #Export.PREFIX) ~= Export.PREFIX then return nil, "not a !PUI_SEN string" end
  local packed = C_EncodingUtil.DecodeBase64(text:sub(#Export.PREFIX + 1))
  if not packed then return nil, "bad base64" end
  local json = C_EncodingUtil.DecompressString(packed)
  if not json then return nil, "bad compressed data" end
  return Export.FromJSON(json)
end

-- Requires opt-in: nothing leaves the machine otherwise (PUI_V2 16.3 privacy).
function Export:Build()
  if not S.db.optIn then return nil, "Turn on 'Share diagnostics' first." end
  local payload = self:Payload()
  local text = Export.Encode(payload)
  S.db.lastSent = { at = time(), reports = #payload.reports, via = "export" }
  return text
end
