local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- PUI.Search (plan 1.25, G11): plain-text search for Ctrl+K, ID lookups,
-- pickers and database search. User text is never a Lua pattern.
--   "quoted text"  exact (case-insensitive) match of the whole name
--   12345          exact ID first, then IDs that start with the digits
--   words          every word must appear (AND), in any order
-- Run() is a generation-tagged Ticker job with a per-tick budget; a new query
-- for the same owner cancels the old one, and stale results are dropped (G20).
local Search = { jobs = {}, gens = {}, budget = 200 }
PUI.Search = Search

local lower, find = string.lower, string.find

function Search.Parse(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local q = { raw = text }
  if text == "" then q.empty = true; return q end
  local quoted = text:match('^"(.*)"$')
  if quoted then q.exact = lower(quoted); return q end
  if text:match("^%d+$") then q.id = tonumber(text); q.idText = text; return q end
  local terms = {}
  for w in text:gmatch("%S+") do terms[#terms + 1] = lower(w) end
  q.terms = terms
  return q
end

-- Match(q, name, id[, tags]) -> rank (1 best) or nil. tags: extra searchable text.
function Search.Match(q, name, id, tags)
  if q.empty then return 3 end
  local n = lower(tostring(name or ""))
  if q.exact then return n == q.exact and 1 or nil end
  if q.id then
    if id == q.id then return 1 end
    if id ~= nil and tostring(id):sub(1, #q.idText) == q.idText then return 2 end
    return nil
  end
  local hay = tags and (n .. " " .. lower(tags)) or n
  for i = 1, #q.terms do
    if not find(hay, q.terms[i], 1, true) then return nil end
  end
  if find(n, q.terms[1], 1, true) == 1 then return 1 end -- name starts with the first word
  return 2
end

-- Run(owner, text, source, onDone[, onProgress]): source is an array of
-- { name = , id = , tags = } or a function(i) -> item|nil. onDone(results)
-- gets items sorted by rank, then name. Returns the generation number.
function Search:Run(owner, text, source, onDone, onProgress)
  assert(type(owner) == "string" and owner ~= "", "Search:Run needs an owner")
  local gen = (self.gens[owner] or 0) + 1
  self.gens[owner] = gen
  local q = self.Parse(text)
  local job = { gen = gen, q = q, i = 0, hits = {}, source = source, onDone = onDone, onProgress = onProgress }
  self.jobs[owner] = job
  local key = "search." .. owner
  local function step()
    if self.jobs[owner] ~= job then PUI.Ticker:Unregister(key); return end -- superseded
    local budget = self.budget
    while budget > 0 do
      job.i = job.i + 1
      local item
      if type(job.source) == "function" then item = job.source(job.i) else item = job.source[job.i] end
      if item == nil then
        PUI.Ticker:Unregister(key)
        table.sort(job.hits, function(a, b)
          if a.rank ~= b.rank then return a.rank < b.rank end
          return lower(tostring(a.item.name or "")) < lower(tostring(b.item.name or ""))
        end)
        local out = {}
        for k = 1, #job.hits do out[k] = job.hits[k].item end
        job.done = true
        if job.onDone then job.onDone(out, gen) end
        return
      end
      local rank = Search.Match(q, item.name, item.id, item.tags)
      if rank then job.hits[#job.hits + 1] = { rank = rank, item = item } end
      budget = budget - 1
    end
    if job.onProgress then job.onProgress(#job.hits, gen) end
  end
  PUI.Ticker:Register(key, 0, step, "Core")
  return gen
end

function Search:Cancel(owner)
  if self.jobs[owner] then
    self.jobs[owner] = nil
    PUI.Ticker:Unregister("search." .. owner)
  end
end

function Search:Generation(owner) return self.gens[owner] or 0 end
