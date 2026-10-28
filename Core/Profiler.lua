local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Developer profiler `/pui profile` (plan 1.32, 5.17b). Opt-in; zero cost
-- off: no wrapper exists until you start it, and stopping puts every
-- original function back. It times only entry points known to Phoenix's own
-- registries (module event handlers from the Kernel, Ticker jobs, and
-- anything registered with Profiler:Register) - never a walk over _G or
-- frames. Self time vs inclusive time comes from a nesting stack; each run
-- is a measurement generation; the report groups by owner, hides rows under
-- the floor and says how many it hid; AB() interleaves two functions.
local P = { entries = {}, stats = {}, generation = 0, running = false, wrapped = {}, stack = {} }
PUI.Profiler = P
-- Hot primitives never wrapped (their cost would be all overhead).
P.EXCLUDE = { ["Core:Secret.IsSecret"] = true, ["Core:Secret.ToText"] = true, ["Core:Kernel.Fire"] = true }

local function now()
  local fn = rawget(_G, "GetTimePreciseSec")
  if fn then return fn() * 1000 end
  return debugprofilestop()
end
P.Now = now

local function stat(owner, name)
  local id = owner .. ":" .. name
  local st = P.stats[id]
  if not st then st = { owner = owner, name = name, calls = 0, incl = 0, self = 0, max = 0 }; P.stats[id] = st end
  return st
end

-- Wrap(owner, name, fn) -> timed function (used only while running).
function P.Wrap(owner, name, fn)
  local st = stat(owner, name)
  local stack = P.stack
  local function done(t0, ...)
    local dt = now() - t0
    local top = stack[#stack]
    stack[#stack] = nil
    st.calls, st.incl = st.calls + 1, st.incl + dt
    st.self = st.self + dt - top.child
    if dt > st.max then st.max = dt end
    local parent = stack[#stack]
    if parent then parent.child = parent.child + dt end
    return ...
  end
  return function(...)
    stack[#stack + 1] = { child = 0 }
    return done(now(), fn(...))
  end
end

-- Register(owner, name, tbl, method): an extra entry point to time.
function P:Register(owner, name, tbl, method)
  local id = owner .. ":" .. name
  self.entries[id] = { owner = owner, name = name, tbl = tbl, method = method }
  if self.running then self:WrapEntry(id, self.entries[id]) end
end
function P:WrapEntry(id, e)
  if self.EXCLUDE[id] or self.wrapped[id] then return end
  local orig = e.tbl[e.method]
  if type(orig) ~= "function" then return end
  local w = P.Wrap(e.owner, e.name, orig)
  e.tbl[e.method] = w
  self.wrapped[id] = { tbl = e.tbl, method = e.method, orig = orig, wrapper = w }
end

function P:Start()
  if self.running then return false end
  self.running = true
  self.generation = self.generation + 1
  wipe(self.stats); wipe(self.stack)
  self.startedAt = now()
  for name, mod in pairs(PUI.Modules) do
    for event in pairs(mod.handlers) do self:WrapEntry(name .. ":" .. event, { owner = name, name = event, tbl = mod.handlers, method = event }) end
  end
  for id, e in pairs(self.entries) do self:WrapEntry(id, e) end
  local T = PUI.Ticker
  T.probe = function(entry) return P.Wrap(entry.owner, "ticker " .. entry.key, entry.rawFn) end
  for _, entry in pairs(T.entries) do entry.fn = T.probe(entry) end
  return true
end
function P:Stop()
  if not self.running then return false end
  self.running = false
  self.elapsed = now() - (self.startedAt or now())
  for id, w in pairs(self.wrapped) do
    if w.tbl[w.method] == w.wrapper then w.tbl[w.method] = w.orig end
    self.wrapped[id] = nil
  end
  local T = PUI.Ticker
  T.probe = nil
  for _, entry in pairs(T.entries) do entry.fn = entry.rawFn end
  return true
end
function P:IsWrapping() return next(self.wrapped) ~= nil or PUI.Ticker.probe ~= nil end

-- Report(floorMs) -> { groups = { {owner, self, incl, rows} }, hidden, generation }.
function P:Report(floor)
  floor = floor or 0.05
  local groups, byOwner, hidden = {}, {}, 0
  for _, st in pairs(self.stats) do
    if st.calls > 0 and st.incl >= floor then
      local g = byOwner[st.owner]
      if not g then g = { owner = st.owner, self = 0, incl = 0, rows = {} }; byOwner[st.owner] = g; groups[#groups + 1] = g end
      g.self, g.incl = g.self + st.self, g.incl + st.incl
      g.rows[#g.rows + 1] = st
    elseif st.calls > 0 then hidden = hidden + 1 end
  end
  table.sort(groups, function(a, b) return a.self > b.self end)
  for _, g in ipairs(groups) do table.sort(g.rows, function(a, b) return a.self > b.self end) end
  return { groups = groups, hidden = hidden, generation = self.generation }
end
function P:OwnerTotal(owner)
  local t = 0
  for _, st in pairs(self.stats) do if st.owner == owner then t = t + st.self end end
  return t
end
function P:ReportText()
  local r = self:Report()
  local out = { string.format("Profiler  -  %s  -  run %d%s", self.running and "running" or "stopped", r.generation,
    self.elapsed and not self.running and string.format("  -  %.1f s", self.elapsed / 1000) or "") }
  if #r.groups == 0 then out[#out + 1] = "\nNo samples yet. /pui profile start, play a little, then /pui profile stop." end
  for _, g in ipairs(r.groups) do
    out[#out + 1] = string.format("\n%s   self %.2f ms   inclusive %.2f ms", g.owner, g.self, g.incl)
    for _, st in ipairs(g.rows) do
      out[#out + 1] = string.format("    %-34s %6d calls   self %8.3f   incl %8.3f   max %6.3f ms", st.name, st.calls, st.self, st.incl, st.max)
    end
  end
  if r.hidden > 0 then out[#out + 1] = string.format("\n%d entry points hidden (under 0.05 ms in total).", r.hidden) end
  return table.concat(out, "\n")
end

-- AB(fnA, fnB, rounds): interleaved A/B timing -> avgA, avgB (ms per call).
function P.AB(a, b, rounds)
  rounds = rounds or 200
  local ta, tb = 0, 0
  for i = 1, rounds do
    local first, second = a, b
    if i % 2 == 0 then first, second = b, a end
    local t0 = now(); first(); local t1 = now(); second(); local t2 = now()
    if first == a then ta, tb = ta + (t1 - t0), tb + (t2 - t1) else tb, ta = tb + (t1 - t0), ta + (t2 - t1) end
  end
  return ta / rounds, tb / rounds
end

PUI.Slash:Register("profile", function(rest)
  local word = (rest or ""):match("^(%S*)")
  if word == "start" then P:Start(); PUI.Slash.Print("profiler started (run " .. P.generation .. ")")
  elseif word == "stop" then P:Stop(); PUI.Slash.Print("profiler stopped")
  elseif word == "report" then PUI.Dialogs:Copy("Profiler report", P:ReportText())
  elseif word == "reset" then wipe(P.stats); PUI.Slash.Print("profiler samples cleared")
  else PUI.Slash.Print("/pui profile start | stop | report | reset") end
end, "Developer profiler: start, stop, report, reset (off costs nothing)")
