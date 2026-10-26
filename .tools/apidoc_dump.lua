-- Phoenix UI tooling: loads Blizzard_APIDocumentationGenerated files (plain Lua
-- tables) in a sandbox and prints one tab-separated line per API entry.
-- Usage: lua5.1 apidoc_dump.lua <file>...
local out = {}
local function names(list)
  local r = {}
  for _, a in ipairs(list or {}) do r[#r + 1] = tostring(a.Name) .. ":" .. tostring(a.Type) end
  return table.concat(r, ",")
end
local function add(doc)
  local ns = doc.Namespace
  for _, f in ipairs(doc.Functions or {}) do
    local full = ns and (ns .. "." .. f.Name) or f.Name
    out[#out + 1] = table.concat({ "function", full, names(f.Arguments), names(f.Returns), doc.Name or "" }, "\t")
  end
  for _, e in ipairs(doc.Events or {}) do
    out[#out + 1] = table.concat({ "event", tostring(e.LiteralName), names(e.Payload), "", doc.Name or "" }, "\t")
  end
end
local env = { APIDocumentation = { AddDocumentationTable = function(_, t) add(t) end } }
env.APIDocumentation.__index = env.APIDocumentation
local proxy
local pmt = {}
pmt.__index = function() return proxy end
pmt.__call = function() return proxy end
pmt.__add = function() return 0 end
pmt.__sub = pmt.__add
pmt.__mul = pmt.__add
pmt.__unm = pmt.__add
proxy = setmetatable({}, pmt)
setmetatable(env, { __index = function(_, k)
  if k == "ipairs" or k == "pairs" or k == "tostring" then return _G[k] end
  return proxy
end })
for i = 1, #arg do
  local chunk = loadfile(arg[i])
  if chunk then
    setfenv(chunk, env)
    chunk()
  end
end
io.write(table.concat(out, "\n"), "\n")
