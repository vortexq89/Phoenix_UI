local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Store (mockup 15): everything the error reporter lists.
--  * Phoenix incidents (Capture) and other addons' errors (db.others, this
--    PC only, BugSack parity) in one newest-first list;
--  * sessions: this, previous, all; source: every addon, Phoenix, others;
--    plain-text search over message, stack, module and addon;
--  * fingerprints: the dedupe hash, shown short, grouping repeats;
--  * resolved states that persist across sessions: new, known, ignored,
--    fixed in a version (seen again after a fix shows as "back").
-- Ignored only stops alerts; an ignored error is still listed (G7).
local S = PUI.Sentinel
local Store = {}
S.Store = Store
local MAX_OTHERS = 100

function Store:DB()
  local db = S.db
  db.others = db.others or {}
  db.resolved = db.resolved or {}
  return db
end

function Store:OnOther(rec)
  local db = self:DB()
  local C = S.Capture
  local stack = C.NormaliseStack(rec.stack or "")
  local hash = C.Hash((rec.addon or "?") .. "|" .. stack .. "|" .. C.NormaliseMessage(rec.message or ""))
  local now = time()
  local inc = db.others[hash]
  local isNew = inc == nil
  if isNew then
    inc = { hash = hash, kind = "error", module = rec.addon or "?", addon = rec.addon or "?", other = true, message = rec.message or "",
      stack = stack, locals = rec.locals, count = 0, firstSeen = now, session = db.session, combat = rec.combat }
    db.others[hash] = inc
    local n, oldest, oldestKey = 0, nil, nil
    for k, v in pairs(db.others) do n = n + 1; if not oldest or v.lastSeen < oldest then oldest, oldestKey = v.lastSeen, k end end
    if n > MAX_OTHERS and oldestKey and oldestKey ~= hash then db.others[oldestKey] = nil end
  end
  inc.count = inc.count + 1
  inc.lastSeen = now
  inc.lastSession = db.session
  if S.Alerts then S.Alerts:OnError(inc, isNew) end
  return inc, isNew
end
function Store:DrainOthers()
  local pending = PUI.SentinelHook.others
  PUI.SentinelHook.others = {}
  for i = 1, #pending do self:OnOther(pending[i]) end
end

-- Resolved states ----------------------------------------------------------
Store.STATES = { new = "New", known = "Known", ignored = "Ignored", fixed = "Fixed" }
function Store:SetState(hash, state, fixedIn)
  local db = self:DB()
  if state == "new" then db.resolved[hash] = nil
  else db.resolved[hash] = { state = state, fixedIn = fixedIn, at = time() } end
end
-- State(inc) -> state, label ("back" when it happened again after a fix).
function Store:State(inc)
  local r = self:DB().resolved[inc.hash]
  if not r then return "new", "New" end
  if r.state == "fixed" then
    if (inc.lastSeen or 0) > (r.at or 0) and inc.addonVersion ~= nil and r.fixedIn ~= nil and inc.addonVersion ~= r.fixedIn and S:Version() == inc.addonVersion then
      return "back", "Back after fix " .. tostring(r.fixedIn)
    end
    return "fixed", "Fixed in " .. tostring(r.fixedIn or "?")
  end
  return r.state, self.STATES[r.state] or r.state
end
function Store.Fingerprint(inc) return (inc.hash or ""):sub(1, 6) end

-- List(opts) -> newest first. opts.session: "this" | "previous" | "all";
-- opts.source: "all" | "phoenix" | "others"; opts.query: plain text.
local function inSession(inc, which, cur)
  if which == "all" then return true end
  local want = which == "previous" and cur - 1 or cur
  return inc.session == want or inc.lastSession == want
end
function Store:List(opts)
  opts = opts or {}
  local db = self:DB()
  local cur = db.session or 0
  local q = opts.query and opts.query ~= "" and opts.query:lower() or nil
  local out = {}
  local function consider(inc)
    if not inSession(inc, opts.session or "all", cur) then return end
    if q then
      local hay = ((inc.message or "") .. "\n" .. (inc.stack or "") .. "\n" .. (inc.module or "") .. "\n" .. (inc.addon or "")):lower()
      if not hay:find(q, 1, true) then return end
    end
    out[#out + 1] = inc
  end
  if opts.source ~= "others" then for _, inc in pairs(db.incidents) do if inc.kind ~= "heartbeat" then consider(inc) end end end
  if opts.source ~= "phoenix" then for _, inc in pairs(db.others) do consider(inc) end end
  table.sort(out, function(a, b)
    if (a.lastSeen or 0) ~= (b.lastSeen or 0) then return (a.lastSeen or 0) > (b.lastSeen or 0) end
    return a.hash < b.hash
  end)
  return out
end
function Store:Counts()
  local db = self:DB()
  local cur = db.session or 0
  local t = { session = 0, previous = 0, all = 0, newThisSession = 0 }
  for _, src in ipairs({ db.incidents, db.others }) do
    for _, inc in pairs(src) do
      if inc.kind ~= "heartbeat" then
        t.all = t.all + 1
        if inSession(inc, "this", cur) then t.session = t.session + 1; if self:State(inc) == "new" or self:State(inc) == "back" then t.newThisSession = t.newThisSession + 1 end end
        if inSession(inc, "previous", cur) then t.previous = t.previous + 1 end
      end
    end
  end
  return t
end
-- Wipe: everything (incidents, others, resolved states kept unless asked).
function Store:Wipe(keepStates)
  local db = self:DB()
  wipe(db.incidents); wipe(db.others)
  if not keepStates then wipe(db.resolved) end
end
