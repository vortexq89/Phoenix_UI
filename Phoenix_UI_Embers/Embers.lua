local PUI = _G.PhoenixUI if not (PUI and PUI.gateOpen) then return end
-- Embers (plan 5.14, 15.5, mockup 10): the damage meter on Blizzard's own meter
-- data (C_DamageMeter), the only legal source on 12.x (the combat log is closed
-- to addons). Live numbers may be secret in restricted content: they go into
-- StatusBars, AbbreviateNumbers and SetFormattedText, never into Lua maths or
-- comparisons. Out of combat a finished session is copied into Phoenix's own
-- segment store, keeping only values the game reports as non-secret, so named,
-- pinned and merged segments survive reload and logout up to the user's cap.
-- Owners (1.O): Embers owns the death recap and party interrupt counts (Ascent
-- reads both); the combat clock is PUI.CombatTimer; reports go through the
-- announcement router; window sets per content come from content profiles
-- (every key here is a profile setting, Embers has no switcher of its own).
-- Off by default.
local _, ns = ...
local Schema, Secret, CQ, Ticker = PUI.Schema, PUI.Secret, PUI.CombatQueue, PUI.Ticker
local OWNER = "Embers"
local MAX_WINDOWS = 4

local EM = { active = false, windows = {}, graph = {}, OWNER = OWNER, MAX_WINDOWS = MAX_WINDOWS }
ns.EM = EM
PUI.Embers = EM
local s = {
  windows = 1, look = "phoenix", rows = 8, pinSelf = true, width = 240, rowHeight = 18, spacing = 1, fontSize = 11,
  barAlpha = 0.9, bgAlpha = 0.75, border = true, classColors = true, showRank = true, showIcon = "spec", showPercent = true,
  showPerSecond = true, header = true, headerTimer = true, refresh = 0.5, numberStyle = "short", forcedUnit = "auto",
  maxSegments = 30, bossOnly = false, graph = true, report = 5, recapEvents = 10, recapOnDeath = false,
  breakdownOnHover = true, breakdownSpells = 8, compareBest = true, bestGhost = true, autoReport = false,
  meters = { "DamageDone", "HealingDone", "Interrupts", "Deaths" }, sessions = { "Current", "Current", "Current", "Current" },
}
EM.settings = s

-- Meter types are the API's own enum (DamageMeterType, 12.0.0+ and Forever)
-- plus Phoenix's Threat window (UnitDetailedThreatSituation, display only).
EM.METERS = { "DamageDone", "Dps", "HealingDone", "Hps", "Absorbs", "Interrupts", "Dispels", "DamageTaken", "AvoidableDamageTaken",
  "Deaths", "EnemyDamageTaken", "Threat" }
EM.METER_LABELS = { DamageDone = "Damage", Dps = "DPS", HealingDone = "Healing", Hps = "HPS", Absorbs = "Absorbs",
  Interrupts = "Interrupts", Dispels = "Dispels", DamageTaken = "Damage taken", AvoidableDamageTaken = "Avoidable damage taken",
  Deaths = "Deaths", EnemyDamageTaken = "Enemy damage taken", Threat = "Threat" }
EM.SESSIONS = { "Current", "Overall", "Saved" }
EM.SESSION_LABELS = { Current = "Current fight", Overall = "Overall", Saved = "Last saved segment" }
EM.LOOKS = { "phoenix", "glass", "blizzard", "compact", "minimal" }
EM.LOOK_LABELS = { phoenix = "Phoenix (Ember)", glass = "Glass", blizzard = "Blizzard-like", compact = "Compact", minimal = "Minimal (text only)" }
EM.UNITS = { "auto", "K", "M", "B" }

function EM.Available()
  local ok, why = C_DamageMeter.IsDamageMeterAvailable()
  return ok == true, why
end

function EM.TypeValue(name) return Enum.DamageMeterType[name] end
function EM.IsThreat(meter) return meter == "Threat" end

-- Live view: the current or overall session of one meter type. Rows carry
-- the API values untouched (possibly secret) plus never-secret fields.
function EM.Live(meter, which)
  if EM.IsThreat(meter) then return nil end
  local sessionType = Enum.DamageMeterSessionType[which or "Current"]
  return C_DamageMeter.GetCombatSessionFromType(sessionType, EM.TypeValue(meter))
end

local function plain(v) if Secret.IsSecret(v) then return nil end return v end
EM.Plain = plain

-- Numbers -----------------------------------------------------------------------
local UNIT_DIV = { K = 1e3, M = 1e6, B = 1e9 }
-- Text for a meter number. Secret values go to the engine's formatter; plain
-- ones follow the user's style and forced unit (K/M/B).
function EM.FormatNumber(v)
  if Secret.IsSecret(v) then return AbbreviateNumbers(v) end
  if type(v) ~= "number" then return "" end
  local div = UNIT_DIV[s.forcedUnit]
  if div then return string.format(v / div >= 100 and "%.0f%s" or "%.1f%s", v / div, s.forcedUnit) end
  return PUI.Format.Number(v, s.numberStyle, v >= 1e6 and 2 or 1)
end

-- Segment store -------------------------------------------------------------------
local function store() return Schema:Get("embers.segments") end
EM.Store = store

-- Spells of one source (breakdown). Values as they come (possibly secret).
function EM.SourceSpells(which, meter, guid)
  if not guid or EM.IsThreat(meter) then return {} end
  local src = C_DamageMeter.GetCombatSessionSourceFromType(Enum.DamageMeterSessionType[which or "Current"], EM.TypeValue(meter), guid)
  local out = {}
  for i, sp in ipairs(src and src.combatSpells or {}) do
    if i > s.breakdownSpells then break end
    out[i] = { spellID = sp.spellID, amount = sp.totalAmount, aps = sp.amountPerSecond }
  end
  return out, src and src.totalAmount
end

-- Copy one finished session (by id) into a storable segment. Fields the game
-- still reports as secret are dropped; a segment with no readable rows is not kept.
function EM.Capture(sessionID, name, meter)
  meter = meter or s.meters[1]
  if EM.IsThreat(meter) then meter = "DamageDone" end
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
  local seg = { name = plain(name) or ("Segment " .. sessionID), meter = meter, at = time(), duration = plain(session.durationSeconds) or 0,
    total = plain(session.totalAmount) or 0, rows = rows, graph = EM.graph.current }
  local enc = EM.lastEncounter
  if enc and enc.name == seg.name then
    seg.encounterID, seg.difficulty, seg.kill = enc.id, enc.difficulty, enc.kill
  end
  return seg
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

function EM.IsBoss(seg) return seg ~= nil and seg.encounterID ~= nil end

-- Best pull (upgrade over Blizzard and Details): your best per-second figure on
-- the same boss and difficulty among saved segments of that meter.
function EM.BestPull(encounterID, difficulty, meter, skip)
  if not encounterID then return nil end
  local best
  for _, seg in ipairs(store()) do
    if seg ~= skip and seg.encounterID == encounterID and (difficulty == nil or seg.difficulty == difficulty) and seg.meter == (meter or seg.meter) then
      for _, r in ipairs(seg.rows) do
        if r.me and (not best or r.aps > best.aps) then best = { aps = r.aps, amount = r.amount, at = seg.at, kill = seg.kill } end
      end
    end
  end
  return best
end

-- Percent difference of a pull's own row against your best saved pull
-- (call before the pull itself is stored).
function EM.VsBest(seg)
  if not (seg and seg.encounterID) then return nil end
  local mine
  for _, r in ipairs(seg.rows) do if r.me then mine = r end end
  local best = EM.BestPull(seg.encounterID, seg.difficulty, seg.meter, seg)
  if not (mine and best and best.aps > 0) then return nil end
  return (mine.aps - best.aps) / best.aps * 100, best
end

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
    if seg and (not s.bossOnly or EM.IsBoss(seg)) then
      -- compared before it is stored, so a pull never counts as its own best
      if EM.IsBoss(seg) then seg.vsBest = EM.VsBest(seg) end
      EM.Save(seg)
      if EM.IsBoss(seg) then EM.AfterBoss(seg) end
    end
  end
  EM.pending = nil
  EM.graph.current = nil
  EM.RefreshWindows()
end

-- After a boss: your result against your best, and an optional report line
-- through the announcement router (where and whether it goes is set there).
function EM.AfterBoss(seg)
  if s.autoReport and seg.rows[1] then
    local r = seg.rows[1]
    PUI.Announce:Send("meter", string.format("%s: top %s %s (%s/s)", seg.name, r.name, EM.FormatNumber(r.amount), EM.FormatNumber(r.aps or 0)))
  end
end

function EM.OnEncounterEnd(_, _, id, name, difficulty, _, success)
  EM.lastEncounter = { id = id, name = name, difficulty = difficulty, kill = success == 1 }
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

-- Interrupt counts (1.O owner): party kicks for Ascent's kick line and run
-- card. Counts are handed on as they come (possibly secret).
function EM.Interrupts(which)
  local session = EM.Live("Interrupts", which or "Current")
  local out = {}
  for _, src in ipairs(session and session.combatSources or {}) do
    out[#out + 1] = { name = src.name, class = src.classFilename, count = src.totalAmount, me = src.isLocalPlayer }
  end
  return out
end

-- Run totals (Ascent run card): per meter, the Overall session's plain values
-- by name; values the game still hides are left out.
function EM.Totals(meters)
  local out = {}
  for _, meter in ipairs(meters) do
    local session = EM.Live(meter, "Overall")
    for _, src in ipairs(session and session.combatSources or {}) do
      local n = plain(src.name)
      if n then
        out[n] = out[n] or { class = src.classFilename, me = src.isLocalPlayer }
        out[n][meter] = plain(src.totalAmount)
        out[n][meter .. "PS"] = plain(src.amountPerSecond)
      end
    end
  end
  return out
end

-- Report and export -------------------------------------------------------------
function EM.ReportLines(seg, top)
  local lines = { string.format("Phoenix Embers - %s (%s, %ds)", seg.name, EM.METER_LABELS[seg.meter] or seg.meter, math.floor(seg.duration or 0)) }
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

-- An explicit report the user asked for (channel chosen by them).
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
      EM.graph.current = EM.graph.current or {}
      local g = EM.graph.current
      g[#g + 1] = plain(src.amountPerSecond) or false
      if #g > 1800 then table.remove(g, 1) end
    end
  end
end

-- Deaths (1.O owner): deaths in a session with their recap IDs.
function EM.Deaths(which)
  local session = EM.Live("Deaths", which or "Current")
  local out = {}
  for _, src in ipairs(session and session.combatSources or {}) do
    out[#out + 1] = { name = src.name, class = src.classFilename, recap = src.deathRecapID, at = src.deathTimeSeconds, me = src.isLocalPlayer }
  end
  return out
end

-- Threat rows (window type "Threat"): group members against your target.
-- Percentages are passed to the bar and formatter as they come; the list keeps
-- group order because secret values cannot be sorted.
function EM.ThreatUnits()
  local units = { "player" }
  if IsInGroup() then
    local raid, n = IsInRaid(), GetNumGroupMembers()
    for i = 1, raid and n or n - 1 do units[#units + 1] = (raid and "raid" or "party") .. i end
    if not raid then units[#units + 1] = "pet" end
  end
  return units
end

function EM.Threat()
  local out = {}
  if not UnitExists("target") then return out end
  for _, unit in ipairs(EM.ThreatUnits()) do
    if UnitExists(unit) then
      local tanking, _, pct = UnitDetailedThreatSituation(unit, "target")
      if type(pct) ~= "nil" then
        local _, class = UnitClass(unit)
        out[#out + 1] = { name = UnitName(unit), class = class, value = pct, tanking = tanking, me = unit == "player" }
      end
    end
  end
  return out
end

-- Class colour: classFilename is never secret, so nothing is cached from inspection.
function EM.ClassColor(class)
  local c = class and not Secret.IsSecret(class) and C_ClassColor.GetClassColor(class)
  if c then return c:GetRGB() end
  return 0.6, 0.6, 0.6
end

function EM.RefreshWindows()
  for i = 1, #EM.windows do ns.Window.Update(EM.windows[i]) end
end

-- Recap on your own death (setting, off by default).
function EM.OnPlayerDead()
  if not s.recapOnDeath then return end
  for _, d in ipairs(EM.Deaths("Current")) do
    if d.me and ns.Recap then ns.Recap.Open(d.recap, d.name, d.class) end
  end
end

local function onEnable(mod)
  EM.active = true
  for i = 1, MAX_WINDOWS do
    if i <= s.windows then
      EM.windows[i] = EM.windows[i] or ns.Window.Create(i)
      EM.windows[i].frame:Show()
    elseif EM.windows[i] then EM.windows[i].frame:Hide() end
  end
  mod:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", EM.OnSession)
  mod:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", function() EM.RefreshWindows() end)
  mod:RegisterEvent("DAMAGE_METER_RESET", function() wipe(EM.graph); EM.RefreshWindows() end)
  mod:RegisterEvent("ENCOUNTER_END", EM.OnEncounterEnd)
  mod:RegisterEvent("PLAYER_DEAD", EM.OnPlayerDead)
  mod:RegisterEvent("PLAYER_TARGET_CHANGED", function() EM.RefreshWindows() end)
  if s.graph then Ticker:Register("embers.graph", 1, function() if InCombatLockdown() then EM.Sample() end end, OWNER) end
  -- one shared refresh job, combat-only and visible-only (15.5 segment engine)
  Ticker:Register("embers.refresh", math.max(0.5, s.refresh), function() if InCombatLockdown() then EM.RefreshWindows() end end, OWNER)
  EM.RefreshWindows()
end

local function onDisable()
  EM.active = false
  Ticker:Unregister("embers.graph")
  Ticker:Unregister("embers.refresh")
  for _, w in ipairs(EM.windows) do w.frame:Hide() end
  if ns.Recap then ns.Recap.Close(); ns.Recap.HideBreakdown() end
end
function EM.Restart() if EM.active then onDisable(); onEnable(EM.module) end end

-- Settings -----------------------------------------------------------------------
local schema = {}
EM.schema = schema
local REBUILD = { windows = true, graph = true, refresh = true }
local function key(name, def)
  def.owner = OWNER
  def.apply = def.apply or function(value)
    s[name] = value
    if REBUILD[name] then EM.Restart() elseif EM.active then EM.RefreshWindows() end
  end
  schema["embers." .. name] = def
end
-- Simple
key("windows", { type = "range", default = 1, min = 1, max = MAX_WINDOWS, step = 1, label = "Meter windows",
  tooltip = "How many meter windows to show (up to 4). Each one has its own meter type and fight; move them in Studio. Different window sets per raid, Mythic+ or arena come from your content profiles.", mode = "simple",
  searchTags = { "meter", "damage", "details", "window" } })
for i = 1, MAX_WINDOWS do
  local idx = i
  key("w" .. i .. ".meter", { type = "select", default = s.meters[i], choices = EM.METERS, choiceLabels = EM.METER_LABELS,
    label = "Window " .. i .. ": shows", tooltip = "What window " .. i .. " shows. Threat lists your group's threat on your target. You can also left-click the window title to switch.",
    mode = "simple", apply = function(v) s.meters[idx] = v; if EM.windows[idx] then EM.windows[idx].meter = v end; if EM.active then EM.RefreshWindows() end end })
  key("w" .. i .. ".session", { type = "select", default = "Current", choices = EM.SESSIONS, choiceLabels = EM.SESSION_LABELS,
    label = "Window " .. i .. ": fight", tooltip = "Current fight, the overall session, or your last saved segment. Right-click the window title to switch.",
    mode = "simple", apply = function(v) s.sessions[idx] = v; if EM.windows[idx] then EM.windows[idx].source = v end; if EM.active then EM.RefreshWindows() end end })
end
key("look", { type = "select", default = "phoenix", choices = EM.LOOKS, choiceLabels = EM.LOOK_LABELS, label = "Look",
  tooltip = "Phoenix, Glass, Blizzard-like, compact or text-only rows. Every part of a look can also be changed below.", mode = "simple" })
key("rows", { type = "range", default = 8, min = 3, max = 25, step = 1, label = "Rows", tooltip = "Rows per window.", mode = "simple" })
key("pinSelf", { type = "toggle", default = true, label = "Always show me",
  tooltip = "When you are below the last visible row, your own row replaces it with your real rank.", mode = "simple" })
key("compareBest", { type = "toggle", default = true, label = "Compare with my best pull",
  tooltip = "On a boss, shows your best saved pull on the same boss and difficulty in the title, and after the pull how you did against it.", mode = "simple" })
key("numberStyle", { type = "select", default = "short", choices = PUI.Format.STYLES, choiceLabels = PUI.Format.STYLE_LABELS,
  label = "Number format", tooltip = "How amounts are written. Numbers the game hides in combat always use the game's own short format.", mode = "simple" })
key("bossOnly", { type = "toggle", default = false, label = "Save bosses only", tooltip = "Keep only boss fights in the saved segments.", mode = "simple" })
-- Display (advanced)
key("width", { type = "range", default = 240, min = 160, max = 480, step = 4, label = "Window width", tooltip = "Width of every meter window.", mode = "advanced" })
key("rowHeight", { type = "range", default = 18, min = 10, max = 32, step = 1, label = "Row height", tooltip = "Height of each row.", mode = "advanced" })
key("spacing", { type = "range", default = 1, min = 0, max = 6, step = 1, label = "Row spacing", tooltip = "Space between rows.", mode = "advanced" })
key("fontSize", { type = "range", default = 11, min = 8, max = 18, step = 1, label = "Text size", tooltip = "Size of names and amounts.", mode = "advanced" })
key("barAlpha", { type = "range", default = 0.9, min = 0.1, max = 1, step = 0.05, label = "Bar opacity", tooltip = "How solid the row bars are.", mode = "advanced" })
key("bgAlpha", { type = "range", default = 0.75, min = 0, max = 1, step = 0.05, label = "Background opacity", tooltip = "Window background opacity.", mode = "advanced" })
key("border", { type = "toggle", default = true, label = "Window border", tooltip = "Thin accent border around each window.", mode = "advanced" })
key("classColors", { type = "toggle", default = true, label = "Class colours", tooltip = "Colour bars by class; off uses your accent colour.", mode = "advanced" })
key("showRank", { type = "toggle", default = true, label = "Rank numbers", tooltip = "Writes 1., 2., 3. before names.", mode = "advanced" })
key("showIcon", { type = "select", default = "spec", choices = { "spec", "none" }, choiceLabels = { spec = "Spec icon", none = "No icon" },
  label = "Row icon", tooltip = "Spec icon next to each row.", mode = "advanced" })
key("showPercent", { type = "toggle", default = true, label = "Percent of total", tooltip = "Adds each row's share of the total when the game shows the numbers.", mode = "advanced" })
key("showPerSecond", { type = "toggle", default = true, label = "Per second", tooltip = "Adds the per-second figure to saved segments.", mode = "advanced" })
key("forcedUnit", { type = "select", default = "auto", choices = EM.UNITS, choiceLabels = { auto = "Automatic", K = "Always K", M = "Always M", B = "Always B" },
  label = "Force unit", tooltip = "Write every readable number in thousands, millions or billions.", mode = "advanced" })
key("header", { type = "toggle", default = true, label = "Title bar", tooltip = "Shows the title bar with meter, fight and timer.", mode = "advanced" })
key("headerTimer", { type = "toggle", default = true, label = "Combat timer in title", tooltip = "Shows the shared combat and encounter timer in the title.", mode = "advanced" })
key("refresh", { type = "range", default = 0.5, min = 0.5, max = 3, step = 0.25, label = "Refresh every (seconds)",
  tooltip = "How often windows redraw in combat. 0.5 seconds is the fastest; slower saves a little CPU.", mode = "advanced" })
key("bestGhost", { type = "toggle", default = true, label = "Best-pull marker on my row", tooltip = "A faint bar on your row showing your best pull on this boss.", mode = "advanced" })
key("breakdownOnHover", { type = "toggle", default = true, label = "Breakdown on hover", tooltip = "Hovering a row opens the spell breakdown beside the window, on the side with more room.", mode = "advanced" })
key("breakdownSpells", { type = "range", default = 8, min = 3, max = 20, step = 1, label = "Breakdown spells", tooltip = "How many spells the breakdown lists.", mode = "advanced" })
key("recapEvents", { type = "range", default = 10, min = 3, max = 25, step = 1, label = "Death recap lines", tooltip = "How many events the death recap lists before a death.", mode = "advanced" })
key("recapOnDeath", { type = "toggle", default = false, label = "Open recap when I die", tooltip = "Opens your death recap automatically when you die.", mode = "advanced" })
key("maxSegments", { type = "range", default = 30, min = 5, max = 200, step = 5, label = "Saved segments", tooltip = "How many finished fights to keep across reloads (pinned ones are always kept).", mode = "advanced" })
key("graph", { type = "toggle", default = true, label = "Per-pull graph", tooltip = "Samples your own per-second figure once a second in combat for the pull graph.", mode = "advanced" })
key("report", { type = "range", default = 5, min = 1, max = 15, step = 1, label = "Report lines", tooltip = "How many names a chat report lists.", mode = "advanced" })
key("autoReport", { type = "toggle", default = false, label = "Announce boss results",
  tooltip = "After a boss, sends the top line through Phoenix announcements (where it goes is set on the Announcements page).", mode = "advanced" })
schema["embers.segments"] = { type = "layout", default = {}, mode = "advanced", owner = OWNER, label = "Saved segments",
  tooltip = "Finished fights kept by Embers.", apply = function() end }

local ckey, cdef = PUI.Coexist:Define("embers", { module = OWNER, job = "Damage meter", addons = { "Details", "Skada", "Recount" } })
cdef.owner = OWNER
schema[ckey] = cdef

for i = 1, MAX_WINDOWS do
  PUI.Layout:RegisterElement("embers.window" .. i, { label = "Embers window " .. i, owner = OWNER, size = { 240, 180 },
    default = { point = "BOTTOMRIGHT", x = -19 - (i - 1) * 250, y = 45 } })
end

-- Step 8c settings carry-over (never resets a choice): the old single meter
-- key becomes window 1's meter, old looks map to the new names, more than four
-- windows become four.
PUI.DB:RegisterMigration("0008c_embers_keys", function(sv)
  local LOOK = { bars = "phoenix", compact = "compact", minimal = "minimal" }
  for _, p in pairs(sv.profiles or {}) do
    if type(p) == "table" then
      if p["embers.meter"] ~= nil then
        if p["embers.w1.meter"] == nil then p["embers.w1.meter"] = p["embers.meter"] end
        p["embers.meter"] = nil
      end
      if p["embers.look"] ~= nil and LOOK[p["embers.look"]] then p["embers.look"] = LOOK[p["embers.look"]] end
      if type(p["embers.windows"]) == "number" and p["embers.windows"] > MAX_WINDOWS then p["embers.windows"] = MAX_WINDOWS end
    end
  end
  return true
end)

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
  elseif word == "deaths" or word == "recap" then
    local list = EM.Deaths("Current")
    if #list == 0 then out("no deaths in this fight") end
    for _, d in ipairs(list) do out(Secret.ToText(d.name) .. " died") end
    local last = list[#list]
    if word == "recap" and last and ns.Recap then ns.Recap.Open(last.recap, last.name, last.class) end
  else
    out("/pui embers list | report [say|party|raid|guild] | export | pin N | deaths | recap | reset")
  end
end, "Embers meter: list, report, export, pin, deaths, recap, reset")

EM.module = PUI:RegisterModule(OWNER, {
  label = "Embers", tooltip = "Damage meter on the game's own meter data: up to four windows, your own row pinned, spell breakdown, death recap, threat, and your best pull on each boss.",
  enabledByDefault = false, schema = schema, onEnable = onEnable, onDisable = onDisable,
  loadCondition = function() return PUI.Coexist:Allows("embers") end,
})
for k, def in pairs(schema) do if def.type ~= "layout" and k:sub(1, 7) == "embers." then def.apply(Schema:Get(k)) end end
