-- Dumps Blizzard_APIDocumentationGenerated into TSV: kind \t fullname \t flags
local dir = arg[1]
local out = io.open(arg[2], "w")
APIDocumentation = {}
function APIDocumentation:AddDocumentationTable(t)
  local ns = t.Namespace
  for _, f in ipairs(t.Functions or {}) do
    local full = ns and (ns .. "." .. f.Name) or f.Name
    local flags = {}
    if f.SecretReturns then flags[#flags+1] = "SecretReturns" end
    if f.SecretArguments then flags[#flags+1] = "SecretArgs=" .. f.SecretArguments end
    for k, v in pairs(f) do if type(k) == "string" and k:match("^Secret") and k ~= "SecretReturns" and k ~= "SecretArguments" then flags[#flags+1] = k end end
    if f.HasRestrictions then flags[#flags+1] = "HasRestrictions" end
    if f.IsProtectedFunction then flags[#flags+1] = "Protected" end
    for _, r in ipairs(f.Returns or {}) do if r.ConditionalSecret then flags[#flags+1] = "ConditionalSecret:" .. r.Name end end
    out:write(((t.Type == "ScriptObject") and "method" or "func"), "\t", (t.Type == "ScriptObject" and (t.Name .. ":" .. f.Name) or full), "\t", table.concat(flags, ","), "\n")
  end
  for _, e in ipairs(t.Events or {}) do
    local flags = {}
    for k, v in pairs(e) do if type(k) == "string" and (k:match("^Secret") or k == "CallbackEvent" or k=="UniqueEvent" or k=="SynchronousEvent") then flags[#flags+1] = k end end
    out:write("event\t", e.LiteralName, "\t", table.concat(flags, ","), "\n")
  end
  for _, tb in ipairs(t.Tables or {}) do
    if tb.Type == "Enumeration" then out:write("enum\tEnum.", tb.Name, "\t\n") end
  end
end
for file in io.popen('ls "' .. dir .. '"'):lines() do
  if file:match("%.lua$") then
    local chunk = loadfile(dir .. "/" .. file)
    if chunk then pcall(chunk) end
  end
end
out:close()
