local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers (PUI_V2 6.1): a damage-meter front end on C_DamageMeter, the only
-- legal source on 12.x (no combat log, no addon comms). Live numbers may be
-- secret in restricted content: they go straight into StatusBars and
-- AbbreviateNumbers, never into Lua arithmetic. Out of combat a finished
-- session is copied into Phoenix's own segment store, keeping only values
-- the game reports as non-secret, so named/pinned/merged segments survive
-- reload and logout up to the user's cap. Off by default.
local _, ns = ...
local Schema, Secret, CQ, Ticker = PUI.Schema, PUI.Secret, PUI.CombatQueue, PUI.Ticker
local OWNER = "Embers"

local EM = { active = false, windows = {}, graph = {}, OWNER = OWNER }
ns.EM = EM
PUI.Embers = EM
local s = { windows = 1, meter = "DamageDone", rows = 8, look = "bars", maxSegments = 30, bossOnly = false, graph = true, report = 5 }
EM.settings = s

-- Meter types are the API's own enum (DamageMeterType, 12.0.0+ and Forever).
EM.METERS = { "DamageDone", "Dps", "HealingDone", "Hps", "Absorbs", "Interrupts", "Dispels", "DamageTaken", "AvoidableDamageTaken", "Deaths", "EnemyDamageTaken" }
EM.LOOKS = { "bars", "compact", "minimal" }

function EM.Available()
  local ok, why = C_DamageMeter.IsDamageMeterAvailable()
  return ok == true, why
end

function EM.TypeValue(name) return Enum.DamageMeterType[name] end

-- Live view: the current or overall session of one meter type. Rows carry
-- the API values untouched (possibly secret) plus never-secret fields.
function EM.Live(meter, which)
  local sessionType = Enum.DamageMeterSessionType[which or "Current"]
  local session = C_DamageMeter.GetCombatSessionFromType(sessionType, EM.TypeValue(meter))
  return session
end

-- Segment store -----------------------------------------------------------------
local function store() return Schema:Get("embers.segments") end
EM.Store = store

local function plain(v) if Secret.IsSecret(v) then return nil end return v end

-- Copy one finished session (by id) into a storable segment. Fields the game
-- still reports as secret are dropped; a segment with no readable rows is not kept.
function EM.Capture(sessionID, name, meter)
  meter = meter or s.meter
  local session = C_DamageMeter.GetCombatSessionFromID(sessionID, EM.TypeValue(meter))
  if not session or type(session.combatSources) ~= "table" then return nil end
  local rows = {}
  for _, src in ipairs(session.combatSources) do
    local amount, n = plain(src.totalAmount), plain(src.name)
    if amount and n then
      rows[#rows + 1] = { name = n, class = src.classFilename, amount = amount, aps = plain(src.amountPerSecond) or 0,
        me = src.isLocalPlayer or nil, spec = src.specIconID }
    end
  end
  if #rows == 0 then return nil end
  table.sort(rows, function(a, b) return a.amount > b.amount end)
  return { name = plain(name) or ("Segment " .. sessionID), meter = meter, at = time(), duration = plain(session.durationSeconds) or 0,
    total = plain(session.totalAmount) or 0, rows = rows, graph = EM.graph.current }
end

function EM.Save(seg)
  if not seg then return false end
  local list = store()
  table.insert(list, 1, seg)
  -- Trim to the cap; pinned segments are never trimmed.
  local kept, n = {}, 0
  for _, x in ipairs(list) do
    if x.pinned or n < s.maxSegments then kept[#kept + 1] = x; if not x.pinned then n = n + 1 end end
  end
  Schema:Set("embers.segments", kept)
  return true
end

function EM.IsBoss(name) return type(name) == "string" and EM.bossNames and EM.bossNames[name] == true end

-- Called when the game reports a finished session; work waits for combat end.
function EM.OnSession(_, _, _, sessionID) -- (module, event, meterType, sessionID)
  if not EM.active or type(sessionID) ~= "number" then return end
  EM.pending = EM.pending or {}
  EM.pending[sessionID] = true
  CQ.Defer("embers.capture", EM.Flush)
end

function EM.Flush()
  if not EM.pending then return end
  local names = {}
  for _, a in ipairs(C_DamageMeter.GetAvailableCombatSessions() or {}) do names[a.sessionID] = a.name end
  for id in pairs(EM.pending) do
    local seg = EM.Capture(id, names[id])
    if seg and (not s.bossOnly or EM.IsBoss(seg.name)) then EM.Save(seg) end
  end
  EM.pending = nil
  EM.graph.current = nil
  EM.RefreshWindows()
end

function EM.Rename(index, name) local list = store(); if list[index] then list[index].name = name; Schema:Set("embers.segments", list) return true end end
function EM.Pin(index, on) local list = store(); if list[index] then list[index].pinned = on or nil; Schema:Set("embers.segments", list) return true end end
function EM.Delete(index) local list = store(); if list[index] then table.remove(list, index); Schema:Set("embers.segments", list) return true end end

-- Merge segments of the same meter into one (sums amounts per name).
function EM.Merge(indexes, name)
  local list, by, meter, dur = store(), {}, nil, 0
  for _, i in ipairs(indexes) do
    local seg = list[i]
    if not seg then return nil end
    meter = meter or seg.meter
    if seg.meter ~= meter then return nil, "different meters" end
    dur = dur + (seg.duration or 0)
    for _, r in ipairs(seg.rows) do
      local row = by[r.name] or { name = r.name, class = r.class, amount = 0, me = r.me, spec = r.spec }
      row.amount = row.amount + r.amount
      by[r.name] = row
    end
  end
  local rows, total = {}, 0
  for _, r in pairs(by) do r.aps = dur > 0 and r.amount / dur or 0; rows[#rows + 1] = r; total = total + r.amount end
  table.sort(rows, function(a, b) return a.amount > b.amount end)
  local seg = { name = name or "Merged", meter = meter, at = time(), duration = dur, total = total, rows = rows, merged = true }
  EM.Save(seg)
  return seg
end

-- Session history: the same segment name across runs (best, last, average).
function EM.Compare(name, who)
  local best, sum, n, last
  for _, seg in ipairs(store()) do
    if seg.name == name then
      for _, r in ipairs(seg.rows) do
        if r.name == who then
          local v = r.aps
          n = (n or 0) + 1; sum = (sum or 0) + v
          best = math.max(best or 0, v)
          last = last or v
        end
      end
    end
  end
  if not n then return nil end
  return { best = best, average = sum / n, last = last, runs = n }
end

-- Report and export -------------------------------------------------------------
function EM.FormatNumber(v)
  if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
  if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
  if v >= 1e3 then return string.format("%.1fK", v / 1e3) end
  return tostring(math.floor(v + 0.5))
end

function EM.ReportLines(seg, top)
  local lines = { string.format("Phoenix Embers - %s (%s, %ds)", seg.name, seg.meter, math.floor(seg.duration or 0)) }
  for i = 1, math.min(top or s.report, #seg.rows) do
    local r = seg.rows[i]
    lines[#lines + 1] = string.format("%d. %s  %s (%s/s)", i, r.name, EM.FormatNumber(r.amount), EM.FormatNumber(r.aps or 0))
  end
  return lines
end

-- Chat is blocked in M+, PvP and encounters on 12.x; the game says when.
function EM.CanReport()
  if InCombatLockdown() then return false, "in combat" end
  if C_ChatInfo.InChatMessagingLockdown() then return false, "chat is locked in this content" end
  return true
end

function EM.Report(index, channel)
  local seg = store()[index or 1]
  if not seg then return false, "no segment" end
  local ok, why = EM.CanReport()
  if not ok then return false, why end
  channel = (channel or "SAY"):upper()
  for _, line in ipairs(EM.ReportLines(seg)) do C_ChatInfo.SendChatMessage(line, channel) end
  return true
end

-- "!PUI_EMB1:" followed by one line per segment row; plain text, copyable.
EM.PREFIX = "!PUI_EMB1:"
local function clean(v) return (tostring(v):gsub("[|;:,\n]", " ")) end
function EM.Export(index)
  local seg = store()[index or 1]
  if not seg then return nil end
  local parts = { clean(seg.name), seg.meter, math.floor(seg.duration or 0), math.floor(seg.total or 0) }
  local rows = {}
  for _, r in ipairs(seg.rows) do rows[#rows + 1] = table.concat({ clean(r.name), r.class or "", math.floor(r.amount) }, ",") end
  return EM.PREFIX .. table.concat(parts, ";") .. "|" .. table.concat(rows, ";")
end

function EM.Import(text)
  if type(text) ~= "string" or text:sub(1, #EM.PREFIX) ~= EM.PREFIX then return nil, "not an Embers string" end
  local head, body = text:sub(#EM.PREFIX + 1):match("^([^|]*)|(.*)$")
  if not head then return nil, "damaged string" end
  local name, meter, dur, total = head:match("^([^;]*);([^;]*);([^;]*);([^;]*)$")
  if not name then return nil, "damaged string" end
  local rows = {}
  for chunk in body:gmatch("[^;]+") do
    local n, class, amount = chunk:match("^([^,]*),([^,]*),([^,]*)$")
    amount = tonumber(amount)
    if n and amount then rows[#rows + 1] = { name = n, class = class ~= "" and class or nil, amount = amount, aps = (tonumber(dur) or 0) > 0 and amount / tonumber(dur) or 0 } end
  end
  return { name = name .. " (imported)", meter = meter, duration = tonumber(dur) or 0, total = tonumber(total) or 0, rows = rows, at = time() }
end

-- Per-pull graph: the player's own per-second figure, sampled at 1 Hz from
-- the API while in combat. Secret samples are not stored (gap in the graph).
function EM.Sample()
  local session = EM.Live("Dps", "Current")
  if not session then return end
  for _, src in ipairs(session.combatSources or {}) do
    if src.isLocalPlayer then
      local v = plain(src.amountPerSecond)
      local key = "current"
      EM.graph[key] = EM.graph[key] or {}
      local g = EM.graph[key]
      g[#g + 1] = v or false
      if #g > 1800 then table.remove(g, 1) end
    end
  end
end

-- Death recap: deaths in the current session (never-secret ids and class).
function EM.Deaths()
  local session = EM.Live("Deaths", "Current")
  local out = {}
  for _, src in ipairs(session and session.combatSources or {}) do
    out[#out + 1] = { name = src.name, class = src.classFilename, recap = src.deathRecapID, at = src.deathTimeSeconds }
  end
  return out
end

-- Class/spec icon resolution: the API gives classFilename and specIconID as
-- never-secret fields, so nothing has to be cached from inspection.
function EM.ClassColor(class)
  local c = class and C_ClassColor.GetClassColor(class)
  if c then return c:GetRGB() end
  return 0.6, 0.6, 0.6
end

function EM.RefreshWindows()
  for i = 1, #EM.windows do ns.Window.Update(EM.windows[i]) end
end

local function onEnable(mod)
  EM.active = true
  for i = 1, 5 do
    if i <= s.windows then
      EM.windows[i] = EM.windows[i] or ns.Window.Create(i)
      EM.windows[i].frame:Show()
    elseif EM.windows[i] then EM.windows[i].frame:Hide() end
  end
  mod:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", EM.OnSession)
  mod:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", function() EM.RefreshWindows() end)
  mod:RegisterEvent("DAMAGE_METER_RESET", function() wipe(EM.graph); EM.RefreshWindows() end)
  if s.graph then Ticker:Register("embers.graph", 1, function() if InCombatLockdown() then EM.Sample() end end, OWNER) end
  Ticker:Register("embers.refresh", 0.5, function() if InCombatLockdown() then EM.RefreshWindows() end end, OWNER)
  EM.RefreshWindows()
end

local function onDisable()
  EM.active = false
  Ticker:Unregister("embers.graph")
  Ticker:Unregister("embers.refresh")
  for _, w in ipairs(EM.windows) do w.frame:Hide() end
end

local schema = {}
EM.schema = schema
local function key(name, def)
  def.owner = OWNER
  def.apply = def.apply or function(value)
    s[name] = value
    if EM.active then onDisable(); onEnable(EM.module) end
  end
  schema["embers." .. name] = def
end
key("windows", { type = "range", default = 1, min = 1, max = 5, step = 1, label = "Meter windows", tooltip = "How many meter windows to show (up to 5); each snaps in Studio.", mode = "simple" })
key("meter", { type = "select", default = "DamageDone", choices = EM.METERS, label = "Meter type", tooltip = "What the first window shows. Each window can switch with a click on its title.", mode = "simple" })
key("rows", { type = "range", default = 8, min = 3, max = 25, step = 1, label = "Rows", tooltip = "Rows per window.", mode = "advanced" })
key("look", { type = "select", default = "bars", choices = EM.LOOKS, label = "Look", tooltip = "Bars, compact or minimal rows; switches live.", mode = "simple" })
key("maxSegments", { type = "range", default = 30, min = 5, max = 200, step = 5, label = "Saved segments", tooltip = "How many finished fights to keep across reloads (pinned ones are always kept).", mode = "advanced" })
key("bossOnly", { type = "toggle", default = false, label = "Bosses only", tooltip = "Keep only boss fights in the saved segments.", mode = "advanced" })
key("graph", { type = "toggle", default = true, label = "Per-pull graph", tooltip = "Samples your own per-second figure once a second in combat for the pull graph.", mode = "advanced" })
key("report", { type = "range", default = 5, min = 1, max = 15, step = 1, label = "Report lines", tooltip = "How many names a chat report lists.", mode = "advanced" })
schema["embers.segments"] = { type = "layout", default = {}, mode = "advanced", owner = OWNER, label = "Saved segments",
  tooltip = "Finished fights kept by Embers.", apply = function() end }

for i = 1, 5 do
  PUI.Layout:RegisterElement("embers.window" .. i, { label = "Embers window " .. i, owner = OWNER, size = { 240, 180 },
    default = { point = "BOTTOMRIGHT", x = -20 - (i - 1) * 250, y = 220 } })
end

PUI.Slash:Register("embers", function(rest)
  local word, arg = (rest or ""):match("^(%S*)%s*(.-)$")
  local out = PUI.Slash.Print
  if word == "report" then
    local ok, why = EM.Report(1, arg ~= "" and arg or nil)
    if not ok then out("not reported: " .. why) end
  elseif word == "export" then
    out(EM.Export(1) or "no saved segment")
  elseif word == "reset" then
    C_DamageMeter.ResetAllCombatSessions()
  elseif word == "list" then
    for i, seg in ipairs(store()) do out(string.format("%d. %s%s (%s)", i, seg.name, seg.pinned and " [pinned]" or "", seg.meter)) end
  elseif word == "pin" then
    EM.Pin(tonumber(arg) or 1, true)
  elseif word == "deaths" then
    for _, d in ipairs(EM.Deaths()) do out(Secret.ToText(d.name) .. " died") end
  else
    out("/pui embers list | report [say|party|raid|guild] | export | pin N | deaths | reset")
  end
end, "Embers meter: list, report, export, pin, deaths, reset")

EM.module = PUI:RegisterModule(OWNER, {
  label = "Embers", tooltip = "Damage meter on the game's own meter data, with saved segments, graphs, report and export.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
})
for k, def in pairs(schema) do if def.type ~= "layout" then def.apply(Schema:Get(k)) end end
