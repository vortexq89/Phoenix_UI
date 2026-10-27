local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Diagnostics `PUI.Diag` (plan 1.31, 5.17a): one page / copyable report with
-- everything needed to understand a problem report: versions and client,
-- error capture mode (own handler or BugGrabber's callback), which error
-- display you chose when BugSack is loaded, modules and their state, Ticker
-- jobs, what the CVar / binding / frame ledgers hold, conflict choices,
-- memory and CPU per Phoenix addon (only when the game's profiler is on),
-- and the profiler state. Read-only; built when you open it.
local Diag = {}
PUI.Diag = Diag

-- With BugSack loaded you choose who shows new errors; Sentinel still
-- captures, lists and uploads either way (errors are never hidden).
local ckey, cdef = PUI.Coexist:Define("sentinel.display", { module = "Sentinel", job = "New-error alerts", soft = true, addons = { "BugSack" } })
cdef.owner = "Sentinel"
cdef.label = "BugSack is loaded: who shows new errors?"
cdef.choiceLabels = { ask = "Ask me", phoenix = "Sentinel shows them (BugSack stays as a source)", other = "BugSack shows them (Sentinel only uploads)" }
PUI.Schema:Register(ckey, cdef)

local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

function Diag:Collect()
  local d = {}
  d.version = C_AddOns.GetAddOnMetadata(PUI.ADDON_NAME, "Version") or "dev"
  d.toc, d.build, d.forever, d.locale = PUI.TOC, PUI.BUILD, PUI.IS_FOREVER == true, GetLocale()
  local hook = PUI.SentinelHook
  d.capture = hook.mode or "?"
  d.bugGrabber = type(rawget(_G, "BugGrabber")) == "table"
  d.bugSack = C_AddOns.IsAddOnLoaded("BugSack") == true
  d.display = PUI.Coexist:Choice("sentinel.display")
  d.modules = {}
  for _, name in ipairs(PUI.Kernel.order or {}) do
    local m = PUI.Modules[name]
    d.modules[#d.modules + 1] = { name = name, enabled = m and m.enabled == true, events = m and m:RegisteredEventCount() or 0 }
  end
  d.ticker = { jobs = count(PUI.Ticker.entries), perFrame = PUI.Ticker.perFrameCount or 0 }
  d.ledger = PUI.Ledger and PUI.Ledger.Summary() or {}
  d.conflicts = {}
  for _, id in ipairs(PUI.Coexist.order or {}) do
    local loaded = PUI.Coexist:Loaded(id)
    if #loaded > 0 then d.conflicts[#d.conflicts + 1] = { id = id, addons = table.concat(loaded, ", "), choice = PUI.Coexist:Choice(id) } end
  end
  d.memory = {}
  local upd, mem = rawget(_G, "UpdateAddOnMemoryUsage"), rawget(_G, "GetAddOnMemoryUsage")
  if upd and mem and not InCombatLockdown() then
    upd()
    for i = 1, C_AddOns.GetNumAddOns() do
      local name = C_AddOns.GetAddOnInfo(i)
      if type(name) == "string" and name:find("^Phoenix_UI") and C_AddOns.IsAddOnLoaded(i) then d.memory[#d.memory + 1] = { name = name, kb = mem(name) or 0 } end
    end
    table.sort(d.memory, function(a, b) return a.kb > b.kb end)
  end
  d.cpu = (C_AddOnProfiler and C_AddOnProfiler.IsEnabled()) and C_AddOnProfiler.GetAddOnMetric(PUI.ADDON_NAME, Enum.AddOnProfilerMetric.RecentAverageTime) or nil
  if PUI.Secret.IsSecret(d.cpu) then d.cpu = nil end
  d.profiler = PUI.Profiler and (PUI.Profiler.running and "running" or "off") or "missing"
  local S = PUI.Sentinel
  d.errors = S and S.Store and S.Store:Counts() or nil
  return d
end

function Diag:Text()
  local d = self:Collect()
  local out = {
    "Phoenix UI diagnostics",
    string.format("Version %s   Interface %s   Build %s   %s   %s", tostring(d.version), tostring(d.toc), tostring(d.build), d.forever and "Forever" or "Retail", tostring(d.locale)),
    string.format("Error capture: %s   BugGrabber %s   BugSack %s   new-error display: %s", d.capture, d.bugGrabber and "yes" or "no", d.bugSack and "yes" or "no", d.display),
  }
  if d.errors then out[#out + 1] = string.format("Errors: %d this session (%d new), %d previous, %d stored", d.errors.session, d.errors.newThisSession, d.errors.previous, d.errors.all) end
  out[#out + 1] = string.format("Ticker: %d jobs (%d every frame)   Profiler: %s", d.ticker.jobs, d.ticker.perFrame, d.profiler)
  out[#out + 1] = string.format("Ledgers: %d CVars still Phoenix's, %d changed by you since, %d key bindings, %d frame takeovers",
    d.ledger.cvars or 0, d.ledger.cvarsChanged or 0, d.ledger.bindings or 0, d.ledger.frames or 0)
  if d.cpu then out[#out + 1] = string.format("CPU (game profiler): %.3f ms per frame", d.cpu) end
  out[#out + 1] = "\nModules:"
  local on, off = {}, {}
  for _, m in ipairs(d.modules) do
    if m.enabled then on[#on + 1] = string.format("%s (%d events)", m.name, m.events) else off[#off + 1] = m.name end
  end
  out[#out + 1] = "  On: " .. (#on > 0 and table.concat(on, ", ") or "none")
  out[#out + 1] = "  Off: " .. (#off > 0 and table.concat(off, ", ") or "none")
  if #d.conflicts > 0 then
    out[#out + 1] = "\nOther addons doing the same job:"
    for _, c in ipairs(d.conflicts) do out[#out + 1] = string.format("  %s: %s -> %s", c.id, c.addons, c.choice) end
  end
  if #d.memory > 0 then
    out[#out + 1] = "\nMemory:"
    for _, m in ipairs(d.memory) do out[#out + 1] = string.format("  %-32s %8.0f KB", m.name, m.kb) end
  end
  return table.concat(out, "\n")
end

PUI.Slash:Register("diag", function() PUI.Dialogs:Copy("Phoenix UI diagnostics", Diag:Text(), "Ctrl+C to copy into a report") end,
  "Diagnostics: versions, capture mode, modules, ledgers, conflicts, memory")
