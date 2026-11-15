local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Encounter stats (BigWigs tools parity, mockup 16 right side): kills, wipes,
-- best kill time and last pull per boss and difficulty; the last pull compared
-- with your best; a wipe trend per night (your longest pull each night, a
-- plain proxy for how far you got, since phases are only known to a boss
-- mod); CSV export through the shared copy box. Reads ENCOUNTER_START/END
-- only (no combat log). Stands down while a boss mod records its own stats,
-- unless you turn that off. Stats live outside profiles (per character or
-- warband-wide); turning the feature off never deletes them.
local _, ns = ...
local Schema, DB = PUI.Schema, PUI.DB
local RT = ns.RT
local OWNER = "RaidTools"
local ST = { current = nil }
ns.Stats = ST
RT.Stats = ST
local s = { enabled = true, yieldToBossMods = true, scope = "character", chatLine = false, historySize = 50, raidsOnly = false }
ST.settings = s
ST.BOSSMODS = { "BigWigs", "DBM-Core" }

function ST.Store()
  local sv = DB.sv
  if not sv then ST.mem = ST.mem or {}; return ST.mem end
  sv.encounterStats = sv.encounterStats or {}
  local k = s.scope == "warband" and "warband" or DB:CharKey()
  sv.encounterStats[k] = sv.encounterStats[k] or {}
  return sv.encounterStats[k]
end

function ST.Yields()
  if not s.yieldToBossMods then return false end
  for _, name in ipairs(ST.BOSSMODS) do if C_AddOns.IsAddOnLoaded(name) then return true end end
  return false
end
function ST.Recording() return RT.active and s.enabled and not ST.Yields() end

function ST.Key(id, difficulty) return tostring(id) .. ":" .. tostring(difficulty or 0) end

function ST.OnStart(_, _, id, name, difficulty, size)
  if not ST.Recording() then return end
  if s.raidsOnly and (size or 0) <= 5 then return end
  ST.current = { id = id, name = name, difficulty = difficulty, started = GetTime() }
end

-- Record(id, name, difficulty, seconds, success, when) -> entry (pure apart from the store)
function ST.Record(id, name, difficulty, seconds, success, when)
  local store = ST.Store()
  local k = ST.Key(id, difficulty)
  local e = store[k]
  if not e then e = { id = id, name = name, difficulty = difficulty, kills = 0, wipes = 0, history = {} }; store[k] = e end
  e.name = name or e.name
  seconds = math.max(0, math.floor((seconds or 0) * 10 + 0.5) / 10)
  local prevBest = e.best
  if success then
    e.kills = e.kills + 1
    if not e.best or seconds < e.best then e.best = seconds end
  else
    e.wipes = e.wipes + 1
    if not e.longestWipe or seconds > e.longestWipe then e.longestWipe = seconds end
  end
  e.last = { seconds = seconds, success = success == true, when = when or time(), prevBest = prevBest }
  table.insert(e.history, { s = seconds, ok = success == true, t = when or time() })
  while #e.history > s.historySize do table.remove(e.history, 1) end
  return e
end

function ST.OnEnd(_, _, id, name, difficulty, size, success)
  local cur = ST.current
  ST.current = nil
  if not (cur and ST.Recording() and cur.id == id) then return end
  local e = ST.Record(id, name, difficulty, GetTime() - cur.started, success == 1 or success == true)
  if s.chatLine then PUI.Slash.Print(ST.LastLine(e)) end
end

local function clock(sec) return PUI.CombatTimer and PUI.CombatTimer.Format(sec) or string.format("%d:%02d", math.floor(sec / 60), sec % 60) end
ST.Clock = clock

-- "+0:08 vs best" / "-0:03 vs best (new best)" / "wipe at 2:14 (best pull 3:02)"
function ST.Compare(e)
  local last = e and e.last
  if not last then return "" end
  if last.success then
    if not last.prevBest then return "first kill" end
    local d = last.seconds - last.prevBest
    if d < 0 then return "-" .. clock(-d) .. " vs best (new best)" end
    return "+" .. clock(d) .. " vs best"
  end
  return "wipe at " .. clock(last.seconds) .. (e.longestWipe and (" (longest " .. clock(e.longestWipe) .. ")") or "")
end
function ST.LastLine(e)
  return string.format("%s: %s %s - kills %d, wipes %d", e.name or "?", e.last.success and "kill" or "wipe", clock(e.last.seconds), e.kills, e.wipes) .. "  " .. ST.Compare(e)
end

-- Wipe trend: longest wipe per night ("2026-10-25"), oldest first.
function ST.Trend(e, nights)
  local byNight, order = {}, {}
  for _, h in ipairs(e and e.history or {}) do
    if not h.ok then
      local night = date("%Y-%m-%d", h.t - 6 * 3600) -- a night runs past midnight
      if not byNight[night] then byNight[night] = 0; order[#order + 1] = night end
      if h.s > byNight[night] then byNight[night] = h.s end
    end
  end
  table.sort(order)
  local out = {}
  for i = math.max(1, #order - (nights or 5) + 1), #order do out[#out + 1] = { night = order[i], seconds = byNight[order[i]] } end
  return out
end
function ST.TrendText(e)
  local t = ST.Trend(e)
  if #t == 0 then return "no wipes yet" end
  local parts = {}
  for _, n in ipairs(t) do parts[#parts + 1] = clock(n.seconds) end
  local dir = ""
  if #t >= 2 then dir = t[#t].seconds > t[1].seconds and "  (getting further)" or t[#t].seconds < t[1].seconds and "  (shorter pulls)" or "  (steady)" end
  return "longest pull per night: " .. table.concat(parts, " > ") .. dir
end

function ST.Rows()
  local out = {}
  for _, e in pairs(ST.Store()) do out[#out + 1] = e end
  table.sort(out, function(a, b)
    local x, y = a.last and a.last.when or 0, b.last and b.last.when or 0
    if x ~= y then return x > y end
    return ST.Key(a.id, a.difficulty) < ST.Key(b.id, b.difficulty)
  end)
  return out
end

function ST.CSV()
  local lines = { "boss,difficulty,kills,wipes,best,last,last_result,longest_wipe" }
  for _, e in ipairs(ST.Rows()) do
    local name = tostring(e.name or e.id):gsub(",", " ")
    lines[#lines + 1] = string.format("%s,%s,%d,%d,%s,%s,%s,%s", name, tostring(e.difficulty), e.kills, e.wipes,
      e.best and clock(e.best) or "", e.last and clock(e.last.seconds) or "", e.last and (e.last.success and "kill" or "wipe") or "", e.longestWipe and clock(e.longestWipe) or "")
  end
  return table.concat(lines, "\n")
end
function ST.Export() PUI.Dialogs:Copy("Encounter stats (CSV)", ST.CSV(), "Ctrl+C copies; paste into a spreadsheet.") end

function ST.Reset(id, difficulty)
  local store = ST.Store()
  local k = ST.Key(id, difficulty)
  if not store[k] then return false end
  store[k] = nil
  return true
end

PUI.Slash:Register("stats", function(rest)
  local verb, a, b = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)")
  if verb == "export" then ST.Export()
  elseif verb == "reset" and tonumber(a) then
    PUI.Dialogs:Confirm({ title = "Reset encounter stats", text = "Delete the stats for encounter " .. a .. (b ~= "" and (" difficulty " .. b) or "") .. "? This cannot be undone.",
      accept = "Reset", cancel = "Keep", onAccept = function() PUI.Slash.Print(ST.Reset(tonumber(a), tonumber(b) or 0) and "reset" or "nothing to reset") end })
  else
    local rows = ST.Rows()
    if #rows == 0 then PUI.Slash.Print("no encounter stats yet" .. (ST.Yields() and " (a boss mod keeps them)" or "")) end
    for i = 1, math.min(8, #rows) do PUI.Slash.Print(ST.LastLine(rows[i]) .. "  " .. ST.TrendText(rows[i])) end
  end
end, "encounter stats: list, export (CSV), reset <encounterID> [difficulty]")

function ST.Enable(mod)
  mod:RegisterEvent("ENCOUNTER_START", ST.OnStart)
  mod:RegisterEvent("ENCOUNTER_END", ST.OnEnd)
end

local schema = ns.schema
local function key(name, def)
  def.owner = OWNER
  def.mode = def.mode or "advanced"
  def.searchTags = { "encounter", "stats", "kills", "wipes", "boss", "bigwigs" }
  def.apply = function(v) s[name] = v end
  schema["rt.stats." .. name] = def
end
key("enabled", { type = "toggle", default = true, label = "Encounter stats", tooltip = "Counts kills and wipes, best kill time and last pull for each boss and difficulty. Turning this off never deletes them.", mode = "simple" })
key("yieldToBossMods", { type = "toggle", default = true, label = "Off while a boss mod keeps stats", tooltip = "Pauses Phoenix's stats while BigWigs or DBM is loaded, so nothing is counted twice.", mode = "simple" })
key("scope", { type = "select", default = "character", choices = { "character", "warband" }, choiceLabels = { character = "Per character", warband = "Warband-wide" },
  label = "Stats kept", tooltip = "Keep stats for this character only, or one set for all your characters." })
key("chatLine", { type = "toggle", default = false, label = "Line after each pull", tooltip = "Prints kill or wipe, time and the compare with your best after every boss pull (only you see it)." })
key("raidsOnly", { type = "toggle", default = false, label = "Raids only", tooltip = "Skips dungeon bosses." })
key("historySize", { type = "range", default = 50, min = 10, max = 200, step = 10, label = "Pulls kept per boss", tooltip = "How many pulls per boss the history (and the wipe trend) keeps." })

RT.Register()
